//
//  ProteomicsDataDatabaseManager.swift
//  Curtain
//
//  Manages per-linkId SQLite database connections using GRDB
//  Equivalent to Android's ProteomicsDataDatabaseManager
//

import Foundation
import GRDB

class ProteomicsDataDatabaseManager {

    // MARK: - Singleton

    static let shared = ProteomicsDataDatabaseManager()

    // MARK: - Constants

    static let schemaVersionKey = "schema_version"
    /// Schema version must match Android (version 5)
    /// When this changes, existing databases will be dropped and recreated (fallbackToDestructiveMigration equivalent)
    static let currentSchemaVersion = 5

    // MARK: - Private Properties

    private var databases: [String: DatabaseQueue] = [:]
    private let lock = NSLock()
    private let fileManager = FileManager.default

    private init() {}

    // MARK: - Public API

    /// Gets or creates a database connection for a specific linkId
    func getDatabaseForLinkId(_ linkId: String) throws -> DatabaseQueue {
        lock.lock()
        defer { lock.unlock() }

        if let existingDb = databases[linkId] {
            return existingDb
        }

        let dbPath = getDatabasePath(for: linkId)
        let dbDirectory = (dbPath as NSString).deletingLastPathComponent

        // Ensure directory exists
        try fileManager.createDirectory(atPath: dbDirectory, withIntermediateDirectories: true)

        // Configure GRDB
        var config = Configuration()
        config.foreignKeysEnabled = true
        config.readonly = false

        let db = try DatabaseQueue(path: dbPath, configuration: config)

        // Create tables if they don't exist
        try db.write { database in
            try ProcessedProteomicsData.createTable(in: database)
            try RawProteomicsData.createTable(in: database)
            try ProteomicsDataMetadata.createTable(in: database)
            try CurtainMetadata.createTable(in: database)
            try GenesMapEntry.createTable(in: database)
            try PrimaryIdsMapEntry.createTable(in: database)
            try GeneNameToAccEntry.createTable(in: database)
            try AllGenesEntry.createTable(in: database)
            // Denormalized mapping tables (matching Android ProteinMappingDatabase)
            try GeneNameMapping.createTable(in: database)
            try PrimaryIdMapping.createTable(in: database)
            try ProteinMappingMetadata.createTable(in: database)
        }

        databases[linkId] = db
        print("[ProteomicsDataDB] Created/opened database for \(linkId) at \(dbPath)")

        return db
    }

    /// Checks if data exists for a linkId and schema version matches
    /// Implements behavior similar to Android Room's fallbackToDestructiveMigration()
    func checkDataExists(_ linkId: String) -> Bool {
        do {
            let db = try getDatabaseForLinkId(linkId)

            return try db.read { database in
                let processedCount = try ProcessedProteomicsData.fetchCount(database)
                let rawCount = try RawProteomicsData.fetchCount(database)

                let storedVersion = try ProteomicsDataMetadata
                    .filter(Column("key") == Self.schemaVersionKey)
                    .fetchOne(database)?.value

                let storedVersionInt = storedVersion.flatMap { Int($0) }
                let versionMatches = storedVersionInt == Self.currentSchemaVersion

                print("[ProteomicsDataDB] checkDataExists for \(linkId): processedCount=\(processedCount), rawCount=\(rawCount), storedVersion=\(storedVersion ?? "nil")")

                if (processedCount > 0 || rawCount > 0) && !versionMatches {
                    print("[ProteomicsDataDB] Schema version mismatch for \(linkId). Will rebuild.")
                    return false
                }

                return (processedCount > 0 || rawCount > 0) && versionMatches
            }
        } catch {
            print("[ProteomicsDataDB] Error checking data exists: \(error)")
            // If there's a disk I/O error, the database is likely corrupted - delete it
            // This is similar to Room's fallbackToDestructiveMigration behavior
            fallbackToDestructiveMigration(linkId: linkId)
            return false
        }
    }

    /// Deletes and recreates the database when schema is incompatible or corrupted
    /// Equivalent to Android Room's fallbackToDestructiveMigration()
    private func fallbackToDestructiveMigration(linkId: String) {
        print("[ProteomicsDataDB] fallbackToDestructiveMigration for \(linkId)")

        // Remove from cache first
        lock.lock()
        databases.removeValue(forKey: linkId)
        lock.unlock()

        // Delete the database file
        let path = getDatabasePath(for: linkId)
        if fileManager.fileExists(atPath: path) {
            do {
                try fileManager.removeItem(atPath: path)
                print("[ProteomicsDataDB] Deleted database file for \(linkId)")
            } catch {
                print("[ProteomicsDataDB] Failed to delete database: \(error)")
            }
        }

        // Also delete any WAL/SHM journal files
        let walPath = path + "-wal"
        let shmPath = path + "-shm"
        try? fileManager.removeItem(atPath: walPath)
        try? fileManager.removeItem(atPath: shmPath)
    }

    /// Clears all data for a linkId
    /// Matches Android's clearAllData behavior
    func clearAllData(_ linkId: String) {
        print("[ProteomicsDataDB] Clearing all data for \(linkId)")
        do {
            let db = try getDatabaseForLinkId(linkId)

            try db.write { database in
                try database.execute(sql: "DELETE FROM \(ProcessedProteomicsData.databaseTableName)")
                try database.execute(sql: "DELETE FROM \(RawProteomicsData.databaseTableName)")
                try database.execute(sql: "DELETE FROM \(ProteomicsDataMetadata.databaseTableName)")
                try database.execute(sql: "DELETE FROM \(CurtainMetadata.databaseTableName)")
                try database.execute(sql: "DELETE FROM \(GenesMapEntry.databaseTableName)")
                try database.execute(sql: "DELETE FROM \(PrimaryIdsMapEntry.databaseTableName)")
                try database.execute(sql: "DELETE FROM \(GeneNameToAccEntry.databaseTableName)")
                try database.execute(sql: "DELETE FROM \(AllGenesEntry.databaseTableName)")
                // Clear denormalized mapping tables
                try database.execute(sql: "DELETE FROM \(GeneNameMapping.databaseTableName)")
                try database.execute(sql: "DELETE FROM \(PrimaryIdMapping.databaseTableName)")
                try database.execute(sql: "DELETE FROM \(ProteinMappingMetadata.databaseTableName)")
            }

            print("[ProteomicsDataDB] Cleared all data for \(linkId)")
        } catch {
            print("[ProteomicsDataDB] Error clearing data: \(error)")
            // If there's an error (likely corrupted database), use destructive migration
            fallbackToDestructiveMigration(linkId: linkId)
        }
    }

    /// Stores the schema version for a linkId
    func storeSchemaVersion(_ linkId: String) {
        do {
            let db = try getDatabaseForLinkId(linkId)

            try db.write { database in
                let metadata = ProteomicsDataMetadata(
                    key: Self.schemaVersionKey,
                    value: String(Self.currentSchemaVersion)
                )
                try metadata.save(database)
            }

            print("[ProteomicsDataDB] Stored schema version \(Self.currentSchemaVersion) for \(linkId)")
        } catch {
            print("[ProteomicsDataDB] Error storing schema version: \(error)")
        }
    }

    /// Closes database for a linkId
    func closeDatabase(_ linkId: String) {
        lock.lock()
        defer { lock.unlock() }
        databases.removeValue(forKey: linkId)
        print("[ProteomicsDataDB] Closed database for \(linkId)")
    }

    /// Closes all open databases
    func closeAllDatabases() {
        lock.lock()
        defer { lock.unlock() }
        databases.removeAll()
        print("[ProteomicsDataDB] Closed all databases")
    }

    /// Gets the file path for a linkId's database
    func getDatabasePath(for linkId: String) -> String {
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let curtainDataDir = documentsPath.appendingPathComponent("CurtainData", isDirectory: true)
        return curtainDataDir.appendingPathComponent("proteomics_data_\(linkId).sqlite").path
    }

    /// Gets the URL for a linkId's database
    func getDatabaseURL(for linkId: String) -> URL {
        return URL(fileURLWithPath: getDatabasePath(for: linkId))
    }

    /// Checks if a database file exists for a linkId
    func databaseFileExists(for linkId: String) -> Bool {
        return fileManager.fileExists(atPath: getDatabasePath(for: linkId))
    }

    /// Deletes the database file for a linkId
    func deleteDatabaseFile(for linkId: String) throws {
        let path = getDatabasePath(for: linkId)
        if fileManager.fileExists(atPath: path) {
            closeDatabase(linkId)
            try fileManager.removeItem(atPath: path)
            print("[ProteomicsDataDB] Deleted database file for \(linkId)")
        }
    }
}

//
//  ProteinMappingService.swift
//  Curtain
//
//  Service for building and querying denormalized protein mappings
//  Matches Android's ProteinMappingService functionality
//

import Foundation
import GRDB

class ProteinMappingService {

    // MARK: - Singleton

    static let shared = ProteinMappingService()

    // MARK: - Constants

    private static let schemaVersionKey = "mapping_schema_version"
    private static let currentSchemaVersion = 1

    // MARK: - Dependencies

    private let databaseManager = ProteomicsDataDatabaseManager.shared
    private let proteomicsDataService = ProteomicsDataService.shared

    private init() {}

    // MARK: - Public API

    /// Ensures mapping tables exist and are populated
    /// Call this after proteomics data is ingested
    func ensureMappingsExist(linkId: String, curtainData: CurtainData) {
        do {
            let db = try databaseManager.getDatabaseForLinkId(linkId)

            // Create tables if they don't exist
            try db.write { database in
                try GeneNameMapping.createTable(in: database)
                try PrimaryIdMapping.createTable(in: database)
                try ProteinMappingMetadata.createTable(in: database)
            }

            // Check if mappings already exist
            let (mappingsExist, geneCount, idCount) = try db.read { database -> (Bool, Int, Int) in
                let geneCount = try GeneNameMapping.fetchCount(database)
                let idCount = try PrimaryIdMapping.fetchCount(database)

                // Check schema version
                let storedVersion = try ProteinMappingMetadata
                    .filter(Column("key") == Self.schemaVersionKey)
                    .fetchOne(database)?.value

                let versionMatches = storedVersion.flatMap { Int($0) } == Self.currentSchemaVersion

                return ((geneCount > 0 || idCount > 0) && versionMatches, geneCount, idCount)
            }

            // Check if UniProt data is available and mappings might need rebuild
            let hasUniprotData = (curtainData.extraData?.uniprot?.db as? [String: Any])?.count ?? 0 > 0

            if mappingsExist {
                print("[ProteinMappingService] Mappings exist for \(linkId), geneNameMappings: \(geneCount), idMappings: \(idCount)")

                // If gene mappings are empty but we have UniProt data, rebuild
                if geneCount == 0 && hasUniprotData {
                    print("[ProteinMappingService] Gene mappings empty but UniProt data available, rebuilding...")
                } else {
                    return
                }
            }

            // Build mappings
            print("[ProteinMappingService] Building mappings for \(linkId)")
            try buildMappings(linkId: linkId, curtainData: curtainData, db: db)

        } catch {
            print("[ProteinMappingService] Error ensuring mappings: \(error)")
        }
    }

    /// Gets gene name for a primary ID (fast O(1) lookup)
    func getGeneNameFromPrimaryId(linkId: String, primaryId: String) -> String? {
        guard !linkId.isEmpty, !primaryId.isEmpty else { return nil }

        do {
            let db = try databaseManager.getDatabaseForLinkId(linkId)
            return try db.read { database -> String? in
                // Direct lookup
                if let mapping = try GeneNameMapping
                    .filter(GeneNameMapping.Columns.primaryId == primaryId)
                    .fetchOne(database) {
                    return mapping.geneName
                }

                // Try split ID lookup
                let splitIds = primaryId.split(separator: ";").map { String($0).trimmingCharacters(in: .whitespaces) }
                for splitId in splitIds {
                    if splitId.isEmpty { continue }
                    if let mapping = try GeneNameMapping
                        .filter(GeneNameMapping.Columns.primaryId.like("%\(splitId)%"))
                        .fetchOne(database) {
                        return mapping.geneName
                    }
                }

                return nil
            }
        } catch {
            print("[ProteinMappingService] Error getting gene name: \(error)")
            return nil
        }
    }

    /// Gets primary IDs from gene name (fast O(1) lookup)
    func getPrimaryIdsFromGeneName(linkId: String, geneName: String) -> [String] {
        guard !linkId.isEmpty, !geneName.isEmpty else { return [] }

        do {
            let db = try databaseManager.getDatabaseForLinkId(linkId)
            return try db.read { database -> [String] in
                let mappings = try GeneNameMapping
                    .filter(GeneNameMapping.Columns.geneName == geneName.uppercased())
                    .fetchAll(database)
                return mappings.map { $0.primaryId }
            }
        } catch {
            print("[ProteinMappingService] Error getting primary IDs from gene name: \(error)")
            return []
        }
    }

    /// Gets primary IDs from split ID (fast O(1) lookup)
    func getPrimaryIdsFromSplitId(linkId: String, splitId: String) -> [String] {
        guard !linkId.isEmpty, !splitId.isEmpty else { return [] }

        do {
            let db = try databaseManager.getDatabaseForLinkId(linkId)
            return try db.read { database -> [String] in
                let mappings = try PrimaryIdMapping
                    .filter(PrimaryIdMapping.Columns.splitId == splitId.uppercased())
                    .fetchAll(database)
                return mappings.map { $0.primaryId }
            }
        } catch {
            print("[ProteinMappingService] Error getting primary IDs from split ID: \(error)")
            return []
        }
    }

    /// Clears all mappings for a linkId
    func clearMappings(linkId: String) {
        do {
            let db = try databaseManager.getDatabaseForLinkId(linkId)
            try db.write { database in
                try database.execute(sql: "DELETE FROM \(GeneNameMapping.databaseTableName)")
                try database.execute(sql: "DELETE FROM \(PrimaryIdMapping.databaseTableName)")
                try database.execute(sql: "DELETE FROM \(ProteinMappingMetadata.databaseTableName)")
            }
            print("[ProteinMappingService] Cleared mappings for \(linkId)")
        } catch {
            print("[ProteinMappingService] Error clearing mappings: \(error)")
        }
    }

    // MARK: - Private Methods

    /// Builds all mappings from processed data and UniProt data
    private func buildMappings(linkId: String, curtainData: CurtainData, db: DatabaseQueue) throws {
        // Clear existing mappings
        try db.write { database in
            try database.execute(sql: "DELETE FROM \(GeneNameMapping.databaseTableName)")
            try database.execute(sql: "DELETE FROM \(PrimaryIdMapping.databaseTableName)")
        }

        // Get all processed data
        let processedData = try proteomicsDataService.getAllProcessedData(linkId: linkId)

        // Debug: Check UniProt data availability
        let uniprotDB = curtainData.extraData?.uniprot?.db as? [String: Any]
        let uniprotCount = uniprotDB?.count ?? 0
        let isPTM = curtainData.differentialForm.isPTM
        print("[ProteinMappingService] Building mappings for \(processedData.count) proteins, UniProt entries: \(uniprotCount), isPTM: \(isPTM)")

        var geneNameMappings: [(String, String)] = []
        var primaryIdMappings: [(String, String)] = []

        for entity in processedData {
            let primaryId = entity.primaryId
            if primaryId.isEmpty { continue }

            // 1. Create primary ID mapping (map full ID to itself)
            primaryIdMappings.append((primaryId.uppercased(), primaryId))

            // 2. Create split ID mappings
            let splitIds = primaryId.split(separator: ";").map { String($0).trimmingCharacters(in: .whitespaces) }
            for splitId in splitIds {
                if splitId.isEmpty || splitId == primaryId { continue }
                primaryIdMappings.append((splitId.uppercased(), primaryId))
            }

            // 3. For PTM data, create accession -> site ID mapping
            if isPTM, let accession = entity.accession, !accession.isEmpty {
                primaryIdMappings.append((accession.uppercased(), primaryId))
            }

            // 4. Get gene name from multiple sources
            var geneName: String? = nil

            // Priority 1: From processed data geneNames column
            if let gn = entity.geneNames, !gn.isEmpty {
                geneName = gn
            }

            // Priority 2: For PTM data, look up gene name using accession from UniProt data
            if (geneName == nil || geneName?.isEmpty == true) && isPTM,
               let accession = entity.accession, !accession.isEmpty {
                geneName = getGeneNameFromUniProt(primaryId: accession, splitIds: [accession], uniprotDB: uniprotDB)
            }

            // Priority 3: From UniProt data using primary ID
            if geneName == nil || geneName?.isEmpty == true {
                geneName = getGeneNameFromUniProt(primaryId: primaryId, splitIds: splitIds, uniprotDB: uniprotDB)
            }

            // 5. Create gene name mappings if we found a gene name
            if let gn = geneName, !gn.isEmpty {
                // Map full gene name
                geneNameMappings.append((gn.uppercased(), primaryId))

                // Map individual gene name parts (split by space, semicolon, backslash)
                let geneParts = gn.components(separatedBy: CharacterSet(charactersIn: " ;\\"))
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }

                for part in geneParts {
                    if part != gn {
                        geneNameMappings.append((part.uppercased(), primaryId))
                    }
                }
            }
        }

        // Batch insert mappings
        print("[ProteinMappingService] Inserting \(geneNameMappings.count) gene name mappings")
        try db.write { database in
            for (geneName, primaryId) in geneNameMappings {
                let mapping = GeneNameMapping(geneName: geneName, primaryId: primaryId)
                try? mapping.insert(database, onConflict: .ignore)
            }
        }

        print("[ProteinMappingService] Inserting \(primaryIdMappings.count) primary ID mappings")
        try db.write { database in
            for (splitId, primaryId) in primaryIdMappings {
                let mapping = PrimaryIdMapping(splitId: splitId, primaryId: primaryId)
                try? mapping.insert(database, onConflict: .ignore)
            }
        }

        // Store schema version
        try db.write { database in
            let metadata = ProteinMappingMetadata(
                key: Self.schemaVersionKey,
                value: String(Self.currentSchemaVersion)
            )
            try metadata.save(database)
        }

        print("[ProteinMappingService] Mapping build complete for \(linkId)")
    }

    /// Extracts gene name from UniProt data
    private func getGeneNameFromUniProt(primaryId: String, splitIds: [String], uniprotDB: [String: Any]?) -> String? {
        guard let db = uniprotDB else { return nil }

        // Try exact match first
        if let record = db[primaryId] as? [String: Any],
           let geneNames = record["Gene Names"] as? String,
           !geneNames.isEmpty {
            return extractFirstGeneName(from: geneNames)
        }

        // Try split IDs
        for splitId in splitIds {
            if splitId.isEmpty { continue }
            if let record = db[splitId] as? [String: Any],
               let geneNames = record["Gene Names"] as? String,
               !geneNames.isEmpty {
                return extractFirstGeneName(from: geneNames)
            }
        }

        return nil
    }

    /// Extracts the first gene name from a gene names string
    private func extractFirstGeneName(from geneNames: String) -> String? {
        let parts = geneNames.components(separatedBy: CharacterSet(charactersIn: " ;\\"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return parts.first
    }

    // MARK: - Batch Operations for Search

    /// Gets primary IDs for multiple gene names (batch operation)
    func batchGetPrimaryIdsFromGeneNames(linkId: String, geneNames: [String]) -> [String: [String]] {
        guard !linkId.isEmpty, !geneNames.isEmpty else { return [:] }

        var result: [String: [String]] = [:]

        do {
            let db = try databaseManager.getDatabaseForLinkId(linkId)
            try db.read { database in
                for geneName in geneNames {
                    let upperName = geneName.uppercased()
                    let mappings = try GeneNameMapping
                        .filter(GeneNameMapping.Columns.geneName == upperName)
                        .fetchAll(database)
                    if !mappings.isEmpty {
                        result[geneName] = mappings.map { $0.primaryId }
                    }
                }
            }
        } catch {
            print("[ProteinMappingService] Error batch getting primary IDs: \(error)")
        }

        return result
    }

    /// Gets gene names for multiple primary IDs (batch operation)
    func batchGetGeneNames(linkId: String, primaryIds: [String]) -> [String: String] {
        guard !linkId.isEmpty, !primaryIds.isEmpty else { return [:] }

        var result: [String: String] = [:]

        do {
            let db = try databaseManager.getDatabaseForLinkId(linkId)
            try db.read { database in
                for primaryId in primaryIds {
                    if let mapping = try GeneNameMapping
                        .filter(GeneNameMapping.Columns.primaryId == primaryId)
                        .fetchOne(database) {
                        result[primaryId] = mapping.geneName
                    }
                }
            }
        } catch {
            print("[ProteinMappingService] Error batch getting gene names: \(error)")
        }

        return result
    }
}

//
//  CurtainDatabaseManager.swift
//  Curtain
//
//  Created by Toan Phung on 06/01/2026.
//

import Foundation
#if canImport(DuckDB)
import DuckDB
#endif

/// Manages the lifecycle of DuckDB connections for specific datasets.
/// This is the "Analytical Layer" of the hybrid architecture.
actor CurtainDatabaseManager {
    
    // MARK: - Singleton
    static let shared = CurtainDatabaseManager()
    
    // MARK: - Private Properties
    #if canImport(DuckDB)
    private var database: Database?
    private var connection: Connection?
    #endif
    private var currentDatabaseURL: URL?
    
    private init() {}
    
    // MARK: - Public API
    
    /// Initializes or opens a DuckDB database for a specific curtain dataset.
    /// - Parameter url: The file URL to the .duckdb file.
    func initializeDatabase(at url: URL) throws {
        // If we are already connected to this DB, do nothing
        if let current = currentDatabaseURL, current == url {
            return
        }
        
        // Close any existing connection
        closeDatabase()
        
        #if canImport(DuckDB)
        do {
            // Open the database file
            database = try Database(store: .file(at: url))
            connection = try database?.connect()
            currentDatabaseURL = url
            print("DuckDB initialized at: \(url.path)")
        } catch {
            throw DatabaseError.initializationFailed(error.localizedDescription)
        }
        #else
        print("DuckDB module not available. Database features will be disabled.")
        #endif
    }
    
    /// Closes the current database connection to free up memory.
    func closeDatabase() {
        #if canImport(DuckDB)
        connection = nil
        database = nil
        #endif
        currentDatabaseURL = nil
    }
    
    /// Executes a raw SQL query.
    /// - Parameter sql: The SQL string to execute.
    /// - Returns: A ResultSet containing the query results.
    #if canImport(DuckDB)
    func executeQuery(_ sql: String) throws -> ResultSet {
        guard let connection = connection else {
            throw DatabaseError.noConnection
        }
        
        do {
            return try connection.query(sql)
        } catch {
            throw DatabaseError.queryFailed(error.localizedDescription)
        }
    }
    #endif
    
    /// Checks if a database is currently open.
    var isDatabaseOpen: Bool {
        #if canImport(DuckDB)
        return connection != nil
        #else
        return false
        #endif
    }
}

// MARK: - Errors

enum DatabaseError: Error, LocalizedError {
    case noConnection
    case initializationFailed(String)
    case queryFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .noConnection:
            return "No active database connection."
        case .initializationFailed(let msg):
            return "Failed to initialize DuckDB: \(msg)"
        case .queryFailed(let msg):
            return "Query execution failed: \(msg)"
        }
    }
}

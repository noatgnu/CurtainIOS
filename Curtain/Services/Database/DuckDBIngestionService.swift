//
//  DuckDBIngestionService.swift
//  Curtain
//
//  Created by Toan Phung on 06/01/2026.
//
//  NOTE: This file is deprecated. DuckDB has been replaced with GRDB/SQLite.
//  See ProteomicsDataService.swift and ProteomicsDataDatabaseManager.swift for the new implementation.
//

import Foundation

#if canImport(DuckDB)
import DuckDB

/// Handles the creation of DuckDB database files from raw JSON/CSV data.
/// This service is responsible for the "Ingestion" phase of the pipeline.
/// @deprecated Use ProteomicsDataService instead.
actor DuckDBIngestionService {

    // MARK: - Singleton
    static let shared = DuckDBIngestionService()

    private let fileManager = FileManager.default
    private let databaseManager = CurtainDatabaseManager.shared

    private init() {}

    // MARK: - Public API

    /// Ingests curtain data and metadata into a new DuckDB database file.
    /// - Parameters:
    ///   - linkId: The unique ID of the curtain (used for filename).
    ///   - rawTsv: The raw data tab-separated string.
    ///   - processedTsv: The processed data tab-separated string.
    ///   - extraData: The full extraData object containing UniProt and dataset maps.
    /// - Returns: The file URL of the created .duckdb file.
    func ingestData(linkId: String, rawTsv: String?, processedTsv: String?, extraData: [String: Any]? = nil) async throws -> URL {
        // 1. Prepare Paths
        let dbURL = getDatabaseURL(for: linkId)

        // Remove existing DB if it exists (re-ingestion)
        if fileManager.fileExists(atPath: dbURL.path) {
            try fileManager.removeItem(at: dbURL)
        }

        // 2. Initialize Database
        try await databaseManager.initializeDatabase(at: dbURL)

        // 3. Ingest Raw Data
        if let rawData = rawTsv, !rawData.isEmpty {
            try await ingestTable(tableName: "raw_data", content: rawData)
        }

        // 4. Ingest Processed Data
        if let processedData = processedTsv, !processedData.isEmpty {
            try await ingestTable(tableName: "processed_data", content: processedData)
        }

        // 5. Ingest Metadata Maps from extraData
        if let extraData = extraData {
            // A. UniProt maps
            if let uniprot = extraData["uniprot"] as? [String: Any] {
                if let db = uniprot["db"] as? [String: Any] {
                    // UniProt DB contains rich data, keep as JSON/Struct
                    try await ingestJSONMap(tableName: "uniprot_db", map: db)

                    // Create a flattened gene name lookup table from uniprot_db
                    let createFlattenedSQL = """
                    CREATE TABLE uniprot_gene_names AS
                    SELECT DISTINCT trim(unnest(string_split(replace(value."Gene Names", ' ', ';'), ';'))) as gene_name, key as accession
                    FROM uniprot_db
                    WHERE value."Gene Names" IS NOT NULL;
                    """
                    print("DEBUG: Creating uniprot_gene_names...")
                    _ = try await databaseManager.executeQuery(createFlattenedSQL)
                    print("DEBUG: uniprot_gene_names created.")
                    _ = try await databaseManager.executeQuery("CREATE INDEX idx_uniprot_gene_names_gene ON uniprot_gene_names(gene_name)")
                }
                if let geneNameToAcc = uniprot["geneNameToAcc"] as? [String: Any] {
                    try await ingestJSONMap(tableName: "gene_name_to_acc", map: geneNameToAcc)
                }
                if let accMap = uniprot["accMap"] as? [String: Any] {
                    try await ingestJSONMap(tableName: "acc_map", map: accMap)
                }
            }

            // B. Dataset maps
            if let data = extraData["data"] as? [String: Any] {
                if let primaryIDsmap = data["primaryIDsmap"] as? [String: Any] {
                    try await ingestJSONMap(tableName: "primary_ids_map", map: primaryIDsmap)
                }
                if let genesMap = data["genesMap"] as? [String: Any] {
                    try await ingestJSONMap(tableName: "genes_map", map: genesMap)
                }
            }
        }

        // 6. Create Indices for all maps
        let tables = ["uniprot_db", "gene_name_to_acc", "acc_map", "primary_ids_map", "genes_map"]
        for table in tables {
            // We ignore errors here in case some tables weren't created due to missing data
            try? await databaseManager.executeQuery("CREATE INDEX IF NOT EXISTS idx_\(table)_key ON \(table)(key)")
        }

        print("Ingestion complete for \(linkId). DB at: \(dbURL.path)")

        // Close DB connection after ingestion is done
        await databaseManager.closeDatabase()

        return dbURL
    }

    // MARK: - Private Helpers

    /// Ingests rich object maps (like Uniprot DB) which are Map serializations.
    /// Structure: { "dataType": "Map", "value": [ ["Key", {RichObject}], ... ] }
    private func ingestJSONMap(tableName: String, map: [String: Any]) async throws {
        // Only handle Map serialization
        guard map["dataType"] as? String == "Map",
              let entries = map["value"] as? [[Any]] else {
            return
        }

        guard !entries.isEmpty else { return }

        // Convert to JSON lines: key, value (json string)
        let jsonLines = entries.compactMap { entry -> String? in
            guard entry.count >= 2, let key = entry[0] as? String else { return nil }
            let valueObj = entry[1]
            let record: [String: Any] = ["key": key, "value": valueObj]
            guard let data = try? JSONSerialization.data(withJSONObject: record),
                  let str = String(data: data, encoding: .utf8) else { return nil }
            return str
        }.joined(separator: "\n")

        let tempURL = fileManager.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).jsonl")
        try jsonLines.write(to: tempURL, atomically: true, encoding: .utf8)

        let sql = "CREATE TABLE IF NOT EXISTS \(tableName) AS SELECT * FROM read_json_auto('\(tempURL.path)');"

        _ = try await databaseManager.executeQuery(sql)

        try? fileManager.removeItem(at: tempURL)
    }

    /// Ingests Standard Dictionaries where value is a Set-like Map.
    /// Structure: { "Key": { "TargetID": true, ... }, ... }
    /// Flattens to: Key -> target_id rows
    private func ingestFlattenedMap(tableName: String, map: [String: Any]) async throws {
        // Handle Standard Dictionary
        // If it happens to be a Map serialization, extract it first
        let entries: [[Any]]
        if map["dataType"] as? String == "Map", let values = map["value"] as? [[Any]] {
            entries = values
        } else {
            entries = map.map { [$0.key, $0.value] }
        }

        guard !entries.isEmpty else { return }

        var csvLines = ["key\ttarget_id"]

        for entry in entries {
            guard entry.count >= 2, let key = entry[0] as? String else { continue }

            // Expected value: { "TargetID": true }
            if let valueMap = entry[1] as? [String: Any] {
                for (target, _) in valueMap {
                    csvLines.append("\(key)\t\(target)")
                }
            } else if let target = entry[1] as? String {
                // Direct mapping case
                csvLines.append("\(key)\t\(target)")
            }
        }

        let csvContent = csvLines.joined(separator: "\n")
        let tempURL = fileManager.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).tsv")

        do {
            try csvContent.write(to: tempURL, atomically: true, encoding: .utf8)
            let sql = "CREATE TABLE IF NOT EXISTS \(tableName) AS SELECT * FROM read_csv('\(tempURL.path)', DELIM='\t', HEADER=TRUE, COLUMNS={'key': 'VARCHAR', 'target_id': 'VARCHAR'});"

            _ = try await databaseManager.executeQuery(sql)

            try? fileManager.removeItem(at: tempURL)
        } catch {
            try? fileManager.removeItem(at: tempURL)
            throw error
        }
    }

    private func getDatabaseURL(for linkId: String) -> URL {
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let curtainDataDir = documentsPath.appendingPathComponent("CurtainData", isDirectory: true)

        // Ensure directory exists
        try? fileManager.createDirectory(at: curtainDataDir, withIntermediateDirectories: true)

        return curtainDataDir.appendingPathComponent("\(linkId).duckdb")
    }

    private func ingestTable(tableName: String, content: String) async throws {
        // 1. Write content to a temporary file (generic extension to avoid biasing detection)
        let tempURL = fileManager.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).txt")

        do {
            try content.write(to: tempURL, atomically: true, encoding: .utf8)

            // 2. Execute DuckDB COPY/CREATE command
            // read_csv_auto automatically detects delimiter (comma, tab, pipe, etc.) and types
            // We do not specify DELIM so DuckDB can sniff it from the content
            let sql = "CREATE TABLE \(tableName) AS SELECT * FROM read_csv_auto('\(tempURL.path)', HEADER=TRUE, SAMPLE_SIZE=-1);"

            _ = try await databaseManager.executeQuery(sql)

            // 3. Cleanup temp file
            try fileManager.removeItem(at: tempURL)

        } catch {
            // Ensure temp file is cleaned up even on error
            try? fileManager.removeItem(at: tempURL)
            throw error
        }
    }
}
#endif

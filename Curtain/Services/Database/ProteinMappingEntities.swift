//
//  ProteinMappingEntities.swift
//  Curtain
//
//  Denormalized mapping tables for fast gene name and ID lookups
//  Matches Android's ProteinMappingDatabase structure
//

import Foundation
import GRDB

// MARK: - GeneNameMapping
// Maps all gene name variants to primaryIds for fast lookup
// Denormalized: One gene name can map to multiple primaryIds

struct GeneNameMapping: Codable, FetchableRecord, PersistableRecord {
    var geneName: String
    var primaryId: String

    static let databaseTableName = "gene_name_mapping"

    enum Columns: String, ColumnExpression {
        case geneName, primaryId
    }
}

extension GeneNameMapping {
    static func createTable(in db: Database) throws {
        try db.create(table: databaseTableName, ifNotExists: true) { t in
            t.column("geneName", .text).notNull()
            t.column("primaryId", .text).notNull()
            t.primaryKey(["geneName", "primaryId"])
        }

        try db.create(index: "idx_gene_name_mapping_gene", on: databaseTableName, columns: ["geneName"], ifNotExists: true)
        try db.create(index: "idx_gene_name_mapping_primary", on: databaseTableName, columns: ["primaryId"], ifNotExists: true)
    }
}

// MARK: - PrimaryIdMapping
// Maps all split IDs and aliases to canonical primaryIds
// For IDs like "P38398;Q6UXY8", creates mappings for each split ID

struct PrimaryIdMapping: Codable, FetchableRecord, PersistableRecord {
    var splitId: String
    var primaryId: String

    static let databaseTableName = "primary_id_mapping"

    enum Columns: String, ColumnExpression {
        case splitId, primaryId
    }
}

extension PrimaryIdMapping {
    static func createTable(in db: Database) throws {
        try db.create(table: databaseTableName, ifNotExists: true) { t in
            t.column("splitId", .text).notNull()
            t.column("primaryId", .text).notNull()
            t.primaryKey(["splitId", "primaryId"])
        }

        try db.create(index: "idx_primary_id_mapping_split", on: databaseTableName, columns: ["splitId"], ifNotExists: true)
    }
}

// MARK: - ProteinMappingMetadata
// Schema version tracking for mapping tables

struct ProteinMappingMetadata: Codable, FetchableRecord, PersistableRecord {
    var key: String
    var value: String

    static let databaseTableName = "protein_mapping_metadata"
}

extension ProteinMappingMetadata {
    static func createTable(in db: Database) throws {
        try db.create(table: databaseTableName, ifNotExists: true) { t in
            t.primaryKey("key", .text)
            t.column("value", .text).notNull()
        }
    }
}

//
//  ProteomicsEntities.swift
//  Curtain
//
//  SQLite entity definitions matching Android Room entities
//

import Foundation
import GRDB

// MARK: - ProcessedProteomicsData
// Stores differential/processed proteomics data for volcano plots

struct ProcessedProteomicsData: Codable, FetchableRecord, MutablePersistableRecord {
    var id: Int64?
    var primaryId: String
    var geneNames: String?
    var foldChange: Double?
    var significant: Double?
    var comparison: String
    // PTM-specific fields
    var accession: String?
    var position: String?
    var positionPeptide: String?
    var peptideSequence: String?
    var score: Double?

    static let databaseTableName = "processed_proteomics_data"

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

extension ProcessedProteomicsData {
    static func createTable(in db: Database) throws {
        try db.create(table: databaseTableName, ifNotExists: true) { t in
            t.autoIncrementedPrimaryKey("id")
            t.column("primaryId", .text).notNull()
            t.column("geneNames", .text)
            t.column("foldChange", .double)
            t.column("significant", .double)
            t.column("comparison", .text).notNull()
            // PTM-specific columns
            t.column("accession", .text)
            t.column("position", .text)
            t.column("positionPeptide", .text)
            t.column("peptideSequence", .text)
            t.column("score", .double)
            t.uniqueKey(["primaryId", "comparison"])
        }

        try db.create(index: "idx_processed_primaryId", on: databaseTableName, columns: ["primaryId"], ifNotExists: true)
        try db.create(index: "idx_processed_comparison", on: databaseTableName, columns: ["comparison"], ifNotExists: true)
        try db.create(index: "idx_processed_accession", on: databaseTableName, columns: ["accession"], ifNotExists: true)
    }
}

// MARK: - RawProteomicsData
// Stores raw sample values for bar charts and violin plots

struct RawProteomicsData: Codable, FetchableRecord, MutablePersistableRecord {
    var id: Int64?
    var primaryId: String
    var sampleName: String
    var sampleValue: Double?

    static let databaseTableName = "raw_proteomics_data"

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

extension RawProteomicsData {
    static func createTable(in db: Database) throws {
        try db.create(table: databaseTableName, ifNotExists: true) { t in
            t.autoIncrementedPrimaryKey("id")
            t.column("primaryId", .text).notNull()
            t.column("sampleName", .text).notNull()
            t.column("sampleValue", .double)
            t.uniqueKey(["primaryId", "sampleName"])
        }

        try db.create(index: "idx_raw_primaryId", on: databaseTableName, columns: ["primaryId"], ifNotExists: true)
        try db.create(index: "idx_raw_sampleName", on: databaseTableName, columns: ["sampleName"], ifNotExists: true)
    }
}

// MARK: - ProteomicsDataMetadata
// Key-value metadata storage (e.g., schema version)

struct ProteomicsDataMetadata: Codable, FetchableRecord, PersistableRecord {
    var key: String
    var value: String

    static let databaseTableName = "proteomics_data_metadata"
}

extension ProteomicsDataMetadata {
    static func createTable(in db: Database) throws {
        try db.create(table: databaseTableName, ifNotExists: true) { t in
            t.primaryKey("key", .text)
            t.column("value", .text).notNull()
        }
    }
}

// MARK: - CurtainMetadata
// Stores all curtain settings, forms, and selections as JSON

struct CurtainMetadata: Codable, FetchableRecord, PersistableRecord {
    var id: Int = 1
    var settingsJson: String
    var rawFormJson: String
    var differentialFormJson: String
    var selectionsJson: String?
    var selectionsMapJson: String?
    var selectedMapJson: String?
    var selectionsNameJson: String?
    var extraDataJson: String?
    var annotatedDataJson: String?
    var password: String
    var fetchUniprot: Bool
    var permanent: Bool
    var bypassUniProt: Bool

    static let databaseTableName = "curtain_metadata"
}

extension CurtainMetadata {
    static func createTable(in db: Database) throws {
        try db.create(table: databaseTableName, ifNotExists: true) { t in
            t.primaryKey("id", .integer)
            t.column("settingsJson", .text).notNull()
            t.column("rawFormJson", .text).notNull()
            t.column("differentialFormJson", .text).notNull()
            t.column("selectionsJson", .text)
            t.column("selectionsMapJson", .text)
            t.column("selectedMapJson", .text)
            t.column("selectionsNameJson", .text)
            t.column("extraDataJson", .text)
            t.column("annotatedDataJson", .text)
            t.column("password", .text).notNull().defaults(to: "")
            t.column("fetchUniprot", .boolean).notNull().defaults(to: true)
            t.column("permanent", .boolean).notNull().defaults(to: false)
            t.column("bypassUniProt", .boolean).notNull().defaults(to: false)
        }
    }
}

// MARK: - GenesMapEntry
// Maps gene identifiers to data (JSON value)

struct GenesMapEntry: Codable, FetchableRecord, PersistableRecord {
    var key: String
    var value: String

    static let databaseTableName = "genes_map"
}

extension GenesMapEntry {
    static func createTable(in db: Database) throws {
        try db.create(table: databaseTableName, ifNotExists: true) { t in
            t.primaryKey("key", .text)
            t.column("value", .text).notNull()
        }
    }
}

// MARK: - PrimaryIdsMapEntry
// Maps primary IDs to data (JSON value)

struct PrimaryIdsMapEntry: Codable, FetchableRecord, PersistableRecord {
    var primaryId: String
    var value: String

    static let databaseTableName = "primary_ids_map"

    enum Columns: String, ColumnExpression {
        case primaryId, value
    }
}

extension PrimaryIdsMapEntry {
    static func createTable(in db: Database) throws {
        try db.create(table: databaseTableName, ifNotExists: true) { t in
            t.primaryKey("primaryId", .text)
            t.column("value", .text).notNull()
        }
    }
}

// MARK: - GeneNameToAccEntry
// Maps gene names to accession numbers

struct GeneNameToAccEntry: Codable, FetchableRecord, PersistableRecord {
    var geneName: String
    var accession: String

    static let databaseTableName = "gene_name_to_acc"
}

extension GeneNameToAccEntry {
    static func createTable(in db: Database) throws {
        try db.create(table: databaseTableName, ifNotExists: true) { t in
            t.primaryKey("geneName", .text)
            t.column("accession", .text).notNull()
        }

        try db.create(index: "idx_gene_name_to_acc_gene", on: databaseTableName, columns: ["geneName"], ifNotExists: true)
    }
}

// MARK: - AllGenesEntry
// Stores all unique gene names for autocomplete

struct AllGenesEntry: Codable, FetchableRecord, MutablePersistableRecord {
    var id: Int64?
    var geneName: String

    static let databaseTableName = "all_genes"

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

extension AllGenesEntry {
    static func createTable(in db: Database) throws {
        try db.create(table: databaseTableName, ifNotExists: true) { t in
            t.autoIncrementedPrimaryKey("id")
            t.column("geneName", .text).notNull().unique()
        }

        try db.create(index: "idx_all_genes_name", on: databaseTableName, columns: ["geneName"], ifNotExists: true)
    }
}

// MARK: - UniProtDBEntry
// Stores UniProt database entries (accession -> JSON data)

struct UniProtDBEntry: Codable, FetchableRecord, PersistableRecord {
    var accession: String  // Primary key (e.g., "P12345")
    var dataJson: String   // Full UniProt data as JSON

    static let databaseTableName = "uniprot_db"
}

extension UniProtDBEntry {
    static func createTable(in db: Database) throws {
        try db.create(table: databaseTableName, ifNotExists: true) { t in
            t.primaryKey("accession", .text)
            t.column("dataJson", .text).notNull()
        }

        try db.create(index: "idx_uniprot_db_accession", on: databaseTableName, columns: ["accession"], ifNotExists: true)
    }
}

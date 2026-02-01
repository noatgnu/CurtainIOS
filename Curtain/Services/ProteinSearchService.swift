//
//  ProteinSearchService.swift
//  Curtain
//
//  Created by Toan Phung on 04/08/2025.
//

import Foundation
import GRDB

enum SearchType: String, CaseIterable {
    case primaryID = "PRIMARY_ID"
    case geneName = "GENE_NAME"
    case accessionID = "ACCESSION_ID"
    
    var displayName: String {
        switch self {
        case .primaryID: return "Primary ID"
        case .geneName: return "Gene Name"
        case .accessionID: return "Accession ID"
        }
    }
}

struct TypeaheadSuggestion {
    let text: String
    let searchType: SearchType
    let matchType: String // "exact" or "partial"
    let resultCount: Int
}

struct SearchResult {
    let searchTerm: String
    let matchedProteins: [String] // Primary IDs
    let searchType: SearchType
    let isExactMatch: Bool
}

struct SearchList {
    let id: String
    let name: String
    let proteinIds: Set<String>
    let searchTerms: [String]
    let searchType: SearchType
    let color: String
    let description: String?
    let timestamp: Foundation.Date
    
    init(id: String = UUID().uuidString, name: String, proteinIds: Set<String>, searchTerms: [String] = [], searchType: SearchType = .primaryID, color: String, description: String? = nil, timestamp: Foundation.Date = Foundation.Date()) {
        self.id = id
        self.name = name
        self.proteinIds = proteinIds
        self.searchTerms = searchTerms
        self.searchType = searchType
        self.color = color
        self.description = description
        self.timestamp = timestamp
    }
}


class ProteinSearchService {
    private let proteomicsDataDatabaseManager = ProteomicsDataDatabaseManager.shared
    private let proteinMappingService = ProteinMappingService.shared

    // MARK: - Core Search Functionality

    func performTypeaheadSearch(
        query: String,
        searchType: SearchType,
        curtainData: CurtainData,
        limit: Int = 10
    ) async -> [TypeaheadSuggestion] {
        // Database-based search disabled for now, using in-memory fallback
        guard query.count >= 2 else { return [] }
        
        let queryLower = query.lowercased()
        var suggestions: [TypeaheadSuggestion] = []
        
        switch searchType {
        case .primaryID:
            suggestions = await searchPrimaryIDSuggestions(queryLower: queryLower, curtainData: curtainData, limit: limit)
        case .geneName:
            suggestions = await searchGeneNameSuggestions(queryLower: queryLower, curtainData: curtainData, limit: limit)
        case .accessionID:
            suggestions = await searchAccessionIDSuggestions(queryLower: queryLower, curtainData: curtainData, limit: limit)
        }
        
        return Array(suggestions.prefix(limit))
    }

    /// GRDB-based typeahead search
    func performTypeaheadSearch(
        query: String,
        searchType: SearchType,
        linkId: String,
        idColumn: String = "Index",
        geneColumn: String = "Gene Names",
        limit: Int = 10
    ) async -> [TypeaheadSuggestion] {
        guard query.count >= 2, !linkId.isEmpty else { return [] }

        do {
            let db = try proteomicsDataDatabaseManager.getDatabaseForLinkId(linkId)
            let queryUpper = query.uppercased()
            let likePattern = "%\(queryUpper)%"

            return try await db.read { database in
                var suggestions: [TypeaheadSuggestion] = []

                switch searchType {
                case .primaryID, .accessionID:
                    // Search in processed_proteomics_data primaryId column
                    let sql = """
                        SELECT DISTINCT primaryId FROM \(ProcessedProteomicsData.databaseTableName)
                        WHERE UPPER(primaryId) LIKE ?
                        LIMIT ?
                    """
                    let rows = try Row.fetchAll(database, sql: sql, arguments: [likePattern, limit])
                    for row in rows {
                        let primaryId: String = row["primaryId"]
                        suggestions.append(TypeaheadSuggestion(
                            text: primaryId,
                            searchType: searchType,
                            matchType: primaryId.uppercased() == queryUpper ? "exact" : "partial",
                            resultCount: 1
                        ))
                    }

                case .geneName:
                    // Search in all_genes table first
                    let genesSql = """
                        SELECT geneName FROM \(AllGenesEntry.databaseTableName)
                        WHERE UPPER(geneName) LIKE ?
                        LIMIT ?
                    """
                    let geneRows = try Row.fetchAll(database, sql: genesSql, arguments: [likePattern, limit])
                    for row in geneRows {
                        let geneName: String = row["geneName"]
                        suggestions.append(TypeaheadSuggestion(
                            text: geneName,
                            searchType: .geneName,
                            matchType: geneName.uppercased() == queryUpper ? "exact" : "partial",
                            resultCount: 1
                        ))
                    }

                    // Also search in processed_proteomics_data geneNames column
                    if suggestions.count < limit {
                        let processedSql = """
                            SELECT DISTINCT geneNames FROM \(ProcessedProteomicsData.databaseTableName)
                            WHERE geneNames IS NOT NULL AND UPPER(geneNames) LIKE ?
                            LIMIT ?
                        """
                        let processedRows = try Row.fetchAll(database, sql: processedSql, arguments: [likePattern, limit - suggestions.count])
                        for row in processedRows {
                            if let geneName: String = row["geneNames"] {
                                // Avoid duplicates
                                if !suggestions.contains(where: { $0.text.uppercased() == geneName.uppercased() }) {
                                    suggestions.append(TypeaheadSuggestion(
                                        text: geneName,
                                        searchType: .geneName,
                                        matchType: geneName.uppercased() == queryUpper ? "exact" : "partial",
                                        resultCount: 1
                                    ))
                                }
                            }
                        }
                    }
                }

                return Array(suggestions.prefix(limit))
            }
        } catch {
            print("[ProteinSearchService] Typeahead search error: \(error)")
            return []
        }
    }

    func performBatchSearch(
        inputText: String,
        searchType: SearchType,
        curtainData: CurtainData,
        useRegex: Bool = false
    ) async -> [SearchResult] {
        // Use in-memory search (database-based search disabled for now)
        let processedInput = processBatchSearchInput(inputText: inputText)
        var results: [SearchResult] = []
        
        for (originalLine, searchTerms) in processedInput {
            var allMatchedProteins: Set<String> = []
            
            if useRegex {
                // In Regex mode, the original line is the pattern
                let pattern = originalLine.trimmingCharacters(in: .whitespacesAndNewlines)
                if !pattern.isEmpty {
                    let proteins = await performRegexSearch(
                        pattern: pattern,
                        searchType: searchType,
                        curtainData: curtainData
                    )
                    allMatchedProteins.formUnion(proteins)
                }
            } else {
                // Normal mode: Replicating getPrimaryIDsDataFromBatch logic
                // 1. Try exact match on whole line
                let exactMatches = parseData(curtainData: curtainData, term: originalLine, searchType: searchType, exact: true)
                allMatchedProteins.formUnion(exactMatches)
                
                // 2. If no exact match on whole line, try parts inexactly
                if exactMatches.isEmpty {
                    for searchTerm in searchTerms {
                        let proteins = parseData(curtainData: curtainData, term: searchTerm, searchType: searchType, exact: false)
                        allMatchedProteins.formUnion(proteins)
                    }
                }
            }
            
            if !allMatchedProteins.isEmpty {
                results.append(SearchResult(
                    searchTerm: originalLine,
                    matchedProteins: Array(allMatchedProteins),
                    searchType: searchType,
                    isExactMatch: !useRegex
                ))
            }
        }
        
        return results
    }

    /// GRDB-based batch search using ProteinMappingService (matches Android IDMappingService flow)
    /// All search terms are resolved to dataset primary IDs via the mapping tables.
    func performBatchSearch(
        inputText: String,
        searchType: SearchType,
        linkId: String,
        idColumn: String = "Index",
        geneColumn: String = "Gene Names",
        useRegex: Bool = false
    ) async -> [SearchResult] {
        guard !linkId.isEmpty else { return [] }

        let processedInput = processBatchSearchInput(inputText: inputText)
        var results: [SearchResult] = []

        for (originalLine, searchTerms) in processedInput {
            var allMatchedProteins: Set<String> = []

            if useRegex {
                let pattern = originalLine.trimmingCharacters(in: .whitespacesAndNewlines)
                if !pattern.isEmpty {
                    let proteins = await performRegexSearch(
                        pattern: pattern,
                        searchType: searchType,
                        linkId: linkId,
                        idColumn: idColumn,
                        geneColumn: geneColumn
                    )
                    allMatchedProteins.formUnion(proteins)
                }
            } else {
                // Use ProteinMappingService to resolve terms to primary IDs
                // This matches Android's IDMappingService.batchSearchProteins flow
                let allTerms = [originalLine] + searchTerms.filter { $0 != originalLine.uppercased() }

                for term in allTerms {
                    let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
                    if trimmed.isEmpty { continue }

                    let primaryIds: [String]
                    switch searchType {
                    case .geneName:
                        primaryIds = proteinMappingService.getPrimaryIdsFromGeneName(linkId: linkId, geneName: trimmed)
                    case .primaryID, .accessionID:
                        primaryIds = proteinMappingService.getPrimaryIdsFromSplitId(linkId: linkId, splitId: trimmed)
                    }

                    allMatchedProteins.formUnion(primaryIds)

                    // If we found matches on the full line, skip individual parts
                    if !primaryIds.isEmpty && term == originalLine {
                        break
                    }
                }
            }

            if !allMatchedProteins.isEmpty {
                results.append(SearchResult(
                    searchTerm: originalLine,
                    matchedProteins: Array(allMatchedProteins),
                    searchType: searchType,
                    isExactMatch: !useRegex
                ))
            }
        }

        return results
    }

    /// GRDB-based partial search (LIKE query)
    private func performPartialSearch(
        searchTerm: String,
        searchType: SearchType,
        linkId: String
    ) async -> [String] {
        guard !linkId.isEmpty, !searchTerm.isEmpty else { return [] }

        do {
            let db = try proteomicsDataDatabaseManager.getDatabaseForLinkId(linkId)
            let termUpper = searchTerm.uppercased()
            let likePattern = "%\(termUpper)%"

            return try await db.read { database in
                var results: Set<String> = []

                switch searchType {
                case .geneName:
                    // Search genes_map table
                    let genesSql = """
                        SELECT value FROM \(GenesMapEntry.databaseTableName)
                        WHERE UPPER(key) LIKE ?
                    """
                    let rows = try Row.fetchAll(database, sql: genesSql, arguments: [likePattern])
                    for row in rows {
                        if let jsonValue: String = row["value"],
                           let data = jsonValue.data(using: .utf8),
                           let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                            for key in dict.keys {
                                results.insert(key)
                            }
                        }
                    }

                case .primaryID, .accessionID:
                    // Search primary_ids_map table
                    let idsSql = """
                        SELECT value FROM \(PrimaryIdsMapEntry.databaseTableName)
                        WHERE UPPER(primaryId) LIKE ?
                    """
                    let rows = try Row.fetchAll(database, sql: idsSql, arguments: [likePattern])
                    for row in rows {
                        if let jsonValue: String = row["value"],
                           let data = jsonValue.data(using: .utf8),
                           let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                            for key in dict.keys {
                                results.insert(key)
                            }
                        }
                    }
                }

                return Array(results)
            }
        } catch {
            print("[ProteinSearchService] Partial search error: \(error)")
            return []
        }
    }

    /// GRDB-based batch exact lookup
    private func performBatchExactLookup(
        terms: [String],
        searchType: SearchType,
        linkId: String,
        idColumn: String = "Index",
        geneColumn: String = "Gene Names"
    ) async -> [String: Set<String>] {
        guard !linkId.isEmpty, !terms.isEmpty else { return [:] }

        do {
            let db = try proteomicsDataDatabaseManager.getDatabaseForLinkId(linkId)

            return try await db.read { database in
                var results: [String: Set<String>] = [:]

                for term in terms {
                    let termUpper = term.uppercased()
                    var matches: Set<String> = []

                    switch searchType {
                    case .geneName:
                        // Exact lookup in genes_map
                        let sql = "SELECT value FROM \(GenesMapEntry.databaseTableName) WHERE UPPER(key) = ?"
                        if let row = try Row.fetchOne(database, sql: sql, arguments: [termUpper]),
                           let jsonValue: String = row["value"],
                           let data = jsonValue.data(using: .utf8),
                           let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                            for key in dict.keys {
                                matches.insert(key)
                            }
                        }

                        // Also check gene_name_to_acc
                        let accSql = "SELECT accession FROM \(GeneNameToAccEntry.databaseTableName) WHERE UPPER(geneName) = ?"
                        let accRows = try Row.fetchAll(database, sql: accSql, arguments: [termUpper])
                        for row in accRows {
                            if let accession: String = row["accession"] {
                                // Look up primaryId from accession
                                let primarySql = "SELECT value FROM \(PrimaryIdsMapEntry.databaseTableName) WHERE UPPER(primaryId) = ?"
                                if let primaryRow = try Row.fetchOne(database, sql: primarySql, arguments: [accession.uppercased()]),
                                   let jsonValue: String = primaryRow["value"],
                                   let data = jsonValue.data(using: .utf8),
                                   let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                                    for key in dict.keys {
                                        matches.insert(key)
                                    }
                                }
                            }
                        }

                    case .primaryID, .accessionID:
                        // Exact lookup in primary_ids_map
                        let sql = "SELECT value FROM \(PrimaryIdsMapEntry.databaseTableName) WHERE UPPER(primaryId) = ?"
                        if let row = try Row.fetchOne(database, sql: sql, arguments: [termUpper]),
                           let jsonValue: String = row["value"],
                           let data = jsonValue.data(using: .utf8),
                           let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                            for key in dict.keys {
                                matches.insert(key)
                            }
                        }
                    }

                    if !matches.isEmpty {
                        results[term] = matches
                    }
                }

                return results
            }
        } catch {
            print("[ProteinSearchService] Batch lookup error: \(error)")
            return [:]
        }
    }
    
    // MARK: - Internal Lookup Helpers (Angular Logic)

    private func parseData(curtainData: CurtainData, term: String, searchType: SearchType, exact: Bool) -> [String] {
        let cleanTerm = term.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if cleanTerm.isEmpty { return [] }

        switch searchType {
        case .geneName:
            if exact {
                return getPrimaryIDsFromGeneNames(geneNames: cleanTerm, curtainData: curtainData)
            } else {
                if let genesMap = curtainData.extraData?.data?.genesMap,
                   let subMap = genesMap[cleanTerm] {
                    var result: Set<String> = []
                    for m in subMap.keys {
                        let res = getPrimaryIDsFromGeneNames(geneNames: m, curtainData: curtainData)
                        for r in res {
                            result.insert(r)
                        }
                    }
                    return Array(result)
                }
            }
        case .primaryID, .accessionID:
            if exact {
                return getPrimaryIDsFromAcc(primaryIDs: cleanTerm, curtainData: curtainData)
            } else {
                if let primaryIDsMap = curtainData.extraData?.data?.primaryIDsMap,
                   let subMap = primaryIDsMap[cleanTerm] {
                    var result: Set<String> = []
                    for m in subMap.keys {
                        let res = getPrimaryIDsFromAcc(primaryIDs: m, curtainData: curtainData)
                        for r in res {
                            result.insert(r)
                        }
                    }
                    return Array(result)
                }
            }
        }
        return []
    }

    private func getPrimaryIDsFromGeneNames(geneNames: String, curtainData: CurtainData) -> [String] {
        var result: Set<String> = []
        let cleanGene = geneNames.uppercased()
        
        // 1. Lookup in UniProt geneNameToAcc
        if let geneNameToAcc = curtainData.extraData?.uniprot?.geneNameToAcc,
           let accessions = geneNameToAcc[cleanGene] {
            
            for a in accessions.keys {
                // 2. Lookup in primaryIDsMap
                if let primaryIDsMap = curtainData.extraData?.data?.primaryIDsMap,
                   let datasetIds = primaryIDsMap[a] {
                    
                    for acc in datasetIds.keys {
                        if !result.contains(acc) {
                            if curtainData.fetchUniprot {
                                // 3. Check UniProt DB for gene names inclusion
                                if let uniprotDB = curtainData.extraData?.uniprot?.db,
                                   let record = uniprotDB[acc] as? [String: Any],
                                   let recordGeneNames = record["Gene Names"] as? String {
                                    if recordGeneNames.uppercased().contains(cleanGene) {
                                        result.insert(acc)
                                    }
                                }
                            } else {
                                result.insert(acc)
                            }
                        }
                    }
                }
            }
        }
        return Array(result)
    }

    private func getPrimaryIDsFromAcc(primaryIDs: String, curtainData: CurtainData) -> [String] {
        var result: [String] = []
        let cleanId = primaryIDs.uppercased()
        
        if let primaryIDsMap = curtainData.extraData?.data?.primaryIDsMap,
           let subMap = primaryIDsMap[cleanId] {
            for acc in subMap.keys {
                if !result.contains(acc) {
                    result.append(acc)
                }
            }
        }
        return result
    }

    // MARK: - Regex Search

    func performRegexSearch(
        pattern: String,
        searchType: SearchType,
        curtainData: CurtainData
    ) async -> [String] {
        // Use DuckDB if available
        if let dbPath = curtainData.dbPath {
            let linkId = dbPath.lastPathComponent.replacingOccurrences(of: ".sqlite", with: "")
            let idColumn = curtainData.differentialForm.primaryIDs
            let geneColumn = curtainData.differentialForm.geneNames
            return await performRegexSearch(pattern: pattern, searchType: searchType, linkId: linkId, idColumn: idColumn, geneColumn: geneColumn)
        }
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return []
        }
        
        var matchedIds: Set<String> = []
        
        // Helper to check match
        let checkMatch: (String) -> Bool = { text in
            let range = NSRange(location: 0, length: text.utf16.count)
            return regex.firstMatch(in: text, options: [], range: range) != nil
        }
        
        switch searchType {
        case .primaryID, .accessionID:
            // Search in ID column
            let ids = getAvailableProteinIds(curtainData: curtainData)
            for id in ids {
                if checkMatch(id) {
                    matchedIds.insert(id)
                }
            }
            
        case .geneName:
            // Search in Gene Names
            // 1. UniProt
            if let uniprotDB = curtainData.extraData?.uniprot?.db {
                for (id, record) in uniprotDB {
                    if let recordDict = record as? [String: Any],
                       let geneNamesString = recordDict["Gene Names"] as? String {
                        let genes = geneNamesString.components(separatedBy: CharacterSet(charactersIn: " ;")).filter { !$0.isEmpty }
                        for gene in genes {
                            if checkMatch(gene) {
                                matchedIds.insert(id)
                                break 
                            }
                        }
                    }
                }
            }
            
            // 2. Dataset Gene Column
            let availableIds = getAvailableProteinIds(curtainData: curtainData)
            if let dataMap = curtainData.selectionsMap { // Use dataMap/selectionsMap for dataset columns
                let geneColumn = curtainData.differentialForm.geneNames
                if !geneColumn.isEmpty {
                    for id in availableIds {
                        if let row = dataMap[id] as? [String: Any],
                           let geneStr = row[geneColumn] as? String {
                            let genes = geneStr.components(separatedBy: ";").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                            for gene in genes {
                                if checkMatch(gene) {
                                    matchedIds.insert(id)
                                    break
                                }
                            }
                        }
                    }
                }
            }
        }
        
        return Array(matchedIds)
    }

    /// GRDB-based regex search using GLOB pattern
    func performRegexSearch(
        pattern: String,
        searchType: SearchType,
        linkId: String,
        idColumn: String = "Index",
        geneColumn: String = "Gene Names"
    ) async -> [String] {
        guard !linkId.isEmpty, !pattern.isEmpty else { return [] }

        // Convert regex pattern to SQL LIKE pattern (simplified)
        // For complex regex, we'll fetch all and filter in Swift
        do {
            let db = try proteomicsDataDatabaseManager.getDatabaseForLinkId(linkId)
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
                return []
            }

            return try await db.read { database in
                var matchedIds: Set<String> = []

                let checkMatch: (String) -> Bool = { text in
                    let range = NSRange(location: 0, length: text.utf16.count)
                    return regex.firstMatch(in: text, options: [], range: range) != nil
                }

                switch searchType {
                case .primaryID, .accessionID:
                    // Search in processed_proteomics_data primaryId column
                    let sql = "SELECT DISTINCT primaryId FROM \(ProcessedProteomicsData.databaseTableName)"
                    let rows = try Row.fetchAll(database, sql: sql)
                    for row in rows {
                        let primaryId: String = row["primaryId"]
                        if checkMatch(primaryId) {
                            matchedIds.insert(primaryId)
                        }
                    }

                case .geneName:
                    // Search in all_genes table
                    let genesSql = "SELECT geneName FROM \(AllGenesEntry.databaseTableName)"
                    let geneRows = try Row.fetchAll(database, sql: genesSql)
                    for row in geneRows {
                        let geneName: String = row["geneName"]
                        if checkMatch(geneName) {
                            // Find proteins with this gene name
                            let lookupSql = "SELECT primaryId FROM \(ProcessedProteomicsData.databaseTableName) WHERE UPPER(geneNames) LIKE ?"
                            let likePattern = "%\(geneName.uppercased())%"
                            let lookupRows = try Row.fetchAll(database, sql: lookupSql, arguments: [likePattern])
                            for lookupRow in lookupRows {
                                let primaryId: String = lookupRow["primaryId"]
                                matchedIds.insert(primaryId)
                            }
                        }
                    }

                    // Also search in processed_proteomics_data geneNames
                    let processedSql = "SELECT DISTINCT primaryId, geneNames FROM \(ProcessedProteomicsData.databaseTableName) WHERE geneNames IS NOT NULL"
                    let processedRows = try Row.fetchAll(database, sql: processedSql)
                    for row in processedRows {
                        if let geneNames: String = row["geneNames"] {
                            // Split gene names and check each
                            let genes = geneNames.components(separatedBy: ";").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                            for gene in genes {
                                if checkMatch(gene) {
                                    let primaryId: String = row["primaryId"]
                                    matchedIds.insert(primaryId)
                                    break
                                }
                            }
                        }
                    }
                }

                return Array(matchedIds)
            }
        } catch {
            print("[ProteinSearchService] Regex search error: \(error)")
            return []
        }
    }

    func performExactSearch(
        searchTerm: String,
        searchType: SearchType,
        curtainData: CurtainData
    ) async -> [String] {
        // Use in-memory search (database-based search disabled for now)
        return parseData(curtainData: curtainData, term: searchTerm, searchType: searchType, exact: true)
    }

    /// GRDB-based exact search
    func performExactSearch(
        searchTerm: String,
        searchType: SearchType,
        linkId: String,
        idColumn: String = "Index",
        geneColumn: String = "Gene Names",
        useDatasetGeneColumn: Bool = false
    ) async -> [String] {
        guard !linkId.isEmpty, !searchTerm.isEmpty else { return [] }

        do {
            let db = try proteomicsDataDatabaseManager.getDatabaseForLinkId(linkId)
            let termUpper = searchTerm.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

            return try await db.read { database in
                var results: Set<String> = []

                switch searchType {
                case .geneName:
                    // 1. Exact lookup in genes_map
                    let genesSql = "SELECT value FROM \(GenesMapEntry.databaseTableName) WHERE UPPER(key) = ?"
                    if let row = try Row.fetchOne(database, sql: genesSql, arguments: [termUpper]),
                       let jsonValue: String = row["value"],
                       let data = jsonValue.data(using: .utf8),
                       let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        for key in dict.keys {
                            results.insert(key)
                        }
                    }

                    // 2. Lookup in gene_name_to_acc then primary_ids_map
                    let accSql = "SELECT accession FROM \(GeneNameToAccEntry.databaseTableName) WHERE UPPER(geneName) = ?"
                    let accRows = try Row.fetchAll(database, sql: accSql, arguments: [termUpper])
                    for accRow in accRows {
                        if let accession: String = accRow["accession"] {
                            let primarySql = "SELECT value FROM \(PrimaryIdsMapEntry.databaseTableName) WHERE UPPER(primaryId) = ?"
                            if let primaryRow = try Row.fetchOne(database, sql: primarySql, arguments: [accession.uppercased()]),
                               let jsonValue: String = primaryRow["value"],
                               let data = jsonValue.data(using: .utf8),
                               let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                                for key in dict.keys {
                                    results.insert(key)
                                }
                            }
                        }
                    }

                    // 3. Direct lookup in processed_proteomics_data geneNames column
                    if useDatasetGeneColumn {
                        let processedSql = "SELECT primaryId FROM \(ProcessedProteomicsData.databaseTableName) WHERE UPPER(geneNames) = ?"
                        let processedRows = try Row.fetchAll(database, sql: processedSql, arguments: [termUpper])
                        for row in processedRows {
                            let primaryId: String = row["primaryId"]
                            results.insert(primaryId)
                        }
                    }

                case .primaryID, .accessionID:
                    // 1. Exact lookup in primary_ids_map
                    let idsSql = "SELECT value FROM \(PrimaryIdsMapEntry.databaseTableName) WHERE UPPER(primaryId) = ?"
                    if let row = try Row.fetchOne(database, sql: idsSql, arguments: [termUpper]),
                       let jsonValue: String = row["value"],
                       let data = jsonValue.data(using: .utf8),
                       let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        for key in dict.keys {
                            results.insert(key)
                        }
                    }

                    // 2. Direct lookup in processed_proteomics_data
                    let processedSql = "SELECT primaryId FROM \(ProcessedProteomicsData.databaseTableName) WHERE UPPER(primaryId) = ?"
                    let processedRows = try Row.fetchAll(database, sql: processedSql, arguments: [termUpper])
                    for row in processedRows {
                        let primaryId: String = row["primaryId"]
                        results.insert(primaryId)
                    }
                }

                return Array(results)
            }
        } catch {
            print("[ProteinSearchService] Exact search error: \(error)")
            return []
        }
    }
    
    
    private func getAvailableProteinIds(curtainData: CurtainData) -> Set<String> {
        // Get protein IDs from selectionsMap/dataMap
        guard let dataMap = curtainData.selectionsMap else {
            return []
        }
        return Set(dataMap.keys)
    }

    private func searchPrimaryIDSuggestions(queryLower: String, curtainData: CurtainData, limit: Int) async -> [TypeaheadSuggestion] {
        let availableProteinIds = getAvailableProteinIds(curtainData: curtainData)
        var suggestions: [TypeaheadSuggestion] = []
        
        for proteinId in availableProteinIds {
            if proteinId.lowercased().contains(queryLower) {
                suggestions.append(TypeaheadSuggestion(
                    text: proteinId,
                    searchType: .primaryID,
                    matchType: proteinId.lowercased() == queryLower ? "exact" : "partial",
                    resultCount: 1
                ))
            }
        }
        
        return suggestions
    }

    private func searchGeneNameSuggestions(queryLower: String, curtainData: CurtainData, limit: Int) async -> [TypeaheadSuggestion] {
        var suggestions: [TypeaheadSuggestion] = []
        
        // Search UniProt gene names
        if let uniprotDB = curtainData.extraData?.uniprot?.db {
            var geneNames: Set<String> = []
            
            for (_, record) in uniprotDB {
                if let recordDict = record as? [String: Any],
                   let geneNamesString = recordDict["Gene Names"] as? String {
                    
                    let recordGeneNames = geneNamesString.components(separatedBy: CharacterSet(charactersIn: " ;"))
                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                        .filter { !$0.isEmpty }
                    
                    geneNames.formUnion(recordGeneNames)
                }
            }
            
            for geneName in geneNames {
                if geneName.lowercased().contains(queryLower) {
                    suggestions.append(TypeaheadSuggestion(
                        text: geneName,
                        searchType: .geneName,
                        matchType: geneName.lowercased() == queryLower ? "exact" : "partial",
                        resultCount: 1
                    ))
                }
            }
        }
        
        return suggestions
    }

    private func searchAccessionIDSuggestions(queryLower: String, curtainData: CurtainData, limit: Int) async -> [TypeaheadSuggestion] {
        guard let uniprotDB = curtainData.extraData?.uniprot?.db else {
            return []
        }
        
        var suggestions: [TypeaheadSuggestion] = []
        
        for accessionId in uniprotDB.keys {
            if accessionId.lowercased().contains(queryLower) {
                suggestions.append(TypeaheadSuggestion(
                    text: accessionId,
                    searchType: .accessionID,
                    matchType: accessionId.lowercased() == queryLower ? "exact" : "partial",
                    resultCount: 1
                ))
            }
        }
        
        return suggestions
    }
    
    // MARK: - Helper Methods
    
    private func processBatchSearchInput(inputText: String) -> [String: [String]] {
        
        let lines = inputText.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        var processedInput: [String: [String]] = [:]
        
        for line in lines {
            // Handle semicolon-delimited entries within each line 
            let terms = line.components(separatedBy: ";")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() }
                .filter { !$0.isEmpty }
            
            processedInput[line] = terms
        }
        
        return processedInput
    }
    
    private func getDatabaseURL(for linkId: String) -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let curtainDataDir = documentsPath.appendingPathComponent("CurtainData", isDirectory: true)
        return curtainDataDir.appendingPathComponent("proteomics_data_\(linkId).sqlite")
    }
}

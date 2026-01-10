//
//  ProteinSearchService.swift
//  Curtain
//
//  Created by Toan Phung on 04/08/2025.
//

import Foundation


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
    let timestamp: Date
    
    init(id: String = UUID().uuidString, name: String, proteinIds: Set<String>, searchTerms: [String] = [], searchType: SearchType = .primaryID, color: String, description: String? = nil, timestamp: Date = Date()) {
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
    
    // MARK: - Core Search Functionality
    
    func performTypeaheadSearch(
        query: String,
        searchType: SearchType,
        curtainData: CurtainData,
        limit: Int = 10
    ) async -> [TypeaheadSuggestion] {
        
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
    
    func performBatchSearch(
        inputText: String,
        searchType: SearchType,
        curtainData: CurtainData
    ) async -> [SearchResult] {
        
        let processedInput = processBatchSearchInput(inputText: inputText)
        var results: [SearchResult] = []
        
        for (originalLine, searchTerms) in processedInput {
            var allMatchedProteins: Set<String> = []
            
            for searchTerm in searchTerms {
                let proteins = await performExactSearch(
                    searchTerm: searchTerm,
                    searchType: searchType,
                    curtainData: curtainData
                )
                allMatchedProteins.formUnion(proteins)
            }
            
            if !allMatchedProteins.isEmpty {
                results.append(SearchResult(
                    searchTerm: originalLine,
                    matchedProteins: Array(allMatchedProteins),
                    searchType: searchType,
                    isExactMatch: true
                ))
            }
        }
        
        return results
    }
    
    func performExactSearch(
        searchTerm: String,
        searchType: SearchType,
        curtainData: CurtainData
    ) async -> [String] {
        
        let cleanTerm = searchTerm.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        
        switch searchType {
        case .primaryID:
            return getPrimaryIDsFromPrimaryId(searchTerm: cleanTerm, curtainData: curtainData)
        case .geneName:
            return getPrimaryIDsFromGeneNames(searchTerm: cleanTerm, curtainData: curtainData)
        case .accessionID:
            return getPrimaryIDsFromAccessionId(searchTerm: cleanTerm, curtainData: curtainData)
        }
    }
    
    
    private func getPrimaryIDsFromPrimaryId(searchTerm: String, curtainData: CurtainData) -> [String] {
        var matchedIds: Set<String> = []
        
        // Get all available protein IDs from the processed data
        let availableProteinIds = getAvailableProteinIds(curtainData: curtainData)
        
        // Handle semicolon-delimited IDs 
        let searchTerms = searchTerm.components(separatedBy: ";").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        
        for term in searchTerms {
            if availableProteinIds.contains(term) {
                matchedIds.insert(term)
            }
        }
        
        return Array(matchedIds)
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
    
    
    private func getPrimaryIDsFromGeneNames(searchTerm: String, curtainData: CurtainData) -> [String] {
        var matchedIds: Set<String> = []
        
        // Handle semicolon-delimited gene names 
        let geneNames = searchTerm.components(separatedBy: ";").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        
        for geneName in geneNames {
            if let uniprotIds = getProteinIdsFromUniProtGene(geneName: geneName, curtainData: curtainData) {
                matchedIds.formUnion(uniprotIds)
            } else {
                // Fallback to direct gene column search
                if let directIds = getProteinIdsFromGeneColumn(geneName: geneName, curtainData: curtainData) {
                    matchedIds.formUnion(directIds)
                }
            }
        }
        
        return Array(matchedIds)
    }
    
    private func getProteinIdsFromUniProtGene(geneName: String, curtainData: CurtainData) -> Set<String>? {
        
        guard let uniprotDB = curtainData.extraData?.uniprot?.db as? [String: Any] else {
            return nil
        }
        
        var matchedIds: Set<String> = []
        
        // Search through UniProt records for gene names
        for (proteinId, record) in uniprotDB {
            if let recordDict = record as? [String: Any],
               let geneNamesString = recordDict["Gene Names"] as? String {
                
                // Parse gene names (can be space or semicolon separated)
                let recordGeneNames = geneNamesString.components(separatedBy: CharacterSet(charactersIn: " ;"))
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                
                if recordGeneNames.contains(where: { $0.caseInsensitiveCompare(geneName) == .orderedSame }) {
                    matchedIds.insert(proteinId)
                }
            }
        }
        
        return matchedIds.isEmpty ? nil : matchedIds
    }
    
    private func getProteinIdsFromGeneColumn(geneName: String, curtainData: CurtainData) -> Set<String>? {
        // Search in the gene column of the processed data
        guard let processedData = curtainData.extraData?.data?.dataMap as? [String: Any],
              let differentialData = processedData["processedDifferentialData"] as? [[String: Any]] else {
            return nil
        }
        
        let geneColumn = curtainData.differentialForm.geneNames
        guard !geneColumn.isEmpty else { return nil }
        
        var matchedIds: Set<String> = []
        let idColumn = curtainData.differentialForm.primaryIDs
        
        for row in differentialData {
            if let rowGeneName = row[geneColumn] as? String,
               let proteinId = row[idColumn] as? String {
                
                // Handle semicolon-delimited gene names in data
                let rowGeneNames = rowGeneName.components(separatedBy: ";")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                
                if rowGeneNames.contains(where: { $0.caseInsensitiveCompare(geneName) == .orderedSame }) {
                    matchedIds.insert(proteinId)
                }
            }
        }
        
        return matchedIds.isEmpty ? nil : matchedIds
    }
    
    private func searchGeneNameSuggestions(queryLower: String, curtainData: CurtainData, limit: Int) async -> [TypeaheadSuggestion] {
        var suggestions: [TypeaheadSuggestion] = []
        
        // Search UniProt gene names
        if let uniprotDB = curtainData.extraData?.uniprot?.db as? [String: Any] {
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
    
    
    private func getPrimaryIDsFromAccessionId(searchTerm: String, curtainData: CurtainData) -> [String] {
        
        // For simplicity, we'll search in the UniProt database
        guard let uniprotDB = curtainData.extraData?.uniprot?.db as? [String: Any] else {
            return []
        }
        
        var matchedIds: [String] = []
        
        // Handle semicolon-delimited accession IDs
        let accessionIds = searchTerm.components(separatedBy: ";").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        
        for accessionId in accessionIds {
            if uniprotDB.keys.contains(accessionId) {
                matchedIds.append(accessionId)
            }
        }
        
        return matchedIds
    }
    
    private func searchAccessionIDSuggestions(queryLower: String, curtainData: CurtainData, limit: Int) async -> [TypeaheadSuggestion] {
        guard let uniprotDB = curtainData.extraData?.uniprot?.db as? [String: Any] else {
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
    
    private func getAvailableProteinIds(curtainData: CurtainData) -> Set<String> {
        // Get protein IDs from processed differential data 
        guard let processedData = curtainData.extraData?.data?.dataMap as? [String: Any],
              let differentialData = processedData["processedDifferentialData"] as? [[String: Any]] else {
            return []
        }
        
        let idColumn = curtainData.differentialForm.primaryIDs
        var proteinIds: Set<String> = []
        
        for row in differentialData {
            if let proteinId = row[idColumn] as? String, !proteinId.isEmpty {
                proteinIds.insert(proteinId)
            }
        }
        
        return proteinIds
    }
}
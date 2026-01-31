//
//  CrossDatasetModels.swift
//  Curtain
//
//  Value types for cross-dataset search configuration, results, and matrix.
//

import Foundation

// MARK: - Enums

enum InputMode: String, CaseIterable {
    case single
    case list
    case curated

    var displayName: String {
        switch self {
        case .single: return "Single"
        case .list: return "List"
        case .curated: return "Curated"
        }
    }
}

enum ProteinSortOption: String, CaseIterable {
    case nameAsc
    case nameDesc
    case matchCountDesc
    case avgFCAsc
    case avgFCDesc

    var displayName: String {
        switch self {
        case .nameAsc: return "Name (A-Z)"
        case .nameDesc: return "Name (Z-A)"
        case .matchCountDesc: return "Most Datasets"
        case .avgFCAsc: return "Avg FC (Low)"
        case .avgFCDesc: return "Avg FC (High)"
        }
    }
}

enum ProcessingState: String {
    case pending
    case loading
    case building
    case searching
    case completed
    case failed
}

// MARK: - Config Structs

struct CrossDatasetSearchConfig {
    var searchTerms: [String]
    var searchType: SearchType
    var datasetLinkIds: [String]
    var significantOnly: Bool
    var useRegex: Bool
    var advancedFiltering: CrossDatasetAdvancedFilterParams?
}

struct CrossDatasetAdvancedFilterParams {
    var minP: Double?
    var maxP: Double?
    var minFCLeft: Double?
    var maxFCLeft: Double?
    var minFCRight: Double?
    var maxFCRight: Double?
    var searchLeft: Bool
    var searchRight: Bool

    init(minP: Double? = nil, maxP: Double? = nil,
         minFCLeft: Double? = nil, maxFCLeft: Double? = nil,
         minFCRight: Double? = nil, maxFCRight: Double? = nil,
         searchLeft: Bool = true, searchRight: Bool = true) {
        self.minP = minP
        self.maxP = maxP
        self.minFCLeft = minFCLeft
        self.maxFCLeft = maxFCLeft
        self.minFCRight = minFCRight
        self.maxFCRight = maxFCRight
        self.searchLeft = searchLeft
        self.searchRight = searchRight
    }
}

// MARK: - Status

struct DatasetProcessingStatus: Identifiable {
    var id: String // linkId
    var datasetName: String
    var state: ProcessingState
    var error: String?
}

// MARK: - Result Structs

struct ProteinSearchSummary: Codable, Identifiable, Hashable {
    var id: String { "\(searchTerm)_\(primaryId ?? "unknown")" }
    var searchTerm: String
    var primaryId: String?
    var geneName: String?
    var datasetsFoundIn: Int
    var totalDatasetsSearched: Int
    var averageFoldChange: Double?
    var hasSignificantResult: Bool

    func hash(into hasher: inout Hasher) {
        hasher.combine(searchTerm)
        hasher.combine(primaryId)
    }

    static func == (lhs: ProteinSearchSummary, rhs: ProteinSearchSummary) -> Bool {
        lhs.searchTerm == rhs.searchTerm && lhs.primaryId == rhs.primaryId
    }
}

struct CrossDatasetSearchResult {
    var config: CrossDatasetSearchConfig
    var proteinSummaries: [ProteinSearchSummary]
    var searchTimestamp: Date
}

struct DatasetComparisonInfo {
    var linkId: String
    var datasetDescription: String
    var comparison: String
}

struct DatasetComparisonResult: Identifiable {
    var id: String { "\(datasetInfo.linkId)_\(datasetInfo.comparison)" }
    var datasetInfo: DatasetComparisonInfo
    var foldChange: Double?
    var pValue: Double?
    var isSignificant: Bool
    var found: Bool
}

struct ProteinDetailedReport {
    var searchTerm: String
    var primaryId: String?
    var geneName: String?
    var results: [DatasetComparisonResult]
    var datasetsFoundIn: Int
    var totalDatasetsSearched: Int
}

// MARK: - Matrix Structs

struct MatrixCell {
    var foldChange: Double?
    var pValue: Double?
    var isSignificant: Bool
    var found: Bool
}

struct MatrixRow: Identifiable {
    var id: String { "\(datasetLinkId)_\(comparison)" }
    var datasetLinkId: String
    var datasetName: String
    var comparison: String
    var conditionLeft: String?
    var conditionRight: String?
    var cells: [String: MatrixCell] // keyed by primaryId or searchTerm
}

struct CrossDatasetMatrix {
    var proteinIds: [String]
    var rows: [MatrixRow]
    var proteinGeneNames: [String: String?]
}

struct MatrixFilterOptions {
    var showSignificantOnly: Bool = false
    var hideNotFound: Bool = false
    var minFoldChange: Double? = nil
    var maxPValue: Double? = nil
    var selectedDatasets: Set<String>? = nil
}

//
//  SavedCrossDatasetSearchEntity.swift
//  Curtain
//
//  SwiftData entity for persisting cross-dataset search results.
//

import Foundation
import SwiftData

@Model
final class SavedCrossDatasetSearchEntity {
    @Attribute(.unique) var searchId: UUID
    var name: String
    var searchTerms: String // newline-separated
    var searchType: String // raw value of SearchType
    var datasetLinkIds: String // comma-separated
    var significantOnly: Bool
    var useRegex: Bool
    var resultSummariesJson: String // JSON-encoded [ProteinSearchSummary]
    var proteinCount: Int
    var datasetCount: Int
    var created: Date
    var lastOpened: Date

    init(
        searchId: UUID = UUID(),
        name: String,
        searchTerms: String,
        searchType: String,
        datasetLinkIds: String,
        significantOnly: Bool = false,
        useRegex: Bool = false,
        resultSummariesJson: String = "[]",
        proteinCount: Int = 0,
        datasetCount: Int = 0,
        created: Date = Date(),
        lastOpened: Date = Date()
    ) {
        self.searchId = searchId
        self.name = name
        self.searchTerms = searchTerms
        self.searchType = searchType
        self.datasetLinkIds = datasetLinkIds
        self.significantOnly = significantOnly
        self.useRegex = useRegex
        self.resultSummariesJson = resultSummariesJson
        self.proteinCount = proteinCount
        self.datasetCount = datasetCount
        self.created = created
        self.lastOpened = lastOpened
    }
}

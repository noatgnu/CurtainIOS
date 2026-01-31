//
//  CrossDatasetSearchViewModel.swift
//  Curtain
//
//  ViewModel for cross-dataset search feature.
//

import Foundation
import SwiftData

@MainActor
@Observable
class CrossDatasetSearchViewModel {

    // MARK: - Input State
    var searchInput: String = ""
    var inputMode: InputMode = .list
    var searchType: SearchType = .geneName
    var useRegex: Bool = false
    var significantOnly: Bool = false
    var advancedFiltering: CrossDatasetAdvancedFilterParams?
    var showAdvancedFiltering: Bool = false

    // MARK: - Dataset Selection
    var selectedDatasetIds: Set<String> = []
    var availableDatasets: [CurtainEntity] = []
    var collections: [CurtainCollectionEntity] = []
    var collectionSessions: [Int: [CollectionSessionEntity]] = [:]
    var expandedCollectionIds: Set<Int> = []
    var selectionTab: Int = 0 // 0 = Sessions, 1 = Collections
    var showSearchInput: Bool = false

    // MARK: - Results
    var searchResult: CrossDatasetSearchResult?
    var selectedProtein: ProteinSearchSummary?
    var proteinReport: ProteinDetailedReport?
    var sortOption: ProteinSortOption = .matchCountDesc

    // MARK: - Matrix
    var matrixData: CrossDatasetMatrix?
    var matrixFilterOptions: MatrixFilterOptions = MatrixFilterOptions()
    var selectedMatrixProtein: String?
    var currentPanel: Int = 0 // Phone: 0=saved, 1=proteins, 2=matrix

    // MARK: - Status
    var isSearching: Bool = false
    var isLoadingReport: Bool = false
    var isLoadingMatrix: Bool = false
    var error: String?
    var datasetStatuses: [String: DatasetProcessingStatus] = [:]

    // MARK: - Saved Searches
    var savedSearches: [SavedCrossDatasetSearchEntity] = []
    var currentSavedSearchId: UUID?

    // MARK: - Curated Lists
    var filterLists: [DataFilterListEntity] = []
    var selectedCategory: String?

    // MARK: - Dependencies
    private var searchService = CrossDatasetSearchService()
    private var savedSearchRepository: SavedSearchRepository?
    private var curtainRepository: CurtainRepository?
    private var collectionRepository: CurtainCollectionRepository?
    private var hasBeenSetup = false

    // MARK: - Setup

    func setupWithModelContext(_ modelContext: ModelContext) {
        guard !hasBeenSetup else { return }
        hasBeenSetup = true

        curtainRepository = CurtainRepository(modelContext: modelContext)
        collectionRepository = CurtainCollectionRepository(modelContext: modelContext)
        savedSearchRepository = SavedSearchRepository(modelContext: modelContext)
        searchService.curtainRepository = curtainRepository

        loadAvailableDatasets()
        loadCollections()
        loadFilterLists(modelContext: modelContext)
        loadSavedSearches()
    }

    private func loadAvailableDatasets() {
        guard let repo = curtainRepository else { return }
        // Get only datasets that have downloaded data
        let allCurtains = repo.getAllCurtains()
        availableDatasets = allCurtains.filter { curtain in
            ProteomicsDataDatabaseManager.shared.checkDataExists(curtain.linkId)
        }
        // Default: select all
        selectedDatasetIds = Set(availableDatasets.map { $0.linkId })
    }

    private func loadCollections() {
        guard let repo = collectionRepository else { return }
        collections = repo.getAllCollections()
    }

    private func loadFilterLists(modelContext: ModelContext) {
        let descriptor = FetchDescriptor<DataFilterListEntity>(
            sortBy: [SortDescriptor(\.name)]
        )
        filterLists = (try? modelContext.fetch(descriptor)) ?? []
    }

    func loadSavedSearches() {
        savedSearches = savedSearchRepository?.getAllSavedSearches() ?? []
    }

    // MARK: - Dataset Selection

    var resolvedDatasetLinkIds: [String] {
        Array(selectedDatasetIds)
    }

    func selectAllDatasets() {
        selectedDatasetIds = Set(availableDatasets.map { $0.linkId })
    }

    func deselectAllDatasets() {
        selectedDatasetIds.removeAll()
    }

    func toggleDatasetSelection(_ linkId: String) {
        if selectedDatasetIds.contains(linkId) {
            selectedDatasetIds.remove(linkId)
        } else {
            selectedDatasetIds.insert(linkId)
        }
    }

    // MARK: - Collection Selection

    func toggleCollectionExpanded(id: Int) {
        if expandedCollectionIds.contains(id) {
            expandedCollectionIds.remove(id)
        } else {
            expandedCollectionIds.insert(id)
            // Lazy-load sessions if not cached
            if collectionSessions[id] == nil {
                if let collection = collections.first(where: { $0.collectionId == id }) {
                    collectionSessions[id] = collection.sessions
                }
            }
        }
    }

    func selectAllSessionsInCollection(_ collectionId: Int) {
        let sessions = collectionSessions[collectionId] ?? collections.first(where: { $0.collectionId == collectionId })?.sessions ?? []
        for session in sessions {
            selectedDatasetIds.insert(session.linkId)
        }
    }

    func deselectAllSessionsInCollection(_ collectionId: Int) {
        let sessions = collectionSessions[collectionId] ?? collections.first(where: { $0.collectionId == collectionId })?.sessions ?? []
        for session in sessions {
            selectedDatasetIds.remove(session.linkId)
        }
    }

    func selectedCountInCollection(_ collectionId: Int) -> Int {
        let sessions = collectionSessions[collectionId] ?? collections.first(where: { $0.collectionId == collectionId })?.sessions ?? []
        return sessions.filter { selectedDatasetIds.contains($0.linkId) }.count
    }

    // MARK: - Search

    func performSearch() async {
        let terms = searchInput
            .components(separatedBy: CharacterSet.newlines)
            .flatMap { line -> [String] in
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return [] }
                if trimmed.contains(";") {
                    return trimmed.components(separatedBy: ";")
                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                        .filter { !$0.isEmpty }
                }
                return [trimmed]
            }

        guard !terms.isEmpty else {
            error = "Please enter at least one search term"
            return
        }

        let linkIds = resolvedDatasetLinkIds
        guard !linkIds.isEmpty else {
            error = "No datasets selected"
            return
        }

        isSearching = true
        error = nil
        datasetStatuses.removeAll()

        let config = CrossDatasetSearchConfig(
            searchTerms: terms,
            searchType: searchType,
            datasetLinkIds: linkIds,
            significantOnly: significantOnly,
            useRegex: useRegex,
            advancedFiltering: showAdvancedFiltering ? advancedFiltering : nil
        )

        let result = await searchService.searchAcrossDatasets(config: config) { [weak self] status in
            Task { @MainActor in
                self?.datasetStatuses[status.id] = status
            }
        }

        searchResult = result
        applySorting()
        isSearching = false

        // Auto-build matrix
        if !result.proteinSummaries.isEmpty {
            await buildMatrix()
        }
    }

    // MARK: - Protein Selection

    func selectProtein(_ protein: ProteinSearchSummary) async {
        selectedProtein = protein
        isLoadingReport = true

        let report = await searchService.getProteinDetailedReport(
            searchTerm: protein.searchTerm,
            primaryId: protein.primaryId,
            datasetLinkIds: searchResult?.config.datasetLinkIds ?? [],
            searchType: searchResult?.config.searchType ?? .geneName
        )

        proteinReport = report
        isLoadingReport = false
    }

    // MARK: - Matrix

    func buildMatrix() async {
        guard let result = searchResult else { return }
        isLoadingMatrix = true

        matrixData = await searchService.buildCrossDatasetMatrix(
            searchResult: result,
            filterOptions: matrixFilterOptions
        )

        isLoadingMatrix = false
    }

    // MARK: - Sorting

    func applySorting() {
        guard var summaries = searchResult?.proteinSummaries else { return }

        switch sortOption {
        case .nameAsc:
            summaries.sort { ($0.geneName ?? $0.searchTerm) < ($1.geneName ?? $1.searchTerm) }
        case .nameDesc:
            summaries.sort { ($0.geneName ?? $0.searchTerm) > ($1.geneName ?? $1.searchTerm) }
        case .matchCountDesc:
            summaries.sort { a, b in
                if a.datasetsFoundIn != b.datasetsFoundIn { return a.datasetsFoundIn > b.datasetsFoundIn }
                return abs(a.averageFoldChange ?? 0) > abs(b.averageFoldChange ?? 0)
            }
        case .avgFCAsc:
            summaries.sort { ($0.averageFoldChange ?? 0) < ($1.averageFoldChange ?? 0) }
        case .avgFCDesc:
            summaries.sort { ($0.averageFoldChange ?? 0) > ($1.averageFoldChange ?? 0) }
        }

        searchResult?.proteinSummaries = summaries
    }

    // MARK: - Saved Searches

    func saveCurrentSearch(name: String) {
        guard let result = searchResult, let repo = savedSearchRepository else { return }
        let entity = repo.saveSearch(
            name: name,
            config: result.config,
            summaries: result.proteinSummaries
        )
        currentSavedSearchId = entity.searchId
        loadSavedSearches()
    }

    func loadSavedSearch(_ entity: SavedCrossDatasetSearchEntity) {
        savedSearchRepository?.updateLastOpened(entity.searchId)

        // Restore config
        searchInput = entity.searchTerms.replacingOccurrences(of: "\n", with: "\n")
        searchType = SearchType(rawValue: entity.searchType) ?? .geneName
        significantOnly = entity.significantOnly
        useRegex = entity.useRegex

        let linkIds = entity.datasetLinkIds.components(separatedBy: ",").filter { !$0.isEmpty }
        selectedDatasetIds = Set(linkIds)

        // Restore results
        if let data = entity.resultSummariesJson.data(using: .utf8),
           let summaries = try? JSONDecoder().decode([ProteinSearchSummary].self, from: data) {
            searchResult = CrossDatasetSearchResult(
                config: CrossDatasetSearchConfig(
                    searchTerms: entity.searchTerms.components(separatedBy: "\n"),
                    searchType: SearchType(rawValue: entity.searchType) ?? .geneName,
                    datasetLinkIds: linkIds,
                    significantOnly: entity.significantOnly,
                    useRegex: entity.useRegex,
                    advancedFiltering: nil
                ),
                proteinSummaries: summaries,
                searchTimestamp: entity.created
            )
        }

        currentSavedSearchId = entity.searchId
        loadSavedSearches()
    }

    func renameSavedSearch(_ id: UUID, name: String) {
        savedSearchRepository?.renameSearch(id, name: name)
        loadSavedSearches()
    }

    func deleteSavedSearch(_ id: UUID) {
        savedSearchRepository?.deleteSearch(id)
        if currentSavedSearchId == id {
            currentSavedSearchId = nil
        }
        loadSavedSearches()
    }

    // MARK: - Export

    func exportResultsCSV() -> String? {
        guard let result = searchResult else { return nil }
        return searchService.exportResultsAsCSV(result: result)
    }

    func exportMatrixCSV() -> String? {
        guard let matrix = matrixData else { return nil }
        return searchService.exportMatrixAsCSV(matrix: matrix)
    }

    // MARK: - Error Handling

    func clearError() {
        error = nil
    }

    // MARK: - Filter List Loading

    func loadFilterListIntoSearch(_ filterList: DataFilterListEntity) {
        let items = filterList.data.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        searchInput = items.joined(separator: "\n")
        inputMode = .curated
    }
}

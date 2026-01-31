//
//  SavedSearchRepository.swift
//  Curtain
//
//  SwiftData CRUD for saved cross-dataset searches.
//

import Foundation
import SwiftData

@Observable
class SavedSearchRepository {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Thread Safety Helper

    private func performDatabaseOperation<T>(_ operation: () -> T) -> T {
        if Thread.isMainThread {
            return operation()
        } else {
            return DispatchQueue.main.sync {
                return operation()
            }
        }
    }

    // MARK: - CRUD

    func getAllSavedSearches() -> [SavedCrossDatasetSearchEntity] {
        return performDatabaseOperation {
            let descriptor = FetchDescriptor<SavedCrossDatasetSearchEntity>(
                sortBy: [SortDescriptor(\.lastOpened, order: .reverse)]
            )
            return (try? modelContext.fetch(descriptor)) ?? []
        }
    }

    func getSearchById(_ id: UUID) -> SavedCrossDatasetSearchEntity? {
        return performDatabaseOperation {
            let descriptor = FetchDescriptor<SavedCrossDatasetSearchEntity>()
            let all = (try? modelContext.fetch(descriptor)) ?? []
            return all.first { $0.searchId == id }
        }
    }

    func saveSearch(
        name: String,
        config: CrossDatasetSearchConfig,
        summaries: [ProteinSearchSummary]
    ) -> SavedCrossDatasetSearchEntity {
        return performDatabaseOperation {
            let jsonData = (try? JSONEncoder().encode(summaries)) ?? Data()
            let jsonString = String(data: jsonData, encoding: .utf8) ?? "[]"

            let entity = SavedCrossDatasetSearchEntity(
                name: name,
                searchTerms: config.searchTerms.joined(separator: "\n"),
                searchType: config.searchType.rawValue,
                datasetLinkIds: config.datasetLinkIds.joined(separator: ","),
                significantOnly: config.significantOnly,
                useRegex: config.useRegex,
                resultSummariesJson: jsonString,
                proteinCount: summaries.count,
                datasetCount: config.datasetLinkIds.count
            )

            modelContext.insert(entity)
            try? modelContext.save()
            return entity
        }
    }

    func updateLastOpened(_ id: UUID) {
        performDatabaseOperation {
            if let entity = getSearchById(id) {
                entity.lastOpened = Date()
                try? modelContext.save()
            }
        }
    }

    func renameSearch(_ id: UUID, name: String) {
        performDatabaseOperation {
            if let entity = getSearchById(id) {
                entity.name = name
                try? modelContext.save()
            }
        }
    }

    func deleteSearch(_ id: UUID) {
        performDatabaseOperation {
            if let entity = getSearchById(id) {
                modelContext.delete(entity)
                try? modelContext.save()
            }
        }
    }
}

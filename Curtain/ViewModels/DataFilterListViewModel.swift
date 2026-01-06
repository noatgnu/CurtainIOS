//
//  DataFilterListViewModel.swift
//  Curtain
//
//  Created by Toan Phung on 02/08/2025.
//

import Foundation
import SwiftData

// MARK: - DataFilterListViewModel (Based on Android DataFilterListViewModel.kt)

@MainActor
@Observable
class DataFilterListViewModel {
    private let repository: DataFilterListRepository
    
    // MARK: - State Properties (Like Android StateFlow)
    
    // Data State
    var filterLists: [DataFilterListEntity] = []
    var categories: [String] = []
    
    // Loading States
    var isLoading = false
    var isSyncing = false
    
    // Sync Progress Tracking (Like Android)
    var syncProgress = 0
    var syncTotal = 0
    var currentSyncCategory: String?
    
    // Error Handling
    var error: String?
    
    init(repository: DataFilterListRepository) {
        self.repository = repository
        loadDataFilterLists()
    }
    
    // MARK: - Data Loading Methods (Like Android)
    
    /// Load data filter lists from the local database
    func loadDataFilterLists() {
        Task {
            // Load filter lists
            filterLists = repository.getAllDataFilterLists()

            // Load categories directly from database
            loadCategories()
        }
    }
    
    /// Load categories directly from the database
    private func loadCategories() {
        categories = repository.getAllCategoriesLocal()
    }
    
    // MARK: - Sync Operations (Like Android)
    
    /// Sync data filter lists from the remote API with detailed progress tracking
    func syncDataFilterLists(hostname: String) async {
        print("🔄 DataFilterListViewModel: Starting sync for hostname: \(hostname)")
        
        isLoading = true
        isSyncing = true
        error = nil
        syncProgress = 0
        
        do {
            // First get all remote categories (like Android)
            print("🔄 DataFilterListViewModel: Fetching categories from \(hostname)")
            let remoteCategories = try await repository.getAllCategories(hostname: hostname)
            print("🔄 DataFilterListViewModel: Found \(remoteCategories.count) categories: \(remoteCategories)")
            syncTotal = remoteCategories.count
            
            var processedCount = 0
            var allFilterLists: [(String, DataFilterList)] = []
            
            for category in remoteCategories {
                currentSyncCategory = category
                syncProgress = processedCount
                print("🔄 DataFilterListViewModel: Processing category: \(category)")
                
                // Fetch filter lists for this category (like Android)
                let categoryFilterLists = try await repository.fetchDataFilterListsByCategory(
                    hostname: hostname,
                    category: category
                )
                print("🔄 DataFilterListViewModel: Found \(categoryFilterLists.count) filter lists for category: \(category)")
                
                allFilterLists.append(contentsOf: categoryFilterLists)
                processedCount += 1
                syncProgress = processedCount
            }
            
            print("🔄 DataFilterListViewModel: Total filter lists collected: \(allFilterLists.count)")
            
            // Convert to entities and save to local database (like Android)
            let entityFilterLists = allFilterLists.map { (category, filterList) in
                repository.mapApiToEntity(filterList, category: category)
            }
            
            print("🔄 DataFilterListViewModel: Saving \(entityFilterLists.count) entities to database")
            try repository.saveDataFilterLists(entityFilterLists)
            
            // Refresh local data
            loadDataFilterLists()
            print("🔄 DataFilterListViewModel: Sync completed successfully. Local lists count: \(filterLists.count)")
            
            isSyncing = false
            isLoading = false
            currentSyncCategory = nil
            
        } catch {
            print("❌ DataFilterListViewModel: Sync failed with error: \(error)")
            self.error = "Failed to sync filter lists: \(error.localizedDescription)"
            isSyncing = false
            isLoading = false
            currentSyncCategory = nil
        }
    }
    
    // MARK: - CRUD Operations (Like Android)
    
    /// Create a new data filter list
    func createDataFilterList(hostname: String, name: String, category: String, data: String, isDefault: Bool = false) async {
        isLoading = true
        error = nil
        
        do {
            let request = DataFilterListRequest(
                name: name,
                category: category,
                data: data,
                isDefault: isDefault
            )
            
            _ = try await repository.createDataFilterList(hostname: hostname, request: request)
            
            // Refresh local data
            loadDataFilterLists()
            isLoading = false
            
        } catch {
            self.error = "Failed to create filter list: \(error.localizedDescription)"
            isLoading = false
        }
    }
    
    /// Update an existing data filter list
    func updateDataFilterList(hostname: String, id: Int, name: String, category: String, data: String, isDefault: Bool = false) async {
        isLoading = true
        error = nil
        
        do {
            let request = DataFilterListRequest(
                name: name,
                category: category,
                data: data,
                isDefault: isDefault
            )
            
            _ = try await repository.updateDataFilterList(hostname: hostname, id: id, request: request)
            
            // Refresh local data
            loadDataFilterLists()
            isLoading = false
            
        } catch {
            self.error = "Failed to update filter list: \(error.localizedDescription)"
            isLoading = false
        }
    }
    
    /// Delete a data filter list
    func deleteDataFilterList(hostname: String, filterList: DataFilterListEntity) async {
        isLoading = true
        error = nil
        
        do {
            // Delete from remote API
            try await repository.deleteRemoteDataFilterList(hostname: hostname, id: filterList.apiId)
            
            // Delete from local database
            try repository.deleteDataFilterList(filterList)
            
            // Refresh local data
            loadDataFilterLists()
            isLoading = false
            
        } catch {
            self.error = "Failed to delete filter list: \(error.localizedDescription)"
            isLoading = false
        }
    }
    
    /// Save a filter list locally only
    func saveDataFilterListLocally(_ filterList: DataFilterListEntity) {
        do {
            try repository.saveDataFilterList(filterList)
            loadDataFilterLists() // Refresh list
        } catch {
            self.error = "Failed to save filter list locally: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Filtering and Search Methods
    
    /// Get filter lists by category
    func getFilterListsByCategory(_ category: String) -> [DataFilterListEntity] {
        return filterLists.filter { $0.category == category }
    }
    
    /// Get default filter lists
    func getDefaultFilterLists() -> [DataFilterListEntity] {
        return filterLists.filter { $0.isDefault }
    }
    
    /// Get user-created filter lists
    func getUserFilterLists() -> [DataFilterListEntity] {
        return filterLists.filter { !$0.isDefault }
    }
    
    /// Search filter lists by name
    func searchFilterLists(_ searchText: String) -> [DataFilterListEntity] {
        guard !searchText.isEmpty else { return filterLists }
        
        return filterLists.filter { filterList in
            filterList.name.localizedCaseInsensitiveContains(searchText) ||
            filterList.category.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    /// Get filter list by ID
    func getFilterListById(_ id: Int) -> DataFilterListEntity? {
        return repository.getDataFilterListById(id)
    }
    
    // MARK: - Remote Operations
    
    /// Fetch a specific filter list from remote API
    func fetchDataFilterListById(hostname: String, id: Int) async {
        isLoading = true
        error = nil
        
        do {
            _ = try await repository.fetchDataFilterListById(hostname: hostname, id: id)
            loadDataFilterLists() // Refresh list
            isLoading = false
        } catch {
            self.error = "Failed to fetch filter list: \(error.localizedDescription)"
            isLoading = false
        }
    }
    
    /// Fetch filter lists for a specific category
    func fetchFilterListsByCategory(hostname: String, category: String) async {
        isLoading = true
        error = nil
        
        do {
            let categoryFilterLists = try await repository.fetchDataFilterListsByCategory(
                hostname: hostname,
                category: category
            )
            
            // Convert to entities and save locally
            let entityFilterLists = categoryFilterLists.map { (category, filterList) in
                repository.mapApiToEntity(filterList, category: category)
            }
            
            try repository.saveDataFilterLists(entityFilterLists)
            loadDataFilterLists() // Refresh list
            isLoading = false
            
        } catch {
            self.error = "Failed to fetch filter lists for category: \(error.localizedDescription)"
            isLoading = false
        }
    }
    
    // MARK: - Utility Methods
    
    func clearError() {
        error = nil
    }
    
    func getSyncProgressPercentage() -> Double {
        guard syncTotal > 0 else { return 0.0 }
        return Double(syncProgress) / Double(syncTotal) * 100.0
    }
    
    func getSyncProgressText() -> String {
        if let category = currentSyncCategory {
            return "Syncing \(category)... (\(syncProgress)/\(syncTotal))"
        } else if isSyncing {
            return "Preparing sync..."
        } else {
            return ""
        }
    }
    
    // MARK: - Data Export/Import
    
    /// Export filter list data as JSON string
    func exportFilterListData(_ filterList: DataFilterListEntity) -> String? {
        let exportData = [
            "name": filterList.name,
            "category": filterList.category,
            "data": filterList.data,
            "isDefault": filterList.isDefault
        ] as [String: Any]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: exportData, options: .prettyPrinted)
            return String(data: jsonData, encoding: .utf8)
        } catch {
            self.error = "Failed to export filter list: \(error.localizedDescription)"
            return nil
        }
    }
    
    /// Import filter list from JSON string
    func importFilterListData(hostname: String, jsonString: String) async {
        isLoading = true
        error = nil
        
        do {
            guard let jsonData = jsonString.data(using: .utf8),
                  let importData = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                  let name = importData["name"] as? String,
                  let category = importData["category"] as? String,
                  let data = importData["data"] as? String else {
                throw DataFilterListViewModelError.invalidImportData
            }
            
            let isDefault = importData["isDefault"] as? Bool ?? false
            
            await createDataFilterList(
                hostname: hostname,
                name: name,
                category: category,
                data: data,
                isDefault: isDefault
            )
            
        } catch {
            self.error = "Failed to import filter list: \(error.localizedDescription)"
            isLoading = false
        }
    }
}

// MARK: - ViewModel Errors

enum DataFilterListViewModelError: Error, LocalizedError {
    case invalidImportData
    case syncFailed
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .invalidImportData:
            return "Invalid import data format"
        case .syncFailed:
            return "Failed to sync with remote server"
        case .networkError:
            return "Network connection error"
        }
    }
}
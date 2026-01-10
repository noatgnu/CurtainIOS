//
//  DataFilterListRepository.swift
//  Curtain
//
//  Created by Toan Phung on 02/08/2025.
//

import Foundation
import SwiftData

// MARK: - DataFilterListRepository 

@Observable
class DataFilterListRepository {
    private let modelContext: ModelContext
    private let networkManager: MultiHostNetworkManager
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.networkManager = MultiHostNetworkManager.shared
    }
    
    // MARK: - Thread Safety Helper
    
    /// Ensures all ModelContext operations are performed on the main thread
    private func performDatabaseOperation<T>(_ operation: () -> T) -> T {
        if Thread.isMainThread {
            return operation()
        } else {
            return DispatchQueue.main.sync {
                return operation()
            }
        }
    }
    
    // MARK: - Local Database Operations 
    
    /// Get all saved data filter lists from the local database
    func getAllDataFilterLists() -> [DataFilterListEntity] {
        return performDatabaseOperation {
            let descriptor = FetchDescriptor<DataFilterListEntity>()
            return (try? modelContext.fetch(descriptor)) ?? []
        }
    }
    
    /// Get a specific data filter list by ID from the local database
    func getDataFilterListById(_ id: Int) -> DataFilterListEntity? {
        return performDatabaseOperation {
            let predicate = #Predicate<DataFilterListEntity> { entity in
                entity.apiId == id
            }
            let descriptor = FetchDescriptor<DataFilterListEntity>(predicate: predicate)
            return try? modelContext.fetch(descriptor).first
        }
    }
    
    /// Save a data filter list to the local database
    func saveDataFilterList(_ dataFilterList: DataFilterListEntity) throws {
        performDatabaseOperation {
            modelContext.insert(dataFilterList)
            try? modelContext.save()
        }
    }
    
    func saveDataFilterLists(_ dataFilterLists: [DataFilterListEntity]) throws {
        performDatabaseOperation {
            let descriptor = FetchDescriptor<DataFilterListEntity>()
            let existingEntities = (try? modelContext.fetch(descriptor)) ?? []
            for entity in existingEntities {
                modelContext.delete(entity)
            }
            
            // Insert new filter lists
            for dataFilterList in dataFilterLists {
                modelContext.insert(dataFilterList)
            }
            try? modelContext.save()
        }
    }
    
    /// Delete a data filter list from the local database
    func deleteDataFilterList(_ dataFilterList: DataFilterListEntity) throws {
        performDatabaseOperation {
            modelContext.delete(dataFilterList)
            try? modelContext.save()
        }
    }
    
    /// Get all unique categories from the database
    func getAllCategoriesLocal() -> [String] {
        return performDatabaseOperation {
            let descriptor = FetchDescriptor<DataFilterListEntity>()
            let entities = (try? modelContext.fetch(descriptor)) ?? []
            let categories = Set(entities.compactMap { $0.category })
            return Array(categories).sorted()
        }
    }
    
    // MARK: - Remote API Operations 
    
    /// Fetch all data filter lists from the remote API
    /// First gets all categories and then fetches lists for each category
    func fetchAllDataFilterLists(hostname: String) async throws -> [(String, DataFilterList)] {
        // First get all categories 
        let categories = try await getAllCategories(hostname: hostname)
        var allFilterLists: [(String, DataFilterList)] = []
        
        for category in categories {
            var offset: Int? = nil
            var hasMore = true
            
            while hasMore {
                let response = try await networkManager.getDataFilterListsByCategory(
                    hostname: hostname,
                    category: category,
                    limit: nil,
                    offset: offset
                )
                
                // Add results with category pairing 
                let listsWithCategory = response.results.map { filterList in
                    (category, filterList)
                }
                allFilterLists.append(contentsOf: listsWithCategory)
                
                // Handle pagination 
                if let nextUrl = response.next {
                    offset = extractOffsetFromUrl(nextUrl)
                    hasMore = offset != nil
                } else {
                    hasMore = false
                }
            }
        }
        
        return allFilterLists
    }
    
    /// Fetch a specific data filter list from the remote API
    func fetchDataFilterListById(hostname: String, id: Int) async throws -> DataFilterList {
        return try await networkManager.getNetworkService(for: hostname).getDataFilterList(hostname: hostname, id: id)
    }
    
    /// Create a new data filter list on the remote API
    func createDataFilterList(hostname: String, request: DataFilterListRequest) async throws -> DataFilterList {
        let service = networkManager.getNetworkService(for: hostname)
        let createdFilterList = try await service.createDataFilterList(hostname: hostname, request: request)
        
        // Also save to local database 
        let entity = mapApiToEntity(createdFilterList, category: request.category)
        try saveDataFilterList(entity)
        
        return createdFilterList
    }
    
    /// Update an existing data filter list on the remote API
    func updateDataFilterList(hostname: String, id: Int, request: DataFilterListRequest) async throws -> DataFilterList {
        let service = networkManager.getNetworkService(for: hostname)
        let updatedFilterList = try await service.updateDataFilterList(hostname: hostname, id: id, request: request)
        
        // Also update in local database 
        let entity = mapApiToEntity(updatedFilterList, category: request.category)
        try saveDataFilterList(entity)
        
        return updatedFilterList
    }
    
    /// Delete a data filter list on the remote API
    func deleteRemoteDataFilterList(hostname: String, id: Int) async throws {
        let service = networkManager.getNetworkService(for: hostname)
        try await service.deleteDataFilterList(hostname: hostname, id: id)
    }
    
    /// Get all available categories from the remote API
    func getAllCategories(hostname: String) async throws -> [String] {
        let service = networkManager.getNetworkService(for: hostname)
        return try await service.getAllCategories(hostname: hostname)
    }
    
    /// Sync data from remote API to local database 
    func syncDataFilterLists(hostname: String) async throws {
        let apiFilterListsWithCategories = try await fetchAllDataFilterLists(hostname: hostname)
        let entityFilterLists = apiFilterListsWithCategories.map { (category, filterList) in
            mapApiToEntity(filterList, category: category)
        }
        try saveDataFilterLists(entityFilterLists)
    }
    
    /// Fetch data filter lists for a specific category 
    func fetchDataFilterListsByCategory(hostname: String, category: String) async throws -> [(String, DataFilterList)] {
        var allFilterLists: [(String, DataFilterList)] = []
        var offset: Int? = nil
        var hasMore = true
        
        while hasMore {
            let response = try await networkManager.getDataFilterListsByCategory(
                hostname: hostname,
                category: category,
                limit: nil,
                offset: offset
            )
            
            // Extract results from the current page 
            let filterLists = response.results.map { filterList in
                (category, filterList)
            }
            allFilterLists.append(contentsOf: filterLists)
            
            // Handle pagination 
            if let nextUrl = response.next {
                offset = extractOffsetFromUrl(nextUrl)
                hasMore = offset != nil
            } else {
                hasMore = false
            }
        }
        
        return allFilterLists
    }
    
    
    /// Helper functions to extract pagination parameters from URLs 
    private func extractOffsetFromUrl(_ url: String) -> Int? {
        let regex = try? NSRegularExpression(pattern: "offset=(\\d+)")
        let range = NSRange(location: 0, length: url.utf16.count)
        let match = regex?.firstMatch(in: url, range: range)
        
        if let match = match {
            let offsetRange = Range(match.range(at: 1), in: url)
            if let offsetRange = offsetRange {
                return Int(String(url[offsetRange]))
            }
        }
        
        return nil
    }
    
    private func extractLimitFromUrl(_ url: String) -> Int? {
        let regex = try? NSRegularExpression(pattern: "limit=(\\d+)")
        let range = NSRange(location: 0, length: url.utf16.count)
        let match = regex?.firstMatch(in: url, range: range)
        
        if let match = match {
            let limitRange = Range(match.range(at: 1), in: url)
            if let limitRange = limitRange {
                return Int(String(url[limitRange]))
            }
        }
        
        return nil
    }
    
    func mapApiToEntity(_ apiModel: DataFilterList, category: String) -> DataFilterListEntity {
        return DataFilterListEntity(
            apiId: apiModel.id,  // Use apiId instead of id for API integer ID
            name: apiModel.name,
            category: category,
            data: apiModel.data,
            isDefault: apiModel.isDefault,
            user: nil
        )
    }
    
    // Overload for backward compatibility 
    private func mapApiToEntity(_ apiModel: DataFilterList) -> DataFilterListEntity {
        return mapApiToEntity(apiModel, category: "")
    }
}

// MARK: - NetworkService Extension for DataFilterList APIs

extension NetworkService {
    
    func createDataFilterList(hostname: String, request: DataFilterListRequest) async throws -> DataFilterList {
        let url = buildURL(hostname: hostname, path: "data_filter_list/")
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let encoder = JSONEncoder()
        urlRequest.httpBody = try encoder.encode(request)
        
        let (data, response) = try await session.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        guard 200...299 ~= httpResponse.statusCode else {
            throw NetworkError.serverError(httpResponse.statusCode)
        }
        
        do {
            let decoder = JSONDecoder()
            return try decoder.decode(DataFilterList.self, from: data)
        } catch {
            throw NetworkError.decodingError(error)
        }
    }
    
    func updateDataFilterList(hostname: String, id: Int, request: DataFilterListRequest) async throws -> DataFilterList {
        let url = buildURL(hostname: hostname, path: "data_filter_list/\(id)/")
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "PUT"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let encoder = JSONEncoder()
        urlRequest.httpBody = try encoder.encode(request)
        
        let (data, response) = try await session.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        guard 200...299 ~= httpResponse.statusCode else {
            throw NetworkError.serverError(httpResponse.statusCode)
        }
        
        do {
            let decoder = JSONDecoder()
            return try decoder.decode(DataFilterList.self, from: data)
        } catch {
            throw NetworkError.decodingError(error)
        }
    }
    
    func deleteDataFilterList(hostname: String, id: Int) async throws {
        let url = buildURL(hostname: hostname, path: "data_filter_list/\(id)/")
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "DELETE"
        
        let (_, response) = try await session.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        guard 200...299 ~= httpResponse.statusCode else {
            throw NetworkError.serverError(httpResponse.statusCode)
        }
    }
}
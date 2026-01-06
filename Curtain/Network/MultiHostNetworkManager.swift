//
//  MultiHostNetworkManager.swift
//  Curtain
//
//  Created by Toan Phung on 02/08/2025.
//

import Foundation

// MARK: - Multi-Host Network Manager (Based on Android BaseUrlInterceptor)

class MultiHostNetworkManager {
    private var networkServices: [String: NetworkService] = [:]
    private let queue = DispatchQueue(label: "multihost.network.queue", attributes: .concurrent)
    
    static let shared = MultiHostNetworkManager()
    
    private init() {}
    
    // MARK: - Service Management
    
    func getNetworkService(for hostname: String) -> NetworkService {
        return queue.sync {
            if let existingService = networkServices[hostname] {
                return existingService
            }
            
            let newService = NetworkService()
            networkServices[hostname] = newService
            return newService
        }
    }
    
    func removeNetworkService(for hostname: String) {
        queue.async(flags: .barrier) {
            self.networkServices.removeValue(forKey: hostname)
        }
    }
    
    func clearAllServices() {
        queue.async(flags: .barrier) {
            self.networkServices.removeAll()
        }
    }
    
    // MARK: - Convenience Methods for API Calls
    
    func getAllCurtains(hostname: String) async throws -> [Curtain] {
        let service = getNetworkService(for: hostname)
        return try await service.getAllCurtains(hostname: hostname)
    }
    
    func getCurtainByLinkId(hostname: String, linkId: String) async throws -> Curtain {
        let service = getNetworkService(for: hostname)
        return try await service.getCurtainByLinkId(hostname: hostname, linkId: linkId)
    }
    
    func downloadCurtain(hostname: String, downloadPath: String) async throws -> Data {
        let service = getNetworkService(for: hostname)
        return try await service.downloadCurtain(hostname: hostname, downloadPath: downloadPath)
    }
    
    func downloadCurtain(hostname: String, downloadPath: String, progressCallback: ((Int, Double) -> Void)?) async throws -> Data {
        let service = getNetworkService(for: hostname)
        return try await service.downloadCurtain(hostname: hostname, downloadPath: downloadPath, progressCallback: progressCallback)
    }
    
    func getAllDataFilterLists(hostname: String, limit: Int? = nil, offset: Int? = nil) async throws -> PaginatedResponse<DataFilterList> {
        let service = getNetworkService(for: hostname)
        return try await service.getAllDataFilterLists(hostname: hostname, limit: limit, offset: offset)
    }
    
    func getDataFilterListsByCategory(hostname: String, category: String, limit: Int? = nil, offset: Int? = nil) async throws -> PaginatedResponse<DataFilterList> {
        let service = getNetworkService(for: hostname)
        return try await service.getDataFilterListsByCategory(hostname: hostname, category: category, limit: limit, offset: offset)
    }
}
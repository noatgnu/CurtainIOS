//
//  NetworkService.swift
//  Curtain
//
//  Created by Toan Phung on 02/08/2025.
//

import Foundation

// MARK: - Network Service Protocol

protocol NetworkServiceProtocol {
    func getAllCurtains(hostname: String) async throws -> [Curtain]
    func getCurtainByLinkId(hostname: String, linkId: String) async throws -> Curtain
    func downloadCurtain(hostname: String, downloadPath: String) async throws -> Data
    func downloadCurtain(hostname: String, downloadPath: String, progressCallback: ((Int, Double) -> Void)?) async throws -> Data
    func getAllDataFilterLists(hostname: String, limit: Int?, offset: Int?) async throws -> PaginatedResponse<DataFilterList>
    func getDataFilterListsByCategory(hostname: String, category: String, limit: Int?, offset: Int?) async throws -> PaginatedResponse<DataFilterList>
}

// MARK: - Network Service Implementation

class NetworkService: NetworkServiceProtocol {
    let session: URLSession
    let downloadClient: DownloadClient
    
    init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        configuration.httpAdditionalHeaders = [
            "Accept": "application/json",
            "Content-Type": "application/json"
        ]
        self.session = URLSession(configuration: configuration)
        self.downloadClient = DownloadClient.shared
    }
    
    
    func getAllCurtains(hostname: String) async throws -> [Curtain] {
        let url = buildURL(hostname: hostname, path: "curtain/")
        let response = try await performRequest(url: url, responseType: PaginatedResponse<Curtain>.self)
        return response.results
    }
    
    func getCurtainByLinkId(hostname: String, linkId: String) async throws -> Curtain {
        let url = buildURL(hostname: hostname, path: "curtain/\(linkId)/")
        return try await performRequest(url: url, responseType: Curtain.self)
    }
    
    func downloadCurtain(hostname: String, downloadPath: String) async throws -> Data {
        // downloadPath is like "{linkId}/download/token={token}"
        let url = buildURL(hostname: hostname, path: "curtain/\(downloadPath)")
        return try await performDataRequest(url: url)
    }
    
    func downloadCurtain(hostname: String, downloadPath: String, progressCallback: ((Int, Double) -> Void)?) async throws -> Data {
        // downloadPath is like "{linkId}/download/token={token}"
        let url = buildURL(hostname: hostname, path: "curtain/\(downloadPath)")
        
        // Use a temporary file path for DownloadClient
        let tempDirectory = FileManager.default.temporaryDirectory
        let tempFileName = UUID().uuidString + ".json"
        let tempFilePath = tempDirectory.appendingPathComponent(tempFileName).path
        
        do {
            // Download with progress using DownloadClient
            _ = try await downloadClient.downloadFileWithStreaming(
                from: url.absoluteString,
                to: tempFilePath,
                progressCallback: progressCallback
            )
            
            // Read the downloaded data
            let tempFileURL = URL(fileURLWithPath: tempFilePath)
            let data = try Data(contentsOf: tempFileURL)
            
            // Clean up temporary file
            try? FileManager.default.removeItem(at: tempFileURL)
            
            return data
        } catch {
            // Clean up temporary file on error
            let tempFileURL = URL(fileURLWithPath: tempFilePath)
            try? FileManager.default.removeItem(at: tempFileURL)
            throw error
        }
    }
    
    
    func getAllDataFilterLists(hostname: String, limit: Int? = nil, offset: Int? = nil) async throws -> PaginatedResponse<DataFilterList> {
        var queryItems: [URLQueryItem] = []
        if let limit = limit {
            queryItems.append(URLQueryItem(name: "limit", value: String(limit)))
        }
        if let offset = offset {
            queryItems.append(URLQueryItem(name: "offset", value: String(offset)))
        }
        
        let url = buildURL(hostname: hostname, path: "data_filter_list/", queryItems: queryItems)
        return try await performRequest(url: url, responseType: PaginatedResponse<DataFilterList>.self)
    }
    
    func getDataFilterListsByCategory(hostname: String, category: String, limit: Int? = nil, offset: Int? = nil) async throws -> PaginatedResponse<DataFilterList> {
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "category_exact", value: category)
        ]
        if let limit = limit {
            queryItems.append(URLQueryItem(name: "limit", value: String(limit)))
        }
        if let offset = offset {
            queryItems.append(URLQueryItem(name: "offset", value: String(offset)))
        }
        
        let url = buildURL(hostname: hostname, path: "data_filter_list/", queryItems: queryItems)
        return try await performRequest(url: url, responseType: PaginatedResponse<DataFilterList>.self)
    }
    
    func getDataFilterList(hostname: String, id: Int) async throws -> DataFilterList {
        let url = buildURL(hostname: hostname, path: "data_filter_list/\(id)/")
        return try await performRequest(url: url, responseType: DataFilterList.self)
    }
    
    func getAllCategories(hostname: String) async throws -> [String] {
        let url = buildURL(hostname: hostname, path: "data_filter_list/get_all_category/")
        return try await performRequest(url: url, responseType: [String].self)
    }
    
    // MARK: - Helper Methods
    
    func buildURL(hostname: String, path: String, queryItems: [URLQueryItem] = []) -> URL {
        // Ensure hostname ends with /
        let baseURL = hostname.hasSuffix("/") ? hostname : "\(hostname)/"
        
        guard var urlComponents = URLComponents(string: "\(baseURL)\(path)") else {
            fatalError("Invalid URL components")
        }
        
        if !queryItems.isEmpty {
            urlComponents.queryItems = queryItems
        }
        
        guard let url = urlComponents.url else {
            fatalError("Could not create URL")
        }
        
        return url
    }
    
    private func performRequest<T: Codable>(url: URL, responseType: T.Type) async throws -> T {
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        guard 200...299 ~= httpResponse.statusCode else {
            throw NetworkError.serverError(httpResponse.statusCode)
        }
        
        do {
            let decoder = JSONDecoder()
            return try decoder.decode(responseType, from: data)
        } catch {
            throw NetworkError.decodingError(error)
        }
    }
    
    private func performDataRequest(url: URL) async throws -> Data {
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        guard 200...299 ~= httpResponse.statusCode else {
            throw NetworkError.serverError(httpResponse.statusCode)
        }
        
        return data
    }
}

// MARK: - Network Errors

enum NetworkError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case serverError(Int)
    case decodingError(Error)
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response"
        case .serverError(let code):
            return "Server error: \(code)"
        case .decodingError(let error):
            return "Decoding error: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}
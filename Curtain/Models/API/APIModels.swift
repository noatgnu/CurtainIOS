//
//  APIModels.swift
//  Curtain
//
//  Created by Toan Phung on 02/08/2025.
//

import Foundation

// MARK: - Basic API Response Models (from actual Android code)

struct Curtain: Codable, Identifiable {
    let id: Int
    let created: String
    let linkId: String
    let file: String
    let enable: Bool
    let description: String
    let curtainType: String
    let encrypted: Bool
    let permanent: Bool
    let dataCite: DataCite?
    
    enum CodingKeys: String, CodingKey {
        case id, created, file, enable, description, encrypted, permanent
        case linkId = "link_id"
        case curtainType = "curtain_type"
        case dataCite = "data_cite"
    }
}

struct DataCite: Codable {
    let id: Int
    let title: String?
    let description: String?
}

struct DataFilterList: Codable, Identifiable {
    let id: Int
    let name: String
    let data: String
    let isDefault: Bool
    
    enum CodingKeys: String, CodingKey {
        case id, name, data
        case isDefault = "default"
    }
}

// MARK: - Request Models

struct CurtainUpdateRequest: Codable {
    let description: String
    let curtainType: String
    let enable: Bool
    let encrypted: Bool
    let permanent: Bool
    
    enum CodingKeys: String, CodingKey {
        case description, enable, encrypted, permanent
        case curtainType = "curtain_type"
    }
}

struct DataFilterListRequest: Codable {
    let name: String
    let category: String
    let data: String
    let isDefault: Bool
    
    enum CodingKeys: String, CodingKey {
        case name, category, data
        case isDefault = "default"
    }
}

// MARK: - Paginated Response Wrapper

struct PaginatedResponse<T: Codable>: Codable {
    let count: Int
    let next: String?
    let previous: String?
    let results: [T]
}
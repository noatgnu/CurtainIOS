//
//  CollectionAPIModels.swift
//  Curtain
//
//  Created by Toan Phung on 29/01/2026.
//

import Foundation

struct CurtainCollectionDto: Codable {
    let id: Int
    let created: String
    let updated: String
    let name: String
    let description: String
    let enable: Bool
    let owner: Int
    let ownerUsername: String
    let curtains: [Int]
    let curtainCount: Int
    let accessibleCurtains: [AccessibleCurtainDto]

    enum CodingKeys: String, CodingKey {
        case id, created, updated, name, description, enable, owner
        case ownerUsername = "owner_username"
        case curtains
        case curtainCount = "curtain_count"
        case accessibleCurtains = "accessible_curtains"
    }
}

struct AccessibleCurtainDto: Codable {
    let id: Int
    let linkId: String
    let name: String?
    let description: String
    let created: String
    let curtainType: String?

    enum CodingKeys: String, CodingKey {
        case id
        case linkId = "link_id"
        case name, description, created
        case curtainType = "curtain_type"
    }
}

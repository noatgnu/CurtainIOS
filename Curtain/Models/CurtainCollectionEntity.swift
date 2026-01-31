//
//  CurtainCollectionEntity.swift
//  Curtain
//
//  Created by Toan Phung on 29/01/2026.
//

import Foundation
import SwiftData

@Model
final class CurtainCollectionEntity: Identifiable, Hashable {
    @Attribute(.unique) var collectionId: Int
    var name: String
    var collectionDescription: String
    var enable: Bool
    var ownerUsername: String
    var curtainCount: Int
    var created: Date
    var updated: Date
    var sourceHostname: String
    var frontendURL: String?
    var lastFetched: Date

    @Relationship(deleteRule: .nullify, inverse: \CollectionSessionEntity.collections)
    var sessions: [CollectionSessionEntity]

    init(
        collectionId: Int,
        name: String,
        collectionDescription: String,
        enable: Bool,
        ownerUsername: String,
        curtainCount: Int,
        created: Date,
        updated: Date,
        sourceHostname: String,
        frontendURL: String? = nil,
        lastFetched: Date = Date()
    ) {
        self.collectionId = collectionId
        self.name = name
        self.collectionDescription = collectionDescription
        self.enable = enable
        self.ownerUsername = ownerUsername
        self.curtainCount = curtainCount
        self.created = created
        self.updated = updated
        self.sourceHostname = sourceHostname
        self.frontendURL = frontendURL
        self.lastFetched = lastFetched
        self.sessions = []
    }

    // MARK: - Identifiable
    var id: Int { collectionId }

    // MARK: - Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(collectionId)
    }

    static func == (lhs: CurtainCollectionEntity, rhs: CurtainCollectionEntity) -> Bool {
        lhs.collectionId == rhs.collectionId
    }
}

@Model
final class CollectionSessionEntity: Identifiable, Hashable {
    @Attribute(.unique) var linkId: String
    var apiId: Int
    var sessionName: String?
    var sessionDescription: String
    var created: Date
    var curtainType: String?
    var sourceHostname: String

    var collections: [CurtainCollectionEntity]

    init(
        linkId: String,
        apiId: Int,
        sessionName: String? = nil,
        sessionDescription: String,
        created: Date,
        curtainType: String? = nil,
        sourceHostname: String
    ) {
        self.linkId = linkId
        self.apiId = apiId
        self.sessionName = sessionName
        self.sessionDescription = sessionDescription
        self.created = created
        self.curtainType = curtainType
        self.sourceHostname = sourceHostname
        self.collections = []
    }

    // MARK: - Identifiable
    var id: String { linkId }

    // MARK: - Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(linkId)
    }

    static func == (lhs: CollectionSessionEntity, rhs: CollectionSessionEntity) -> Bool {
        lhs.linkId == rhs.linkId
    }
}

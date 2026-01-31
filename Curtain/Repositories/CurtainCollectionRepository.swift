//
//  CurtainCollectionRepository.swift
//  Curtain
//
//  Created by Toan Phung on 29/01/2026.
//

import Foundation
import SwiftData

@Observable
class CurtainCollectionRepository {
    private let modelContext: ModelContext
    private let networkManager: MultiHostNetworkManager

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.networkManager = MultiHostNetworkManager.shared
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

    // MARK: - Local Database Operations

    func getAllCollections() -> [CurtainCollectionEntity] {
        return performDatabaseOperation {
            let descriptor = FetchDescriptor<CurtainCollectionEntity>(
                sortBy: [SortDescriptor(\.updated, order: .reverse)]
            )
            return (try? modelContext.fetch(descriptor)) ?? []
        }
    }

    func getCollectionById(_ collectionId: Int) -> CurtainCollectionEntity? {
        return performDatabaseOperation {
            let predicate = #Predicate<CurtainCollectionEntity> { collection in
                collection.collectionId == collectionId
            }
            let descriptor = FetchDescriptor<CurtainCollectionEntity>(predicate: predicate)
            return try? modelContext.fetch(descriptor).first
        }
    }

    func getCollectionSessions(collectionId: Int) -> [CollectionSessionEntity] {
        return performDatabaseOperation {
            guard let collection = getCollectionById(collectionId) else { return [] }
            return collection.sessions
        }
    }

    func getSessionByLinkId(_ linkId: String) -> CollectionSessionEntity? {
        return performDatabaseOperation {
            let predicate = #Predicate<CollectionSessionEntity> { s in
                s.linkId == linkId
            }
            let descriptor = FetchDescriptor<CollectionSessionEntity>(predicate: predicate)
            return try? modelContext.fetch(descriptor).first
        }
    }

    func searchCollections(query: String) -> [CurtainCollectionEntity] {
        return performDatabaseOperation {
            let descriptor = FetchDescriptor<CurtainCollectionEntity>(
                sortBy: [SortDescriptor(\.updated, order: .reverse)]
            )
            let all = (try? modelContext.fetch(descriptor)) ?? []
            guard !query.isEmpty else { return all }
            return all.filter {
                $0.name.localizedCaseInsensitiveContains(query) ||
                $0.collectionDescription.localizedCaseInsensitiveContains(query) ||
                $0.ownerUsername.localizedCaseInsensitiveContains(query)
            }
        }
    }

    func insertCollectionWithSessions(collection: CurtainCollectionEntity, sessions: [CollectionSessionEntity]) {
        performDatabaseOperation {
            modelContext.insert(collection)
            for session in sessions {
                // Check if session already exists
                let linkId = session.linkId
                let predicate = #Predicate<CollectionSessionEntity> { s in
                    s.linkId == linkId
                }
                let descriptor = FetchDescriptor<CollectionSessionEntity>(predicate: predicate)
                if let existing = try? modelContext.fetch(descriptor).first {
                    if !existing.collections.contains(where: { $0.collectionId == collection.collectionId }) {
                        existing.collections.append(collection)
                    }
                    if !collection.sessions.contains(where: { $0.linkId == linkId }) {
                        collection.sessions.append(existing)
                    }
                } else {
                    modelContext.insert(session)
                    session.collections.append(collection)
                    collection.sessions.append(session)
                }
            }
            try? modelContext.save()
        }
    }

    func replaceCollectionSessions(collection: CurtainCollectionEntity, sessions: [CollectionSessionEntity]) {
        performDatabaseOperation {
            // Remove old session associations
            collection.sessions.removeAll()

            for session in sessions {
                let linkId = session.linkId
                let predicate = #Predicate<CollectionSessionEntity> { s in
                    s.linkId == linkId
                }
                let descriptor = FetchDescriptor<CollectionSessionEntity>(predicate: predicate)
                if let existing = try? modelContext.fetch(descriptor).first {
                    if !existing.collections.contains(where: { $0.collectionId == collection.collectionId }) {
                        existing.collections.append(collection)
                    }
                    collection.sessions.append(existing)
                } else {
                    modelContext.insert(session)
                    session.collections.append(collection)
                    collection.sessions.append(session)
                }
            }
            try? modelContext.save()
        }
    }

    func deleteCollection(collection: CurtainCollectionEntity) {
        performDatabaseOperation {
            modelContext.delete(collection)
            try? modelContext.save()
            cleanupOrphanedSessions()
        }
    }

    func cleanupOrphanedSessions() {
        performDatabaseOperation {
            let descriptor = FetchDescriptor<CollectionSessionEntity>()
            let allSessions = (try? modelContext.fetch(descriptor)) ?? []
            for session in allSessions where session.collections.isEmpty {
                modelContext.delete(session)
            }
            try? modelContext.save()
        }
    }

    // MARK: - Network + Database Operations

    func fetchCollectionFromApi(collectionId: Int, hostname: String, frontendURL: String? = nil) async throws -> CurtainCollectionEntity {
        let dto = try await networkManager.getCollectionById(hostname: hostname, collectionId: collectionId)
        return saveCollectionDto(dto, hostname: hostname, frontendURL: frontendURL)
    }

    func refreshCollection(collection: CurtainCollectionEntity) async throws -> CurtainCollectionEntity {
        let dto = try await networkManager.getCollectionById(
            hostname: collection.sourceHostname,
            collectionId: collection.collectionId
        )
        return updateCollectionFromDto(existing: collection, dto: dto)
    }

    // MARK: - DTO Mapping

    private func saveCollectionDto(_ dto: CurtainCollectionDto, hostname: String, frontendURL: String? = nil) -> CurtainCollectionEntity {
        return performDatabaseOperation {
            // Check if collection already exists
            if let existing = getCollectionById(dto.id) {
                return updateCollectionFromDto(existing: existing, dto: dto)
            }

            let entity = CurtainCollectionEntity(
                collectionId: dto.id,
                name: dto.name,
                collectionDescription: dto.description,
                enable: dto.enable,
                ownerUsername: dto.ownerUsername,
                curtainCount: dto.curtainCount,
                created: parseDate(dto.created),
                updated: parseDate(dto.updated),
                sourceHostname: hostname,
                frontendURL: frontendURL,
                lastFetched: Date()
            )

            let sessions = dto.accessibleCurtains.map { curtainDto in
                CollectionSessionEntity(
                    linkId: curtainDto.linkId,
                    apiId: curtainDto.id,
                    sessionName: curtainDto.name,
                    sessionDescription: curtainDto.description,
                    created: parseDate(curtainDto.created),
                    curtainType: curtainDto.curtainType,
                    sourceHostname: hostname
                )
            }

            insertCollectionWithSessions(collection: entity, sessions: sessions)
            return entity
        }
    }

    private func updateCollectionFromDto(existing: CurtainCollectionEntity, dto: CurtainCollectionDto) -> CurtainCollectionEntity {
        return performDatabaseOperation {
            existing.name = dto.name
            existing.collectionDescription = dto.description
            existing.enable = dto.enable
            existing.ownerUsername = dto.ownerUsername
            existing.curtainCount = dto.curtainCount
            existing.updated = parseDate(dto.updated)
            existing.lastFetched = Date()

            let sessions = dto.accessibleCurtains.map { curtainDto in
                CollectionSessionEntity(
                    linkId: curtainDto.linkId,
                    apiId: curtainDto.id,
                    sessionName: curtainDto.name,
                    sessionDescription: curtainDto.description,
                    created: parseDate(curtainDto.created),
                    curtainType: curtainDto.curtainType,
                    sourceHostname: existing.sourceHostname
                )
            }

            replaceCollectionSessions(collection: existing, sessions: sessions)
            return existing
        }
    }

    private func parseDate(_ dateString: String) -> Date {
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: dateString) ?? Date()
    }
}

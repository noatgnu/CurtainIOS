//
//  DOIViewModel.swift
//  Curtain
//
//  Created by Toan Phung on 07/01/2026.
//

import Foundation
import SwiftUI

@MainActor
@Observable
class DOIViewModel {
    enum LoadingState {
        case idle
        case loading(String)
        case collection(DataCiteMetadata, DOIParsedData)
        case loadingSession(String)
        case completed([String: Any])
        case error(Error)
    }

    var state: LoadingState = .idle
    var doi: String = ""

    private let doiService = DOIService.shared

    func loadDOI(_ doiString: String, sessionId: String? = nil) async {
        self.doi = doiString
        state = .loading("Fetching DOI metadata from DataCite...")

        do {
            let metadata = try await doiService.fetchMetadata(doi: doiString)

            guard !metadata.data.attributes.alternateIdentifiers.isEmpty else {
                throw DOIError.noAlternateIdentifiers
            }

            state = .loading("Parsing session data...")

            if let parsedData = await doiService.parseAlternateIdentifiers(metadata.data.attributes.alternateIdentifiers) {
                if let sessionId = sessionId {
                    try await loadSpecificSession(from: parsedData, sessionId: sessionId, metadata: metadata)
                } else if let collectionMetadata = parsedData.collectionMetadata,
                          !collectionMetadata.allSessionLinks.isEmpty {
                    state = .collection(metadata, parsedData)
                } else if let mainSessionUrl = parsedData.mainSessionUrl {
                    try await loadSessionFromURL(mainSessionUrl)
                } else {
                    try await tryAlternateIdentifiers(metadata.data.attributes.alternateIdentifiers)
                }
            } else {
                try await tryAlternateIdentifiers(metadata.data.attributes.alternateIdentifiers)
            }
        } catch {
            state = .error(error)
        }
    }

    func loadSessionFromURL(_ urlString: String) async throws {
        state = .loadingSession("Loading session data...")

        let sessionData = try await doiService.fetchSessionData(from: urlString)
        state = .completed(sessionData)
    }

    func loadSessionFromCollection(_ sessionUrl: String) async {
        do {
            try await loadSessionFromURL(sessionUrl)
        } catch {
            state = .error(error)
        }
    }

    private func loadSpecificSession(from parsedData: DOIParsedData, sessionId: String, metadata: DataCiteMetadata) async throws {
        if let collectionMetadata = parsedData.collectionMetadata {
            for session in collectionMetadata.allSessionLinks {
                if session.sessionId == sessionId {
                    try await loadSessionFromURL(session.sessionUrl)
                    return
                }
            }
        }

        throw DOIError.sessionDataFetchFailed
    }

    private func tryAlternateIdentifiers(_ identifiers: [AlternateIdentifier]) async throws {
        for identifier in identifiers.reversed() {
            if identifier.alternateIdentifierType.lowercased() == "url" {
                do {
                    try await loadSessionFromURL(identifier.alternateIdentifier)
                    return
                } catch {
                    continue
                }
            }
        }

        throw DOIError.noAlternateIdentifiers
    }

    func retry() async {
        await loadDOI(doi)
    }
}

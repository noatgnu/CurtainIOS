//
//  DOIService.swift
//  Curtain
//
//  Created by Toan Phung on 07/01/2026.
//

import Foundation

enum DOIError: Error, LocalizedError {
    case invalidDOI
    case metadataFetchFailed
    case noAlternateIdentifiers
    case sessionDataFetchFailed
    case invalidURL

    var errorDescription: String? {
        switch self {
        case .invalidDOI:
            return "Invalid DOI format"
        case .metadataFetchFailed:
            return "Failed to fetch DOI metadata"
        case .noAlternateIdentifiers:
            return "No alternate identifiers found in DOI"
        case .sessionDataFetchFailed:
            return "Failed to fetch session data from DOI"
        case .invalidURL:
            return "Invalid URL in alternate identifier"
        }
    }
}

class DOIService {
    static let shared = DOIService()

    private let dataciteBaseURL = "https://api.datacite.org/dois"

    private init() {}

    func fetchMetadata(doi: String) async throws -> DataCiteMetadata {
        let cleanDOI = doi.replacingOccurrences(of: "doi.org/", with: "")

        guard let url = URL(string: "\(dataciteBaseURL)/\(cleanDOI)") else {
            throw DOIError.invalidDOI
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw DOIError.metadataFetchFailed
        }

        let decoder = JSONDecoder()
        return try decoder.decode(DataCiteMetadata.self, from: data)
    }

    func parseAlternateIdentifiers(_ alternateIdentifiers: [AlternateIdentifier]) async -> DOIParsedData? {
        for identifier in alternateIdentifiers {
            if identifier.alternateIdentifierType.lowercased() == "url" {
                let urlString = identifier.alternateIdentifier

                if let parsedData = try? await fetchAndParseCollectionMetadata(from: urlString) {
                    return parsedData
                }

                return DOIParsedData(mainSessionUrl: urlString, collectionMetadata: nil)
            }
        }

        return nil
    }

    private func fetchAndParseCollectionMetadata(from urlString: String) async throws -> DOIParsedData? {
        guard let url = URL(string: urlString) else {
            return nil
        }

        let (data, _) = try await URLSession.shared.data(from: url)

        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let mainSessionUrl = json["mainSessionUrl"] as? String,
               let collectionData = json["collectionMetadata"] as? [String: Any] {

                let title = collectionData["title"] as? String
                let description = collectionData["description"] as? String
                var sessionLinks: [DOISessionLink] = []

                if let allSessions = collectionData["allSessionLinks"] as? [[String: Any]] {
                    for session in allSessions {
                        if let sessionId = session["sessionId"] as? String,
                           let sessionUrl = session["sessionUrl"] as? String {
                            let sessionTitle = session["title"] as? String
                            sessionLinks.append(DOISessionLink(
                                sessionId: sessionId,
                                sessionUrl: sessionUrl,
                                title: sessionTitle
                            ))
                        }
                    }
                }

                let metadata = DOICollectionMetadata(
                    title: title,
                    description: description,
                    allSessionLinks: sessionLinks
                )

                return DOIParsedData(mainSessionUrl: mainSessionUrl, collectionMetadata: metadata)
            }
        }

        return nil
    }

    func fetchSessionData(from urlString: String) async throws -> [String: Any] {
        guard let url = URL(string: urlString) else {
            throw DOIError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw DOIError.sessionDataFetchFailed
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw DOIError.sessionDataFetchFailed
        }

        return json
    }

    func loadSessionFromDOI(doi: String, sessionId: String? = nil) async throws -> [String: Any] {
        let metadata = try await fetchMetadata(doi: doi)

        guard !metadata.data.attributes.alternateIdentifiers.isEmpty else {
            throw DOIError.noAlternateIdentifiers
        }

        if let parsedData = await parseAlternateIdentifiers(metadata.data.attributes.alternateIdentifiers) {
            if let sessionId = sessionId,
               let collectionMetadata = parsedData.collectionMetadata {
                for session in collectionMetadata.allSessionLinks {
                    if session.sessionId == sessionId {
                        return try await fetchSessionData(from: session.sessionUrl)
                    }
                }
            }

            if let mainSessionUrl = parsedData.mainSessionUrl {
                return try await fetchSessionData(from: mainSessionUrl)
            }
        }

        for identifier in metadata.data.attributes.alternateIdentifiers.reversed() {
            if identifier.alternateIdentifierType.lowercased() == "url" {
                do {
                    return try await fetchSessionData(from: identifier.alternateIdentifier)
                } catch {
                    continue
                }
            }
        }

        throw DOIError.noAlternateIdentifiers
    }
}

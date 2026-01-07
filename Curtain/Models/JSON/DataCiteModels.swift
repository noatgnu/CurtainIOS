//
//  DataCiteModels.swift
//  Curtain
//
//  Created by Toan Phung on 07/01/2026.
//

import Foundation

struct DataCiteMetadata: Codable {
    let data: DataCiteMetadataData
}

struct DataCiteMetadataData: Codable {
    let id: String
    let type: String
    let attributes: DataCiteMetadataAttributes
}

struct DataCiteMetadataAttributes: Codable {
    let doi: String
    let prefix: String
    let suffix: String
    let identifiers: [String]?
    let alternateIdentifiers: [AlternateIdentifier]
    let creators: [DataCiteCreator]
    let titles: [DataCiteTitle]
    let publisher: String?
    let publicationYear: Int?
    let descriptions: [DataCiteDescription]?
    let url: String?
    let state: String?
    let created: String?
    let updated: String?
}

struct AlternateIdentifier: Codable {
    let alternateIdentifier: String
    let alternateIdentifierType: String
}

struct DataCiteCreator: Codable {
    let name: String
    let affiliation: [String]?
    let nameIdentifiers: [String]?
}

struct DataCiteTitle: Codable {
    let title: String
}

struct DataCiteDescription: Codable {
    let description: String
    let descriptionType: String?
}

struct DOIParsedData {
    let mainSessionUrl: String?
    let collectionMetadata: DOICollectionMetadata?
}

struct DOICollectionMetadata {
    let title: String?
    let description: String?
    let allSessionLinks: [DOISessionLink]
}

struct DOISessionLink {
    let sessionId: String
    let sessionUrl: String
    let title: String?
}

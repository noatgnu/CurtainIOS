//
//  CurtainEntity.swift
//  Curtain
//
//  Created by Toan Phung on 02/08/2025.
//

import Foundation
import SwiftData

@Model
final class CurtainEntity {
    @Attribute(.unique) var linkId: String
    var created: Date
    var updated: Date
    var file: String?
    var dataDescription: String
    var enable: Bool
    var curtainType: String
    var sourceHostname: String
    var frontendURL: String?
    var isPinned: Bool
    
    init(linkId: String, created: Date = Date(), updated: Date = Date(), file: String? = nil, dataDescription: String, enable: Bool = true, curtainType: String, sourceHostname: String, frontendURL: String? = nil, isPinned: Bool = false) {
        self.linkId = linkId
        self.created = created
        self.updated = updated
        self.file = file
        self.dataDescription = dataDescription
        self.enable = enable
        self.curtainType = curtainType
        self.sourceHostname = sourceHostname
        self.frontendURL = frontendURL
        self.isPinned = isPinned
    }
}

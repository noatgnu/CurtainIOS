//
//  CurtainSiteSettings.swift
//  Curtain
//
//  Created by Toan Phung on 02/08/2025.
//

import Foundation
import SwiftData

@Model
final class CurtainSiteSettings {
    @Attribute(.unique) var hostname: String
    var lastSync: Date
    var active: Bool
    var apiKey: String?
    var notes: String?
    var siteDescription: String?
    var requiresAuthentication: Bool
    var createdAt: Date
    
    // Computed property for backward compatibility
    var isActive: Bool {
        get { active }
        set { active = newValue }
    }
    
    // Computed property for backward compatibility
    var description: String {
        get { siteDescription ?? "" }
        set { siteDescription = newValue.isEmpty ? nil : newValue }
    }
    
    init(hostname: String, lastSync: Date = Date(), active: Bool = true, apiKey: String? = nil, notes: String? = nil, siteDescription: String? = nil, requiresAuthentication: Bool = false, createdAt: Date = Date()) {
        self.hostname = hostname
        self.lastSync = lastSync
        self.active = active
        self.apiKey = apiKey
        self.notes = notes
        self.siteDescription = siteDescription
        self.requiresAuthentication = requiresAuthentication
        self.createdAt = createdAt
    }
}
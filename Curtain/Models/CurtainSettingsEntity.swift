//
//  CurtainSettingsEntity.swift
//  Curtain
//
//  Created by Toan Phung on 10/01/2026.
//

import Foundation
import SwiftData

@Model
final class CurtainSettingsEntity: Identifiable {
    @Attribute(.unique) var linkId: String
    
    // Store configurations as JSON Data
    var settingsData: Data
    var rawFormData: Data
    var differentialFormData: Data
    
    // Cache for decoded objects (not persisted)
    @Transient var cachedSettings: CurtainSettings?
    @Transient var cachedRawForm: CurtainRawForm?
    @Transient var cachedDifferentialForm: CurtainDifferentialForm?
    
    init(linkId: String, settings: CurtainSettings, rawForm: CurtainRawForm, differentialForm: CurtainDifferentialForm) {
        self.linkId = linkId
        
        // Encode to Data
        do {
            self.settingsData = try JSONEncoder().encode(settings)
            self.rawFormData = try JSONEncoder().encode(rawForm)
            self.differentialFormData = try JSONEncoder().encode(differentialForm)
        } catch {
            print("Error encoding settings: \(error)")
            self.settingsData = Data()
            self.rawFormData = Data()
            self.differentialFormData = Data()
        }
        
        self.cachedSettings = settings
        self.cachedRawForm = rawForm
        self.cachedDifferentialForm = differentialForm
    }
    
    // MARK: - Decoders
    
    func getSettings() -> CurtainSettings? {
        if let cached = cachedSettings { return cached }
        
        do {
            let decoded = try JSONDecoder().decode(CurtainSettings.self, from: settingsData)
            cachedSettings = decoded
            return decoded
        } catch {
            print("Error decoding settings for \(linkId): \(error)")
            return nil
        }
    }
    
    func getRawForm() -> CurtainRawForm? {
        if let cached = cachedRawForm { return cached }
        
        do {
            let decoded = try JSONDecoder().decode(CurtainRawForm.self, from: rawFormData)
            cachedRawForm = decoded
            return decoded
        } catch {
            print("Error decoding rawForm for \(linkId): \(error)")
            return nil
        }
    }
    
    func getDifferentialForm() -> CurtainDifferentialForm? {
        if let cached = cachedDifferentialForm { return cached }
        
        do {
            let decoded = try JSONDecoder().decode(CurtainDifferentialForm.self, from: differentialFormData)
            cachedDifferentialForm = decoded
            return decoded
        } catch {
            print("Error decoding differentialForm for \(linkId): \(error)")
            return nil
        }
    }
    
    // MARK: - Update Methods
    
    func updateSettings(_ settings: CurtainSettings) {
        do {
            self.settingsData = try JSONEncoder().encode(settings)
            self.cachedSettings = settings
        } catch {
            print("Error updating settings: \(error)")
        }
    }
}

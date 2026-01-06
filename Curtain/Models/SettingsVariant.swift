//
//  SettingsVariant.swift
//  Curtain
//
//  Created by Toan Phung on 06/08/2025.
//

import Foundation

// MARK: - Settings Variant Model

struct SettingsVariant: Codable, Identifiable {
    let id: String
    let name: String
    let description: String
    let dateCreated: Date
    let dateModified: Date
    
    // Store the complete serialized CurtainSettings as JSON data
    private let settingsData: Data
    
    // Quick access properties for UI display (derived from stored settings)
    var pCutoff: Double {
        return storedSettingsDict["pCutoff"] as? Double ?? 0.05
    }
    
    var log2FCCutoff: Double {
        return storedSettingsDict["log2FCCutoff"] as? Double ?? 0.6
    }
    
    var academic: Bool {
        return storedSettingsDict["academic"] as? Bool ?? false
    }
    
    // Helper to get stored settings as dictionary
    private var storedSettingsDict: [String: Any] {
        do {
            guard let dict = try JSONSerialization.jsonObject(with: settingsData) as? [String: Any] else {
                print("❌ SettingsVariant: Failed to deserialize settings dictionary")
                return [:]
            }
            return dict
        } catch {
            print("❌ SettingsVariant: Failed to deserialize stored settings: \(error)")
            return [:]
        }
    }
    
    // Computed property to reconstruct CurtainSettings from stored dictionary
    private var storedSettings: CurtainSettings? {
        // Reconstruct CurtainSettings from the stored dictionary
        return SettingsVariant.reconstructSettings(from: storedSettingsDict)
    }
    
    // Helper method to reconstruct CurtainSettings from dictionary
    // This mirrors the logic in CurtainDataService.manualDeserializeSettingsFromMap
    private static func reconstructSettings(from map: [String: Any]) -> CurtainSettings? {
        // Complete reconstruction of CurtainSettings with all properties including textAnnotation
        return CurtainSettings(
            fetchUniprot: map["fetchUniprot"] as? Bool ?? true,
            inputDataCols: map["inputDataCols"] as? [String: Any] ?? [:],
            probabilityFilterMap: map["probabilityFilterMap"] as? [String: Any] ?? [:],
            barchartColorMap: map["barchartColorMap"] as? [String: Any] ?? [:],
            pCutoff: map["pCutoff"] as? Double ?? 0.05,
            log2FCCutoff: map["log2FCCutoff"] as? Double ?? 0.6,
            description: map["description"] as? String ?? "",
            uniprot: map["uniprot"] as? Bool ?? false,
            colorMap: map["colorMap"] as? [String: String] ?? [:],
            academic: map["academic"] as? Bool ?? false,
            backGroundColorGrey: map["backGroundColorGrey"] as? Bool ?? false,
            currentComparison: map["currentComparison"] as? String ?? "",
            version: map["version"] as? Double ?? 2.0,
            currentId: map["currentID"] as? String ?? "",
            fdrCurveText: map["fdrCurveText"] as? String ?? "",
            fdrCurveTextEnable: map["fdrCurveTextEnable"] as? Bool ?? false,
            prideAccession: map["prideAccession"] as? String ?? "",
            project: parseProject(map["project"]),
            sampleOrder: map["sampleOrder"] as? [String: [String]] ?? [:],
            sampleVisible: map["sampleVisible"] as? [String: Bool] ?? [:],
            conditionOrder: map["conditionOrder"] as? [String] ?? [],
            sampleMap: map["sampleMap"] as? [String: [String: String]] ?? [:],
            volcanoAxis: parseVolcanoAxis(map["volcanoAxis"]),
            textAnnotation: map["textAnnotation"] as? [String: Any] ?? [:], // CRITICAL: Include textAnnotation
            volcanoPlotTitle: map["volcanoPlotTitle"] as? String ?? "",
            visible: map["visible"] as? [String: Any] ?? [:],
            volcanoPlotGrid: parseVolcanoPlotGrid(map["volcanoPlotGrid"]),
            volcanoPlotDimension: parseVolcanoPlotDimension(map["volcanoPlotDimension"]),
            volcanoAdditionalShapes: map["volcanoAdditionalShapes"] as? [Any] ?? [],
            volcanoPlotLegendX: map["volcanoPlotLegendX"] as? Double,
            volcanoPlotLegendY: map["volcanoPlotLegendY"] as? Double,
            defaultColorList: map["defaultColorList"] as? [String] ?? CurtainSettings.defaultColors(),
            scatterPlotMarkerSize: map["scatterPlotMarkerSize"] as? Double ?? 10.0,
            plotFontFamily: map["plotFontFamily"] as? String ?? "Arial",
            stringDBColorMap: map["stringDBColorMap"] as? [String: String] ?? CurtainSettings.defaultStringDBColors(),
            interactomeAtlasColorMap: map["interactomeAtlasColorMap"] as? [String: String] ?? CurtainSettings.defaultInteractomeColors(),
            proteomicsDBColor: map["proteomicsDBColor"] as? String ?? "#ff7f0e",
            networkInteractionSettings: map["networkInteractionSettings"] as? [String: String] ?? CurtainSettings.defaultNetworkInteractionSettings(),
            rankPlotColorMap: map["rankPlotColorMap"] as? [String: Any] ?? [:],
            rankPlotAnnotation: map["rankPlotAnnotation"] as? [String: Any] ?? [:],
            legendStatus: map["legendStatus"] as? [String: Any] ?? [:],
            selectedComparison: map["selectedComparison"] as? [String],
            imputationMap: map["imputationMap"] as? [String: Any] ?? [:],
            enableImputation: map["enableImputation"] as? Bool ?? false,
            viewPeptideCount: map["viewPeptideCount"] as? Bool ?? false,
            peptideCountData: map["peptideCountData"] as? [String: Any] ?? [:]
        )
    }
    
    // Helper parsing methods for complex objects (matching CurtainDataService logic)
    private static func parseProject(_ data: Any?) -> Project {
        guard let map = data as? [String: Any] else {
            return Project()
        }
        
        return Project(
            title: map["title"] as? String ?? "",
            projectDescription: map["projectDescription"] as? String ?? "",
            organisms: parseNameItemList(map["organisms"]),
            organismParts: parseNameItemList(map["organismParts"]),
            cellTypes: parseNameItemList(map["cellTypes"]),
            diseases: parseNameItemList(map["diseases"]),
            sampleProcessingProtocol: map["sampleProcessingProtocol"] as? String ?? "",
            dataProcessingProtocol: map["dataProcessingProtocol"] as? String ?? "",
            accession: map["accession"] as? String ?? "",
            sampleAnnotations: map["sampleAnnotations"] as? [String: Any] ?? [:]
        )
    }
    
    private static func parseNameItemList(_ data: Any?) -> [NameItem] {
        guard let array = data as? [[String: Any]] else {
            return [NameItem()]
        }
        
        return array.map { item in
            NameItem(
                name: item["name"] as? String ?? "",
                cvLabel: item["cvLabel"] as? String
            )
        }
    }
    
    private static func parseVolcanoAxis(_ data: Any?) -> VolcanoAxis {
        guard let map = data as? [String: Any] else {
            return VolcanoAxis()
        }
        
        return VolcanoAxis(
            minX: (map["minX"] as? NSNumber)?.doubleValue,
            maxX: (map["maxX"] as? NSNumber)?.doubleValue,
            minY: (map["minY"] as? NSNumber)?.doubleValue,
            maxY: (map["maxY"] as? NSNumber)?.doubleValue,
            x: map["x"] as? String ?? "Log2FC",
            y: map["y"] as? String ?? "-log10(p-value)",
            dtickX: (map["dtickX"] as? NSNumber)?.doubleValue,
            dtickY: (map["dtickY"] as? NSNumber)?.doubleValue,
            ticklenX: map["ticklenX"] as? Int ?? 5,
            ticklenY: map["ticklenY"] as? Int ?? 5
        )
    }
    
    private static func parseVolcanoPlotGrid(_ data: Any?) -> [String: Bool] {
        guard let map = data as? [String: Any] else {
            return ["x": true, "y": true]
        }
        
        return [
            "x": map["x"] as? Bool ?? true,
            "y": map["y"] as? Bool ?? true
        ]
    }
    
    private static func parseVolcanoPlotDimension(_ data: Any?) -> VolcanoPlotDimension {
        guard let map = data as? [String: Any] else {
            return VolcanoPlotDimension()
        }
        
        return VolcanoPlotDimension(
            width: map["width"] as? Int ?? 800,
            height: map["height"] as? Int ?? 1000,
            margin: parseVolcanoPlotMargin(map["margin"])
        )
    }
    
    private static func parseVolcanoPlotMargin(_ data: Any?) -> VolcanoPlotMargin {
        guard let map = data as? [String: Any] else {
            return VolcanoPlotMargin()
        }
        
        return VolcanoPlotMargin(
            left: map["l"] as? Int,
            right: map["r"] as? Int,
            bottom: map["b"] as? Int,
            top: map["t"] as? Int
        )
    }
    
    init(
        id: String = UUID().uuidString,
        name: String,
        description: String = "",
        dateCreated: Date = Date(),
        dateModified: Date = Date(),
        from curtainSettings: CurtainSettings,
        selectedMap: [String: [String: Bool]]? = nil,
        selectionsName: [String]? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.dateCreated = dateCreated
        self.dateModified = dateModified
        
        // Serialize the complete CurtainSettings object + selection data using its toDictionary method
        do {
            var settingsDict = curtainSettings.toDictionary()
            // Add selection data to the settings dictionary
            if let selectedMap = selectedMap {
                settingsDict["selectedMap"] = selectedMap
            }
            if let selectionsName = selectionsName {
                settingsDict["selectionsName"] = selectionsName
            }
            self.settingsData = try JSONSerialization.data(withJSONObject: settingsDict, options: [])
            print("✅ SettingsVariant: Serialized settings with \(selectedMap?.count ?? 0) selected proteins and \(selectionsName?.count ?? 0) selection groups")
        } catch {
            print("❌ SettingsVariant: Failed to serialize CurtainSettings: \(error)")
            // Fallback to empty data
            self.settingsData = Data()
        }
    }
    
    /// Apply this variant's settings to a CurtainSettings object
    /// Preserves data-specific properties while applying variant settings
    func appliedTo(_ settings: CurtainSettings) -> CurtainSettings {
        guard let variantSettings = storedSettings else {
            print("❌ SettingsVariant: Could not decode stored settings, returning current settings")
            return settings
        }
        
        // Create new settings using the stored variant settings as base
        // but preserve certain data-specific properties from current settings
        return CurtainSettings(
            fetchUniprot: variantSettings.fetchUniprot,
            inputDataCols: settings.inputDataCols, // Preserve: data-specific
            probabilityFilterMap: settings.probabilityFilterMap, // Preserve: data-specific
            barchartColorMap: variantSettings.barchartColorMap.isEmpty ? settings.barchartColorMap : variantSettings.barchartColorMap, // Apply: condition colors from variant, fallback to current if variant has none
            pCutoff: variantSettings.pCutoff,
            log2FCCutoff: variantSettings.log2FCCutoff,
            description: settings.description, // Preserve: dataset description
            uniprot: variantSettings.uniprot,
            colorMap: variantSettings.colorMap, // Apply: selection colors from variant
            academic: variantSettings.academic,
            backGroundColorGrey: variantSettings.backGroundColorGrey,
            currentComparison: settings.currentComparison, // Preserve: data-specific
            version: settings.version, // Preserve: data version
            currentId: settings.currentId, // Preserve: dataset ID
            fdrCurveText: variantSettings.fdrCurveText,
            fdrCurveTextEnable: variantSettings.fdrCurveTextEnable,
            prideAccession: settings.prideAccession, // Preserve: data-specific
            project: settings.project, // Preserve: data-specific
            sampleOrder: settings.sampleOrder, // Preserve: data-specific
            sampleVisible: settings.sampleVisible, // Preserve: data-specific
            conditionOrder: settings.conditionOrder, // Preserve: data-specific
            sampleMap: settings.sampleMap, // Preserve: data-specific
            volcanoAxis: variantSettings.volcanoAxis,
            textAnnotation: variantSettings.textAnnotation, // Apply: variant annotations
            volcanoPlotTitle: variantSettings.volcanoPlotTitle,
            visible: settings.visible, // Preserve: current visibility state
            volcanoPlotGrid: variantSettings.volcanoPlotGrid,
            volcanoPlotDimension: variantSettings.volcanoPlotDimension,
            volcanoAdditionalShapes: variantSettings.volcanoAdditionalShapes,
            volcanoPlotLegendX: variantSettings.volcanoPlotLegendX,
            volcanoPlotLegendY: variantSettings.volcanoPlotLegendY,
            defaultColorList: variantSettings.defaultColorList,
            scatterPlotMarkerSize: variantSettings.scatterPlotMarkerSize,
            plotFontFamily: variantSettings.plotFontFamily,
            stringDBColorMap: variantSettings.stringDBColorMap,
            interactomeAtlasColorMap: variantSettings.interactomeAtlasColorMap,
            proteomicsDBColor: variantSettings.proteomicsDBColor,
            networkInteractionSettings: variantSettings.networkInteractionSettings,
            rankPlotColorMap: variantSettings.rankPlotColorMap,
            rankPlotAnnotation: variantSettings.rankPlotAnnotation,
            legendStatus: variantSettings.legendStatus,
            selectedComparison: settings.selectedComparison, // Preserve: data-specific
            imputationMap: settings.imputationMap, // Preserve: data-specific
            enableImputation: variantSettings.enableImputation,
            viewPeptideCount: variantSettings.viewPeptideCount,
            peptideCountData: settings.peptideCountData // Preserve: data-specific
        )
    }
    
    /// Get stored selection map from this variant
    func getStoredSelectedMap() -> [String: [String: Bool]]? {
        return storedSettingsDict["selectedMap"] as? [String: [String: Bool]]
    }
    
    /// Get stored selection names from this variant
    func getStoredSelectionsName() -> [String]? {
        return storedSettingsDict["selectionsName"] as? [String]
    }
}

// MARK: - Settings Variant Manager

class SettingsVariantManager: ObservableObject {
    static let shared = SettingsVariantManager()
    
    @Published var savedVariants: [SettingsVariant] = []
    
    private let userDefaults = UserDefaults.standard
    private let variantsKey = "CurtainSettingsVariants"
    
    private init() {
        loadVariants()
    }
    
    // MARK: - Core Operations
    
    func saveVariant(_ variant: SettingsVariant) {
        // Check if variant with same ID exists and update it
        if let existingIndex = savedVariants.firstIndex(where: { $0.id == variant.id }) {
            var updatedVariant = variant
            updatedVariant = SettingsVariant(
                id: variant.id,
                name: variant.name,
                description: variant.description,
                dateCreated: savedVariants[existingIndex].dateCreated,
                dateModified: Date(),
                from: variant.appliedTo(CurtainSettings()) // This is a bit hacky but works for our use case
            )
            savedVariants[existingIndex] = updatedVariant
        } else {
            // Add new variant
            savedVariants.append(variant)
        }
        
        persistVariants()
        print("✅ SettingsVariantManager: Saved variant '\(variant.name)' (ID: \(variant.id))")
    }
    
    func deleteVariant(withId id: String) {
        savedVariants.removeAll { $0.id == id }
        persistVariants()
        print("🗑️ SettingsVariantManager: Deleted variant with ID: \(id)")
    }
    
    func deleteVariant(_ variant: SettingsVariant) {
        deleteVariant(withId: variant.id)
    }
    
    func loadVariant(withId id: String) -> SettingsVariant? {
        return savedVariants.first { $0.id == id }
    }
    
    func duplicateVariant(_ variant: SettingsVariant, newName: String) -> SettingsVariant {
        let duplicate = SettingsVariant(
            name: newName,
            description: variant.description,
            from: variant.appliedTo(CurtainSettings())
        )
        saveVariant(duplicate)
        return duplicate
    }
    
    // MARK: - Convenience Methods
    
    var sortedVariants: [SettingsVariant] {
        return savedVariants.sorted { $0.dateModified > $1.dateModified }
    }
    
    // MARK: - Persistence
    
    private func persistVariants() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(savedVariants)
            userDefaults.set(data, forKey: variantsKey)
            print("💾 SettingsVariantManager: Persisted \(savedVariants.count) variants")
        } catch {
            print("❌ SettingsVariantManager: Failed to persist variants: \(error)")
        }
    }
    
    private func loadVariants() {
        guard let data = userDefaults.data(forKey: variantsKey) else {
            print("📂 SettingsVariantManager: No saved variants found")
            return
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            savedVariants = try decoder.decode([SettingsVariant].self, from: data)
            print("📂 SettingsVariantManager: Loaded \(savedVariants.count) variants")
        } catch {
            print("❌ SettingsVariantManager: Failed to load variants: \(error)")
            savedVariants = []
        }
    }
    
    // MARK: - Export/Import
    
    func exportVariant(_ variant: SettingsVariant) -> Data? {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            encoder.dateEncodingStrategy = .iso8601
            return try encoder.encode(variant)
        } catch {
            print("❌ SettingsVariantManager: Failed to export variant: \(error)")
            return nil
        }
    }
    
    func importVariant(from data: Data) -> SettingsVariant? {
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let variant = try decoder.decode(SettingsVariant.self, from: data)
            
            // Generate new ID to avoid conflicts
            let importedVariant = SettingsVariant(
                name: "\(variant.name) (Imported)",
                description: variant.description,
                from: variant.appliedTo(CurtainSettings())
            )
            
            saveVariant(importedVariant)
            return importedVariant
        } catch {
            print("❌ SettingsVariantManager: Failed to import variant: \(error)")
            return nil
        }
    }
}
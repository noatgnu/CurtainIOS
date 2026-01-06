//
//  CurtainDataProcessor.swift
//  Curtain
//
//  Created by Toan Phung on 05/08/2025.
//

import Foundation

class CurtainDataProcessor {
    
    /// Process raw CSV data to create essential metadata structures
    /// This is the iOS equivalent of Android's processRawData() method
    static func processRawData(_ curtainData: CurtainData) -> CurtainSettings {
        print("🔄 CurtainDataProcessor: Starting raw data processing")
        
        guard let rawCSV = curtainData.raw, !rawCSV.isEmpty else {
            print("❌ CurtainDataProcessor: No raw CSV data available")
            return curtainData.settings
        }
        
        let samples = curtainData.rawForm.samples
        guard !samples.isEmpty else {
            print("❌ CurtainDataProcessor: No samples defined in rawForm")
            return curtainData.settings
        }
        
        print("🔄 CurtainDataProcessor: Processing \(samples.count) samples")
        
        var conditions = [String]()
        var colorMap = [String: String]()
        var colorPosition = 0
        var sampleMap = [String: [String: String]]()
        var sampleOrder = [String: [String]]()
        var sampleVisible = [String: Bool]()
        
        // Process each sample to extract condition information
        for sample in samples {
            print("🔄 CurtainDataProcessor: Processing sample: \(sample)")
            
            // Extract condition from sample name (Android logic: split on "." and take all but last part)
            let parts = sample.components(separatedBy: ".")
            let replicate = parts.last ?? ""
            let condition = parts.count > 1 ? parts.dropLast().joined(separator: ".") : ""
            
            // Use existing condition mapping if available, otherwise use extracted condition
            let actualCondition = curtainData.settings.sampleMap[sample]?["condition"] ?? condition
            
            print("🔄 CurtainDataProcessor: Sample \(sample) -> condition: '\(actualCondition)', replicate: '\(replicate)'")
            
            // Add new conditions to the list and assign colors
            if !actualCondition.isEmpty && !conditions.contains(actualCondition) {
                conditions.append(actualCondition)
                
                // Cycle through default colors (Android logic)
                if colorPosition >= curtainData.settings.defaultColorList.count {
                    colorPosition = 0
                }
                colorMap[actualCondition] = curtainData.settings.defaultColorList[colorPosition]
                colorPosition += 1
                
                print("🔄 CurtainDataProcessor: Added condition '\(actualCondition)' with color \(colorMap[actualCondition] ?? "none")")
            }
            
            // Build sample order for this condition
            if sampleOrder[actualCondition] == nil {
                sampleOrder[actualCondition] = []
            }
            if !sampleOrder[actualCondition]!.contains(sample) {
                sampleOrder[actualCondition]!.append(sample)
            }
            
            // Set sample visibility (default to true)
            if sampleVisible[sample] == nil {
                sampleVisible[sample] = true
            }
            
            // Create sample mapping info
            sampleMap[sample] = [
                "replicate": replicate,
                "condition": actualCondition,
                "name": sample
            ]
        }
        
        print("🔄 CurtainDataProcessor: Discovered \(conditions.count) conditions: \(conditions)")
        print("🔄 CurtainDataProcessor: Created sampleMap with \(sampleMap.count) entries")
        print("🔄 CurtainDataProcessor: Created sampleOrder: \(sampleOrder.mapValues { $0.count })")
        print("🔄 CurtainDataProcessor: Created sampleVisible with \(sampleVisible.count) entries")
        
        // Merge with existing settings (Android logic)
        let updatedSettings = mergeWithExistingSettings(
            currentSettings: curtainData.settings,
            newConditions: conditions,
            newColorMap: colorMap,
            newSampleMap: sampleMap,
            newSampleOrder: sampleOrder,
            newSampleVisible: sampleVisible
        )
        
        print("✅ CurtainDataProcessor: Raw data processing complete")
        return updatedSettings
    }
    
    /// Merge new metadata with existing settings (Android logic)
    private static func mergeWithExistingSettings(
        currentSettings: CurtainSettings,
        newConditions: [String],
        newColorMap: [String: String],
        newSampleMap: [String: [String: String]],
        newSampleOrder: [String: [String]],
        newSampleVisible: [String: Bool]
    ) -> CurtainSettings {
        
        // Merge condition order (preserve existing order, add new conditions)
        var finalConditionOrder = [String]()
        
        if currentSettings.conditionOrder.isEmpty {
            finalConditionOrder = newConditions
        } else {
            // Keep existing order for conditions still present
            for condition in currentSettings.conditionOrder {
                if newConditions.contains(condition) {
                    finalConditionOrder.append(condition)
                }
            }
            // Add any new conditions
            for condition in newConditions {
                if !finalConditionOrder.contains(condition) {
                    finalConditionOrder.append(condition)
                }
            }
        }
        
        // Merge color map (preserve existing colors, add new ones)
        var finalColorMap = currentSettings.colorMap
        for (condition, color) in newColorMap {
            if finalColorMap[condition] == nil {
                finalColorMap[condition] = color
            }
        }
        
        // Merge sample map (remove missing samples, add new ones)
        var finalSampleMap = currentSettings.sampleMap
        if currentSettings.sampleMap.isEmpty {
            finalSampleMap = newSampleMap
        } else {
            // Remove missing samples
            let currentSampleKeys = Set(newSampleMap.keys)
            finalSampleMap = finalSampleMap.filter { currentSampleKeys.contains($0.key) }
            
            // Add new samples
            for (sample, info) in newSampleMap {
                if finalSampleMap[sample] == nil {
                    finalSampleMap[sample] = info
                }
            }
        }
        
        // Merge sample order (preserve existing, add new)
        var finalSampleOrder = currentSettings.sampleOrder
        for (condition, samples) in newSampleOrder {
            if finalSampleOrder[condition] == nil {
                finalSampleOrder[condition] = samples
            } else {
                // Merge sample lists, preserving existing order
                var updatedSamples = finalSampleOrder[condition] ?? []
                for sample in samples {
                    if !updatedSamples.contains(sample) {
                        updatedSamples.append(sample)
                    }
                }
                finalSampleOrder[condition] = updatedSamples
            }
        }
        
        // Clean up sample order for removed conditions
        finalSampleOrder = finalSampleOrder.filter { finalConditionOrder.contains($0.key) }
        
        // Merge sample visibility (preserve existing, add new)
        var finalSampleVisible = currentSettings.sampleVisible
        for (sample, visible) in newSampleVisible {
            if finalSampleVisible[sample] == nil {
                finalSampleVisible[sample] = visible
            }
        }
        
        // Clean up sample visibility for removed samples
        let currentSampleKeys = Set(newSampleMap.keys)
        finalSampleVisible = finalSampleVisible.filter { currentSampleKeys.contains($0.key) }
        
        print("🔄 CurtainDataProcessor: Final conditionOrder: \(finalConditionOrder)")
        print("🔄 CurtainDataProcessor: Final colorMap: \(finalColorMap)")
        print("🔄 CurtainDataProcessor: Final sampleMap count: \(finalSampleMap.count)")
        print("🔄 CurtainDataProcessor: Final sampleOrder: \(finalSampleOrder.mapValues { $0.count })")
        print("🔄 CurtainDataProcessor: Final sampleVisible count: \(finalSampleVisible.count)")
        
        // Create updated settings
        return CurtainSettings(
            fetchUniprot: currentSettings.fetchUniprot,
            inputDataCols: currentSettings.inputDataCols,
            probabilityFilterMap: currentSettings.probabilityFilterMap,
            barchartColorMap: currentSettings.barchartColorMap,
            pCutoff: currentSettings.pCutoff,
            log2FCCutoff: currentSettings.log2FCCutoff,
            description: currentSettings.description,
            uniprot: currentSettings.uniprot,
            colorMap: finalColorMap,
            academic: currentSettings.academic,
            backGroundColorGrey: currentSettings.backGroundColorGrey,
            currentComparison: currentSettings.currentComparison,
            version: currentSettings.version,
            currentId: currentSettings.currentId,
            fdrCurveText: currentSettings.fdrCurveText,
            fdrCurveTextEnable: currentSettings.fdrCurveTextEnable,
            prideAccession: currentSettings.prideAccession,
            project: currentSettings.project,
            sampleOrder: finalSampleOrder,
            sampleVisible: finalSampleVisible,
            conditionOrder: finalConditionOrder,
            sampleMap: finalSampleMap,
            volcanoAxis: currentSettings.volcanoAxis,
            textAnnotation: currentSettings.textAnnotation,
            volcanoPlotTitle: currentSettings.volcanoPlotTitle,
            visible: currentSettings.visible,
            volcanoPlotGrid: currentSettings.volcanoPlotGrid,
            volcanoPlotDimension: currentSettings.volcanoPlotDimension,
            volcanoAdditionalShapes: currentSettings.volcanoAdditionalShapes,
            volcanoPlotLegendX: currentSettings.volcanoPlotLegendX,
            volcanoPlotLegendY: currentSettings.volcanoPlotLegendY,
            defaultColorList: currentSettings.defaultColorList,
            scatterPlotMarkerSize: currentSettings.scatterPlotMarkerSize,
            plotFontFamily: currentSettings.plotFontFamily,
            stringDBColorMap: currentSettings.stringDBColorMap,
            interactomeAtlasColorMap: currentSettings.interactomeAtlasColorMap,
            proteomicsDBColor: currentSettings.proteomicsDBColor,
            networkInteractionSettings: currentSettings.networkInteractionSettings,
            rankPlotColorMap: currentSettings.rankPlotColorMap,
            rankPlotAnnotation: currentSettings.rankPlotAnnotation,
            legendStatus: currentSettings.legendStatus,
            selectedComparison: currentSettings.selectedComparison,
            imputationMap: currentSettings.imputationMap,
            enableImputation: currentSettings.enableImputation,
            viewPeptideCount: currentSettings.viewPeptideCount,
            peptideCountData: currentSettings.peptideCountData
        )
    }
}
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
        let startTime = Date()

        guard let rawCSV = curtainData.raw, !rawCSV.isEmpty else {
            return curtainData.settings
        }

        let samples = curtainData.rawForm.samples
        guard !samples.isEmpty else {
            return curtainData.settings
        }

        
        var conditions = [String]()
        var colorMap = [String: String]()
        var colorPosition = 0
        var sampleMap = [String: [String: String]]()
        var sampleOrder = [String: [String]]()
        var sampleVisible = [String: Bool]()
        
        // Process each sample to extract condition information
        for sample in samples {
            
            // Extract condition from sample name (Android logic: split on "." and take all but last part)
            let parts = sample.components(separatedBy: ".")
            let replicate = parts.last ?? ""
            let condition = parts.count > 1 ? parts.dropLast().joined(separator: ".") : ""
            
            // Use existing condition mapping if available, otherwise use extracted condition
            let actualCondition = curtainData.settings.sampleMap[sample]?["condition"] ?? condition
            
            
            // Add new conditions to the list and assign colors
            if !actualCondition.isEmpty && !conditions.contains(actualCondition) {
                conditions.append(actualCondition)
                
                // Cycle through default colors (Android logic)
                if colorPosition >= curtainData.settings.defaultColorList.count {
                    colorPosition = 0
                }
                colorMap[actualCondition] = curtainData.settings.defaultColorList[colorPosition]
                colorPosition += 1
                
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
        
        
        // Merge with existing settings (Android logic)
        let updatedSettings = mergeWithExistingSettingsSync(
            currentSettings: curtainData.settings,
            newConditions: conditions,
            newColorMap: colorMap,
            newSampleMap: sampleMap,
            newSampleOrder: sampleOrder,
            newSampleVisible: sampleVisible
        )

        let duration = Date().timeIntervalSince(startTime)

        return updatedSettings
    }
    
    /// Merge new metadata with existing settings (Android logic) - Synchronous version
    /// Accessible to DataProcessorActor
    fileprivate static func mergeWithExistingSettingsSync(
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
            peptideCountData: currentSettings.peptideCountData,
            volcanoConditionLabels: currentSettings.volcanoConditionLabels,
            volcanoTraceOrder: currentSettings.volcanoTraceOrder,
            volcanoPlotYaxisPosition: currentSettings.volcanoPlotYaxisPosition,
            customVolcanoTextCol: currentSettings.customVolcanoTextCol,
            barChartConditionBracket: currentSettings.barChartConditionBracket,
            columnSize: currentSettings.columnSize,
            chartYAxisLimits: currentSettings.chartYAxisLimits,
            individualYAxisLimits: currentSettings.individualYAxisLimits,
            violinPointPos: currentSettings.violinPointPos,
            networkInteractionData: currentSettings.networkInteractionData,
            enrichrGeneRankMap: currentSettings.enrichrGeneRankMap,
            enrichrRunList: currentSettings.enrichrRunList,
            extraData: currentSettings.extraData,
            enableMetabolomics: currentSettings.enableMetabolomics,
            metabolomicsColumnMap: currentSettings.metabolomicsColumnMap,
            encrypted: currentSettings.encrypted,
            dataAnalysisContact: currentSettings.dataAnalysisContact,
            markerSizeMap: currentSettings.markerSizeMap
        )
    }

    // MARK: - Async Processing API

    /// Shared actor instance for background processing
    private static let processorActor = DataProcessorActor()

    /// Process raw data asynchronously on background thread
    /// - Parameters:
    ///   - curtainData: Data to process
    ///   - progressCallback: Optional progress updates (0.0 to 1.0)
    /// - Returns: Processed settings
    static func processRawDataAsync(
        _ curtainData: CurtainData,
        progressCallback: ((Double) -> Void)? = nil
    ) async -> CurtainSettings {
        return await processorActor.processRawData(
            curtainData,
            progressCallback: progressCallback
        )
    }
}

// MARK: - Background Processing Actor

/// Thread-safe actor for heavy data processing operations
actor DataProcessorActor {

    /// Process raw CSV data into settings with progress tracking
    func processRawData(
        _ curtainData: CurtainData,
        progressCallback: ((Double) -> Void)?
    ) async -> CurtainSettings {
        // Run on detached task to ensure background execution
        return await Task.detached {
            await self.processRawDataInternal(curtainData, progressCallback: progressCallback)
        }.value
    }

    private func processRawDataInternal(
        _ curtainData: CurtainData,
        progressCallback: ((Double) -> Void)?
    ) async -> CurtainSettings {
        let startTime = Date()

        guard let rawCSV = curtainData.raw, !rawCSV.isEmpty else {
            progressCallback?(1.0)
            return curtainData.settings
        }

        let samples = curtainData.rawForm.samples
        guard !samples.isEmpty else {
            progressCallback?(1.0)
            return curtainData.settings
        }

        let totalSteps = Double(samples.count)

        var conditions = [String]()
        var colorMap = [String: String]()
        var colorPosition = 0
        var sampleMap = [String: [String: String]]()
        var sampleOrder = [String: [String]]()
        var sampleVisible = [String: Bool]()

        // Process each sample with progress tracking
        for (index, sample) in samples.enumerated() {
            // Extract condition from sample name (Android logic: split on "." and take all but last part)
            let parts = sample.components(separatedBy: ".")
            let replicate = parts.last ?? ""
            let condition = parts.count > 1 ? parts.dropLast().joined(separator: ".") : ""

            // Use existing condition mapping if available, otherwise use extracted condition
            let actualCondition = curtainData.settings.sampleMap[sample]?["condition"] ?? condition

            // Add new conditions to the list and assign colors
            if !actualCondition.isEmpty && !conditions.contains(actualCondition) {
                conditions.append(actualCondition)

                // Cycle through default colors (Android logic)
                if colorPosition >= curtainData.settings.defaultColorList.count {
                    colorPosition = 0
                }
                colorMap[actualCondition] = curtainData.settings.defaultColorList[colorPosition]
                colorPosition += 1
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

            // Report progress every 10 samples to reduce overhead
            if index % 10 == 0 || index == samples.count - 1 {
                let progress = Double(index + 1) / totalSteps * 0.9  // Reserve 10% for merging
                progressCallback?(progress)
            }
        }

        progressCallback?(0.9)

        let merged = CurtainDataProcessor.mergeWithExistingSettingsSync(
            currentSettings: curtainData.settings,
            newConditions: conditions,
            newColorMap: colorMap,
            newSampleMap: sampleMap,
            newSampleOrder: sampleOrder,
            newSampleVisible: sampleVisible
        )

        let duration = Date().timeIntervalSince(startTime)

        progressCallback?(1.0)
        return merged
    }
}
//
//  ConditionColorManagerView.swift
//  Curtain
//
//  Created by Toan Phung on 06/08/2025.
//

import SwiftUI

// MARK: - Condition Color Type

enum ConditionColorType: String, CaseIterable {
    case conditionColors = "Condition Colors"
    
    var description: String {
        switch self {
        case .conditionColors:
            return "Colors for experimental conditions displayed in bar charts and violin plots"
        }
    }
    
    var icon: String {
        switch self {
        case .conditionColors:
            return "chart.bar.fill"
        }
    }
}

// MARK: - Condition Color Info

struct ConditionColorInfo: Identifiable {
    let id = UUID()
    let name: String
    let type: ConditionColorType
    var color: Color
    var hexColor: String
    var alpha: Double = 1.0
    
    init(name: String, type: ConditionColorType, hexColor: String, alpha: Double = 1.0) {
        self.name = name
        self.type = type
        
        // Detect if the hexColor is actually ARGB format
        if hexColor.hasPrefix("#") && hexColor.count == 9 {
            // Extract alpha and color components from ARGB
            let alphaHex = String(hexColor.dropFirst().prefix(2))
            let colorHex = "#" + String(hexColor.dropFirst().dropFirst(2))
            
            if let alphaValue = Int(alphaHex, radix: 16) {
                self.alpha = Double(alphaValue) / 255.0
            } else {
                self.alpha = alpha
            }
            self.hexColor = colorHex
            
            // Try to create color from the RGB part
            if let parsedColor = Color(hex: colorHex) {
                self.color = parsedColor
            } else {
                self.color = .gray
            }
        } else {
            // Standard hex color
            self.hexColor = hexColor
            self.alpha = alpha
            
            // Try to create color, with better fallback handling
            if let parsedColor = Color(hex: hexColor) {
                self.color = parsedColor
            } else {
                // If hex parsing fails, don't mask with gray - use a default that indicates the issue
                
                // Try to create a valid hex color if the original was malformed
                let cleanHex = hexColor.hasPrefix("#") ? hexColor : "#" + hexColor
                if let fallbackColor = Color(hex: cleanHex) {
                    self.color = fallbackColor
                    self.hexColor = cleanHex
                } else {
                    // Last resort: use gray but preserve original hexColor for debugging
                    self.color = .gray
                }
            }
        }
    }
    
    var displayColor: Color {
        return color.opacity(alpha)
    }
    
    var argbString: String {
        let alphaInt = Int(alpha * 255)
        let colorComponents = color.cgColor?.components ?? [0, 0, 0, 1]
        let red = Int((colorComponents[0]) * 255)
        let green = Int((colorComponents[1]) * 255) 
        let blue = Int((colorComponents[2]) * 255)
        return String(format: "#%02X%02X%02X%02X", alphaInt, red, green, blue)
    }
    
    mutating func updateFromHex(_ hex: String) {
        self.hexColor = hex
        self.color = Color(hex: hex) ?? self.color
    }
    
    mutating func updateFromARGB(_ argb: String) {
        if argb.hasPrefix("#") && argb.count == 9 {
            let alphaHex = String(argb.dropFirst().prefix(2))
            let colorHex = "#" + String(argb.dropFirst().dropFirst(2))
            
            if let alphaValue = Int(alphaHex, radix: 16) {
                self.alpha = Double(alphaValue) / 255.0
            }
            self.hexColor = colorHex
            self.color = Color(hex: colorHex) ?? self.color
        }
    }
}

// MARK: - Condition Color Manager

struct ConditionColorManagerView: View {
    @Binding var curtainData: CurtainData
    @Environment(\.dismiss) private var dismiss
    
    @State private var conditionColors: [ConditionColorInfo] = []
    @State private var searchText = ""
    
    var filteredConditions: [ConditionColorInfo] {
        if searchText.isEmpty {
            return conditionColors
        }
        return conditionColors.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Info Header
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: ConditionColorType.conditionColors.icon)
                            .foregroundColor(.blue)
                        Text(ConditionColorType.conditionColors.rawValue)
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                    
                    Text(ConditionColorType.conditionColors.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemGray6))
                
                // Search Bar
                if !conditionColors.isEmpty {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField("Search conditions...", text: $searchText)
                        if !searchText.isEmpty {
                            Button("Clear") {
                                searchText = ""
                            }
                            .font(.caption)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    .padding()
                }
                
                // Conditions List
                if filteredConditions.isEmpty {
                    ContentUnavailableView(
                        searchText.isEmpty ? "No Condition Colors" : "No Results",
                        systemImage: searchText.isEmpty ? "chart.bar.fill" : "magnifyingglass",
                        description: Text(searchText.isEmpty ? "No experimental conditions found" : "No conditions match your search")
                    )
                } else {
                    List {
                        ForEach(filteredConditions) { conditionInfo in
                            ConditionColorRowView(
                                conditionInfo: conditionInfo,
                                onColorChange: { updatedInfo in
                                    updateConditionColor(updatedInfo)
                                }
                            )
                        }
                    }
                }
            }
            .navigationTitle("Condition Colors")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        saveChanges()
                        dismiss()
                    }
                }
            }
            .onAppear {
                // First, ensure missing color assignments are populated
                populateMissingColorAssignments()
                // Then load the condition colors (which will now include the populated ones)
                loadConditionColors()
            }
        }
    }
    
    // MARK: - Data Management
    
    private func loadConditionColors() {
        var conditions: [ConditionColorInfo] = []
        
        // First, populate any missing color assignments
        populateMissingColorAssignments()
        
        // Load condition colors from conditionOrder using same priority as ProteinChartView
        for conditionName in curtainData.settings.conditionOrder {
            let colorString = getActualConditionColor(conditionName)
            
            // The ConditionColorInfo init will now properly handle ARGB format detection
            conditions.append(ConditionColorInfo(
                name: conditionName,
                type: .conditionColors,
                hexColor: colorString,
                alpha: 1.0  // Will be overridden if colorString is ARGB format
            ))
        }
        
        self.conditionColors = conditions.sorted { $0.name < $1.name }
        
    }
    
    // Populate missing color assignments using same logic as bar charts
    private func populateMissingColorAssignments() {
        var newBarchartColorMap = curtainData.settings.barchartColorMap
        let defaultColors = curtainData.settings.defaultColorList
        var hasChanges = false
        
        // For each condition, ensure it has a color assignment
        for (index, conditionName) in curtainData.settings.conditionOrder.enumerated() {
            // Check if condition already has a color assignment
            let hasAssignment = (curtainData.settings.barchartColorMap[conditionName]?.value as? String)?.isEmpty == false ||
                               curtainData.settings.colorMap[conditionName]?.isEmpty == false
            
            if !hasAssignment {
                // Assign default color using same logic as chart
                let colorIndex = index % defaultColors.count
                let defaultColor = defaultColors[colorIndex]
                newBarchartColorMap[conditionName] = AnyCodable(defaultColor)
                hasChanges = true
            }
        }
        
        // Update settings if we made changes
        if hasChanges {
            // Convert to [String: Any] for helper method compatibility if needed, or update helper
            // Actually, newBarchartColorMap is already [String: AnyCodable]
            // We can update updateBarchartColorMap to take AnyCodable map
            updateBarchartColorMap(newBarchartColorMap)
        }
    }
    
    // Helper method to update barchartColorMap without going through full save process
    private func updateBarchartColorMap(_ newBarchartColorMap: [String: AnyCodable]) {
        let updatedSettings = CurtainSettings(
            fetchUniprot: curtainData.settings.fetchUniprot,
            inputDataCols: curtainData.settings.inputDataCols,
            probabilityFilterMap: curtainData.settings.probabilityFilterMap,
            barchartColorMap: newBarchartColorMap,
            pCutoff: curtainData.settings.pCutoff,
            log2FCCutoff: curtainData.settings.log2FCCutoff,
            description: curtainData.settings.description,
            uniprot: curtainData.settings.uniprot,
            colorMap: curtainData.settings.colorMap,
            academic: curtainData.settings.academic,
            backGroundColorGrey: curtainData.settings.backGroundColorGrey,
            currentComparison: curtainData.settings.currentComparison,
            version: curtainData.settings.version,
            currentId: curtainData.settings.currentId,
            fdrCurveText: curtainData.settings.fdrCurveText,
            fdrCurveTextEnable: curtainData.settings.fdrCurveTextEnable,
            prideAccession: curtainData.settings.prideAccession,
            project: curtainData.settings.project,
            sampleOrder: curtainData.settings.sampleOrder,
            sampleVisible: curtainData.settings.sampleVisible,
            conditionOrder: curtainData.settings.conditionOrder,
            sampleMap: curtainData.settings.sampleMap,
            volcanoAxis: curtainData.settings.volcanoAxis,
            textAnnotation: curtainData.settings.textAnnotation,
            volcanoPlotTitle: curtainData.settings.volcanoPlotTitle,
            visible: curtainData.settings.visible,
            volcanoPlotGrid: curtainData.settings.volcanoPlotGrid,
            volcanoPlotDimension: curtainData.settings.volcanoPlotDimension,
            volcanoAdditionalShapes: curtainData.settings.volcanoAdditionalShapes,
            volcanoPlotLegendX: curtainData.settings.volcanoPlotLegendX,
            volcanoPlotLegendY: curtainData.settings.volcanoPlotLegendY,
            defaultColorList: curtainData.settings.defaultColorList,
            scatterPlotMarkerSize: curtainData.settings.scatterPlotMarkerSize,
            plotFontFamily: curtainData.settings.plotFontFamily,
            stringDBColorMap: curtainData.settings.stringDBColorMap,
            interactomeAtlasColorMap: curtainData.settings.interactomeAtlasColorMap,
            proteomicsDBColor: curtainData.settings.proteomicsDBColor,
            networkInteractionSettings: curtainData.settings.networkInteractionSettings,
            rankPlotColorMap: curtainData.settings.rankPlotColorMap,
            rankPlotAnnotation: curtainData.settings.rankPlotAnnotation,
            legendStatus: curtainData.settings.legendStatus,
            selectedComparison: curtainData.settings.selectedComparison,
            imputationMap: curtainData.settings.imputationMap,
            enableImputation: curtainData.settings.enableImputation,
            viewPeptideCount: curtainData.settings.viewPeptideCount,
            peptideCountData: curtainData.settings.peptideCountData,
            volcanoConditionLabels: curtainData.settings.volcanoConditionLabels,
            volcanoTraceOrder: curtainData.settings.volcanoTraceOrder,
            volcanoPlotYaxisPosition: curtainData.settings.volcanoPlotYaxisPosition,
            customVolcanoTextCol: curtainData.settings.customVolcanoTextCol,
            barChartConditionBracket: curtainData.settings.barChartConditionBracket,
            columnSize: curtainData.settings.columnSize,
            chartYAxisLimits: curtainData.settings.chartYAxisLimits,
            individualYAxisLimits: curtainData.settings.individualYAxisLimits,
            violinPointPos: curtainData.settings.violinPointPos,
            networkInteractionData: curtainData.settings.networkInteractionData,
            enrichrGeneRankMap: curtainData.settings.enrichrGeneRankMap,
            enrichrRunList: curtainData.settings.enrichrRunList,
            extraData: curtainData.settings.extraData,
            enableMetabolomics: curtainData.settings.enableMetabolomics,
            metabolomicsColumnMap: curtainData.settings.metabolomicsColumnMap,
            encrypted: curtainData.settings.encrypted,
            dataAnalysisContact: curtainData.settings.dataAnalysisContact,
            markerSizeMap: curtainData.settings.markerSizeMap
        )
        
        // Update CurtainData
        let updatedCurtainData = CurtainData(
            raw: curtainData.raw,
            rawForm: curtainData.rawForm,
            differentialForm: curtainData.differentialForm,
            processed: curtainData.processed,
            password: curtainData.password,
            selections: curtainData.selections,
            selectionsMap: curtainData.selectionsMap,
            selectedMap: curtainData.selectedMap,
            selectionsName: curtainData.selectionsName,
            settings: updatedSettings,
            fetchUniprot: curtainData.fetchUniprot,
            annotatedData: curtainData.annotatedData,
            extraData: curtainData.extraData,
            permanent: curtainData.permanent,
            bypassUniProt: curtainData.bypassUniProt,
            dbPath: curtainData.dbPath
        )
        // Ensure uniprotDB is preserved
        var finalData = updatedCurtainData
        finalData.uniprotDB = curtainData.uniprotDB
        curtainData = finalData
    }
    
    // Get actual color being used by bar chart (same priority as ProteinChartView)
    private func getActualConditionColor(_ conditionName: String) -> String {
        // Priority 1: barchartColorMap (protein-specific overrides) - highest priority
        if let color = curtainData.settings.barchartColorMap[conditionName]?.value as? String, !color.isEmpty {
            return color
        }
        
        // Priority 2: general colorMap  
        if let color = curtainData.settings.colorMap[conditionName], !color.isEmpty {
            return color
        }
        
        // Priority 3: Default palette assignment
        let defaultColor = getDefaultColorForCondition(conditionName)
        return defaultColor
    }
    
    private func getDefaultColorForCondition(_ conditionName: String) -> String {
        // Use the EXACT same logic as ProteinChartView for consistency
        let androidPastelColors = [
            "#fd7f6f",  // Red
            "#7eb0d5",  // Blue  
            "#b2e061",  // Green
            "#bd7ebe",  // Purple
            "#ffb55a",  // Orange
            "#ffee65",  // Yellow
            "#beb9db",  // Light Purple
            "#fdcce5",  // Pink
            "#8bd3c7",  // Teal
            "#b3de69"   // Light Green
        ]
        
        // Use conditionOrder index for consistent assignment (same as ProteinChartView)
        let conditionIndex = curtainData.settings.conditionOrder.firstIndex(of: conditionName) ?? 0
        let defaultColor = androidPastelColors[conditionIndex % androidPastelColors.count]
        
        return defaultColor
    }
    
    private func updateConditionColor(_ updatedInfo: ConditionColorInfo) {
        if let index = conditionColors.firstIndex(where: { $0.id == updatedInfo.id }) {
            conditionColors[index] = updatedInfo
            
            // Immediately update the curtainData and trigger plot refresh
            updateSingleConditionColor(updatedInfo)
        }
    }
    
    // Update a single condition color immediately and trigger refresh
    private func updateSingleConditionColor(_ conditionInfo: ConditionColorInfo) {
        var newBarchartColorMap = curtainData.settings.barchartColorMap
        
        // Update the specific condition color
        let colorWithAlpha = conditionInfo.alpha < 1.0 ? conditionInfo.argbString : conditionInfo.hexColor
        newBarchartColorMap[conditionInfo.name] = AnyCodable(colorWithAlpha)
        
        // Create updated settings with the single color change
        let updatedSettings = CurtainSettings(
            fetchUniprot: curtainData.settings.fetchUniprot,
            inputDataCols: curtainData.settings.inputDataCols,
            probabilityFilterMap: curtainData.settings.probabilityFilterMap,
            barchartColorMap: newBarchartColorMap,
            pCutoff: curtainData.settings.pCutoff,
            log2FCCutoff: curtainData.settings.log2FCCutoff,
            description: curtainData.settings.description,
            uniprot: curtainData.settings.uniprot,
            colorMap: curtainData.settings.colorMap,
            academic: curtainData.settings.academic,
            backGroundColorGrey: curtainData.settings.backGroundColorGrey,
            currentComparison: curtainData.settings.currentComparison,
            version: curtainData.settings.version,
            currentId: curtainData.settings.currentId,
            fdrCurveText: curtainData.settings.fdrCurveText,
            fdrCurveTextEnable: curtainData.settings.fdrCurveTextEnable,
            prideAccession: curtainData.settings.prideAccession,
            project: curtainData.settings.project,
            sampleOrder: curtainData.settings.sampleOrder,
            sampleVisible: curtainData.settings.sampleVisible,
            conditionOrder: curtainData.settings.conditionOrder,
            sampleMap: curtainData.settings.sampleMap,
            volcanoAxis: curtainData.settings.volcanoAxis,
            textAnnotation: curtainData.settings.textAnnotation,
            volcanoPlotTitle: curtainData.settings.volcanoPlotTitle,
            visible: curtainData.settings.visible,
            volcanoPlotGrid: curtainData.settings.volcanoPlotGrid,
            volcanoPlotDimension: curtainData.settings.volcanoPlotDimension,
            volcanoAdditionalShapes: curtainData.settings.volcanoAdditionalShapes,
            volcanoPlotLegendX: curtainData.settings.volcanoPlotLegendX,
            volcanoPlotLegendY: curtainData.settings.volcanoPlotLegendY,
            defaultColorList: curtainData.settings.defaultColorList,
            scatterPlotMarkerSize: curtainData.settings.scatterPlotMarkerSize,
            plotFontFamily: curtainData.settings.plotFontFamily,
            stringDBColorMap: curtainData.settings.stringDBColorMap,
            interactomeAtlasColorMap: curtainData.settings.interactomeAtlasColorMap,
            proteomicsDBColor: curtainData.settings.proteomicsDBColor,
            networkInteractionSettings: curtainData.settings.networkInteractionSettings,
            rankPlotColorMap: curtainData.settings.rankPlotColorMap,
            rankPlotAnnotation: curtainData.settings.rankPlotAnnotation,
            legendStatus: curtainData.settings.legendStatus,
            selectedComparison: curtainData.settings.selectedComparison,
            imputationMap: curtainData.settings.imputationMap,
            enableImputation: curtainData.settings.enableImputation,
            viewPeptideCount: curtainData.settings.viewPeptideCount,
            peptideCountData: curtainData.settings.peptideCountData,
            volcanoConditionLabels: curtainData.settings.volcanoConditionLabels,
            volcanoTraceOrder: curtainData.settings.volcanoTraceOrder,
            volcanoPlotYaxisPosition: curtainData.settings.volcanoPlotYaxisPosition,
            customVolcanoTextCol: curtainData.settings.customVolcanoTextCol,
            barChartConditionBracket: curtainData.settings.barChartConditionBracket,
            columnSize: curtainData.settings.columnSize,
            chartYAxisLimits: curtainData.settings.chartYAxisLimits,
            individualYAxisLimits: curtainData.settings.individualYAxisLimits,
            violinPointPos: curtainData.settings.violinPointPos,
            networkInteractionData: curtainData.settings.networkInteractionData,
            enrichrGeneRankMap: curtainData.settings.enrichrGeneRankMap,
            enrichrRunList: curtainData.settings.enrichrRunList,
            extraData: curtainData.settings.extraData,
            enableMetabolomics: curtainData.settings.enableMetabolomics,
            metabolomicsColumnMap: curtainData.settings.metabolomicsColumnMap,
            encrypted: curtainData.settings.encrypted,
            dataAnalysisContact: curtainData.settings.dataAnalysisContact,
            markerSizeMap: curtainData.settings.markerSizeMap
        )
        
        // Update CurtainData
        let updatedCurtainData = CurtainData(
            raw: curtainData.raw,
            rawForm: curtainData.rawForm,
            differentialForm: curtainData.differentialForm,
            processed: curtainData.processed,
            password: curtainData.password,
            selections: curtainData.selections,
            selectionsMap: curtainData.selectionsMap,
            selectedMap: curtainData.selectedMap,
            selectionsName: curtainData.selectionsName,
            settings: updatedSettings,
            fetchUniprot: curtainData.fetchUniprot,
            annotatedData: curtainData.annotatedData,
            extraData: curtainData.extraData,
            permanent: curtainData.permanent,
            bypassUniProt: curtainData.bypassUniProt,
            dbPath: curtainData.dbPath
        )
        
        var finalData = updatedCurtainData
        finalData.uniprotDB = curtainData.uniprotDB
        curtainData = finalData
        
        // Immediately trigger chart refresh
        NotificationCenter.default.post(
            name: NSNotification.Name("ProteinChartRefresh"),
            object: nil,
            userInfo: ["reason": "immediateColorUpdate", "conditionName": conditionInfo.name]
        )
        
    }
    
    private func saveChanges() {
        var newBarchartColorMap = curtainData.settings.barchartColorMap
        
        // Update barchartColorMap with condition color changes (highest priority for bar charts)
        for conditionInfo in conditionColors {
            let colorWithAlpha = conditionInfo.alpha < 1.0 ? conditionInfo.argbString : conditionInfo.hexColor
            newBarchartColorMap[conditionInfo.name] = AnyCodable(colorWithAlpha)
        }
        
        // Create updated settings
        let updatedSettings = CurtainSettings(
            fetchUniprot: curtainData.settings.fetchUniprot,
            inputDataCols: curtainData.settings.inputDataCols,
            probabilityFilterMap: curtainData.settings.probabilityFilterMap,
            barchartColorMap: newBarchartColorMap,
            pCutoff: curtainData.settings.pCutoff,
            log2FCCutoff: curtainData.settings.log2FCCutoff,
            description: curtainData.settings.description,
            uniprot: curtainData.settings.uniprot,
            colorMap: curtainData.settings.colorMap,
            academic: curtainData.settings.academic,
            backGroundColorGrey: curtainData.settings.backGroundColorGrey,
            currentComparison: curtainData.settings.currentComparison,
            version: curtainData.settings.version,
            currentId: curtainData.settings.currentId,
            fdrCurveText: curtainData.settings.fdrCurveText,
            fdrCurveTextEnable: curtainData.settings.fdrCurveTextEnable,
            prideAccession: curtainData.settings.prideAccession,
            project: curtainData.settings.project,
            sampleOrder: curtainData.settings.sampleOrder,
            sampleVisible: curtainData.settings.sampleVisible,
            conditionOrder: curtainData.settings.conditionOrder,
            sampleMap: curtainData.settings.sampleMap,
            volcanoAxis: curtainData.settings.volcanoAxis,
            textAnnotation: curtainData.settings.textAnnotation,
            volcanoPlotTitle: curtainData.settings.volcanoPlotTitle,
            visible: curtainData.settings.visible,
            volcanoPlotGrid: curtainData.settings.volcanoPlotGrid,
            volcanoPlotDimension: curtainData.settings.volcanoPlotDimension,
            volcanoAdditionalShapes: curtainData.settings.volcanoAdditionalShapes,
            volcanoPlotLegendX: curtainData.settings.volcanoPlotLegendX,
            volcanoPlotLegendY: curtainData.settings.volcanoPlotLegendY,
            defaultColorList: curtainData.settings.defaultColorList,
            scatterPlotMarkerSize: curtainData.settings.scatterPlotMarkerSize,
            plotFontFamily: curtainData.settings.plotFontFamily,
            stringDBColorMap: curtainData.settings.stringDBColorMap,
            interactomeAtlasColorMap: curtainData.settings.interactomeAtlasColorMap,
            proteomicsDBColor: curtainData.settings.proteomicsDBColor,
            networkInteractionSettings: curtainData.settings.networkInteractionSettings,
            rankPlotColorMap: curtainData.settings.rankPlotColorMap,
            rankPlotAnnotation: curtainData.settings.rankPlotAnnotation,
            legendStatus: curtainData.settings.legendStatus,
            selectedComparison: curtainData.settings.selectedComparison,
            imputationMap: curtainData.settings.imputationMap,
            enableImputation: curtainData.settings.enableImputation,
            viewPeptideCount: curtainData.settings.viewPeptideCount,
            peptideCountData: curtainData.settings.peptideCountData,
            volcanoConditionLabels: curtainData.settings.volcanoConditionLabels,
            volcanoTraceOrder: curtainData.settings.volcanoTraceOrder,
            volcanoPlotYaxisPosition: curtainData.settings.volcanoPlotYaxisPosition,
            customVolcanoTextCol: curtainData.settings.customVolcanoTextCol,
            barChartConditionBracket: curtainData.settings.barChartConditionBracket,
            columnSize: curtainData.settings.columnSize,
            chartYAxisLimits: curtainData.settings.chartYAxisLimits,
            individualYAxisLimits: curtainData.settings.individualYAxisLimits,
            violinPointPos: curtainData.settings.violinPointPos,
            networkInteractionData: curtainData.settings.networkInteractionData,
            enrichrGeneRankMap: curtainData.settings.enrichrGeneRankMap,
            enrichrRunList: curtainData.settings.enrichrRunList,
            extraData: curtainData.settings.extraData,
            enableMetabolomics: curtainData.settings.enableMetabolomics,
            metabolomicsColumnMap: curtainData.settings.metabolomicsColumnMap,
            encrypted: curtainData.settings.encrypted,
            dataAnalysisContact: curtainData.settings.dataAnalysisContact,
            markerSizeMap: curtainData.settings.markerSizeMap
        )
        
        // Update CurtainData
        let updatedCurtainData = CurtainData(
            raw: curtainData.raw,
            rawForm: curtainData.rawForm,
            differentialForm: curtainData.differentialForm,
            processed: curtainData.processed,
            password: curtainData.password,
            selections: curtainData.selections,
            selectionsMap: curtainData.selectionsMap,
            selectedMap: curtainData.selectedMap,
            selectionsName: curtainData.selectionsName,
            settings: updatedSettings,
            fetchUniprot: curtainData.fetchUniprot,
            annotatedData: curtainData.annotatedData,
            extraData: curtainData.extraData,
            permanent: curtainData.permanent,
            bypassUniProt: curtainData.bypassUniProt,
            dbPath: curtainData.dbPath
        )
        
        var finalData = updatedCurtainData
        finalData.uniprotDB = curtainData.uniprotDB
        curtainData = finalData
        
        // Trigger chart refresh
        NotificationCenter.default.post(
            name: NSNotification.Name("ProteinChartRefresh"),
            object: nil,
            userInfo: ["reason": "colorUpdate"]
        )
        
    }
    
}

// MARK: - Condition Color Row View

struct ConditionColorRowView: View {
    let conditionInfo: ConditionColorInfo
    let onColorChange: (ConditionColorInfo) -> Void
    
    @State private var showingDetailedPicker = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Color Preview
            RoundedRectangle(cornerRadius: 8)
                .fill(conditionInfo.displayColor)
                .frame(width: 32, height: 32)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.primary.opacity(0.2), lineWidth: 1)
                )
            
            // Condition Info
            VStack(alignment: .leading, spacing: 2) {
                Text(conditionInfo.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)
                
                HStack(spacing: 8) {
                    Text(conditionInfo.hexColor)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .textSelection(.enabled)
                    
                    if conditionInfo.alpha < 1.0 {
                        Text("α: \(conditionInfo.alpha, specifier: "%.2f")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            // Color Picker
            ColorPicker("", selection: Binding(
                get: { conditionInfo.color },
                set: { newColor in
                    var updatedInfo = conditionInfo
                    updatedInfo.color = newColor
                    updatedInfo.hexColor = newColor.toHex() ?? conditionInfo.hexColor
                    onColorChange(updatedInfo)
                }
            ))
            .labelsHidden()
            .scaleEffect(0.8)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            showingDetailedPicker = true
        }
        .sheet(isPresented: $showingDetailedPicker) {
            ConditionDetailedColorPickerView(
                conditionInfo: Binding(
                    get: { conditionInfo },
                    set: { updatedInfo in
                        onColorChange(updatedInfo)
                    }
                )
            )
        }
    }
}

// MARK: - Condition Detailed Color Picker View

struct ConditionDetailedColorPickerView: View {
    @Binding var conditionInfo: ConditionColorInfo
    @Environment(\.dismiss) private var dismiss
    
    @State private var hexInput = ""
    @State private var argbInput = ""
    @State private var alphaSlider: Double = 1.0
    @State private var showingInvalidHex = false
    @State private var showingInvalidARGB = false
    
    var body: some View {
        NavigationView {
            Form {
                Section("Condition Information") {
                    HStack {
                        Image(systemName: conditionInfo.type.icon)
                            .foregroundColor(.secondary)
                        Text(conditionInfo.type.rawValue)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(conditionInfo.name)
                        .font(.headline)
                }
                
                Section("Color Preview") {
                    HStack {
                        Spacer()
                        RoundedRectangle(cornerRadius: 12)
                            .fill(conditionInfo.displayColor)
                            .frame(width: 100, height: 100)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.primary.opacity(0.2), lineWidth: 2)
                            )
                        Spacer()
                    }
                    .padding(.vertical)
                }
                
                Section("Color Picker") {
                    ColorPicker("Choose Color", selection: Binding(
                        get: { conditionInfo.color },
                        set: { newColor in
                            conditionInfo.color = newColor
                            conditionInfo.hexColor = newColor.toHex() ?? conditionInfo.hexColor
                            updateInputFields()
                        }
                    ))
                }
                
                Section("Transparency") {
                    VStack(spacing: 8) {
                        HStack {
                            Text("Opacity")
                            Spacer()
                            Text("\(Int(alphaSlider * 100))%")
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(value: $alphaSlider, in: 0...1, step: 0.01) { _ in
                            conditionInfo.alpha = alphaSlider
                        }
                    }
                }
                
                Section("Manual Input") {
                    VStack(spacing: 12) {
                        // Hex Input
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Hex Color")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            HStack {
                                TextField("#RRGGBB", text: $hexInput)
                                    .textFieldStyle(.roundedBorder)
                                    .autocapitalization(.allCharacters)
                                
                                Button("Apply") {
                                    applyHexColor()
                                }
                                .disabled(hexInput.isEmpty)
                            }
                            
                            if showingInvalidHex {
                                Text("Invalid hex format. Use #RRGGBB")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                        
                        // ARGB Input
                        VStack(alignment: .leading, spacing: 4) {
                            Text("ARGB Color (with transparency)")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            HStack {
                                TextField("#AARRGGBB", text: $argbInput)
                                    .textFieldStyle(.roundedBorder)
                                    .autocapitalization(.allCharacters)
                                
                                Button("Apply") {
                                    applyARGBColor()
                                }
                                .disabled(argbInput.isEmpty)
                            }
                            
                            if showingInvalidARGB {
                                Text("Invalid ARGB format. Use #AARRGGBB")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }
                
                Section("Current Values") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Hex:")
                                .fontWeight(.medium)
                            Text(conditionInfo.hexColor)
                                .textSelection(.enabled)
                            Spacer()
                        }
                        
                        HStack {
                            Text("ARGB:")
                                .fontWeight(.medium)
                            Text(conditionInfo.argbString)
                                .textSelection(.enabled)
                            Spacer()
                        }
                        
                        HStack {
                            Text("Opacity:")
                                .fontWeight(.medium)
                            Text("\(Int(conditionInfo.alpha * 100))%")
                            Spacer()
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Edit Condition Color")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                updateInputFields()
                alphaSlider = conditionInfo.alpha
            }
        }
    }
    
    private func updateInputFields() {
        hexInput = conditionInfo.hexColor
        argbInput = conditionInfo.argbString
    }
    
    private func applyHexColor() {
        showingInvalidHex = false
        
        if isValidHexColor(hexInput) {
            conditionInfo.updateFromHex(hexInput)
            argbInput = conditionInfo.argbString
        } else {
            showingInvalidHex = true
        }
    }
    
    private func applyARGBColor() {
        showingInvalidARGB = false
        
        if isValidARGBColor(argbInput) {
            conditionInfo.updateFromARGB(argbInput)
            hexInput = conditionInfo.hexColor
            alphaSlider = conditionInfo.alpha
        } else {
            showingInvalidARGB = true
        }
    }
    
    private func isValidHexColor(_ hex: String) -> Bool {
        let pattern = "^#[0-9A-Fa-f]{6}$"
        return hex.range(of: pattern, options: .regularExpression) != nil
    }
    
    private func isValidARGBColor(_ argb: String) -> Bool {
        let pattern = "^#[0-9A-Fa-f]{8}$"
        return argb.range(of: pattern, options: .regularExpression) != nil
    }
}

#Preview {
    ConditionColorManagerView(curtainData: .constant(CurtainData.previewData()))
}


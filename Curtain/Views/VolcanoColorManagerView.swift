//
//  VolcanoColorManagerView.swift
//  Curtain
//
//  Created by Toan Phung on 06/08/2025.
//

import SwiftUI

// MARK: - Volcano Color Type

enum VolcanoColorType: String, CaseIterable {
    case volcanoPlotColors = "Volcano Plot Colors"
    
    var description: String {
        switch self {
        case .volcanoPlotColors:
            return "Colors for search/selection groups and significance categories displayed on volcano plots"
        }
    }
    
    var icon: String {
        switch self {
        case .volcanoPlotColors:
            return "chart.xyaxis.line"
        }
    }
}

// MARK: - Volcano Group Color Info

struct VolcanoGroupColorInfo: Identifiable {
    let id = UUID()
    let name: String
    let type: VolcanoColorType
    var color: Color
    var hexColor: String
    var alpha: Double = 1.0
    
    init(name: String, type: VolcanoColorType, hexColor: String, alpha: Double = 1.0) {
        self.name = name
        self.type = type
        self.hexColor = hexColor
        self.alpha = alpha
        self.color = Color(hex: hexColor) ?? .gray
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

// MARK: - Volcano Plot Color Manager

struct VolcanoColorManagerView: View {
    @Binding var curtainData: CurtainData
    @Environment(\.dismiss) private var dismiss
    
    @State private var volcanoGroups: [VolcanoGroupColorInfo] = []
    @State private var searchText = ""
    
    var filteredGroups: [VolcanoGroupColorInfo] {
        if searchText.isEmpty {
            return volcanoGroups
        }
        return volcanoGroups.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Info Header
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: VolcanoColorType.volcanoPlotColors.icon)
                            .foregroundColor(.blue)
                        Text(VolcanoColorType.volcanoPlotColors.rawValue)
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                    
                    Text(VolcanoColorType.volcanoPlotColors.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemGray6))
                
                // Search Bar
                if !volcanoGroups.isEmpty {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField("Search groups...", text: $searchText)
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
                
                // Groups List
                if filteredGroups.isEmpty {
                    ContentUnavailableView(
                        searchText.isEmpty ? "No Volcano Plot Groups" : "No Results",
                        systemImage: searchText.isEmpty ? "chart.xyaxis.line" : "magnifyingglass",
                        description: Text(searchText.isEmpty ? "No groups found in the current volcano plot" : "No groups match your search")
                    )
                } else {
                    List {
                        ForEach(filteredGroups) { groupInfo in
                            VolcanoGroupRowView(
                                groupInfo: groupInfo,
                                onColorChange: { updatedInfo in
                                    updateGroupColor(updatedInfo)
                                }
                            )
                        }
                    }
                }
            }
            .navigationTitle("Volcano Colors")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                    .fixedSize()
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        saveChanges()
                        dismiss()
                    }
                    .fixedSize()
                }
            }
            .onAppear {
                loadVolcanoGroups()
            }
        }
    }
    
    // MARK: - Data Management
    
    private func loadVolcanoGroups() {
        var groups: [VolcanoGroupColorInfo] = []
        var allTraceGroups: Set<String> = []
        
        let conditionSet = Set(curtainData.settings.conditionOrder)
        
        // Method 1: Get user-created selection groups from selectedMap (search results, manual selections)
        if let selectedMap = curtainData.selectedMap {
            for (_, selections) in selectedMap {
                for (selectionName, isSelected) in selections {
                    if isSelected && !conditionSet.contains(selectionName) {
                        allTraceGroups.insert(selectionName)
                    }
                }
            }
        }
        
        // Method 2: Generate auto-created significance groups based on volcano plot logic
        let significanceGroups = generateSignificanceGroups(
            settings: curtainData.settings,
            differentialData: getProcessedDifferentialData()
        )
        allTraceGroups.formUnion(significanceGroups)
        
        // Create color info for all discovered trace groups
        for groupName in allTraceGroups {
            let colorString = curtainData.settings.colorMap[groupName] ?? getDefaultColorForGroup(groupName)
            groups.append(VolcanoGroupColorInfo(
                name: groupName,
                type: .volcanoPlotColors,
                hexColor: colorString,
                alpha: 1.0
            ))
        }
        
        self.volcanoGroups = groups.sorted { $0.name < $1.name }
    }
    
    // Generate significance groups using the same logic as VolcanoPlotDataService
    private func generateSignificanceGroups(settings: CurtainSettings, differentialData: [[String: Any]]) -> Set<String> {
        var significanceGroups: Set<String> = []
        let pCutoff = settings.pCutoff
        let log2FCCutoff = settings.log2FCCutoff
        
        // Get available comparisons
        let comparisons = getAvailableComparisons(from: differentialData)
        
        // Generate all possible significance group combinations
        for comparison in comparisons {
            // P-value thresholds
            let pValueCategories = [
                "P-value <= \(pCutoff)",
                "P-value > \(pCutoff)"
            ]
            
            // Fold change thresholds  
            let fcCategories = [
                "FC <= \(log2FCCutoff)",
                "FC > \(log2FCCutoff)"
            ]
            
            // Create all combinations
            for pCategory in pValueCategories {
                for fcCategory in fcCategories {
                    let groupName = "\(pCategory);\(fcCategory) (\(comparison))"
                    significanceGroups.insert(groupName)
                }
            }
        }
        
        return significanceGroups
    }
    
    private func getProcessedDifferentialData() -> [[String: Any]] {
        guard let processedData = curtainData.extraData?.data?.dataMap as? [String: Any],
              let differentialData = processedData["processedDifferentialData"] as? [[String: Any]] else {
            return []
        }
        return differentialData
    }
    
    private func getAvailableComparisons(from differentialData: [[String: Any]]) -> Set<String> {
        var comparisons: Set<String> = []
        let comparisonColumn = curtainData.differentialForm.comparison
        
        if comparisonColumn.isEmpty {
            comparisons.insert("1") // Default comparison
        } else {
            for row in differentialData {
                if let comparison = row[comparisonColumn] as? String, !comparison.isEmpty {
                    comparisons.insert(comparison)
                }
            }
            if comparisons.isEmpty {
                comparisons.insert("1") // Fallback
            }
        }
        
        return comparisons
    }
    
    private func getDefaultColorForGroup(_ groupName: String) -> String {
        // Use the same default color assignment logic as VolcanoPlotDataService
        let defaultColors = curtainData.settings.defaultColorList
        let hash = abs(groupName.hashValue)
        let colorIndex = hash % defaultColors.count
        return defaultColors[colorIndex]
    }
    
    private func updateGroupColor(_ updatedInfo: VolcanoGroupColorInfo) {
        if let index = volcanoGroups.firstIndex(where: { $0.id == updatedInfo.id }) {
            volcanoGroups[index] = updatedInfo
        }
    }
    
    private func saveChanges() {
        var newColorMap = curtainData.settings.colorMap
        
        // Update colorMap with volcano plot group changes
        for groupInfo in volcanoGroups {
            let colorWithAlpha = groupInfo.alpha < 1.0 ? groupInfo.argbString : groupInfo.hexColor
            newColorMap[groupInfo.name] = colorWithAlpha
        }
        
        // Create updated settings
        let updatedSettings = CurtainSettings(
            fetchUniprot: curtainData.settings.fetchUniprot,
            inputDataCols: curtainData.settings.inputDataCols,
            probabilityFilterMap: curtainData.settings.probabilityFilterMap,
            barchartColorMap: curtainData.settings.barchartColorMap,
            pCutoff: curtainData.settings.pCutoff,
            log2FCCutoff: curtainData.settings.log2FCCutoff,
            description: curtainData.settings.description,
            uniprot: curtainData.settings.uniprot,
            colorMap: newColorMap,
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
            peptideCountData: curtainData.settings.peptideCountData
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
            dbPath: curtainData.dbPath,
            linkId: curtainData.linkId
        )

        curtainData = updatedCurtainData
        
        // Trigger volcano plot refresh
        NotificationCenter.default.post(
            name: NSNotification.Name("VolcanoPlotRefresh"),
            object: nil,
            userInfo: ["reason": "colorUpdate"]
        )
        
    }
}

// MARK: - Volcano Group Row View

struct VolcanoGroupRowView: View {
    let groupInfo: VolcanoGroupColorInfo
    let onColorChange: (VolcanoGroupColorInfo) -> Void
    
    @State private var showingDetailedPicker = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Color Preview
            RoundedRectangle(cornerRadius: 8)
                .fill(groupInfo.displayColor)
                .frame(width: 32, height: 32)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.primary.opacity(0.2), lineWidth: 1)
                )
            
            // Group Info
            VStack(alignment: .leading, spacing: 2) {
                Text(groupInfo.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)
                
                HStack(spacing: 8) {
                    Text(groupInfo.hexColor)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .textSelection(.enabled)
                    
                    if groupInfo.alpha < 1.0 {
                        Text("α: \(groupInfo.alpha, specifier: "%.2f")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            // Color Picker
            ColorPicker("", selection: Binding(
                get: { groupInfo.color },
                set: { newColor in
                    var updatedInfo = groupInfo
                    updatedInfo.color = newColor
                    updatedInfo.hexColor = newColor.toHex() ?? groupInfo.hexColor
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
            VolcanoDetailedColorPickerView(
                groupInfo: Binding(
                    get: { groupInfo },
                    set: { updatedInfo in
                        onColorChange(updatedInfo)
                    }
                )
            )
        }
    }
}

// MARK: - Volcano Detailed Color Picker View

struct VolcanoDetailedColorPickerView: View {
    @Binding var groupInfo: VolcanoGroupColorInfo
    @Environment(\.dismiss) private var dismiss
    
    @State private var hexInput = ""
    @State private var argbInput = ""
    @State private var alphaSlider: Double = 1.0
    @State private var showingInvalidHex = false
    @State private var showingInvalidARGB = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Group Information") {
                    HStack {
                        Image(systemName: groupInfo.type.icon)
                            .foregroundColor(.secondary)
                        Text(groupInfo.type.rawValue)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(groupInfo.name)
                        .font(.headline)
                }
                
                Section("Color Preview") {
                    HStack {
                        Spacer()
                        RoundedRectangle(cornerRadius: 12)
                            .fill(groupInfo.displayColor)
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
                        get: { groupInfo.color },
                        set: { newColor in
                            groupInfo.color = newColor
                            groupInfo.hexColor = newColor.toHex() ?? groupInfo.hexColor
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
                            groupInfo.alpha = alphaSlider
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
                            Text(groupInfo.hexColor)
                                .textSelection(.enabled)
                            Spacer()
                        }
                        
                        HStack {
                            Text("ARGB:")
                                .fontWeight(.medium)
                            Text(groupInfo.argbString)
                                .textSelection(.enabled)
                            Spacer()
                        }
                        
                        HStack {
                            Text("Opacity:")
                                .fontWeight(.medium)
                            Text("\(Int(groupInfo.alpha * 100))%")
                            Spacer()
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Edit Color")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                    .fixedSize()
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                    .fixedSize()
                }
            }
            .onAppear {
                updateInputFields()
                alphaSlider = groupInfo.alpha
            }
        }
    }
    
    private func updateInputFields() {
        hexInput = groupInfo.hexColor
        argbInput = groupInfo.argbString
    }
    
    private func applyHexColor() {
        showingInvalidHex = false
        
        if isValidHexColor(hexInput) {
            groupInfo.updateFromHex(hexInput)
            argbInput = groupInfo.argbString
        } else {
            showingInvalidHex = true
        }
    }
    
    private func applyARGBColor() {
        showingInvalidARGB = false
        
        if isValidARGBColor(argbInput) {
            groupInfo.updateFromARGB(argbInput)
            hexInput = groupInfo.hexColor
            alphaSlider = groupInfo.alpha
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
    VolcanoColorManagerView(curtainData: .constant(CurtainData.previewData()))
}
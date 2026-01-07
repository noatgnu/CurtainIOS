//
//  GroupColorManagerView.swift
//  Curtain
//
//  Created by Toan Phung on 06/08/2025.
//

import SwiftUI

// MARK: - Color Group Types

enum GroupColorType: String, CaseIterable {
    case conditionColors = "Condition Colors"
    
    var description: String {
        switch self {
        case .conditionColors:
            return "Colors bound to experimental conditions for bar charts and violin plots"
        }
    }
    
    var icon: String {
        switch self {
        case .conditionColors:
            return "chart.bar.fill"
        }
    }
}

// MARK: - Color Models

struct GroupColorInfo: Identifiable {
    let id = UUID()
    let name: String
    let type: GroupColorType
    var color: Color
    var hexColor: String
    var alpha: Double = 1.0
    
    init(name: String, type: GroupColorType, hexColor: String, alpha: Double = 1.0) {
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

// MARK: - Main Group Color Manager View

struct GroupColorManagerView: View {
    @Binding var curtainData: CurtainData
    @Environment(\.dismiss) private var dismiss
    
    @State private var groupColors: [GroupColorInfo] = []
    @State private var selectedType: GroupColorType = .conditionColors
    @State private var searchText = ""
    @State private var showingColorDetails = false
    @State private var selectedColorInfo: GroupColorInfo?
    
    var filteredGroups: [GroupColorInfo] {
        let typeFiltered = groupColors.filter { $0.type == selectedType }
        if searchText.isEmpty {
            return typeFiltered
        }
        return typeFiltered.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: selectedType.icon)
                            .foregroundColor(.blue)
                        Text(selectedType.rawValue)
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                    
                    Text(selectedType.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("Volcano plot colors are managed directly from the volcano plot tab")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .fontWeight(.medium)
                }
                .padding()
                .background(Color(.systemGray6))
                
                // Search Bar
                if !groupColors.isEmpty {
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
                    .padding(.horizontal)
                }
                
                // Groups List
                if filteredGroups.isEmpty {
                    ContentUnavailableView(
                        searchText.isEmpty ? "No \(selectedType.rawValue)" : "No Results",
                        systemImage: searchText.isEmpty ? selectedType.icon : "magnifyingglass",
                        description: Text(searchText.isEmpty ? "No groups of this type found" : "No groups match your search")
                    )
                } else {
                    List {
                        ForEach(filteredGroups) { groupInfo in
                            GroupColorRowView(
                                groupInfo: groupInfo,
                                onColorChange: { updatedInfo in
                                    updateGroupColor(updatedInfo)
                                },
                                onTapDetail: {
                                    selectedColorInfo = groupInfo
                                    showingColorDetails = true
                                }
                            )
                        }
                    }
                }
                
                Spacer()
            }
            .navigationTitle("Group Colors")
            .navigationBarTitleDisplayMode(.large)
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
                loadGroupColors()
            }
            .sheet(isPresented: $showingColorDetails) {
                if let colorInfo = selectedColorInfo {
                    DetailedColorPickerView(
                        groupInfo: Binding(
                            get: { colorInfo },
                            set: { updatedInfo in
                                selectedColorInfo = updatedInfo
                                updateGroupColor(updatedInfo)
                            }
                        )
                    )
                }
            }
        }
    }
    
    // MARK: - Data Management
    
    private func loadGroupColors() {
        var colors: [GroupColorInfo] = []
        
        // Load condition colors from conditionOrder (experimental conditions)
        for conditionName in curtainData.settings.conditionOrder {
            // Get color from colorMap if available, otherwise provide default
            let colorString = curtainData.settings.colorMap[conditionName] ?? "#808080"
            colors.append(GroupColorInfo(
                name: conditionName,
                type: .conditionColors,
                hexColor: colorString,
                alpha: 1.0
            ))
        }
        
        self.groupColors = colors.sorted { $0.name < $1.name }
    }
    
    
    
    private func updateGroupColor(_ updatedInfo: GroupColorInfo) {
        // Update in the local array
        if let index = groupColors.firstIndex(where: { $0.id == updatedInfo.id }) {
            groupColors[index] = updatedInfo
        }
        
        // Update the selected color info if it matches
        if selectedColorInfo?.id == updatedInfo.id {
            selectedColorInfo = updatedInfo
        }
    }
    
    private func saveChanges() {
        var newColorMap = curtainData.settings.colorMap
        
        // Update colorMap with all changes (both volcano plot colors and condition colors)
        for groupInfo in groupColors {
            let colorWithAlpha = groupInfo.alpha < 1.0 ? groupInfo.argbString : groupInfo.hexColor
            newColorMap[groupInfo.name] = colorWithAlpha
        }
        
        // Create updated settings
        let updatedSettings = CurtainSettings(
            fetchUniprot: curtainData.settings.fetchUniprot,
            inputDataCols: curtainData.settings.inputDataCols,
            probabilityFilterMap: curtainData.settings.probabilityFilterMap,
            barchartColorMap: curtainData.settings.barchartColorMap, // Keep unchanged
            pCutoff: curtainData.settings.pCutoff,
            log2FCCutoff: curtainData.settings.log2FCCutoff,
            description: curtainData.settings.description,
            uniprot: curtainData.settings.uniprot,
            colorMap: newColorMap, // Updated colorMap
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
        
        // Update the CurtainData
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
            settings: updatedSettings, // Updated settings
            fetchUniprot: curtainData.fetchUniprot,
            annotatedData: curtainData.annotatedData,
            extraData: curtainData.extraData,
            permanent: curtainData.permanent
        )
        
        curtainData = updatedCurtainData
    }
}

// MARK: - Supporting Views

struct GroupColorRowView: View {
    let groupInfo: GroupColorInfo
    let onColorChange: (GroupColorInfo) -> Void
    let onTapDetail: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Color Preview
            RoundedRectangle(cornerRadius: 8)
                .fill(groupInfo.displayColor)
                .frame(width: 40, height: 40)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.primary.opacity(0.2), lineWidth: 1)
                )
            
            // Group Info
            VStack(alignment: .leading, spacing: 4) {
                Text(groupInfo.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                HStack(spacing: 12) {
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
            
            // Quick Actions
            HStack(spacing: 8) {
                Button(action: onTapDetail) {
                    Image(systemName: "paintpalette.fill")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                .buttonStyle(PlainButtonStyle())
                
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
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            onTapDetail()
        }
    }
}

// MARK: - Detailed Color Picker View

struct DetailedColorPickerView: View {
    @Binding var groupInfo: GroupColorInfo
    @Environment(\.dismiss) private var dismiss
    
    @State private var hexInput = ""
    @State private var argbInput = ""
    @State private var alphaSlider: Double = 1.0
    @State private var showingInvalidHex = false
    @State private var showingInvalidARGB = false
    
    var body: some View {
        NavigationView {
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
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
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

// MARK: - Color Extensions

extension Color {
    func toHex() -> String? {
        guard let components = self.cgColor?.components else { return nil }
        
        let red = Int(components[0] * 255)
        let green = Int(components[1] * 255)
        let blue = Int(components[2] * 255)
        
        return String(format: "#%02X%02X%02X", red, green, blue)
    }
}

#Preview {
    GroupColorManagerView(curtainData: .constant(CurtainData.previewData()))
}

// MARK: - Preview Data Extension

extension CurtainData {
    static func previewData() -> CurtainData {
        let mockSettings = CurtainSettings(
            fetchUniprot: true,
            inputDataCols: [:],
            probabilityFilterMap: [:],
            barchartColorMap: [:],
            pCutoff: 0.05,
            log2FCCutoff: 0.6,
            description: "Mock Data",
            uniprot: true,
            colorMap: [
                "Control": "#1f77b4",
                "Treatment": "#ff7f0e", 
                "Significant Up": "#2ca02c",
                "Significant Down": "#d62728",
                "Not Significant": "#7f7f7f",
                "Search Group 1": "#9467bd",
                "Selection Group A": "#8c564b"
            ],
            academic: true,
            backGroundColorGrey: false
        )
        
        return CurtainData(
            settings: mockSettings
        )
    }
}
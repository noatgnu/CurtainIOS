//
//  BarChartConditionBracketSettingsView.swift
//  Curtain
//
//  Created by Toan Phung on 06/01/2026.
//

import SwiftUI

// MARK: - Bar Chart Condition Bracket Settings View

struct BarChartConditionBracketSettingsView: View {
    @Binding var curtainData: CurtainData
    @Environment(\.dismiss) private var dismiss

    // Local state for editing
    @State private var showBracket: Bool = false
    @State private var bracketHeight: Double = 0.05
    @State private var bracketColor: Color = .black
    @State private var bracketColorHex: String = "#000000"
    @State private var bracketWidth: Int = 2

    // For color picker
    @State private var showingColorPicker = false

    var body: some View {
        NavigationView {
            Form {
                // Enable/Disable Section
                Section {
                    Toggle("Show Condition Bracket", isOn: $showBracket)

                    if showBracket {
                        Text("Draws a bracket above bar charts connecting the two conditions selected in volcano plot labels")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                if showBracket {
                    // Info Section
                    Section {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(.blue)
                            Text("The bracket connects the left and right conditions from the Volcano Condition Labels settings")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    // Bracket Styling Section
                    Section("Bracket Appearance") {
                        // Bracket Height
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Bracket Height")
                                    .font(.subheadline)
                                Spacer()
                                Text("\(bracketHeight, specifier: "%.3f")")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Slider(value: $bracketHeight, in: 0.01...0.2, step: 0.01)

                            Text("Height of the bracket above the plot (0.01 - 0.2)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        // Bracket Width
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Line Width")
                                    .font(.subheadline)
                                Spacer()
                                Text("\(bracketWidth)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Stepper("", value: $bracketWidth, in: 1...5, step: 1)
                                .labelsHidden()

                            Text("Thickness of the bracket lines (1-5 pixels)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        // Bracket Color
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Bracket Color")
                                .font(.subheadline)

                            HStack(spacing: 12) {
                                // Color preview
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(bracketColor)
                                    .frame(width: 50, height: 50)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                    )

                                // Color picker
                                ColorPicker("", selection: $bracketColor, supportsOpacity: false)
                                    .labelsHidden()
                                    .onChange(of: bracketColor) { oldValue, newValue in
                                        bracketColorHex = colorToHex(newValue)
                                    }

                                // Hex text field
                                TextField("Hex Color", text: $bracketColorHex)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.caption)
                                    .onChange(of: bracketColorHex) { oldValue, newValue in
                                        if let color = hexToColor(newValue) {
                                            bracketColor = color
                                        }
                                    }
                            }

                            Text("Select bracket color")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    // Preview Section
                    Section("Preview") {
                        VStack(alignment: .center, spacing: 8) {
                            Text("Bracket Preview")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            // Simple bracket preview
                            ZStack {
                                // Background
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(.systemGray6))
                                    .frame(height: 120)

                                // Bracket visualization
                                VStack(spacing: 0) {
                                    Spacer()

                                    // Horizontal line at bottom
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.3))
                                        .frame(height: 1)

                                    // Bracket drawing
                                    GeometryReader { geometry in
                                        let width = geometry.size.width
                                        let leftX = width * 0.25
                                        let rightX = width * 0.75
                                        let baseY = geometry.size.height - 60
                                        let topY = baseY - CGFloat(bracketHeight * 200)  // Scale for preview

                                        Path { path in
                                            // Left vertical
                                            path.move(to: CGPoint(x: leftX, y: baseY))
                                            path.addLine(to: CGPoint(x: leftX, y: topY))

                                            // Horizontal connector
                                            path.move(to: CGPoint(x: leftX, y: topY))
                                            path.addLine(to: CGPoint(x: rightX, y: topY))

                                            // Right vertical
                                            path.move(to: CGPoint(x: rightX, y: topY))
                                            path.addLine(to: CGPoint(x: rightX, y: baseY))
                                        }
                                        .stroke(bracketColor, lineWidth: CGFloat(bracketWidth))
                                    }
                                    .frame(height: 80)
                                }
                            }
                            .frame(height: 120)
                        }
                    }

                    // Current Settings Section
                    Section("Current Volcano Conditions") {
                        HStack {
                            Text("Left Condition:")
                                .font(.subheadline)
                            Spacer()
                            Text(curtainData.settings.volcanoConditionLabels.leftCondition.isEmpty ? "Not set" : curtainData.settings.volcanoConditionLabels.leftCondition)
                                .font(.caption)
                                .foregroundColor(curtainData.settings.volcanoConditionLabels.leftCondition.isEmpty ? .red : .secondary)
                        }

                        HStack {
                            Text("Right Condition:")
                                .font(.subheadline)
                            Spacer()
                            Text(curtainData.settings.volcanoConditionLabels.rightCondition.isEmpty ? "Not set" : curtainData.settings.volcanoConditionLabels.rightCondition)
                                .font(.caption)
                                .foregroundColor(curtainData.settings.volcanoConditionLabels.rightCondition.isEmpty ? .red : .secondary)
                        }

                        if curtainData.settings.volcanoConditionLabels.leftCondition.isEmpty || curtainData.settings.volcanoConditionLabels.rightCondition.isEmpty {
                            HStack {
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundColor(.orange)
                                Text("Configure volcano condition labels to enable bracket display")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Condition Bracket")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveSettings()
                        dismiss()

                        // Trigger plot refresh using correct notification name
                        NotificationCenter.default.post(name: NSNotification.Name("ProteinChartRefresh"), object: nil)
                    }
                }
            }
            .onAppear {
                loadSettings()
            }
        }
    }

    // MARK: - Helper Methods

    private func loadSettings() {
        let settings = curtainData.settings.barChartConditionBracket
        showBracket = settings.showBracket
        bracketHeight = settings.bracketHeight
        bracketColorHex = settings.bracketColor
        bracketColor = hexToColor(settings.bracketColor) ?? .black
        bracketWidth = settings.bracketWidth

    }

    private func saveSettings() {
        // Create updated bracket settings
        let updatedBracket = BarChartConditionBracket(
            showBracket: showBracket,
            bracketHeight: bracketHeight,
            bracketColor: bracketColorHex,
            bracketWidth: bracketWidth
        )

        // Create updated settings with the new bracket settings
        let updatedSettings = CurtainSettings(
            fetchUniprot: curtainData.settings.fetchUniprot,
            inputDataCols: curtainData.settings.inputDataCols,
            probabilityFilterMap: curtainData.settings.probabilityFilterMap,
            barchartColorMap: curtainData.settings.barchartColorMap,
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
            barChartConditionBracket: updatedBracket,  // ← Updated bracket settings
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
            permanent: curtainData.permanent
        )

        curtainData = updatedCurtainData

    }

    private func hexToColor(_ hex: String) -> Color? {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0

        return Color(red: r, green: g, blue: b)
    }

    private func colorToHex(_ color: Color) -> String {
        guard let components = UIColor(color).cgColor.components else {
            return "#000000"
        }

        let r = Int(components[0] * 255.0)
        let g = Int(components[1] * 255.0)
        let b = Int(components[2] * 255.0)

        return String(format: "#%02X%02X%02X", r, g, b)
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var sampleData = CurtainData(
        settings: CurtainSettings()
    )

    BarChartConditionBracketSettingsView(curtainData: $sampleData)
}

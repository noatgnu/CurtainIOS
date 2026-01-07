//
//  VolcanoConditionLabelsSettingsView.swift
//  Curtain
//
//  Created by Toan Phung on 05/01/2026.
//

import SwiftUI

// MARK: - Volcano Condition Labels Settings View

struct VolcanoConditionLabelsSettingsView: View {
    @Binding var curtainData: CurtainData
    @Environment(\.dismiss) private var dismiss

    // Local state for editing
    @State private var enabled: Bool = false
    @State private var leftCondition: String = ""
    @State private var rightCondition: String = ""
    @State private var leftX: Double = 0.25
    @State private var rightX: Double = 0.75
    @State private var yPosition: Double = -0.1
    @State private var fontSize: Int = 14
    @State private var fontColor: Color = .black
    @State private var fontColorHex: String = "#000000"

    // Available conditions from the data
    @State private var availableConditions: [String] = []

    var body: some View {
        NavigationView {
            Form {
                // Enable/Disable Section
                Section {
                    Toggle("Enable Condition Labels", isOn: $enabled)

                    if enabled {
                        Text("Show condition labels below the volcano plot")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                if enabled {
                    // Condition Selection Section
                    Section("Conditions") {
                        // Left Condition
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Left Condition (Decrease)")
                                .font(.subheadline)
                                .fontWeight(.medium)

                            if availableConditions.isEmpty {
                                TextField("Enter condition name", text: $leftCondition)
                                    .textFieldStyle(.roundedBorder)
                            } else {
                                Picker("Left Condition", selection: $leftCondition) {
                                    Text("None").tag("")
                                    ForEach(availableConditions, id: \.self) { condition in
                                        Text(condition).tag(condition)
                                    }
                                }
                                .pickerStyle(.menu)

                                TextField("Or enter custom name", text: $leftCondition)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.caption)
                            }
                        }

                        // Right Condition
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Right Condition (Increase)")
                                .font(.subheadline)
                                .fontWeight(.medium)

                            if availableConditions.isEmpty {
                                TextField("Enter condition name", text: $rightCondition)
                                    .textFieldStyle(.roundedBorder)
                            } else {
                                Picker("Right Condition", selection: $rightCondition) {
                                    Text("None").tag("")
                                    ForEach(availableConditions, id: \.self) { condition in
                                        Text(condition).tag(condition)
                                    }
                                }
                                .pickerStyle(.menu)

                                TextField("Or enter custom name", text: $rightCondition)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.caption)
                            }
                        }
                    }

                    // Position Section
                    Section("Label Positioning") {
                        VStack(spacing: 16) {
                            // Left X Position
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("Left Label X Position")
                                        .font(.subheadline)
                                    Spacer()
                                    Text("\(leftX, specifier: "%.2f")")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Slider(value: $leftX, in: 0...1, step: 0.05)

                                Text("Horizontal position (0 = left edge, 1 = right edge)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            // Right X Position
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("Right Label X Position")
                                        .font(.subheadline)
                                    Spacer()
                                    Text("\(rightX, specifier: "%.2f")")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Slider(value: $rightX, in: 0...1, step: 0.05)

                                Text("Horizontal position (0 = left edge, 1 = right edge)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            // Y Position
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("Vertical Position")
                                        .font(.subheadline)
                                    Spacer()
                                    Text("\(yPosition, specifier: "%.2f")")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Slider(value: $yPosition, in: -0.3...0.3, step: 0.01)

                                Text("Vertical position (negative = below plot, positive = above plot)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            // Reset to Defaults Button
                            Button(action: resetPositionsToDefaults) {
                                HStack {
                                    Image(systemName: "arrow.counterclockwise")
                                    Text("Reset to Defaults")
                                }
                            }
                            .buttonStyle(.borderless)
                            .foregroundColor(.blue)

                            // Auto-Adjust Button
                            Button(action: autoAdjustConditionLabels) {
                                HStack {
                                    Image(systemName: "arrow.up.arrow.down")
                                    Text("Auto-Adjust to Avoid Overlap")
                                }
                            }
                            .buttonStyle(.borderless)
                            .foregroundColor(.blue)

                            Text("Automatically adjusts Y position to avoid overlap with legend")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    // Font Settings Section
                    Section("Font Settings") {
                        // Font Size
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Font Size")
                                    .font(.subheadline)
                                Spacer()
                                Text("\(fontSize)pt")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Stepper("", value: $fontSize, in: 8...24, step: 1)
                                .labelsHidden()
                        }

                        // Font Color
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Font Color")
                                .font(.subheadline)

                            HStack {
                                // Color Preview
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(fontColor)
                                    .frame(width: 40, height: 40)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.primary.opacity(0.2), lineWidth: 1)
                                    )

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(fontColorHex)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .textSelection(.enabled)
                                }

                                Spacer()

                                // Color Picker
                                ColorPicker("", selection: $fontColor)
                                    .labelsHidden()
                                    .onChange(of: fontColor) { _, newColor in
                                        fontColorHex = newColor.toHex() ?? "#000000"
                                    }
                            }

                            // Manual Hex Input
                            HStack {
                                TextField("#000000", text: $fontColorHex)
                                    .textFieldStyle(.roundedBorder)
                                    .autocapitalization(.allCharacters)
                                    .font(.caption)

                                Button("Apply") {
                                    applyHexColor()
                                }
                                .font(.caption)
                                .buttonStyle(.bordered)
                                .disabled(fontColorHex.isEmpty)
                            }
                        }
                    }

                    // Preview Section
                    Section("Preview") {
                        VStack(spacing: 12) {
                            Text("The labels will appear below the volcano plot like this:")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            HStack {
                                if !leftCondition.isEmpty {
                                    Text(leftCondition)
                                        .font(.system(size: CGFloat(fontSize)))
                                        .foregroundColor(fontColor)
                                        .frame(maxWidth: .infinity, alignment: .center)
                                        .padding(.leading, CGFloat(leftX) * 100)
                                }

                                Spacer()

                                if !rightCondition.isEmpty {
                                    Text(rightCondition)
                                        .font(.system(size: CGFloat(fontSize)))
                                        .foregroundColor(fontColor)
                                        .frame(maxWidth: .infinity, alignment: .center)
                                        .padding(.trailing, (1.0 - CGFloat(rightX)) * 100)
                                }
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
            .navigationTitle("Condition Labels")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        saveChanges()
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadCurrentSettings()
                loadAvailableConditions()
            }
        }
    }

    // MARK: - Data Management

    private func loadCurrentSettings() {
        let labels = curtainData.settings.volcanoConditionLabels
        enabled = labels.enabled
        leftCondition = labels.leftCondition
        rightCondition = labels.rightCondition
        leftX = labels.leftX
        rightX = labels.rightX
        yPosition = labels.yPosition
        fontSize = labels.fontSize
        fontColorHex = labels.fontColor
        fontColor = Color(hex: labels.fontColor) ?? .black
    }

    private func loadAvailableConditions() {
        // Extract unique conditions from conditionOrder
        availableConditions = curtainData.settings.conditionOrder
    }

    private func resetPositionsToDefaults() {
        leftX = 0.25
        rightX = 0.75
        yPosition = -0.1
    }

    private func autoAdjustConditionLabels() {
        // Get legend Y position (default is -0.1 if not set)
        let legendY = curtainData.settings.volcanoPlotLegendY ?? -0.1
        let labelY = yPosition

        // If both are below plot (negative) and too close (within 0.1), adjust label position
        if legendY < 0 && labelY < 0 && abs(legendY - labelY) < 0.1 {
            yPosition = legendY + 0.1
        } else {
        }
    }

    private func applyHexColor() {
        if let color = Color(hex: fontColorHex) {
            fontColor = color
        }
    }

    private func saveChanges() {
        // Create updated volcanoConditionLabels
        let updatedLabels = VolcanoConditionLabels(
            enabled: enabled,
            leftCondition: leftCondition,
            rightCondition: rightCondition,
            leftX: leftX,
            rightX: rightX,
            yPosition: yPosition,
            fontSize: fontSize,
            fontColor: fontColorHex
        )

        // Create updated settings with the new condition labels
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
            volcanoConditionLabels: updatedLabels,  // ← New condition labels
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
            permanent: curtainData.permanent
        )

        curtainData = updatedCurtainData

        // Trigger volcano plot refresh
        NotificationCenter.default.post(
            name: NSNotification.Name("VolcanoPlotRefresh"),
            object: nil,
            userInfo: ["reason": "conditionLabelsUpdate"]
        )

    }
}

#Preview {
    VolcanoConditionLabelsSettingsView(curtainData: .constant(CurtainData.previewData()))
}

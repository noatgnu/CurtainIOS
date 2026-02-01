//
//  GlobalYAxisLimitsSettingsView.swift
//  Curtain
//
//  Created by Toan Phung on 05/01/2026.
//

import SwiftUI

// MARK: - Global Y-Axis Limits Settings View

struct GlobalYAxisLimitsSettingsView: View {
    @Binding var curtainData: CurtainData
    @Environment(\.dismiss) private var dismiss

    // Local state for editing - Bar Chart
    @State private var barChartMinEnabled: Bool = false
    @State private var barChartMaxEnabled: Bool = false
    @State private var barChartMin: String = ""
    @State private var barChartMax: String = ""

    // Local state for editing - Average Bar Chart
    @State private var avgBarChartMinEnabled: Bool = false
    @State private var avgBarChartMaxEnabled: Bool = false
    @State private var avgBarChartMin: String = ""
    @State private var avgBarChartMax: String = ""

    // Local state for editing - Violin Plot
    @State private var violinPlotMinEnabled: Bool = false
    @State private var violinPlotMaxEnabled: Bool = false
    @State private var violinPlotMin: String = ""
    @State private var violinPlotMax: String = ""

    var body: some View {
        NavigationStack {
            Form {
                // Info Section
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Global Y-Axis Limits")
                            .font(.headline)

                        Text("Set consistent Y-axis ranges for all protein charts of each type. Leave fields disabled for automatic scaling.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 4)
                }

                // Bar Chart Section
                Section("Bar Chart") {
                    ChartLimitInputs(
                        minEnabled: $barChartMinEnabled,
                        maxEnabled: $barChartMaxEnabled,
                        minValue: $barChartMin,
                        maxValue: $barChartMax,
                        chartTypeName: "Bar Chart"
                    )
                }

                // Average Bar Chart Section
                Section("Average Bar Chart") {
                    ChartLimitInputs(
                        minEnabled: $avgBarChartMinEnabled,
                        maxEnabled: $avgBarChartMaxEnabled,
                        minValue: $avgBarChartMin,
                        maxValue: $avgBarChartMax,
                        chartTypeName: "Average Bar Chart"
                    )
                }

                // Violin Plot Section
                Section("Violin Plot") {
                    ChartLimitInputs(
                        minEnabled: $violinPlotMinEnabled,
                        maxEnabled: $violinPlotMaxEnabled,
                        minValue: $violinPlotMin,
                        maxValue: $violinPlotMax,
                        chartTypeName: "Violin Plot"
                    )
                }

                // Reset Section
                Section {
                    Button(action: resetAllToDefaults) {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Reset All to Auto")
                        }
                        .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Y-Axis Limits")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
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
                loadCurrentSettings()
            }
        }
    }

    // MARK: - Data Management

    private func loadCurrentSettings() {
        // Bar Chart
        if let limits = curtainData.settings.chartYAxisLimits["barChart"] {
            if let min = limits.min {
                barChartMinEnabled = true
                barChartMin = String(min)
            }
            if let max = limits.max {
                barChartMaxEnabled = true
                barChartMax = String(max)
            }
        }

        // Average Bar Chart
        if let limits = curtainData.settings.chartYAxisLimits["averageBarChart"] {
            if let min = limits.min {
                avgBarChartMinEnabled = true
                avgBarChartMin = String(min)
            }
            if let max = limits.max {
                avgBarChartMaxEnabled = true
                avgBarChartMax = String(max)
            }
        }

        // Violin Plot
        if let limits = curtainData.settings.chartYAxisLimits["violinPlot"] {
            if let min = limits.min {
                violinPlotMinEnabled = true
                violinPlotMin = String(min)
            }
            if let max = limits.max {
                violinPlotMaxEnabled = true
                violinPlotMax = String(max)
            }
        }

    }

    private func resetAllToDefaults() {
        barChartMinEnabled = false
        barChartMaxEnabled = false
        barChartMin = ""
        barChartMax = ""

        avgBarChartMinEnabled = false
        avgBarChartMaxEnabled = false
        avgBarChartMin = ""
        avgBarChartMax = ""

        violinPlotMinEnabled = false
        violinPlotMaxEnabled = false
        violinPlotMin = ""
        violinPlotMax = ""
    }

    private func saveChanges() {
        // Create updated chart Y-axis limits
        var updatedLimits: [String: ChartYAxisLimits] = [:]

        // Bar Chart
        let barChartLimits = ChartYAxisLimits(
            min: barChartMinEnabled ? Double(barChartMin) : nil,
            max: barChartMaxEnabled ? Double(barChartMax) : nil
        )
        updatedLimits["barChart"] = barChartLimits

        // Average Bar Chart
        let avgBarChartLimits = ChartYAxisLimits(
            min: avgBarChartMinEnabled ? Double(avgBarChartMin) : nil,
            max: avgBarChartMaxEnabled ? Double(avgBarChartMax) : nil
        )
        updatedLimits["averageBarChart"] = avgBarChartLimits

        // Violin Plot
        let violinPlotLimits = ChartYAxisLimits(
            min: violinPlotMinEnabled ? Double(violinPlotMin) : nil,
            max: violinPlotMaxEnabled ? Double(violinPlotMax) : nil
        )
        updatedLimits["violinPlot"] = violinPlotLimits

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
            chartYAxisLimits: updatedLimits,  // ← Updated global Y-axis limits
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
            dbPath: curtainData.dbPath,
            linkId: curtainData.linkId
        )

        curtainData = updatedCurtainData

    }
}

// MARK: - Chart Limit Inputs Component

struct ChartLimitInputs: View {
    @Binding var minEnabled: Bool
    @Binding var maxEnabled: Bool
    @Binding var minValue: String
    @Binding var maxValue: String
    let chartTypeName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Minimum Value
            VStack(alignment: .leading, spacing: 4) {
                Toggle("Set Minimum", isOn: $minEnabled)
                    .font(.subheadline)
                    .fontWeight(.medium)

                if minEnabled {
                    TextField("Minimum Y value", text: $minValue)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.decimalPad)
                        .font(.caption)
                }
            }

            // Maximum Value
            VStack(alignment: .leading, spacing: 4) {
                Toggle("Set Maximum", isOn: $maxEnabled)
                    .font(.subheadline)
                    .fontWeight(.medium)

                if maxEnabled {
                    TextField("Maximum Y value", text: $maxValue)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.decimalPad)
                        .font(.caption)
                }
            }

            // Info text
            if minEnabled || maxEnabled {
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(.blue)
                        .font(.caption)
                    Text("All \(chartTypeName)s will use these limits")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 4)
            } else {
                HStack {
                    Image(systemName: "checkmark.circle")
                        .foregroundColor(.green)
                        .font(.caption)
                    Text("Using automatic scaling")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 4)
            }
        }
    }
}

#Preview {
    GlobalYAxisLimitsSettingsView(curtainData: .constant(CurtainData.previewData()))
}

//
//  IndividualYAxisLimitsSettingsView.swift
//  Curtain
//
//  Created by Toan Phung on 05/01/2026.
//

import SwiftUI

// MARK: - Individual Y-Axis Limits Settings View

struct IndividualYAxisLimitsSettingsView: View {
    @Binding var curtainData: CurtainData
    let proteinId: String
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

    // Track if any individual limits are set
    private var hasIndividualLimits: Bool {
        barChartMinEnabled || barChartMaxEnabled ||
        avgBarChartMinEnabled || avgBarChartMaxEnabled ||
        violinPlotMinEnabled || violinPlotMaxEnabled
    }

    private var displayName: String {
        // Try to get gene name from UniProt
        if let uniprotDB = curtainData.extraData?.uniprot?.db as? [String: Any],
           let uniprotRecord = uniprotDB[proteinId] as? [String: Any],
           let geneNames = uniprotRecord["Gene Names"] as? String,
           !geneNames.isEmpty {
            let firstGeneName = geneNames.components(separatedBy: CharacterSet(charactersIn: " ;"))
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .first

            if let geneName = firstGeneName, geneName != proteinId {
                return "\(geneName) (\(proteinId))"
            }
        }

        return proteinId
    }

    var body: some View {
        NavigationView {
            Form {
                // Info Section
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Individual Y-Axis Limits")
                            .font(.headline)

                        Text("Set custom Y-axis ranges for \(displayName). These limits override global settings.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        if hasIndividualLimits {
                            HStack {
                                Image(systemName: "star.fill")
                                    .foregroundColor(.yellow)
                                    .font(.caption)
                                Text("Individual limits active - overriding global settings")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                            .padding(.top, 4)
                        } else {
                            HStack {
                                Image(systemName: "globe")
                                    .foregroundColor(.blue)
                                    .font(.caption)
                                Text("Using global or auto settings")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.top, 4)
                        }
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

                // Actions Section
                Section {
                    Button(action: clearAllLimits) {
                        HStack {
                            Image(systemName: "trash")
                            Text("Clear All Individual Limits")
                        }
                        .foregroundColor(.red)
                    }
                    .disabled(!hasIndividualLimits)
                }
            }
            .navigationTitle("Y-Axis Limits")
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
            }
        }
    }

    // MARK: - Data Management

    private func loadCurrentSettings() {
        // Try to load existing individual limits for this protein
        if let individualLimitsForProtein = curtainData.settings.individualYAxisLimits[proteinId] as? [String: [String: Double]] {
            // Bar Chart
            if let barChartLimits = individualLimitsForProtein["barChart"] {
                if let min = barChartLimits["min"] {
                    barChartMinEnabled = true
                    barChartMin = String(min)
                }
                if let max = barChartLimits["max"] {
                    barChartMaxEnabled = true
                    barChartMax = String(max)
                }
            }

            // Average Bar Chart
            if let avgBarChartLimits = individualLimitsForProtein["averageBarChart"] {
                if let min = avgBarChartLimits["min"] {
                    avgBarChartMinEnabled = true
                    avgBarChartMin = String(min)
                }
                if let max = avgBarChartLimits["max"] {
                    avgBarChartMaxEnabled = true
                    avgBarChartMax = String(max)
                }
            }

            // Violin Plot
            if let violinPlotLimits = individualLimitsForProtein["violinPlot"] {
                if let min = violinPlotLimits["min"] {
                    violinPlotMinEnabled = true
                    violinPlotMin = String(min)
                }
                if let max = violinPlotLimits["max"] {
                    violinPlotMaxEnabled = true
                    violinPlotMax = String(max)
                }
            }

            print("📋 IndividualYAxisLimitsSettings: Loaded individual limits for protein '\(proteinId)'")
        } else {
            print("📋 IndividualYAxisLimitsSettings: No individual limits set for protein '\(proteinId)'")
        }
    }

    private func clearAllLimits() {
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
        // Get existing individual limits or create new dictionary
        var updatedIndividualLimits = curtainData.settings.individualYAxisLimits

        // Check if we have any limits set for this protein
        if hasIndividualLimits {
            // Create limits dictionary for this protein
            var proteinLimits: [String: [String: Double]] = [:]

            // Bar Chart
            if barChartMinEnabled || barChartMaxEnabled {
                var barChartLimits: [String: Double] = [:]
                if barChartMinEnabled, let min = Double(barChartMin) {
                    barChartLimits["min"] = min
                }
                if barChartMaxEnabled, let max = Double(barChartMax) {
                    barChartLimits["max"] = max
                }
                if !barChartLimits.isEmpty {
                    proteinLimits["barChart"] = barChartLimits
                }
            }

            // Average Bar Chart
            if avgBarChartMinEnabled || avgBarChartMaxEnabled {
                var avgBarChartLimits: [String: Double] = [:]
                if avgBarChartMinEnabled, let min = Double(avgBarChartMin) {
                    avgBarChartLimits["min"] = min
                }
                if avgBarChartMaxEnabled, let max = Double(avgBarChartMax) {
                    avgBarChartLimits["max"] = max
                }
                if !avgBarChartLimits.isEmpty {
                    proteinLimits["averageBarChart"] = avgBarChartLimits
                }
            }

            // Violin Plot
            if violinPlotMinEnabled || violinPlotMaxEnabled {
                var violinPlotLimits: [String: Double] = [:]
                if violinPlotMinEnabled, let min = Double(violinPlotMin) {
                    violinPlotLimits["min"] = min
                }
                if violinPlotMaxEnabled, let max = Double(violinPlotMax) {
                    violinPlotLimits["max"] = max
                }
                if !violinPlotLimits.isEmpty {
                    proteinLimits["violinPlot"] = violinPlotLimits
                }
            }

            updatedIndividualLimits[proteinId] = proteinLimits
        } else {
            // No limits set, remove this protein's entry
            updatedIndividualLimits.removeValue(forKey: proteinId)
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
            individualYAxisLimits: updatedIndividualLimits,  // ← Updated individual Y-axis limits
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

        // Trigger protein chart refresh
        NotificationCenter.default.post(
            name: NSNotification.Name("ProteinChartRefresh"),
            object: nil,
            userInfo: ["reason": "individualYAxisLimitsUpdate", "proteinId": proteinId]
        )

        print("✅ IndividualYAxisLimitsSettings: Updated individual Y-axis limits for protein '\(proteinId)'")
    }
}

#Preview {
    IndividualYAxisLimitsSettingsView(
        curtainData: .constant(CurtainData.previewData()),
        proteinId: "P12345"
    )
}

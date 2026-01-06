//
//  ColumnSizeSettingsView.swift
//  Curtain
//
//  Created by Toan Phung on 06/01/2026.
//

import SwiftUI

// MARK: - Column Size Settings View

struct ColumnSizeSettingsView: View {
    @Binding var curtainData: CurtainData
    @Environment(\.dismiss) private var dismiss

    // Local state for editing
    @State private var barChartColumnSize: String = "0"
    @State private var averageBarChartColumnSize: String = "0"
    @State private var violinPlotColumnSize: String = "0"

    var body: some View {
        NavigationView {
            Form {
                // Info Section
                Section {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Column size controls the width of individual bars/columns in charts")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("Formula: width = marginLeft + marginRight + (columnSize × itemCount)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text("Set to 0 for auto width (default)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // Bar Chart Section
                Section("Bar Chart") {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Column Width")
                                .font(.subheadline)
                            Text("Width per sample in pixels")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        TextField("0", text: $barChartColumnSize)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.numberPad)
                            .frame(width: 80)
                            .multilineTextAlignment(.trailing)
                    }

                    if let size = Int(barChartColumnSize), size > 0 {
                        HStack {
                            Text("Status:")
                                .font(.caption)
                            Spacer()
                            Text("\(size) pixels per sample")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    } else {
                        HStack {
                            Text("Status:")
                                .font(.caption)
                            Spacer()
                            Text("Auto width")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // Average Bar Chart Section
                Section("Average Bar Chart") {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Column Width")
                                .font(.subheadline)
                            Text("Width per condition in pixels")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        TextField("0", text: $averageBarChartColumnSize)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.numberPad)
                            .frame(width: 80)
                            .multilineTextAlignment(.trailing)
                    }

                    if let size = Int(averageBarChartColumnSize), size > 0 {
                        HStack {
                            Text("Status:")
                                .font(.caption)
                            Spacer()
                            Text("\(size) pixels per condition")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    } else {
                        HStack {
                            Text("Status:")
                                .font(.caption)
                            Spacer()
                            Text("Auto width")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // Violin Plot Section
                Section("Violin Plot") {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Plot Width")
                                .font(.subheadline)
                            Text("Width per condition in pixels")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        TextField("0", text: $violinPlotColumnSize)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.numberPad)
                            .frame(width: 80)
                            .multilineTextAlignment(.trailing)
                    }

                    if let size = Int(violinPlotColumnSize), size > 0 {
                        HStack {
                            Text("Status:")
                                .font(.caption)
                            Spacer()
                            Text("\(size) pixels per condition")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    } else {
                        HStack {
                            Text("Status:")
                                .font(.caption)
                            Spacer()
                            Text("Auto width")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // Reset Section
                Section {
                    Button(action: resetToDefaults) {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Reset All to Auto Width")
                            Spacer()
                        }
                    }
                    .foregroundColor(.orange)
                }
            }
            .navigationTitle("Column Size")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveChanges()
                        dismiss()

                        // Trigger plot refresh
                        NotificationCenter.default.post(name: NSNotification.Name("RefreshPlots"), object: nil)
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
        // Load existing column size settings
        if let barChartSize = curtainData.settings.columnSize["barChart"] {
            barChartColumnSize = String(barChartSize)
        } else {
            barChartColumnSize = "0"
        }

        if let avgBarChartSize = curtainData.settings.columnSize["averageBarChart"] {
            averageBarChartColumnSize = String(avgBarChartSize)
        } else {
            averageBarChartColumnSize = "0"
        }

        if let violinSize = curtainData.settings.columnSize["violinPlot"] {
            violinPlotColumnSize = String(violinSize)
        } else {
            violinPlotColumnSize = "0"
        }

        print("📋 ColumnSizeSettings: Loaded - barChart: \(barChartColumnSize), avgBarChart: \(averageBarChartColumnSize), violin: \(violinPlotColumnSize)")
    }

    private func saveChanges() {
        // Build updated columnSize dictionary
        var updatedColumnSize: [String: Int] = [:]

        if let size = Int(barChartColumnSize), size >= 0 {
            updatedColumnSize["barChart"] = size
        } else {
            updatedColumnSize["barChart"] = 0
        }

        if let size = Int(averageBarChartColumnSize), size >= 0 {
            updatedColumnSize["averageBarChart"] = size
        } else {
            updatedColumnSize["averageBarChart"] = 0
        }

        if let size = Int(violinPlotColumnSize), size >= 0 {
            updatedColumnSize["violinPlot"] = size
        } else {
            updatedColumnSize["violinPlot"] = 0
        }

        // Create updated settings with the new column sizes
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
            columnSize: updatedColumnSize,  // ← Updated column sizes
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

        print("✅ ColumnSizeSettings: Saved - barChart: \(updatedColumnSize["barChart"] ?? 0), avgBarChart: \(updatedColumnSize["averageBarChart"] ?? 0), violin: \(updatedColumnSize["violinPlot"] ?? 0)")
    }

    private func resetToDefaults() {
        barChartColumnSize = "0"
        averageBarChartColumnSize = "0"
        violinPlotColumnSize = "0"
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var sampleData = CurtainData(
        settings: CurtainSettings()
    )

    ColumnSizeSettingsView(curtainData: $sampleData)
}

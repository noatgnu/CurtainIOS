//
//  VolcanoTextColumnSettingsView.swift
//  Curtain
//
//  Created by Toan Phung on 05/01/2026.
//

import SwiftUI

// MARK: - Volcano Custom Text Column Settings View

struct VolcanoTextColumnSettingsView: View {
    @Binding var curtainData: CurtainData
    @Environment(\.dismiss) private var dismiss

    // Local state for editing
    @State private var selectedColumn: String = ""

    // Available columns from the data
    @State private var availableColumns: [String] = []

    var body: some View {
        NavigationView {
            Form {
                // Info Section
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Customize Hover Text")
                            .font(.headline)

                        Text("By default, volcano plot points show gene name and ID on hover. You can override this with any column from your data.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 4)
                }

                // Column Selection Section
                Section("Text Column") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Select Column")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        if availableColumns.isEmpty {
                            Text("No columns available")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Picker("Column", selection: $selectedColumn) {
                                Text("Default (Gene Name + ID)").tag("")
                                ForEach(availableColumns, id: \.self) { column in
                                    Text(column).tag(column)
                                }
                            }
                            .pickerStyle(.menu)

                            if !selectedColumn.isEmpty {
                                HStack {
                                    Image(systemName: "info.circle")
                                        .foregroundColor(.blue)
                                        .font(.caption)
                                    Text("Hover text will show values from '\(selectedColumn)'")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.top, 4)
                            }
                        }
                    }
                }

                // Example Section
                Section("Examples") {
                    VStack(alignment: .leading, spacing: 12) {
                        ExampleRow(
                            title: "Default",
                            description: "Shows: GeneSymbol(P12345)"
                        )

                        if !selectedColumn.isEmpty {
                            ExampleRow(
                                title: "Custom (\(selectedColumn))",
                                description: "Shows: Value from '\(selectedColumn)' column"
                            )
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Hover Text Column")
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
                loadAvailableColumns()
            }
        }
    }

    // MARK: - Data Management

    private func loadCurrentSettings() {
        selectedColumn = curtainData.settings.customVolcanoTextCol
    }

    private func loadAvailableColumns() {
        // Extract column names from raw data (CSV/TSV header)
        if let raw = curtainData.raw, !raw.isEmpty {
            let lines = raw.components(separatedBy: .newlines).filter { !$0.isEmpty }
            if let firstLine = lines.first {
                // Parse header line (tab-separated)
                availableColumns = firstLine.components(separatedBy: "\t")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                    .sorted()
                return
            }
        }
        availableColumns = []
    }

    private func saveChanges() {
        // Create updated settings with the new custom text column
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
            customVolcanoTextCol: selectedColumn,  // ← Updated custom text column
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
            userInfo: ["reason": "customTextColumnUpdate"]
        )

    }
}

// MARK: - Helper Views

struct ExampleRow: View {
    let title: String
    let description: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    VolcanoTextColumnSettingsView(curtainData: .constant(CurtainData.previewData()))
}

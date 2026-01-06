//
//  VolcanoTraceOrderSettingsView.swift
//  Curtain
//
//  Created by Toan Phung on 06/01/2026.
//

import SwiftUI

// MARK: - Volcano Trace Order Settings View

struct VolcanoTraceOrderSettingsView: View {
    @Binding var curtainData: CurtainData
    @Environment(\.dismiss) private var dismiss

    // Local state for editing
    @State private var traceOrder: [String] = []
    @State private var availableTraces: [String] = []
    @State private var isEditing: Bool = false

    var body: some View {
        NavigationView {
            Form {
                // Info Section
                Section {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Control the rendering order of traces in the volcano plot")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("Traces at the top of the list are rendered first (appear behind)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text("Traces at the bottom appear on top of other traces")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // Trace Order Section
                if !traceOrder.isEmpty {
                    Section("Trace Rendering Order") {
                        List {
                            ForEach(traceOrder, id: \.self) { traceName in
                                HStack {
                                    Image(systemName: "line.3.horizontal")
                                        .foregroundColor(.secondary)
                                        .font(.caption)

                                    Text(traceName)
                                        .font(.subheadline)

                                    Spacer()

                                    // Position indicator
                                    if let index = traceOrder.firstIndex(of: traceName) {
                                        Text("#\(index + 1)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color.secondary.opacity(0.2))
                                            .cornerRadius(4)
                                    }
                                }
                            }
                            .onMove { source, destination in
                                traceOrder.move(fromOffsets: source, toOffset: destination)
                            }
                        }
                    }

                    // Instructions Section
                    Section {
                        HStack {
                            Image(systemName: "hand.draw")
                                .foregroundColor(.orange)
                            Text("Tap 'Edit' to drag and reorder traces")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    // Reset Section
                    Section {
                        Button(action: resetToDefaultOrder) {
                            HStack {
                                Image(systemName: "arrow.counterclockwise")
                                Text("Reset to Default Order")
                                Spacer()
                            }
                        }
                        .foregroundColor(.orange)
                    }
                } else {
                    // No traces available
                    Section {
                        HStack {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.orange)
                            Text("No traces found in current volcano plot data")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Trace Order")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        // Edit button
                        if !traceOrder.isEmpty {
                            EditButton()
                                .environment(\.editMode, $isEditing.wrappedValue ? .constant(.active) : .constant(.inactive))
                        }

                        // Save button
                        Button("Save") {
                            saveChanges()
                            dismiss()

                            // Trigger plot refresh
                            NotificationCenter.default.post(name: NSNotification.Name("VolcanoPlotRefresh"), object: nil)
                        }
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
        // Get available traces from selectionsName
        if let selections = curtainData.selectionsName {
            availableTraces = selections.sorted()
        } else {
            availableTraces = []
        }

        // Load existing trace order or use default
        if !curtainData.settings.volcanoTraceOrder.isEmpty {
            // Use configured order
            traceOrder = curtainData.settings.volcanoTraceOrder

            // Add any new traces that aren't in the saved order
            for traceName in availableTraces {
                if !traceOrder.contains(traceName) {
                    traceOrder.append(traceName)
                }
            }

            // Remove any traces that no longer exist
            traceOrder = traceOrder.filter { availableTraces.contains($0) }
        } else {
            // Use default order (alphabetical)
            traceOrder = availableTraces
        }

        print("📋 VolcanoTraceOrder: Loaded \(traceOrder.count) traces in order: \(traceOrder)")
    }

    private func saveChanges() {
        // Create updated settings with the new trace order
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
            volcanoTraceOrder: traceOrder,  // ← Updated trace order
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

        print("✅ VolcanoTraceOrder: Saved trace order: \(traceOrder)")
    }

    private func resetToDefaultOrder() {
        // Reset to alphabetical order
        traceOrder = availableTraces.sorted()
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var sampleData = CurtainData(
        selectionsName: ["Group A", "Group B", "Group C", "Background", "P-value < 0.05", "FC > 2"],
        settings: CurtainSettings()
    )

    VolcanoTraceOrderSettingsView(curtainData: $sampleData)
}

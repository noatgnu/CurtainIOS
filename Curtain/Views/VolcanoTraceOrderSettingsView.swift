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
                            Text("Includes user selections and significance groups (P-value/FC)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text("Traces at the top are rendered first (behind), bottom traces appear on top")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // Trace Order Section
                if !traceOrder.isEmpty {
                    Section {
                        ForEach(traceOrder, id: \.self) { traceName in
                            HStack {
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
                    } header: {
                        Text("Trace Rendering Order (Drag to Reorder)")
                    }
                    .environment(\.editMode, .constant(.active))

                    // Instructions Section
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "info.circle.fill")
                                    .foregroundColor(.blue)
                                Text("Rendering Order")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 8) {
                                    Text("•")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text("Top of list = renders first (behind other traces)")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                HStack(spacing: 8) {
                                    Text("•")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text("Bottom of list = renders last (on top of other traces)")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }

                            Divider()

                            HStack {
                                Image(systemName: "hand.draw")
                                    .foregroundColor(.orange)
                                Text("How to reorder:")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 8) {
                                    Text("1.")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    Text("Drag traces using ≡ handles")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                HStack(spacing: 8) {
                                    Text("2.")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    Text("Tap 'Save' to apply changes")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
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
                    // Save button
                    Button("Save") {
                        saveChanges()
                        dismiss()

                        // Trigger plot refresh
                        NotificationCenter.default.post(name: NSNotification.Name("VolcanoPlotRefresh"), object: nil)
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
        // Get available traces from the actual rendered plot (matching Angular behavior)
        // Angular passes this.graphData to the modal, which contains the actual plotted traces
        let allTraces: [String]
        if let renderedTraces = PlotlyCoordinator.sharedCoordinator?.renderedTraceNames {
            allTraces = renderedTraces
            print("📋 VolcanoTraceOrder: Using \(allTraces.count) traces from actual rendered plot")
        } else {
            // Fallback to colorMap if coordinator data not available yet
            allTraces = Array(curtainData.settings.colorMap.keys).sorted()
            print("⚠️ VolcanoTraceOrder: No rendered trace data available, using colorMap keys (\(allTraces.count) traces)")
        }

        // Initialize with current custom order if it exists, matching Angular behavior
        if !curtainData.settings.volcanoTraceOrder.isEmpty {
            print("📋 VolcanoTraceOrder: Using saved custom order: \(curtainData.settings.volcanoTraceOrder)")

            // Start with the configured order
            traceOrder = curtainData.settings.volcanoTraceOrder

            // Add any new traces that aren't in the saved order
            for traceName in allTraces {
                if !traceOrder.contains(traceName) {
                    traceOrder.append(traceName)
                    print("   + Added new trace '\(traceName)' to end of order")
                }
            }

            // Remove any traces that no longer exist
            let beforeCount = traceOrder.count
            traceOrder = traceOrder.filter { allTraces.contains($0) }
            if traceOrder.count < beforeCount {
                print("   - Removed \(beforeCount - traceOrder.count) obsolete traces")
            }
        } else {
            // No custom order - use the CURRENT ACTUAL render order from the plot
            // (allTraces is already renderedTraceNames which has the correct order)
            traceOrder = allTraces
            print("📋 VolcanoTraceOrder: No custom order found, showing current render order: \(traceOrder)")
        }

        print("📋 VolcanoTraceOrder: Final loaded order (\(traceOrder.count) traces): \(traceOrder)")
        print("💡 VolcanoTraceOrder: This is the CURRENT render order - modify to change plot rendering")
    }

    private func saveChanges() {
        print("💾 VolcanoTraceOrder: Saving trace order: \(traceOrder)")
        print("💾 VolcanoTraceOrder: This order will be used for rendering (top = rendered first/behind, bottom = rendered last/on top)")

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
        // Reset to the default render order (from the current plot)
        if let renderedTraces = PlotlyCoordinator.sharedCoordinator?.renderedTraceNames {
            traceOrder = renderedTraces
            print("🔄 VolcanoTraceOrder: Reset to default render order: \(traceOrder)")
        } else {
            // Fallback to alphabetical if no render data available
            traceOrder = Array(curtainData.settings.colorMap.keys).sorted()
            print("🔄 VolcanoTraceOrder: Reset to alphabetical order (no render data): \(traceOrder)")
        }
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

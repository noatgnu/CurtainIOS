//
//  ViolinPointPositionSettingsView.swift
//  Curtain
//
//  Created by Toan Phung on 06/01/2026.
//

import SwiftUI

// MARK: - Violin Point Position Settings View

struct ViolinPointPositionSettingsView: View {
    @Binding var curtainData: CurtainData
    @Environment(\.dismiss) private var dismiss

    // Local state for editing
    @State private var pointPosition: Double = -2.0

    var body: some View {
        NavigationView {
            Form {
                // Info Section
                Section {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Control the horizontal position of individual data points in violin plots")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("Negative values: points on the left side")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text("Positive values: points on the right side")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text("Zero: points centered on the violin")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // Position Slider Section
                Section("Point Position") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Position:")
                                .font(.subheadline)
                            Spacer()
                            Text(String(format: "%.1f", pointPosition))
                                .font(.headline)
                                .foregroundColor(.blue)
                        }

                        Slider(value: $pointPosition, in: -2.0...2.0, step: 0.1)
                            .accentColor(.blue)

                        // Visual guide
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("-2.0")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("Far left")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            VStack(spacing: 2) {
                                Text("0.0")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("Center")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("2.0")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("Far right")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                    .padding(.vertical, 8)
                }

                // Preview Section
                Section("Preview") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "eye")
                                .foregroundColor(.blue)
                            Text("Current Position: \(String(format: "%.1f", pointPosition))")
                                .font(.subheadline)
                        }

                        // Visual representation
                        ZStack {
                            // Violin background
                            RoundedRectangle(cornerRadius: 30)
                                .fill(Color.blue.opacity(0.2))
                                .frame(height: 100)

                            // Point indicator
                            HStack(spacing: 0) {
                                Spacer()
                                    .frame(width: calculatePointOffset(for: pointPosition))

                                Circle()
                                    .fill(Color.blue)
                                    .frame(width: 10, height: 10)
                                    .shadow(radius: 2)

                                Spacer()
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)

                        Text(positionDescription(for: pointPosition))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                    }
                }

                // Reset Section
                Section {
                    Button(action: resetToDefault) {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Reset to Default (-2.0)")
                            Spacer()
                        }
                    }
                    .foregroundColor(.orange)
                }
            }
            .navigationTitle("Violin Point Position")
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
        pointPosition = curtainData.settings.violinPointPos
    }

    private func saveChanges() {
        // Create updated settings with the new point position
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
            individualYAxisLimits: curtainData.settings.individualYAxisLimits,
            violinPointPos: pointPosition,  // ← Updated violin point position
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

    private func resetToDefault() {
        pointPosition = -2.0
    }

    private func calculatePointOffset(for position: Double) -> CGFloat {
        // Map position from -2...2 to 0...1 proportion
        let proportion = (position + 2.0) / 4.0
        // Assuming container width, calculate offset (adjust based on actual UI)
        return CGFloat(proportion) * 300 // Approximate width
    }

    private func positionDescription(for position: Double) -> String {
        if position < -1.5 {
            return "Points positioned far to the left of the violin"
        } else if position < -0.5 {
            return "Points positioned moderately to the left"
        } else if position < 0.5 {
            return "Points positioned near the center"
        } else if position < 1.5 {
            return "Points positioned moderately to the right"
        } else {
            return "Points positioned far to the right of the violin"
        }
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var sampleData = CurtainData(
        settings: CurtainSettings()
    )

    ViolinPointPositionSettingsView(curtainData: $sampleData)
}

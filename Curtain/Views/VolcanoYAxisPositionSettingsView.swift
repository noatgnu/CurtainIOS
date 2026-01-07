//
//  VolcanoYAxisPositionSettingsView.swift
//  Curtain
//
//  Created by Toan Phung on 06/01/2026.
//

import SwiftUI

// MARK: - Volcano Y-Axis Position Settings View

struct VolcanoYAxisPositionSettingsView: View {
    @Binding var curtainData: CurtainData
    @Environment(\.dismiss) private var dismiss

    // Local state for editing
    @State private var showLeft: Bool = false
    @State private var showMiddle: Bool = true

    var body: some View {
        NavigationView {
            Form {
                // Info Section
                Section {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Control the position of the Y-axis in volcano plots")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("You can enable one, both, or neither axis")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // Position Selection Section
                Section("Y-Axis Position") {
                    Toggle(isOn: $showLeft) {
                        HStack {
                            Image(systemName: "arrow.left.square.fill")
                                .foregroundColor(showLeft ? .blue : .gray)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Left")
                                    .fontWeight(.medium)
                                Text("Y-axis at left edge")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .tint(.blue)

                    Toggle(isOn: $showMiddle) {
                        HStack {
                            Image(systemName: "arrow.up.arrow.down.square.fill")
                                .foregroundColor(showMiddle ? .blue : .gray)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Middle")
                                    .fontWeight(.medium)
                                Text("Y-axis at center (x=0)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .tint(.blue)

                    // Current selection summary
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.title3)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Active:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(currentPositionText())
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }

                        Spacer()
                    }
                    .padding(.vertical, 4)
                }

                // Preview Section
                Section("Preview") {
                    VStack(spacing: 12) {
                        Text("Visual Representation")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.gray.opacity(0.1))
                                .frame(height: 150)

                            VStack(spacing: 0) {
                                Spacer()

                                HStack(spacing: 0) {
                                    if showLeft {
                                        VStack(spacing: 2) {
                                            Text("Y")
                                                .font(.caption)
                                                .fontWeight(.bold)
                                                .foregroundColor(.blue)
                                            Rectangle()
                                                .fill(Color.blue)
                                                .frame(width: 2)
                                        }
                                        .frame(width: 30)
                                        .padding(.leading, 8)
                                    }

                                    if showMiddle {
                                        Spacer()

                                        VStack(spacing: 2) {
                                            Text("Y")
                                                .font(.caption)
                                                .fontWeight(.bold)
                                                .foregroundColor(.green)
                                            Rectangle()
                                                .fill(Color.green)
                                                .frame(width: 2)
                                        }
                                        .frame(width: 30)

                                        Spacer()
                                    } else if !showLeft {
                                        Spacer()
                                    } else {
                                        Spacer()
                                    }
                                }
                                .frame(height: 120)

                                HStack(spacing: 4) {
                                    Rectangle()
                                        .fill(Color.gray)
                                        .frame(height: 2)
                                    Text("X")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                .padding(.horizontal, showLeft ? 40 : 8)
                                .padding(.bottom, 8)
                            }
                        }
                        .frame(maxWidth: .infinity)

                        Text(previewText())
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                // Reset Section
                Section {
                    Button(action: resetToDefault) {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Reset to Default (Middle)")
                            Spacer()
                        }
                    }
                    .foregroundColor(.orange)
                }
            }
            .navigationTitle("Y-Axis Position")
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
        let positions = curtainData.settings.volcanoPlotYaxisPosition
        showLeft = positions.contains("left")
        showMiddle = positions.contains("middle")

        if positions.isEmpty {
            showMiddle = true
        }

    }

    private func currentPositionText() -> String {
        if showLeft && showMiddle {
            return "Left + Middle"
        } else if showLeft {
            return "Left"
        } else if showMiddle {
            return "Middle"
        } else {
            return "None"
        }
    }

    private func previewText() -> String {
        if showLeft && showMiddle {
            return "Both Y-axes active"
        } else if showLeft {
            return "Y-axis at left edge only"
        } else if showMiddle {
            return "Y-axis at center (x=0) only"
        } else {
            return "No Y-axis visible"
        }
    }

    private func saveChanges() {
        var positions: [String] = []
        if showLeft {
            positions.append("left")
        }
        if showMiddle {
            positions.append("middle")
        }

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
            volcanoPlotYaxisPosition: positions,
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
        showLeft = false
        showMiddle = true
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var sampleData = CurtainData(
        settings: CurtainSettings()
    )

    VolcanoYAxisPositionSettingsView(curtainData: $sampleData)
}

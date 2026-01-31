//
//  MarkerSizeMapSettingsView.swift
//  Curtain
//
//  Created by Toan Phung on 06/01/2026.
//

import SwiftUI

// MARK: - Marker Size Map Settings View

struct MarkerSizeMapSettingsView: View {
    @Binding var curtainData: CurtainData
    @Environment(\.dismiss) private var dismiss

    // Local state for editing
    @State private var markerSizes: [String: String] = [:]  // Group name -> size as string
    @State private var availableGroups: [String] = []

    var body: some View {
        NavigationView {
            Form {
                // Info Section
                Section {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Configure marker sizes for individual selection groups")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("Groups without custom sizes use the global marker size setting")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // Default Marker Size Section
                Section("Default Marker Size") {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Global Default")
                                .font(.subheadline)
                            Text("Used when no custom size is set")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Text("\(Int(curtainData.settings.scatterPlotMarkerSize)) px")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                // Groups Section
                if !availableGroups.isEmpty {
                    Section("Selection Groups") {
                        ForEach(availableGroups, id: \.self) { groupName in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(groupName)
                                        .font(.subheadline)

                                    if let sizeStr = markerSizes[groupName], let size = Int(sizeStr), size > 0 {
                                        Text("Custom: \(size) px")
                                            .font(.caption2)
                                            .foregroundColor(.green)
                                    } else {
                                        Text("Using default (\(Int(curtainData.settings.scatterPlotMarkerSize)) px)")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }

                                Spacer()

                                TextField("Default", text: Binding(
                                    get: { markerSizes[groupName] ?? "" },
                                    set: { markerSizes[groupName] = $0 }
                                ))
                                .textFieldStyle(.roundedBorder)
                                .keyboardType(.numberPad)
                                .frame(width: 80)
                                .multilineTextAlignment(.trailing)

                                // Clear button
                                if let sizeStr = markerSizes[groupName], !sizeStr.isEmpty {
                                    Button(action: {
                                        markerSizes[groupName] = ""
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.secondary)
                                    }
                                    .buttonStyle(.borderless)
                                }
                            }
                        }
                    }
                } else {
                    Section {
                        HStack {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.orange)
                            Text("No selection groups found in current data")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // Reset Section
                if !availableGroups.isEmpty {
                    Section {
                        Button(action: clearAllCustomSizes) {
                            HStack {
                                Image(systemName: "arrow.counterclockwise")
                                Text("Clear All Custom Sizes")
                                Spacer()
                            }
                        }
                        .foregroundColor(.orange)
                    }
                }
            }
            .navigationTitle("Marker Sizes")
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
        // Get available groups from selectionsName
        if let groups = curtainData.selectionsName {
            availableGroups = groups.sorted()
        } else {
            availableGroups = []
        }

        // Load existing marker sizes for each group
        for groupName in availableGroups {
            if let size = curtainData.settings.markerSizeMap[groupName] as? Int {
                markerSizes[groupName] = String(size)
            } else if let size = curtainData.settings.markerSizeMap[groupName] as? Double {
                markerSizes[groupName] = String(Int(size))
            } else {
                markerSizes[groupName] = ""  // Use default
            }
        }

    }

    private func saveChanges() {
        // Build updated markerSizeMap
        var updatedMarkerSizeMap: [String: Any] = [:]

        for groupName in availableGroups {
            if let sizeStr = markerSizes[groupName],
               let size = Int(sizeStr),
               size > 0 {
                updatedMarkerSizeMap[groupName] = size
            }
            // If empty or 0, don't add to map (will use default)
        }

        // Create updated settings with the new marker size map
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
            violinPointPos: curtainData.settings.violinPointPos,
            networkInteractionData: curtainData.settings.networkInteractionData,
            enrichrGeneRankMap: curtainData.settings.enrichrGeneRankMap,
            enrichrRunList: curtainData.settings.enrichrRunList,
            extraData: curtainData.settings.extraData,
            enableMetabolomics: curtainData.settings.enableMetabolomics,
            metabolomicsColumnMap: curtainData.settings.metabolomicsColumnMap,
            encrypted: curtainData.settings.encrypted,
            dataAnalysisContact: curtainData.settings.dataAnalysisContact,
            markerSizeMap: CurtainSettings.toAnyCodableMap(updatedMarkerSizeMap)  // ← Updated marker size map
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

    private func clearAllCustomSizes() {
        for groupName in availableGroups {
            markerSizes[groupName] = ""
        }
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var sampleData = CurtainData(
        selectionsName: ["Group A", "Group B", "Group C", "Background"],
        settings: CurtainSettings()
    )

    MarkerSizeMapSettingsView(curtainData: $sampleData)
}

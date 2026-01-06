//
//  ExtraDataStorageSettingsView.swift
//  Curtain
//
//  Created by Toan Phung on 06/01/2026.
//

import SwiftUI

// MARK: - Extra Data Storage Settings View

struct ExtraDataStorageSettingsView: View {
    @Binding var curtainData: CurtainData
    @Environment(\.dismiss) private var dismiss

    // Local state for editing
    @State private var extraDataItems: [ExtraDataItem] = []
    @State private var showingAddSheet = false
    @State private var showingEditSheet = false
    @State private var editingItem: ExtraDataItem?
    @State private var editingIndex: Int?

    var body: some View {
        NavigationView {
            Form {
                // Info Section
                Section {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Store additional metadata and notes with your analysis")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("Use this to save custom information, annotations, or references")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // Extra Data Items List
                if !extraDataItems.isEmpty {
                    Section("Stored Items (\(extraDataItems.count))") {
                        ForEach(Array(extraDataItems.enumerated()), id: \.offset) { index, item in
                            Button(action: {
                                editingItem = item
                                editingIndex = index
                                showingEditSheet = true
                            }) {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text(item.name)
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.primary)

                                        Spacer()

                                        if !item.type.isEmpty {
                                            Text(item.type)
                                                .font(.caption)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 2)
                                                .background(Color.blue.opacity(0.2))
                                                .foregroundColor(.blue)
                                                .cornerRadius(4)
                                        }
                                    }

                                    if !item.content.isEmpty {
                                        Text(item.content)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .lineLimit(2)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    deleteItem(at: index)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                } else {
                    Section {
                        HStack {
                            Image(systemName: "tray")
                                .foregroundColor(.orange)
                            Text("No extra data items stored")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // Actions Section
                Section {
                    Button(action: {
                        showingAddSheet = true
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.blue)
                            Text("Add New Item")
                            Spacer()
                        }
                    }

                    if !extraDataItems.isEmpty {
                        Button(action: clearAllItems) {
                            HStack {
                                Image(systemName: "trash")
                                Text("Clear All Items")
                                Spacer()
                            }
                        }
                        .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Extra Data Storage")
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
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                ExtraDataItemEditView(
                    item: nil,
                    onSave: { newItem in
                        extraDataItems.append(newItem)
                        showingAddSheet = false
                    },
                    onCancel: {
                        showingAddSheet = false
                    }
                )
            }
            .sheet(isPresented: $showingEditSheet) {
                if let editingItem = editingItem, let editingIndex = editingIndex {
                    ExtraDataItemEditView(
                        item: editingItem,
                        onSave: { updatedItem in
                            extraDataItems[editingIndex] = updatedItem
                            showingEditSheet = false
                            self.editingItem = nil
                            self.editingIndex = nil
                        },
                        onCancel: {
                            showingEditSheet = false
                            self.editingItem = nil
                            self.editingIndex = nil
                        }
                    )
                }
            }
            .onAppear {
                loadSettings()
            }
        }
    }

    // MARK: - Helper Methods

    private func loadSettings() {
        extraDataItems = curtainData.settings.extraData
        print("📋 ExtraDataStorage: Loaded \(extraDataItems.count) items")
    }

    private func saveChanges() {
        // Create updated settings with the new extra data items
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
            extraData: extraDataItems,  // ← Updated extra data items
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

        print("✅ ExtraDataStorage: Saved \(extraDataItems.count) items")
    }

    private func deleteItem(at index: Int) {
        extraDataItems.remove(at: index)
    }

    private func clearAllItems() {
        extraDataItems.removeAll()
    }
}

// MARK: - Extra Data Item Edit View

struct ExtraDataItemEditView: View {
    let item: ExtraDataItem?
    let onSave: (ExtraDataItem) -> Void
    let onCancel: () -> Void

    @State private var name: String = ""
    @State private var content: String = ""
    @State private var type: String = ""

    var body: some View {
        NavigationView {
            Form {
                Section("Item Details") {
                    TextField("Name", text: $name)
                        .textInputAutocapitalization(.words)

                    TextField("Type (optional)", text: $type)
                        .textInputAutocapitalization(.words)
                }

                Section("Content") {
                    TextEditor(text: $content)
                        .frame(minHeight: 150)
                        .font(.body)
                }

                if item != nil {
                    Section {
                        Text("Editing existing item")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle(item == nil ? "Add Item" : "Edit Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onCancel()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        let newItem = ExtraDataItem(
                            name: name.isEmpty ? "Untitled" : name,
                            content: content,
                            type: type
                        )
                        onSave(newItem)
                    }
                    .disabled(name.isEmpty && content.isEmpty)
                }
            }
            .onAppear {
                if let item = item {
                    name = item.name
                    content = item.content
                    type = item.type
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var sampleData = CurtainData(
        settings: CurtainSettings()
    )

    ExtraDataStorageSettingsView(curtainData: $sampleData)
}

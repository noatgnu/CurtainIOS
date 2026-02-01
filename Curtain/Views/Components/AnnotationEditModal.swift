//
//  AnnotationEditModal.swift
//  Curtain
//
//  Created by Toan Phung on 06/01/2026.
//

import SwiftUI

// MARK: - Annotation Edit Modal

/// Modal for editing annotation text and position
/// Extracted from PlotlyWebView.swift lines 2245-2649
struct AnnotationEditModal: View {
    let candidates: [AnnotationEditCandidate]
    @Binding var curtainData: CurtainData
    @Binding var isPresented: Bool
    let onAnnotationUpdated: () -> Void
    let onInteractivePositioning: (AnnotationEditCandidate) -> Void

    @State private var selectedCandidate: AnnotationEditCandidate?
    @State private var editAction: AnnotationEditAction = .editText
    @State private var editedText: String = ""
    @State private var textOffsetX: Double = -20
    @State private var textOffsetY: Double = -20

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if let selectedCandidate = selectedCandidate {
                    // Show edit interface for selected annotation
                    singleAnnotationEditView(selectedCandidate)
                } else if candidates.count > 1 {
                    // Multiple annotations - show selection list
                    annotationSelectionList
                } else if let candidate = candidates.first {
                    // Single annotation - show edit options directly
                    singleAnnotationEditView(candidate)
                } else {
                    Text("No annotations selected")
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Edit Annotation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if selectedCandidate != nil && candidates.count > 1 {
                        Button("Back") {
                            selectedCandidate = nil
                        }
                        .fixedSize()
                    } else {
                        Button("Cancel") {
                            isPresented = false
                        }
                        .fixedSize()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(editAction == .moveTextInteractive ? "Start Interactive Mode" : "Done") {
                        if let candidate = selectedCandidate {
                            if editAction == .moveTextInteractive {
                                onInteractivePositioning(candidate)
                                isPresented = false
                            } else {
                                saveAnnotationChanges(candidate)
                                isPresented = false
                            }
                        }
                    }
                    .fixedSize()
                    .disabled(selectedCandidate == nil && candidates.count > 1)
                }
            }
        }
                .onAppear {
                    if candidates.count == 1 {
                        selectedCandidate = candidates.first
                        editedText = extractPlainText(from: candidates.first?.currentText ?? "")
        
                        // Initialize offset values from existing annotation
                        if let candidate = candidates.first,
                           let annotationData = curtainData.settings.textAnnotation[candidate.key]?.value as? [String: Any],
                           let dataSection = annotationData["data"] as? [String: Any] {
                            textOffsetX = dataSection["ax"] as? Double ?? -20
                            textOffsetY = dataSection["ay"] as? Double ?? -20
                        }
                    }
                }
            }
        
            // MARK: - Annotation Selection List
        
            private var annotationSelectionList: some View {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Multiple annotations found:")
                        .font(.headline)
        
                    List(candidates, id: \.key) { candidate in
                        Button(action: {
                            selectedCandidate = candidate
                            editedText = extractPlainText(from: candidate.currentText)
        
                            // Initialize offset values from selected annotation
                            if let annotationData = curtainData.settings.textAnnotation[candidate.key]?.value as? [String: Any],
                               let dataSection = annotationData["data"] as? [String: Any] {
                                textOffsetX = dataSection["ax"] as? Double ?? -20
                                textOffsetY = dataSection["ay"] as? Double ?? -20
                            }
                        }) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(candidate.title)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
        
                                Text(extractPlainText(from: candidate.currentText))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
        
                                Text("Distance: \(candidate.distance, specifier: "%.1f")px")
                                    .font(.caption2)
                                    .foregroundColor(.orange)
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .background(
                            selectedCandidate?.key == candidate.key ?
                            Color.blue.opacity(0.1) : Color.clear
                        )
                        .cornerRadius(8)
                    }
                    .frame(maxHeight: 300)
                }
            }
        
            // MARK: - Single Annotation Edit View
        
            private func singleAnnotationEditView(_ candidate: AnnotationEditCandidate) -> some View {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Edit Annotation: \(candidate.title)")
                        .font(.headline)
        
                    // Edit action selection
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Choose Action:")
                            .font(.subheadline)
                            .fontWeight(.medium)
        
                        VStack(spacing: 8) {
                            Button(action: {
                                editAction = .editText
                            }) {
                                HStack {
                                    Image(systemName: editAction == .editText ? "checkmark.circle.fill" : "circle")
                                    Text("Edit Text")
                                    Spacer()
                                }
                                .foregroundColor(editAction == .editText ? .blue : .primary)
                            }
        
                            Button(action: {
                                editAction = .moveText
                            }) {
                                HStack {
                                    Image(systemName: editAction == .moveText ? "checkmark.circle.fill" : "circle")
                                    Text("Adjust Position (Sliders)")
                                    Spacer()
                                }
                                .foregroundColor(editAction == .moveText ? .blue : .primary)
                            }
        
                            Button(action: {
                                editAction = .moveTextInteractive
                            }) {
                                HStack {
                                    Image(systemName: editAction == .moveTextInteractive ? "checkmark.circle.fill" : "circle")
                                    Text("Move by Tapping on Plot")
                                    Spacer()
                                }
                                .foregroundColor(editAction == .moveTextInteractive ? .blue : .primary)
                            }
                        }
                    }
        
                    if editAction == .editText {
                        // Text editing interface
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Annotation Text:")
                                .font(.subheadline)
                                .fontWeight(.medium)
        
                            TextField("Enter annotation text", text: $editedText)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
        
                            Text("Preview: ")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            + Text(editedText)
                                .font(.caption)
                                .fontWeight(.bold)
                        }
                    } else if editAction == .moveTextInteractive {
                        // Interactive positioning interface
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Interactive Position Movement:")
                                .font(.subheadline)
                                .fontWeight(.medium)
        
                            Text("Use the 'Start Interactive Mode' button above, then tap anywhere on the plot where you want the annotation text to appear. The arrow will stay connected to the data point.")
                                .font(.caption)
                                .foregroundColor(.secondary)
        
                            HStack {
                                Image(systemName: "hand.point.up.left.fill")
                                    .foregroundColor(.blue)
                                Text("Tap 'Start Interactive Mode' button above to begin positioning")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Spacer()
                            }
                            .padding()
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(12)
        
                            Text("💡 Tip: You can tap anywhere on the plot to position the text. The system will calculate the best offset from the data point automatically.")
                                .font(.caption2)
                                .foregroundColor(.blue)
                                .padding()
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(8)
                        }
                    } else {
                        // Position moving interface (sliders)
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Text Position Adjustment:")
                                .font(.subheadline)
                                .fontWeight(.medium)
        
                            Text("Adjust the position of the annotation text relative to the data point:")
                                .font(.caption)
                                .foregroundColor(.secondary)
        
                            // X Offset Control
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Horizontal Offset: \(textOffsetX, specifier: "%.0f")px")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                HStack {
                                    Button("-10") { textOffsetX -= 10 }
                                        .buttonStyle(.bordered)
                                        .font(.caption)
                                    Button("-5") { textOffsetX -= 5 }
                                        .buttonStyle(.bordered)
                                        .font(.caption)
                                    Slider(value: $textOffsetX, in: -100...100, step: 5)
                                    Button("+5") { textOffsetX += 5 }
                                        .buttonStyle(.bordered)
                                        .font(.caption)
                                    Button("+10") { textOffsetX += 10 }
                                        .buttonStyle(.bordered)
                                        .font(.caption)
                                }
                            }
        
                            // Y Offset Control
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Vertical Offset: \(textOffsetY, specifier: "%.0f")px")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                HStack {
                                    Button("-10") { textOffsetY -= 10 }
                                        .buttonStyle(.bordered)
                                        .font(.caption)
                                    Button("-5") { textOffsetY -= 5 }
                                        .buttonStyle(.bordered)
                                        .font(.caption)
                                    Slider(value: $textOffsetY, in: -100...100, step: 5)
                                    Button("+5") { textOffsetY += 5 }
                                        .buttonStyle(.bordered)
                                        .font(.caption)
                                    Button("+10") { textOffsetY += 10 }
                                        .buttonStyle(.bordered)
                                        .font(.caption)
                                }
                            }
        
                            // Reset button
                            HStack {
                                Button("Reset to Default") {
                                    textOffsetX = -20
                                    textOffsetY = -20
                                }
                                .buttonStyle(.bordered)
        
                                Spacer()
        
                                Text("Arrow stays at data point")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .italic()
                            }
        
                            Text("Preview: Text will be positioned \(textOffsetX, specifier: "%.0f")px horizontally and \(textOffsetY, specifier: "%.0f")px vertically from the data point.")
                                .font(.caption)
                                .foregroundColor(.blue)
                                .padding()
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(8)
                        }
                    }
                }
            }
        
            // MARK: - Helper Methods
        
            private func extractPlainText(from htmlText: String) -> String {
                // Remove HTML tags like <b> and </b>
                return htmlText
                    .replacingOccurrences(of: "<b>", with: "")
                    .replacingOccurrences(of: "</b>", with: "")
                    .replacingOccurrences(of: "<i>", with: "")
                    .replacingOccurrences(of: "</i>", with: "")
            }
        
            private func saveAnnotationChanges(_ candidate: AnnotationEditCandidate) {
                var updatedTextAnnotation = curtainData.settings.textAnnotation
        
                guard var annotationData = updatedTextAnnotation[candidate.key]?.value as? [String: Any],
                      var dataSection = annotationData["data"] as? [String: Any] else {
                    return
                }
        
                if editAction == .editText {
                    // Update the text
                    let newHtmlText = "<b>\(editedText)</b>"
                    dataSection["text"] = newHtmlText
                    annotationData["data"] = dataSection
                    updatedTextAnnotation[candidate.key] = AnyCodable(annotationData)
        
                } else if editAction == .moveText {
                    // Update the text position offsets
                    dataSection["ax"] = textOffsetX
                    dataSection["ay"] = textOffsetY
                    annotationData["data"] = dataSection
                    updatedTextAnnotation[candidate.key] = AnyCodable(annotationData)
        
                }
        
                // Update the CurtainData with new textAnnotation
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
                    textAnnotation: updatedTextAnnotation, // Updated textAnnotation (already AnyCodable map)
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
                                markerSizeMap: curtainData.settings.markerSizeMap
                            )
                    
                            // Update CurtainData
                            curtainData = CurtainData(
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
                    
                    
                            // Trigger plot refresh
                            onAnnotationUpdated()
                        }
                    }
                    

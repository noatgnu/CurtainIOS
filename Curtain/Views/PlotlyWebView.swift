//
//  PlotlyWebView.swift
//  Curtain
//
//  Created by Toan Phung on 02/08/2025.
//

import SwiftUI
import WebKit
import Combine


struct AnnotationEditCandidate {
    let key: String
    let title: String
    let currentText: String
    let arrowPosition: CGPoint  // Arrow tip position in plot coordinates
    let textPosition: CGPoint   // Current text position in plot coordinates
    let distance: Double        // Distance from tap point
}

enum AnnotationEditAction {
    case editText
    case moveText
    case moveTextInteractive
}

struct PlotlyWebView: UIViewRepresentable {
    let curtainData: CurtainData
    let plotType: PlotType
    let selections: [SelectionOperation]
    let searchFilter: String?
    let editMode: Bool
    let curtainDataService: CurtainDataService?
    @Binding var isLoading: Bool
    @Binding var error: String?
    @Binding var selectedPoints: [ProteinPoint]
    
    let pointInteractionViewModel: PointInteractionViewModel
    let selectionManager: SelectionManager
    let annotationManager: AnnotationManager

    @Binding var coordinateRefreshTrigger: Int

    let exportService: PlotExportService?

    @Environment(\.colorScheme) var colorScheme

    enum PlotType {
        case volcano
        case scatter
        case heatmap
        case custom(layout: [String: Any])
    }
    
    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.allowsInlineMediaPlayback = true
        configuration.suppressesIncrementalRendering = false
        
        configuration.preferences.isFraudulentWebsiteWarningEnabled = false
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        
        let contentController = WKUserContentController()
        contentController.add(context.coordinator, name: "plotReady")
        contentController.add(context.coordinator, name: "plotUpdated")
        contentController.add(context.coordinator, name: "plotError")
        contentController.add(context.coordinator, name: "pointClicked")
        contentController.add(context.coordinator, name: "pointHovered")
        contentController.add(context.coordinator, name: "annotationMoved")
        contentController.add(context.coordinator, name: "plotDimensions")
        contentController.add(context.coordinator, name: "annotationCoordinates")
        contentController.add(context.coordinator, name: "plotExported")
        contentController.add(context.coordinator, name: "plotExportError")
        contentController.add(context.coordinator, name: "plotInfo")
        configuration.userContentController = contentController
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator

        webView.isOpaque = false
        if colorScheme == .dark {
            webView.backgroundColor = UIColor(red: 28/255, green: 28/255, blue: 30/255, alpha: 1.0)  // #1C1C1E
            webView.scrollView.backgroundColor = UIColor(red: 28/255, green: 28/255, blue: 30/255, alpha: 1.0)
        } else {
            webView.backgroundColor = .white
            webView.scrollView.backgroundColor = .white
        }

        context.coordinator.setCurrentWebView(webView)

        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.setCurrentWebView(webView)

        if colorScheme == .dark {
            webView.backgroundColor = UIColor(red: 28/255, green: 28/255, blue: 30/255, alpha: 1.0)  // #1C1C1E
            webView.scrollView.backgroundColor = UIColor(red: 28/255, green: 28/255, blue: 30/255, alpha: 1.0)
        } else {
            webView.backgroundColor = .white
            webView.scrollView.backgroundColor = .white
        }

        if !context.coordinator.htmlLoaded {
            context.coordinator.generateAndLoadPlot(in: webView)
        } else {
        }
    }
    
    
    /// Export the current plot as PNG with specified options
    func exportAsPNG(filename: String? = nil, width: Int = 1200, height: Int = 800) {
        guard let webView = Coordinator.getCurrentWebView() else {
            return
        }
        
        let finalFilename = filename ?? generateDefaultFilename(format: "png")
        let jsCode = "window.CurtainVisualization.exportAsPNG('\(finalFilename)', \(width), \(height));"
        
        webView.evaluateJavaScript(jsCode) { _, _ in
        }
    }
    
    /// Export the current plot as SVG with specified options
    func exportAsSVG(filename: String? = nil, width: Int = 1200, height: Int = 800) {
        guard let webView = Coordinator.getCurrentWebView() else {
            return
        }
        
        let finalFilename = filename ?? generateDefaultFilename(format: "svg")
        let jsCode = "window.CurtainVisualization.exportAsSVG('\(finalFilename)', \(width), \(height));"
        
        webView.evaluateJavaScript(jsCode) { _, _ in
        }
    }
    
    /// Get information about the current plot for export purposes
    func getCurrentPlotInfo() {
        guard let webView = Coordinator.getCurrentWebView() else {
            return
        }
        
        let jsCode = "window.CurtainVisualization.getCurrentPlotInfo();"
        webView.evaluateJavaScript(jsCode) { _, _ in
        }
    }
    
    
    private func generateDefaultFilename(format: String) -> String {
        let plotTypeString = plotTypeToString()
        let timestamp = DateFormatter.filenameSafe.string(from: Date())
        return "\(plotTypeString)_\(timestamp).\(format)"
    }
    
    private func plotTypeToString() -> String {
        switch plotType {
        case .volcano:
            return "volcano_plot"
        case .scatter:
            return "scatter_plot"
        case .heatmap:
            return "heatmap"
        case .custom:
            return "custom_plot"
        }
    }
    
    
    /// Export the currently active plot as PNG (static method for global access)
    static func exportCurrentPlotAsPNG(filename: String? = nil, width: Int = 1200, height: Int = 800) {
        guard let webView = PlotlyCoordinator.getCurrentWebView() else {
            return
        }
        
        let finalFilename = filename ?? "plot_\(DateFormatter.filenameSafe.string(from: Date())).png"
        let jsCode = "window.CurtainVisualization.exportAsPNG('\(finalFilename)', \(width), \(height));"
        
        webView.evaluateJavaScript(jsCode) { _, _ in
        }
    }
    
    /// Export the currently active plot as SVG (static method for global access)
    static func exportCurrentPlotAsSVG(filename: String? = nil, width: Int = 1200, height: Int = 800) {
        guard let webView = PlotlyCoordinator.getCurrentWebView() else {
            return
        }
        
        let finalFilename = filename ?? "plot_\(DateFormatter.filenameSafe.string(from: Date())).svg"
        let jsCode = "window.CurtainVisualization.exportAsSVG('\(finalFilename)', \(width), \(height));"
        
        webView.evaluateJavaScript(jsCode) { _, _ in
        }
    }
    
    /// Check if there's an active plot available for export
    static func canExportCurrentPlot() -> Bool {
        return PlotlyCoordinator.getCurrentWebView() != nil
    }
    
    func makeCoordinator() -> PlotlyCoordinator {
        PlotlyCoordinator(self)
    }
}


struct InteractiveVolcanoPlotView: View {
    @Binding var curtainData: CurtainData
    @Binding var annotationEditMode: Bool // Now passed from parent


    /// Manages plot loading, error states, and selected points
    @State private var loadingState = PlotLoadingViewState()

    /// Controls plot rendering and refresh behavior
    @State private var renderState = PlotRenderViewState()

    /// Manages modal presentation states (search, annotation editor)
    @State private var modalState = UIModalViewState()

    /// Manages annotation positioning workflow
    @State private var positioningState = AnnotationPositioningViewState()

    /// Manages drag gesture state and performance throttling
    @State private var dragState = DragOperationViewState()


    // Default initializer for cases where annotation edit mode is not needed
    init(curtainData: Binding<CurtainData>) {
        self._curtainData = curtainData
        self._annotationEditMode = .constant(false)
    }

    // Full initializer with annotation edit mode
    init(curtainData: Binding<CurtainData>, annotationEditMode: Binding<Bool>) {
        self._curtainData = curtainData
        self._annotationEditMode = annotationEditMode
    }


    @StateObject private var pointInteractionViewModel = PointInteractionViewModel()
    @StateObject private var selectionManager = SelectionManager()
    @StateObject private var annotationManager = AnnotationManager()
    @StateObject private var proteinSearchManager = ProteinSearchManager()
    @StateObject private var plotExportService = PlotExportService.shared
    
    var body: some View {
        Group {
            if loadingState.isLoading {
                loadingView
            } else if let error = loadingState.error {
                errorView(error)
            } else {
                plotContentView
            }
        }
        .sheet(isPresented: $modalState.showingProteinSearch) {
            ProteinSearchView(curtainData: $curtainData)
        }
        .sheet(isPresented: $modalState.showingAnnotationEditor) {
            AnnotationEditModal(
                candidates: modalState.selectedAnnotationsForEdit,
                curtainData: $curtainData,
                isPresented: $modalState.showingAnnotationEditor,
                onAnnotationUpdated: {
                    NotificationCenter.default.post(
                        name: NSNotification.Name("VolcanoPlotRefresh"),
                        object: nil,
                        userInfo: ["reason": "annotation_edited"]
                    )
                },
                onInteractivePositioning: { candidate in
                    var originalAx: Double = -20.0
                    var originalAy: Double = -20.0

                    if let annotationData = curtainData.settings.textAnnotation[candidate.key]?.value as? [String: Any],
                       let dataSection = annotationData["data"] as? [String: Any] {
                        originalAx = dataSection["ax"] as? Double ?? -20.0
                        originalAy = dataSection["ay"] as? Double ?? -20.0
                    }

                    positioningState.startPositioning(
                        candidate: candidate,
                        originalAx: originalAx,
                        originalAy: originalAy
                    )

                    modalState.hideAnnotationEditor()
                }
            )
        }
        .sheet(isPresented: $pointInteractionViewModel.isModalPresented) {
            if let clickData = pointInteractionViewModel.selectedPointData {
                PointInteractionModal(
                    clickData: clickData,
                    curtainData: $curtainData,
                    selectionManager: selectionManager,
                    annotationManager: annotationManager,
                    proteinSearchManager: proteinSearchManager,
                    isPresented: $pointInteractionViewModel.isModalPresented
                )
            }
        }
        .onAppear {
            if loadingState.isLoading && loadingState.error == nil {
                loadPlot()
            } else {
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("VolcanoPlotRefresh"))) { notification in
            renderState.triggerRefresh()
            renderState.forceUpdate()
        }
    }

    
    private func handleAnnotationEditTap(at tapPoint: CGPoint, geometry: GeometryProxy) {

        let nearbyAnnotations = findAnnotationsNearPoint(tapPoint, maxDistance: 150.0, viewSize: geometry.size)

        if nearbyAnnotations.isEmpty {
            return
        }

        modalState.showAnnotationEditor(with: nearbyAnnotations)

    }

    private func handleInteractivePositioning(at tapPoint: CGPoint, geometry: GeometryProxy) {
        guard let candidate = positioningState.positioningCandidate else { return }
        
        
        let settings = curtainData.settings
        let volcanoAxis = settings.volcanoAxis
        
        let plotWidth = geometry.size.width
        let plotHeight = geometry.size.height
        let marginLeft: Double = 70.0    // Y-axis labels and title
        let marginRight: Double = 40.0   // Plot area padding
        let marginTop: Double = 60.0     // Plot title
        let marginBottom: Double = 120.0 // X-axis labels, title, and horizontal legend
        
        let plotAreaWidth = plotWidth - marginLeft - marginRight
        let plotAreaHeight = plotHeight - marginTop - marginBottom
        
        let xMin = volcanoAxis.minX ?? -3.0
        let xMax = volcanoAxis.maxX ?? 3.0
        let yMin = volcanoAxis.minY ?? 0.0
        let yMax = volcanoAxis.maxY ?? 5.0
        
        let arrowX = candidate.arrowPosition.x
        let arrowY = candidate.arrowPosition.y
        
        let viewArrowX = marginLeft + ((arrowX - xMin) / (xMax - xMin)) * plotAreaWidth
        let viewArrowY = plotHeight - marginBottom - ((arrowY - yMin) / (yMax - yMin)) * plotAreaHeight
        
        let offsetX = Double(tapPoint.x) - viewArrowX
        let offsetY = Double(tapPoint.y) - viewArrowY
        

        positioningState.updatePreviewOffset(x: offsetX, y: offsetY)
        positioningState.startPreview()

        updateAnnotationPositionJS(candidate: candidate, offsetX: offsetX, offsetY: offsetY)
    }
    
    private func handleInteractiveDrag(at dragPoint: CGPoint, geometry: GeometryProxy) {
        guard let candidate = positioningState.positioningCandidate else {
            return
        }


        if !dragState.isDragging {

            if let textPos = getCurrentAnnotationTextPosition(candidate, geometry: geometry),
               let arrowPos = getArrowPositionForCandidate(candidate, geometry: geometry) {
                dragState.startDrag(at: textPos, arrowPosition: arrowPos)
            } else {
            }

            if !positioningState.isPreviewingPosition {
                positioningState.startPreview()
            }
        }

        let updateResult = dragState.updateDrag(to: dragPoint)
        if updateResult {
        }

        if let arrowPosition = dragState.cachedArrowPosition {
            let offsetX = Double(dragPoint.x) - arrowPosition.x
            let offsetY = Double(dragPoint.y) - arrowPosition.y // Direct mapping, no inversion

            positioningState.updatePreviewOffset(x: offsetX, y: offsetY)
            
            if dragState.dragStartPosition != nil {
            }
        }
    }
    
    private func getCurrentAnnotationTextPosition(_ candidate: AnnotationEditCandidate, geometry: GeometryProxy) -> CGPoint? {
        guard let arrowPos = getArrowPositionForCandidate(candidate, geometry: geometry) else {
            return nil
        }
        
        guard let annotationData = curtainData.settings.textAnnotation[candidate.key]?.value as? [String: Any],
              let dataSection = annotationData["data"] as? [String: Any],
              let ax = dataSection["ax"] as? Double,
              let ay = dataSection["ay"] as? Double else {
            return arrowPos // Fallback to arrow position
        }
        
        let currentTextPosition = CGPoint(
            x: arrowPos.x + ax,
            y: arrowPos.y + ay  // Back to adding ay directly
        )
        
        return currentTextPosition
    }
    
    private func getArrowPositionForCandidate(_ candidate: AnnotationEditCandidate, geometry: GeometryProxy) -> CGPoint? {
        
        // Try to use JavaScript-provided coordinates first
        let coordinator = PlotlyWebView.Coordinator.sharedCoordinator
        
        if let jsCoordinates = coordinator?.annotationCoordinates {
            for coord in jsCoordinates {
                
                // Try matching by plot coordinates first (most reliable)
                if let plotX = coord["plotX"] as? Double,
                   let plotY = coord["plotY"] as? Double,
                   abs(plotX - candidate.arrowPosition.x) < 0.0001,
                   abs(plotY - candidate.arrowPosition.y) < 0.0001,
                   let screenX = coord["screenX"] as? Double,
                   let screenY = coord["screenY"] as? Double {
                    return CGPoint(x: screenX, y: screenY)
                }
                
                // Fallback: try matching by ID
                if let id = coord["id"] as? String,
                   (id == candidate.key || id == candidate.title),
                   let screenX = coord["screenX"] as? Double,
                   let screenY = coord["screenY"] as? Double {
                    return CGPoint(x: screenX, y: screenY)
                }
            }
        }
        
        // Fallback to calculated coordinates if JavaScript data not available
        if let jsCoordinates = PlotlyWebView.Coordinator.sharedCoordinator?.annotationCoordinates {
            for _ in jsCoordinates {
            }
        } else {
        }
        
        // Get the volcano axis settings
        let volcanoAxis = curtainData.settings.volcanoAxis
        
        // Use JavaScript plot dimensions if available, otherwise fallback to estimates
        let plotWidth = Double(geometry.size.width)
        let plotHeight = Double(geometry.size.height)
        
        let (marginLeft, marginRight, marginTop, marginBottom): (Double, Double, Double, Double)
        
        if PlotlyWebView.Coordinator.sharedCoordinator != nil {
        }
        
        if let jsDimensions = PlotlyWebView.Coordinator.sharedCoordinator?.plotDimensions,
           let plotLeft = jsDimensions["plotLeft"] as? Double,
           let plotRight = jsDimensions["plotRight"] as? Double,
           let plotTop = jsDimensions["plotTop"] as? Double,
           let plotBottom = jsDimensions["plotBottom"] as? Double {
            // Use JavaScript-provided dimensions
            marginLeft = plotLeft
            marginRight = plotWidth - plotRight
            marginTop = plotTop
            marginBottom = plotHeight - plotBottom
        } else {
            // Fallback to estimated margins
            marginLeft = 70.0    // Y-axis labels and title
            marginRight = 40.0   // Plot area padding
            marginTop = 60.0     // Plot title
            marginBottom = 120.0 // X-axis labels, title, and horizontal legend
        }
        
        let plotAreaWidth = plotWidth - marginLeft - marginRight
        let plotAreaHeight = plotHeight - marginTop - marginBottom
        
        let xMin = volcanoAxis.minX ?? -3.0
        let xMax = volcanoAxis.maxX ?? 3.0
        let yMin = volcanoAxis.minY ?? 0.0
        let yMax = volcanoAxis.maxY ?? 5.0
        
        let arrowX = candidate.arrowPosition.x
        let arrowY = candidate.arrowPosition.y
        
        let viewArrowX = marginLeft + ((arrowX - xMin) / (xMax - xMin)) * plotAreaWidth
        let viewArrowY = plotHeight - marginBottom - ((arrowY - yMin) / (yMax - yMin)) * plotAreaHeight
        
        return CGPoint(x: viewArrowX, y: viewArrowY)
    }
    
    // Preview annotation position without permanently committing to CurtainData
    private func updateAnnotationPositionPreview(candidate: AnnotationEditCandidate, offsetX: Double, offsetY: Double) {
        // This temporarily updates the annotation for preview
        // The changes are not saved to permanent settings until accepted
        updateAnnotationPosition(candidate: candidate, offsetX: offsetX, offsetY: offsetY)
    }
    
    private func updateAnnotationPositionJS(candidate: AnnotationEditCandidate, offsetX: Double, offsetY: Double) {
        
        // The offsets are already in Plotly coordinate system, no conversion needed
        let plotlyAx = offsetX
        let plotlyAy = offsetY  // Already in Plotly coordinates
        
        
        // Find the coordinator and call its JavaScript method
        // We need to extract the coordinator from the PlotlyWebView somehow
        // For now, let's use NotificationCenter to communicate with the coordinator
        NotificationCenter.default.post(
            name: NSNotification.Name("UpdateAnnotationJS"),
            object: nil,
            userInfo: [
                "title": candidate.title,
                "ax": plotlyAx,
                "ay": plotlyAy
            ]
        )
    }
    
    // Accept the preview position and make it permanent
    private func acceptPositionPreview() {
        // Use JavaScript to commit the final position efficiently
        if let candidate = positioningState.positioningCandidate {
            let offset = positioningState.currentOffset
            updateAnnotationPositionJS(candidate: candidate, offsetX: offset.x, offsetY: offset.y)
            // Also save to CurtainData for persistence
            updateAnnotationPosition(candidate: candidate, offsetX: offset.x, offsetY: offset.y)
        }

        // Reset all states using ViewState methods
        dragState.reset()
        positioningState.acceptPosition()
    }

    // Reject the preview position and revert to original
    private func rejectPositionPreview() {
        guard let candidate = positioningState.positioningCandidate else {
            // Just reset states if no candidate
            dragState.reset()
            positioningState.reset()
            return
        }

        // Revert to original position using JavaScript for immediate response
        let originalOffset = positioningState.originalOffset
        updateAnnotationPositionJS(candidate: candidate, offsetX: originalOffset.x, offsetY: originalOffset.y)

        // Reset all states using ViewState methods
        dragState.reset()
        positioningState.rejectPosition()
    }
    
    private func updateAnnotationPosition(candidate: AnnotationEditCandidate, offsetX: Double, offsetY: Double) {
        var updatedTextAnnotation = curtainData.settings.textAnnotation
        
        guard var annotationData = updatedTextAnnotation[candidate.key]?.value as? [String: Any],
              var dataSection = annotationData["data"] as? [String: Any] else {
            return
        }
        
        // Update the position offsets
        dataSection["ax"] = offsetX
        dataSection["ay"] = offsetY
        annotationData["data"] = dataSection
        updatedTextAnnotation[candidate.key] = AnyCodable(annotationData)
        
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
            textAnnotation: updatedTextAnnotation,
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
        // Ensure uniprotDB is preserved
        curtainData.uniprotDB = curtainData.uniprotDB
        
    }
    
    private func findAnnotationsNearPoint(_ tapPoint: CGPoint, maxDistance: Double, viewSize: CGSize) -> [AnnotationEditCandidate] {
        var candidates: [AnnotationEditCandidate] = []
        
        let settings = curtainData.settings
        let textAnnotations = settings.textAnnotation
        let volcanoAxis = settings.volcanoAxis
        
        
        let plotWidth = viewSize.width
        let plotHeight = viewSize.height
        let marginLeft: Double = 70.0    // Y-axis labels and title
        let marginRight: Double = 40.0   // Plot area padding
        let marginTop: Double = 60.0     // Plot title
        let marginBottom: Double = 120.0 // X-axis labels, title, and horizontal legend
        
        let plotAreaWidth = plotWidth - marginLeft - marginRight
        let plotAreaHeight = plotHeight - marginTop - marginBottom
        
        let xMin = volcanoAxis.minX ?? -3.0
        let xMax = volcanoAxis.maxX ?? 3.0
        let yMin = volcanoAxis.minY ?? 0.0
        let yMax = volcanoAxis.maxY ?? 5.0
        
        for (key, value) in textAnnotations {
            guard let annotationData = value.value as? [String: Any],
                  let dataSection = annotationData["data"] as? [String: Any],
                  let title = annotationData["title"] as? String,
                  let arrowX = dataSection["x"] as? Double,
                  let arrowY = dataSection["y"] as? Double,
                  let text = dataSection["text"] as? String else {
                continue
            }
            
            // Convert plot coordinates to view coordinates
            let viewArrowX = marginLeft + ((arrowX - xMin) / (xMax - xMin)) * plotAreaWidth
            let viewArrowY = plotHeight - marginBottom - ((arrowY - yMin) / (yMax - yMin)) * plotAreaHeight
            
            // Calculate text position based on arrow position and offsets
            let ax = dataSection["ax"] as? Double ?? -20
            let ay = dataSection["ay"] as? Double ?? -20
            
            // Text offset is in pixels from arrow position
            // TESTING: Let's go back to original calculation and add debugging
            let viewTextX = viewArrowX + ax
            let viewTextY = viewArrowY + ay  // Back to original - add ay directly
            
            // EXTENSIVE DEBUG: Let's see what's happening
            
            // Calculate distance from tap point in view coordinates
            let distance = sqrt(pow(Double(tapPoint.x) - viewTextX, 2) + pow(Double(tapPoint.y) - viewTextY, 2))
            
            
            if distance <= maxDistance {
                let candidate = AnnotationEditCandidate(
                    key: key,
                    title: title,
                    currentText: text,
                    arrowPosition: CGPoint(x: arrowX, y: arrowY), // Keep in plot coordinates
                    textPosition: CGPoint(x: viewTextX, y: viewTextY), // View coordinates for UI
                    distance: distance
                )
                candidates.append(candidate)
            }
        }
        
        
        // Sort by distance (closest first)
        return candidates.sorted { $0.distance < $1.distance }
    }
    
    
    private var loadingView: some View {
        VStack {
            ProgressView("Loading volcano plot...")
                .scaleEffect(1.2)
            Text("Processing data...")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func errorView(_ errorMessage: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.orange)
            
            Text("Plot Error")
                .font(.title2)
                .fontWeight(.medium)
            
            Text(errorMessage)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Retry") {
                loadPlot()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var plotContentView: some View {
        ZStack {
            PlotlyWebView(
                curtainData: curtainData,
                plotType: .volcano, 
                selections: [], // No selections in read-only mode
                searchFilter: nil, // No search in read-only mode
                editMode: false, // Disable point interactions when in annotation edit mode
                curtainDataService: nil, // No editing service needed
                isLoading: $loadingState.isLoading,
                error: $loadingState.error,
                selectedPoints: $loadingState.selectedPoints,
                pointInteractionViewModel: annotationEditMode ? PointInteractionViewModel() : pointInteractionViewModel, // Disable interactions in edit mode
                selectionManager: selectionManager,
                annotationManager: annotationManager,
                coordinateRefreshTrigger: $renderState.coordinateRefreshTrigger,
                exportService: plotExportService
            )
            .id("\(renderState.plotId)-\(renderState.refreshTrigger)") // Force refresh when selections change
            .frame(minHeight: 400) // Ensure WebView has proper size
            .clipped()
            .onAppear {
                // Don't force update on every appear - only update when renderState changes via .id()

                // Trigger plot dimensions request when entering annotation edit mode
                if annotationEditMode {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        // Use the shared coordinator to request dimensions
                        PlotlyCoordinator.sharedCoordinator?.requestPlotDimensions()
                    }
                }
            }
            
            // Transparent overlay for annotation editing (but not over the floating button)
            if annotationEditMode {
                AnnotationEditOverlay(
                    curtainData: curtainData,
                    isInteractivePositioning: positioningState.isInteractivePositioning,
                    isPreviewingPosition: positioningState.isPreviewingPosition,
                    positioningCandidate: positioningState.positioningCandidate,
                    // Native drag preview properties - pass bindings for real-time updates
                    isShowingDragPreview: $dragState.isShowingDragPreview,
                    dragStartPosition: $dragState.dragStartPosition,
                    currentDragPosition: $dragState.currentDragPosition,
                    onAnnotationTapped: { tapPoint, geometry in
                        if positioningState.isInteractivePositioning {
                            // Allow continuous positioning even in preview mode
                            handleInteractivePositioning(at: tapPoint, geometry: geometry)
                        } else if !positioningState.isPreviewingPosition {
                            handleAnnotationEditTap(at: tapPoint, geometry: geometry)
                        }
                        // Allow continuous editing during preview mode
                    },
                    onAnnotationDragged: { dragPoint, geometry in
                        // Handle drag for smooth annotation movement with native preview
                        if positioningState.isInteractivePositioning {
                            handleInteractiveDrag(at: dragPoint, geometry: geometry)
                        }
                    },
                    onDragEnded: {
                        // Complete drag - keeps preview visible for accept/reject decision
                        dragState.completeDrag()
                    }
                )
                .allowsHitTesting(true)
                .id("overlay-\(renderState.coordinateRefreshTrigger)") // Force refresh when coordinates update
            }
        }
        .overlay(
            // Edit mode indicator - positioned lower to avoid toolbar
            annotationEditMode ? 
            VStack {
                Spacer()
                    .frame(height: 80) // Push notification below toolbar
                HStack {
                    if positioningState.isInteractivePositioning && positioningState.isPreviewingPosition {
                        Text("📝➡️📍 Preview: Drag to move text, then Accept or Cancel")
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.green.opacity(0.9))
                            .foregroundColor(.white)
                            .cornerRadius(16)
                    } else if positioningState.isInteractivePositioning {
                        Text("🎯 Drag to reposition the annotation text")
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.blue.opacity(0.9))
                            .foregroundColor(.white)
                            .cornerRadius(16)
                    } else {
                        Text("🎯 Annotation Edit Mode - Tap near annotations to edit")
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.orange.opacity(0.9))
                            .foregroundColor(.white)
                            .cornerRadius(16)
                    }
                    Spacer()
                }
                Spacer()
            }
            .padding() : nil,
            alignment: .topLeading
        )
        .overlay(
            // Accept/Reject buttons for preview mode
            positioningState.isPreviewingPosition ?
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    
                    // Reject button
                    Button(action: rejectPositionPreview) {
                        HStack(spacing: 6) {
                            Image(systemName: "xmark.circle.fill")
                            Text("Cancel")
                        }
                        .font(.system(size: 16, weight: .medium))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(20)
                    }
                    
                    Spacer()
                        .frame(width: 20)
                    
                    // Accept button
                    Button(action: acceptPositionPreview) {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Accept")
                        }
                        .font(.system(size: 16, weight: .medium))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(20)
                    }
                    
                    Spacer()
                }
                .padding(.bottom, 100) // Position above bottom safe area
            } : nil,
            alignment: .bottom
        )
    }
    
    
    private func loadPlot() {
        // Check both in-memory data and SQLite database
        if curtainData.hasDataAvailable {
            // Force the plot to show by setting to ready state immediately
            loadingState.setReady()
        } else {
            loadingState.setError("No protein data available for volcano plot")
        }
    }
}


struct SelectedPointsPanel: View {
    let points: [ProteinPoint]
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Selected Proteins (\(points.count))")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("Clear") {
                    onDismiss()
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            .padding(.horizontal)
            .padding(.top)
            
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(points, id: \.id) { protein in
                        ProteinDetailRow(protein: protein)
                    }
                }
                .padding(.horizontal)
            }
        }
        .background(Color(.systemGray6))
    }
}

struct ProteinDetailRow: View {
    let protein: ProteinPoint
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(protein.proteinName ?? protein.primaryID)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                if let geneNames = protein.geneNames {
                    Text(geneNames)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 8) {
                    Text("FC: \(protein.log2FC, specifier: "%.2f")")
                        .font(.caption)
                        .foregroundColor(protein.log2FC > 0 ? .red : .blue)
                    
                    Text("p: \(protein.pValue, specifier: "%.2e")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if protein.isSignificant {
                    Text("Significant")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.green)
                }
            }
        }
        .padding(.vertical, 4)
    }
}




struct AnnotationIndicatorView: View {
    let annotationKey: String
    let annotationData: [String: Any]?
    let geometry: GeometryProxy
    let volcanoAxis: VolcanoAxis
    let jsCoordinatesFinder: (Double, Double) -> JSCoordinateResult?
    
    var body: some View {
        Group {
            if let annotationData = annotationData,
               let dataSection = annotationData["data"] as? [String: Any],
               let x = dataSection["x"] as? Double,
               let y = dataSection["y"] as? Double {
                
                let jsCoordinateResult = jsCoordinatesFinder(x, y)
                
                if let jsResult = jsCoordinateResult {
                    JavaScriptAnnotationView(jsResult: jsResult, plotX: x, plotY: y)
                } else {
                    CalculatedAnnotationView(
                        x: x, y: y,
                        dataSection: dataSection,
                        geometry: geometry,
                        volcanoAxis: volcanoAxis
                    )
                }
            }
        }
    }
}

struct JavaScriptAnnotationView: View {
    let jsResult: JSCoordinateResult
    let plotX: Double
    let plotY: Double
    
    var body: some View {
        GeometryReader { geometry in
            // FIXED: Since the outer annotationIndicators view already applies frame/offset positioning,
            // we should NOT adjust coordinates here to avoid double adjustment that causes clipping

            // Use JavaScript coordinates directly since the outer frame/offset handles positioning
            let adjustedX = jsResult.screenX
            let adjustedY = jsResult.screenY
            
            let _ = {
            }()
            
            // Only show the pencil icon at the annotation text position
            Text("✏️")
                .font(.caption)
                .position(
                    x: CGFloat(adjustedX + jsResult.ax),
                    y: CGFloat(adjustedY + jsResult.ay)
                )
        }
    }
}

struct CalculatedAnnotationView: View {
    let x: Double
    let y: Double
    let dataSection: [String: Any]
    let geometry: GeometryProxy
    let volcanoAxis: VolcanoAxis
    
    var body: some View {
        // Convert plot coordinates to view coordinates
        let plotWidth = geometry.size.width
        let plotHeight = geometry.size.height
        let marginLeft: Double = 70.0    // Y-axis labels and title
        let marginRight: Double = 40.0   // Plot area padding
        let marginTop: Double = 60.0     // Plot title
        let marginBottom: Double = 120.0 // X-axis labels, title, and horizontal legend
        
        let plotAreaWidth = plotWidth - marginLeft - marginRight
        let plotAreaHeight = plotHeight - marginTop - marginBottom
        
        let xMin = volcanoAxis.minX ?? -3.0
        let xMax = volcanoAxis.maxX ?? 3.0
        let yMin = volcanoAxis.minY ?? 0.0
        let yMax = volcanoAxis.maxY ?? 5.0
        
        let viewX = marginLeft + ((x - xMin) / (xMax - xMin)) * plotAreaWidth
        let viewY = plotHeight - marginBottom - ((y - yMin) / (yMax - yMin)) * plotAreaHeight
        
        // Calculate text position with offset
        let ax = dataSection["ax"] as? Double ?? -20
        let ay = dataSection["ay"] as? Double ?? -20
        let textX = viewX + ax
        let textY = viewY + ay
        
        let _ = {
        }()
        
        return ZStack {
            // Data point position (where the arrow points)
            Circle()
                .fill(Color.red.opacity(0.7))
                .stroke(Color.red, lineWidth: 2)
                .frame(width: 8, height: 8)
                .position(x: viewX, y: viewY)
            
            // Annotation text position (calculated with ax/ay offsets)
            Circle()
                .fill(Color.orange.opacity(0.3))
                .stroke(Color.orange, lineWidth: 2)
                .frame(width: 30, height: 30)
                .position(
                    x: CGFloat(textX),
                    y: CGFloat(textY)
                )
        }
        .overlay(
            Text("✏️")
                .font(.caption)
                .position(
                    x: CGFloat(textX),
                    y: CGFloat(textY)
                )
        )
    }
}



#Preview {
    NavigationStack {
        VStack {
            Text("Volcano Plot Preview")
                .font(.title)
                .padding()
            Spacer()
        }
    }
}

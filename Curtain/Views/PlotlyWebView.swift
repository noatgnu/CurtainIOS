//
//  PlotlyWebView.swift
//  Curtain
//
//  Created by Toan Phung on 02/08/2025.
//

import SwiftUI
import WebKit
import Combine

// MARK: - Annotation Editing Models

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
    
    // Point interaction system (like Android)
    let pointInteractionViewModel: PointInteractionViewModel
    let selectionManager: SelectionManager
    let annotationManager: AnnotationManager

    // Refresh trigger for coordinate recalculation
    @Binding var coordinateRefreshTrigger: Int

    // Plot export functionality
    let exportService: PlotExportService?

    // Color scheme detection for dark mode support
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
        
        // Disable network requests to avoid WebKit networking issues
        configuration.preferences.isFraudulentWebsiteWarningEnabled = false
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        
        // Add message handlers for iOS-JavaScript communication
        let contentController = WKUserContentController()
        contentController.add(context.coordinator, name: "plotReady")
        contentController.add(context.coordinator, name: "plotUpdated")
        contentController.add(context.coordinator, name: "plotError")
        contentController.add(context.coordinator, name: "pointClicked")
        contentController.add(context.coordinator, name: "pointHovered")
        contentController.add(context.coordinator, name: "annotationMoved")
        contentController.add(context.coordinator, name: "plotDimensions")
        contentController.add(context.coordinator, name: "annotationCoordinates")
        // Export message handlers
        contentController.add(context.coordinator, name: "plotExported")
        contentController.add(context.coordinator, name: "plotExportError")
        contentController.add(context.coordinator, name: "plotInfo")
        configuration.userContentController = contentController
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        
        // Set the current webView in the coordinator
        context.coordinator.setCurrentWebView(webView)
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        print("🔄 PlotlyWebView: updateUIView called")
        context.coordinator.parent = self
        // Store webView reference in coordinator with enhanced persistence
        context.coordinator.setCurrentWebView(webView)
        
        // Only regenerate if HTML isn't loaded to prevent unnecessary reloads
        if !context.coordinator.htmlLoaded {
            context.coordinator.generateAndLoadPlot(in: webView)
        } else {
            print("🔄 PlotlyWebView: HTML already loaded, skipping regeneration but maintaining webView reference")
        }
    }
    
    // MARK: - Export Methods
    
    /// Export the current plot as PNG with specified options
    func exportAsPNG(filename: String? = nil, width: Int = 1200, height: Int = 800) {
        guard let webView = Coordinator.getCurrentWebView() else {
            print("❌ PlotlyWebView: Cannot export PNG - WebView not available")
            return
        }
        
        let finalFilename = filename ?? generateDefaultFilename(format: "png")
        let jsCode = "window.CurtainVisualization.exportAsPNG('\(finalFilename)', \(width), \(height));"
        
        print("📤 PlotlyWebView: Exporting PNG - \(finalFilename) (\(width)x\(height))")
        webView.evaluateJavaScript(jsCode) { result, error in
            if let error = error {
                print("❌ PlotlyWebView: PNG export JavaScript failed: \(error)")
            }
        }
    }
    
    /// Export the current plot as SVG with specified options
    func exportAsSVG(filename: String? = nil, width: Int = 1200, height: Int = 800) {
        guard let webView = Coordinator.getCurrentWebView() else {
            print("❌ PlotlyWebView: Cannot export SVG - WebView not available")
            return
        }
        
        let finalFilename = filename ?? generateDefaultFilename(format: "svg")
        let jsCode = "window.CurtainVisualization.exportAsSVG('\(finalFilename)', \(width), \(height));"
        
        print("📤 PlotlyWebView: Exporting SVG - \(finalFilename) (\(width)x\(height))")
        webView.evaluateJavaScript(jsCode) { result, error in
            if let error = error {
                print("❌ PlotlyWebView: SVG export JavaScript failed: \(error)")
            }
        }
    }
    
    /// Get information about the current plot for export purposes
    func getCurrentPlotInfo() {
        guard let webView = Coordinator.getCurrentWebView() else {
            print("❌ PlotlyWebView: Cannot get plot info - WebView not available")
            return
        }
        
        let jsCode = "window.CurtainVisualization.getCurrentPlotInfo();"
        webView.evaluateJavaScript(jsCode) { result, error in
            if let error = error {
                print("❌ PlotlyWebView: Get plot info JavaScript failed: \(error)")
            }
        }
    }
    
    // MARK: - Private Helper Methods
    
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
    
    // MARK: - Static Export Methods
    
    /// Export the currently active plot as PNG (static method for global access)
    static func exportCurrentPlotAsPNG(filename: String? = nil, width: Int = 1200, height: Int = 800) {
        guard let webView = PlotlyCoordinator.getCurrentWebView() else {
            print("❌ PlotlyWebView: Cannot export PNG - No active WebView")
            return
        }
        
        let finalFilename = filename ?? "plot_\(DateFormatter.filenameSafe.string(from: Date())).png"
        let jsCode = "window.CurtainVisualization.exportAsPNG('\(finalFilename)', \(width), \(height));"
        
        print("📤 PlotlyWebView: Static PNG export - \(finalFilename) (\(width)x\(height))")
        webView.evaluateJavaScript(jsCode) { result, error in
            if let error = error {
                print("❌ PlotlyWebView: Static PNG export failed: \(error)")
            }
        }
    }
    
    /// Export the currently active plot as SVG (static method for global access)
    static func exportCurrentPlotAsSVG(filename: String? = nil, width: Int = 1200, height: Int = 800) {
        guard let webView = PlotlyCoordinator.getCurrentWebView() else {
            print("❌ PlotlyWebView: Cannot export SVG - No active WebView")
            return
        }
        
        let finalFilename = filename ?? "plot_\(DateFormatter.filenameSafe.string(from: Date())).svg"
        let jsCode = "window.CurtainVisualization.exportAsSVG('\(finalFilename)', \(width), \(height));"
        
        print("📤 PlotlyWebView: Static SVG export - \(finalFilename) (\(width)x\(height))")
        webView.evaluateJavaScript(jsCode) { result, error in
            if let error = error {
                print("❌ PlotlyWebView: Static SVG export failed: \(error)")
            }
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

// MARK: - Convenience View

struct InteractiveVolcanoPlotView: View {
    @Binding var curtainData: CurtainData
    @Binding var annotationEditMode: Bool // Now passed from parent
    @State private var isLoading = true
    @State private var error: String?
    @State private var selectedPoints: [ProteinPoint] = []
    @State private var plotId = UUID() // Force SwiftUI updates
    @State private var refreshTrigger = 0 // Force plot regeneration when selections change
    @State private var coordinateRefreshTrigger = 0 // Trigger coordinate recalculation when plot dimensions arrive
    @State private var showingProteinSearch = false // Show protein search dialog
    @State private var showingAnnotationEditor = false // Show annotation editing modal
    @State private var selectedAnnotationsForEdit: [AnnotationEditCandidate] = [] // Annotations near tap point
    @State private var isInteractivePositioning = false // Interactive positioning mode
    @State private var positioningCandidate: AnnotationEditCandidate? // Annotation being repositioned
    @State private var isPreviewingPosition = false // Preview mode with accept/reject options
    @State private var previewOffsetX: Double = 0.0 // Preview offset X
    @State private var previewOffsetY: Double = 0.0 // Preview offset Y
    @State private var originalOffsetX: Double = 0.0 // Original offset X for revert
    @State private var originalOffsetY: Double = 0.0 // Original offset Y for revert
    @State private var isDragging = false // Track if user is actively dragging
    @State private var lastDragTime: Date = Date() // Throttle drag updates
    @State private var cachedArrowPosition: CGPoint? // Cache arrow position during drag
    @State private var dragStartPosition: CGPoint? // Original position when drag started
    @State private var currentDragPosition: CGPoint? // Current drag position for preview line
    @State private var isShowingDragPreview = false // Show native preview line
    
    
    
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
    
    // Point interaction system (like Android)
    @StateObject private var pointInteractionViewModel = PointInteractionViewModel()
    @StateObject private var selectionManager = SelectionManager()
    @StateObject private var annotationManager = AnnotationManager()
    @StateObject private var proteinSearchManager = ProteinSearchManager()
    @StateObject private var plotExportService = PlotExportService.shared
    
    var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                print("🔄 InteractiveVolcanoPlotView: Showing loading view (isLoading=\(isLoading))")
                return AnyView(loadingView)
            } else if let error = error {
                print("❌ InteractiveVolcanoPlotView: Showing error view: \(error)")
                return AnyView(errorView(error))
            } else {
                print("📊 InteractiveVolcanoPlotView: Showing plot content view")
                return AnyView(plotContentView)
            }
        }
        // Remove navigation title and toolbar since they're handled by parent
        .sheet(isPresented: $showingProteinSearch) {
            ProteinSearchView(curtainData: $curtainData)
        }
        .sheet(isPresented: $showingAnnotationEditor) {
            AnnotationEditModal(
                candidates: selectedAnnotationsForEdit,
                curtainData: $curtainData,
                isPresented: $showingAnnotationEditor,
                onAnnotationUpdated: {
                    // Refresh plot after annotation changes
                    NotificationCenter.default.post(
                        name: NSNotification.Name("VolcanoPlotRefresh"),
                        object: nil,
                        userInfo: ["reason": "annotation_edited"]
                    )
                },
                onInteractivePositioning: { candidate in
                    // Start interactive positioning mode
                    positioningCandidate = candidate
                    isInteractivePositioning = true
                    
                    // Store original offsets for potential revert
                    if let annotationData = curtainData.settings.textAnnotation[candidate.key] as? [String: Any],
                       let dataSection = annotationData["data"] as? [String: Any] {
                        originalOffsetX = dataSection["ax"] as? Double ?? 0.0
                        originalOffsetY = dataSection["ay"] as? Double ?? 0.0
                    }
                    
                    // Close the annotation editor modal
                    showingAnnotationEditor = false
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
            print("🔵 InteractiveVolcanoPlotView: onAppear called with \(curtainData.proteomicsData.count) proteins")
            print("🔍 InteractiveVolcanoPlotView: Initial state - isLoading: \(isLoading), error: \(error ?? "nil")")
            loadPlot()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("VolcanoPlotRefresh"))) { notification in
            print("🔄 InteractiveVolcanoPlotView: Received volcano plot refresh notification")
            if let reason = notification.userInfo?["reason"] as? String {
                print("🔄 InteractiveVolcanoPlotView: Refresh reason: \(reason)")
            }
            // Force plot regeneration by incrementing refresh trigger
            refreshTrigger += 1
            plotId = UUID()
            print("🔄 InteractiveVolcanoPlotView: Updated refreshTrigger to \(refreshTrigger)")
        }
    }
    
    // MARK: - Annotation Editing Methods
    
    private func handleAnnotationEditTap(at tapPoint: CGPoint, geometry: GeometryProxy) {
        print("🎯 Handling annotation edit tap at: \(tapPoint) in view size: \(geometry.size)")
        
        // Find annotations near the tap point using the actual view geometry
        let nearbyAnnotations = findAnnotationsNearPoint(tapPoint, maxDistance: 150.0, viewSize: geometry.size)
        
        if nearbyAnnotations.isEmpty {
            print("🎯 No annotations found near tap point")
            return
        }
        
        selectedAnnotationsForEdit = nearbyAnnotations
        showingAnnotationEditor = true
        
        print("🎯 Found \(nearbyAnnotations.count) annotations near tap point")
    }
    
    private func handleInteractivePositioning(at tapPoint: CGPoint, geometry: GeometryProxy) {
        guard let candidate = positioningCandidate else { return }
        
        print("🎯 Interactive positioning tap at: \(tapPoint)")
        
        // Convert tap point to annotation offset coordinates
        let settings = curtainData.settings
        let volcanoAxis = settings.volcanoAxis
        
        // Use the actual view dimensions
        let plotWidth = geometry.size.width
        let plotHeight = geometry.size.height
        // Plotly.js typical margins with horizontal legend below
        let marginLeft: Double = 70.0    // Y-axis labels and title
        let marginRight: Double = 40.0   // Plot area padding
        let marginTop: Double = 60.0     // Plot title
        let marginBottom: Double = 120.0 // X-axis labels, title, and horizontal legend
        
        let plotAreaWidth = plotWidth - marginLeft - marginRight
        let plotAreaHeight = plotHeight - marginTop - marginBottom
        
        // Get axis ranges
        let xMin = volcanoAxis.minX ?? -3.0
        let xMax = volcanoAxis.maxX ?? 3.0
        let yMin = volcanoAxis.minY ?? 0.0
        let yMax = volcanoAxis.maxY ?? 5.0
        
        // Get the annotation's arrow position (data point location)
        let arrowX = candidate.arrowPosition.x
        let arrowY = candidate.arrowPosition.y
        
        // Convert arrow position to view coordinates
        let viewArrowX = marginLeft + ((arrowX - xMin) / (xMax - xMin)) * plotAreaWidth
        let viewArrowY = plotHeight - marginBottom - ((arrowY - yMin) / (yMax - yMin)) * plotAreaHeight
        
        // Calculate offset from arrow position to tap point
        let offsetX = Double(tapPoint.x) - viewArrowX
        let offsetY = Double(tapPoint.y) - viewArrowY
        
        print("🎯 Arrow at view coordinates: (\(viewArrowX), \(viewArrowY))")
        print("🎯 Tap at view coordinates: (\(tapPoint.x), \(tapPoint.y))")
        print("🎯 Calculated offset: (\(offsetX), \(offsetY))")
        
        // Store preview position and enter preview mode
        previewOffsetX = offsetX
        previewOffsetY = offsetY
        isPreviewingPosition = true
        
        // Use JavaScript to update annotation position efficiently (no plot reload!)
        updateAnnotationPositionJS(candidate: candidate, offsetX: offsetX, offsetY: offsetY)
    }
    
    // Handle interactive drag for smooth annotation movement - now with native preview
    private func handleInteractiveDrag(at dragPoint: CGPoint, geometry: GeometryProxy) {
        guard let candidate = positioningCandidate else {
            print("❌ PlotlyWebView: No positioning candidate for drag")
            return
        }
        
        print("🎯 PlotlyWebView: Interactive drag at \(dragPoint) for candidate \(candidate.title)")
        
        // Set drag state
        if !isDragging {
            isDragging = true
            cachedArrowPosition = nil // Clear cache for new drag session
            print("🎯 PlotlyWebView: Starting drag for \(candidate.title)")
            
            // Get current annotation text position for the preview line (not the arrow position)
            if let textPos = getCurrentAnnotationTextPosition(candidate, geometry: geometry) {
                dragStartPosition = textPos
                // Still cache arrow position for offset calculations
                cachedArrowPosition = getArrowPositionForCandidate(candidate, geometry: geometry)
            }
            
            // Enter preview mode on first drag
            if !isPreviewingPosition {
                isPreviewingPosition = true
            }
            isShowingDragPreview = true
        }
        
        // Update current drag position for native preview line (no throttling needed for SwiftUI)
        currentDragPosition = dragPoint
        
        // Store the calculated offset for final commit
        if let arrowPosition = cachedArrowPosition {
            let offsetX = Double(dragPoint.x) - arrowPosition.x
            // FIXED: Direct coordinate mapping - negative y should move up, negative x should move left
            // Drag left (negative X change) → negative offset (move left)
            // Drag up (negative Y change) → negative offset (move up) 
            let offsetY = Double(dragPoint.y) - arrowPosition.y // Direct mapping, no inversion
            
            previewOffsetX = offsetX
            previewOffsetY = offsetY
            
            // Debug coordinate calculations
            print("🔍 DRAG DEBUG (FIXED):")
            print("   Arrow Position: (\(arrowPosition.x), \(arrowPosition.y))")
            print("   Drag Point: (\(dragPoint.x), \(dragPoint.y))")
            print("   Calculated Offset (ax, ay): (\(offsetX), \(offsetY)) - Direct mapping, no inversion")
            if let startPos = dragStartPosition {
                print("   Start Position (current text): (\(startPos.x), \(startPos.y))")
            }
        }
    }
    
    // Get the current annotation text position - back to original calculation with debugging
    private func getCurrentAnnotationTextPosition(_ candidate: AnnotationEditCandidate, geometry: GeometryProxy) -> CGPoint? {
        guard let arrowPos = getArrowPositionForCandidate(candidate, geometry: geometry) else {
            return nil
        }
        
        // Get current ax/ay offsets from the annotation data
        guard let annotationData = curtainData.settings.textAnnotation[candidate.key] as? [String: Any],
              let dataSection = annotationData["data"] as? [String: Any],
              let ax = dataSection["ax"] as? Double,
              let ay = dataSection["ay"] as? Double else {
            print("❌ PlotlyWebView: Could not get ax/ay offsets for candidate")
            return arrowPos // Fallback to arrow position
        }
        
        // Back to original calculation - add both ax and ay directly
        let currentTextPosition = CGPoint(
            x: arrowPos.x + ax,
            y: arrowPos.y + ay  // Back to adding ay directly
        )
        
        print("🔍 DRAG START POSITION DEBUG:")
        print("   Arrow Position: (\(arrowPos.x), \(arrowPos.y))")
        print("   Current Offsets (ax, ay): (\(ax), \(ay))")
        print("   Calculated Start Position: (\(currentTextPosition.x), \(currentTextPosition.y))")
        print("   Candidate.textPosition: (\(candidate.textPosition.x), \(candidate.textPosition.y))")
        print("   Geometry size: \(geometry.size)")
        return currentTextPosition
    }
    
    // Get the view coordinates of the arrow position for a candidate
    private func getArrowPositionForCandidate(_ candidate: AnnotationEditCandidate, geometry: GeometryProxy) -> CGPoint? {
        print("🔍 getArrowPositionForCandidate called for \(candidate.title)")
        print("🔍 Candidate plot position: (\(candidate.arrowPosition.x), \(candidate.arrowPosition.y))")
        
        // Try to use JavaScript-provided coordinates first
        let coordinator = PlotlyWebView.Coordinator.sharedCoordinator
        print("🔍 sharedCoordinator exists: \(coordinator != nil)")
        print("🔍 annotationCoordinates exists: \(coordinator?.annotationCoordinates != nil)")
        
        if let jsCoordinates = coordinator?.annotationCoordinates {
            print("🔍 Searching JavaScript coordinates for candidate: key='\(candidate.key)' title='\(candidate.title)'")
            for coord in jsCoordinates {
                print("🔍 Checking coordinate: \(coord)")
                
                // Try matching by plot coordinates first (most reliable)
                if let plotX = coord["plotX"] as? Double,
                   let plotY = coord["plotY"] as? Double,
                   abs(plotX - candidate.arrowPosition.x) < 0.0001,
                   abs(plotY - candidate.arrowPosition.y) < 0.0001,
                   let screenX = coord["screenX"] as? Double,
                   let screenY = coord["screenY"] as? Double {
                    print("🎯 Using JavaScript coordinates for \(candidate.title) by plot coordinates: (\(screenX), \(screenY))")
                    return CGPoint(x: screenX, y: screenY)
                }
                
                // Fallback: try matching by ID
                if let id = coord["id"] as? String,
                   (id == candidate.key || id == candidate.title),
                   let screenX = coord["screenX"] as? Double,
                   let screenY = coord["screenY"] as? Double {
                    print("🎯 Using JavaScript coordinates for \(candidate.title) by ID: (\(screenX), \(screenY))")
                    return CGPoint(x: screenX, y: screenY)
                }
            }
        }
        
        // Fallback to calculated coordinates if JavaScript data not available
        print("⚠️ No JavaScript coordinates found for \(candidate.title), using fallback calculation")
        print("🔍 Available JavaScript coordinates:")
        if let jsCoordinates = PlotlyWebView.Coordinator.sharedCoordinator?.annotationCoordinates {
            for coord in jsCoordinates {
                print("   - ID: \(coord["id"] as? String ?? "nil"), screenX: \(coord["screenX"] as? Double ?? 0), screenY: \(coord["screenY"] as? Double ?? 0)")
            }
        } else {
            print("   - No JavaScript coordinates received yet")
        }
        
        // Get the volcano axis settings
        let volcanoAxis = curtainData.settings.volcanoAxis
        
        // Use JavaScript plot dimensions if available, otherwise fallback to estimates
        let plotWidth = Double(geometry.size.width)
        let plotHeight = Double(geometry.size.height)
        
        let (marginLeft, marginRight, marginTop, marginBottom): (Double, Double, Double, Double)
        
        print("🔍 DEBUG: sharedCoordinator exists: \(PlotlyWebView.Coordinator.sharedCoordinator != nil)")
        print("🔍 DEBUG: plotDimensions exists: \(PlotlyWebView.Coordinator.sharedCoordinator?.plotDimensions != nil)")
        if let coord = PlotlyWebView.Coordinator.sharedCoordinator {
            print("🔍 DEBUG: plotDimensions content: \(coord.plotDimensions ?? [:])")
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
            print("📏 Using JavaScript plot dimensions: L:\(marginLeft), R:\(marginRight), T:\(marginTop), B:\(marginBottom)")
        } else {
            // Fallback to estimated margins
            marginLeft = 70.0    // Y-axis labels and title
            marginRight = 40.0   // Plot area padding
            marginTop = 60.0     // Plot title
            marginBottom = 120.0 // X-axis labels, title, and horizontal legend
            print("⚠️ Using estimated margins: L:\(marginLeft), R:\(marginRight), T:\(marginTop), B:\(marginBottom)")
        }
        
        let plotAreaWidth = plotWidth - marginLeft - marginRight
        let plotAreaHeight = plotHeight - marginTop - marginBottom
        
        // Get axis ranges
        let xMin = volcanoAxis.minX ?? -3.0
        let xMax = volcanoAxis.maxX ?? 3.0
        let yMin = volcanoAxis.minY ?? 0.0
        let yMax = volcanoAxis.maxY ?? 5.0
        
        // Get the annotation's arrow position (data point location)
        let arrowX = candidate.arrowPosition.x
        let arrowY = candidate.arrowPosition.y
        
        // Convert arrow position to view coordinates
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
    
    // Use JavaScript to update annotation position efficiently (no plot reload)
    private func updateAnnotationPositionJS(candidate: AnnotationEditCandidate, offsetX: Double, offsetY: Double) {
        print("⚡ PlotlyWebView: Sending JavaScript update for \(candidate.title) with Plotly offset \(offsetX), \(offsetY)")
        
        // The offsets are already in Plotly coordinate system, no conversion needed
        let plotlyAx = offsetX
        let plotlyAy = offsetY  // Already in Plotly coordinates
        
        print("⚡ PlotlyWebView: Plotly coordinates ax=\(plotlyAx), ay=\(plotlyAy)")
        
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
        if let candidate = positioningCandidate {
            updateAnnotationPositionJS(candidate: candidate, offsetX: previewOffsetX, offsetY: previewOffsetY)
            // Also save to CurtainData for persistence
            updateAnnotationPosition(candidate: candidate, offsetX: previewOffsetX, offsetY: previewOffsetY)
        }
        
        // Clear preview state
        isShowingDragPreview = false
        dragStartPosition = nil
        currentDragPosition = nil
        cachedArrowPosition = nil
        
        // Exit preview mode
        isInteractivePositioning = false
        isPreviewingPosition = false
        positioningCandidate = nil
        isDragging = false
    }
    
    // Reject the preview position and revert to original
    private func rejectPositionPreview() {
        guard let candidate = positioningCandidate else {
            isShowingDragPreview = false
            dragStartPosition = nil
            currentDragPosition = nil
            isInteractivePositioning = false
            isPreviewingPosition = false
            return
        }
        
        // Revert to original position using JavaScript for immediate response
        updateAnnotationPositionJS(candidate: candidate, offsetX: originalOffsetX, offsetY: originalOffsetY)
        
        // Clear preview state
        isShowingDragPreview = false
        dragStartPosition = nil
        currentDragPosition = nil
        cachedArrowPosition = nil
        
        // Exit preview mode
        isInteractivePositioning = false
        isPreviewingPosition = false
        positioningCandidate = nil
        isDragging = false
    }
    
    private func updateAnnotationPosition(candidate: AnnotationEditCandidate, offsetX: Double, offsetY: Double) {
        var updatedTextAnnotation = curtainData.settings.textAnnotation
        
        guard var annotationData = updatedTextAnnotation[candidate.key] as? [String: Any],
              var dataSection = annotationData["data"] as? [String: Any] else {
            print("❌ Failed to get annotation data for key: \(candidate.key)")
            return
        }
        
        // Update the position offsets
        dataSection["ax"] = offsetX
        dataSection["ay"] = offsetY
        annotationData["data"] = dataSection
        updatedTextAnnotation[candidate.key] = annotationData
        
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
            peptideCountData: curtainData.settings.peptideCountData
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
            permanent: curtainData.permanent
        )
        
        print("✅ Updated annotation position: '\(candidate.title)' to offset (\(offsetX), \(offsetY))")
    }
    
    private func findAnnotationsNearPoint(_ tapPoint: CGPoint, maxDistance: Double, viewSize: CGSize) -> [AnnotationEditCandidate] {
        var candidates: [AnnotationEditCandidate] = []
        
        let settings = curtainData.settings
        let textAnnotations = settings.textAnnotation
        let volcanoAxis = settings.volcanoAxis
        
        print("🎯 Tap point in overlay coordinates: (\(tapPoint.x), \(tapPoint.y))")
        print("🎯 Using actual view size: \(viewSize)")
        
        // Use the actual view dimensions from the overlay GeometryReader
        let plotWidth = viewSize.width
        let plotHeight = viewSize.height
        // Plotly.js typical margins with horizontal legend below
        let marginLeft: Double = 70.0    // Y-axis labels and title
        let marginRight: Double = 40.0   // Plot area padding
        let marginTop: Double = 60.0     // Plot title
        let marginBottom: Double = 120.0 // X-axis labels, title, and horizontal legend
        
        let plotAreaWidth = plotWidth - marginLeft - marginRight
        let plotAreaHeight = plotHeight - marginTop - marginBottom
        
        // Get axis ranges
        let xMin = volcanoAxis.minX ?? -3.0
        let xMax = volcanoAxis.maxX ?? 3.0
        let yMin = volcanoAxis.minY ?? 0.0
        let yMax = volcanoAxis.maxY ?? 5.0
        
        for (key, value) in textAnnotations {
            guard let annotationData = value as? [String: Any],
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
            print("🔍 ANNOTATION CALCULATION DEBUG for '\(title)':")
            print("   Plot coordinates (x,y): (\(arrowX), \(arrowY))")
            print("   View arrow position: (\(viewArrowX), \(viewArrowY))")
            print("   Offsets (ax,ay): (\(ax), \(ay))")
            print("   Calculated text position: (\(viewTextX), \(viewTextY))")
            print("   View size: \(viewSize)")
            print("   Plot area: \(plotAreaWidth) x \(plotAreaHeight)")
            print("   Margins: L:\(marginLeft) R:\(marginRight) T:\(marginTop) B:\(marginBottom)")
            
            // Calculate distance from tap point in view coordinates
            let distance = sqrt(pow(Double(tapPoint.x) - viewTextX, 2) + pow(Double(tapPoint.y) - viewTextY, 2))
            
            print("🎯 Annotation '\(title)': plot(\(arrowX), \(arrowY)) -> view(\(viewArrowX), \(viewArrowY)) + offset(\(ax), \(ay)) = text(\(viewTextX), \(viewTextY)) | tap(\(tapPoint.x), \(tapPoint.y)) | distance: \(distance)")
            
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
        
        print("🎯 Found \(candidates.count) annotation candidates within \(maxDistance)px of tap point (\(tapPoint.x), \(tapPoint.y))")
        
        // Sort by distance (closest first)
        return candidates.sorted { $0.distance < $1.distance }
    }
    
    // MARK: - Subviews
    
    private var loadingView: some View {
        VStack {
            ProgressView("Loading volcano plot...")
                .scaleEffect(1.2)
            Text("Processing \(curtainData.proteomicsData.count) proteins")
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
            // Android-style: Simple, clean volcano plot with point interactions
            PlotlyWebView(
                curtainData: curtainData,
                plotType: .volcano, 
                selections: [], // No selections in read-only mode
                searchFilter: nil, // No search in read-only mode
                editMode: false, // Disable point interactions when in annotation edit mode
                curtainDataService: nil, // No editing service needed
                isLoading: $isLoading,
                error: $error,
                selectedPoints: $selectedPoints,
                pointInteractionViewModel: annotationEditMode ? PointInteractionViewModel() : pointInteractionViewModel, // Disable interactions in edit mode
                selectionManager: selectionManager,
                annotationManager: annotationManager,
                coordinateRefreshTrigger: $coordinateRefreshTrigger,
                exportService: plotExportService
            )
            .id("\(plotId)-\(refreshTrigger)") // Force refresh when selections change
            .frame(minHeight: 400) // Ensure WebView has proper size
            .clipped()
            .onAppear {
                print("🔵 PlotlyWebView: onAppear called")
                // Trigger a plot update
                DispatchQueue.main.async {
                    self.plotId = UUID()
                }
                
                // Trigger plot dimensions request when entering annotation edit mode
                if annotationEditMode {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        print("🔍 Requesting plot dimensions due to annotation edit mode")
                        // Use the shared coordinator to request dimensions
                        PlotlyCoordinator.sharedCoordinator?.requestPlotDimensions()
                    }
                }
            }
            
            // Transparent overlay for annotation editing (but not over the floating button)
            if annotationEditMode {
                AnnotationEditOverlay(
                    curtainData: curtainData,
                    isInteractivePositioning: isInteractivePositioning,
                    isPreviewingPosition: isPreviewingPosition,
                    positioningCandidate: positioningCandidate,
                    // Native drag preview properties
                    isShowingDragPreview: isShowingDragPreview,
                    dragStartPosition: dragStartPosition,
                    currentDragPosition: currentDragPosition,
                    onAnnotationTapped: { tapPoint, geometry in
                        if isInteractivePositioning {
                            // Allow continuous positioning even in preview mode
                            handleInteractivePositioning(at: tapPoint, geometry: geometry)
                        } else if !isPreviewingPosition {
                            handleAnnotationEditTap(at: tapPoint, geometry: geometry)
                        }
                        // Allow continuous editing during preview mode
                    },
                    onAnnotationDragged: { dragPoint, geometry in
                        // Handle drag for smooth annotation movement with native preview
                        if isInteractivePositioning {
                            handleInteractiveDrag(at: dragPoint, geometry: geometry)
                        }
                    },
                    onDragEnded: {
                        // Reset drag state when drag ends
                        isDragging = false
                        // Keep the preview line visible for accept/reject decision
                    }
                )
                .allowsHitTesting(true)
                .id("overlay-\(coordinateRefreshTrigger)") // Force refresh when coordinates update
            }
        }
        .overlay(
            // Edit mode indicator - positioned lower to avoid toolbar
            annotationEditMode ? 
            VStack {
                Spacer()
                    .frame(height: 80) // Push notification below toolbar
                HStack {
                    if isInteractivePositioning && isPreviewingPosition {
                        Text("📝➡️📍 Preview: Drag to move text, then Accept or Cancel")
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.green.opacity(0.9))
                            .foregroundColor(.white)
                            .cornerRadius(16)
                    } else if isInteractivePositioning {
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
            isPreviewingPosition ?
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
        print("🔵 InteractiveVolcanoPlotView: Loading plot with \(curtainData.proteomicsData.count) proteins")
        
        if curtainData.proteomicsData.isEmpty {
            print("❌ InteractiveVolcanoPlotView: No protein data available")
            error = "No protein data available for volcano plot"
            isLoading = false
        } else {
            print("🔵 InteractiveVolcanoPlotView: Protein data available, forcing plot view to show")
            error = nil
            // Force the plot to show by setting loading to false immediately
            isLoading = false
            
            // Add a small delay to ensure UI updates
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                print("🔄 InteractiveVolcanoPlotView: Ensuring plot view is visible")
            }
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

// MARK: - Annotation Editing Components


// MARK: - Helper Views

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
                print("🎯 Direct JavaScript coordinate usage for annotation at (\(plotX), \(plotY))")
                print("📐 SwiftUI GeometryReader size: \(geometry.size)")
                print("📐 SwiftUI GeometryReader frame: \(geometry.frame(in: .global))")
                print("🌐 JS screen position: (\(jsResult.screenX), \(jsResult.screenY))")
                print("✅ Direct coordinates (no adjustment): (\(adjustedX), \(adjustedY))")
                print("🌐 JS annotation text position: (\(jsResult.screenX + jsResult.ax), \(jsResult.screenY + jsResult.ay))")
                print("✅ Direct annotation text position: (\(adjustedX + jsResult.ax), \(adjustedY + jsResult.ay))")
                print("📱 Device screen bounds: \(UIScreen.main.bounds)")
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
        // Plotly.js typical margins with horizontal legend below
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
            print("🔍 PENCIL POSITION DEBUG:")
            print("   Plot coordinates (x,y): (\(x), \(y))")
            print("   View arrow position: (\(viewX), \(viewY))")
            print("   Offsets (ax,ay): (\(ax), \(ay))")
            print("   Calculated pencil position: (\(textX), \(textY))")
            print("   Geometry size: \(geometry.size)")
            print("   Axis ranges - X: (\(xMin), \(xMax)), Y: (\(yMin), \(yMax))")
            print("   Plot area - Width: \(plotAreaWidth), Height: \(plotAreaHeight)")
            print("   Margins - L:\(marginLeft), R:\(marginRight), T:\(marginTop), B:\(marginBottom)")
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


// MARK: - Preview

#Preview {
    NavigationView {
        VStack {
            Text("Volcano Plot Preview")
                .font(.title)
                .padding()
            Spacer()
        }
    }
}

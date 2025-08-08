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
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: PlotlyWebView
        private let chartGenerator: PlotlyChartGenerator
        private var isHtmlLoaded = false
        private weak var currentWebView: WKWebView?
        private var webViewId: String = UUID().uuidString // Track webView identity
        static var sharedCoordinator: Coordinator? // Maintain persistent reference
        
        // Store plot dimensions and coordinates received from JavaScript
        var plotDimensions: [String: Any]?
        var annotationCoordinates: [[String: Any]]?
        
        init(_ parent: PlotlyWebView) {
            self.parent = parent
            self.chartGenerator = PlotlyChartGenerator(curtainDataService: parent.curtainDataService)
            super.init()
            
            // Listen for volcano plot refresh notifications (like Android volcanoPlotRefreshTrigger)
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleVolcanoPlotRefresh),
                name: NSNotification.Name("VolcanoPlotRefresh"),
                object: nil
            )
            
            // Listen for JavaScript annotation update requests
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleAnnotationJSUpdate),
                name: NSNotification.Name("UpdateAnnotationJS"),
                object: nil
            )
        }
        
        deinit {
            NotificationCenter.default.removeObserver(self)
        }
        
        @objc private func handleVolcanoPlotRefresh(_ notification: Notification) {
            print("🔄 PlotlyWebView: Received volcano plot refresh notification")
            if let reason = notification.userInfo?["reason"] as? String {
                print("🔄 PlotlyWebView: Refresh reason: \(reason)")
            }
            
            // Force plot regeneration (like Android volcanoPlotRefreshTrigger)
            DispatchQueue.main.async {
                self.isHtmlLoaded = false
                if let webView = self.currentWebView {
                    self.generateAndLoadPlot(in: webView)
                }
            }
        }
        
        @objc private func handleAnnotationJSUpdate(_ notification: Notification) {
            guard let userInfo = notification.userInfo,
                  let title = userInfo["title"] as? String,
                  let ax = userInfo["ax"] as? Double,
                  let ay = userInfo["ay"] as? Double else {
                print("❌ PlotlyWebView.Coordinator: Invalid annotation JS update data")
                return
            }
            
            print("⚡ PlotlyWebView.Coordinator: Handling JavaScript annotation update for title: \(title)")
            DispatchQueue.main.async {
                self.updateAnnotationPositionJS(title, ax: ax, ay: ay)
            }
        }
        
        func setCurrentWebView(_ webView: WKWebView) {
            currentWebView = webView
            webViewId = UUID().uuidString
            Self.sharedCoordinator = self // Maintain persistent reference
            print("🌐 PlotlyWebView.Coordinator: WebView reference set with ID: \(webViewId)")
        }
        
        // Static method to access current webView from anywhere
        static func getCurrentWebView() -> WKWebView? {
            return sharedCoordinator?.currentWebView
        }
        
        // Public accessor for isHtmlLoaded
        var htmlLoaded: Bool { return isHtmlLoaded }
        
        // Execute JavaScript to update annotation position efficiently using title
        func updateAnnotationPositionJS(_ title: String, ax: Double, ay: Double) {
            let webView = currentWebView ?? Self.getCurrentWebView()
            guard let webView = webView else {
                print("❌ PlotlyWebView.Coordinator: No webView available for JavaScript (ID: \(webViewId))")
                // Try to recover by checking shared coordinator
                if let sharedWebView = Self.sharedCoordinator?.currentWebView {
                    print("⚡ PlotlyWebView.Coordinator: Recovered webView from shared coordinator")
                    self.executeJavaScriptUpdate(on: sharedWebView, title: title, ax: ax, ay: ay)
                }
                return
            }
            
            executeJavaScriptUpdate(on: webView, title: title, ax: ax, ay: ay)
        }
        
        private func executeJavaScriptUpdate(on webView: WKWebView, title: String, ax: Double, ay: Double) {
            print("⚡ PlotlyWebView.Coordinator: Executing JavaScript update for '\(title)' with webView ID: \(webViewId)")
            
            let jsCode = """
                if (window.VolcanoPlot && window.VolcanoPlot.updateAnnotationPosition) {
                    console.log('Updating annotation by title: \(title) to ax=\(ax), ay=\(ay)');
                    window.VolcanoPlot.updateAnnotationPosition('\(title)', \(ax), \(ay));
                } else {
                    console.log('VolcanoPlot.updateAnnotationPosition not available');
                }
            """
            
            webView.evaluateJavaScript(jsCode) { result, error in
                if let error = error {
                    print("❌ PlotlyWebView: JavaScript annotation update failed: \(error)")
                } else {
                    print("✅ PlotlyWebView: Annotation '\(title)' position updated via JavaScript")
                }
            }
        }
        
        // Request plot dimensions and annotation coordinates from JavaScript
        func requestPlotDimensions() {
            let webView = currentWebView ?? Self.getCurrentWebView()
            guard let webView = webView else {
                print("❌ PlotlyWebView.Coordinator: No webView available for requesting plot dimensions")
                return
            }
            
            let jsCode = """
                if (window.VolcanoPlot && window.VolcanoPlot.sendPlotDimensions) {
                    window.VolcanoPlot.sendPlotDimensions();
                    
                    // Also send annotation coordinates if available
                    if (window.VolcanoPlot.convertAndSendCoordinates) {
                        // Get the current plot element
                        const plotElement = document.getElementById('plot');
                        if (plotElement && plotElement.layout && plotElement.layout.annotations && plotElement.layout.annotations.length > 0) {
                            window.VolcanoPlot.convertAndSendCoordinates(plotElement.layout.annotations);
                        } else {
                            console.log('No annotations found on plot element');
                        }
                    }
                } else {
                    console.log('VolcanoPlot.sendPlotDimensions not available yet');
                }
            """
            
            webView.evaluateJavaScript(jsCode) { result, error in
                if let error = error {
                    print("❌ PlotlyWebView: JavaScript plot dimensions request failed: \(error)")
                } else {
                    print("✅ PlotlyWebView: Requested plot dimensions from JavaScript")
                }
            }
        }
        
        // MARK: - WKNavigationDelegate
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            print("🏁 PlotlyWebView: WebView navigation finished")
            isHtmlLoaded = true
            DispatchQueue.main.async {
                self.parent.isLoading = false
                self.parent.error = nil
            }
            
            // Give a small delay for JavaScript to initialize the plot
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                if self.parent.isLoading {
                    print("🔧 PlotlyWebView: Force completing after navigation + delay")
                    self.parent.isLoading = false
                }
            }
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async {
                self.parent.error = "WebView navigation failed: \(error.localizedDescription)"
                self.parent.isLoading = false
            }
        }
        
        // MARK: - WKScriptMessageHandler
        
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            print("🔔 PlotlyWebView: Received message: \(message.name)")
            DispatchQueue.main.async {
                switch message.name {
                case "plotReady":
                    print("✅ PlotlyWebView: Plot ready message received")
                    self.parent.isLoading = false
                    self.parent.error = nil
                    
                    // Request plot dimensions and annotation coordinates after a small delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.requestPlotDimensions()
                    }
                    
                case "plotUpdated":
                    print("🔄 PlotlyWebView: Plot updated message received")
                    self.parent.isLoading = false
                    
                    // Request plot dimensions after updates too, with delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.requestPlotDimensions()
                    }
                    
                case "plotError":
                    print("❌ PlotlyWebView: Plot error message received: \(message.body)")
                    self.parent.error = message.body as? String ?? "Unknown plot error"
                    self.parent.isLoading = false
                    
                case "pointClicked":
                    print("👆 PlotlyWebView: Point clicked message received")
                    self.handlePointClicked(message.body)
                    
                case "pointHovered":
                    self.handlePointHovered(message.body)
                    
                case "annotationMoved":
                    self.handleAnnotationMoved(message.body)
                
                case "plotDimensions":
                    if let dimensionsString = message.body as? String,
                       let dimensionsData = dimensionsString.data(using: .utf8),
                       let dimensions = try? JSONSerialization.jsonObject(with: dimensionsData) as? [String: Any] {
                        print("📏 PlotlyWebView: Received plot dimensions: \(dimensions)")
                        // Store dimensions for coordinate calculations
                        self.plotDimensions = dimensions
                        
                        // Trigger UI refresh to recalculate coordinates with new dimensions
                        DispatchQueue.main.async {
                            self.parent.coordinateRefreshTrigger += 1
                            print("🔄 PlotlyWebView: Triggering coordinate recalculation after receiving plot dimensions")
                        }
                    }
                
                case "annotationCoordinates":
                    if let coordinatesString = message.body as? String,
                       let coordinatesData = coordinatesString.data(using: .utf8),
                       let coordinates = try? JSONSerialization.jsonObject(with: coordinatesData) as? [[String: Any]] {
                        print("📍 PlotlyWebView: Received annotation coordinates: \(coordinates)")
                        // Store coordinates for overlay positioning
                        self.annotationCoordinates = coordinates
                    }
                    
                default:
                    break
                }
            }
        }
        
        // MARK: - Plot Generation
        
        func generateAndLoadPlot(in webView: WKWebView) {
            print("🔄 PlotlyWebView: generateAndLoadPlot called")
            
            // Store webView reference for future refresh notifications
            currentWebView = webView
            
            guard !isHtmlLoaded else {
                print("🔍 PlotlyWebView: HTML already loaded, skipping generation")
                return
            }
            
            DispatchQueue.main.async {
                // Don't set isLoading = true here since we want to show the plot immediately
                // self.parent.isLoading = true  
                self.parent.error = nil
                print("🔧 PlotlyWebView: Preparing to load HTML without setting loading state")
            }
            
            print("🔄 PlotlyWebView: Creating plot generation context")
            print("🔍 PlotlyWebView: Protein data count: \(parent.curtainData.proteomicsData.count)")
            print("🔍 PlotlyWebView: First few protein keys: \(Array(parent.curtainData.proteomicsData.keys.prefix(3)))")
            
            // Check first protein data structure
            if let firstKey = parent.curtainData.proteomicsData.keys.first,
               let firstProtein = parent.curtainData.proteomicsData[firstKey] {
                print("🔍 PlotlyWebView: First protein (\(firstKey)) data: \(firstProtein)")
            }
            
            // Create plot generation context
            let context = PlotGenerationContext(
                data: parent.curtainData,
                settings: parent.curtainData.settings,
                selections: parent.selections,
                searchFilter: parent.searchFilter,
                editMode: parent.editMode
            )
            
            print("🔄 PlotlyWebView: Generating HTML for volcano plot")
            
            // Debug the first few proteins to understand data structure
            if let firstKey = parent.curtainData.proteomicsData.keys.first,
               let firstProtein = parent.curtainData.proteomicsData[firstKey] {
                print("🔍 PlotlyWebView: First protein data structure:")
                print("🔍 PlotlyWebView: Key: \(firstKey)")
                print("🔍 PlotlyWebView: Value type: \(type(of: firstProtein))")
                
                // Try to inspect the dictionary structure
                if let proteinDict = firstProtein as? [String: Any] {
                    print("🔍 PlotlyWebView: Protein dictionary keys: \(proteinDict.keys)")
                    for (key, value) in proteinDict.prefix(5) {
                        print("🔍 PlotlyWebView: \(key): \(value) (type: \(type(of: value)))")
                    }
                }
            }
            
            // Generate HTML based on plot type - use Task for async calls
            Task {
                let html: String
                switch parent.plotType {
                case .volcano:
                    html = await chartGenerator.createVolcanoPlotHtml(context: context)
                case .scatter:
                    html = generateNotImplementedHtml("Scatter plot")
                case .heatmap:
                    html = generateNotImplementedHtml("Heatmap")
                case .custom:
                    html = generateNotImplementedHtml("Custom plot")
                }
                
                print("🔄 PlotlyWebView: HTML generation completed")
                
                // Update UI on main thread
                await MainActor.run {
                    // Load the generated HTML string directly. A baseURL is not needed
                    // because the plotly.min.js script is inlined in the HTML.
                    print("🔍 PlotlyWebView: Generated HTML (first 200 chars): \(String(html.prefix(200)))")
                    print("🔍 PlotlyWebView: Loading HTML string directly without a base URL.")
                    webView.loadHTMLString(html, baseURL: nil)
                    print("🔍 PlotlyWebView: loadHTMLString called")
                    
                    // Add a backup completion timer in case WebView navigation doesn't complete
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        if self.parent.isLoading {
                            print("⚠️ PlotlyWebView: Navigation didn't complete, forcing completion")
                            self.parent.isLoading = false
                            self.parent.error = nil
                            self.isHtmlLoaded = true
                        }
                    }
                }
            }
        }
        
        // MARK: - Event Handlers
        
        private func handlePointClicked(_ messageBody: Any?) {
            Task {
                await handlePointClickedAsync(messageBody)
            }
        }
        
        private func handlePointClickedAsync(_ messageBody: Any?) async {
            guard let jsonString = messageBody as? String,
                  let data = jsonString.data(using: .utf8),
                  let pointData = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                print("❌ PlotlyWebView: Failed to parse point click data")
                return
            }
            
            print("👆 PlotlyWebView: Processing point click data: \(pointData)")
            
            // Extract point data from JavaScript message (like Android)
            guard let proteinId = pointData["proteinId"] as? String ?? pointData["id"] as? String,
                  let log2FC = pointData["log2FC"] as? Double ?? pointData["x"] as? Double,
                  let pValue = pointData["pValue"] as? Double else {
                print("❌ PlotlyWebView: Missing required point data")
                return
            }
            
            // Extract Y coordinate (already in -log10 form) if available
            let plotY = pointData["y"] as? Double ?? -log10(pValue)
            
            // Get proteins from the same volcano data source that generated the plot
            let volcanoDataService = VolcanoPlotDataService()
            let volcanoResult = await volcanoDataService.processVolcanoData(
                curtainData: parent.curtainData,
                settings: parent.curtainData.settings
            )
            
            // Convert volcano JSON data to ProteinPoint objects for consistency
            var proteinCount = 0
            let allProteins = volcanoResult.jsonData.compactMap { dataPoint -> ProteinPoint? in
                guard let id = dataPoint["id"] as? String,
                      let gene = dataPoint["gene"] as? String,
                      let x = dataPoint["x"] as? Double,
                      let y = dataPoint["y"] as? Double else {
                    return nil
                }
                
                // Y coordinate is already -log10(pvalue), convert to regular p-value for storage
                let pValue = pow(10, -y)
                
                // Get color from group name and colormap (like Android implementation)
                let proteinColor = getProteinColorFromGroups(
                    proteinId: id,
                    fcValue: x,
                    pValue: pValue,
                    curtainData: parent.curtainData,
                    colorMap: volcanoResult.colorMap
                )
                
                // Debug color assignment for first few proteins
                if proteinCount < 3 {
                    print("🎨 PlotlyWebView: Protein \(id) assigned color: \(proteinColor)")
                    if let selections = dataPoint["selections"] as? [String] {
                        print("🎨 PlotlyWebView: Protein \(id) selections: \(selections)")
                    }
                }
                proteinCount += 1
                
                return ProteinPoint(
                    id: id,
                    primaryID: id,
                    proteinName: gene,
                    geneNames: gene,
                    log2FC: x,
                    pValue: pValue,
                    isSignificant: abs(x) >= parent.curtainData.settings.log2FCCutoff && pValue <= parent.curtainData.settings.pCutoff,
                    isSelected: false,
                    condition: nil,
                    color: proteinColor,  // Use color determined from groups and colormap
                    customData: dataPoint
                )
            }
            
            print("🔍 PlotlyWebView: Using volcano data source with \(allProteins.count) proteins")
            
            // Find the clicked protein
            guard let clickedProtein = allProteins.first(where: { $0.id == proteinId }) else {
                print("❌ PlotlyWebView: Clicked protein not found: \(proteinId)")
                print("🔍 PlotlyWebView: Available protein IDs (first 10): \(allProteins.prefix(10).map { $0.id })")
                return
            }
            
            print("✅ PlotlyWebView: Found clicked protein: \(clickedProtein.primaryID)")
            
            // Calculate nearby proteins using euclidean distance (like Android)
            let nearbyProteins = DistanceCalculator.findNearbyProteins(
                around: clickedProtein,
                from: allProteins,
                distanceCutoff: parent.pointInteractionViewModel.distanceCutoff
            )
            
            print("🔍 PlotlyWebView: Found \(nearbyProteins.count) nearby proteins within distance \(parent.pointInteractionViewModel.distanceCutoff)")
            
            // Create point click data
            let clickPosition = CGPoint(
                x: pointData["screenX"] as? Double ?? 0,
                y: pointData["screenY"] as? Double ?? 0
            )
            
            let plotCoordinates = PlotCoordinates(
                x: log2FC,
                y: plotY // Use plot Y coordinate (already in -log10 form)
            )
            
            let clickData = VolcanoPointClickData(
                clickedProtein: clickedProtein,
                nearbyProteins: nearbyProteins,
                clickPosition: clickPosition,
                plotCoordinates: plotCoordinates
            )
            
            // Show interaction modal (like Android)
            parent.pointInteractionViewModel.handlePointClick(clickData)
            
            // Also update selected points for backwards compatibility
            parent.selectedPoints = [clickedProtein]
        }
        
        private func handlePointHovered(_ messageBody: Any?) {
            // Handle point hover events if needed
        }
        
        private func handleAnnotationMoved(_ messageBody: Any?) {
            // Handle annotation movement if needed
        }
        
        // MARK: - Helper Methods
        
        /// Determine protein color based on selection groups and significance (like Android)
        private func getProteinColorFromGroups(
            proteinId: String,
            fcValue: Double,
            pValue: Double,
            curtainData: CurtainData,
            colorMap: [String: String]
        ) -> String {
            
            // Check user selections first (highest priority)
            if let selectedMap = curtainData.selectedMap,
               let selectionForId = selectedMap[proteinId] {
                for (selectionName, isSelected) in selectionForId {
                    if isSelected, let selectionColor = colorMap[selectionName] {
                        print("🎨 getProteinColorFromGroups: Protein \(proteinId) in selection '\(selectionName)' -> \(selectionColor)")
                        return selectionColor
                    }
                }
            }
            
            // If no user selections, determine significance group and get its color
            let significanceGroup = getSignificanceGroup(
                fcValue: fcValue,
                pValue: pValue,
                settings: curtainData.settings
            )
            
            let groupColor = colorMap[significanceGroup] ?? "#cccccc"
            print("🎨 getProteinColorFromGroups: Protein \(proteinId) in significance group '\(significanceGroup)' -> \(groupColor)")
            return groupColor
        }
        
        /// Determine significance group name (matching Android VolcanoPlotDataService)
        private func getSignificanceGroup(
            fcValue: Double,
            pValue: Double,
            settings: CurtainSettings
        ) -> String {
            let ylog = -log10(settings.pCutoff)
            let transformedPValue = -log10(max(pValue, 1e-300))
            var groups: [String] = []
            
            // P-value classification
            if transformedPValue < ylog {
                groups.append("P-value > \(settings.pCutoff)")
            } else {
                groups.append("P-value <= \(settings.pCutoff)")
            }
            
            // Fold change classification
            if abs(fcValue) > settings.log2FCCutoff {
                groups.append("FC > \(settings.log2FCCutoff)")
            } else {
                groups.append("FC <= \(settings.log2FCCutoff)")
            }
            
            // Create full group name with comparison
            let groupText = groups.joined(separator: ";")
            let comparison = settings.currentComparison.isEmpty ? "1" : settings.currentComparison
            return "\(groupText) (\(comparison))"
        }
        
        private func generateNotImplementedHtml(_ plotType: String) -> String {
            return """
            <!DOCTYPE html>
            <html>
            <head>
                <meta charset="UTF-8">
                <meta name="viewport" content="width=device-width, initial-scale=1.0">
                <title>\(plotType)</title>
                <style>
                    body {
                        margin: 0;
                        padding: 20px;
                        font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                        display: flex;
                        justify-content: center;
                        align-items: center;
                        height: 100vh;
                        text-align: center;
                        background-color: var(--background-color, #ffffff);
                        color: var(--text-color, #000000);
                    }
                    
                    @media (prefers-color-scheme: dark) {
                        body {
                            --background-color: #1c1c1e;
                            --text-color: #ffffff;
                        }
                    }
                </style>
            </head>
            <body>
                <div>
                    <h3>\(plotType) Coming Soon</h3>
                    <p>This plot type is not yet implemented.</p>
                </div>
                <script>
                    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.plotReady) {
                        window.webkit.messageHandlers.plotReady.postMessage('ready');
                    }
                </script>
            </body>
            </html>
            """
        }
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
                coordinateRefreshTrigger: $coordinateRefreshTrigger
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
                        PlotlyWebView.Coordinator.sharedCoordinator?.requestPlotDimensions()
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

struct AnnotationEditOverlay: View {
    let curtainData: CurtainData
    let isInteractivePositioning: Bool
    let isPreviewingPosition: Bool
    let positioningCandidate: AnnotationEditCandidate?
    // Native drag preview properties
    let isShowingDragPreview: Bool
    let dragStartPosition: CGPoint?
    let currentDragPosition: CGPoint?
    let onAnnotationTapped: (CGPoint, GeometryProxy) -> Void
    let onAnnotationDragged: ((CGPoint, GeometryProxy) -> Void)?
    let onDragEnded: (() -> Void)?
    
    var body: some View {
        GeometryReader { geometry in
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { location in
                    // Check if tap is in toolbar area (full width, top section)
                    let toolbarHeight: CGFloat = 48 // Height of the minimal toolbar
                    let toolbarAreaY: CGFloat = 0
                    
                    let isInToolbarArea = location.y >= toolbarAreaY && location.y <= toolbarHeight
                    
                    // Only handle annotation taps if not in toolbar area
                    if !isInToolbarArea {
                        onAnnotationTapped(location, geometry)
                    }
                }
                .gesture(
                    DragGesture(coordinateSpace: .local)
                        .onChanged { value in
                            // Check if drag is in toolbar area
                            let toolbarHeight: CGFloat = 48
                            let isInToolbarArea = value.location.y <= toolbarHeight
                            
                            // Only handle annotation drags if not in toolbar area and we're in positioning mode
                            if !isInToolbarArea && isInteractivePositioning {
                                onAnnotationDragged?(value.location, geometry)
                            }
                        }
                        .onEnded { value in
                            // Drag ended - finalize position and reset drag state
                            let toolbarHeight: CGFloat = 48
                            let isInToolbarArea = value.location.y <= toolbarHeight
                            
                            if !isInToolbarArea && isInteractivePositioning {
                                onAnnotationDragged?(value.location, geometry)
                                onDragEnded?()
                            }
                        }
                )
                .overlay(
                    // Visual indicators for annotations and native drag preview
                    ZStack {
                        // Native drag preview line
                        if isShowingDragPreview, let startPos = dragStartPosition, let currentPos = currentDragPosition {
                            nativeDragPreviewLine(from: startPos, to: currentPos)
                        }
                        
                        // Visual indicators for annotations
                        Group {
                            if isInteractivePositioning {
                                interactivePositioningIndicators(geometry)
                            } else {
                                annotationIndicators
                            }
                        }
                    }
                )
        }
    }
    
    // Native drag preview line - smooth SwiftUI rendering
    private func nativeDragPreviewLine(from startPos: CGPoint, to currentPos: CGPoint) -> some View {
        ZStack {
            // Main preview line - bright and prominent
            Path { path in
                path.move(to: startPos)
                path.addLine(to: currentPos)
            }
            .stroke(Color.blue, style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [8, 4]))
            .shadow(color: .blue.opacity(0.3), radius: 2)
            
            // Start point indicator (current annotation text position)
            Circle()
                .fill(Color.orange)
                .stroke(Color.white, lineWidth: 2)
                .frame(width: 14, height: 14)
                .position(startPos)
                .overlay(
                    Text("📝")
                        .font(.caption2)
                        .position(startPos)
                )
            
            // End point indicator (where annotation text will move to)
            Circle()
                .fill(Color.green)
                .stroke(Color.white, lineWidth: 2)
                .frame(width: 16, height: 16)
                .position(currentPos)
                .overlay(
                    Text("📍")
                        .font(.caption2)
                        .position(currentPos)
                )
            
            // Distance indicator and coordinate display
            let distance = sqrt(pow(currentPos.x - startPos.x, 2) + pow(currentPos.y - startPos.y, 2))
            let midPoint = CGPoint(
                x: (startPos.x + currentPos.x) / 2,
                y: (startPos.y + currentPos.y) / 2 - 20
            )
            
            Text("\(Int(distance))px")
                .font(.caption2)
                .fontWeight(.medium)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.black.opacity(0.7))
                .foregroundColor(.white)
                .cornerRadius(8)
                .position(midPoint)
            
            // Start position coordinates (current annotation position)
            Text("START: (\(Int(startPos.x)), \(Int(startPos.y)))")
                .font(.caption2)
                .fontWeight(.medium)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(Color.orange.opacity(0.9))
                .foregroundColor(.white)
                .cornerRadius(6)
                .position(CGPoint(x: startPos.x, y: startPos.y - 25))
            
            // End position coordinates (where annotation will move to)
            Text("END: (\(Int(currentPos.x)), \(Int(currentPos.y)))")
                .font(.caption2)
                .fontWeight(.medium)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(Color.green.opacity(0.9))
                .foregroundColor(.white)
                .cornerRadius(6)
                .position(CGPoint(x: currentPos.x, y: currentPos.y - 25))
        }
    }
    
    private func interactivePositioningIndicators(_ geometry: GeometryProxy) -> some View {
        ZStack {
            // Show help text
            VStack {
                Spacer()
                    .frame(height: 80) // Push below toolbar
                Text("📍 Drag to move the annotation text")
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.9))
                    .foregroundColor(.white)
                    .cornerRadius(16)
                Spacer()
            }
            .padding()
            
            // Highlight the annotation being moved
            if let candidate = positioningCandidate {
                let volcanoAxis = curtainData.settings.volcanoAxis
                
                // Convert plot coordinates to view coordinates
                let plotWidth = geometry.size.width
                let plotHeight = geometry.size.height
                let marginLeft: Double = 80.0
                let marginBottom: Double = 80.0
                let marginTop: Double = 80.0
                let marginRight: Double = 80.0
                
                let plotAreaWidth = plotWidth - marginLeft - marginRight
                let plotAreaHeight = plotHeight - marginTop - marginBottom
                
                let xMin = volcanoAxis.minX ?? -3.0
                let xMax = volcanoAxis.maxX ?? 3.0
                let yMin = volcanoAxis.minY ?? 0.0
                let yMax = volcanoAxis.maxY ?? 5.0
                
                let x = candidate.arrowPosition.x
                let y = candidate.arrowPosition.y
                
                let viewX = marginLeft + ((x - xMin) / (xMax - xMin)) * plotAreaWidth
                let viewY = plotHeight - marginBottom - ((y - yMin) / (yMax - yMin)) * plotAreaHeight
                
                // Show the data point being annotated
                Circle()
                    .fill(Color.blue.opacity(0.5))
                    .stroke(Color.blue, lineWidth: 3)
                    .frame(width: 20, height: 20)
                    .position(
                        x: CGFloat(viewX),
                        y: CGFloat(viewY)
                    )
                    .overlay(
                        Text("📍")
                            .font(.caption2)
                            .position(
                                x: CGFloat(viewX),
                                y: CGFloat(viewY)
                            )
                    )
            }
        }
    }
    
    // Helper struct for JavaScript coordinate results
    struct JSCoordinateResult {
        let screenX: Double
        let screenY: Double
        let ax: Double
        let ay: Double
    }
    
    // Helper function to find JavaScript coordinates for a given plot position
    private func findJavaScriptCoordinates(plotX: Double, plotY: Double) -> JSCoordinateResult? {
        guard let jsCoordinates = PlotlyWebView.Coordinator.sharedCoordinator?.annotationCoordinates else {
            return nil
        }
        
        for coord in jsCoordinates {
            if let coordPlotX = coord["plotX"] as? Double,
               let coordPlotY = coord["plotY"] as? Double,
               abs(coordPlotX - plotX) < 0.0001,
               abs(coordPlotY - plotY) < 0.0001,
               let screenX = coord["screenX"] as? Double,
               let screenY = coord["screenY"] as? Double,
               let ax = coord["ax"] as? Double,
               let ay = coord["ay"] as? Double {
                return JSCoordinateResult(screenX: screenX, screenY: screenY, ax: ax, ay: ay)
            }
        }
        return nil
    }

    private func calculateNestedPlotBounds(geometry: GeometryProxy) -> (left: Double, top: Double, width: Double, height: Double) {
        // FIXED: The nested GeometryReader coordinate issue - calculate directly from JavaScript
        let coordinator = PlotlyWebView.Coordinator.sharedCoordinator
        let plotDimensions = coordinator?.plotDimensions
        
        if let webViewInfo = plotDimensions?["webView"] as? [String: Any],
           let finalPlotLeft = plotDimensions?["plotLeft"] as? Double,
           let finalPlotTop = plotDimensions?["plotTop"] as? Double,
           let finalPlotRight = plotDimensions?["plotRight"] as? Double,
           let finalPlotBottom = plotDimensions?["plotBottom"] as? Double {
            
            let webViewLeft = webViewInfo["left"] as? Double ?? 0.0
            let webViewTop = webViewInfo["top"] as? Double ?? 0.0
            
            // CRITICAL: For nested GeometryReader in overlay, convert to WebView-relative coordinates
            let plotBounds = (
                left: finalPlotLeft - webViewLeft,
                top: finalPlotTop - webViewTop,
                width: finalPlotRight - finalPlotLeft,
                height: finalPlotBottom - finalPlotTop
            )
            
            print("🔧 NESTED GEOMETRY FIX:")
            print("   Final plot in parent: L=\(finalPlotLeft), T=\(finalPlotTop), R=\(finalPlotRight), B=\(finalPlotBottom)")
            print("   WebView offset: (\(webViewLeft), \(webViewTop))")
            print("   Nested geometry size: \(geometry.size)")
            print("   Calculated bounds: (\(plotBounds.left), \(plotBounds.top), \(plotBounds.width), \(plotBounds.height))")
            
            return plotBounds
        } else {
            // Fallback
            let fallbackBounds = calculatePlotBounds(geometry: geometry)
            print("🔧 Using fallback plot bounds: \(fallbackBounds)")
            return fallbackBounds
        }
    }
    
    private var annotationIndicators: some View {
        GeometryReader { geometry in
            // Calculate safe plot boundaries outside of View builder (RESTORED TO WORKING VERSION)
            let plotBounds = calculatePlotBounds(geometry: geometry)
            
            ZStack {
                ForEach(Array(curtainData.settings.textAnnotation.keys), id: \.self) { key in
                    AnnotationIndicatorView(
                        annotationKey: key,
                        annotationData: curtainData.settings.textAnnotation[key] as? [String: Any],
                        geometry: geometry,
                        volcanoAxis: curtainData.settings.volcanoAxis,
                        jsCoordinatesFinder: findJavaScriptCoordinates
                    )
                }
                
            }
            .frame(width: plotBounds.width, height: plotBounds.height)
            .offset(x: plotBounds.left, y: plotBounds.top)
            .clipped() // Ensure overlay doesn't extend beyond plot area
        }
    }
    
    private func calculatePlotBounds(geometry: GeometryProxy?) -> (left: Double, top: Double, width: Double, height: Double) {
        // Get enhanced plot boundaries from JavaScript that include complete coordinate hierarchy
        let coordinator = PlotlyWebView.Coordinator.sharedCoordinator
        let plotDimensions = coordinator?.plotDimensions
        
        print("📊 Enhanced calculatePlotBounds using complete coordinate hierarchy")
        print("📊 Available plotDimensions keys: \(plotDimensions?.keys.sorted() ?? [])")
        
        // Check if we have the enhanced coordinate hierarchy data
        if let webViewInfo = plotDimensions?["webView"] as? [String: Any],
           let plotElementInfo = plotDimensions?["plotElement"] as? [String: Any],
           let plotAreaInfo = plotDimensions?["plotArea"] as? [String: Any] {
            
            // Extract WebView position in parent view
            let webViewLeft = webViewInfo["left"] as? Double ?? 0.0
            let webViewTop = webViewInfo["top"] as? Double ?? 0.0
            let webViewWidth = webViewInfo["width"] as? Double ?? (geometry?.size.width ?? 400.0)
            let webViewHeight = webViewInfo["height"] as? Double ?? (geometry?.size.height ?? 600.0)
            
            // Extract plot element position within WebView
            let plotElementOffsetX = plotElementInfo["offsetX"] as? Double ?? 0.0
            let plotElementOffsetY = plotElementInfo["offsetY"] as? Double ?? 0.0
            let plotElementWidth = plotElementInfo["width"] as? Double ?? webViewWidth
            let plotElementHeight = plotElementInfo["height"] as? Double ?? webViewHeight
            
            // Extract plot area position within plot element
            let plotAreaLeft = plotAreaInfo["left"] as? Double ?? 0.0
            let plotAreaTop = plotAreaInfo["top"] as? Double ?? 0.0
            let plotAreaWidth = plotAreaInfo["width"] as? Double ?? plotElementWidth
            let plotAreaHeight = plotAreaInfo["height"] as? Double ?? plotElementHeight
            
            print("📊 Enhanced coordinate hierarchy breakdown:")
            print("   🌐 WebView in parent: (\(webViewLeft), \(webViewTop)) \(webViewWidth)x\(webViewHeight)")
            print("   📈 Plot element in WebView: (\(plotElementOffsetX), \(plotElementOffsetY)) \(plotElementWidth)x\(plotElementHeight)")
            print("   📊 Plot area in element: (\(plotAreaLeft), \(plotAreaTop)) \(plotAreaWidth)x\(plotAreaHeight)")
            
            // CRITICAL FIX: For SwiftUI overlays, we need coordinates relative to the WebView, not parent view
            // The JavaScript returns final coordinates in parent view system, but SwiftUI needs WebView-relative
            
            // Method 1: Use the plotLeft/plotRight values and subtract WebView offset to get WebView-relative coordinates
            if let finalPlotLeft = plotDimensions?["plotLeft"] as? Double,
               let finalPlotTop = plotDimensions?["plotTop"] as? Double,
               let finalPlotRight = plotDimensions?["plotRight"] as? Double,
               let finalPlotBottom = plotDimensions?["plotBottom"] as? Double {
                
                // Convert from parent-view coordinates to WebView-relative coordinates
                let swiftUIPlotLeft = finalPlotLeft - webViewLeft
                let swiftUIPlotTop = finalPlotTop - webViewTop
                let swiftUIPlotWidth = finalPlotRight - finalPlotLeft
                let swiftUIPlotHeight = finalPlotBottom - finalPlotTop
                
                print("🎯 FIXED SwiftUI overlay coordinates (WebView-relative from parent-view coordinates):")
                print("   Parent view final: L=\(finalPlotLeft), T=\(finalPlotTop), R=\(finalPlotRight), B=\(finalPlotBottom)")
                print("   WebView offset: (\(webViewLeft), \(webViewTop))")
                print("   WebView-relative position: (\(swiftUIPlotLeft), \(swiftUIPlotTop))")
                print("   Size: \(swiftUIPlotWidth) x \(swiftUIPlotHeight)")
                print("   Coverage: \(swiftUIPlotWidth/webViewWidth*100)% x \(swiftUIPlotHeight/webViewHeight*100)%")
                
                return (left: swiftUIPlotLeft, top: swiftUIPlotTop, width: swiftUIPlotWidth, height: swiftUIPlotHeight)
                
            } else {
                // Method 2: Fallback to manual calculation using hierarchy components
                let swiftUIPlotLeft = plotElementOffsetX + plotAreaLeft
                let swiftUIPlotTop = plotElementOffsetY + plotAreaTop
                let swiftUIPlotWidth = plotAreaWidth
                let swiftUIPlotHeight = plotAreaHeight
                
                print("🎯 Fallback SwiftUI overlay coordinates (manual hierarchy calculation):")
                print("   Position: (\(swiftUIPlotLeft), \(swiftUIPlotTop))")
                print("   Size: \(swiftUIPlotWidth) x \(swiftUIPlotHeight)")
                print("   Coverage: \(swiftUIPlotWidth/webViewWidth*100)% x \(swiftUIPlotHeight/webViewHeight*100)%")
                
                return (left: swiftUIPlotLeft, top: swiftUIPlotTop, width: swiftUIPlotWidth, height: swiftUIPlotHeight)
            }
            
        } else {
            // Fallback to legacy coordinate system for backward compatibility
            print("⚠️ Enhanced coordinate hierarchy not available, using legacy system")
            
            let fullWidth = plotDimensions?["fullWidth"] as? Double ?? (geometry?.size.width ?? 400.0)
            let fullHeight = plotDimensions?["fullHeight"] as? Double ?? (geometry?.size.height ?? 600.0)
            
            let plotLeft = plotDimensions?["plotLeft"] as? Double
            let plotTop = plotDimensions?["plotTop"] as? Double  
            let plotRight = plotDimensions?["plotRight"] as? Double
            let plotBottom = plotDimensions?["plotBottom"] as? Double
            
            // Handle null values by using reasonable defaults based on typical Plotly margins
            let safeLeft: Double
            let safeTop: Double  
            let safeRight: Double
            let safeBottom: Double
            
            if plotLeft == nil || plotTop == nil || plotRight == nil || plotBottom == nil {
                print("⚠️ Some plot dimensions are null, using estimated values")
                safeLeft = fullWidth * 0.15  // ~15% margin left
                safeTop = fullHeight * 0.1   // ~10% margin top  
                safeRight = fullWidth * 0.85 // ~15% margin right
                safeBottom = fullHeight * 0.9 // ~10% margin bottom
            } else {
                safeLeft = plotLeft!
                safeTop = plotTop!
                safeRight = plotRight!
                safeBottom = plotBottom!
            }
            
            let plotWidth = safeRight - safeLeft
            let plotHeight = safeBottom - safeTop
            
            print("🎯 Legacy plot boundaries: L=\(safeLeft), T=\(safeTop), R=\(safeRight), B=\(safeBottom)")
            print("📐 Legacy plot dimensions: \(plotWidth) x \(plotHeight)")
            
            return (left: safeLeft, top: safeTop, width: plotWidth, height: plotHeight)
        }
    }
}

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
        NavigationView {
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
            .navigationBarItems(
                leading: selectedCandidate != nil && candidates.count > 1 ? 
                    AnyView(Button("Back") {
                        selectedCandidate = nil
                    }) :
                    AnyView(Button("Cancel") {
                        isPresented = false
                    }),
                trailing: Button(editAction == .moveTextInteractive ? "Start Interactive Mode" : "Done") {
                    if let candidate = selectedCandidate {
                        if editAction == .moveTextInteractive {
                            // Start interactive positioning mode
                            onInteractivePositioning(candidate)
                            isPresented = false
                        } else {
                            // Save regular changes
                            saveAnnotationChanges(candidate)
                            isPresented = false
                        }
                    }
                }
                .disabled(selectedCandidate == nil && candidates.count > 1)
            )
        }
        .onAppear {
            if candidates.count == 1 {
                selectedCandidate = candidates.first
                editedText = extractPlainText(from: candidates.first?.currentText ?? "")
                
                // Initialize offset values from existing annotation
                if let candidate = candidates.first,
                   let annotationData = curtainData.settings.textAnnotation[candidate.key] as? [String: Any],
                   let dataSection = annotationData["data"] as? [String: Any] {
                    textOffsetX = dataSection["ax"] as? Double ?? -20
                    textOffsetY = dataSection["ay"] as? Double ?? -20
                }
            }
        }
    }
    
    private var annotationSelectionList: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Multiple annotations found:")
                .font(.headline)
            
            List(candidates, id: \.key) { candidate in
                Button(action: {
                    selectedCandidate = candidate
                    editedText = extractPlainText(from: candidate.currentText)
                    
                    // Initialize offset values from selected annotation
                    if let annotationData = curtainData.settings.textAnnotation[candidate.key] as? [String: Any],
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
        
        guard var annotationData = updatedTextAnnotation[candidate.key] as? [String: Any],
              var dataSection = annotationData["data"] as? [String: Any] else {
            print("❌ Failed to get annotation data for key: \(candidate.key)")
            return
        }
        
        if editAction == .editText {
            // Update the text
            let newHtmlText = "<b>\(editedText)</b>"
            dataSection["text"] = newHtmlText
            annotationData["data"] = dataSection
            updatedTextAnnotation[candidate.key] = annotationData
            
            print("🎯 Updated annotation text: '\(editedText)' for key: \(candidate.key)")
        } else if editAction == .moveText {
            // Update the text position offsets
            dataSection["ax"] = textOffsetX
            dataSection["ay"] = textOffsetY
            annotationData["data"] = dataSection
            updatedTextAnnotation[candidate.key] = annotationData
            
            print("🎯 Updated annotation position: '\(candidate.key)' to offset (\(textOffsetX), \(textOffsetY))")
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
            textAnnotation: updatedTextAnnotation, // Updated textAnnotation
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
        
        print("✅ Updated CurtainData with modified annotation")
        print("📊 Total annotations: \(updatedTextAnnotation.count)")
        
        // Trigger plot refresh
        onAnnotationUpdated()
    }
}

// MARK: - Helper Views

struct AnnotationIndicatorView: View {
    let annotationKey: String
    let annotationData: [String: Any]?
    let geometry: GeometryProxy
    let volcanoAxis: VolcanoAxis
    let jsCoordinatesFinder: (Double, Double) -> AnnotationEditOverlay.JSCoordinateResult?
    
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
    let jsResult: AnnotationEditOverlay.JSCoordinateResult
    let plotX: Double
    let plotY: Double
    
    var body: some View {
        GeometryReader { geometry in
            // FIXED: Since the outer annotationIndicators view already applies frame/offset positioning,
            // we should NOT adjust coordinates here to avoid double adjustment that causes clipping
            let coordinator = PlotlyWebView.Coordinator.sharedCoordinator
            let plotDimensions = coordinator?.plotDimensions
            
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

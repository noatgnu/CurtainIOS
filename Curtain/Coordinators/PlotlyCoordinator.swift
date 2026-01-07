//
//  PlotlyCoordinator.swift
//  Curtain
//
//  Created by Toan Phung on 06/01/2026.
//

import WebKit
import SwiftUI
import Combine

// MARK: - Plotly Coordinator

/// Coordinator for PlotlyWebView, managing WebKit lifecycle and event handling
/// Extracted from PlotlyWebView.swift lines 231-886
@MainActor
class PlotlyCoordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {

    // MARK: - Properties

    var parent: PlotlyWebView
    private let chartGenerator: PlotlyChartGenerator
    private var isHtmlLoaded = false
    private let bridgeService: PlotlyBridgeService
    private let colorResolver: ProteinColorResolver
    private var webViewId: String = UUID().uuidString

    // Shared coordinator for global access
    static var sharedCoordinator: PlotlyCoordinator?

    // Plot dimensions and coordinates received from JavaScript
    var plotDimensions: [String: Any]?
    var annotationCoordinates: [[String: Any]]?

    // Track the trace names that were actually rendered in the current plot
    var renderedTraceNames: [String]?

    // MARK: - Initialization

    init(_ parent: PlotlyWebView) {
        self.parent = parent
        self.chartGenerator = PlotlyChartGenerator(curtainDataService: parent.curtainDataService)
        self.bridgeService = PlotlyBridgeService()
        self.colorResolver = ProteinColorResolver.shared
        super.init()

        setupNotificationObservers()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Setup

    private func setupNotificationObservers() {
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

    @objc private func handleVolcanoPlotRefresh(_ notification: Notification) {
        print("🔄 PlotlyCoordinator: Received volcano plot refresh notification")
        if let reason = notification.userInfo?["reason"] as? String {
            print("🔄 PlotlyCoordinator: Refresh reason: \(reason)")
        }

        // Force plot regeneration (like Android volcanoPlotRefreshTrigger)
        isHtmlLoaded = false
        if let webView = bridgeService.getWebView() {
            generateAndLoadPlot(in: webView)
        }
    }

    @objc private func handleAnnotationJSUpdate(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let title = userInfo["title"] as? String,
              let ax = userInfo["ax"] as? Double,
              let ay = userInfo["ay"] as? Double else {
            print("❌ PlotlyCoordinator: Invalid annotation JS update data")
            return
        }

        print("⚡ PlotlyCoordinator: Handling JavaScript annotation update for title: \(title)")
        bridgeService.updateAnnotationPosition(title: title, ax: ax, ay: ay)
    }

    // MARK: - WebView Management

    func setCurrentWebView(_ webView: WKWebView) {
        bridgeService.setWebView(webView)
        Self.sharedCoordinator = self
        print("🌐 PlotlyCoordinator: WebView reference set with ID: \(webViewId)")
    }

    static func getCurrentWebView() -> WKWebView? {
        return sharedCoordinator?.bridgeService.getWebView()
    }

    /// Request plot dimensions from JavaScript
    func requestPlotDimensions() {
        bridgeService.requestPlotDimensions()
    }

    var htmlLoaded: Bool { return isHtmlLoaded }

    // MARK: - WKNavigationDelegate

    nonisolated func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        print("🏁 PlotlyCoordinator: WebView navigation finished")
        Task { @MainActor in
            self.isHtmlLoaded = true
            self.parent.isLoading = false
            self.parent.error = nil

            // Give a small delay for JavaScript to initialize the plot
            Task {
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                if self.parent.isLoading {
                    print("🔧 PlotlyCoordinator: Force completing after navigation + delay")
                    self.parent.isLoading = false
                }
            }
        }
    }

    nonisolated func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        Task { @MainActor in
            self.parent.error = "WebView navigation failed: \(error.localizedDescription)"
            self.parent.isLoading = false
        }
    }

    // MARK: - WKScriptMessageHandler

    nonisolated func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        print("🔔 PlotlyCoordinator: Received message: \(message.name)")
        Task { @MainActor in
            switch message.name {
            case "plotReady":
                print("✅ PlotlyCoordinator: Plot ready message received")
                self.parent.isLoading = false
                self.parent.error = nil

                // Request plot dimensions and annotation coordinates after a small delay
                Task {
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                    self.bridgeService.requestPlotDimensions()
                }

            case "plotUpdated":
                print("🔄 PlotlyCoordinator: Plot updated message received")
                self.parent.isLoading = false

                // Request plot dimensions after updates too, with delay
                Task {
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                    self.bridgeService.requestPlotDimensions()
                }

            case "plotError":
                print("❌ PlotlyCoordinator: Plot error message received: \(message.body)")
                self.parent.error = message.body as? String ?? "Unknown plot error"
                self.parent.isLoading = false

            case "pointClicked":
                print("👆 PlotlyCoordinator: Point clicked message received")
                self.handlePointClicked(message.body)

            case "pointHovered":
                self.handlePointHovered(message.body)

            case "annotationMoved":
                self.handleAnnotationMoved(message.body)

            case "plotDimensions":
                if let dimensionsString = message.body as? String,
                   let dimensionsData = dimensionsString.data(using: .utf8),
                   let dimensions = try? JSONSerialization.jsonObject(with: dimensionsData) as? [String: Any] {
                    print("📏 PlotlyCoordinator: Received plot dimensions: \(dimensions)")
                    self.plotDimensions = dimensions

                    // Trigger UI refresh to recalculate coordinates with new dimensions
                    self.parent.coordinateRefreshTrigger += 1
                    print("🔄 PlotlyCoordinator: Triggering coordinate recalculation after receiving plot dimensions")
                }

            case "annotationCoordinates":
                if let coordinatesString = message.body as? String,
                   let coordinatesData = coordinatesString.data(using: .utf8),
                   let coordinates = try? JSONSerialization.jsonObject(with: coordinatesData) as? [[String: Any]] {
                    print("📍 PlotlyCoordinator: Received annotation coordinates: \(coordinates)")
                    self.annotationCoordinates = coordinates
                }

            case "plotExported":
                print("📤 PlotlyCoordinator: Plot export success message received")
                self.handlePlotExported(message.body)

            case "plotExportError":
                print("❌ PlotlyCoordinator: Plot export error message received")
                self.handlePlotExportError(message.body)

            case "plotInfo":
                print("📊 PlotlyCoordinator: Plot info message received")
                self.handlePlotInfo(message.body)

            default:
                break
            }
        }
    }

    // MARK: - Plot Generation

    func generateAndLoadPlot(in webView: WKWebView) {
        print("🔄 PlotlyCoordinator: generateAndLoadPlot called")

        // Store webView reference for future refresh notifications
        bridgeService.setWebView(webView)

        guard !isHtmlLoaded else {
            print("🔍 PlotlyCoordinator: HTML already loaded, skipping generation")
            return
        }

        parent.error = nil
        print("🔧 PlotlyCoordinator: Preparing to load HTML without setting loading state")

        print("🔄 PlotlyCoordinator: Creating plot generation context")
        print("🔍 PlotlyCoordinator: Protein data count: \(parent.curtainData.proteomicsData.count)")

        // Create plot generation context
        let context = PlotGenerationContext(
            data: parent.curtainData,
            settings: parent.curtainData.settings,
            selections: parent.selections,
            searchFilter: parent.searchFilter,
            editMode: parent.editMode,
            isDarkMode: parent.colorScheme == .dark
        )

        print("🔄 PlotlyCoordinator: Generating HTML for volcano plot")

        // Generate HTML based on plot type - use Task for async calls
        Task {
            let html: String
            switch parent.plotType {
            case .volcano:
                html = await chartGenerator.createVolcanoPlotHtml(context: context)
                // Store the rendered trace names for UI access (e.g., trace order settings)
                self.renderedTraceNames = chartGenerator.lastGeneratedTraceNames
                print("📝 PlotlyCoordinator: Stored \(self.renderedTraceNames?.count ?? 0) rendered trace names")
            case .scatter:
                html = generateNotImplementedHtml("Scatter plot")
            case .heatmap:
                html = generateNotImplementedHtml("Heatmap")
            case .custom:
                html = generateNotImplementedHtml("Custom plot")
            }

            print("🔄 PlotlyCoordinator: HTML generation completed")

            // Update UI on main thread
            await MainActor.run {
                print("🔍 PlotlyCoordinator: Generated HTML (first 200 chars): \(String(html.prefix(200)))")
                print("🔍 PlotlyCoordinator: Loading HTML string directly without a base URL.")
                webView.loadHTMLString(html, baseURL: nil)
                print("🔍 PlotlyCoordinator: loadHTMLString called")

                // Add a backup completion timer in case WebView navigation doesn't complete
                Task {
                    try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                    if self.parent.isLoading {
                        print("⚠️ PlotlyCoordinator: Navigation didn't complete, forcing completion")
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
            print("❌ PlotlyCoordinator: Failed to parse point click data")
            return
        }

        print("👆 PlotlyCoordinator: Processing point click data: \(pointData)")

        // Extract point data from JavaScript message (like Android)
        guard let proteinId = pointData["proteinId"] as? String ?? pointData["id"] as? String,
              let log2FC = pointData["log2FC"] as? Double ?? pointData["x"] as? Double,
              let pValue = pointData["pValue"] as? Double else {
            print("❌ PlotlyCoordinator: Missing required point data")
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

            // Use ProteinColorResolver for color resolution
            let proteinColor = colorResolver.resolveColor(
                proteinId: id,
                fcValue: x,
                pValue: pValue,
                curtainData: parent.curtainData,
                colorMap: volcanoResult.colorMap
            )

            // Debug color assignment for first few proteins
            if proteinCount < 3 {
                print("🎨 PlotlyCoordinator: Protein \(id) assigned color: \(proteinColor)")
                if let selections = dataPoint["selections"] as? [String] {
                    print("🎨 PlotlyCoordinator: Protein \(id) selections: \(selections)")
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

        print("🔍 PlotlyCoordinator: Using volcano data source with \(allProteins.count) proteins")

        // Find the clicked protein
        guard let clickedProtein = allProteins.first(where: { $0.id == proteinId }) else {
            print("❌ PlotlyCoordinator: Clicked protein not found: \(proteinId)")
            print("🔍 PlotlyCoordinator: Available protein IDs (first 10): \(allProteins.prefix(10).map { $0.id })")
            return
        }

        print("✅ PlotlyCoordinator: Found clicked protein: \(clickedProtein.primaryID)")

        // Calculate nearby proteins using euclidean distance (like Android)
        let nearbyProteins = DistanceCalculator.findNearbyProteins(
            around: clickedProtein,
            from: allProteins,
            distanceCutoff: parent.pointInteractionViewModel.distanceCutoff
        )

        print("🔍 PlotlyCoordinator: Found \(nearbyProteins.count) nearby proteins within distance \(parent.pointInteractionViewModel.distanceCutoff)")

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

    // MARK: - Export Handler Methods

    private func handlePlotExported(_ messageBody: Any?) {
        guard let exportData = messageBody as? [String: Any] else {
            print("❌ PlotlyCoordinator: Invalid export data received")
            return
        }

        print("📤 PlotlyCoordinator: Processing export data: \(exportData.keys)")

        // Process the export using the export service
        if let exportService = parent.exportService {
            Task {
                let result = await exportService.processExportData(exportData)
                await MainActor.run {
                    if result.success {
                        print("✅ PlotlyCoordinator: Export completed successfully - \(result.filename)")
                    } else {
                        print("❌ PlotlyCoordinator: Export failed - \(result.error ?? "Unknown error")")
                    }
                }
            }
        } else {
            print("❌ PlotlyCoordinator: Export service not available")
        }
    }

    private func handlePlotExportError(_ messageBody: Any?) {
        if let errorData = messageBody as? [String: Any],
           let format = errorData["format"] as? String,
           let errorMessage = errorData["error"] as? String {
            print("❌ PlotlyCoordinator: \(format.uppercased()) export failed: \(errorMessage)")

            if let exportService = parent.exportService {
                Task { @MainActor in
                    exportService.exportError = "Export failed: \(errorMessage)"
                }
            }
        } else {
            print("❌ PlotlyCoordinator: Unknown export error: \(messageBody ?? "nil")")
        }
    }

    private func handlePlotInfo(_ messageBody: Any?) {
        if let plotInfo = messageBody as? [String: Any] {
            print("📊 PlotlyCoordinator: Plot info received: \(plotInfo)")
            // Store plot info for future export filename generation
        }
    }

    // MARK: - Helper Methods

    private func generateNotImplementedHtml(_ plotType: String) -> String {
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <style>
                body {
                    display: flex;
                    justify-content: center;
                    align-items: center;
                    height: 100vh;
                    margin: 0;
                    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
                    background-color: #f5f5f5;
                }
                .message {
                    text-align: center;
                    padding: 40px;
                    background: white;
                    border-radius: 12px;
                    box-shadow: 0 2px 10px rgba(0,0,0,0.1);
                }
                h2 {
                    color: #333;
                    margin: 0 0 10px 0;
                }
                p {
                    color: #666;
                    margin: 0;
                }
            </style>
        </head>
        <body>
            <div class="message">
                <h2>\(plotType) Not Yet Implemented</h2>
                <p>This plot type is coming soon</p>
            </div>
        </body>
        </html>
        """
    }
}

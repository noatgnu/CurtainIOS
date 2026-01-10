//
//  PlotlyCoordinator.swift
//  Curtain
//
//  Created by Toan Phung on 06/01/2026.
//

import WebKit
import SwiftUI
import Combine

@MainActor
class PlotlyCoordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {


    var parent: PlotlyWebView
    let chartGenerator: PlotlyChartGenerator
    private var isHtmlLoaded = false
    private let bridgeService: PlotlyBridgeService
    private let colorResolver: ProteinColorResolver
    private var webViewId: String = UUID().uuidString

    static var sharedCoordinator: PlotlyCoordinator?

    var plotDimensions: [String: Any]?
    var annotationCoordinates: [[String: Any]]?

    var renderedTraceNames: [String]?


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


    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleVolcanoPlotRefresh),
            name: NSNotification.Name("VolcanoPlotRefresh"),
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAnnotationJSUpdate),
            name: NSNotification.Name("UpdateAnnotationJS"),
            object: nil
        )
    }

    @objc private func handleVolcanoPlotRefresh(_ notification: Notification) {
    }

    @objc private func handleAnnotationJSUpdate(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let title = userInfo["title"] as? String,
              let ax = userInfo["ax"] as? Double,
              let ay = userInfo["ay"] as? Double else {
            return
        }

        bridgeService.updateAnnotationPosition(title: title, ax: ax, ay: ay)
    }


    func setCurrentWebView(_ webView: WKWebView) {
        bridgeService.setWebView(webView)
        Self.sharedCoordinator = self
    }

    static func getCurrentWebView() -> WKWebView? {
        return sharedCoordinator?.bridgeService.getWebView()
    }

    /// Request plot dimensions from JavaScript
    func requestPlotDimensions() {
        bridgeService.requestPlotDimensions()
    }

    var htmlLoaded: Bool { return isHtmlLoaded }


    nonisolated func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Task { @MainActor in
            self.isHtmlLoaded = true
            self.parent.isLoading = false
            self.parent.error = nil

            Task {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if self.parent.isLoading {
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


    nonisolated func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        Task { @MainActor in
            switch message.name {
            case "plotReady":
                self.parent.isLoading = false
                self.parent.error = nil

                Task {
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    self.bridgeService.requestPlotDimensions()
                }

            case "plotUpdated":
                self.parent.isLoading = false

                Task {
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    self.bridgeService.requestPlotDimensions()
                }

            case "plotError":
                self.parent.error = message.body as? String ?? "Unknown plot error"
                self.parent.isLoading = false

            case "pointClicked":
                self.handlePointClicked(message.body)

            case "pointHovered":
                self.handlePointHovered(message.body)

            case "annotationMoved":
                self.handleAnnotationMoved(message.body)

            case "plotDimensions":
                if let dimensionsString = message.body as? String,
                   let dimensionsData = dimensionsString.data(using: .utf8),
                   let dimensions = try? JSONSerialization.jsonObject(with: dimensionsData) as? [String: Any] {
                    self.plotDimensions = dimensions
                    self.parent.coordinateRefreshTrigger += 1
                }

            case "annotationCoordinates":
                if let coordinatesString = message.body as? String,
                   let coordinatesData = coordinatesString.data(using: .utf8),
                   let coordinates = try? JSONSerialization.jsonObject(with: coordinatesData) as? [[String: Any]] {
                    self.annotationCoordinates = coordinates
                }

            case "plotExported":
                self.handlePlotExported(message.body)

            case "plotExportError":
                self.handlePlotExportError(message.body)

            case "plotInfo":
                self.handlePlotInfo(message.body)

            default:
                break
            }
        }
    }


    func generateAndLoadPlot(in webView: WKWebView) {
        bridgeService.setWebView(webView)

        guard !isHtmlLoaded else {
            return
        }

        parent.error = nil

        let context = PlotGenerationContext(
            data: parent.curtainData,
            settings: parent.curtainData.settings,
            selections: parent.selections,
            searchFilter: parent.searchFilter,
            editMode: parent.editMode,
            isDarkMode: parent.colorScheme == .dark
        )

        Task {
            let html: String
            switch parent.plotType {
            case .volcano:
                html = await chartGenerator.createVolcanoPlotHtml(context: context)
                self.renderedTraceNames = chartGenerator.lastGeneratedTraceNames
            case .scatter:
                html = generateNotImplementedHtml("Scatter plot")
            case .heatmap:
                html = generateNotImplementedHtml("Heatmap")
            case .custom:
                html = generateNotImplementedHtml("Custom plot")
            }

            await MainActor.run {
                webView.loadHTMLString(html, baseURL: nil)

                Task {
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    if self.parent.isLoading {
                        self.parent.isLoading = false
                        self.parent.error = nil
                        self.isHtmlLoaded = true
                    }
                }
            }
        }
    }


    private func handlePointClicked(_ messageBody: Any?) {
        Task {
            await handlePointClickedAsync(messageBody)
        }
    }

    private func handlePointClickedAsync(_ messageBody: Any?) async {
        guard let jsonString = messageBody as? String,
              let data = jsonString.data(using: .utf8),
              let pointData = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }

        guard let proteinId = pointData["proteinId"] as? String ?? pointData["id"] as? String,
              let log2FC = pointData["log2FC"] as? Double ?? pointData["x"] as? Double,
              let pValue = pointData["pValue"] as? Double else {
            return
        }

        let plotY = pointData["y"] as? Double ?? -log10(pValue)

        let volcanoDataService = VolcanoPlotDataService()
        let volcanoResult = await volcanoDataService.processVolcanoData(
            curtainData: parent.curtainData,
            settings: parent.curtainData.settings
        )

        var proteinCount = 0
        let allProteins = volcanoResult.jsonData.compactMap { dataPoint -> ProteinPoint? in
            guard let id = dataPoint["id"] as? String,
                  let gene = dataPoint["gene"] as? String,
                  let x = dataPoint["x"] as? Double,
                  let y = dataPoint["y"] as? Double else {
                return nil
            }

            let pValue = pow(10, -y)

            let proteinColor = colorResolver.resolveColor(
                proteinId: id,
                fcValue: x,
                pValue: pValue,
                curtainData: parent.curtainData,
                colorMap: volcanoResult.colorMap
            )

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

        guard let clickedProtein = allProteins.first(where: { $0.id == proteinId }) else {
            return
        }

        let nearbyProteins = DistanceCalculator.findNearbyProteins(
            around: clickedProtein,
            from: allProteins,
            distanceCutoff: parent.pointInteractionViewModel.distanceCutoff
        )

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

        parent.pointInteractionViewModel.handlePointClick(clickData)

        parent.selectedPoints = [clickedProtein]
    }

    private func handlePointHovered(_ messageBody: Any?) {
    }

    private func handleAnnotationMoved(_ messageBody: Any?) {
    }


    private func handlePlotExported(_ messageBody: Any?) {
        guard let exportData = messageBody as? [String: Any] else {
            return
        }

        if let exportService = parent.exportService {
            Task {
                let result = await exportService.processExportData(exportData)
            }
        }
    }

    private func handlePlotExportError(_ messageBody: Any?) {
        if let errorData = messageBody as? [String: Any],
           let format = errorData["format"] as? String,
           let errorMessage = errorData["error"] as? String {
            if let exportService = parent.exportService {
                Task { @MainActor in
                    exportService.exportError = "Export failed: \(errorMessage)"
                }
            }
        }
    }

    private func handlePlotInfo(_ messageBody: Any?) {
    }


    private func generateNotImplementedHtml(_ plotType: String) -> String {
        do {
            let htmlTemplate = try WebTemplateLoader.shared.loadHTMLTemplate(named: "not-implemented")
            let substitutions: [String: String] = [
                "PLOT_TYPE": plotType
            ]
            return WebTemplateLoader.shared.render(template: htmlTemplate, substitutions: substitutions)
        } catch {
            return """
            <!DOCTYPE html>
            <html><body><div style="text-align:center;padding:40px;"><h2>\(plotType) Not Yet Implemented</h2><p>This plot type is coming soon</p></div></body></html>
            """
        }
    }
}

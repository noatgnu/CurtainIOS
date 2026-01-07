//
//  PlotlyBridgeService.swift
//  Curtain
//
//  Created by Toan Phung on 06/01/2026.
//

import WebKit
import Foundation

// MARK: - Plotly Bridge Service

/// Manages JavaScript-Swift communication bridge for Plotly plots
/// Instance-based: Each Coordinator creates its own bridge service
@MainActor
class PlotlyBridgeService {

    // MARK: - Properties

    private weak var webView: WKWebView?
    private let bridgeId = UUID().uuidString

    // MARK: - Initialization

    init() {
        print("PlotlyBridgeService: Created new bridge instance (\(bridgeId))")
    }

    // MARK: - WebView Management

    /// Set the WebView for this bridge instance
    func setWebView(_ webView: WKWebView) {
        self.webView = webView
        print("PlotlyBridgeService: WebView set for bridge (\(bridgeId))")
    }

    /// Get the current WebView reference
    func getWebView() -> WKWebView? {
        return webView
    }

    // MARK: - JavaScript Execution

    /// Execute JavaScript code on the webView
    func evaluateJavaScript(
        _ script: String,
        completion: ((Result<Any?, Error>) -> Void)? = nil
    ) {
        guard let webView = webView else {
            print("❌ PlotlyBridgeService: WebView not available")
            completion?(.failure(PlotlyBridgeError.webViewNotAvailable))
            return
        }

        webView.evaluateJavaScript(script) { result, error in
            if let error = error {
                print("❌ PlotlyBridgeService: JavaScript execution failed: \(error)")
                completion?(.failure(error))
            } else {
                completion?(.success(result))
            }
        }
    }

    // MARK: - Annotation Operations

    /// Update annotation position via JavaScript (no plot reload)
    /// Extracted from PlotlyWebView.swift lines 314-348
    func updateAnnotationPosition(title: String, ax: Double, ay: Double) {
        guard let webView = webView else {
            print("❌ PlotlyBridgeService: No webView available for annotation update")
            return
        }

        print("⚡ PlotlyBridgeService: Updating annotation '\(title)' to ax=\(ax), ay=\(ay)")

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
                print("❌ PlotlyBridgeService: Annotation update failed: \(error)")
            } else {
                print("✅ PlotlyBridgeService: Annotation '\(title)' position updated")
            }
        }
    }

    // MARK: - Plot Dimension Requests

    /// Request plot dimensions and annotation coordinates from JavaScript
    /// Extracted from PlotlyWebView.swift lines 351-384
    func requestPlotDimensions() {
        guard let webView = webView else {
            print("❌ PlotlyBridgeService: No webView available for requesting plot dimensions")
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
                print("❌ PlotlyBridgeService: Plot dimensions request failed: \(error)")
            } else {
                print("✅ PlotlyBridgeService: Requested plot dimensions from JavaScript")
            }
        }
    }

    // MARK: - Export Operations

    /// Export plot as PNG
    /// Extracted from PlotlyWebView.swift lines 112-128
    func exportAsPNG(filename: String, width: Int, height: Int) {
        guard let webView = webView else {
            print("❌ PlotlyBridgeService: Cannot export PNG - WebView not available")
            return
        }

        let jsCode = "window.CurtainVisualization.exportAsPNG('\(filename)', \(width), \(height));"

        print("📤 PlotlyBridgeService: Exporting PNG - \(filename) (\(width)x\(height))")
        webView.evaluateJavaScript(jsCode) { result, error in
            if let error = error {
                print("❌ PlotlyBridgeService: PNG export failed: \(error)")
            } else {
                print("✅ PlotlyBridgeService: PNG export initiated")
            }
        }
    }

    /// Export plot as SVG
    /// Extracted from PlotlyWebView.swift lines 131-146
    func exportAsSVG(filename: String, width: Int, height: Int) {
        guard let webView = webView else {
            print("❌ PlotlyBridgeService: Cannot export SVG - WebView not available")
            return
        }

        let jsCode = "window.CurtainVisualization.exportAsSVG('\(filename)', \(width), \(height));"

        print("📤 PlotlyBridgeService: Exporting SVG - \(filename) (\(width)x\(height))")
        webView.evaluateJavaScript(jsCode) { result, error in
            if let error = error {
                print("❌ PlotlyBridgeService: SVG export failed: \(error)")
            } else {
                print("✅ PlotlyBridgeService: SVG export initiated")
            }
        }
    }

    /// Get current plot info
    /// Extracted from PlotlyWebView.swift lines 148-160
    func getCurrentPlotInfo() {
        guard let webView = webView else {
            print("❌ PlotlyBridgeService: Cannot get plot info - WebView not available")
            return
        }

        let jsCode = "window.CurtainVisualization.getCurrentPlotInfo();"
        webView.evaluateJavaScript(jsCode) { result, error in
            if let error = error {
                print("❌ PlotlyBridgeService: Get plot info failed: \(error)")
            } else {
                print("✅ PlotlyBridgeService: Plot info requested")
            }
        }
    }
}

// MARK: - Errors

enum PlotlyBridgeError: Error {
    case webViewNotAvailable
    case javascriptExecutionFailed(String)
}

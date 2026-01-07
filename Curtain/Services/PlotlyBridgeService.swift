//
//  PlotlyBridgeService.swift
//  Curtain
//
//  Created by Toan Phung on 06/01/2026.
//

import WebKit
import Foundation


@MainActor
class PlotlyBridgeService {


    private weak var webView: WKWebView?
    private let bridgeId = UUID().uuidString


    init() {
    }


    func setWebView(_ webView: WKWebView) {
        self.webView = webView
    }

    func getWebView() -> WKWebView? {
        return webView
    }


    func evaluateJavaScript(
        _ script: String,
        completion: ((Result<Any?, Error>) -> Void)? = nil
    ) {
        guard let webView = webView else {
            completion?(.failure(PlotlyBridgeError.webViewNotAvailable))
            return
        }

        webView.evaluateJavaScript(script) { result, error in
            if let error = error {
                completion?(.failure(error))
            } else {
                completion?(.success(result))
            }
        }
    }


    func updateAnnotationPosition(title: String, ax: Double, ay: Double) {
        guard let webView = webView else {
            return
        }

        let jsCode = """
            if (window.VolcanoPlot && window.VolcanoPlot.updateAnnotationPosition) {
                window.VolcanoPlot.updateAnnotationPosition('\(title)', \(ax), \(ay));
            }
        """

        webView.evaluateJavaScript(jsCode, completionHandler: nil)
    }


    func requestPlotDimensions() {
        guard let webView = webView else {
            return
        }

        let jsCode = """
            if (window.VolcanoPlot && window.VolcanoPlot.sendPlotDimensions) {
                window.VolcanoPlot.sendPlotDimensions();

                if (window.VolcanoPlot.convertAndSendCoordinates) {
                    const plotElement = document.getElementById('plot');
                    if (plotElement && plotElement.layout && plotElement.layout.annotations && plotElement.layout.annotations.length > 0) {
                        window.VolcanoPlot.convertAndSendCoordinates(plotElement.layout.annotations);
                    }
                }
            }
        """

        webView.evaluateJavaScript(jsCode, completionHandler: nil)
    }


    func exportAsPNG(filename: String, width: Int, height: Int) {
        guard let webView = webView else {
            return
        }

        let jsCode = "window.CurtainVisualization.exportAsPNG('\(filename)', \(width), \(height));"

        webView.evaluateJavaScript(jsCode, completionHandler: nil)
    }

    func exportAsSVG(filename: String, width: Int, height: Int) {
        guard let webView = webView else {
            return
        }

        let jsCode = "window.CurtainVisualization.exportAsSVG('\(filename)', \(width), \(height));"

        webView.evaluateJavaScript(jsCode, completionHandler: nil)
    }

    func getCurrentPlotInfo() {
        guard let webView = webView else {
            return
        }

        let jsCode = "window.CurtainVisualization.getCurrentPlotInfo();"
        webView.evaluateJavaScript(jsCode, completionHandler: nil)
    }
}


enum PlotlyBridgeError: Error {
    case webViewNotAvailable
    case javascriptExecutionFailed(String)
}

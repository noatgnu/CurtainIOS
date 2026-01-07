//
//  CoordinateTransformUtilities.swift
//  Curtain
//
//  Created by Toan Phung on 06/01/2026.
//

import CoreGraphics
import Foundation
import SwiftUI

// MARK: - Supporting Types

/// Represents the calculated bounds of the plot area
struct PlotBounds {
    let left: Double
    let top: Double
    let width: Double
    let height: Double
}

/// Represents the axis ranges for coordinate transformations
struct AxisRanges {
    let xMin: Double
    let xMax: Double
    let yMin: Double
    let yMax: Double

    /// Initialize from VolcanoAxis with default fallback values
    init(volcanoAxis: VolcanoAxis) {
        self.xMin = volcanoAxis.minX ?? -3.0
        self.xMax = volcanoAxis.maxX ?? 3.0
        self.yMin = volcanoAxis.minY ?? 0.0
        self.yMax = volcanoAxis.maxY ?? 5.0
    }

    /// Initialize with explicit values
    init(xMin: Double, xMax: Double, yMin: Double, yMax: Double) {
        self.xMin = xMin
        self.xMax = xMax
        self.yMin = yMin
        self.yMax = yMax
    }
}

// MARK: - Coordinate Transform Utilities

/// Pure coordinate transformation utilities for Plotly plots
/// Handles conversions between plot data space, view space, and Plotly offset coordinates
struct CoordinateTransformUtilities {

    // MARK: - Plot Bounds Calculation

    /// Calculate plot area bounds from JavaScript dimensions with complete coordinate hierarchy
    /// Extracted from PlotlyWebView.swift lines 2128-2242
    static func calculatePlotBounds(
        from jsDimensions: [String: Any]?,
        viewSize: CGSize,
        useEnhancedHierarchy: Bool = true
    ) -> PlotBounds {
        guard let plotDimensions = jsDimensions else {
            return fallbackPlotBounds(viewSize: viewSize)
        }

        print("📊 CoordinateTransformUtilities: Calculating plot bounds")
        print("📊 Available plotDimensions keys: \(plotDimensions.keys.sorted())")

        // Check if we have the enhanced coordinate hierarchy data
        if useEnhancedHierarchy,
           let webViewInfo = plotDimensions["webView"] as? [String: Any],
           let plotElementInfo = plotDimensions["plotElement"] as? [String: Any],
           let plotAreaInfo = plotDimensions["plotArea"] as? [String: Any] {

            // Extract WebView position in parent view
            let webViewLeft = webViewInfo["left"] as? Double ?? 0.0
            let webViewTop = webViewInfo["top"] as? Double ?? 0.0
            let webViewWidth = webViewInfo["width"] as? Double ?? viewSize.width
            let webViewHeight = webViewInfo["height"] as? Double ?? viewSize.height

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

            // Use final plot coordinates and convert to WebView-relative
            if let finalPlotLeft = plotDimensions["plotLeft"] as? Double,
               let finalPlotTop = plotDimensions["plotTop"] as? Double,
               let finalPlotRight = plotDimensions["plotRight"] as? Double,
               let finalPlotBottom = plotDimensions["plotBottom"] as? Double {

                // Convert from parent-view coordinates to WebView-relative coordinates
                let swiftUIPlotLeft = finalPlotLeft - webViewLeft
                let swiftUIPlotTop = finalPlotTop - webViewTop
                let swiftUIPlotWidth = finalPlotRight - finalPlotLeft
                let swiftUIPlotHeight = finalPlotBottom - finalPlotTop

                print("🎯 SwiftUI overlay coordinates (WebView-relative):")
                print("   Parent view final: L=\(finalPlotLeft), T=\(finalPlotTop), R=\(finalPlotRight), B=\(finalPlotBottom)")
                print("   WebView offset: (\(webViewLeft), \(webViewTop))")
                print("   WebView-relative position: (\(swiftUIPlotLeft), \(swiftUIPlotTop))")
                print("   Size: \(swiftUIPlotWidth) x \(swiftUIPlotHeight)")
                print("   Coverage: \(swiftUIPlotWidth/webViewWidth*100)% x \(swiftUIPlotHeight/webViewHeight*100)%")

                return PlotBounds(
                    left: swiftUIPlotLeft,
                    top: swiftUIPlotTop,
                    width: swiftUIPlotWidth,
                    height: swiftUIPlotHeight
                )
            } else {
                // Fallback to manual calculation using hierarchy components
                let swiftUIPlotLeft = plotElementOffsetX + plotAreaLeft
                let swiftUIPlotTop = plotElementOffsetY + plotAreaTop
                let swiftUIPlotWidth = plotAreaWidth
                let swiftUIPlotHeight = plotAreaHeight

                print("🎯 Fallback SwiftUI overlay coordinates (manual hierarchy calculation):")
                print("   Position: (\(swiftUIPlotLeft), \(swiftUIPlotTop))")
                print("   Size: \(swiftUIPlotWidth) x \(swiftUIPlotHeight)")

                return PlotBounds(
                    left: swiftUIPlotLeft,
                    top: swiftUIPlotTop,
                    width: swiftUIPlotWidth,
                    height: swiftUIPlotHeight
                )
            }
        } else {
            // Legacy coordinate system fallback
            return legacyPlotBounds(from: plotDimensions, viewSize: viewSize)
        }
    }

    /// Calculate nested plot bounds for overlay geometry
    /// Extracted from PlotlyWebView.swift lines 2068-2103
    static func calculateNestedPlotBounds(
        from jsDimensions: [String: Any]?,
        viewSize: CGSize
    ) -> PlotBounds {
        guard let plotDimensions = jsDimensions else {
            return fallbackPlotBounds(viewSize: viewSize)
        }

        if let webViewInfo = plotDimensions["webView"] as? [String: Any],
           let finalPlotLeft = plotDimensions["plotLeft"] as? Double,
           let finalPlotTop = plotDimensions["plotTop"] as? Double,
           let finalPlotRight = plotDimensions["plotRight"] as? Double,
           let finalPlotBottom = plotDimensions["plotBottom"] as? Double {

            let webViewLeft = webViewInfo["left"] as? Double ?? 0.0
            let webViewTop = webViewInfo["top"] as? Double ?? 0.0

            // CRITICAL: For nested GeometryReader in overlay, convert to WebView-relative coordinates
            let plotBounds = PlotBounds(
                left: finalPlotLeft - webViewLeft,
                top: finalPlotTop - webViewTop,
                width: finalPlotRight - finalPlotLeft,
                height: finalPlotBottom - finalPlotTop
            )

            print("🔧 NESTED GEOMETRY FIX:")
            print("   Final plot in parent: L=\(finalPlotLeft), T=\(finalPlotTop), R=\(finalPlotRight), B=\(finalPlotBottom)")
            print("   WebView offset: (\(webViewLeft), \(webViewTop))")
            print("   Calculated bounds: (\(plotBounds.left), \(plotBounds.top), \(plotBounds.width), \(plotBounds.height))")

            return plotBounds
        } else {
            return calculatePlotBounds(from: jsDimensions, viewSize: viewSize)
        }
    }

    // MARK: - Coordinate Conversions

    /// Convert plot data coordinates to view coordinates
    /// Extracted from PlotlyWebView.swift lines 1265-1268, 1477-1478, 2014-2016
    static func plotToView(
        plotX: Double,
        plotY: Double,
        plotBounds: PlotBounds,
        axisRanges: AxisRanges
    ) -> CGPoint {
        let viewX = plotBounds.left + ((plotX - axisRanges.xMin) / (axisRanges.xMax - axisRanges.xMin)) * plotBounds.width
        let viewY = plotBounds.height - ((plotY - axisRanges.yMin) / (axisRanges.yMax - axisRanges.yMin)) * plotBounds.height + plotBounds.top

        return CGPoint(x: viewX, y: viewY)
    }

    /// Convert view coordinates to plot data coordinates
    static func viewToPlot(
        viewX: Double,
        viewY: Double,
        plotBounds: PlotBounds,
        axisRanges: AxisRanges
    ) -> CGPoint {
        let plotX = axisRanges.xMin + ((viewX - plotBounds.left) / plotBounds.width) * (axisRanges.xMax - axisRanges.xMin)
        let plotY = axisRanges.yMin + ((plotBounds.height - (viewY - plotBounds.top)) / plotBounds.height) * (axisRanges.yMax - axisRanges.yMin)

        return CGPoint(x: plotX, y: plotY)
    }

    /// Calculate Plotly annotation offset from view positions
    /// Extracted from PlotlyWebView.swift lines 1068-1074, 1118-1136
    static func calculatePlotlyOffset(
        arrowViewPosition: CGPoint,
        textViewPosition: CGPoint
    ) -> (ax: Double, ay: Double) {
        let offsetX = textViewPosition.x - arrowViewPosition.x
        let offsetY = textViewPosition.y - arrowViewPosition.y

        return (ax: offsetX, ay: offsetY)
    }

    // MARK: - Private Helper Methods

    /// Legacy plot bounds calculation for backward compatibility
    private static func legacyPlotBounds(from plotDimensions: [String: Any], viewSize: CGSize) -> PlotBounds {
        print("⚠️ Using legacy coordinate system")

        let fullWidth = plotDimensions["fullWidth"] as? Double ?? viewSize.width
        let fullHeight = plotDimensions["fullHeight"] as? Double ?? viewSize.height

        let plotLeft = plotDimensions["plotLeft"] as? Double
        let plotTop = plotDimensions["plotTop"] as? Double
        let plotRight = plotDimensions["plotRight"] as? Double
        let plotBottom = plotDimensions["plotBottom"] as? Double

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

        return PlotBounds(left: safeLeft, top: safeTop, width: plotWidth, height: plotHeight)
    }

    /// Fallback plot bounds when no JavaScript dimensions available
    private static func fallbackPlotBounds(viewSize: CGSize) -> PlotBounds {
        print("⚠️ No plot dimensions available, using fallback estimates")

        let estimatedMarginLeft = viewSize.width * 0.15
        let estimatedMarginTop = viewSize.height * 0.1
        let estimatedMarginRight = viewSize.width * 0.15
        let estimatedMarginBottom = viewSize.height * 0.1

        let plotWidth = viewSize.width - estimatedMarginLeft - estimatedMarginRight
        let plotHeight = viewSize.height - estimatedMarginTop - estimatedMarginBottom

        return PlotBounds(
            left: estimatedMarginLeft,
            top: estimatedMarginTop,
            width: plotWidth,
            height: plotHeight
        )
    }
}

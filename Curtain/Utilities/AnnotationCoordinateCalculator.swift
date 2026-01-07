//
//  AnnotationCoordinateCalculator.swift
//  Curtain
//
//  Created by Toan Phung on 06/01/2026.
//

import CoreGraphics
import Foundation
import SwiftUI

// MARK: - Supporting Types

/// Result of JavaScript coordinate lookup
struct JSCoordinateResult {
    let screenX: Double
    let screenY: Double
    let ax: Double
    let ay: Double
}

// MARK: - Annotation Coordinate Calculator

/// Specialized utilities for annotation coordinate calculations
/// Handles finding annotations near points and coordinate lookups
struct AnnotationCoordinateCalculator {

    // MARK: - Annotation Discovery

    /// Find annotations near a tap point
    /// Extracted from PlotlyWebView.swift lines 1438-1521
    static func findAnnotationsNearPoint(
        _ tapPoint: CGPoint,
        maxDistance: Double,
        textAnnotations: [String: Any],
        volcanoAxis: VolcanoAxis,
        viewSize: CGSize,
        jsDimensions: [String: Any]?
    ) -> [AnnotationEditCandidate] {
        var candidates: [AnnotationEditCandidate] = []


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
            let viewTextX = viewArrowX + ax
            let viewTextY = viewArrowY + ay


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

    // MARK: - Position Calculations

    /// Get arrow position for a candidate annotation
    /// Extracted from PlotlyWebView.swift lines 1170-1270
    static func getArrowPosition(
        for candidate: AnnotationEditCandidate,
        viewSize: CGSize,
        volcanoAxis: VolcanoAxis,
        jsCoordinates: [[String: Any]]?,
        jsDimensions: [String: Any]?
    ) -> CGPoint? {

        // Try to use JavaScript-provided coordinates first
        if let jsCoordinates = jsCoordinates {
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

        let plotWidth = Double(viewSize.width)
        let plotHeight = Double(viewSize.height)

        let (marginLeft, marginRight, marginTop, marginBottom): (Double, Double, Double, Double)

        if let jsDimensions = jsDimensions,
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

    /// Get current text position for annotation
    /// Extracted from PlotlyWebView.swift lines 1140-1167
    static func getCurrentTextPosition(
        for candidate: AnnotationEditCandidate,
        arrowPosition: CGPoint,
        annotationData: [String: Any]
    ) -> CGPoint {
        // Get current ax/ay offsets from the annotation data
        guard let dataSection = annotationData["data"] as? [String: Any],
              let ax = dataSection["ax"] as? Double,
              let ay = dataSection["ay"] as? Double else {
            return arrowPosition // Fallback to arrow position
        }

        // Add both ax and ay directly
        let currentTextPosition = CGPoint(
            x: arrowPosition.x + ax,
            y: arrowPosition.y + ay
        )


        return currentTextPosition
    }

    // MARK: - JavaScript Coordinate Lookup

    /// Find JavaScript coordinates for plot position
    /// Extracted from PlotlyWebView.swift lines 2048-2066
    static func findJavaScriptCoordinates(
        plotX: Double,
        plotY: Double,
        jsCoordinates: [[String: Any]]?
    ) -> JSCoordinateResult? {
        guard let jsCoordinates = jsCoordinates else {
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
}

//
//  AnnotationEditOverlay.swift
//  Curtain
//
//  Created by Toan Phung on 06/01/2026.
//

import SwiftUI

// MARK: - Annotation Edit Overlay

/// Overlay for annotation editing with tap and drag gestures
/// Extracted from PlotlyWebView.swift lines 1826-2243
struct AnnotationEditOverlay: View {
    let curtainData: CurtainData
    let isInteractivePositioning: Bool
    let isPreviewingPosition: Bool
    let positioningCandidate: AnnotationEditCandidate?
    // Native drag preview properties - using @Binding for real-time updates
    @Binding var isShowingDragPreview: Bool
    @Binding var dragStartPosition: CGPoint?
    @Binding var currentDragPosition: CGPoint?
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
                        } else {
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

    // MARK: - Native Drag Preview

    /// Native drag preview line - smooth SwiftUI rendering
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

    // MARK: - Interactive Positioning Indicators

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

    // MARK: - Annotation Indicators

    private var annotationIndicators: some View {
        GeometryReader { geometry in
            // Calculate safe plot boundaries using CoordinateTransformUtilities
            let plotBounds = calculatePlotBounds(geometry: geometry)

            ZStack {
                ForEach(Array(curtainData.settings.textAnnotation.keys), id: \.self) { key in
                    AnnotationIndicatorView(
                        annotationKey: key,
                        annotationData: curtainData.settings.textAnnotation[key]?.value as? [String: Any],
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

    // MARK: - Helper Methods

    /// Find JavaScript coordinates for a given plot position
    private func findJavaScriptCoordinates(plotX: Double, plotY: Double) -> JSCoordinateResult? {
        guard let jsCoordinates = PlotlyCoordinator.sharedCoordinator?.annotationCoordinates else {
            return nil
        }

        return AnnotationCoordinateCalculator.findJavaScriptCoordinates(
            plotX: plotX,
            plotY: plotY,
            jsCoordinates: jsCoordinates
        )
    }

    /// Calculate nested plot bounds for overlay geometry
    private func calculateNestedPlotBounds(geometry: GeometryProxy) -> (left: Double, top: Double, width: Double, height: Double) {
        let coordinator = PlotlyCoordinator.sharedCoordinator
        let plotDimensions = coordinator?.plotDimensions

        if let webViewInfo = plotDimensions?["webView"] as? [String: Any],
           let _ = plotDimensions?["plotLeft"] as? Double,
           let _ = plotDimensions?["plotTop"] as? Double,
           let _ = plotDimensions?["plotRight"] as? Double,
           let _ = plotDimensions?["plotBottom"] as? Double {

            let _ = webViewInfo["left"] as? Double ?? 0.0
            let _ = webViewInfo["top"] as? Double ?? 0.0

            // Use CoordinateTransformUtilities
            let bounds = CoordinateTransformUtilities.calculateNestedPlotBounds(
                from: plotDimensions,
                viewSize: geometry.size
            )

            return (left: bounds.left, top: bounds.top, width: bounds.width, height: bounds.height)
        } else {
            // Fallback
            let fallbackBounds = calculatePlotBounds(geometry: geometry)
            return fallbackBounds
        }
    }

    /// Calculate plot bounds using CoordinateTransformUtilities
    private func calculatePlotBounds(geometry: GeometryProxy?) -> (left: Double, top: Double, width: Double, height: Double) {
        let coordinator = PlotlyCoordinator.sharedCoordinator
        let plotDimensions = coordinator?.plotDimensions

        let bounds = CoordinateTransformUtilities.calculatePlotBounds(
            from: plotDimensions,
            viewSize: geometry?.size ?? CGSize(width: 400, height: 600)
        )

        return (left: bounds.left, top: bounds.top, width: bounds.width, height: bounds.height)
    }
}

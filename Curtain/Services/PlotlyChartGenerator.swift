//
//  PlotlyChartGenerator.swift
//  Curtain
//
//  Created by Toan Phung on 02/08/2025.
//

import Foundation
import UIKit

class PlotlyChartGenerator {
    private let curtainDataService: CurtainDataService?
    private let volcanoPlotDataService: VolcanoPlotDataService

    private(set) var lastGeneratedTraceNames: [String] = []

    init(curtainDataService: CurtainDataService? = nil) {
        self.curtainDataService = curtainDataService
        self.volcanoPlotDataService = VolcanoPlotDataService()
    }
    
    
    func createVolcanoPlotHtml(context: PlotGenerationContext) async -> String {
        
        let volcanoResult = await volcanoPlotDataService.processVolcanoData(
            curtainData: convertToCurtainData(context.data),
            settings: context.settings
        )
        
        
        let plotData = createAndroidCompatiblePlotData(volcanoResult, context: context)
        
        do {
            let plotJSON = try plotData.toJSON()
            return generateVolcanoHtmlTemplate(plotJSON: plotJSON, editMode: context.editMode, isDarkMode: context.isDarkMode)
        } catch {
            return generateErrorHtml("Failed to generate volcano plot data")
        }
    }
    
    private func convertToCurtainData(_ data: CurtainData) -> CurtainData {
        return data
    }
    
    private func createAndroidCompatiblePlotData(_ volcanoResult: VolcanoProcessResult, context: PlotGenerationContext) -> PlotData {
        let traces = createAndroidCompatibleTraces(volcanoResult.jsonData, settings: context.settings, colorMap: volcanoResult.colorMap)
        let layout = createAndroidCompatibleLayout(volcanoResult, context: context)
        let config = createDefaultPlotConfig()
        
        return PlotData(traces: traces, layout: layout, config: config)
    }
    
    
    private func createAndroidCompatibleTraces(_ jsonData: [[String: Any]], settings: CurtainSettings, colorMap: [String: String]) -> [PlotTrace] {
        
        var selectionGroups: [String: (color: String, points: [AndroidDataPoint])] = [:]
        
        for dataPoint in jsonData {
            let androidPoint = AndroidDataPoint(
                x: dataPoint["x"] as? Double ?? 0.0,
                y: dataPoint["y"] as? Double ?? 0.0,
                id: dataPoint["id"] as? String ?? "",
                gene: dataPoint["gene"] as? String ?? "",
                comparison: dataPoint["comparison"] as? String ?? "1",
                selections: dataPoint["selections"] as? [String] ?? [],
                colors: dataPoint["colors"] as? [String] ?? [],
                color: dataPoint["color"] as? String ?? "#808080",
                customText: dataPoint["customText"] as? String
            )
            
            for (index, selectionName) in androidPoint.selections.enumerated() {
                let selectionColor = index < androidPoint.colors.count ? androidPoint.colors[index] : "#808080"
                
                if selectionGroups[selectionName] == nil {
                    selectionGroups[selectionName] = (color: selectionColor, points: [])
                }
                selectionGroups[selectionName]?.points.append(androidPoint)
            }
        }
        

        var traces: [PlotTrace] = []

        let allGroupNames = Array(selectionGroups.keys).sorted()

        let userSelectionNames = allGroupNames.filter { selectionName in
            return selectionName != "Background" &&
                   selectionName != "Other" &&
                   !selectionName.contains("P-value") &&
                   !selectionName.contains("FC")
        }

        for selectionName in userSelectionNames {
            guard let groupData = selectionGroups[selectionName] else { continue }
            let trace = createAndroidCompatibleTrace(
                dataPoints: groupData.points,
                name: selectionName,
                color: groupData.color,
                markerSize: getMarkerSize(for: selectionName, settings: settings)
            )
            traces.append(trace)
        }

        let backgroundAndSignificanceNames = allGroupNames.filter { selectionName in
            return selectionName == "Background" ||
                   selectionName == "Other" ||
                   selectionName.contains("P-value") ||
                   selectionName.contains("FC")
        }

        for selectionName in backgroundAndSignificanceNames {
            guard let groupData = selectionGroups[selectionName] else { continue }
            let trace = createAndroidCompatibleTrace(
                dataPoints: groupData.points,
                name: selectionName,
                color: groupData.color,
                markerSize: getMarkerSize(for: selectionName, settings: settings)
            )
            traces.append(trace)
        }


        if !settings.volcanoTraceOrder.isEmpty {
            traces = reorderTraces(traces, accordingTo: settings.volcanoTraceOrder)
        } else {
            traces.reverse()
        }


        lastGeneratedTraceNames = traces.map { $0.name }

        return traces
    }
    
    private func createAndroidCompatibleTrace(dataPoints: [AndroidDataPoint], name: String, color: String, markerSize: Double) -> PlotTrace {
        let x = dataPoints.map { $0.x }
        let y = dataPoints.map { $0.y }
        
        let text = dataPoints.map { point -> String in
            if let customText = point.customText, !customText.isEmpty {
                return customText
            }

            let geneName = point.gene.trimmingCharacters(in: .whitespacesAndNewlines)
            let primaryId = point.id.trimmingCharacters(in: .whitespacesAndNewlines)

            if !geneName.isEmpty && geneName != primaryId {
                return "\(geneName)(\(primaryId))"
            } else {
                return primaryId
            }
        }
        
        let customdata = dataPoints.map { point -> [String: Any] in
            return [
                "id": point.id,
                "gene": point.gene,
                "comparison": point.comparison,
                "x": point.x,
                "y": point.y,
                "pValue": pow(10, -point.y), // Convert back from -log10
                "selections": point.selections,
                "colors": point.colors
            ]
        }
        
        let marker = PlotMarker(
            color: color,
            size: markerSize,
            symbol: "circle",
            line: PlotLine(color: "white", width: 0.5, dash: nil)
        )
        
        return PlotTrace(
            x: x,
            y: y,
            mode: "markers",
            type: "scatter",
            name: name,
            marker: marker,
            text: text,
            hovertemplate: "<b>%{text}</b><br>Log2FC: %{x:.3f}<br>-Log10(p-value): %{y:.3f}<br>p-value: %{customdata.pValue:.2e}<extra></extra>",
            customdata: customdata
        )
    }
    
    private func createAndroidCompatibleLayout(_ volcanoResult: VolcanoProcessResult, context: PlotGenerationContext) -> PlotLayout {
        let settings = context.settings
        let volcanoAxis = volcanoResult.updatedVolcanoAxis

        let textColor = context.isDarkMode ? "#E0E0E0" : "#000000"  // Light gray for better contrast than pure white
        let gridColor = context.isDarkMode ? "#555555" : "#e0e0e0"  // Medium gray for visibility

        let title = PlotTitle(
            text: settings.volcanoPlotTitle,
            font: PlotFont(
                family: settings.plotFontFamily,
                size: 16,
                color: textColor
            )
        )


        let xaxisZerolineColor: String
        if settings.volcanoPlotYaxisPosition.contains("middle") {
            xaxisZerolineColor = context.isDarkMode ? "#E0E0E0" : "#000000"
        } else {
            xaxisZerolineColor = "rgba(0,0,0,0)"
        }

        let xaxis = PlotAxis(
            title: PlotAxisTitle(
                text: volcanoAxis.x,
                font: PlotFont(family: settings.plotFontFamily, size: 12, color: textColor)
            ),
            zeroline: nil,
            zerolinecolor: xaxisZerolineColor,
            gridcolor: gridColor,
            linecolor: textColor,
            range: [volcanoAxis.minX ?? -3.0, volcanoAxis.maxX ?? 3.0],
            font: PlotFont(family: settings.plotFontFamily, size: 10, color: textColor),
            dtick: volcanoAxis.dtickX,
            ticklen: volcanoAxis.ticklenX,
            showgrid: settings.volcanoPlotGrid["x"] ?? true
        )

        let yaxis = PlotAxis(
            title: PlotAxisTitle(
                text: volcanoAxis.y,
                font: PlotFont(family: settings.plotFontFamily, size: 12, color: textColor)
            ),
            zeroline: false,
            zerolinecolor: nil,
            showline: false,
            gridcolor: gridColor,
            linecolor: textColor,
            range: [volcanoAxis.minY ?? 0.0, volcanoAxis.maxY ?? 5.0],
            font: PlotFont(family: settings.plotFontFamily, size: 10, color: textColor),
            dtick: volcanoAxis.dtickY,
            ticklen: volcanoAxis.ticklenY,
            showgrid: settings.volcanoPlotGrid["y"] ?? true,
            side: nil
        )

        var shapes = createAndroidCompatibleThresholdShapes(settings, volcanoAxis)

        if settings.volcanoPlotYaxisPosition.contains("left") {
            let yAxisShape = PlotShape(
                type: "line",
                x0: volcanoAxis.minX ?? -3.0,
                x1: volcanoAxis.minX ?? -3.0,
                y0: volcanoAxis.minY ?? 0.0,
                y1: volcanoAxis.maxY ?? 5.0,
                xref: "x",
                yref: "y",
                line: PlotLine(color: textColor, width: 1, dash: nil),
                isYAxisLine: true
            )
            shapes.append(yAxisShape)
        } else {
        }
        for (key, value) in settings.textAnnotation {
        }
        var annotations = convertTextAnnotations(settings.textAnnotation, isDarkMode: context.isDarkMode)

        let conditionLabelAnnotations = createVolcanoConditionLabelAnnotations(settings, isDarkMode: context.isDarkMode)
        annotations.append(contentsOf: conditionLabelAnnotations)

        return PlotLayout(
            title: title,
            xaxis: xaxis,
            yaxis: yaxis,
            hovermode: "closest",
            showlegend: true,
            plot_bgcolor: "rgba(0,0,0,0)",  // Transparent - let HTML background show through
            paper_bgcolor: "rgba(0,0,0,0)",  // Transparent - let HTML background show through
            font: PlotFont(family: settings.plotFontFamily, size: 12, color: textColor),
            shapes: shapes,
            annotations: annotations,
            legend: PlotLegend(
                orientation: "h", // Horizontal orientation like Android
                x: 0.5,
                xanchor: "center",
                y: settings.volcanoPlotLegendY ?? -0.1, // Position below the plot like Android
                yanchor: "top"
            )
        )
    }
    
    private func createAndroidCompatibleThresholdShapes(_ settings: CurtainSettings, _ volcanoAxis: VolcanoAxis) -> [PlotShape] {
        let maxY = volcanoAxis.maxY ?? 5.0
        let minX = volcanoAxis.minX ?? -3.0
        let maxX = volcanoAxis.maxX ?? 3.0
        
        let pValueThreshold = -log10(settings.pCutoff)
        
        return [
            PlotShape(
                type: "line",
                x0: -settings.log2FCCutoff,
                x1: -settings.log2FCCutoff,
                y0: 0,
                y1: maxY,
                xref: "x",
                yref: "y",
                line: PlotLine(color: "rgb(21,4,4)", width: 1, dash: "dash"),
                isYAxisLine: nil
            ),
            PlotShape(
                type: "line",
                x0: settings.log2FCCutoff,
                x1: settings.log2FCCutoff,
                y0: 0,
                y1: maxY,
                xref: "x",
                yref: "y",
                line: PlotLine(color: "rgb(21,4,4)", width: 1, dash: "dash"),
                isYAxisLine: nil
            ),
            PlotShape(
                type: "line",
                x0: minX,
                x1: maxX,
                y0: pValueThreshold,
                y1: pValueThreshold,
                xref: "x",
                yref: "y",
                line: PlotLine(color: "rgb(21,4,4)", width: 1, dash: "dash"),
                isYAxisLine: nil
            )
        ]
    }
    
    
    
    private struct AndroidDataPoint {
        let x: Double
        let y: Double
        let id: String
        let gene: String
        let comparison: String
        let selections: [String]
        let colors: [String]
        let color: String
        let customText: String?  // Optional custom text from user-specified column
    }
    
    private func convertTextAnnotations(_ textAnnotations: [String: Any], isDarkMode: Bool) -> [PlotAnnotation] {
        var annotations: [PlotAnnotation] = []

        let defaultFontColor = isDarkMode ? "#FFFFFF" : "#000000"
        let defaultArrowColor = isDarkMode ? "#FFFFFF" : "#000000"

        for (key, value) in textAnnotations {

            if let annotationData = value as? [String: Any] {
                if let dataSection = annotationData["data"] as? [String: Any] {

                    guard let text = dataSection["text"] as? String,
                          let x = dataSection["x"] as? Double,
                          let y = dataSection["y"] as? Double else {
                        continue
                    }

                    let title = annotationData["title"] as? String ?? key

                    let showarrow = dataSection["showarrow"] as? Bool ?? true
                    let arrowhead = dataSection["arrowhead"] as? Int ?? 1
                    let arrowsize = dataSection["arrowsize"] as? Double ?? 1.0
                    let arrowwidth = dataSection["arrowwidth"] as? Double ?? 1.0

                    var arrowcolor = dataSection["arrowcolor"] as? String ?? defaultArrowColor
                    if isDarkMode && isBlackColor(arrowcolor) {
                        arrowcolor = "#FFFFFF"
                    }

                    let ax = dataSection["ax"] as? Double ?? -20
                    let ay = dataSection["ay"] as? Double ?? -20
                    let xanchor = dataSection["xanchor"] as? String ?? "center"
                    let yanchor = dataSection["yanchor"] as? String ?? "bottom"

                    var fontSize: Double = 15
                    var fontColor: String = defaultFontColor
                    var fontFamily: String = "Arial, sans-serif"

                    if let fontData = dataSection["font"] as? [String: Any] {
                        fontSize = fontData["size"] as? Double ?? 15
                        fontColor = fontData["color"] as? String ?? defaultFontColor
                        fontFamily = fontData["family"] as? String ?? "Arial, sans-serif"
                    }

                    if isDarkMode && isBlackColor(fontColor) {
                        fontColor = "#FFFFFF"
                    }
                    
                    let annotation = PlotAnnotation(
                        id: key,
                        title: title,
                        text: text,
                        x: x,
                        y: y,
                        xref: nil,  // Use default data coordinates
                        yref: nil,  // Use default data coordinates
                        showarrow: showarrow,
                        arrowhead: arrowhead,
                        arrowsize: arrowsize,
                        arrowwidth: arrowwidth,
                        arrowcolor: arrowcolor,
                        ax: ax,
                        ay: ay,
                        xanchor: xanchor,
                        yanchor: yanchor,
                        font: PlotFont(family: fontFamily, size: fontSize, color: fontColor)
                    )
                    annotations.append(annotation)
                    
                } else {
                    continue
                }
            } else {
                continue
            }
        }
        
        return annotations
    }


    /// Check if a color string represents black or very dark color
    private func isBlackColor(_ color: String) -> Bool {
        let normalized = color.lowercased().trimmingCharacters(in: .whitespaces)

        if normalized == "#000000" || normalized == "#000" || normalized == "black" {
            return true
        }

        if normalized.hasPrefix("#") {
            let hex = String(normalized.dropFirst()) // Remove #

            if hex.count == 6 {
                let rHex = String(hex.prefix(2))
                let gHex = String(hex.dropFirst(2).prefix(2))
                let bHex = String(hex.dropFirst(4).prefix(2))

                if let r = Int(rHex, radix: 16),
                   let g = Int(gHex, radix: 16),
                   let b = Int(bHex, radix: 16) {
                    return r < 30 && g < 30 && b < 30
                }
            }
            else if hex.count == 3 {
                let r = String(hex.prefix(1))
                let g = String(hex.dropFirst(1).prefix(1))
                let b = String(hex.dropFirst(2).prefix(1))

                let rHex = r + r  // Double the character (e.g., "F" -> "FF")
                let gHex = g + g
                let bHex = b + b

                if let rVal = Int(rHex, radix: 16),
                   let gVal = Int(gHex, radix: 16),
                   let bVal = Int(bHex, radix: 16) {
                    return rVal < 30 && gVal < 30 && bVal < 30
                }
            }
        }

        return false
    }


    private func createVolcanoConditionLabelAnnotations(_ settings: CurtainSettings, isDarkMode: Bool) -> [PlotAnnotation] {
        var conditionAnnotations: [PlotAnnotation] = []

        // Check if condition labels are enabled
        guard settings.volcanoConditionLabels.enabled else {
            return conditionAnnotations
        }

        let leftCondition = settings.volcanoConditionLabels.leftCondition
        let rightCondition = settings.volcanoConditionLabels.rightCondition

        // Validate that both conditions are not empty and are different from each other
        guard !leftCondition.isEmpty && !rightCondition.isEmpty else {
            return conditionAnnotations
        }

        guard leftCondition != rightCondition else {
            return conditionAnnotations
        }


        // Use dark mode appropriate color: if saved color is black, replace with white in dark mode
        let savedColor = settings.volcanoConditionLabels.fontColor
        let labelColor: String
        if isDarkMode && isBlackColor(savedColor) {
            labelColor = "#FFFFFF"  // Use white in dark mode for better contrast
        } else {
            labelColor = savedColor  // Use saved color
        }

        // Create left condition label
        let leftLabel = PlotAnnotation(
            id: "volcanoConditionLabel_left",
            title: "Left Condition Label",
            text: leftCondition,
            x: settings.volcanoConditionLabels.leftX,
            y: settings.volcanoConditionLabels.yPosition,
            xref: "paper",  // Use paper coordinates (0-1 range)
            yref: "paper",  // Use paper coordinates (0-1 range)
            showarrow: false,
            arrowhead: nil,
            arrowsize: nil,
            arrowwidth: nil,
            arrowcolor: nil,
            ax: nil,
            ay: nil,
            xanchor: "center",
            yanchor: "top",
            font: PlotFont(
                family: settings.plotFontFamily,
                size: Double(settings.volcanoConditionLabels.fontSize),
                color: labelColor
            )
        )
        conditionAnnotations.append(leftLabel)

        // Create right condition label
        let rightLabel = PlotAnnotation(
            id: "volcanoConditionLabel_right",
            title: "Right Condition Label",
            text: rightCondition,
            x: settings.volcanoConditionLabels.rightX,
            y: settings.volcanoConditionLabels.yPosition,
            xref: "paper",  // Use paper coordinates (0-1 range)
            yref: "paper",  // Use paper coordinates (0-1 range)
            showarrow: false,
            arrowhead: nil,
            arrowsize: nil,
            arrowwidth: nil,
            arrowcolor: nil,
            ax: nil,
            ay: nil,
            xanchor: "center",
            yanchor: "top",
            font: PlotFont(
                family: settings.plotFontFamily,
                size: Double(settings.volcanoConditionLabels.fontSize),
                color: labelColor
            )
        )
        conditionAnnotations.append(rightLabel)

        return conditionAnnotations
    }

    private func createDefaultPlotConfig() -> PlotConfig {
        return PlotConfig(
            responsive: true,
            displayModeBar: false,     // Android: always hidden
            editable: false,           // Android: disable Plotly editing
            scrollZoom: true,          // Android: enable scroll zoom
            doubleClick: "reset"       // Android: enable double-click reset
        )
    }
    
    
    private func generateVolcanoHtmlTemplate(plotJSON: String, editMode: Bool, isDarkMode: Bool) -> String {
        let backgroundColor = isDarkMode ? "#1C1C1E" : "#ffffff"
        let textColor = isDarkMode ? "#E0E0E0" : "#000000"

        do {
            let htmlTemplate = try WebTemplateLoader.shared.loadHTMLTemplate(named: "volcano-plot")
            var volcanoJS = try WebTemplateLoader.shared.loadJavaScript(named: "volcano-plot")

            volcanoJS = volcanoJS.replacingOccurrences(of: "{{PLOT_DATA}}", with: plotJSON)
            volcanoJS = volcanoJS.replacingOccurrences(of: "{{EDIT_MODE}}", with: editMode ? "true" : "false")

            let substitutions: [String: String] = [
                "BACKGROUND_COLOR": backgroundColor,
                "TEXT_COLOR": textColor,
                "PLOTLY_JS": getInlinePlotlyJS(),
                "VOLCANO_PLOT_JS": volcanoJS
            ]

            return WebTemplateLoader.shared.render(template: htmlTemplate, substitutions: substitutions)
        } catch {
            return generateErrorHtml("Failed to load volcano plot template: \(error.localizedDescription)")
        }
    }
    
    private func getInlinePlotlyJS() -> String {
        // Try to read plotly.min.js from the bundle
        if let plotlyURL = Bundle.main.url(forResource: "plotly.min", withExtension: "js"),
           let plotlyContent = try? String(contentsOf: plotlyURL, encoding: .utf8) {
            return plotlyContent
        } else {
            // Return a minimal fallback that will trigger the error handler
            return "console.error('Plotly.js not found in bundle');"
        }
    }
    
    /// Get marker size for a specific group, checking markerSizeMap first, then falling back to default
    private func getMarkerSize(for groupName: String, settings: CurtainSettings) -> Double {
        // Check if there's a custom size for this group in markerSizeMap
        if let customSize = settings.markerSizeMap[groupName] as? Int {
            return Double(customSize)
        } else if let customSize = settings.markerSizeMap[groupName] as? Double {
            return customSize
        }

        // Fall back to default marker size
        return settings.scatterPlotMarkerSize
    }

    /// Reorder traces according to volcanoTraceOrder setting (matches Angular sortGraphDataByOrder)
    private func reorderTraces(_ traces: [PlotTrace], accordingTo order: [String]) -> [PlotTrace] {

        // Create a dictionary for quick lookup
        var tracesByName: [String: PlotTrace] = [:]
        for trace in traces {
            tracesByName[trace.name] = trace
        }

        var reorderedTraces: [PlotTrace] = []

        // Add traces in the specified order (matching Angular's orderedTraces)
        for traceName in order {
            if let trace = tracesByName[traceName] {
                reorderedTraces.append(trace)
                tracesByName.removeValue(forKey: traceName)
            } else {
            }
        }

        // Add any remaining traces that weren't in the order (matching Angular's unorderedTraces)
        for trace in traces {
            if tracesByName[trace.name] != nil {
                reorderedTraces.append(trace)
            }
        }

        return reorderedTraces
    }

    private func generateErrorHtml(_ message: String) -> String {
        do {
            let htmlTemplate = try WebTemplateLoader.shared.loadHTMLTemplate(named: "error")
            let substitutions: [String: String] = [
                "ERROR_TITLE": "Plot Generation Error",
                "ERROR_MESSAGE": message
            ]
            return WebTemplateLoader.shared.render(template: htmlTemplate, substitutions: substitutions)
        } catch {
            return """
            <!DOCTYPE html>
            <html><body><div style="text-align:center;padding:40px;"><h3>Error</h3><p>\(message)</p></div></body></html>
            """
        }
    }
}

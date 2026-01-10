import Foundation
import UIKit

class PlotlyChartGenerator {
    private let curtainDataService: CurtainDataService?
    private let volcanoPlotDataService: VolcanoPlotDataService

    private(set) var lastGeneratedTraceNames: [String] = []
    private(set) var lastGeneratedTraces: [PlotTrace] = []

    init(curtainDataService: CurtainDataService? = nil) {
        self.curtainDataService = curtainDataService
        self.volcanoPlotDataService = VolcanoPlotDataService()
    }
    
    func createVolcanoPlotHtml(context: PlotGenerationContext) async -> String {
        let volcanoResult = await volcanoPlotDataService.processVolcanoData(
            curtainData: convertToAppData(context.data),
            settings: context.settings
        )
        
        let plotData = createCompatiblePlotData(volcanoResult, context: context)
        
        do {
            let plotJSON = try plotData.toJSON()
            return generateVolcanoHtmlTemplate(plotJSON: plotJSON, editMode: context.editMode, isDarkMode: context.isDarkMode)
        } catch {
            return generateErrorHtml("Failed to generate volcano plot data")
        }
    }
    
    private func convertToAppData(_ data: CurtainData) -> AppData {
        let appData = AppData()
        appData.dataMap = data.selectionsMap
        appData.rawForm = RawForm(
            primaryIDs: data.rawForm.primaryIDs,
            samples: data.rawForm.samples,
            log2: data.rawForm.log2
        )
        appData.differentialForm = DifferentialForm(
            primaryIDs: data.differentialForm.primaryIDs,
            geneNames: data.differentialForm.geneNames,
            foldChange: data.differentialForm.foldChange,
            transformFC: data.differentialForm.transformFC,
            significant: data.differentialForm.significant,
            transformSignificant: data.differentialForm.transformSignificant,
            comparison: data.differentialForm.comparison,
            comparisonSelect: data.differentialForm.comparisonSelect,
            reverseFoldChange: data.differentialForm.reverseFoldChange
        )
        appData.selectedMap = data.selectedMap ?? [:]
        if let rawString = data.raw {
            appData.raw = InputFile(originalFile: rawString)
        }
        return appData
    }
    
    private func createCompatiblePlotData(_ volcanoResult: VolcanoProcessResult, context: PlotGenerationContext) -> PlotData {
        let traces = createCompatibleTraces(volcanoResult.jsonData, settings: context.settings, colorMap: volcanoResult.colorMap, selectionsName: context.data.selectionsName ?? [])
        let layout = createCompatibleLayout(volcanoResult, context: context)
        let config = createDefaultPlotConfig()
        
        return PlotData(traces: traces, layout: layout, config: config)
    }
    
    private func createCompatibleTraces(_ jsonData: [[String: Any]], settings: CurtainSettings, colorMap: [String: String], selectionsName: [String]) -> [PlotTrace] {
        var selectionGroups: [String: (color: String, points: [DataPoint])] = [:]

        for dataPoint in jsonData {
            let point = DataPoint(
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

            for (index, selectionName) in point.selections.enumerated() {
                let selectionColor = index < point.colors.count ? point.colors[index] : "#808080"

                if selectionGroups[selectionName] == nil {
                    selectionGroups[selectionName] = (color: selectionColor, points: [])
                }
                selectionGroups[selectionName]?.points.append(point)
            }
        }

        var traces: [PlotTrace] = []
        let allGroupNames = Array(selectionGroups.keys)

        // 1. Add Background trace first (drawn at the bottom)
        if let groupData = selectionGroups["Background"] {
            let trace = createCompatibleTrace(
                dataPoints: groupData.points,
                name: "Background",
                color: groupData.color,
                markerSize: getMarkerSize(for: "Background", settings: settings)
            )
            traces.append(trace)
        }

        // 2. Add Significant/Other traces (drawn above Background)
        let significantNames = allGroupNames.filter {
            return ($0 == "Other" || $0.contains("P-value") || $0.contains("FC")) && $0 != "Background"
        }.sorted()

        for selectionName in significantNames {
            guard let groupData = selectionGroups[selectionName] else { continue }
            let trace = createCompatibleTrace(
                dataPoints: groupData.points,
                name: selectionName,
                color: groupData.color,
                markerSize: getMarkerSize(for: selectionName, settings: settings)
            )
            traces.append(trace)
        }

        // 3. Add User Selections (drawn on top of everything)
        let userSelectionNames: [String]
        if !selectionsName.isEmpty {
            userSelectionNames = selectionsName.filter { selectionGroups[$0] != nil }
        } else {
            userSelectionNames = allGroupNames.filter {
                return $0 != "Background" &&
                       !significantNames.contains($0)
            }.sorted()
        }

        for selectionName in userSelectionNames {
            guard let groupData = selectionGroups[selectionName] else { continue }
            let trace = createCompatibleTrace(
                dataPoints: groupData.points,
                name: selectionName,
                color: groupData.color,
                markerSize: getMarkerSize(for: selectionName, settings: settings)
            )
            traces.append(trace)
        }

        // Apply custom trace order if specified
        let sortedTraces = reorderTraces(traces, accordingTo: settings.volcanoTraceOrder)
        
        lastGeneratedTraceNames = sortedTraces.map { $0.name }
        lastGeneratedTraces = sortedTraces
        return sortedTraces
    }
    
    private func createCompatibleTrace(dataPoints: [DataPoint], name: String, color: String, markerSize: Double) -> PlotTrace {
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
                "pValue": pow(10, -point.y),
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
    
    private func createCompatibleLayout(_ volcanoResult: VolcanoProcessResult, context: PlotGenerationContext) -> PlotLayout {
        let settings = context.settings
        let volcanoAxis = volcanoResult.updatedVolcanoAxis
        let textColor = context.isDarkMode ? "#E0E0E0" : "#000000"
        let gridColor = context.isDarkMode ? "#555555" : "#e0e0e0"

        let title = PlotTitle(
            text: settings.volcanoPlotTitle,
            font: PlotFont(family: settings.plotFontFamily, size: 16, color: textColor)
        )

        let xaxisZerolineColor: String
        if settings.volcanoPlotYaxisPosition.contains("middle") {
            xaxisZerolineColor = context.isDarkMode ? "#E0E0E0" : "#000000"
        } else {
            xaxisZerolineColor = "rgba(0,0,0,0)"
        }

        let xaxis = PlotAxis(
            title: PlotAxisTitle(text: volcanoAxis.x, font: PlotFont(family: settings.plotFontFamily, size: 12, color: textColor)),
            zeroline: nil,
            zerolinecolor: xaxisZerolineColor,
            gridcolor: gridColor,
            linecolor: textColor,
            range: [volcanoAxis.minX ?? -3.0, volcanoAxis.maxX ?? 3.0],
            font: PlotFont(family: settings.plotFontFamily, size: 10, color: textColor),
            dtick: volcanoAxis.dtickX,
            ticklen: volcanoAxis.ticklenX,
            showgrid: settings.volcanoPlotGrid["x"] ?? true,
            automargin: true
        )

        let yaxis = PlotAxis(
            title: PlotAxisTitle(text: volcanoAxis.y, font: PlotFont(family: settings.plotFontFamily, size: 12, color: textColor)),
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
            automargin: true,
            side: nil
        )

        var shapes = createCompatibleThresholdShapes(settings, volcanoAxis)

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
        }
        
        var annotations = convertTextAnnotations(settings.textAnnotation, isDarkMode: context.isDarkMode)
        let conditionLabelAnnotations = createVolcanoConditionLabelAnnotations(settings, isDarkMode: context.isDarkMode)
        annotations.append(contentsOf: conditionLabelAnnotations)

        let margin = buildMarginFromSettings(settings)

        return PlotLayout(
            title: title,
            xaxis: xaxis,
            yaxis: yaxis,
            hovermode: "closest",
            showlegend: true,
            plot_bgcolor: "rgba(0,0,0,0)",
            paper_bgcolor: "rgba(0,0,0,0)",
            font: PlotFont(family: settings.plotFontFamily, size: 12, color: textColor),
            shapes: shapes,
            annotations: annotations,
            legend: PlotLegend(orientation: "h", x: 0.5, xanchor: "center", y: settings.volcanoPlotLegendY ?? -0.15, yanchor: "top"),
            margin: margin
        )
    }
    
    private func buildMarginFromSettings(_ settings: CurtainSettings) -> PlotMargin? {
        let margin = settings.volcanoPlotDimension.margin
        if margin.left != nil || margin.right != nil || margin.bottom != nil || margin.top != nil {
            return PlotMargin(
                left: margin.left ?? 80,
                right: margin.right ?? 80,
                top: margin.top ?? 100,
                bottom: margin.bottom ?? 120
            )
        }
        return nil
    }

    private func createCompatibleThresholdShapes(_ settings: CurtainSettings, _ volcanoAxis: VolcanoAxis) -> [PlotShape] {
        let maxY = volcanoAxis.maxY ?? 5.0
        let minX = volcanoAxis.minX ?? -3.0
        let maxX = volcanoAxis.maxX ?? 3.0
        let pValueThreshold = -log10(settings.pCutoff)
        
        return [
            PlotShape(type: "line", x0: -settings.log2FCCutoff, x1: -settings.log2FCCutoff, y0: 0, y1: maxY, xref: "x", yref: "y", line: PlotLine(color: "rgb(21,4,4)", width: 1, dash: "dash"), isYAxisLine: nil),
            PlotShape(type: "line", x0: settings.log2FCCutoff, x1: settings.log2FCCutoff, y0: 0, y1: maxY, xref: "x", yref: "y", line: PlotLine(color: "rgb(21,4,4)", width: 1, dash: "dash"), isYAxisLine: nil),
            PlotShape(type: "line", x0: minX, x1: maxX, y0: pValueThreshold, y1: pValueThreshold, xref: "x", yref: "y", line: PlotLine(color: "rgb(21,4,4)", width: 1, dash: "dash"), isYAxisLine: nil)
        ]
    }
    
    private struct DataPoint {
        let x: Double
        let y: Double
        let id: String
        let gene: String
        let comparison: String
        let selections: [String]
        let colors: [String]
        let color: String
        let customText: String?
    }
    
    private func convertTextAnnotations(_ textAnnotations: [String: Any], isDarkMode: Bool) -> [PlotAnnotation] {
        var annotations: [PlotAnnotation] = []
        let defaultFontColor = isDarkMode ? "#FFFFFF" : "#000000"
        let defaultArrowColor = isDarkMode ? "#FFFFFF" : "#000000"

        for (key, value) in textAnnotations {
            if let annotationData = value as? [String: Any], let dataSection = annotationData["data"] as? [String: Any] {
                guard let text = dataSection["text"] as? String, let x = dataSection["x"] as? Double, let y = dataSection["y"] as? Double else { continue }
                let title = annotationData["title"] as? String ?? key
                let showarrow = dataSection["showarrow"] as? Bool ?? true
                let arrowhead = dataSection["arrowhead"] as? Int ?? 1
                let arrowsize = dataSection["arrowsize"] as? Double ?? 1.0
                let arrowwidth = dataSection["arrowwidth"] as? Double ?? 1.0
                var arrowcolor = dataSection["arrowcolor"] as? String ?? defaultArrowColor
                if isDarkMode && isBlackColor(arrowcolor) { arrowcolor = "#FFFFFF" }
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
                if isDarkMode && isBlackColor(fontColor) { fontColor = "#FFFFFF" }
                let annotation = PlotAnnotation(id: key, title: title, text: text, x: x, y: y, xref: nil, yref: nil, showarrow: showarrow, arrowhead: arrowhead, arrowsize: arrowsize, arrowwidth: arrowwidth, arrowcolor: arrowcolor, ax: ax, ay: ay, xanchor: xanchor, yanchor: yanchor, font: PlotFont(family: fontFamily, size: fontSize, color: fontColor))
                annotations.append(annotation)
            }
        }
        return annotations
    }

    private func isBlackColor(_ color: String) -> Bool {
        let normalized = color.lowercased().trimmingCharacters(in: .whitespaces)
        if normalized == "#000000" || normalized == "#000" || normalized == "black" { return true }
        if normalized.hasPrefix("#") {
            let hex = String(normalized.dropFirst())
            if hex.count == 6 {
                let r = Int(hex.prefix(2), radix: 16) ?? 255
                let g = Int(hex.dropFirst(2).prefix(2), radix: 16) ?? 255
                let b = Int(hex.dropFirst(4).prefix(2), radix: 16) ?? 255
                return r < 30 && g < 30 && b < 30
            } else if hex.count == 3 {
                let r = Int(String(repeating: String(hex.prefix(1)), count: 2), radix: 16) ?? 255
                let g = Int(String(repeating: String(hex.dropFirst(1).prefix(1)), count: 2), radix: 16) ?? 255
                let b = Int(String(repeating: String(hex.dropFirst(2).prefix(1)), count: 2), radix: 16) ?? 255
                return r < 30 && g < 30 && b < 30
            }
        }
        return false
    }

    private func createVolcanoConditionLabelAnnotations(_ settings: CurtainSettings, isDarkMode: Bool) -> [PlotAnnotation] {
        guard settings.volcanoConditionLabels.enabled else { return [] }
        let leftCondition = settings.volcanoConditionLabels.leftCondition
        let rightCondition = settings.volcanoConditionLabels.rightCondition
        guard !leftCondition.isEmpty && !rightCondition.isEmpty, leftCondition != rightCondition else { return [] }
        let savedColor = settings.volcanoConditionLabels.fontColor
        let labelColor = (isDarkMode && isBlackColor(savedColor)) ? "#FFFFFF" : savedColor
        let leftLabel = PlotAnnotation(id: "volcanoConditionLabel_left", title: "Left Condition Label", text: leftCondition, x: settings.volcanoConditionLabels.leftX, y: settings.volcanoConditionLabels.yPosition, xref: "paper", yref: "paper", showarrow: false, arrowhead: nil, arrowsize: nil, arrowwidth: nil, arrowcolor: nil, ax: nil, ay: nil, xanchor: "center", yanchor: "top", font: PlotFont(family: settings.plotFontFamily, size: Double(settings.volcanoConditionLabels.fontSize), color: labelColor))
        let rightLabel = PlotAnnotation(id: "volcanoConditionLabel_right", title: "Right Condition Label", text: rightCondition, x: settings.volcanoConditionLabels.rightX, y: settings.volcanoConditionLabels.yPosition, xref: "paper", yref: "paper", showarrow: false, arrowhead: nil, arrowsize: nil, arrowwidth: nil, arrowcolor: nil, ax: nil, ay: nil, xanchor: "center", yanchor: "top", font: PlotFont(family: settings.plotFontFamily, size: Double(settings.volcanoConditionLabels.fontSize), color: labelColor))
        return [leftLabel, rightLabel]
    }

    private func createDefaultPlotConfig() -> PlotConfig {
        return PlotConfig(responsive: true, displayModeBar: false, editable: false, scrollZoom: true, doubleClick: "reset")
    }
    
    private func generateVolcanoHtmlTemplate(plotJSON: String, editMode: Bool, isDarkMode: Bool) -> String {
        let backgroundColor = isDarkMode ? "#1C1C1E" : "#ffffff"
        let textColor = isDarkMode ? "#E0E0E0" : "#000000"
        do {
            let htmlTemplate = try WebTemplateLoader.shared.loadHTMLTemplate(named: "volcano-plot")
            var volcanoJS = try WebTemplateLoader.shared.loadJavaScript(named: "volcano-plot")
            volcanoJS = volcanoJS.replacingOccurrences(of: "{{PLOT_DATA}}", with: plotJSON)
            volcanoJS = volcanoJS.replacingOccurrences(of: "{{EDIT_MODE}}", with: editMode ? "true" : "false")
            let substitutions = ["BACKGROUND_COLOR": backgroundColor, "TEXT_COLOR": textColor, "PLOTLY_JS": getInlinePlotlyJS(), "VOLCANO_PLOT_JS": volcanoJS]
            return WebTemplateLoader.shared.render(template: htmlTemplate, substitutions: substitutions)
        } catch {
            return generateErrorHtml("Failed to load volcano plot template: \(error.localizedDescription)")
        }
    }
    
    private func getInlinePlotlyJS() -> String {
        if let plotlyURL = Bundle.main.url(forResource: "plotly.min", withExtension: "js"), let plotlyContent = try? String(contentsOf: plotlyURL, encoding: .utf8) {
            return plotlyContent
        } else {
            return "console.error('Plotly.js not found in bundle');"
        }
    }
    
    private func getMarkerSize(for groupName: String, settings: CurtainSettings) -> Double {
        if let customSize = settings.markerSizeMap[groupName] as? Int { return Double(customSize) }
        else if let customSize = settings.markerSizeMap[groupName] as? Double { return customSize }
        return settings.scatterPlotMarkerSize
    }

    private func reorderTraces(_ traces: [PlotTrace], accordingTo order: [String]) -> [PlotTrace] {
        if order.isEmpty {
            return traces
        }

        var tracesByName: [String: PlotTrace] = [:]
        for trace in traces { tracesByName[trace.name] = trace }

        var reorderedTraces: [PlotTrace] = []
        for traceName in order {
            if let trace = tracesByName[traceName] {
                reorderedTraces.append(trace)
                tracesByName.removeValue(forKey: traceName)
            }
        }

        for trace in traces {
            if tracesByName[trace.name] != nil { reorderedTraces.append(trace) }
        }

        return reorderedTraces
    }

    private func generateErrorHtml(_ message: String) -> String {
        do {
            let htmlTemplate = try WebTemplateLoader.shared.loadHTMLTemplate(named: "error")
            let substitutions = ["ERROR_TITLE": "Plot Generation Error", "ERROR_MESSAGE": message]
            return WebTemplateLoader.shared.render(template: htmlTemplate, substitutions: substitutions)
        } catch {
            return "<!DOCTYPE html><html><body><div style=\"text-align:center;padding:40px;\"><h3>Error</h3><p>\(message)</p></div></body></html>"
        }
    }
}

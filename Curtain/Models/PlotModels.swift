//
//  PlotModels.swift
//  Curtain
//
//  Created by Toan Phung on 02/08/2025.
//

import Foundation

// MARK: - Core Plot Data Models

struct PlotData {
    let traces: [PlotTrace]
    let layout: PlotLayout
    let config: PlotConfig
}

struct PlotTrace {
    let x: Any  // Can be [Double] or [String] for categorical data
    let y: [Double]
    let mode: String
    let type: String
    let name: String
    let marker: PlotMarker?
    let text: [String]?
    let textposition: String?  // "none" to hide text on bars, but keep for hover
    let hovertemplate: String?
    let customdata: [[String: Any]]?
    let error_y: PlotErrorBar?

    // Violin plot specific properties (Android-compatible)
    let violinmode: String?
    let box_visible: Bool?
    let meanline_visible: Bool?
    let points: String?
    let pointpos: Double?
    let jitter: Double?
    let fillcolor: String?
    let line_color: String?

    // Additional Android violin plot properties
    let spanmode: String?      // "soft" for smooth kernel density estimation
    let bandwidth: String?     // "auto" for automatic bandwidth selection
    let scalemode: String?     // "width" to scale violin width consistently
    let selected: PlotMarker?  // Selection state marker
    let unselected: PlotMarker? // Unselected state marker
    
    init(x: Any, y: [Double], mode: String, type: String, name: String, marker: PlotMarker? = nil, text: [String]? = nil, textposition: String? = nil, hovertemplate: String? = nil, customdata: [[String: Any]]? = nil, error_y: PlotErrorBar? = nil, violinmode: String? = nil, box_visible: Bool? = nil, meanline_visible: Bool? = nil, points: String? = nil, pointpos: Double? = nil, jitter: Double? = nil, fillcolor: String? = nil, line_color: String? = nil, spanmode: String? = nil, bandwidth: String? = nil, scalemode: String? = nil, selected: PlotMarker? = nil, unselected: PlotMarker? = nil) {
        self.x = x
        self.y = y
        self.mode = mode
        self.type = type
        self.name = name
        self.marker = marker
        self.text = text
        self.textposition = textposition
        self.hovertemplate = hovertemplate
        self.customdata = customdata
        self.error_y = error_y
        self.violinmode = violinmode
        self.box_visible = box_visible
        self.meanline_visible = meanline_visible
        self.points = points
        self.pointpos = pointpos
        self.jitter = jitter
        self.fillcolor = fillcolor
        self.line_color = line_color
        self.spanmode = spanmode
        self.bandwidth = bandwidth
        self.scalemode = scalemode
        self.selected = selected
        self.unselected = unselected
    }
}

struct PlotMarker {
    let color: Any // Can be string or array
    let size: Any // Can be number or array
    let symbol: String?
    let line: PlotLine?
    let opacity: Double?
    
    init(color: Any, size: Any, symbol: String? = nil, line: PlotLine? = nil, opacity: Double? = nil) {
        self.color = color
        self.size = size
        self.symbol = symbol
        self.line = line
        self.opacity = opacity
    }
}

struct PlotLine {
    let color: String
    let width: Double
    let dash: String?
}

struct PlotErrorBar {
    let type: String
    let array: [Double]
    let visible: Bool
    let color: String
    let thickness: Double
    let width: Double
}

struct PlotLayout {
    let title: PlotTitle?
    let xaxis: PlotAxis
    let yaxis: PlotAxis
    let hovermode: String?
    let showlegend: Bool
    let plot_bgcolor: String?
    let paper_bgcolor: String?
    let font: PlotFont?
    let shapes: [PlotShape]?
    let annotations: [PlotAnnotation]?
    let legend: PlotLegend?
    let margin: PlotMargin?
    let width: Int?  // Optional plot width (for column size feature)
    let height: Int?  // Optional plot height

    init(title: PlotTitle? = nil, xaxis: PlotAxis, yaxis: PlotAxis, hovermode: String? = nil, showlegend: Bool, plot_bgcolor: String? = nil, paper_bgcolor: String? = nil, font: PlotFont? = nil, shapes: [PlotShape]? = nil, annotations: [PlotAnnotation]? = nil, legend: PlotLegend? = nil, margin: PlotMargin? = nil, width: Int? = nil, height: Int? = nil) {
        self.title = title
        self.xaxis = xaxis
        self.yaxis = yaxis
        self.hovermode = hovermode
        self.showlegend = showlegend
        self.plot_bgcolor = plot_bgcolor
        self.paper_bgcolor = paper_bgcolor
        self.font = font
        self.shapes = shapes
        self.annotations = annotations
        self.legend = legend
        self.margin = margin
        self.width = width
        self.height = height
    }
}

struct PlotTitle {
    let text: String
    let font: PlotFont?
}

struct PlotAxis {
    let title: PlotAxisTitle
    let zeroline: Bool?
    let zerolinecolor: String?
    let gridcolor: String?
    let range: [Double]?
    let font: PlotFont?
    let dtick: Double?
    let ticklen: Int?
    let showgrid: Bool?
    let tickangle: Int?
    let type: String?
    let automargin: Bool?
    let tickmode: String?
    let tickvals: [Double]?
    let ticktext: [String]?
    let side: String?  // Y-axis position: "left" or "right" (middle uses default behavior)

    init(title: PlotAxisTitle, zeroline: Bool? = nil, zerolinecolor: String? = nil, gridcolor: String? = nil, range: [Double]? = nil, font: PlotFont? = nil, dtick: Double? = nil, ticklen: Int? = nil, showgrid: Bool? = nil, tickangle: Int? = nil, type: String? = nil, automargin: Bool? = nil, tickmode: String? = nil, tickvals: [Double]? = nil, ticktext: [String]? = nil, side: String? = nil) {
        self.title = title
        self.zeroline = zeroline
        self.zerolinecolor = zerolinecolor
        self.gridcolor = gridcolor
        self.range = range
        self.font = font
        self.dtick = dtick
        self.ticklen = ticklen
        self.showgrid = showgrid
        self.tickangle = tickangle
        self.type = type
        self.automargin = automargin
        self.tickmode = tickmode
        self.tickvals = tickvals
        self.ticktext = ticktext
        self.side = side
    }
}

struct PlotAxisTitle {
    let text: String
    let font: PlotFont?
}

struct PlotFont {
    let family: String
    let size: Double?
    let color: String?
    let dash: String?
    
    init(family: String, size: Double? = nil, color: String? = nil, dash: String? = nil) {
        self.family = family
        self.size = size
        self.color = color
        self.dash = dash
    }
}

struct PlotShape {
    let type: String
    let x0: Double?
    let x1: Double?
    let y0: Double?
    let y1: Double?
    let xref: String?
    let yref: String?
    let line: PlotLine
}

struct PlotAnnotation {
    let id: String
    let title: String
    let text: String
    let x: Double
    let y: Double
    let xref: String?  // "x" for data coordinates (default), "paper" for paper coordinates
    let yref: String?  // "y" for data coordinates (default), "paper" for paper coordinates
    let showarrow: Bool
    let arrowhead: Int?
    let arrowsize: Double?
    let arrowwidth: Double?
    let arrowcolor: String?
    let ax: Double?
    let ay: Double?
    let xanchor: String?
    let yanchor: String?
    let font: PlotFont?
}

struct PlotConfig {
    let responsive: Bool
    let displayModeBar: Bool
    let editable: Bool
    let scrollZoom: Bool
    let doubleClick: String
}

struct PlotLegend {
    let orientation: String // "v" for vertical, "h" for horizontal
    let x: Double
    let xanchor: String // "left", "center", "right"
    let y: Double
    let yanchor: String // "top", "middle", "bottom"
}

struct PlotMargin {
    let left: Int
    let right: Int
    let top: Int
    let bottom: Int
}

// MARK: - Volcano Plot Specific Models

struct VolcanoPlotData {
    let proteins: [ProteinPoint]
    let significantThresholds: SignificanceThresholds
    let annotations: [PlotAnnotation]
    let settings: CurtainSettings
    let title: String
}

struct ProteinPoint {
    let id: String
    let primaryID: String
    let proteinName: String?
    let geneNames: String?
    let log2FC: Double
    let pValue: Double
    let isSignificant: Bool
    let isSelected: Bool
    let condition: String?
    let color: String
    let customData: [String: Any]
    
    var negLog10PValue: Double {
        // Use pre-calculated plot Y coordinate if available, otherwise calculate it
        if let plotY = customData["plotYCoordinate"] as? Double {
            return plotY
        }
        return -log10(max(pValue, 1e-300)) // Prevent log(0)
    }
    
    var significance: ProteinSignificance {
        let fcSignificant = abs(log2FC) >= significantThresholds.log2FCCutoff
        let pValueSignificant = pValue <= significantThresholds.pCutoff
        
        if fcSignificant && pValueSignificant {
            return .significant
        } else if fcSignificant || pValueSignificant {
            return .borderline
        } else {
            return .notSignificant
        }
    }
    
    private var significantThresholds: SignificanceThresholds {
        return SignificanceThresholds(pCutoff: 0.05, log2FCCutoff: 0.6)
    }
}

enum ProteinSignificance {
    case significant
    case borderline
    case notSignificant
}

struct SignificanceThresholds {
    let pCutoff: Double
    let log2FCCutoff: Double
}

// MARK: - Bar Chart Models

struct BarChartData {
    let proteins: [String]
    let conditions: [String]
    let values: [[Double]] // proteins x conditions
    let errorBars: [[Double]]? // For average charts
    let peptideCounts: [[Int]]? // For heatmap overlay
    let settings: CurtainSettings
}

struct ViolinPlotData {
    let proteins: [String]
    let conditions: [String]
    let distributionData: [[[Double]]] // proteins x conditions x samples
    let settings: CurtainSettings
}

// MARK: - Selection and Interaction Models

struct SelectionOperation {
    let id: String
    let name: String
    let proteinIds: Set<String>
    let color: String
    let isActive: Bool
}

struct PointClickData {
    let proteinId: String
    let screenX: Double
    let screenY: Double
    let plotX: Double
    let plotY: Double
    let nearbyProteins: [String]
}

struct AnnotationEditData {
    let annotationId: String
    let newText: String?
    let newPosition: CGPoint?
}

// MARK: - Plot Generation Context

struct PlotGenerationContext {
    let data: CurtainData
    let settings: CurtainSettings
    let selections: [SelectionOperation]
    let searchFilter: String?
    let editMode: Bool
    let isDarkMode: Bool  // Add dark mode detection

    var filteredProteins: [ProteinPoint] {
        var proteins = convertToProteinPoints()
        
        // Apply search filter
        if let searchFilter = searchFilter, !searchFilter.isEmpty {
            proteins = proteins.filter { protein in
                protein.primaryID.localizedCaseInsensitiveContains(searchFilter) ||
                protein.proteinName?.localizedCaseInsensitiveContains(searchFilter) == true ||
                protein.geneNames?.localizedCaseInsensitiveContains(searchFilter) == true
            }
        }
        
        // Apply selections
        for selection in selections where selection.isActive {
            for i in proteins.indices {
                if selection.proteinIds.contains(proteins[i].id) {
                    proteins[i] = ProteinPoint(
                        id: proteins[i].id,
                        primaryID: proteins[i].primaryID,
                        proteinName: proteins[i].proteinName,
                        geneNames: proteins[i].geneNames,
                        log2FC: proteins[i].log2FC,
                        pValue: proteins[i].pValue,
                        isSignificant: proteins[i].isSignificant,
                        isSelected: true,
                        condition: proteins[i].condition,
                        color: selection.color,
                        customData: proteins[i].customData
                    )
                }
            }
        }
        
        return proteins
    }
    
    private func convertToProteinPoints() -> [ProteinPoint] {
        // Use processed differential data (like Android) instead of raw proteomicsData
        guard let processedData = data.extraData?.data?.dataMap as? [String: Any],
              let differentialData = processedData["processedDifferentialData"] as? [[String: Any]] else {
            print("❌ PlotGenerationContext: No processedDifferentialData found, falling back to proteomicsData")
            return convertFromProteomicsData()
        }
        
        print("🔍 PlotGenerationContext: convertToProteinPoints using processedDifferentialData with \(differentialData.count) entries")
        
        // Extract values using user-specified field mapping from differential form
        let diffForm = data.differentialForm
        let fcColumn = diffForm.foldChange
        let sigColumn = diffForm.significant
        let idColumn = diffForm.primaryIDs
        let geneColumn = diffForm.geneNames
        
        print("🔍 PlotGenerationContext: DifferentialForm configuration - FC: '\(fcColumn)', Sig: '\(sigColumn)', ID: '\(idColumn)', Gene: '\(geneColumn)'")
        
        var processedCount = 0
        let proteins = differentialData.compactMap { proteinData -> ProteinPoint? in
            
            // CRITICAL: User must specify these columns, don't use defaults that might not exist
            guard !fcColumn.isEmpty && !sigColumn.isEmpty && !idColumn.isEmpty else {
                if processedCount < 3 {
                    print("🔍 PlotGenerationContext: Skipping protein \\(key) - required columns not specified by user")
                    print("🔍 PlotGenerationContext: FC=\\(fcColumn), Sig=\\(sigColumn), ID=\\(idColumn)")
                }
                return nil
            }
            
            let log2FC = proteinData[fcColumn] as? Double ?? 0.0
            let pValue = proteinData[sigColumn] as? Double ?? 1.0
            
            // Debug first few proteins to understand data structure
            if processedCount < 3 {
                print("🔍 PlotGenerationContext: Protein data keys: \(proteinData.keys.sorted())")
                print("🔍 PlotGenerationContext: Protein foldChange: \(proteinData[fcColumn] ?? "nil")")
                print("🔍 PlotGenerationContext: Protein pValue: \(proteinData[sigColumn] ?? "nil")")
                print("🔍 PlotGenerationContext: Protein geneNames: \(proteinData[geneColumn] ?? "nil")")
                print("🔍 PlotGenerationContext: Protein primaryID: \(proteinData[idColumn] ?? "nil")")
            }
            
            // Validate significance value - handle both raw p-values and transformed (-log10) values
            let isValidSignificance: Bool
            if data.differentialForm.transformSignificant {
                // For transformed values, expect -log10(p-value) which should be >= 0
                isValidSignificance = pValue >= 0
            } else {
                // For raw p-values, expect 0 < p <= 1
                isValidSignificance = pValue > 0 && pValue <= 1
            }
            
            guard isValidSignificance else { 
                if processedCount < 3 {
                    print("🔍 PlotGenerationContext: Protein invalid pValue: \(pValue) (transformSignificant: \(data.differentialForm.transformSignificant))")
                }
                return nil 
            }
            
            processedCount += 1
            
            let proteinName = proteinData["proteinName"] as? String ??
                             proteinData["protein_names"] as? String
            
            let geneNames = proteinData[geneColumn] as? String
            
            let thresholds = SignificanceThresholds(
                pCutoff: settings.pCutoff,
                log2FCCutoff: settings.log2FCCutoff
            )
            
            let isSignificant = abs(log2FC) >= thresholds.log2FCCutoff && 
                               pValue <= thresholds.pCutoff
            
            // Default color assignment
            let defaultColor = isSignificant ? "#d32f2f" : "#cccccc"
            
            // Extract primary ID using ONLY user-specified column
            let primaryID = proteinData[idColumn] as? String ?? ""
            guard !primaryID.isEmpty else {
                if processedCount < 3 {
                    print("🔍 PlotGenerationContext: Skipping protein - no primary ID in column '\(idColumn)'")
                }
                return nil
            }

            // Store the correct values based on transformation status
            let finalPValue: Double
            let plotYCoordinate: Double
            
            if data.differentialForm.transformSignificant {
                // pValue is already -log10 transformed, use it directly as plot Y coordinate
                finalPValue = pow(10, -pValue) // Convert back to raw p-value for compatibility
                plotYCoordinate = pValue // This is already -log10(p-value)
            } else {
                // pValue is raw, store as-is
                finalPValue = pValue
                plotYCoordinate = -log10(max(pValue, 1e-300)) // Apply transformation for plot coordinates
            }
            
            return ProteinPoint(
                id: primaryID, // Use primary ID as the main ID (like Android)
                primaryID: primaryID,
                proteinName: proteinName,
                geneNames: geneNames,
                log2FC: log2FC,
                pValue: finalPValue,
                isSignificant: isSignificant,
                isSelected: false,
                condition: proteinData["condition"] as? String,
                color: defaultColor,
                customData: proteinData.merging(["plotYCoordinate": plotYCoordinate], uniquingKeysWith: { _, new in new })
            )
        }
        
        print("🔍 PlotGenerationContext: Successfully converted \(proteins.count) proteins from \(differentialData.count) total")
        return proteins
    }
    
    // Fallback method using proteomicsData (original implementation)
    private func convertFromProteomicsData() -> [ProteinPoint] {
        print("🔍 PlotGenerationContext: convertFromProteomicsData called with \(data.proteomicsData.count) proteins")
        
        var processedCount = 0
        let proteins = data.proteomicsData.compactMap { key, value -> ProteinPoint? in
            guard let proteinData = value as? [String: Any] else { 
                print("🔍 PlotGenerationContext: Protein \(key) data is not dictionary: \(type(of: value))")
                return nil 
            }
            
            // Extract values using user-specified field mapping from differential form
            let diffForm = data.differentialForm
            let fcColumn = diffForm.foldChange
            let sigColumn = diffForm.significant
            let idColumn = diffForm.primaryIDs
            let geneColumn = diffForm.geneNames
            
            // CRITICAL: User must specify these columns, don't use defaults that might not exist
            guard !fcColumn.isEmpty && !sigColumn.isEmpty && !idColumn.isEmpty else {
                if processedCount < 3 {
                    print("🔍 PlotGenerationContext: Skipping protein \\(key) - required columns not specified by user")
                    print("🔍 PlotGenerationContext: FC=\\(fcColumn), Sig=\\(sigColumn), ID=\\(idColumn)")
                }
                return nil
            }
            
            let log2FC = proteinData[fcColumn] as? Double ?? 0.0
            let pValue = proteinData[sigColumn] as? Double ?? 1.0
            
            // Debug first few proteins to understand data structure
            if processedCount < 3 {
                print("🔍 PlotGenerationContext: Protein data keys: \(proteinData.keys.sorted())")
                print("🔍 PlotGenerationContext: Protein foldChange: \(proteinData[fcColumn] ?? "nil")")
                print("🔍 PlotGenerationContext: Protein pValue: \(proteinData[sigColumn] ?? "nil")")
                print("🔍 PlotGenerationContext: Protein geneNames: \(proteinData[geneColumn] ?? "nil")")
                print("🔍 PlotGenerationContext: Protein primaryID: \(proteinData[idColumn] ?? "nil")")
            }
            
            // Validate significance value - handle both raw p-values and transformed (-log10) values
            let isValidSignificance: Bool
            if data.differentialForm.transformSignificant {
                // For transformed values, expect -log10(p-value) which should be >= 0
                isValidSignificance = pValue >= 0
            } else {
                // For raw p-values, expect 0 < p <= 1
                isValidSignificance = pValue > 0 && pValue <= 1
            }
            
            guard isValidSignificance else { 
                if processedCount < 3 {
                    print("🔍 PlotGenerationContext: Protein invalid pValue: \(pValue) (transformSignificant: \(data.differentialForm.transformSignificant))")
                }
                return nil 
            }
            
            processedCount += 1
            
            let proteinName = proteinData["proteinName"] as? String ??
                             proteinData["protein_names"] as? String
            
            let geneNames = proteinData[geneColumn] as? String
            
            let thresholds = SignificanceThresholds(
                pCutoff: settings.pCutoff,
                log2FCCutoff: settings.log2FCCutoff
            )
            
            let isSignificant = abs(log2FC) >= thresholds.log2FCCutoff && 
                               pValue <= thresholds.pCutoff
            
            // Default color assignment
            let defaultColor = isSignificant ? "#d32f2f" : "#cccccc"
            
            // Extract primary ID using ONLY user-specified column
            let primaryID = proteinData[idColumn] as? String ?? ""
            guard !primaryID.isEmpty else {
                if processedCount < 3 {
                    print("🔍 PlotGenerationContext: Skipping protein \(key) - no primary ID in column '\(idColumn)'")
                }
                return nil
            }

            // Store the correct values based on transformation status
            let finalPValue: Double
            let plotYCoordinate: Double
            
            if data.differentialForm.transformSignificant {
                // pValue is already -log10 transformed, use it directly as plot Y coordinate
                finalPValue = pow(10, -pValue) // Convert back to raw p-value for compatibility
                plotYCoordinate = pValue // This is already -log10(p-value)
            } else {
                // pValue is raw, store as-is
                finalPValue = pValue
                plotYCoordinate = -log10(max(pValue, 1e-300)) // Apply transformation for plot coordinates
            }
            
            return ProteinPoint(
                id: key,
                primaryID: primaryID,
                proteinName: proteinName,
                geneNames: geneNames,
                log2FC: log2FC,
                pValue: finalPValue,
                isSignificant: isSignificant,
                isSelected: false,
                condition: proteinData["condition"] as? String,
                color: defaultColor,
                customData: proteinData.merging(["plotYCoordinate": plotYCoordinate], uniquingKeysWith: { _, new in new })
            )
        }
        
        print("🔍 PlotGenerationContext: Successfully converted \(proteins.count) proteins from \(data.proteomicsData.count) total")
        return proteins
    }
}

// MARK: - Extensions for JSON Serialization

extension PlotData {
    func toJSON() throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        
        let dict: [String: Any] = [
            "data": traces.map { $0.toDictionary() },
            "layout": layout.toDictionary(),
            "config": config.toDictionary()
        ]
        
        let data = try JSONSerialization.data(withJSONObject: dict)
        return String(data: data, encoding: .utf8) ?? "{}"
    }
}

extension PlotTrace {
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "x": x,
            "y": y,
            "mode": mode,
            "type": type,
            "name": name
        ]
        
        if let marker = marker {
            dict["marker"] = marker.toDictionary()
        }
        
        if let text = text {
            dict["text"] = text
        }
        
        if let hovertemplate = hovertemplate {
            dict["hovertemplate"] = hovertemplate
        }
        
        if let customdata = customdata {
            dict["customdata"] = customdata
        }
        
        if let error_y = error_y {
            dict["error_y"] = error_y.toDictionary()
        }
        
        // Violin plot specific properties
        if let violinmode = violinmode {
            dict["violinmode"] = violinmode
        }
        
        if let box_visible = box_visible {
            // Android box configuration: white fill with black border
            dict["box"] = [
                "visible": box_visible,
                "fillcolor": "rgba(255,255,255,0.8)",
                "line": [
                    "color": "black",
                    "width": 2
                ]
            ]
        }
        
        if let meanline_visible = meanline_visible {
            // Android meanline configuration: red color with 2px width
            dict["meanline"] = [
                "visible": meanline_visible,
                "color": "red",
                "width": 2
            ]
        }
        
        if let points = points {
            dict["points"] = points
        }
        
        if let pointpos = pointpos {
            dict["pointpos"] = pointpos
        }
        
        if let jitter = jitter {
            dict["jitter"] = jitter
        }
        
        if let fillcolor = fillcolor {
            dict["fillcolor"] = fillcolor
        }
        
        if let line_color = line_color {
            // Android violin line configuration: specified color with 1px width
            dict["line"] = [
                "color": line_color,
                "width": 1
            ]
        }
        
        // Additional Android violin plot properties
        if let spanmode = spanmode {
            dict["spanmode"] = spanmode
        }
        
        if let bandwidth = bandwidth {
            dict["bandwidth"] = bandwidth
        }
        
        if let scalemode = scalemode {
            dict["scalemode"] = scalemode
        }
        
        if let selected = selected {
            dict["selected"] = ["marker": selected.toDictionary()]
        }
        
        if let unselected = unselected {
            dict["unselected"] = ["marker": unselected.toDictionary()]
        }
        
        return dict
    }
}

extension PlotMarker {
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "color": color,
            "size": size
        ]
        
        if let symbol = symbol {
            dict["symbol"] = symbol
        }
        
        if let line = line {
            dict["line"] = line.toDictionary()
        }
        
        if let opacity = opacity {
            dict["opacity"] = opacity
        }
        
        return dict
    }
}

extension PlotLine {
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "color": color,
            "width": width
        ]
        
        if let dash = dash {
            dict["dash"] = dash
        }
        
        return dict
    }
}

extension PlotLayout {
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "xaxis": xaxis.toDictionary(),
            "yaxis": yaxis.toDictionary(),
            "showlegend": showlegend
        ]
        
        if let title = title {
            dict["title"] = title.toDictionary()
        }
        
        if let hovermode = hovermode {
            dict["hovermode"] = hovermode
        }
        
        if let plot_bgcolor = plot_bgcolor {
            dict["plot_bgcolor"] = plot_bgcolor
        }
        
        if let paper_bgcolor = paper_bgcolor {
            dict["paper_bgcolor"] = paper_bgcolor
        }
        
        if let font = font {
            dict["font"] = font.toDictionary()
        }
        
        if let shapes = shapes {
            dict["shapes"] = shapes.map { $0.toDictionary() }
        }
        
        if let annotations = annotations {
            dict["annotations"] = annotations.map { $0.toDictionary() }
        }
        
        if let legend = legend {
            dict["legend"] = legend.toDictionary()
        }
        
        if let margin = margin {
            dict["margin"] = margin.toDictionary()
        }
        
        return dict
    }
}

extension PlotAxis {
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "title": title.toDictionary()
        ]
        
        if let zeroline = zeroline {
            dict["zeroline"] = zeroline
        }
        
        if let zerolinecolor = zerolinecolor {
            dict["zerolinecolor"] = zerolinecolor
        }
        
        if let gridcolor = gridcolor {
            dict["gridcolor"] = gridcolor
        }
        
        if let range = range {
            dict["range"] = range
        }
        
        if let font = font {
            dict["font"] = font.toDictionary()
        }
        
        if let dtick = dtick {
            dict["dtick"] = dtick
        }
        
        if let ticklen = ticklen {
            dict["ticklen"] = ticklen
        }
        
        if let showgrid = showgrid {
            dict["showgrid"] = showgrid
        }
        
        if let tickangle = tickangle {
            dict["tickangle"] = tickangle
        }
        
        if let type = type {
            dict["type"] = type
        }
        
        if let automargin = automargin {
            dict["automargin"] = automargin
        }
        
        if let tickmode = tickmode {
            dict["tickmode"] = tickmode
        }
        
        if let tickvals = tickvals {
            dict["tickvals"] = tickvals
        }
        
        if let ticktext = ticktext {
            dict["ticktext"] = ticktext
        }
        
        return dict
    }
}

extension PlotAxisTitle {
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = ["text": text]
        
        if let font = font {
            dict["font"] = font.toDictionary()
        }
        
        return dict
    }
}

extension PlotTitle {
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = ["text": text]
        
        if let font = font {
            dict["font"] = font.toDictionary()
        }
        
        return dict
    }
}

extension PlotFont {
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = ["family": family]
        
        if let size = size {
            dict["size"] = size
        }
        
        if let color = color {
            dict["color"] = color
        }
        
        if let dash = dash {
            dict["dash"] = dash
        }
        
        return dict
    }
}

extension PlotShape {
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "type": type,
            "line": line.toDictionary()
        ]
        
        if let x0 = x0 { dict["x0"] = x0 }
        if let x1 = x1 { dict["x1"] = x1 }
        if let y0 = y0 { dict["y0"] = y0 }
        if let y1 = y1 { dict["y1"] = y1 }
        if let xref = xref { dict["xref"] = xref }
        if let yref = yref { dict["yref"] = yref }
        
        return dict
    }
}

extension PlotAnnotation {
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "text": text,
            "x": x,
            "y": y,
            "showarrow": showarrow
        ]

        // Add coordinate reference system (paper vs data coordinates)
        if let xref = xref {
            dict["xref"] = xref
        }

        if let yref = yref {
            dict["yref"] = yref
        }

        if let arrowhead = arrowhead {
            dict["arrowhead"] = arrowhead
        }

        if let arrowsize = arrowsize {
            dict["arrowsize"] = arrowsize
        }

        if let arrowwidth = arrowwidth {
            dict["arrowwidth"] = arrowwidth
        }

        if let arrowcolor = arrowcolor {
            dict["arrowcolor"] = arrowcolor
        }

        if let ax = ax {
            dict["ax"] = ax
        }

        if let ay = ay {
            dict["ay"] = ay
        }

        if let xanchor = xanchor {
            dict["xanchor"] = xanchor
        }

        if let yanchor = yanchor {
            dict["yanchor"] = yanchor
        }

        if let font = font {
            dict["font"] = font.toDictionary()
        }

        return dict
    }
}

extension PlotConfig {
    func toDictionary() -> [String: Any] {
        return [
            "responsive": responsive,
            "displayModeBar": displayModeBar,
            "editable": editable,
            "scrollZoom": scrollZoom,
            "doubleClick": doubleClick
        ]
    }
}

extension PlotErrorBar {
    func toDictionary() -> [String: Any] {
        return [
            "type": type,
            "array": array,
            "visible": visible,
            "color": color,
            "thickness": thickness,
            "width": width
        ]
    }
}

extension PlotLegend {
    func toDictionary() -> [String: Any] {
        return [
            "orientation": orientation,
            "x": x,
            "xanchor": xanchor,
            "y": y,
            "yanchor": yanchor
        ]
    }
}

extension PlotMargin {
    func toDictionary() -> [String: Any] {
        return [
            "l": left,
            "r": right,
            "t": top,
            "b": bottom
        ]
    }
}
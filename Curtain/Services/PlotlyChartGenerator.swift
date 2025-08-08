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
    
    init(curtainDataService: CurtainDataService? = nil) {
        self.curtainDataService = curtainDataService
        self.volcanoPlotDataService = VolcanoPlotDataService()
    }
    
    // MARK: - Volcano Plot Generation
    
    func createVolcanoPlotHtml(context: PlotGenerationContext) async -> String {
        print("🔍 PlotlyChartGenerator: createVolcanoPlotHtml called (using Android workflow)")
        print("🔍 PlotlyChartGenerator: Input protein count: \(context.data.proteomicsData.count)")
        
        // Use Android workflow for data processing
        let volcanoResult = await volcanoPlotDataService.processVolcanoData(
            curtainData: convertToCurtainData(context.data),
            settings: context.settings
        )
        
        print("🔍 PlotlyChartGenerator: Processed \(volcanoResult.jsonData.count) data points using Android workflow")
        
        let plotData = createAndroidCompatiblePlotData(volcanoResult, context: context)
        
        do {
            let plotJSON = try plotData.toJSON()
            print("🔍 PlotlyChartGenerator: Generated Android-compatible plot JSON length: \(plotJSON.count)")
            return generateVolcanoHtmlTemplate(plotJSON: plotJSON, editMode: context.editMode)
        } catch {
            print("❌ PlotlyChartGenerator: Error generating volcano plot JSON: \(error)")
            return generateErrorHtml("Failed to generate volcano plot data")
        }
    }
    
    // Convert PlotGenerationContext data to CurtainData format for Android workflow
    private func convertToCurtainData(_ data: CurtainData) -> CurtainData {
        return data
    }
    
    // Create Android-compatible plot data from volcano processing result
    private func createAndroidCompatiblePlotData(_ volcanoResult: VolcanoProcessResult, context: PlotGenerationContext) -> PlotData {
        let traces = createAndroidCompatibleTraces(volcanoResult.jsonData, settings: context.settings, colorMap: volcanoResult.colorMap)
        let layout = createAndroidCompatibleLayout(volcanoResult, context: context)
        let config = createDefaultPlotConfig()
        
        return PlotData(traces: traces, layout: layout, config: config)
    }
    
    
    // Create traces using Android-compatible data format
    private func createAndroidCompatibleTraces(_ jsonData: [[String: Any]], settings: CurtainSettings, colorMap: [String: String]) -> [PlotTrace] {
        print("🔍 PlotlyChartGenerator: createAndroidCompatibleTraces called with \(jsonData.count) data points")
        
        // Group data points by selection like Android (each selection becomes a trace)
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
                color: dataPoint["color"] as? String ?? "#808080"
            )
            
            // Process each selection for this point (like Android JavaScript)
            for (index, selectionName) in androidPoint.selections.enumerated() {
                let selectionColor = index < androidPoint.colors.count ? androidPoint.colors[index] : "#808080"
                
                if selectionGroups[selectionName] == nil {
                    selectionGroups[selectionName] = (color: selectionColor, points: [])
                }
                selectionGroups[selectionName]?.points.append(androidPoint)
            }
        }
        
        print("🔍 PlotlyChartGenerator: Created \(selectionGroups.count) selection groups: \(Array(selectionGroups.keys))")
        
        // Create traces for each selection (like Android)
        var traces: [PlotTrace] = []
        
        // First: Add user selection traces (non-background, non-significance)
        let userSelections = selectionGroups.filter { (selectionName, _) in
            return selectionName != "Background" && 
                   selectionName != "Other" &&
                   !selectionName.contains("P-value") &&
                   !selectionName.contains("FC")
        }
        
        for (selectionName, groupData) in userSelections {
            let trace = createAndroidCompatibleTrace(
                dataPoints: groupData.points,
                name: selectionName,
                color: groupData.color,
                markerSize: settings.scatterPlotMarkerSize
            )
            traces.append(trace)
        }
        
        // Second: Add background and significance group traces
        let backgroundAndSignificance = selectionGroups.filter { (selectionName, _) in
            return selectionName == "Background" || 
                   selectionName == "Other" ||
                   selectionName.contains("P-value") ||
                   selectionName.contains("FC")
        }
        
        for (selectionName, groupData) in backgroundAndSignificance {
            let trace = createAndroidCompatibleTrace(
                dataPoints: groupData.points,
                name: selectionName,
                color: groupData.color,
                markerSize: settings.scatterPlotMarkerSize
            )
            traces.append(trace)
        }
        
        // Reverse traces array to match Android/Angular frontend ordering
        traces.reverse()
        
        print("🔍 PlotlyChartGenerator: Final trace order: \(traces.map { $0.name })")
        return traces
    }
    
    // Create trace using Android data format
    private func createAndroidCompatibleTrace(dataPoints: [AndroidDataPoint], name: String, color: String, markerSize: Double) -> PlotTrace {
        let x = dataPoints.map { $0.x }
        let y = dataPoints.map { $0.y }
        
        // Format text like Android: <genename>(<primaryid>) if gene name exists, otherwise just primaryid
        let text = dataPoints.map { point -> String in
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
    
    // Create layout using Android volcano axis settings
    private func createAndroidCompatibleLayout(_ volcanoResult: VolcanoProcessResult, context: PlotGenerationContext) -> PlotLayout {
        let settings = context.settings
        let volcanoAxis = volcanoResult.updatedVolcanoAxis
        
        let title = PlotTitle(
            text: settings.volcanoPlotTitle,
            font: PlotFont(
                family: settings.plotFontFamily,
                size: 16,
                color: nil
            )
        )
        
        let xaxis = PlotAxis(
            title: PlotAxisTitle(
                text: volcanoAxis.x,
                font: PlotFont(family: settings.plotFontFamily, size: 12, color: nil)
            ),
            zeroline: true,
            zerolinecolor: "#000000",
            gridcolor: "#e0e0e0",
            range: [volcanoAxis.minX ?? -3.0, volcanoAxis.maxX ?? 3.0],
            font: PlotFont(family: settings.plotFontFamily, size: 10, color: nil),
            dtick: volcanoAxis.dtickX,
            ticklen: volcanoAxis.ticklenX,
            showgrid: settings.volcanoPlotGrid["x"] ?? true
        )
        
        let yaxis = PlotAxis(
            title: PlotAxisTitle(
                text: volcanoAxis.y,
                font: PlotFont(family: settings.plotFontFamily, size: 12, color: nil)
            ),
            zeroline: false,
            zerolinecolor: nil,
            gridcolor: "#e0e0e0",
            range: [volcanoAxis.minY ?? 0.0, volcanoAxis.maxY ?? 5.0],
            font: PlotFont(family: settings.plotFontFamily, size: 10, color: nil),
            dtick: volcanoAxis.dtickY,
            ticklen: volcanoAxis.ticklenY,
            showgrid: settings.volcanoPlotGrid["y"] ?? true
        )
        
        let shapes = createAndroidCompatibleThresholdShapes(settings, volcanoAxis)
        print("🔍 PlotlyChartGenerator: Converting textAnnotation with \(settings.textAnnotation.count) entries")
        for (key, value) in settings.textAnnotation {
            print("🔍 PlotlyChartGenerator: textAnnotation key '\(key)': \(value)")
        }
        let annotations = convertTextAnnotations(settings.textAnnotation)
        print("🔍 PlotlyChartGenerator: Final annotations count: \(annotations.count)")
        
        return PlotLayout(
            title: title,
            xaxis: xaxis,
            yaxis: yaxis,
            hovermode: "closest",
            showlegend: true,
            plot_bgcolor: "rgba(0,0,0,0)",
            paper_bgcolor: "rgba(0,0,0,0)",
            font: PlotFont(family: settings.plotFontFamily, size: 12, color: nil),
            shapes: shapes,
            annotations: annotations,
            legend: PlotLegend(
                orientation: "h", // Horizontal orientation like Android
                x: 0.5,
                xanchor: "center",
                y: -0.1, // Position below the plot like Android
                yanchor: "top"
            )
        )
    }
    
    // Create threshold shapes using Android volcano axis settings
    private func createAndroidCompatibleThresholdShapes(_ settings: CurtainSettings, _ volcanoAxis: VolcanoAxis) -> [PlotShape] {
        let maxY = volcanoAxis.maxY ?? 5.0
        let minX = volcanoAxis.minX ?? -3.0
        let maxX = volcanoAxis.maxX ?? 3.0
        
        let pValueThreshold = -log10(settings.pCutoff)
        
        // Android uses rgb(21,4,4) color with dashed lines
        return [
            // Vertical line for negative fold change cutoff (like Android)
            PlotShape(
                type: "line",
                x0: -settings.log2FCCutoff,
                x1: -settings.log2FCCutoff,
                y0: 0,
                y1: maxY,
                xref: "x",
                yref: "y",
                line: PlotLine(color: "rgb(21,4,4)", width: 1, dash: "dash")
            ),
            // Vertical line for positive fold change cutoff (like Android)
            PlotShape(
                type: "line",
                x0: settings.log2FCCutoff,
                x1: settings.log2FCCutoff,
                y0: 0,
                y1: maxY,
                xref: "x",
                yref: "y",
                line: PlotLine(color: "rgb(21,4,4)", width: 1, dash: "dash")
            ),
            // Horizontal line for p-value cutoff (like Android)
            PlotShape(
                type: "line",
                x0: minX,
                x1: maxX,
                y0: pValueThreshold,
                y1: pValueThreshold,
                xref: "x",
                yref: "y",
                line: PlotLine(color: "rgb(21,4,4)", width: 1, dash: "dash")
            )
        ]
    }
    
    
    // MARK: - Helper Methods
    
    // Android data point structure
    private struct AndroidDataPoint {
        let x: Double
        let y: Double
        let id: String
        let gene: String
        let comparison: String
        let selections: [String]
        let colors: [String]
        let color: String
    }
    
    private func convertTextAnnotations(_ textAnnotations: [String: Any]) -> [PlotAnnotation] {
        var annotations: [PlotAnnotation] = []
        
        for (key, value) in textAnnotations {
            print("🔍 PlotlyChartGenerator: Processing annotation key '\(key)'")
            print("🔍 PlotlyChartGenerator: Value type: \(type(of: value))")
            print("🔍 PlotlyChartGenerator: Value: \(value)")
            
            if let annotationData = value as? [String: Any] {
                print("🔍 PlotlyChartGenerator: Annotation data keys: \(annotationData.keys)")
                if let dataSection = annotationData["data"] as? [String: Any] {
                    print("🔍 PlotlyChartGenerator: Data section keys: \(dataSection.keys)")
                    
                    // Extract values from the nested "data" section (Android format)
                    guard let text = dataSection["text"] as? String,
                          let x = dataSection["x"] as? Double,
                          let y = dataSection["y"] as? Double else {
                        print("❌ PlotlyChartGenerator: Invalid annotation data for key: \(key)")
                        print("❌ PlotlyChartGenerator: text=\(dataSection["text"] ?? "nil"), x=\(dataSection["x"] ?? "nil"), y=\(dataSection["y"] ?? "nil")")
                        continue
                    }
                    
                    // Extract title - the unique stable identifier (gene name(primary id) or primary id)
                    let title = annotationData["title"] as? String ?? key
                    print("🔍 PlotlyChartGenerator: Extracted x=\(x), y=\(y), text='\(text)'")
                    
                    // Extract additional properties with Android defaults
                    let showarrow = dataSection["showarrow"] as? Bool ?? true
                    let arrowhead = dataSection["arrowhead"] as? Int ?? 1
                    let arrowsize = dataSection["arrowsize"] as? Double ?? 1.0
                    let arrowwidth = dataSection["arrowwidth"] as? Double ?? 1.0
                    let arrowcolor = dataSection["arrowcolor"] as? String ?? "#000000"
                    let ax = dataSection["ax"] as? Double ?? -20
                    let ay = dataSection["ay"] as? Double ?? -20
                    let xanchor = dataSection["xanchor"] as? String ?? "center"
                    let yanchor = dataSection["yanchor"] as? String ?? "bottom"
                    
                    // Extract font properties
                    var fontSize: Double = 15
                    var fontColor: String = "#000000"
                    var fontFamily: String = "Arial, sans-serif"
                    
                    if let fontData = dataSection["font"] as? [String: Any] {
                        fontSize = fontData["size"] as? Double ?? 15
                        fontColor = fontData["color"] as? String ?? "#000000"
                        fontFamily = fontData["family"] as? String ?? "Arial, sans-serif"
                    }
                    
                    let annotation = PlotAnnotation(
                        id: key,
                        title: title,
                        text: text,
                        x: x,
                        y: y,
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
                    
                    print("✅ PlotlyChartGenerator: Created annotation '\(key)' at plot coordinates (\(x), \(y)) with text: '\(text)'")
                } else {
                    print("❌ PlotlyChartGenerator: No 'data' section found in annotation: \(annotationData)")
                    continue
                }
            } else {
                print("❌ PlotlyChartGenerator: Value is not dictionary: \(value)")
                continue
            }
        }
        
        print("📊 PlotlyChartGenerator: Converted \(annotations.count) annotations from textAnnotation data")
        return annotations
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
    
    // MARK: - HTML Template Generation
    
    private func generateVolcanoHtmlTemplate(plotJSON: String, editMode: Bool) -> String {
        return """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <meta http-equiv="Content-Security-Policy" content="default-src 'self' 'unsafe-inline' 'unsafe-eval'; connect-src 'none'; img-src 'self' data:; script-src 'self' 'unsafe-inline' 'unsafe-eval';">
            <title>Volcano Plot</title>
            <style>
                body {
                    margin: 0;
                    padding: 0;
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                    background-color: var(--background-color, #ffffff);
                    color: var(--text-color, #000000);
                }
                
                #plot {
                    width: 100%;
                    height: 100vh;
                }
                
                .loading {
                    display: flex;
                    justify-content: center;
                    align-items: center;
                    height: 100vh;
                    font-size: 18px;
                    color: var(--text-color, #666);
                }
                
                .error {
                    display: flex;
                    justify-content: center;
                    align-items: center;
                    height: 100vh;
                    font-size: 16px;
                    color: #d32f2f;
                    text-align: center;
                    padding: 20px;
                }
                
                /* Dark mode support */
                @media (prefers-color-scheme: dark) {
                    body {
                        --background-color: #1c1c1e;
                        --text-color: #ffffff;
                    }
                }
            </style>
        </head>
        <body>
            <div id="loading" class="loading">Loading volcano plot...</div>
            <div id="plot" style="display: none;"></div>
            <div id="error" class="error" style="display: none;">
                <div>
                    <h3>Unable to load volcano plot</h3>
                    <p>Please check your data and try again.</p>
                </div>
            </div>

            <script>
            // Inline Plotly.js to avoid resource loading issues
            \(getInlinePlotlyJS())
            </script>
            <script>
                // Check if Plotly loaded successfully
                if (typeof Plotly === 'undefined') {
                    console.error('Plotly.js failed to load');
                    document.getElementById('loading').style.display = 'none';
                    document.getElementById('error').style.display = 'block';
                    document.getElementById('error').innerHTML = '<div><h3>Plot Library Error</h3><p>Unable to load plotting library. Please try again.</p></div>';
                    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.plotError) {
                        window.webkit.messageHandlers.plotError.postMessage('Plotly.js failed to load');
                    }
                } else {
                    // Global configuration for Plotly
                    Plotly.setPlotConfig({
                        displayModeBar: true,
                        displaylogo: false,
                        modeBarButtonsToRemove: ['sendDataToCloud', 'editInChartStudio']
                    });

                    // Plot data from iOS
                    const plotData = \(plotJSON);
                    const editMode = \(editMode ? "true" : "false");
                
                // State management
                let currentPlot = null;
                let selectedPoints = [];
                let annotations = plotData.layout.annotations || [];
                
                // Fast annotation lookup map for drag performance
                const annotationMap = new Map();
                
                // Debug: Log initial annotations
                console.log('Initial annotations from plotData:', annotations);
                console.log('Number of annotations:', annotations.length);
                
                // iOS WebView communication interface
                window.VolcanoPlot = {
                    // Initialize the plot
                    initialize: function() {
                        try {
                            document.getElementById('loading').style.display = 'none';
                            document.getElementById('error').style.display = 'none';
                            document.getElementById('plot').style.display = 'block';
                            
                            Plotly.newPlot('plot', plotData.data, plotData.layout, plotData.config)
                                .then(() => {
                                    currentPlot = document.getElementById('plot');
                                    this.initializeAnnotationMap();
                                    this.setupEventHandlers();
                                    this.notifyReady();
                                })
                                .catch(error => {
                                    console.error('Error creating volcano plot:', error);
                                    this.showError('Failed to create volcano plot: ' + error.message);
                                });
                        } catch (error) {
                            console.error('Error in initialize:', error);
                            this.showError('JavaScript error: ' + error.message);
                        }
                    },
                    
                    // Get complete coordinate hierarchy: parent view -> WebView -> plot element -> plot area
                    getPlotDimensions: function() {
                        if (!currentPlot || !currentPlot._fullLayout) {
                            console.log('📊 No plot or layout available');
                            return null;
                        }
                        
                        const layout = currentPlot._fullLayout;
                        const plotDiv = currentPlot;
                        
                        // STEP 1: Detect WebView position within parent view hierarchy
                        const body = document.body || document.documentElement;
                        const html = document.documentElement;
                        
                        // Get WebView content position (accounting for any scrolling)
                        const webViewRect = body.getBoundingClientRect();
                        const webViewScrollLeft = html.scrollLeft || body.scrollLeft || 0;
                        const webViewScrollTop = html.scrollTop || body.scrollTop || 0;
                        
                        console.log('🌐 WebView position in parent view:', {
                            left: webViewRect.left,
                            top: webViewRect.top,
                            width: webViewRect.width,
                            height: webViewRect.height,
                            scrollLeft: webViewScrollLeft,
                            scrollTop: webViewScrollTop
                        });
                        
                        // STEP 2: Detect plot element position within WebView
                        const plotElementRect = plotDiv.getBoundingClientRect();
                        const plotElementOffsetX = plotElementRect.left - webViewRect.left + webViewScrollLeft;
                        const plotElementOffsetY = plotElementRect.top - webViewRect.top + webViewScrollTop;
                        
                        console.log('📈 Plot element position in WebView:', {
                            offsetX: plotElementOffsetX,
                            offsetY: plotElementOffsetY,
                            width: plotElementRect.width,
                            height: plotElementRect.height
                        });
                        
                        // STEP 3: Get plot area position within plot element using Plotly's coordinate system
                        const xaxis = layout.xaxis;
                        const yaxis = layout.yaxis;
                        
                        if (!xaxis || !yaxis || !xaxis.range || !yaxis.range) {
                            console.log('📊 No axis information available');
                            return null;
                        }
                        
                        console.log('📊 Axis ranges - X:', xaxis.range, 'Y:', yaxis.range);
                        
                        // Use Plotly's l2p functions to get plot area boundaries within plot element
                        try {
                            // Get the actual margins from Plotly layout
                            const margin = layout.margin || {};
                            const marginLeft = margin.l || 80;
                            const marginTop = margin.t || 100;
                            const marginRight = margin.r || 80;
                            const marginBottom = margin.b || 80;
                            
                            console.log('📊 Plotly margins:', margin);
                            console.log('📊 Calculated margins - L:', marginLeft, 'T:', marginTop, 'R:', marginRight, 'B:', marginBottom);
                            
                            // Get corners of the plot area using data coordinates  
                            const xMin = xaxis.range[0];
                            const xMax = xaxis.range[1];
                            const yMin = yaxis.range[0];
                            const yMax = yaxis.range[1];
                            
                            // Convert data coordinates to plot-relative pixel coordinates (within plot element)
                            const plotRelativeTopLeft = { 
                                x: xaxis.l2p(xMin), 
                                y: yaxis.l2p(yMax) 
                            };
                            const plotRelativeBottomRight = { 
                                x: xaxis.l2p(xMax), 
                                y: yaxis.l2p(yMin) 
                            };
                            
                            console.log('📊 Plot-relative coordinates within element - TopLeft:', plotRelativeTopLeft, 'BottomRight:', plotRelativeBottomRight);
                            
                            // Plot area boundaries relative to plot element
                            const plotAreaLeft = marginLeft + plotRelativeTopLeft.x;
                            const plotAreaTop = marginTop + plotRelativeTopLeft.y;
                            const plotAreaRight = marginLeft + plotRelativeBottomRight.x;
                            const plotAreaBottom = marginTop + plotRelativeBottomRight.y;
                            
                            // STEP 4: Calculate final coordinates - complete hierarchy transformation
                            // Final position = WebView offset + plot element offset + plot area offset
                            const finalPlotLeft = webViewRect.left + plotElementOffsetX + plotAreaLeft;
                            const finalPlotTop = webViewRect.top + plotElementOffsetY + plotAreaTop;
                            const finalPlotRight = webViewRect.left + plotElementOffsetX + plotAreaRight;
                            const finalPlotBottom = webViewRect.top + plotElementOffsetY + plotAreaBottom;
                            
                            console.log('📊 Final plot boundaries in parent view coordinates:');
                            console.log('   L=' + finalPlotLeft + ', T=' + finalPlotTop + ', R=' + finalPlotRight + ', B=' + finalPlotBottom);
                            
                            return {
                                // Complete coordinate hierarchy results
                                plotLeft: finalPlotLeft,
                                plotRight: finalPlotRight,
                                plotTop: finalPlotTop,
                                plotBottom: finalPlotBottom,
                                
                                // Intermediate coordinate system information for debugging
                                webView: {
                                    left: webViewRect.left,
                                    top: webViewRect.top,
                                    width: webViewRect.width,
                                    height: webViewRect.height
                                },
                                plotElement: {
                                    offsetX: plotElementOffsetX,
                                    offsetY: plotElementOffsetY,
                                    width: plotElementRect.width,
                                    height: plotElementRect.height
                                },
                                plotArea: {
                                    left: plotAreaLeft,
                                    top: plotAreaTop,
                                    right: plotAreaRight,
                                    bottom: plotAreaBottom,
                                    width: plotAreaRight - plotAreaLeft,
                                    height: plotAreaBottom - plotAreaTop
                                },
                                
                                // Full dimensions
                                fullWidth: plotDiv.offsetWidth,
                                fullHeight: plotDiv.offsetHeight,
                                
                                // Axis ranges
                                xRange: xaxis.range,
                                yRange: yaxis.range,
                                
                                // Debug info
                                method: 'complete_hierarchy_l2p',
                                hasL2P: !!(xaxis.l2p && yaxis.l2p),
                                coordinateHierarchy: 'webView->plotElement->plotArea'
                            };
                            
                        } catch (error) {
                            console.log('📊 Error using Plotly l2p functions:', error);
                            
                            // Fallback to domain-based calculation with hierarchy
                            const xDomain = xaxis.domain || [0, 1];
                            const yDomain = yaxis.domain || [0, 1];
                            
                            // Plot area relative to plot element
                            const plotAreaLeft = xDomain[0] * plotDiv.offsetWidth;
                            const plotAreaRight = xDomain[1] * plotDiv.offsetWidth;
                            const plotAreaTop = (1 - yDomain[1]) * plotDiv.offsetHeight; // Y is flipped
                            const plotAreaBottom = (1 - yDomain[0]) * plotDiv.offsetHeight;
                            
                            // Final position using complete hierarchy
                            const finalPlotLeft = webViewRect.left + plotElementOffsetX + plotAreaLeft;
                            const finalPlotTop = webViewRect.top + plotElementOffsetY + plotAreaTop;
                            const finalPlotRight = webViewRect.left + plotElementOffsetX + plotAreaRight;
                            const finalPlotBottom = webViewRect.top + plotElementOffsetY + plotAreaBottom;
                            
                            console.log('📊 Using domain fallback with complete hierarchy - xDomain:', xDomain, 'yDomain:', yDomain);
                            console.log('📊 Domain-based boundaries: L=' + finalPlotLeft + ', T=' + finalPlotTop + ', R=' + finalPlotRight + ', B=' + finalPlotBottom);
                            
                            return {
                                plotLeft: finalPlotLeft,
                                plotRight: finalPlotRight,
                                plotTop: finalPlotTop,
                                plotBottom: finalPlotBottom,
                                
                                webView: {
                                    left: webViewRect.left,
                                    top: webViewRect.top,
                                    width: webViewRect.width,
                                    height: webViewRect.height
                                },
                                plotElement: {
                                    offsetX: plotElementOffsetX,
                                    offsetY: plotElementOffsetY,
                                    width: plotElementRect.width,
                                    height: plotElementRect.height
                                },
                                plotArea: {
                                    left: plotAreaLeft,
                                    top: plotAreaTop,
                                    right: plotAreaRight,
                                    bottom: plotAreaBottom,
                                    width: plotAreaRight - plotAreaLeft,
                                    height: plotAreaBottom - plotAreaTop
                                },
                                
                                fullWidth: plotDiv.offsetWidth,
                                fullHeight: plotDiv.offsetHeight,
                                xRange: xaxis.range,
                                yRange: yaxis.range,
                                method: 'complete_hierarchy_domain_fallback',
                                hasL2P: false,
                                coordinateHierarchy: 'webView->plotElement->plotArea'
                            };
                        }
                    },

                    // Convert plot coordinates to screen coordinates using complete coordinate hierarchy
                    convertPlotToScreen: function(x, y) {
                        if (!currentPlot || !currentPlot._fullLayout) {
                            console.log('📊 convertPlotToScreen: No plot available');
                            return null;
                        }
                        
                        // Use the enhanced getPlotDimensions that includes complete hierarchy
                        const dims = this.getPlotDimensions();
                        if (!dims) {
                            console.log('📊 convertPlotToScreen: No plot dimensions available');
                            return null;
                        }
                        
                        const layout = currentPlot._fullLayout;
                        const xaxis = layout.xaxis;
                        const yaxis = layout.yaxis;
                        
                        if (!xaxis || !yaxis) {
                            console.log('📊 convertPlotToScreen: No axis available');
                            return null;
                        }
                        
                        try {
                            // Use Plotly's l2p to get plot-relative coordinates within plot element
                            const plotRelativeX = xaxis.l2p(x);
                            const plotRelativeY = yaxis.l2p(y);
                            
                            // Get plot area position within plot element
                            const margin = layout.margin || {};
                            const marginLeft = margin.l || 80;
                            const marginTop = margin.t || 100;
                            
                            // Position within plot element
                            const plotElementX = marginLeft + plotRelativeX;
                            const plotElementY = marginTop + plotRelativeY;
                            
                            // Apply complete coordinate hierarchy transformation:
                            // Final position = WebView position + plot element offset + plot area position
                            const finalScreenX = dims.webView.left + dims.plotElement.offsetX + plotElementX;
                            const finalScreenY = dims.webView.top + dims.plotElement.offsetY + plotElementY;
                            
                            console.log('📊 convertPlotToScreen complete hierarchy:');
                            console.log('   Plot coords: (' + x + ',' + y + ')');
                            console.log('   Plot-relative: (' + plotRelativeX + ',' + plotRelativeY + ')');
                            console.log('   Plot element: (' + plotElementX + ',' + plotElementY + ')');
                            console.log('   WebView offset: (' + dims.webView.left + ',' + dims.webView.top + ')');
                            console.log('   Element offset: (' + dims.plotElement.offsetX + ',' + dims.plotElement.offsetY + ')');
                            console.log('   Final screen: (' + finalScreenX + ',' + finalScreenY + ')');
                            
                            return { 
                                x: finalScreenX, 
                                y: finalScreenY,
                                hierarchy: {
                                    plotRelative: { x: plotRelativeX, y: plotRelativeY },
                                    plotElement: { x: plotElementX, y: plotElementY },
                                    webViewOffset: { x: dims.webView.left, y: dims.webView.top },
                                    elementOffset: { x: dims.plotElement.offsetX, y: dims.plotElement.offsetY }
                                }
                            };
                            
                        } catch (error) {
                            console.log('📊 Error in convertPlotToScreen l2p, using fallback:', error);
                            
                            // Fallback to manual calculation with complete hierarchy
                            if (!dims.plotArea) {
                                console.log('📊 No plot area information for fallback');
                                return null;
                            }
                            
                            const plotAreaWidth = dims.plotArea.width;
                            const plotAreaHeight = dims.plotArea.height;
                            
                            // Manual coordinate transformation within plot area
                            const normalizedX = (x - dims.xRange[0]) / (dims.xRange[1] - dims.xRange[0]);
                            const normalizedY = (dims.yRange[1] - y) / (dims.yRange[1] - dims.yRange[0]); // Y is flipped
                            
                            const plotAreaX = normalizedX * plotAreaWidth;
                            const plotAreaY = normalizedY * plotAreaHeight;
                            
                            // Apply complete hierarchy: WebView + plot element + plot area
                            const finalScreenX = dims.webView.left + dims.plotElement.offsetX + dims.plotArea.left + plotAreaX;
                            const finalScreenY = dims.webView.top + dims.plotElement.offsetY + dims.plotArea.top + plotAreaY;
                            
                            console.log('📊 convertPlotToScreen fallback with complete hierarchy:');
                            console.log('   Plot coords: (' + x + ',' + y + ') -> normalized: (' + normalizedX + ',' + normalizedY + ')');
                            console.log('   Plot area: (' + plotAreaX + ',' + plotAreaY + ')');
                            console.log('   Final screen: (' + finalScreenX + ',' + finalScreenY + ')');
                            
                            return { 
                                x: finalScreenX, 
                                y: finalScreenY,
                                method: 'fallback_with_hierarchy'
                            };
                        }
                    },

                    // Initialize annotation map for fast lookups during dragging
                    initializeAnnotationMap: function() {
                        annotationMap.clear();
                        
                        // Get annotations from the current plot layout instead of cached version
                        if (currentPlot && currentPlot.layout && currentPlot.layout.annotations) {
                            annotations = currentPlot.layout.annotations;
                            console.log('Updated annotations from live plot:', annotations.length, 'annotations');
                        }
                        
                        // Debug: Log each annotation structure and plot dimensions
                        const dims = this.getPlotDimensions();
                        console.log('Plot dimensions:', dims);
                        
                        annotations.forEach((annotation, index) => {
                            console.log('Annotation', index, ':', JSON.stringify(annotation, null, 2));
                        });
                        
                        // Build fast lookup map from annotation titles to object reference + index
                        annotations.forEach((annotation, index) => {
                            const annotationInfo = { 
                                annotation: annotation, 
                                index: index 
                            };
                            
                            // Try multiple properties as identifiers
                            let identifier = null;
                            if (annotation.title) {
                                identifier = annotation.title;
                                console.log('Mapped annotation by title:', identifier, 'at index', index);
                            } else if (annotation.text) {
                                // Use text content as identifier if no title
                                identifier = annotation.text.replace(/<[^>]*>/g, ''); // Remove HTML tags
                                console.log('Mapped annotation by text:', identifier, 'at index', index);
                            } else if (annotation.id) {
                                identifier = annotation.id;
                                console.log('Mapped annotation by ID:', identifier, 'at index', index);
                            }
                            
                            if (identifier) {
                                annotationMap.set(identifier, annotationInfo);
                            } else {
                                console.warn('No identifier found for annotation at index', index);
                            }
                        });
                        
                        console.log('Annotation map initialized with', annotationMap.size, 'entries');
                        console.log('Map keys:', Array.from(annotationMap.keys()));
                    },
                    
                    // Setup event handlers for interactivity
                    setupEventHandlers: function() {
                        if (!currentPlot) return;
                        
                        // Handle point clicks (like Android)
                        currentPlot.on('plotly_click', (data) => {
                            if (data.points && data.points.length > 0) {
                                const point = data.points[0];
                                const clickData = {
                                    proteinId: point.customdata.id,
                                    id: point.customdata.id, // Also provide as 'id' for compatibility
                                    primaryID: point.customdata.id, // Use actual protein ID
                                    proteinName: point.customdata.gene,
                                    log2FC: point.x,
                                    pValue: point.customdata.pValue,
                                    x: point.x, // Also provide as 'x' for compatibility
                                    y: point.y, // Also provide as 'y' for compatibility
                                    screenX: data.event.clientX,
                                    screenY: data.event.clientY
                                };
                                
                                console.log('Point clicked:', clickData);
                                this.notifyPointClicked(clickData);
                            }
                        });
                        
                        // Handle annotation drags (if edit mode is enabled)
                        if (editMode) {
                            this.enableAnnotationEditing();
                        }
                        
                        // Handle plot hover
                        currentPlot.on('plotly_hover', (data) => {
                            if (data.points && data.points.length > 0) {
                                const point = data.points[0];
                                this.notifyPointHovered(point.customdata);
                            }
                        });
                    },
                    
                    // Enable annotation editing
                    enableAnnotationEditing: function() {
                        // Implementation for annotation editing
                        // This would include drag handlers and coordinate conversion
                    },
                    
                    // Update plot with new data
                    updatePlot: function(newData) {
                        try {
                            if (currentPlot) {
                                Plotly.react(currentPlot, newData.data, newData.layout, newData.config)
                                    .then(() => {
                                        this.notifyUpdated();
                                    })
                                    .catch(error => {
                                        console.error('Error updating plot:', error);
                                        this.showError('Failed to update plot: ' + error.message);
                                    });
                            }
                        } catch (error) {
                            console.error('Error in updatePlot:', error);
                            this.showError('JavaScript error: ' + error.message);
                        }
                    },
                    
                    // Add annotation
                    addAnnotation: function(annotation) {
                        annotations.push(annotation);
                        this.updateAnnotations();
                    },
                    
                    // Update annotations
                    updateAnnotations: function() {
                        if (currentPlot) {
                            const update = { 'annotations': annotations };
                            Plotly.relayout(currentPlot, update);
                        }
                    },
                    
                    // Update single annotation position efficiently (for dragging)
                    updateAnnotationPosition: function(annotationTitle, ax, ay) {
                        if (!currentPlot) {
                            console.error('No current plot available');
                            return;
                        }
                        
                        // Fast direct lookup using stable title - O(1) performance!
                        const annotationInfo = annotationMap.get(annotationTitle);
                        
                        if (annotationInfo) {
                            // Update the ax and ay values directly on the object reference
                            annotationInfo.annotation.ax = ax;
                            annotationInfo.annotation.ay = ay;
                            
                            // Use extremely efficient relayout with cached index - no indexOf() needed!
                            const update = { 
                                ['annotations[' + annotationInfo.index + '].ax']: ax,
                                ['annotations[' + annotationInfo.index + '].ay']: ay
                            };
                            
                            // Use synchronous approach for ultra-low latency
                            try {
                                Plotly.relayout(currentPlot, update);
                            } catch (error) {
                                console.error('Plotly.relayout failed:', error);
                            }
                        } else {
                            // Fallback: search by text content without verbose logging
                            for (let [key, info] of annotationMap.entries()) {
                                if (info.annotation.text && info.annotation.text.includes(annotationTitle)) {
                                    return this.updateAnnotationPosition(key, ax, ay);
                                }
                            }
                            
                            console.warn('No annotation found for title:', annotationTitle);
                        }
                    },
                    
                    // Batch update multiple annotation positions (for preview mode)
                    updateAnnotationPositions: function(updates) {
                        if (!currentPlot || !updates || updates.length === 0) return;
                        
                        const batchUpdate = {};
                        let hasChanges = false;
                        
                        for (const update of updates) {
                            // Fast direct lookup using stable title - O(1) performance!
                            const annotationInfo = annotationMap.get(update.title);
                            
                            if (annotationInfo) {
                                // Update the object reference directly
                                annotationInfo.annotation.ax = update.ax;
                                annotationInfo.annotation.ay = update.ay;
                                
                                // Add to batch update for Plotly with cached index - no indexOf() needed!
                                batchUpdate['annotations[' + annotationInfo.index + '].ax'] = update.ax;
                                batchUpdate['annotations[' + annotationInfo.index + '].ay'] = update.ay;
                                hasChanges = true;
                            }
                        }
                        
                        if (hasChanges) {
                            // Batch update only the changed annotation positions
                            Plotly.relayout(currentPlot, batchUpdate);
                        }
                    },
                    
                    // Show error message
                    showError: function(message) {
                        document.getElementById('loading').style.display = 'none';
                        document.getElementById('plot').style.display = 'none';
                        const errorDiv = document.getElementById('error');
                        errorDiv.innerHTML = '<div><h3>Volcano Plot Error</h3><p>' + message + '</p></div>';
                        errorDiv.style.display = 'flex';
                        this.notifyError(message);
                    },
                    
                    // Communication with iOS
                    notifyReady: function() {
                        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.plotReady) {
                            window.webkit.messageHandlers.plotReady.postMessage('ready');
                        }
                    },
                    
                    notifyPointClicked: function(pointData) {
                        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.pointClicked) {
                            window.webkit.messageHandlers.pointClicked.postMessage(JSON.stringify(pointData));
                        }
                    },
                    
                    notifyPointHovered: function(pointData) {
                        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.pointHovered) {
                            window.webkit.messageHandlers.pointHovered.postMessage(JSON.stringify(pointData));
                        }
                    },
                    
                    notifyUpdated: function() {
                        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.plotUpdated) {
                            window.webkit.messageHandlers.plotUpdated.postMessage('updated');
                        }
                    },
                    
                    notifyError: function(message) {
                        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.plotError) {
                            window.webkit.messageHandlers.plotError.postMessage(message);
                        }
                    },
                    
                    // Send plot dimensions to iOS
                    sendPlotDimensions: function() {
                        const dims = this.getPlotDimensions();
                        if (dims && window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.plotDimensions) {
                            window.webkit.messageHandlers.plotDimensions.postMessage(JSON.stringify(dims));
                        }
                    },
                    
                    // Convert plot coordinates to screen and send to iOS
                    convertAndSendCoordinates: function(annotations) {
                        const results = [];
                        const dims = this.getPlotDimensions();
                        
                        console.log('🎯 convertAndSendCoordinates called with', annotations.length, 'annotations');
                        console.log('🎯 Plot dimensions:', dims);
                        
                        if (dims) {
                            for (const annotation of annotations) {
                                const screenPos = this.convertPlotToScreen(annotation.x, annotation.y);
                                console.log('🎯 Annotation:', annotation.id || annotation.title, 
                                           'Data coords:', annotation.x, annotation.y, 
                                           'Screen coords:', screenPos?.x, screenPos?.y,
                                           'Offsets:', annotation.ax || 0, annotation.ay || 0);
                                
                                if (screenPos) {
                                    results.push({
                                        id: annotation.id || annotation.title,
                                        plotX: annotation.x,
                                        plotY: annotation.y,
                                        screenX: screenPos.x,
                                        screenY: screenPos.y,
                                        ax: annotation.ax || 0,
                                        ay: annotation.ay || 0
                                    });
                                }
                            }
                        }
                        
                        console.log('🎯 Sending coordinate results:', results);
                        
                        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.annotationCoordinates) {
                            window.webkit.messageHandlers.annotationCoordinates.postMessage(JSON.stringify(results));
                        }
                    }
                };
                
                // Initialize when page loads
                document.addEventListener('DOMContentLoaded', function() {
                    window.VolcanoPlot.initialize();
                });
                
                } // End of Plotly loaded check
            </script>
        </body>
        </html>
        """
    }
    
    private func getInlinePlotlyJS() -> String {
        // Try to read plotly.min.js from the bundle
        if let plotlyURL = Bundle.main.url(forResource: "plotly.min", withExtension: "js"),
           let plotlyContent = try? String(contentsOf: plotlyURL, encoding: .utf8) {
            print("📦 PlotlyChartGenerator: Successfully loaded plotly.min.js inline (\(plotlyContent.count) characters)")
            return plotlyContent
        } else {
            print("❌ PlotlyChartGenerator: Failed to load plotly.min.js from bundle")
            // Return a minimal fallback that will trigger the error handler
            return "console.error('Plotly.js not found in bundle');"
        }
    }
    
    private func generateErrorHtml(_ message: String) -> String {
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Error</title>
        </head>
        <body>
            <div style="display: flex; justify-content: center; align-items: center; height: 100vh; text-align: center;">
                <div>
                    <h3>Plot Generation Error</h3>
                    <p>\(message)</p>
                </div>
            </div>
        </body>
        </html>
        """
    }
}

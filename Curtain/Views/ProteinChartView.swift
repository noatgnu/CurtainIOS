//
//  ProteinChartView.swift
//  Curtain
//
//  Created by Toan Phung on 05/08/2025.
//

import SwiftUI
import WebKit
import Foundation

struct ProteinChartView: View {
    let proteinId: String
    @Binding var curtainData: CurtainData
    @Binding var chartType: ProteinChartType
    @Binding var isPresented: Bool

    // Navigation support
    let proteinList: [String]
    let initialIndex: Int

    @State private var chartHtml: String = ""
    @State private var isLoading = true
    @State private var error: String?
    @State private var currentIndex: Int
    @State private var showingConditionColorManager = false
    @State private var showingIndividualYAxisLimits = false
    @State private var showingBracketSettings = false
    @Environment(\.colorScheme) var colorScheme
    
    // Initialize with protein list for swipe navigation
    init(proteinId: String, curtainData: Binding<CurtainData>, chartType: Binding<ProteinChartType>, isPresented: Binding<Bool>, proteinList: [String] = [], initialIndex: Int = 0) {
        self.proteinId = proteinId
        self._curtainData = curtainData
        self._chartType = chartType
        self._isPresented = isPresented
        self.proteinList = proteinList
        self.initialIndex = initialIndex
        self._currentIndex = State(initialValue: initialIndex)
    }
    
    // Current protein being displayed
    private var currentProteinId: String {
        guard currentIndex >= 0 && currentIndex < proteinList.count else {
            return proteinId // Fallback to original protein
        }
        return proteinList[currentIndex]
    }
    
    // Navigation state
    private var hasPreviousProtein: Bool {
        return currentIndex > 0
    }
    
    private var hasNextProtein: Bool {
        return currentIndex < proteinList.count - 1
    }
    
    private var displayName: String {
        // Use UniProt data directly from curtainData (proper approach)
        if let uniprotDB = curtainData.extraData?.uniprot?.db as? [String: Any],
           let uniprotRecord = uniprotDB[currentProteinId] as? [String: Any],
           let geneNames = uniprotRecord["Gene Names"] as? String,
           !geneNames.isEmpty {
            // Parse the first gene name from Gene Names string (can be space or semicolon separated)
            let firstGeneName = geneNames.components(separatedBy: CharacterSet(charactersIn: " ;"))
                .map { $0.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .first
            
            if let geneName = firstGeneName, geneName != currentProteinId {
                return "\(geneName) (\(currentProteinId))"
            }
        }
        
        return currentProteinId
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Chart type selector
                VStack(spacing: 12) {
                    HStack {
                        Text("Chart Type:")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        Picker("Chart Type", selection: $chartType) {
                            ForEach(ProteinChartType.allCases, id: \.self) { type in
                                Text(type.displayName).tag(type)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .frame(maxWidth: 250)
                    }
                    
                    // Navigation controls (only show if we have a protein list)
                    if proteinList.count > 1 {
                        HStack {
                            // Previous button
                            Button(action: {
                                navigateToPrevious()
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "chevron.left")
                                        .font(.caption)
                                    Text("Previous")
                                        .font(.caption)
                                }
                                .foregroundColor(hasPreviousProtein ? .blue : .gray)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(.systemGray6))
                                .clipShape(Capsule())
                            }
                            .disabled(!hasPreviousProtein)
                            
                            Spacer()
                            
                            // Position indicator
                            Text("\(currentIndex + 1) of \(proteinList.count)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            // Next button
                            Button(action: {
                                navigateToNext()
                            }) {
                                HStack(spacing: 4) {
                                    Text("Next")
                                        .font(.caption)
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                }
                                .foregroundColor(hasNextProtein ? .blue : .gray)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(.systemGray6))
                                .clipShape(Capsule())
                            }
                            .disabled(!hasNextProtein)
                        }
                    }
                    
                    Text(displayName)
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                .padding()
                .background(Color(.systemGray6))
                
                // Chart content with floating action button
                ZStack {
                    if isLoading {
                        VStack {
                            Spacer()
                            VStack(spacing: 16) {
                                ProgressView()
                                    .scaleEffect(1.2)
                                Text("Loading \(chartType.displayName.lowercased())...")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .onAppear {
                            }
                            Spacer()
                        }
                    } else if let error = error {
                        VStack {
                            Spacer()
                            VStack(spacing: 16) {
                                Image(systemName: "exclamationmark.triangle")
                                    .font(.system(size: 50))
                                    .foregroundColor(.orange)
                                
                                Text("Chart Error")
                                    .font(.title2)
                                    .fontWeight(.medium)
                                
                                Text(error)
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                            }
                            .onAppear {
                            }
                            Spacer()
                        }
                    } else {
                        ProteinChartWebView(htmlContent: chartHtml)
                            .onAppear {
                            }
                            .gesture(
                                // Add swipe gesture for navigation
                                DragGesture(minimumDistance: 50)
                                    .onEnded { value in
                                        handleSwipeGesture(value)
                                    }
                            )
                    }
                    
                    // Floating Action Buttons
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            VStack(spacing: 12) {
                                // Y-Axis Limits Button
                                Button(action: {
                                    showingIndividualYAxisLimits = true
                                }) {
                                    Image(systemName: "chart.bar.xaxis")
                                        .font(.title2)
                                        .foregroundColor(.white)
                                        .frame(width: 44, height: 44)
                                        .background(Color.orange)
                                        .clipShape(Circle())
                                        .shadow(radius: 4)
                                }
                                .disabled(isLoading)
                                .opacity(isLoading ? 0.5 : 1.0)

                                // Condition Colors Button
                                Button(action: {
                                    showingConditionColorManager = true
                                }) {
                                    Image(systemName: "chart.bar.fill")
                                        .font(.title2)
                                        .foregroundColor(.white)
                                        .frame(width: 44, height: 44)
                                        .background(Color.blue)
                                        .clipShape(Circle())
                                        .shadow(radius: 4)
                                }
                                .disabled(isLoading)
                                .opacity(isLoading ? 0.5 : 1.0)

                                // Condition Bracket Button (only for bar charts)
                                if chartType == .barChart || chartType == .averageBarChart {
                                    Button(action: {
                                        showingBracketSettings = true
                                    }) {
                                        Image(systemName: "curlybraces")
                                            .font(.title2)
                                            .foregroundColor(.white)
                                            .frame(width: 44, height: 44)
                                            .background(Color.purple)
                                            .clipShape(Circle())
                                            .shadow(radius: 4)
                                    }
                                    .disabled(isLoading)
                                    .opacity(isLoading ? 0.5 : 1.0)
                                }
                            }
                            .padding(.trailing, 16)
                            .padding(.bottom, 16)
                        }
                    }
                }
            }
            .navigationTitle("Protein Chart")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Close") {
                    isPresented = false
                },
                trailing: HStack {
                    Button("Export") {
                        // TODO: Export functionality
                    }
                    .disabled(isLoading || error != nil)
                }
            )
        }
        .sheet(isPresented: $showingConditionColorManager) {
            ConditionColorManagerView(curtainData: $curtainData)
        }
        .sheet(isPresented: $showingIndividualYAxisLimits) {
            IndividualYAxisLimitsSettingsView(curtainData: $curtainData, proteinId: currentProteinId)
        }
        .sheet(isPresented: $showingBracketSettings) {
            BarChartConditionBracketSettingsView(curtainData: $curtainData)
        }
        .onAppear {
            // Only load chart if it hasn't been loaded yet (initial state)
            // This prevents unnecessary redraws when app comes back from background
            if isLoading && error == nil && chartHtml.isEmpty {
                loadChart()
            } else {
            }
        }
        .onChange(of: chartType) { oldValue, newValue in
            loadChart()
        }
        .onChange(of: currentIndex) { oldValue, newValue in
            loadChart()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ProteinChartRefresh"))) { notification in
            // Reload the chart with updated colors
            loadChart()
        }
    }
    
    private func loadChart() {
        isLoading = true
        error = nil
        
        Task {
            do {
                let html = try await generateChartHtml()
                await MainActor.run {
                    self.chartHtml = html
                    self.isLoading = false
                }
            } catch {
                if let _ = error as? ChartGenerationError {
                }
                await MainActor.run {
                    self.error = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
    
    // MARK: - Navigation Functions
    
    private func navigateToPrevious() {
        guard hasPreviousProtein else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            currentIndex -= 1
        }
    }
    
    private func navigateToNext() {
        guard hasNextProtein else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            currentIndex += 1
        }
    }
    
    private func handleSwipeGesture(_ value: DragGesture.Value) {
        let swipeThreshold: CGFloat = 100
        let horizontalDistance = value.translation.width
        let verticalDistance = abs(value.translation.height)
        
        // Only process horizontal swipes (ignore vertical swipes)
        guard abs(horizontalDistance) > swipeThreshold && abs(horizontalDistance) > verticalDistance else {
            return
        }
        
        if horizontalDistance > 0 {
            // Swipe right -> go to previous protein
            navigateToPrevious()
        } else {
            // Swipe left -> go to next protein
            navigateToNext()
        }
    }
    
    private func generateChartHtml() async throws -> String {
        let startTime = Date()
        
        if let rawData = curtainData.raw {
            let lines = rawData.components(separatedBy: .newlines).filter { !$0.isEmpty }
            if !lines.isEmpty {
                _ = lines[0].components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            }
        } else {
        }
        

        let processingStart = Date()
        _ = await curtainData.getProcessedSettingsAsync { progress in
        }
        _ = Date().timeIntervalSince(processingStart)
        
        let generator = ProteinChartGenerator()
        let html = try await generator.generateProteinChart(
            proteinId: currentProteinId,
            curtainData: curtainData,
            chartType: chartType,
            isDarkMode: colorScheme == .dark
        )
        
        _ = Date().timeIntervalSince(startTime)
        if html.count < 100 {
        }
        return html
    }
}

struct ProteinChartWebView: UIViewRepresentable {
    let htmlContent: String
    
    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.scrollView.isScrollEnabled = true
        webView.scrollView.bounces = false
        webView.isOpaque = false
        webView.backgroundColor = UIColor.clear
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        if !htmlContent.isEmpty {
            webView.loadHTMLString(htmlContent, baseURL: nil)
        } else {
        }
    }
}

// MARK: - Protein Chart Generator

class ProteinChartGenerator {
    
    func generateProteinChart(proteinId: String, curtainData: CurtainData, chartType: ProteinChartType, isDarkMode: Bool) async throws -> String {

        // Check if we have raw CSV data to parse
        guard let rawCSV = curtainData.raw, !rawCSV.isEmpty else {
            throw ChartGenerationError.noRawData
        }

        // Parse the raw CSV data to extract sample-level intensity values
        let chartData = try await parseRawDataForProtein(proteinId: proteinId, rawCSV: rawCSV, curtainData: curtainData)


        guard !chartData.proteinValues.isEmpty else {
            throw ChartGenerationError.invalidProteinData
        }

        let plotData = createPlotData(chartData: chartData, chartType: chartType, curtainData: curtainData, isDarkMode: isDarkMode)

        let plotJSON = try plotData.toJSON()
        return generateChartHtmlTemplate(plotJSON: plotJSON, chartType: chartType)
    }
    
    private func parseRawDataForProtein(proteinId: String, rawCSV: String, curtainData: CurtainData) async throws -> ProteinChartData {

        let primaryIdColumn = curtainData.rawForm.primaryIDs
        let samples = curtainData.rawForm.samples
        let processedSettings = await curtainData.getProcessedSettingsAsync()
        let conditionOrder = processedSettings.conditionOrder
        _ = processedSettings.sampleMap
        
        
        // Parse tab-separated data into rows
        let lines = rawCSV.components(separatedBy: .newlines).filter { !$0.isEmpty }
        guard !lines.isEmpty else {
            throw ChartGenerationError.noRawData
        }
        
        // Get header row (tab-separated)
        let header = lines[0].components(separatedBy: "\t").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        
        // Find column indices
        guard let primaryIdIndex = header.firstIndex(of: primaryIdColumn) else {
            
            // Try to find similar columns
            let similarColumns = header.filter { $0.localizedCaseInsensitiveContains("index") || $0.localizedCaseInsensitiveContains("id") }
            if !similarColumns.isEmpty {
            }
            
            throw ChartGenerationError.invalidProteinData
        }
        
        // Find sample column indices
        var sampleIndices: [String: Int] = [:]
        for sample in samples {
            if let index = header.firstIndex(of: sample) {
                sampleIndices[sample] = index
            }
        }
        
        
        // Find the protein row
        var proteinValues: [String: Double] = [:]
        var proteinFound = false
        
        for (lineIndex, line) in lines.dropFirst().enumerated() { // Skip header
            let values = line.components(separatedBy: "\t").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            
            guard values.count > primaryIdIndex else { 
                if lineIndex < 3 {
                }
                continue 
            }
            
            let rowProteinId = values[primaryIdIndex]
            if lineIndex < 3 {
            }
            
            if rowProteinId == proteinId {
                proteinFound = true
                
                // Extract sample values
                for (sample, index) in sampleIndices {
                    guard values.count > index else { 
                        continue 
                    }
                    
                    let valueString = values[index]
                    if let value = Double(valueString), value.isFinite {
                        proteinValues[sample] = value
                        if proteinValues.count <= 5 {
                        }
                    } else {
                        // Treat invalid values as null (don't add to proteinValues)
                        if proteinValues.count <= 5 {
                        }
                    }
                }
                
                break
            }
        }
        
        if !proteinFound {
        }
        
        
        // Organize by conditions, respecting sampleVisible filter
        var conditionData: [String: [Double]] = [:]
        var conditionSamples: [String: [String]] = [:]
        
        
        for condition in conditionOrder {
            conditionData[condition] = []
            conditionSamples[condition] = []
            
            // Find all samples that belong to this condition
            // sampleMap is structured as [sampleName: [metadata]] where metadata contains "condition"
            let samplesForCondition = processedSettings.sampleMap.compactMap { (sampleName, metadata) -> String? in
                if let sampleCondition = metadata["condition"], sampleCondition == condition {
                    return sampleName
                }
                return nil
            }
            
            
            for sample in samplesForCondition {
                // IMPORTANT: Apply sampleVisible filter (like Android)
                // Only include samples where sampleVisible[sampleName] == true
                let isVisible = processedSettings.sampleVisible[sample] ?? true // Default to true if not specified
                
                
                if isVisible, let value = proteinValues[sample] {
                    conditionData[condition]?.append(value)
                    conditionSamples[condition]?.append(sample)
                }
            }
            
        }
        
        return ProteinChartData(
            proteinId: proteinId,
            samples: samples,
            conditions: conditionOrder,
            conditionData: conditionData,
            conditionSamples: conditionSamples,
            proteinValues: proteinValues
        )
    }
    
    
    private func createPlotData(chartData: ProteinChartData, chartType: ProteinChartType, curtainData: CurtainData, isDarkMode: Bool) -> PlotData {
        switch chartType {
        case .barChart:
            return createBarChart(chartData: chartData, curtainData: curtainData, isDarkMode: isDarkMode)
        case .averageBarChart:
            return createAverageBarChart(chartData: chartData, curtainData: curtainData, isDarkMode: isDarkMode)
        case .violinPlot:
            return createViolinPlot(chartData: chartData, curtainData: curtainData, isDarkMode: isDarkMode)
        }
    }
    
    private func createBarChart(chartData: ProteinChartData, curtainData: CurtainData, isDarkMode: Bool) -> PlotData {
        // Android INDIVIDUAL_BAR implementation - exact replication with grouping and dividers
        var xValues: [Int] = []          // Use indices instead of sample names
        var yValues: [Double] = []
        var colors: [String] = []
        var hoverText: [String] = []
        var sampleNames: [String] = []   // Keep sample names for hover

        // Track position info for grouping and dividers
        var tickvals: [Double] = []    // Positions for condition labels (x-axis indices)
        var ticktext: [String] = []    // Condition names
        var shapes: [PlotShape] = []   // Separator lines
        var currentPosition = 0

        // Track condition positions for bracket drawing
        var conditionPositions: [String: (start: Int, end: Int)] = [:]

        // Store info for horizontal condition highlight lines (to be drawn after loop when total is known)
        var conditionHighlightInfo: [(condition: String, start: Int, end: Int)] = []

        // Process data exactly like Android: iterate through conditions in order
        for (conditionIndex, condition) in chartData.conditions.enumerated() {
            guard let values = chartData.conditionData[condition],
                  let samples = chartData.conditionSamples[condition] else { continue }

            let conditionColor = getConditionColor(condition: condition, curtainData: curtainData)
            let startPosition = currentPosition

            // Add each sample as individual bar (Android approach)
            for (index, sample) in samples.enumerated() {
                let value = values[index]

                xValues.append(currentPosition)  // Use position index
                yValues.append(value)
                colors.append(conditionColor)
                sampleNames.append(sample)

                // Android hover template: sampleName, value, condition
                hoverText.append("<b>\(sample)</b><br>Value: \(String(format: "%.3f", value))<br>Condition: \(condition)")
                currentPosition += 1
            }

            // Calculate middle position for condition label (using x-axis indices)
            // For samples at positions [0,1,2] the middle is at 1.0
            // For samples at positions [3,4,5,6] the middle is at 4.5
            let endPosition = currentPosition - 1
            let middlePosition = Double(startPosition + endPosition) / 2.0
            tickvals.append(middlePosition)
            ticktext.append(condition)

            // Store condition positions for bracket drawing
            conditionPositions[condition] = (start: startPosition, end: endPosition)

            // Store info for horizontal line if this is left or right condition
            let isLeftCondition = condition == curtainData.settings.volcanoConditionLabels.leftCondition
            let isRightCondition = condition == curtainData.settings.volcanoConditionLabels.rightCondition

            if (isLeftCondition || isRightCondition) && curtainData.settings.barChartConditionBracket.showBracket {
                conditionHighlightInfo.append((condition: condition, start: startPosition, end: currentPosition))
            }

            // Add separator line after each condition group (except the last one)
            if conditionIndex < chartData.conditions.count - 1 {
                let separatorPosition = Double(currentPosition) - 0.5
                shapes.append(PlotShape(
                    type: "line",
                    x0: separatorPosition,
                    x1: separatorPosition,
                    y0: 0,
                    y1: nil,  // Will be set to ymax in layout
                    xref: "x",  // Use data coordinates
                    yref: "paper",
                    line: PlotLine(
                        color: "rgba(0,0,0,0.5)",  // Android semi-transparent black
                        width: 1,
                        dash: "dash"  // Android dashed line
                    ),
                    isYAxisLine: nil
                ))
            }
        }

        // Now that we know the total sample count, add horizontal lines for left/right conditions
        let totalSamples = currentPosition
        for info in conditionHighlightInfo {
            // Calculate paper coordinates using total sample count (Android pattern)
            let x0 = Double(info.start) / Double(totalSamples)
            let x1 = Double(info.end) / Double(totalSamples)
            let width = x1 - x0
            let padding = width * 0.1  // 10% padding on each side

            // Add horizontal line at y=1.02 spanning the condition width
            shapes.append(PlotShape(
                type: "line",
                x0: x0 + padding,
                x1: x1 - padding,
                y0: 1.02,
                y1: 1.02,
                xref: "paper",
                yref: "paper",
                line: PlotLine(
                    color: curtainData.settings.barChartConditionBracket.bracketColor,
                    width: Double(curtainData.settings.barChartConditionBracket.bracketWidth),
                    dash: nil
                ),
                isYAxisLine: nil
            ))
        }

        // Add condition bracket shapes if enabled
        if let bracketShapes = createBarChartConditionBrackets(
            settings: curtainData.settings,
            conditionPositions: conditionPositions,
            totalSamples: totalSamples
        ) {
            shapes.append(contentsOf: bracketShapes)
        }

        // Single trace with all bars (Android pattern)
        let trace = PlotTrace(
            x: xValues,  // Use indices for proper tick positioning
            y: yValues,
            mode: "markers",
            type: "bar",
            name: "",  // No name needed
            marker: PlotMarker(
                color: colors,
                size: 10,
                symbol: nil,
                line: PlotLine(color: "rgba(0,0,0,0.3)", width: 1, dash: nil)  // Android border
            ),
            text: hoverText,
            textposition: "none",  // Hide text on bars, but keep for hover
            hovertemplate: "%{text}<extra></extra>",  // Use text for hover
            customdata: nil
        )

        // Android layout configuration with custom grouping
        let defaultYRange = [0.0, (yValues.max() ?? 1.0) * 1.1]
        let finalYRange = applyGlobalYAxisLimits(chartType: .barChart, defaultRange: defaultYRange, curtainData: curtainData, proteinId: chartData.proteinId)

        let layout = createAndroidIndividualBarChartLayout(
            title: "\(getProteinDisplayName(chartData.proteinId, curtainData: curtainData))",
            yRange: finalYRange,
            tickvals: tickvals,
            ticktext: ticktext,
            shapes: shapes,
            curtainData: curtainData,
            sampleCount: currentPosition,
            isDarkMode: isDarkMode
        )

        let config = createAndroidChartConfig()

        return PlotData(traces: [trace], layout: layout, config: config)
    }
    
    private func createAverageBarChart(chartData: ProteinChartData, curtainData: CurtainData, isDarkMode: Bool) -> PlotData {
        // Android AVERAGE_BAR implementation - exact replication
        var traces: [PlotTrace] = []
        var xValues: [String] = []
        var yValues: [Double] = []
        var errorValues: [Double] = []
        var colors: [String] = []
        
        // Collect individual sample data for dot overlay
        var allDotXValues: [String] = []
        var allDotYValues: [Double] = []
        
        // Track condition indices for bracket drawing
        var conditionIndices: [String: Int] = [:]

        // Statistical calculations matching Android exactly
        for (index, condition) in chartData.conditions.enumerated() {
            guard let values = chartData.conditionData[condition], !values.isEmpty else { continue }

            // Android statistical calculations
            let mean = values.reduce(0, +) / Double(values.count)
            let variance = values.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(values.count)
            let std = sqrt(variance)
            let standardError = std / sqrt(Double(values.count))  // Android uses SE

            let conditionColor = getConditionColor(condition: condition, curtainData: curtainData)

            xValues.append(condition)
            yValues.append(mean)
            errorValues.append(standardError)
            colors.append(conditionColor)

            // Store condition index for bracket drawing
            conditionIndices[condition] = index

            // Collect individual sample values for dots (Android feature)
            for value in values {
                allDotXValues.append(condition)  // Each dot uses condition name as x
                allDotYValues.append(value)      // Individual sample values
            }
        }
        
        // Get color scheme appropriate colors for dots and error bars (Android pattern)
        let dotColor = isDarkMode ? "#adb5bd" : "#654949"  // Light gray in dark mode, dark brown in light mode
        let errorBarColor = isDarkMode ? "#FFFFFF" : "#000000"  // White in dark mode, black in light mode
        let barBorderColor = isDarkMode ? "#FFFFFF" : "#000000"  // White in dark mode, black in light mode

        // Main bar trace with error bars (Android configuration)
        let barTrace = PlotTrace(
            x: xValues,
            y: yValues,
            mode: "markers",
            type: "bar",
            name: "",  // No name needed
            marker: PlotMarker(
                color: colors,
                size: 10,
                symbol: nil,
                line: PlotLine(color: barBorderColor, width: 1, dash: nil)  // Android border with contrast
            ),
            text: nil,
            hovertemplate: "<b>%{x}</b><br>Mean: %{y:.3f}<extra></extra>",  // Android hover
            customdata: nil,
            error_y: PlotErrorBar(
                type: "data",
                array: errorValues,
                visible: true,
                color: errorBarColor,  // Android error bars with proper contrast
                thickness: 2,         // Android thickness
                width: 4              // Android width
            )
        )
        traces.append(barTrace)

        // Individual sample dots overlay (Android feature)
        let dotTrace = PlotTrace(
            x: allDotXValues,
            y: allDotYValues,
            mode: "markers",
            type: "scatter",
            name: "",  // No legend
            marker: PlotMarker(
                color: dotColor,      // Android color scheme-aware dots
                size: 6,              // Android 6px markers
                symbol: "circle",
                line: nil,
                opacity: 0.8          // Android opacity for better visibility
            ),
            text: nil,
            hovertemplate: "<b>%{x}</b><br>Value: %{y:.3f}<extra></extra>",  // Android hover for individual points
            customdata: nil
        )
        traces.append(dotTrace)

        // Create bracket shapes if enabled
        let totalConditions = chartData.conditions.count
        var bracketShapes: [PlotShape] = []
        if let shapes = createAverageBarChartConditionBrackets(
            settings: curtainData.settings,
            conditionIndices: conditionIndices,
            totalConditions: totalConditions
        ) {
            bracketShapes = shapes
        }

        // Android layout configuration
        let defaultYRange = [0.0, (yValues.max() ?? 1.0) * 1.15]  // Extra space for error bars
        let finalYRange = applyGlobalYAxisLimits(chartType: .averageBarChart, defaultRange: defaultYRange, curtainData: curtainData, proteinId: chartData.proteinId)

        let layout = createAndroidAverageChartLayout(
            title: "\(getProteinDisplayName(chartData.proteinId, curtainData: curtainData))",
            yRange: finalYRange,
            shapes: bracketShapes,
            curtainData: curtainData,
            conditionCount: chartData.conditions.count,
            isDarkMode: isDarkMode
        )

        let config = createAndroidChartConfig()

        return PlotData(traces: traces, layout: layout, config: config)
    }
    
    private func calculateStandardError(values: [Double]) -> Double {
        guard values.count > 1 else { return 0.0 }
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.reduce(0) { sum, value in
            sum + pow(value - mean, 2)
        } / Double(values.count - 1)
        let standardDeviation = sqrt(variance)
        return standardDeviation / sqrt(Double(values.count))  // Standard Error = SD / sqrt(N)
    }
    
    private func createViolinPlot(chartData: ProteinChartData, curtainData: CurtainData, isDarkMode: Bool) -> PlotData {
        // Android VIOLIN_PLOT implementation - exact replication
        var traces: [PlotTrace] = []

        // Track condition indices for bracket drawing
        var conditionIndices: [String: Int] = [:]

        // Create one trace per condition (Android approach)
        for (index, condition) in chartData.conditions.enumerated() {
            guard let values = chartData.conditionData[condition],
                  let _ = chartData.conditionSamples[condition],
                  !values.isEmpty else { continue }

            let conditionColor = getConditionColor(condition: condition, curtainData: curtainData)

            // Store condition index for bracket drawing
            conditionIndices[condition] = index

            // Calculate Android-style statistics for enhanced hover
            let mean = values.reduce(0, +) / Double(values.count)
            let variance = values.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(values.count)
            let std = sqrt(variance)
            let sortedValues = values.sorted()
            let median = sortedValues.count % 2 == 0
                ? (sortedValues[sortedValues.count / 2 - 1] + sortedValues[sortedValues.count / 2]) / 2.0
                : sortedValues[sortedValues.count / 2]

            // Create enhanced hover template with all statistics (Android-style)
            let hoverTemplate = "<b>%{x}</b><br>" +
                "Value: %{y:.3f}<br>" +
                "Mean: \(String(format: "%.3f", mean))<br>" +
                "Median: \(String(format: "%.3f", median))<br>" +
                "Std: \(String(format: "%.3f", std))<br>" +
                "N: \(values.count)<extra></extra>"

            // Android violin plot trace configuration - exact match
            let trace = PlotTrace(
                x: Array(repeating: condition, count: values.count),
                y: values,
                mode: "markers",       // Android mode
                type: "violin",
                name: condition,       // Android uses condition name
                marker: PlotMarker(
                    color: conditionColor,
                    size: 4,           // Android point size
                    symbol: "circle",
                    line: nil,         // No marker border in Android
                    opacity: 0.7       // Android marker opacity
                ),
                text: nil,
                hovertemplate: hoverTemplate,  // Android enhanced hover with stats
                customdata: nil,
                // Android violin plot exact settings
                violinmode: nil,        // Android doesn't set violinmode for individual traces
                box_visible: true,      // Show box plot overlay with white fill
                meanline_visible: true, // Show mean line (red in Android)
                points: "all",          // Show all individual points
                pointpos: curtainData.settings.violinPointPos,  // Configurable point position (-2 to 2)
                jitter: nil,           // Android doesn't set jitter (uses default)
                fillcolor: conditionColor,
                line_color: "black",    // Android uses black violin outline
                // Additional Android properties
                spanmode: "soft",       // Smooth kernel density estimation
                bandwidth: "auto",      // Automatic bandwidth selection
                scalemode: "width",     // Scale violin width consistently
                selected: PlotMarker(   // Android selection state
                    color: "#e61010",
                    size: 6,
                    symbol: "circle",
                    line: nil,
                    opacity: 1.0        // Full opacity when selected
                ),
                unselected: PlotMarker( // Android unselected state
                    color: conditionColor,
                    size: 4,
                    symbol: "circle",
                    line: nil,
                    opacity: 0.3        // Reduced opacity when unselected
                )
            )
            traces.append(trace)
        }

        // Create bracket shapes if enabled
        let totalConditions = chartData.conditions.count
        var bracketShapes: [PlotShape] = []
        if let shapes = createAverageBarChartConditionBrackets(
            settings: curtainData.settings,
            conditionIndices: conditionIndices,
            totalConditions: totalConditions
        ) {
            bracketShapes = shapes
        }

        // Android layout configuration
        let yValues = chartData.conditionData.values.flatMap { $0 }
        let defaultYRange = [(yValues.min() ?? 0.0) * 0.95, (yValues.max() ?? 1.0) * 1.05]
        let finalYRange = applyGlobalYAxisLimits(chartType: .violinPlot, defaultRange: defaultYRange, curtainData: curtainData, proteinId: chartData.proteinId)

        let layout = createAndroidViolinLayout(
            title: "\(getProteinDisplayName(chartData.proteinId, curtainData: curtainData))",
            yRange: finalYRange,
            curtainData: curtainData,
            conditionCount: chartData.conditions.count,
            bracketShapes: bracketShapes,
            isDarkMode: isDarkMode
        )

        let config = createAndroidChartConfig()

        return PlotData(traces: traces, layout: layout, config: config)
    }
    
    private func createChartLayoutWithDividers(title: String, xAxisTitle: String, yAxisTitle: String, curtainData: CurtainData, xValues: [String], yRange: [Double]) -> PlotLayout {
        // Create base layout
        let baseLayout = createChartLayout(title: title, xAxisTitle: xAxisTitle, yAxisTitle: yAxisTitle, curtainData: curtainData)
        
        // Add divider lines between conditions (like Android)
        var shapes: [PlotShape] = []
        for i in 0..<(xValues.count - 1) {
            let dividerX = Double(i) + 0.5  // Position between bars
            shapes.append(PlotShape(
                type: "line",
                x0: dividerX,
                x1: dividerX,
                y0: yRange[0],
                y1: yRange[1] * 1.1,  // Extend slightly above
                xref: "x",
                yref: "y",
                line: PlotLine(color: "#cccccc", width: 1, dash: "dash"),
                isYAxisLine: nil
            ))
        }
        
        return PlotLayout(
            title: baseLayout.title,
            xaxis: baseLayout.xaxis,
            yaxis: baseLayout.yaxis,
            hovermode: baseLayout.hovermode,
            showlegend: baseLayout.showlegend,
            plot_bgcolor: baseLayout.plot_bgcolor,
            paper_bgcolor: baseLayout.paper_bgcolor,
            font: baseLayout.font,
            shapes: shapes,  // Add divider shapes
            annotations: baseLayout.annotations,
            legend: baseLayout.legend
        )
    }
    
    private func createChartLayout(title: String, xAxisTitle: String, yAxisTitle: String, curtainData: CurtainData) -> PlotLayout {
        // Android-style layout: White background, black borders, clean typography
        let plotTitle = PlotTitle(
            text: title,
            font: PlotFont(
                family: "Arial",  // Android uses Arial
                size: 14,         // Android uses 14px bold titles
                color: "#000000"  // Black text like Android
            )
        )
        
        let xaxis = PlotAxis(
            title: PlotAxisTitle(
                text: xAxisTitle,
                font: PlotFont(family: "Arial", size: 10, color: "#000000")  // Android uses 10px axis labels
            ),
            zeroline: false,
            zerolinecolor: nil,
            gridcolor: "#e0e0e0",  // Light gray grid like Android
            range: nil,
            font: PlotFont(family: "Arial", size: 10, color: "#000000"),
            dtick: nil,
            ticklen: 4,  // Android uses 4px tick length
            showgrid: true
        )
        
        let yaxis = PlotAxis(
            title: PlotAxisTitle(
                text: yAxisTitle,
                font: PlotFont(family: "Arial", size: 10, color: "#000000")
            ),
            zeroline: true,
            zerolinecolor: "#000000",  // Black zero line
            gridcolor: "#e0e0e0",
            range: nil,
            font: PlotFont(family: "Arial", size: 10, color: "#000000"),
            dtick: nil,
            ticklen: 4,
            showgrid: true
        )
        
        return PlotLayout(
            title: plotTitle,
            xaxis: xaxis,
            yaxis: yaxis,
            hovermode: "closest",
            showlegend: true,
            plot_bgcolor: "#ffffff",     // White background like Android
            paper_bgcolor: "#ffffff",    // White paper background like Android
            font: PlotFont(family: "Arial", size: 10, color: "#000000"),
            shapes: nil,
            annotations: nil,
            legend: PlotLegend(
                orientation: "h",  // Horizontal legend like Android
                x: 0.5,
                xanchor: "center",
                y: -0.15,           // Position below chart like Android
                yanchor: "top"
            )
        )
    }
    
    private func createChartConfig() -> PlotConfig {
        // Android-style config: Disable mode bar, enable responsiveness
        return PlotConfig(
            responsive: true,
            displayModeBar: false,    // Android: always hidden
            editable: false,          // Android: disable Plotly editing
            scrollZoom: false,        // Android: disable scroll zoom for consistency
            doubleClick: "reset"      // Android: enable double-click reset
        )
    }
    
    private func createChartConfigWithoutLegend() -> PlotConfig {
        // Same as createChartConfig but designed for charts that don't need legends
        return PlotConfig(
            responsive: true,
            displayModeBar: false,
            editable: false,
            scrollZoom: false,
            doubleClick: "reset"
        )
    }
    
    private func createBarChartLayoutWithConditionDividers(
        title: String,
        xAxisTitle: String,
        yAxisTitle: String,
        curtainData: CurtainData,
        xValues: [String],
        yRange: [Double],
        conditionPositions: [String: (start: Int, end: Int)]
    ) -> PlotLayout {
        // Create base layout
        let baseLayout = createChartLayout(title: title, xAxisTitle: xAxisTitle, yAxisTitle: yAxisTitle, curtainData: curtainData)
        
        // Create divider lines between condition groups
        var shapes: [PlotShape] = []
        var annotations: [PlotAnnotation] = []
        
        let conditions = Array(conditionPositions.keys).sorted()
        
        // Add dividers between condition groups (not between individual bars)
        for i in 0..<(conditions.count - 1) {
            let currentCondition = conditions[i]
            guard let currentRange = conditionPositions[currentCondition] else { continue }
            
            // Position divider after the last bar of current condition
            let dividerX = Double(currentRange.end) + 0.5

            shapes.append(PlotShape(
                type: "line",
                x0: dividerX,
                x1: dividerX,
                y0: yRange[0],
                y1: yRange[1],
                xref: "x",
                yref: "y",
                line: PlotLine(color: "#cccccc", width: 1, dash: "dash"),
                isYAxisLine: nil
            ))
        }
        
        // Add condition labels at the center of each group
        for condition in conditions {
            guard let range = conditionPositions[condition] else { continue }
            
            let centerX = Double(range.start + range.end) / 2.0
            
            annotations.append(PlotAnnotation(
                id: "condition-\(condition)",
                title: "condition-\(condition)",
                text: condition,
                x: centerX,
                y: yRange[1] * 0.95,  // Position near top of chart
                xref: nil,  // Use default data coordinates
                yref: nil,  // Use default data coordinates
                showarrow: false,
                arrowhead: nil,
                arrowsize: nil,
                arrowwidth: nil,
                arrowcolor: nil,
                ax: nil,
                ay: nil,
                xanchor: "center",
                yanchor: "bottom",
                font: PlotFont(family: "Arial", size: 12, color: "#000000")
            ))
        }
        
        // Return layout with dividers, condition labels, and no legend
        return PlotLayout(
            title: baseLayout.title,
            xaxis: PlotAxis(
                title: PlotAxisTitle(text: "Samples", font: PlotFont(family: "Arial", size: 10, color: "#000000")),
                zeroline: false,
                zerolinecolor: nil,
                gridcolor: "#e0e0e0",
                range: nil,
                font: PlotFont(family: "Arial", size: 8, color: "#000000"),  // Smaller font for sample names
                dtick: nil,
                ticklen: 4,
                showgrid: true
            ),
            yaxis: baseLayout.yaxis,
            hovermode: baseLayout.hovermode,
            showlegend: false,  // No legend needed - conditions shown as annotations
            plot_bgcolor: baseLayout.plot_bgcolor,
            paper_bgcolor: baseLayout.paper_bgcolor,
            font: baseLayout.font,
            shapes: shapes,
            annotations: annotations,
            legend: nil  // No legend
        )
    }
    
    // MARK: - Android Layout Functions
    
    private func createAndroidChartConfig() -> PlotConfig {
        // Android exact configuration
        return PlotConfig(
            responsive: true,
            displayModeBar: false,  // Android: always disabled
            editable: false,        // Android: always disabled
            scrollZoom: false,      // Android: always disabled
            doubleClick: "reset"    // Android: enable double-click reset
        )
    }
    
    private func createAndroidBarChartLayout(title: String, yRange: [Double]) -> PlotLayout {
        // Android Individual Bar Chart layout - exact configuration
        return PlotLayout(
            title: nil,  // Remove title - already have header title
            xaxis: PlotAxis(
                title: PlotAxisTitle(
                    text: "Conditions",
                    font: PlotFont(family: "Arial", size: 10, color: "#000000", dash: nil)
                ),
                zeroline: false,
                zerolinecolor: nil,
                gridcolor: "#e0e0e0",
                range: nil,
                font: PlotFont(family: "Arial", size: 10, color: "#000000", dash: nil),
                dtick: nil,
                ticklen: nil,
                showgrid: true,
                tickangle: 0,      // Android: horizontal labels
                type: "category",  // Android: categorical axis
                automargin: true   // Android: auto margin
            ),
            yaxis: PlotAxis(
                title: PlotAxisTitle(
                    text: "Intensity",
                    font: PlotFont(family: "Arial", size: 10, color: "#000000", dash: nil)
                ),
                zeroline: true,
                zerolinecolor: "#000000",
                gridcolor: "#e0e0e0",
                range: yRange,
                font: PlotFont(family: "Arial", size: 10, color: "#000000", dash: nil),
                dtick: nil,
                ticklen: nil,
                showgrid: true,
                automargin: true
            ),
            hovermode: "closest",
            showlegend: false,      // Android: no legend for individual bars
            plot_bgcolor: "#ffffff",
            paper_bgcolor: "#ffffff",
            font: PlotFont(family: "Arial", size: 10, color: "#000000", dash: nil),
            shapes: nil,
            annotations: nil,
            legend: nil,
            margin: PlotMargin(left: 50, right: 20, top: 20, bottom: 100)  // Android margins
        )
    }
    
    private func createAndroidIndividualBarChartLayout(
        title: String,
        yRange: [Double],
        tickvals: [Double],
        ticktext: [String],
        shapes: [PlotShape],
        curtainData: CurtainData,
        sampleCount: Int,
        isDarkMode: Bool
    ) -> PlotLayout {
        // Android Individual Bar Chart with custom grouping and dividers

        // Get colors appropriate for current color scheme
        let textColor = isDarkMode ? "#FFFFFF" : "#000000"
        let gridColor = isDarkMode ? "#404040" : "#e0e0e0"
        let zeroLineColor = isDarkMode ? "#606060" : "#000000"
        let bgColor = isDarkMode ? "#1c1c1e" : "#ffffff"

        // Update shapes to have proper y1 values
        let updatedShapes = shapes.map { shape in
            PlotShape(
                type: shape.type,
                x0: shape.x0,
                x1: shape.x1,
                y0: shape.y0,
                y1: 1.0,  // Set to top of chart in paper coordinates
                xref: shape.xref,
                yref: shape.yref,
                line: shape.line,
                isYAxisLine: shape.isYAxisLine
            )
        }

        // Calculate width based on columnSize if set (Android formula)
        // width = marginLeft + marginRight + (columnSize × sampleCount)
        let plotWidth: Int?
        if let columnSize = curtainData.settings.columnSize["barChart"], columnSize > 0 {
            plotWidth = 50 + 20 + (columnSize * sampleCount)  // margins + (columnSize × sampleCount)
        } else {
            plotWidth = nil  // Auto width
        }

        // Calculate top margin based on whether brackets are shown
        // Bracket extends to y = 1.02 + bracketHeight in paper coordinates
        // Need sufficient margin to display the bracket above the plot
        let topMargin: Int
        if curtainData.settings.barChartConditionBracket.showBracket {
            // Calculate required margin: (0.02 + bracketHeight) needs space
            // Assuming typical plot height ~600px, allocate proportional margin
            let bracketExtension = 0.02 + curtainData.settings.barChartConditionBracket.bracketHeight
            topMargin = max(80, Int(bracketExtension * 600))  // At least 80px, or proportional to bracket
        } else {
            topMargin = 20  // Default minimal margin
        }

        return PlotLayout(
            title: nil,  // Remove title as requested - already have header title
            xaxis: PlotAxis(
                title: PlotAxisTitle(
                    text: "Conditions",
                    font: PlotFont(family: "Arial", size: 10, color: textColor)
                ),
                zeroline: false,
                zerolinecolor: nil,
                gridcolor: gridColor,
                range: nil,
                font: PlotFont(family: "Arial", size: 10, color: textColor),
                dtick: nil,
                ticklen: nil,
                showgrid: true,
                tickangle: 0,
                type: "category",
                automargin: true,
                tickmode: "array",      // Android custom tick mode
                tickvals: tickvals,     // Positions for condition labels
                ticktext: ticktext      // Condition names as labels
            ),
            yaxis: PlotAxis(
                title: PlotAxisTitle(
                    text: "Intensity",
                    font: PlotFont(family: "Arial", size: 10, color: textColor)
                ),
                zeroline: true,
                zerolinecolor: zeroLineColor,
                gridcolor: gridColor,
                range: yRange,
                font: PlotFont(family: "Arial", size: 10, color: textColor),
                dtick: nil,
                ticklen: nil,
                showgrid: true,
                automargin: true
            ),
            hovermode: "closest",
            showlegend: false,
            plot_bgcolor: bgColor,
            paper_bgcolor: bgColor,
            font: PlotFont(family: "Arial", size: 10, color: textColor),
            shapes: updatedShapes,   // Separator lines between condition groups
            annotations: nil,
            legend: nil,
            margin: PlotMargin(left: 50, right: 20, top: topMargin, bottom: 100),
            width: plotWidth,  // Optional width based on column size
            height: nil  // Auto height
        )
    }
    
    private func createAndroidAverageChartLayout(title: String, yRange: [Double], shapes: [PlotShape]? = nil, curtainData: CurtainData, conditionCount: Int, isDarkMode: Bool) -> PlotLayout {
        // Android Average Bar Chart layout - exact configuration

        // Get colors appropriate for current color scheme
        let textColor = isDarkMode ? "#FFFFFF" : "#000000"
        let gridColor = isDarkMode ? "#404040" : "#e0e0e0"
        let zeroLineColor = isDarkMode ? "#606060" : "#000000"
        let bgColor = isDarkMode ? "#1c1c1e" : "#ffffff"

        // Calculate width based on columnSize if set (Android formula)
        // width = marginLeft + marginRight + (columnSize × conditionCount)
        let plotWidth: Int?
        if let columnSize = curtainData.settings.columnSize["averageBarChart"], columnSize > 0 {
            plotWidth = 50 + 20 + (columnSize * conditionCount)  // margins + (columnSize × conditionCount)
        } else {
            plotWidth = nil  // Auto width
        }

        // Calculate top margin based on whether brackets are shown
        let topMargin: Int
        if curtainData.settings.barChartConditionBracket.showBracket {
            let bracketExtension = 0.02 + curtainData.settings.barChartConditionBracket.bracketHeight
            topMargin = max(80, Int(bracketExtension * 600))
        } else {
            topMargin = 20
        }

        return PlotLayout(
            title: nil,  // Remove title - already have header title
            xaxis: PlotAxis(
                title: PlotAxisTitle(
                    text: "Conditions",
                    font: PlotFont(family: "Arial", size: 10, color: textColor, dash: nil)
                ),
                zeroline: false,
                zerolinecolor: nil,
                gridcolor: gridColor,
                range: nil,
                font: PlotFont(family: "Arial", size: 10, color: textColor, dash: nil),
                dtick: nil,
                ticklen: nil,
                showgrid: true,
                tickangle: 0,
                type: "category",
                automargin: true
            ),
            yaxis: PlotAxis(
                title: PlotAxisTitle(
                    text: "Intensity",
                    font: PlotFont(family: "Arial", size: 10, color: textColor, dash: nil)
                ),
                zeroline: true,
                zerolinecolor: zeroLineColor,
                gridcolor: gridColor,
                range: yRange,
                font: PlotFont(family: "Arial", size: 10, color: textColor, dash: nil),
                dtick: nil,
                ticklen: nil,
                showgrid: true,
                automargin: true
            ),
            hovermode: "closest",
            showlegend: false,      // Android: no legend for average bars
            plot_bgcolor: bgColor,
            paper_bgcolor: bgColor,
            font: PlotFont(family: "Arial", size: 10, color: textColor, dash: nil),
            shapes: shapes,  // Support condition brackets
            annotations: nil,
            legend: nil,
            margin: PlotMargin(left: 50, right: 20, top: topMargin, bottom: 100),
            width: plotWidth,  // Optional width based on column size
            height: nil  // Auto height
        )
    }
    
    private func createAndroidViolinLayout(title: String, yRange: [Double], curtainData: CurtainData, conditionCount: Int, bracketShapes: [PlotShape], isDarkMode: Bool) -> PlotLayout {
        // Android Violin Plot layout - exact configuration

        // Get colors appropriate for current color scheme
        let textColor = isDarkMode ? "#FFFFFF" : "#000000"
        let gridColor = isDarkMode ? "#404040" : "#e0e0e0"
        let zeroLineColor = isDarkMode ? "#606060" : "#000000"
        let bgColor = isDarkMode ? "#1c1c1e" : "#ffffff"

        // Calculate width based on columnSize if set (Android formula)
        // width = marginLeft + marginRight + (columnSize × conditionCount)
        let plotWidth: Int?
        if let columnSize = curtainData.settings.columnSize["violinPlot"], columnSize > 0 {
            plotWidth = 50 + 20 + (columnSize * conditionCount)  // margins + (columnSize × conditionCount)
        } else {
            plotWidth = nil  // Auto width
        }

        // Calculate top margin based on whether brackets are shown
        let topMargin: Int
        if curtainData.settings.barChartConditionBracket.showBracket {
            let bracketExtension = 0.02 + curtainData.settings.barChartConditionBracket.bracketHeight
            topMargin = max(80, Int(bracketExtension * 600))
        } else {
            topMargin = 20
        }

        return PlotLayout(
            title: nil,  // Remove title - already have header title
            xaxis: PlotAxis(
                title: PlotAxisTitle(
                    text: "Conditions",
                    font: PlotFont(family: "Arial", size: 10, color: textColor, dash: nil)
                ),
                zeroline: false,
                zerolinecolor: nil,
                gridcolor: gridColor,
                range: nil,
                font: PlotFont(family: "Arial", size: 10, color: textColor, dash: nil),
                dtick: nil,
                ticklen: nil,
                showgrid: true,
                tickangle: 0,
                type: "category",
                automargin: true
            ),
            yaxis: PlotAxis(
                title: PlotAxisTitle(
                    text: "Intensity",
                    font: PlotFont(family: "Arial", size: 10, color: textColor, dash: nil)
                ),
                zeroline: true,
                zerolinecolor: zeroLineColor,
                gridcolor: gridColor,
                range: yRange,
                font: PlotFont(family: "Arial", size: 10, color: textColor, dash: nil),
                dtick: nil,
                ticklen: nil,
                showgrid: true,
                automargin: true
            ),
            hovermode: "closest",
            showlegend: false,      // Android: no legend for violin plots
            plot_bgcolor: bgColor,
            paper_bgcolor: bgColor,
            font: PlotFont(family: "Arial", size: 10, color: textColor, dash: nil),
            shapes: bracketShapes.isEmpty ? nil : bracketShapes,  // Add bracket shapes if any
            annotations: nil,
            legend: nil,
            margin: PlotMargin(left: 50, right: 20, top: topMargin, bottom: 100),
            width: plotWidth,  // Optional width based on column size
            height: nil  // Auto height
        )
    }
    
    // MARK: - Color Management
    
    private func getConditionColor(condition: String, curtainData: CurtainData) -> String {
        // Android Color Assignment Priority (matching ConditionColorService.kt):
        // 1. barchartColorMap (protein-specific overrides) - highest priority
        // 2. colorMap (general condition colors)  
        // 3. Default palette assignment
        
        // First priority: barchartColorMap (protein-specific overrides)
        if let color = curtainData.settings.barchartColorMap[condition] as? String, !color.isEmpty {
            return color
        }
        
        // Second priority: general colorMap
        if let color = curtainData.settings.colorMap[condition], !color.isEmpty {
            return color
        }
        
        // Third priority: Android Default Color Palettes (Pastel palette as default)
        let androidPastelColors = [
            "#fd7f6f",  // Red
            "#7eb0d5",  // Blue  
            "#b2e061",  // Green
            "#bd7ebe",  // Purple
            "#ffb55a",  // Orange
            "#ffee65",  // Yellow
            "#beb9db",  // Light Purple
            "#fdcce5",  // Pink
            "#8bd3c7",  // Teal
            "#b3de69"   // Light Green
        ]
        
        let conditionIndex = curtainData.settings.conditionOrder.firstIndex(of: condition) ?? 0
        let defaultColor = androidPastelColors[conditionIndex % androidPastelColors.count]
        return defaultColor
    }
    
    
    private func getProteinDisplayName(_ proteinId: String, curtainData: CurtainData) -> String {
        // Use UniProt data directly from curtainData (proper approach)
        if let uniprotDB = curtainData.extraData?.uniprot?.db as? [String: Any],
           let uniprotRecord = uniprotDB[proteinId] as? [String: Any],
           let geneNames = uniprotRecord["Gene Names"] as? String,
           !geneNames.isEmpty {
            // Parse the first gene name from Gene Names string (can be space or semicolon separated)
            let firstGeneName = geneNames.components(separatedBy: CharacterSet(charactersIn: " ;"))
                .map { $0.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .first
            
            if let geneName = firstGeneName, geneName != proteinId {
                return "\(geneName) (\(proteinId))"
            }
        }
        
        return proteinId
    }

    /// Apply Y-axis limits from settings (individual overrides global)
    /// Priority: individual limits > global limits > default calculated range
    private func applyGlobalYAxisLimits(chartType: ProteinChartType, defaultRange: [Double], curtainData: CurtainData, proteinId: String? = nil) -> [Double] {
        // Map chart type to settings key
        let settingsKey: String
        switch chartType {
        case .barChart:
            settingsKey = "barChart"
        case .averageBarChart:
            settingsKey = "averageBarChart"
        case .violinPlot:
            settingsKey = "violinPlot"
        }

        // PRIORITY 1: Check for individual protein-specific limits (highest priority)
        if let proteinId = proteinId,
           let individualLimitsForProtein = curtainData.settings.individualYAxisLimits[proteinId] as? [String: [String: Double]],
           let chartLimitsDict = individualLimitsForProtein[settingsKey] {
            // Extract min/max from the dictionary
            let minY = chartLimitsDict["min"] ?? defaultRange[0]
            let maxY = chartLimitsDict["max"] ?? defaultRange[1]

            return [minY, maxY]
        }

        // PRIORITY 2: Check for global limits (medium priority)
        if let globalLimits = curtainData.settings.chartYAxisLimits[settingsKey] {
            let minY = globalLimits.min ?? defaultRange[0]
            let maxY = globalLimits.max ?? defaultRange[1]

            // Only log if actually using custom limits (not just defaults)
            if globalLimits.min != nil || globalLimits.max != nil {
            }
            return [minY, maxY]
        }

        // PRIORITY 3: Use default calculated range (lowest priority)
        return defaultRange
    }

    /// Create bracket shapes connecting two conditions in bar chart (if enabled)
    /// Returns array of PlotShape for the bracket (left vertical, horizontal, right vertical)
    private func createBarChartConditionBrackets(
        settings: CurtainSettings,
        conditionPositions: [String: (start: Int, end: Int)],
        totalSamples: Int
    ) -> [PlotShape]? {
        // Check if bracket is enabled
        guard settings.barChartConditionBracket.showBracket else {
            return nil
        }

        // Get left and right conditions from volcano settings
        let leftCondition = settings.volcanoConditionLabels.leftCondition
        let rightCondition = settings.volcanoConditionLabels.rightCondition

        // Validate conditions are not empty
        guard !leftCondition.isEmpty, !rightCondition.isEmpty else {
            return nil
        }

        // Get position ranges for both conditions
        guard let leftPos = conditionPositions[leftCondition],
              let rightPos = conditionPositions[rightCondition] else {
            return nil
        }

        // Calculate paper coordinates (normalized 0-1 range) - Android pattern
        // Divide by totalSamples (not totalSamples - 1) to match Android behavior
        let leftX0 = Double(leftPos.start) / Double(totalSamples)
        let leftX1 = Double(leftPos.end + 1) / Double(totalSamples)  // end+1 because end is inclusive
        let rightX0 = Double(rightPos.start) / Double(totalSamples)
        let rightX1 = Double(rightPos.end + 1) / Double(totalSamples)  // end+1 because end is inclusive

        // Calculate middle positions for each condition
        let leftMidX = (leftX0 + leftX1) / 2.0
        let rightMidX = (rightX0 + rightX1) / 2.0

        // Bracket Y positions (above the plot)
        let baseY = 1.02  // Just above plot area
        let bracketY = baseY + settings.barChartConditionBracket.bracketHeight

        // Create PlotLine for bracket styling
        let bracketLine = PlotLine(
            color: settings.barChartConditionBracket.bracketColor,
            width: Double(settings.barChartConditionBracket.bracketWidth),
            dash: nil
        )

        var bracketShapes: [PlotShape] = []

        // Left vertical line: from (leftMidX, baseY) to (leftMidX, bracketY)
        bracketShapes.append(PlotShape(
            type: "line",
            x0: leftMidX,
            x1: leftMidX,
            y0: baseY,
            y1: bracketY,
            xref: "paper",
            yref: "paper",
            line: bracketLine,
            isYAxisLine: nil
        ))

        // Horizontal connector: from (leftMidX, bracketY) to (rightMidX, bracketY)
        bracketShapes.append(PlotShape(
            type: "line",
            x0: leftMidX,
            x1: rightMidX,
            y0: bracketY,
            y1: bracketY,
            xref: "paper",
            yref: "paper",
            line: bracketLine,
            isYAxisLine: nil
        ))

        // Right vertical line: from (rightMidX, bracketY) to (rightMidX, baseY)
        bracketShapes.append(PlotShape(
            type: "line",
            x0: rightMidX,
            x1: rightMidX,
            y0: bracketY,
            y1: baseY,
            xref: "paper",
            yref: "paper",
            line: bracketLine,
            isYAxisLine: nil
        ))


        return bracketShapes
    }

    /// Create bracket shapes connecting two conditions in average bar chart (if enabled)
    /// For categorical x-axis, paper coordinates are calculated differently
    private func createAverageBarChartConditionBrackets(
        settings: CurtainSettings,
        conditionIndices: [String: Int],
        totalConditions: Int
    ) -> [PlotShape]? {
        // Check if bracket is enabled
        guard settings.barChartConditionBracket.showBracket else {
            return nil
        }

        // Get left and right conditions from volcano settings
        let leftCondition = settings.volcanoConditionLabels.leftCondition
        let rightCondition = settings.volcanoConditionLabels.rightCondition

        // Validate conditions are not empty
        guard !leftCondition.isEmpty, !rightCondition.isEmpty else {
            return nil
        }

        // Get indices for both conditions
        guard let leftIndex = conditionIndices[leftCondition],
              let rightIndex = conditionIndices[rightCondition] else {
            return nil
        }

        guard totalConditions > 0 else {
            return nil
        }

        // For categorical x-axis, each condition occupies 1/totalConditions of the plot width
        // Condition at index i spans from i/totalConditions to (i+1)/totalConditions
        let leftX0 = Double(leftIndex) / Double(totalConditions)
        let leftX1 = Double(leftIndex + 1) / Double(totalConditions)
        let rightX0 = Double(rightIndex) / Double(totalConditions)
        let rightX1 = Double(rightIndex + 1) / Double(totalConditions)

        // Calculate middle positions for bracket vertical lines
        let leftMidX = (leftX0 + leftX1) / 2.0
        let rightMidX = (rightX0 + rightX1) / 2.0

        // Bracket Y positions (above the plot)
        let baseY = 1.02  // Just above plot area
        let bracketY = baseY + settings.barChartConditionBracket.bracketHeight

        // Create PlotLine for bracket styling
        let bracketLine = PlotLine(
            color: settings.barChartConditionBracket.bracketColor,
            width: Double(settings.barChartConditionBracket.bracketWidth),
            dash: nil
        )

        var bracketShapes: [PlotShape] = []

        // Add horizontal lines highlighting each condition (Android pattern)
        // Left condition horizontal line
        let leftWidth = leftX1 - leftX0
        let leftPadding = leftWidth * 0.1
        bracketShapes.append(PlotShape(
            type: "line",
            x0: leftX0 + leftPadding,
            x1: leftX1 - leftPadding,
            y0: baseY,
            y1: baseY,
            xref: "paper",
            yref: "paper",
            line: bracketLine,
            isYAxisLine: nil
        ))

        // Right condition horizontal line
        let rightWidth = rightX1 - rightX0
        let rightPadding = rightWidth * 0.1
        bracketShapes.append(PlotShape(
            type: "line",
            x0: rightX0 + rightPadding,
            x1: rightX1 - rightPadding,
            y0: baseY,
            y1: baseY,
            xref: "paper",
            yref: "paper",
            line: bracketLine,
            isYAxisLine: nil
        ))

        // Left vertical line: from (leftMidX, baseY) to (leftMidX, bracketY)
        bracketShapes.append(PlotShape(
            type: "line",
            x0: leftMidX,
            x1: leftMidX,
            y0: baseY,
            y1: bracketY,
            xref: "paper",
            yref: "paper",
            line: bracketLine,
            isYAxisLine: nil
        ))

        // Horizontal connector: from (leftMidX, bracketY) to (rightMidX, bracketY)
        bracketShapes.append(PlotShape(
            type: "line",
            x0: leftMidX,
            x1: rightMidX,
            y0: bracketY,
            y1: bracketY,
            xref: "paper",
            yref: "paper",
            line: bracketLine,
            isYAxisLine: nil
        ))

        // Right vertical line: from (rightMidX, bracketY) to (rightMidX, baseY)
        bracketShapes.append(PlotShape(
            type: "line",
            x0: rightMidX,
            x1: rightMidX,
            y0: bracketY,
            y1: baseY,
            xref: "paper",
            yref: "paper",
            line: bracketLine,
            isYAxisLine: nil
        ))


        return bracketShapes
    }

    private func calculateStandardDeviation(values: [Double], mean: Double) -> Double {
        let variance = values.reduce(0) { sum, value in
            sum + pow(value - mean, 2)
        } / Double(values.count - 1)
        return sqrt(variance)
    }
    
    private func generateChartHtmlTemplate(plotJSON: String, chartType: ProteinChartType) -> String {
        do {
            let htmlTemplate = try WebTemplateLoader.shared.loadHTMLTemplate(named: "protein-chart")
            var proteinChartJS = try WebTemplateLoader.shared.loadJavaScript(named: "protein-chart")

            proteinChartJS = proteinChartJS.replacingOccurrences(of: "{{PLOT_DATA}}", with: plotJSON)
            proteinChartJS = proteinChartJS.replacingOccurrences(of: "{{CHART_TITLE}}", with: chartType.displayName)

            let substitutions: [String: String] = [
                "CHART_TITLE": chartType.displayName,
                "LOADING_MESSAGE": "Loading \(chartType.displayName.lowercased())...",
                "PLOTLY_JS": getInlinePlotlyJS(),
                "PROTEIN_CHART_JS": proteinChartJS
            ]

            return WebTemplateLoader.shared.render(template: htmlTemplate, substitutions: substitutions)
        } catch {
            return """
            <!DOCTYPE html>
            <html><body>
            <div style="display: flex; justify-content: center; align-items: center; height: 100vh; text-align: center;">
                <div><h3>Template Error</h3><p>Failed to load chart template: \(error.localizedDescription)</p></div>
            </div>
            </body></html>
            """
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
}

// MARK: - Data Models

struct ProteinChartData {
    let proteinId: String
    let samples: [String]
    let conditions: [String]
    let conditionData: [String: [Double]]
    let conditionSamples: [String: [String]]
    let proteinValues: [String: Double]
}

enum ChartGenerationError: Error {
    case noRawData
    case invalidProteinData
    case plotGenerationFailed
    
    var localizedDescription: String {
        switch self {
        case .noRawData:
            return "No raw sample data available for chart generation"
        case .invalidProteinData:
            return "Invalid protein data format"
        case .plotGenerationFailed:
            return "Failed to generate plot data"
        }
    }
}
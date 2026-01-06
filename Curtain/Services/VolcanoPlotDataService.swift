//
//  VolcanoPlotDataService.swift
//  Curtain
//
//  Created by Toan Phung on 04/08/2025.
//

import Foundation

// MARK: - Volcano Plot Data Service (Like Android VolcanoPlotTabFragment)

class VolcanoPlotDataService {
    
    // MARK: - Main Processing Method (Like Android processVolcanoData)
    
    func processVolcanoData(curtainData: CurtainData, settings: CurtainSettings) async -> VolcanoProcessResult {
        print("🔍 VolcanoPlotDataService: Starting volcano data processing (like Android)")
        
        let diffForm = curtainData.differentialForm
        let fcColumn = diffForm.foldChange
        let sigColumn = diffForm.significant
        let idColumn = diffForm.primaryIDs
        let geneColumn = diffForm.geneNames
        let comparisonColumn = diffForm.comparison
        
        print("🔍 VolcanoPlotDataService: Using columns - FC: \(fcColumn), Sig: \(sigColumn), ID: \(idColumn), Gene: \(geneColumn)")
        
        var jsonData: [[String: Any]] = []
        var minFC = Double.greatestFiniteMagnitude
        var maxFC = -Double.greatestFiniteMagnitude
        var maxLogP = 0.0
        
        // Get processed data (like Android)
        guard let processedData = curtainData.extraData?.data?.dataMap as? [String: Any],
              let differentialData = processedData["processedDifferentialData"] as? [[String: Any]] else {
            print("❌ VolcanoPlotDataService: No processedDifferentialData found")
            return VolcanoProcessResult(jsonData: [], colorMap: [:], updatedVolcanoAxis: settings.volcanoAxis)
        }
        
        print("🔍 VolcanoPlotDataService: Processing \(differentialData.count) differential data points")
        
        // Color assignment logic (like Android)
        var colorMap = settings.colorMap
        let selectOperationNames = extractSelectionNames(from: curtainData)
        
        assignColorsToSelections(selectOperationNames, &colorMap, settings)
        
        // Process each data point (like Android) - use EXACT user-specified primary ID column
        for row in differentialData {
            // CRITICAL: Use exactly the primary ID column specified by user, never guess
            guard !idColumn.isEmpty else {
                print("❌ VolcanoPlotDataService: Primary ID column not specified by user")  
                continue
            }
            
            guard let id = row[idColumn] as? String, !id.isEmpty else {
                if row[idColumn] != nil {
                    print("❌ VolcanoPlotDataService: Invalid primary ID in column '\(idColumn)': \(row[idColumn] ?? "nil") (type: \(type(of: row[idColumn])))")
                }
                continue
            }

            // Gene name resolution workflow: UniProt > gene column > ID (like Android)
            let gene = resolveGeneName(for: id, row: row, geneColumn: geneColumn, curtainData: curtainData)
            
            // Extract and validate numeric values (like Android)
            let fcValue = extractDoubleValue(row[fcColumn])
            let sigValue = extractDoubleValue(row[sigColumn])
            
            guard !fcValue.isNaN && !sigValue.isNaN else { continue }
            
            minFC = min(minFC, fcValue)
            maxFC = max(maxFC, fcValue)
            maxLogP = max(maxLogP, sigValue)
            
            // Extract comparison value from the row (like Android)
            let comparisonValue: String
            if comparisonColumn.isEmpty {
                comparisonValue = "1"  // Default like Android
            } else {
                comparisonValue = row[comparisonColumn] as? String ?? "1"
            }
            
            // Determine trace group and color (like Android)
            let (selections, selectionColors) = determineTraceGroupAndColors(
                id: id,
                fcValue: fcValue,
                sigValue: sigValue,
                comparison: comparisonValue,  // Pass actual comparison value, not column name
                curtainData: curtainData,
                settings: settings,
                colorMap: colorMap
            )
            
            // Extract custom text if specified
            var customText: String? = nil
            if !settings.customVolcanoTextCol.isEmpty {
                // Try to get value from custom column
                if let customValue = row[settings.customVolcanoTextCol] {
                    customText = String(describing: customValue)
                    print("🔍 VolcanoPlotDataService: Using custom text column '\(settings.customVolcanoTextCol)': '\(customText ?? "nil")'")
                }
            }

            // Create data point for Plotly (like Android JSON structure)
            var dataPoint: [String: Any] = [
                "x": fcValue,
                "y": sigValue,
                "id": id,
                "gene": gene.replacingOccurrences(of: "\"", with: "\\\"").replacingOccurrences(of: "'", with: "\\'"),
                "comparison": comparisonValue,
                "selections": selections,
                "colors": selectionColors,
                "color": selectionColors.first ?? "#808080"
            ]

            // Add custom text if available
            if let customText = customText {
                dataPoint["customText"] = customText
            }
            
            jsonData.append(dataPoint)
        }
        
        // Update volcano axis settings (like Android)
        let updatedVolcanoAxis = VolcanoAxis(
            minX: settings.volcanoAxis.minX ?? (minFC - 1.0),
            maxX: settings.volcanoAxis.maxX ?? (maxFC + 1.0),
            minY: settings.volcanoAxis.minY ?? 0.0,
            maxY: settings.volcanoAxis.maxY ?? (maxLogP + 1.0),
            x: settings.volcanoAxis.x.isEmpty ? "Fold Change" : settings.volcanoAxis.x,
            y: settings.volcanoAxis.y.isEmpty ? "-log10(p-value)" : settings.volcanoAxis.y,
            dtickX: settings.volcanoAxis.dtickX,
            dtickY: settings.volcanoAxis.dtickY,
            ticklenX: settings.volcanoAxis.ticklenX,
            ticklenY: settings.volcanoAxis.ticklenY
        )
        
        print("🔍 VolcanoPlotDataService: Generated \(jsonData.count) plot points")
        
        return VolcanoProcessResult(
            jsonData: jsonData,
            colorMap: colorMap,
            updatedVolcanoAxis: updatedVolcanoAxis
        )
    }
    
    // MARK: - Gene Name Resolution (Like Android)
    
    private func resolveGeneName(for id: String, row: [String: Any], geneColumn: String, curtainData: CurtainData) -> String {
        var gene = id
        
        // Step 1: Try UniProt lookup (like Android)
        if curtainData.fetchUniprot {
            if let uniprotDB = curtainData.extraData?.uniprot?.db as? [String: Any],
               let uniprotRecord = uniprotDB[id] as? [String: Any],
               let geneNames = uniprotRecord["Gene Names"] as? String,
               !geneNames.isEmpty {
                gene = geneNames
                return gene
            }
        }
        
        // Step 2: Try gene column (like Android)
        if !geneColumn.isEmpty,
           let geneFromColumn = row[geneColumn] as? String,
           !geneFromColumn.isEmpty {
            gene = geneFromColumn
        }
        
        // Step 3: Fallback to ID (already set)
        return gene
    }
    
    // MARK: - Helper Methods
    
    private func extractDoubleValue(_ value: Any?) -> Double {
        switch value {
        case let number as NSNumber:
            let doubleValue = number.doubleValue
            return doubleValue.isNaN ? 0.0 : doubleValue
        case let string as String:
            return Double(string) ?? 0.0
        default:
            return 0.0
        }
    }
    
    private func extractSelectionNames(from curtainData: CurtainData) -> Set<String> {
        var selectOperationNames = Set<String>()
        
        // Extract from selectedMap (like Android)
        if let selectedMap = curtainData.selectedMap {
            for (_, selections) in selectedMap {
                for (selectionName, isSelected) in selections {
                    if isSelected {
                        selectOperationNames.insert(selectionName)
                    }
                }
            }
        }
        
        return selectOperationNames
    }
    
    // MARK: - Color Assignment Algorithm (Like Android)
    
    private func assignColorsToSelections(_ selectOperationNames: Set<String>, _ colorMap: inout [String: String], _ settings: CurtainSettings) {
        let defaultColorList = settings.defaultColorList
        var currentColors: [String] = []
        
        // Collect currently used colors (like Android)
        for (_, color) in colorMap {
            if defaultColorList.contains(color) {
                currentColors.append(color)
            }
        }
        
        // Set current position for color assignment (like Android)
        var currentPosition = 0
        if currentColors.count < defaultColorList.count {
            currentPosition = currentColors.count
        }
        
        // Assign colors using Android logic
        var breakColor = false
        var shouldRepeat = false
        
        for s in selectOperationNames {
            if colorMap[s] == nil {
                while true {
                    if breakColor {
                        colorMap[s] = defaultColorList[currentPosition]
                        break
                    }
                    
                    if currentColors.contains(defaultColorList[currentPosition]) {
                        currentPosition += 1
                        if shouldRepeat {
                            colorMap[s] = defaultColorList[currentPosition]
                            currentPosition = 0
                            breakColor = true
                            break
                        }
                    } else if currentPosition >= defaultColorList.count {
                        currentPosition = 0
                        colorMap[s] = defaultColorList[currentPosition]
                        shouldRepeat = true
                        break
                    } else {
                        colorMap[s] = defaultColorList[currentPosition]
                        break
                    }
                }
                
                currentPosition += 1
                if currentPosition == defaultColorList.count {
                    currentPosition = 0
                }
            }
        }
    }
    
    // MARK: - Trace Group Determination (Like Android)
    
    private func determineTraceGroupAndColors(
        id: String,
        fcValue: Double,
        sigValue: Double,
        comparison: String,
        curtainData: CurtainData,
        settings: CurtainSettings,
        colorMap: [String: String]
    ) -> ([String], [String]) {
        
        var selections: [String] = []
        var colors: [String] = []
        
        // Check user selections first (like Android)
        // Android: val selectionForId: Map<String, Boolean>? = curtainData.selectedMap[id] as? Map<String, Boolean>
        if let selectedMap = curtainData.selectedMap,
           let selectionForId = selectedMap[id] {
            for (selectionName, isSelected) in selectionForId {
                if isSelected && colorMap[selectionName] != nil {
                    selections.append(selectionName)
                    colors.append(colorMap[selectionName] ?? "#808080")
                }
            }
        }
        
        // If no user selections, assign to significance group (like Android)
        if selections.isEmpty {
            let (significantGroup, _) = getSignificantGroup(fcValue: fcValue, sigValue: sigValue, settings: settings, comparison: comparison)
            selections.append(significantGroup)
            colors.append(colorMap[significantGroup] ?? "#cccccc")
        }
        
        return (selections, colors)
    }
    
    // MARK: - Significance Group Classification (Like Android)
    
    private func getSignificantGroup(fcValue: Double, sigValue: Double, settings: CurtainSettings, comparison: String) -> (String, String) {
        let ylog = -log10(settings.pCutoff)
        var groups: [String] = []
        var position = ""
        
        // P-value classification
        if sigValue < ylog {
            groups.append("P-value > \(settings.pCutoff)")
            position = "P-value > "
        } else {
            groups.append("P-value <= \(settings.pCutoff)")
            position = "P-value <= "
        }
        
        // Fold change classification
        if abs(fcValue) > settings.log2FCCutoff {
            groups.append("FC > \(settings.log2FCCutoff)")
            position += "FC > "
        } else {
            groups.append("FC <= \(settings.log2FCCutoff)")
            position += "FC <= "
        }
        
        // Create full group name with comparison (like Android)
        let groupText = groups.joined(separator: ";")
        let fullGroupName = "\(groupText) (\(comparison))"
        
        return (fullGroupName, position)
    }
}

// MARK: - Data Structures

struct VolcanoProcessResult {
    let jsonData: [[String: Any]]
    let colorMap: [String: String]
    let updatedVolcanoAxis: VolcanoAxis
}
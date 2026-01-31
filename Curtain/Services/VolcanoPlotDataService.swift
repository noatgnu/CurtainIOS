import Foundation
import GRDB

class VolcanoPlotDataService {
    private let proteomicsDataService = ProteomicsDataService.shared
    private let proteomicsDataDatabaseManager = ProteomicsDataDatabaseManager.shared
    private let proteinMappingService = ProteinMappingService.shared
    
    // MARK: - Legacy In-Memory Processing
    
    func processVolcanoData(curtainData: AppData, settings: CurtainSettings) async -> VolcanoProcessResult {
        let diffForm = curtainData.differentialForm!
        let fcColumn = diffForm.foldChange
        let sigColumn = diffForm.significant
        let idColumn = diffForm.primaryIDs
        let geneColumn = diffForm.geneNames
        let comparisonColumn = diffForm.comparison
        
        var minFC = Double.greatestFiniteMagnitude
        var maxFC = -Double.greatestFiniteMagnitude
        var maxLogP = 0.0
        
        var differentialData: [[String: Any]] = []
        if let processedData = curtainData.dataMap,
           let data = processedData["processedDifferentialData"] as? [[String: Any]] {
            differentialData = data
        }
        
        if differentialData.isEmpty, let processedString = curtainData.differential?.originalFile, !processedString.isEmpty {
            differentialData = parseRawProcessedString(rawContent: processedString, diffForm: diffForm)
        }
        
        if differentialData.isEmpty {
            return VolcanoProcessResult(jsonData: [], colorMap: [:], updatedVolcanoAxis: settings.volcanoAxis)
        }
        
        var colorMap = settings.colorMap
        let selectOperationNames = extractSelectionNames(from: curtainData)
        var colorIndex = assignColorsToSelections(selectOperationNames, &colorMap, settings)
        
        var jsonData: [[String: Any]] = []
        var firstValidPoint = true
        
        for row in differentialData {
            guard !idColumn.isEmpty else { continue }
            guard let id = row[idColumn] as? String, !id.isEmpty else { continue }

            let gene = resolveGeneName(for: id, row: row, geneColumn: geneColumn, curtainData: curtainData)
            
            let fcValue = extractDoubleValue(row[fcColumn])
            let sigValue = extractDoubleValue(row[sigColumn])
            
            guard !fcValue.isNaN && !sigValue.isNaN && !fcValue.isInfinite && !sigValue.isInfinite else { continue }
            
            if firstValidPoint {
                minFC = fcValue
                maxFC = fcValue
                maxLogP = sigValue
                firstValidPoint = false
            } else {
                minFC = min(minFC, fcValue)
                maxFC = max(maxFC, fcValue)
                maxLogP = max(maxLogP, sigValue)
            }
            
            let comparisonValue = comparisonColumn.isEmpty ? "1" : (row[comparisonColumn] as? String ?? "1")
            
            var selections: [String] = []
            var colors: [String] = []
            var hasUserSelection = false

            if let selectionForId = curtainData.selectedMap[id] {
                for (name, isSelected) in selectionForId {
                    if isSelected, let color = colorMap[name] {
                        if let match = name.range(of: #"\(([^)]*)\)[^(]*$"#, options: .regularExpression),
                           let captureRange = name.range(of: #"\([^)]*\)"#, options: .regularExpression, range: match) {
                            let extractedComparison = String(name[captureRange].dropFirst().dropLast())
                            if extractedComparison == comparisonValue {
                                selections.append(name)
                                colors.append(color)
                                hasUserSelection = true
                            }
                        } else {
                            selections.append(name)
                            colors.append(color)
                            hasUserSelection = true
                        }
                    }
                }
            }
            
            if !hasUserSelection {
                if settings.backGroundColorGrey {
                    selections.append("Background")
                    colors.append("#a4a2a2")
                } else {
                    let (group, _) = getSignificantGroup(fcValue: fcValue, sigValue: sigValue, settings: settings, comparison: comparisonValue)
                    selections.append(group)
                    
                    if colorMap[group] == nil {
                        let defaultColors = settings.defaultColorList
                        if !defaultColors.isEmpty {
                            colorMap[group] = defaultColors[colorIndex % defaultColors.count]
                            colorIndex += 1
                        } else {
                            colorMap[group] = "#cccccc"
                        }
                    }
                    colors.append(colorMap[group] ?? "#cccccc")
                }
            }

            var dataPoint: [String: Any] = [
                "x": fcValue,
                "y": sigValue,
                "id": id,
                "gene": gene.replacingOccurrences(of: "\"", with: "\\\"").replacingOccurrences(of: "'", with: "\'\'"),
                "comparison": comparisonValue,
                "selections": selections,
                "colors": colors,
                "color": colors.first ?? "#808080"
            ]

            if !settings.customVolcanoTextCol.isEmpty, let customValue = row[settings.customVolcanoTextCol] {
                dataPoint["customText"] = String(describing: customValue)
            }
            
            jsonData.append(dataPoint)
        }
        
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
        
        return VolcanoProcessResult(jsonData: jsonData, colorMap: colorMap, updatedVolcanoAxis: updatedVolcanoAxis)
    }

    // MARK: - New SQLite Processing

    func processVolcanoData(linkId: String, settingsEntity: CurtainSettingsEntity) throws -> VolcanoProcessResult {
        guard let settings = settingsEntity.getSettings(),
              let diffForm = settingsEntity.getDifferentialForm() else {
            return VolcanoProcessResult(jsonData: [], colorMap: [:], updatedVolcanoAxis: VolcanoAxis())
        }
        return try processVolcanoData(linkId: linkId, settings: settings, differentialForm: diffForm)
    }

    /// SQLite-based volcano data processing using settings directly
    func processVolcanoData(linkId: String, settings: CurtainSettings, differentialForm: CurtainDifferentialForm) throws -> VolcanoProcessResult {

        // Fetch processed data from SQLite
        let processedData = try proteomicsDataService.getAllProcessedData(linkId: linkId)

        // Debug: Log gene name resolution
        let withGeneNames = processedData.filter { $0.geneNames != nil && !($0.geneNames?.isEmpty ?? true) }.count
        print("[VolcanoPlotDataService] Total proteins: \(processedData.count), with geneNames: \(withGeneNames)")
        if let first = processedData.first {
            print("[VolcanoPlotDataService] First protein: id=\(first.primaryId), geneNames=\(first.geneNames ?? "nil")")
        }

        // Fetch metadata for selections
        let metadata = try proteomicsDataService.getCurtainMetadata(linkId: linkId)

        var selectedMap: [String: [String: Bool]] = [:]
        if let json = metadata?.selectedMapJson,
           let data = json.data(using: .utf8) {
            selectedMap = (try? JSONDecoder().decode([String: [String: Bool]].self, from: data)) ?? [:]
        }

        // Process data
        var jsonData: [[String: Any]] = []
        var colorMap = settings.colorMap
        var minFC = Double.greatestFiniteMagnitude
        var maxFC = -Double.greatestFiniteMagnitude
        var maxLogP = 0.0
        var firstValidPoint = true

        let selectOperationNames = extractSelectionNames(from: selectedMap)
        var colorIndex = assignColorsToSelections(selectOperationNames, &colorMap, settings)

        for entity in processedData {
            let id = entity.primaryId
            if id.isEmpty { continue }

            let fcValue = entity.foldChange ?? 0.0
            let sigValue = entity.significant ?? 0.0
            let comparisonValue = entity.comparison

            // Resolve gene name using priority: 1) entity.geneNames, 2) mapping service, 3) primaryId
            var geneName = id
            var geneSource = "primaryId"
            if let gn = entity.geneNames, !gn.isEmpty {
                // Get first gene name from the column value
                let firstGene = gn.components(separatedBy: CharacterSet(charactersIn: " ;\\"))
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                    .first
                geneName = firstGene ?? gn
                geneSource = "entity.geneNames"
            } else if let gn = proteinMappingService.getGeneNameFromPrimaryId(linkId: linkId, primaryId: id), !gn.isEmpty {
                geneName = gn
                geneSource = "mappingService"
            }

            // Debug: log first few gene name resolutions
            if jsonData.count < 5 {
                print("[VolcanoPlotDataService] Gene resolution for \(id): '\(geneName)' from \(geneSource)")
            }

            guard !fcValue.isNaN && !sigValue.isNaN && !fcValue.isInfinite && !sigValue.isInfinite else { continue }

            if firstValidPoint {
                minFC = fcValue
                maxFC = fcValue
                maxLogP = sigValue
                firstValidPoint = false
            } else {
                minFC = min(minFC, fcValue)
                maxFC = max(maxFC, fcValue)
                maxLogP = max(maxLogP, sigValue)
            }

            // Selection and color assignment
            var selections: [String] = []
            var colors: [String] = []
            var hasUserSelection = false

            if let selectionForId = selectedMap[id] {
                for (name, isSelected) in selectionForId {
                    if isSelected, let color = colorMap[name] {
                        // Check if the selection is comparison-specific
                        if let match = name.range(of: #"\(([^)]*)\)[^(]*$"#, options: .regularExpression),
                           let captureRange = name.range(of: #"\([^)]*\)"#, options: .regularExpression, range: match) {
                            let extractedComparison = String(name[captureRange].dropFirst().dropLast())
                            if extractedComparison == comparisonValue {
                                selections.append(name)
                                colors.append(color)
                                hasUserSelection = true
                            }
                        } else {
                            selections.append(name)
                            colors.append(color)
                            hasUserSelection = true
                        }
                    }
                }
            }

            if !hasUserSelection {
                if settings.backGroundColorGrey {
                    selections.append("Background")
                    colors.append("#a4a2a2")
                } else {
                    let (group, _) = getSignificantGroup(fcValue: fcValue, sigValue: sigValue, settings: settings, comparison: comparisonValue)
                    selections.append(group)

                    if colorMap[group] == nil {
                        let defaultColors = settings.defaultColorList
                        if !defaultColors.isEmpty {
                            colorMap[group] = defaultColors[colorIndex % defaultColors.count]
                            colorIndex += 1
                        } else {
                            colorMap[group] = "#cccccc"
                        }
                    }
                    colors.append(colorMap[group] ?? "#cccccc")
                }
            }

            var dataPoint: [String: Any] = [
                "x": fcValue,
                "y": sigValue,
                "id": id,
                "gene": geneName.replacingOccurrences(of: "\"", with: "\\\"").replacingOccurrences(of: "'", with: "\'\'"),
                "comparison": comparisonValue,
                "selections": selections,
                "colors": colors,
                "color": colors.first ?? "#808080"
            ]

            if !settings.customVolcanoTextCol.isEmpty {
                // Custom text column would need to be stored separately if needed
                dataPoint["customText"] = ""
            }

            jsonData.append(dataPoint)
        }

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

        return VolcanoProcessResult(jsonData: jsonData, colorMap: colorMap, updatedVolcanoAxis: updatedVolcanoAxis)
    }

    private func extractSelectionNames(from selectedMap: [String: [String: Bool]]) -> Set<String> {
        var names = Set<String>()
        for (_, selections) in selectedMap {
            for (name, isSelected) in selections where isSelected {
                names.insert(name)
            }
        }
        return names
    }

    private func getDatabaseURL(for linkId: String) -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let curtainDataDir = documentsPath.appendingPathComponent("CurtainData", isDirectory: true)
        return curtainDataDir.appendingPathComponent("proteomics_data_\(linkId).sqlite")
    }
    
    private func parseRawProcessedString(rawContent: String, diffForm: RawForm? = nil) -> [[String: Any]] {
        return []
    }
    
    private func parseRawProcessedString(rawContent: String, diffForm: DifferentialForm) -> [[String: Any]] {
        let lines = rawContent.components(separatedBy: .newlines)
        if lines.isEmpty { return [] }
        
        let headers = lines[0].components(separatedBy: "\t").map { $0.trimmingCharacters(in: .whitespaces) }
        var data: [[String: Any]] = []
        
        let fcIndex = headers.firstIndex { $0.caseInsensitiveCompare(diffForm.foldChange.trimmingCharacters(in: .whitespaces)) == .orderedSame }
        let sigIndex = headers.firstIndex { $0.caseInsensitiveCompare(diffForm.significant.trimmingCharacters(in: .whitespaces)) == .orderedSame }
        let idIndex = headers.firstIndex { $0.caseInsensitiveCompare(diffForm.primaryIDs.trimmingCharacters(in: .whitespaces)) == .orderedSame }
        let geneIndex = headers.firstIndex { $0.caseInsensitiveCompare(diffForm.geneNames.trimmingCharacters(in: .whitespaces)) == .orderedSame }
        let compIndex = headers.firstIndex { $0.caseInsensitiveCompare(diffForm.comparison.trimmingCharacters(in: .whitespaces)) == .orderedSame }
        
        if fcIndex == nil || sigIndex == nil || idIndex == nil { return [] }
        
        for i in 1..<lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }
            let cols = line.components(separatedBy: "\t")
            let maxIndex = [fcIndex, sigIndex, idIndex].compactMap { $0 }.max() ?? 0
            if cols.count <= maxIndex { continue }
            
            var rowMap: [String: Any] = [: ]
            for j in 0..<cols.count where j < headers.count {
                rowMap[headers[j]] = cols[j]
            }
            
            if let idx = fcIndex {
                var fcValue = Double(cols[idx]) ?? 0.0
                if diffForm.transformFC { fcValue = fcValue > 0 ? log2(fcValue) : 0.0 }
                if diffForm.reverseFoldChange { fcValue = -fcValue }
                rowMap[diffForm.foldChange] = fcValue
            }
            
            if let idx = sigIndex {
                var sigValue = Double(cols[idx]) ?? 0.0
                if diffForm.transformSignificant { sigValue = sigValue > 0 ? -log10(sigValue) : 0.0 }
                rowMap[diffForm.significant] = sigValue
            }
            
            if let idx = idIndex { rowMap[diffForm.primaryIDs] = cols[idx] }
            if let idx = geneIndex, idx < cols.count { rowMap[diffForm.geneNames] = cols[idx] }
            if let idx = compIndex, idx < cols.count { rowMap[diffForm.comparison] = cols[idx] }
            data.append(rowMap)
        }
        return data
    }
    
    private func resolveGeneName(for id: String, row: [String: Any], geneColumn: String, curtainData: AppData) -> String {
        var gene = id
        if let uniprotDB = curtainData.uniprotDB {
            if let uniprotRecord = uniprotDB[id] as? [String: Any],
               let geneNames = uniprotRecord["Gene Names"] as? String,
               !geneNames.isEmpty {
                let firstGeneName = geneNames.components(separatedBy: CharacterSet(charactersIn: " ;\\"))
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                    .first
                if let geneName = firstGeneName {
                    gene = geneName
                }
            }
        }
        if !geneColumn.isEmpty, let geneFromColumn = row[geneColumn] as? String, !geneFromColumn.isEmpty {
            gene = geneFromColumn
        }
        return gene
    }
    
    private func extractDoubleValue(_ value: Any?) -> Double {
        if let number = value as? NSNumber { return number.doubleValue }
        if let string = value as? String { return Double(string) ?? Double.nan }
        if let double = value as? Double { return double }
        return Double.nan
    }
    
    private func extractSelectionNames(from curtainData: AppData) -> Set<String> {
        var names = Set<String>()
        for (_, selections) in curtainData.selectedMap {
            for (name, isSelected) in selections where isSelected {
                names.insert(name)
            }
        }
        return names
    }
    
    private func assignColorsToSelections(_ selectOperationNames: Set<String>, _ colorMap: inout [String: String], _ settings: CurtainSettings) -> Int {
        let defaultColorList = settings.defaultColorList
        let currentColors = Array(colorMap.values).filter { defaultColorList.contains($0) }
        var currentPosition = currentColors.count < defaultColorList.count ? currentColors.count : 0
        var shouldRepeat = false
        
        for s in selectOperationNames.sorted() {
            if colorMap[s] == nil {
                while true {
                    if currentPosition >= defaultColorList.count {
                        currentPosition = 0
                        shouldRepeat = true
                    }
                    
                    let candidate = defaultColorList[currentPosition]
                    
                    if currentColors.contains(candidate) {
                        if shouldRepeat {
                            currentPosition += 1
                            if currentPosition >= defaultColorList.count { currentPosition = 0 }
                            colorMap[s] = defaultColorList[currentPosition]
                            break
                        } else {
                            currentPosition += 1
                        }
                    } else {
                        colorMap[s] = candidate
                        break
                    }
                }
                
                currentPosition += 1
                if currentPosition >= defaultColorList.count { currentPosition = 0 }
            }
        }
        return currentPosition
    }
    
    private func getSignificantGroup(fcValue: Double, sigValue: Double, settings: CurtainSettings, comparison: String) -> (String, String) {
        let ylog = -log10(settings.pCutoff)
        var groups: [String] = []
        var position = ""
        if sigValue < ylog { groups.append("P-value > \(settings.pCutoff)"); position = "P-value > " }
        else { groups.append("P-value <= \(settings.pCutoff)"); position = "P-value <= " }
        if abs(fcValue) > settings.log2FCCutoff { groups.append("FC > \(settings.log2FCCutoff)"); position += "FC > " } 
        else { groups.append("FC <= \(settings.log2FCCutoff)"); position += "FC <= " }
        return ("\(groups.joined(separator: ";")) (\(comparison))", position)
    }
}

struct VolcanoProcessResult {
    let jsonData: [[String: Any]]
    let colorMap: [String: String]
    let updatedVolcanoAxis: VolcanoAxis
}

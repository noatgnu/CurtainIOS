//
//  CurtainDataService.swift
//  Curtain
//
//  Created by Toan Phung on 02/08/2025.
//

import Foundation

// MARK: - CurtainDataService 

@Observable
class CurtainDataService {
    
    // State fields 
    var instructorMode: Bool = false
    var tempLink: Bool = false
    var bypassUniProt: Bool = false
    var draftDataCiteCount: Int = 0
    var colorMap: [String: Any] = [:]
    
    // Data structures 
    var dataMap: [String: String] = [:]
    var uniprotData = UniprotData()
    var curtainData = AppData()
    var curtainSettings = CurtainSettings()
    
    // UniProt service 
    private var _uniprotService: UniProtService?
    
    func getUniprotService() -> UniProtService {
        if _uniprotService == nil {
            _uniprotService = UniProtService(curtainDataService: self)
        }
        return _uniprotService!
    }
    
    // MARK: - Main Parsing Method 
    
    func restoreSettings(from jsonObject: Any) async throws {
        
        // Parse the main JSON object 
        let dataObject: [String: Any]
        switch jsonObject {
        case let string as String:
            dataObject = try parseJsonObject(string)
        case let dict as [String: Any]:
            dataObject = dict
        default:
            throw CurtainDataError.invalidJsonFormat
        }
        
        if let settingsData = dataObject["settings"] {
            switch settingsData {
            case let settingsString as String:
                curtainSettings = try manualDeserializeSettingsFromString(settingsString)
            case let settingsMap as [String: Any]:
                curtainSettings = manualDeserializeSettingsFromMap(settingsMap)
            default:
                curtainSettings = CurtainSettings()
            }
        }
        
        
        if dataObject["fetchUniprot"] as? Bool == true {
            let extraDataObj: [String: Any]?
            
            switch dataObject["extraData"] {
            case let extraDataString as String:
                extraDataObj = try parseJsonObject(extraDataString)
            case let extraDataMap as [String: Any]:
                extraDataObj = extraDataMap
            default:
                extraDataObj = nil
            }
            
            if let extraData = extraDataObj {
                // Process Uniprot data 
                if let uniprotObj = extraData["uniprot"] as? [String: Any] {
                    uniprotData.results = convertToMutableMap(uniprotObj["results"]) ?? [:]
                    uniprotData.dataMap = convertToMutableMap(uniprotObj["dataMap"])
                    uniprotData.accMap = convertToMutableAccMap(uniprotObj["accMap"])
                    uniprotData.db = convertToMutableMap(uniprotObj["db"])
                    uniprotData.organism = uniprotObj["organism"] as? String ?? ""
                    uniprotData.geneNameToAcc = convertToMutableMap(uniprotObj["geneNameToAcc"])
                }
                
                
                if let dataObj = extraData["data"] as? [String: Any] {
                    
                    curtainData.dataMap = convertToMutableMap(dataObj["dataMap"])
                    
                    curtainData.genesMap = processGenesMap(dataObj["genesMap"])
                    
                    curtainData.primaryIDsMap = processPrimaryIDsMap(dataObj["primaryIDsmap"])
                    
                    // Step 4: Process allGenes array
                    curtainData.allGenes = dataObj["allGenes"] as? [String] ?? []
                }
                
                performPostExtraDataProcessing()
            }
        }
        
        // Process raw and differential forms 
        if let rawFormData = dataObject["rawForm"] as? [String: Any] {
            curtainData.rawForm = RawForm(
                primaryIDs: rawFormData["_primaryIDs"] as? String ?? "",
                samples: rawFormData["_samples"] as? [String] ?? [],
                log2: rawFormData["_log2"] as? Bool ?? false
            )
        }
        
        if let diffFormData = dataObject["differentialForm"] as? [String: Any] {
            let comparisonSelectValue = diffFormData["_comparisonSelect"]
            let comparisonSelectList: [String]
            switch comparisonSelectValue {
            case let stringValue as String:
                comparisonSelectList = [stringValue]
            case let arrayValue as [String]:
                comparisonSelectList = arrayValue
            default:
                comparisonSelectList = []
            }
            
            curtainData.differentialForm = DifferentialForm(
                primaryIDs: diffFormData["_primaryIDs"] as? String ?? "",
                geneNames: diffFormData["_geneNames"] as? String ?? "",
                foldChange: diffFormData["_foldChange"] as? String ?? "",
                transformFC: diffFormData["_transformFC"] as? Bool ?? false,
                significant: diffFormData["_significant"] as? String ?? "",
                transformSignificant: diffFormData["_transformSignificant"] as? Bool ?? false,
                comparison: diffFormData["_comparison"] as? String ?? "",
                comparisonSelect: comparisonSelectList,
                reverseFoldChange: diffFormData["_reverseFoldChange"] as? Bool ?? false
            )
        }
        
        // Version handling 
        if curtainSettings.version == 2.0 {
            curtainData.selected = dataObject["selections"] as? [String: [Any]] ?? [:]
            curtainData.selectedMap = dataObject["selectionsMap"] as? [String: [String: Bool]] ?? [:]
            curtainData.selectOperationNames = dataObject["selectionsName"] as? [String] ?? []
        }
        
        // Process raw and processed data strings 
        if let rawString = dataObject["raw"] as? String, !rawString.isEmpty {
            curtainData.raw = InputFile(
                filename: "rawFile.txt",
                originalFile: rawString
            )
        }
        
        if let processedString = dataObject["processed"] as? String, !processedString.isEmpty {
            curtainData.differential = InputFile(
                filename: "processedFile.txt",
                originalFile: processedString
            )
        }
        
        
        await processDifferentialData()
        
        
        await performFinalDataIntegration()
        
    }
    
    
    private func performFinalDataIntegration() async {
        
        // Step 1: Integrate UniProt data with main data 
        if let uniprotDB = uniprotData.db, let dataMap = curtainData.dataMap {
            
            for (proteinId, _) in dataMap {
                if let uniprotRecord = uniprotDB[proteinId] as? [String: Any] {
                    
                    if var proteinData = dataMap[proteinId] as? [String: Any] {
                        // Add gene names from UniProt if not present
                        if proteinData["geneNames"] == nil || (proteinData["geneNames"] as? String)?.isEmpty == true {
                            proteinData["geneNames"] = uniprotRecord["Gene Names"] as? String
                        }
                        
                        // Add protein names from UniProt if not present
                        if proteinData["proteinName"] == nil || (proteinData["proteinName"] as? String)?.isEmpty == true {
                            proteinData["proteinName"] = uniprotRecord["Protein Names"] as? String
                        }
                        
                        // Update the data map
                        if var mutableDataMap = curtainData.dataMap {
                            mutableDataMap[proteinId] = proteinData
                            curtainData.dataMap = mutableDataMap
                        }
                    }
                }
            }
        }
        
        // Step 2: Validate data integrity 
        validateDataIntegrity()
        
    }
    
    private func validateDataIntegrity() {
        
        // Check dataMap structure
        if let dataMap = curtainData.dataMap {
            _ = dataMap.values.compactMap { $0 as? [String: Any] }.count
            
            // Sample validation on first few proteins
            for (_, value) in dataMap.prefix(3) {
                if let proteinDict = value as? [String: Any] {
                    _ = proteinDict["foldChange"] != nil
                    _ = proteinDict["pValue"] != nil
                    _ = proteinDict["geneNames"] != nil
                } else {
                }
            }
        }
        
        // Check UniProt integration
        if uniprotData.db != nil {
        }
        
    }
    
    
    private func processDifferentialData() async {
        
        guard let differential = curtainData.differential, !differential.originalFile.isEmpty else {
            return
        }
        
        let diffForm = curtainData.differentialForm!
        let df = differential.df
        
        
        // Handle comparison column defaulting 
        var comparison = diffForm.comparison
        var comparisonSelect = diffForm.comparisonSelect
        
        if comparison.isEmpty || comparison == "CurtainSetComparison" {
            comparison = "CurtainSetComparison"
            comparisonSelect = ["1"]
        }
        
        // Define essential columns to keep  - MUST be user-specified
        var essentialColumns = Set<String>()
        let fcColumn = diffForm.foldChange
        let sigColumn = diffForm.significant
        let idColumn = diffForm.primaryIDs
        let geneNameColumn = diffForm.geneNames
        
        
        guard !fcColumn.isEmpty && !sigColumn.isEmpty && !idColumn.isEmpty else {
            return
        }
        
        // Add non-empty columns to essential set
        [fcColumn, sigColumn, idColumn, geneNameColumn, comparison].forEach { col in
            if !col.isEmpty {
                essentialColumns.insert(col)
            }
        }
        
        
        var modifiedData: [[String: Any]] = []
        
        // Process each row 
        for rowIndex in 0..<df.rowCount() {
            // Filter by comparison value 
            if !comparison.isEmpty && !comparisonSelect.isEmpty {
                let compValue: String
                if comparison == "CurtainSetComparison" {
                    compValue = "1"
                } else {
                    compValue = df.getValue(row: rowIndex, column: comparison)?.trimmingCharacters(in: .whitespaces) ?? ""
                }
                
                if !comparisonSelect.contains(compValue) {
                    continue
                }
            }
            
            // Create sparse row map with only essential columns 
            var rowMap: [String: Any] = [:]
            
            for column in essentialColumns {
                let value: Any
                if column == "CurtainSetComparison" {
                    value = "1"
                } else {
                    value = df.getValue(row: rowIndex, column: column) ?? ""
                }
                rowMap[column] = value
            }
            
            // Process fold change values 
            if !fcColumn.isEmpty && rowMap[fcColumn] != nil {
                var fcValue = Double(rowMap[fcColumn] as? String ?? "0") ?? 0.0
                
                if diffForm.transformFC {
                    fcValue = fcValue > 0 ? log2(fcValue) : 0.0
                }
                if diffForm.reverseFoldChange {
                    fcValue = -fcValue
                }
                
                rowMap[fcColumn] = fcValue
            }
            
            // Process significance values 
            if !sigColumn.isEmpty && rowMap[sigColumn] != nil {
                var sigValue = Double(rowMap[sigColumn] as? String ?? "0") ?? 0.0
                
                if diffForm.transformSignificant {
                    sigValue = sigValue > 0 ? -log10(sigValue) : 0.0
                }
                
                rowMap[sigColumn] = sigValue
            }
            
            modifiedData.append(rowMap)
        }
        
        if curtainData.dataMap == nil {
            curtainData.dataMap = [:]
        }
        curtainData.dataMap!["processedDifferentialData"] = modifiedData
        
    }
    
    
    private func parseJsonObject(_ jsonString: String) throws -> [String: Any] {
        guard let data = jsonString.data(using: .utf8) else {
            throw CurtainDataError.invalidJsonFormat
        }
        
        guard let result = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw CurtainDataError.invalidJsonFormat
        }
        
        return result
    }
    
    
    private func convertToMutableMap(_ data: Any?) -> [String: Any]? {
        
        guard let dataMap = data as? [String: Any] else {
            if let arrayData = data as? [[Any]] {
                return convertArrayToMap(arrayData)
            }
            return data as? [String: Any]
        }
        
        
        // Check for JavaScript Map serialization format: {value: [[key, value], ...]}
        if let mapValue = dataMap["value"] as? [[Any]] {
            return convertArrayToMap(mapValue)
        }
        
        // Return the dictionary as-is if it's not in the special format
        return dataMap
    }
    
    private func convertArrayToMap(_ arrayData: [[Any]]) -> [String: Any] {
        var result: [String: Any] = [:]
        for (index, pair) in arrayData.enumerated() {
            if pair.count >= 2,
               let key = pair[0] as? String {
                result[key] = pair[1]
                
                // Debug first few pairs to understand data structure
                if index < 3 {
                    if let dict = pair[1] as? [String: Any] {
                        // Show first few key-value pairs from the protein data
                        for (_, _) in dict.prefix(3) {
                        }
                    }
                }
            }
        }
        return result
    }
    
    
    private func processGenesMap(_ data: Any?) -> Any? {
        
        if let mapData = convertToMutableMap(data) {
            return mapData
        }
        // Return as-is if not in Map format
        return data
    }
    
    private func processPrimaryIDsMap(_ data: Any?) -> Any? {
        
        if let mapData = convertToMutableMap(data) {
            return mapData
        }
        return data
    }
    
    private func performPostExtraDataProcessing() {
        
        
        if let dataMap = curtainData.dataMap {
            
            // Debug first few entries to verify data structure
            let firstThreeKeys = Array(dataMap.keys.prefix(3))
            for key in firstThreeKeys {
                if let proteinData = dataMap[key] {
                    if let _ = proteinData as? [String: Any] {
                    }
                }
            }
        }
        
        
        if uniprotData.db != nil {
        }
        
    }
    
    private func convertToMutableAccMap(_ data: Any?) -> [String: [String]]? {
        guard let dataMap = data as? [String: Any],
              let mapValue = dataMap["value"] as? [[Any]] else {
            return data as? [String: [String]]
        }
        
        // Handle special format for accession maps 
        var result: [String: [String]] = [:]
        for pair in mapValue {
            if pair.count >= 2,
               let key = pair[0] as? String,
               let valueList = pair[1] as? [String] {
                result[key] = valueList
            }
        }
        
        return result
    }
    
    
    private func manualDeserializeSettingsFromString(_ jsonString: String) throws -> CurtainSettings {
        let settingsMap = try parseJsonObject(jsonString)
        return manualDeserializeSettingsFromMap(settingsMap)
    }
    
    private func manualDeserializeSettingsFromMap(_ map: [String: Any]) -> CurtainSettings {
        // Extract values into variables to help compiler type-checking
        let fetchUniprot = map["fetchUniprot"] as? Bool ?? true
        let inputDataCols = map["inputDataCols"] as? [String: Any] ?? [:]
        let probabilityFilterMap = map["probabilityFilterMap"] as? [String: Any] ?? [:]
        let barchartColorMap = map["barchartColorMap"] as? [String: Any] ?? [:]
        let pCutoff = map["pCutoff"] as? Double ?? 0.05
        let log2FCCutoff = map["log2FCCutoff"] as? Double ?? 0.6
        let description = map["description"] as? String ?? ""
        let uniprot = map["uniprot"] as? Bool ?? true
        let colorMap = map["colorMap"] as? [String: String] ?? [:]
        let academic = map["academic"] as? Bool ?? true
        let backGroundColorGrey = map["backGroundColorGrey"] as? Bool ?? false
        let currentComparison = map["currentComparison"] as? String ?? ""
        let version = map["version"] as? Double ?? 2.0
        let currentId = map["currentID"] as? String ?? ""
        let fdrCurveText = map["fdrCurveText"] as? String ?? ""
        let fdrCurveTextEnable = map["fdrCurveTextEnable"] as? Bool ?? false
        let prideAccession = map["prideAccession"] as? String ?? ""
        let project = parseProject(map["project"])
        let sampleOrder = map["sampleOrder"] as? [String: [String]] ?? [:]
        let sampleVisible = map["sampleVisible"] as? [String: Bool] ?? [:]
        let conditionOrder = map["conditionOrder"] as? [String] ?? []
        let volcanoAxis = parseVolcanoAxis(map["volcanoAxis"])
        let textAnnotation = map["textAnnotation"] as? [String: Any] ?? [:]
        let volcanoPlotTitle = map["volcanoPlotTitle"] as? String ?? ""
        let visible = map["visible"] as? [String: Any] ?? [:]
        let defaultColorList = map["defaultColorList"] as? [String] ?? CurtainSettings.defaultColors()
        let scatterPlotMarkerSize = map["scatterPlotMarkerSize"] as? Double ?? 10.0
        let rankPlotColorMap = map["rankPlotColorMap"] as? [String: Any] ?? [:]
        let rankPlotAnnotation = map["rankPlotAnnotation"] as? [String: Any] ?? [:]
        let legendStatus = map["legendStatus"] as? [String: Any] ?? [:]
        let stringDBColorMap = map["stringDBColorMap"] as? [String: String] ?? CurtainSettings.defaultStringDBColors()
        let interactomeAtlasColorMap = map["interactomeAtlasColorMap"] as? [String: String] ?? CurtainSettings.defaultInteractomeColors()
        let proteomicsDBColor = map["proteomicsDBColor"] as? String ?? "#ff7f0e"
        let networkInteractionSettings = map["networkInteractionSettings"] as? [String: String] ?? CurtainSettings.defaultNetworkInteractionSettings()
        let plotFontFamily = map["plotFontFamily"] as? String ?? "Arial"
        let volcanoPlotGrid = parseVolcanoPlotGrid(map["volcanoPlotGrid"])
        let volcanoPlotDimension = parseVolcanoPlotDimension(map["volcanoPlotDimension"])
        let volcanoAdditionalShapes = map["volcanoAdditionalShapes"] as? [Any] ?? []
        let volcanoPlotLegendX = map["volcanoPlotLegendX"] as? Double
        let volcanoPlotLegendY = map["volcanoPlotLegendY"] as? Double
        let sampleMap = map["sampleMap"] as? [String: [String: String]] ?? [:]
        let selectedComparison = map["selectedComparison"] as? [String]
        let imputationMap = map["imputationMap"] as? [String: Any] ?? [:]
        let enableImputation = map["enableImputation"] as? Bool ?? false
        let viewPeptideCount = map["viewPeptideCount"] as? Bool ?? false
        let peptideCountData = map["peptideCountData"] as? [String: Any] ?? [:]
        
        return CurtainSettings(
            fetchUniprot: fetchUniprot,
            inputDataCols: inputDataCols,
            probabilityFilterMap: probabilityFilterMap,
            barchartColorMap: barchartColorMap,
            pCutoff: pCutoff,
            log2FCCutoff: log2FCCutoff,
            description: description,
            uniprot: uniprot,
            colorMap: colorMap,
            academic: academic,
            backGroundColorGrey: backGroundColorGrey,
            currentComparison: currentComparison,
            version: version,
            currentId: currentId,
            fdrCurveText: fdrCurveText,
            fdrCurveTextEnable: fdrCurveTextEnable,
            prideAccession: prideAccession,
            project: project,
            sampleOrder: sampleOrder,
            sampleVisible: sampleVisible,
            conditionOrder: conditionOrder,
            sampleMap: sampleMap,
            volcanoAxis: volcanoAxis,
            textAnnotation: textAnnotation,
            volcanoPlotTitle: volcanoPlotTitle,
            visible: visible,
            volcanoPlotGrid: volcanoPlotGrid,
            volcanoPlotDimension: volcanoPlotDimension,
            volcanoAdditionalShapes: volcanoAdditionalShapes,
            volcanoPlotLegendX: volcanoPlotLegendX,
            volcanoPlotLegendY: volcanoPlotLegendY,
            defaultColorList: defaultColorList,
            scatterPlotMarkerSize: scatterPlotMarkerSize,
            plotFontFamily: plotFontFamily,
            stringDBColorMap: stringDBColorMap,
            interactomeAtlasColorMap: interactomeAtlasColorMap,
            proteomicsDBColor: proteomicsDBColor,
            networkInteractionSettings: networkInteractionSettings,
            rankPlotColorMap: rankPlotColorMap,
            rankPlotAnnotation: rankPlotAnnotation,
            legendStatus: legendStatus,
            selectedComparison: selectedComparison,
            imputationMap: imputationMap,
            enableImputation: enableImputation,
            viewPeptideCount: viewPeptideCount,
            peptideCountData: peptideCountData
        )
    }
    
    
    private func parseProject(_ data: Any?) -> Project {
        guard let map = data as? [String: Any] else {
            return Project()
        }
        
        return Project(
            title: map["title"] as? String ?? "",
            projectDescription: map["projectDescription"] as? String ?? "",
            organisms: parseNameItemList(map["organisms"]),
            organismParts: parseNameItemList(map["organismParts"]),
            cellTypes: parseNameItemList(map["cellTypes"]),
            diseases: parseNameItemList(map["diseases"]),
            sampleProcessingProtocol: map["sampleProcessingProtocol"] as? String ?? "",
            dataProcessingProtocol: map["dataProcessingProtocol"] as? String ?? "",
            accession: map["accession"] as? String ?? "",
            sampleAnnotations: map["sampleAnnotations"] as? [String: Any] ?? [:]
        )
    }
    
    private func parseNameItemList(_ data: Any?) -> [NameItem] {
        guard let array = data as? [[String: Any]] else {
            return [NameItem()]
        }
        
        return array.map { item in
            NameItem(
                name: item["name"] as? String ?? "",
                cvLabel: item["cvLabel"] as? String
            )
        }
    }
    
    private func parseVolcanoAxis(_ data: Any?) -> VolcanoAxis {
        guard let map = data as? [String: Any] else {
            return VolcanoAxis()
        }
        
        
        let result = VolcanoAxis(
            minX: (map["minX"] as? NSNumber)?.doubleValue,
            maxX: (map["maxX"] as? NSNumber)?.doubleValue,
            minY: (map["minY"] as? NSNumber)?.doubleValue,
            maxY: (map["maxY"] as? NSNumber)?.doubleValue,
            x: map["x"] as? String ?? "Log2FC",
            y: map["y"] as? String ?? "-log10(p-value)",
            dtickX: (map["dtickX"] as? NSNumber)?.doubleValue,
            dtickY: (map["dtickY"] as? NSNumber)?.doubleValue,
            ticklenX: map["ticklenX"] as? Int ?? 5,
            ticklenY: map["ticklenY"] as? Int ?? 5
        )
        
        return result
    }
    
    private func parseVolcanoPlotGrid(_ data: Any?) -> [String: Bool] {
        guard let map = data as? [String: Any] else {
            return ["x": true, "y": true]
        }
        
        return [
            "x": map["x"] as? Bool ?? true,
            "y": map["y"] as? Bool ?? true
        ]
    }
    
    private func parseVolcanoPlotDimension(_ data: Any?) -> VolcanoPlotDimension {
        guard let map = data as? [String: Any] else {
            return VolcanoPlotDimension()
        }
        
        return VolcanoPlotDimension(
            width: map["width"] as? Int ?? 800,
            height: map["height"] as? Int ?? 1000,
            margin: parseVolcanoPlotMargin(map["margin"])
        )
    }
    
    private func parseVolcanoPlotMargin(_ data: Any?) -> VolcanoPlotMargin {
        guard let map = data as? [String: Any] else {
            return VolcanoPlotMargin()
        }
        
        return VolcanoPlotMargin(
            left: map["l"] as? Int,
            right: map["r"] as? Int,
            bottom: map["b"] as? Int,
            top: map["t"] as? Int
        )
    }
}


class UniprotData {
    var results: [String: Any] = [:]
    var dataMap: [String: Any]?
    var accMap: [String: [String]]?
    var db: [String: Any]?
    var organism: String = ""
    var geneNameToAcc: [String: Any]?
}

class AppData {
    var dataMap: [String: Any]?
    var genesMap: Any?
    var primaryIDsMap: Any?
    var allGenes: [String] = []
    var uniprotDB: [String: Any]?
    var rawForm: RawForm?
    var differentialForm: DifferentialForm?
    var selected: [String: [Any]] = [:]
    var selectedMap: [String: [String: Bool]] = [:]
    var selectOperationNames: [String] = []
    var raw: InputFile?
    var differential: InputFile?
}

struct RawForm {
    let primaryIDs: String
    let samples: [String]
    let log2: Bool
}

struct DifferentialForm {
    let primaryIDs: String
    let geneNames: String
    let foldChange: String
    let transformFC: Bool
    let significant: String
    let transformSignificant: Bool
    let comparison: String
    let comparisonSelect: [String]
    let reverseFoldChange: Bool
}


// MARK: - Errors

enum CurtainDataError: Error, LocalizedError {
    case invalidJsonFormat
    case parseError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidJsonFormat:
            return "Invalid JSON format"
        case .parseError(let message):
            return "Parse error: \(message)"
        }
    }
}
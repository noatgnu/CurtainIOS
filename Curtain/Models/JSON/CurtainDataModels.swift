//
//  CurtainDataModels.swift
//  Curtain
//
//  Created by Toan Phung on 02/08/2025.
//

import Foundation

// MARK: - Main CurtainData Structure 

struct CurtainData {
    // Data Content Fields
    let raw: String?
    let rawForm: CurtainRawForm
    let differentialForm: CurtainDifferentialForm
    let processed: String?
    let password: String
    let selections: [String: [Any]]?
    var selectionsMap: [String: Any]?
    var selectedMap: [String: [String: Bool]]? 
    var selectionsName: [String]?
    private var _settings: CurtainSettings
    let fetchUniprot: Bool
    let annotatedData: Any?
    let extraData: ExtraData?
    let permanent: Bool
    // Android field: ensure it's not ignored
    var bypassUniProt: Bool
    
    // SQLite database path for data storage
    let dbPath: URL?

    // Stored link ID for database queries (overrides computed property)
    private var _storedLinkId: String?

    // Uniprot DB for gene name resolution
    var uniprotDB: [String: Any]?
    
    // Direct access to settings without automatic processing to avoid loops
    var settings: CurtainSettings {
        get { return _settings }
        set { _settings = newValue }
    }
    
    // Method to get processed settings when needed (e.g., for protein charts)
    func getProcessedSettings() -> CurtainSettings {
        // Only process if we have the necessary data and are missing metadata
        guard let rawData = raw,
              !rawData.isEmpty,
              !rawForm.samples.isEmpty,
              (_settings.conditionOrder.isEmpty || _settings.sampleMap.isEmpty) else {
            return _settings
        }

        let processedSettings = CurtainDataProcessor.processRawData(self)
        return processedSettings
    }

    /// Async version with progress tracking - processes on background thread
    /// - Parameter progressCallback: Optional progress updates (0.0 to 1.0)
    /// - Returns: Processed settings with metadata from raw data
    func getProcessedSettingsAsync(
        progressCallback: ((Double) -> Void)? = nil
    ) async -> CurtainSettings {
        // Only process if we have the necessary data and are missing metadata
        guard let rawData = raw,
              !rawData.isEmpty,
              !rawForm.samples.isEmpty,
              (_settings.conditionOrder.isEmpty || _settings.sampleMap.isEmpty) else {
            progressCallback?(1.0)
            return _settings
        }

        let processedSettings = await CurtainDataProcessor.processRawDataAsync(
            self,
            progressCallback: progressCallback
        )
        return processedSettings
    }

    // Computed properties for easier access
    var proteomicsData: [String: Any] {
        // Priority 1: Use processed differential data 
        if let extraData = extraData,
           let data = extraData.data,
           let dataMap = data.dataMap {
            let convertedDataMap = convertDataMapToDict(dataMap)
            
            // Check if we have processedDifferentialData 
            if let processedData = convertedDataMap["processedDifferentialData"] as? [[String: Any]] {
                
                // Convert array to dictionary with protein IDs as keys
                var result: [String: Any] = [:]
                for (index, row) in processedData.enumerated() {
                    // Find the protein ID field
                    let proteinId = findProteinId(in: row) ?? "PROTEIN_\(index)"
                    result[proteinId] = row
                }
                
                return result
            }
            
            // Fallback: Use raw dataMap conversion
            return convertedDataMap
        }
        
        return [:]
    }
    
    // Helper to find protein ID field in row data - use ONLY user-specified column
    private func findProteinId(in row: [String: Any]) -> String? {
        
        guard !differentialForm.primaryIDs.isEmpty else {
            return nil
        }
        
        let primaryIdColumn = differentialForm.primaryIDs
        guard let id = row[primaryIdColumn] as? String, !id.isEmpty else {
            if row[primaryIdColumn] != nil {
            } else {
            }
            return nil
        }
        
        return id
    }
    
    var rawDataRowCount: Int {
        // Count based on samples or data availability
        if !rawForm.samples.isEmpty {
            return rawForm.samples.count
        }
        return proteomicsData.count
    }
    
    var differentialDataRowCount: Int {
        // Count differential data rows
        return proteomicsData.count
    }
    
    var linkId: String {
        // Use stored linkId if available, otherwise fall back to settings.currentId
        return _storedLinkId ?? settings.currentId
    }

    mutating func setLinkId(_ id: String) {
        _storedLinkId = id
    }

    /// Returns true if data is available (either in-memory or in SQLite database)
    var hasDataAvailable: Bool {
        // Check in-memory data first
        if !proteomicsData.isEmpty {
            return true
        }

        // Check SQLite database
        let currentLinkId = linkId
        if !currentLinkId.isEmpty {
            return ProteomicsDataDatabaseManager.shared.checkDataExists(currentLinkId)
        }

        return false
    }

    // MARK: - Gene Name Resolution (Matching Android Pattern)

    /// Gets gene name for a protein ID
    /// Priority: 1) Denormalized mapping tables, 2) processed_proteomics_data, 3) extraData.uniprot.db, 4) nil
    /// This matches Android's approach with ProteinMappingService
    func getGeneNameForProtein(_ primaryId: String) -> String? {
        let currentLinkId = linkId

        if !currentLinkId.isEmpty {
            // Priority 1: Try denormalized mapping tables (fastest - O(1) lookup)
            if let geneName = ProteinMappingService.shared.getGeneNameFromPrimaryId(linkId: currentLinkId, primaryId: primaryId),
               !geneName.isEmpty {
                return geneName
            }

            // Priority 2: Try processed_proteomics_data geneNames column
            if let geneName = ProteomicsDataService.shared.getGeneNameForProtein(linkId: currentLinkId, primaryId: primaryId),
               !geneName.isEmpty {
                return geneName
            }
        }

        // Priority 3: Try extraData.uniprot.db (legacy in-memory data)
        if let uniprotDB = extraData?.uniprot?.db as? [String: Any] {
            // Try exact match first
            if let uniprotRecord = uniprotDB[primaryId] as? [String: Any],
               let geneNames = uniprotRecord["Gene Names"] as? String,
               !geneNames.isEmpty {
                return geneNames
            }

            // Try split IDs
            let splitIds = primaryId.split(separator: ";").map { String($0).trimmingCharacters(in: .whitespaces) }
            for splitId in splitIds {
                if splitId.isEmpty { continue }
                if let uniprotRecord = uniprotDB[splitId] as? [String: Any],
                   let geneNames = uniprotRecord["Gene Names"] as? String,
                   !geneNames.isEmpty {
                    return geneNames
                }
            }
        }

        // Priority 4: Try uniprotDB property (if set directly)
        if let uniprotDB = uniprotDB {
            if let uniprotRecord = uniprotDB[primaryId] as? [String: Any],
               let geneNames = uniprotRecord["Gene Names"] as? String,
               !geneNames.isEmpty {
                return geneNames
            }
        }

        return nil
    }

    /// Gets the first/primary gene name for display
    /// Parses the gene names string and returns the first gene name
    func getPrimaryGeneNameForProtein(_ primaryId: String) -> String? {
        guard let geneNames = getGeneNameForProtein(primaryId), !geneNames.isEmpty else {
            return nil
        }

        // Parse the first gene name (can be space or semicolon separated)
        let firstGeneName = geneNames.components(separatedBy: CharacterSet(charactersIn: " ;"))
            .first(where: { !$0.isEmpty })
        return firstGeneName
    }

    /// Gets display name for a protein (gene name or primary ID)
    /// Returns gene name if available, otherwise returns primaryId
    func getDisplayNameForProtein(_ primaryId: String) -> String {
        if let geneName = getPrimaryGeneNameForProtein(primaryId) {
            return geneName
        }
        return primaryId
    }
    
    var description: String {
        return settings.description
    }
    
    var curtainType: String {
        // Derive curtain type from settings or data structure
        if !rawForm.samples.isEmpty {
            return "TP" // Total Proteome
        } else if !differentialForm.comparison.isEmpty {
            return "CC" // Comparative Analysis  
        }
        return "TP"
    }
    
    init(
        raw: String? = nil,
        rawForm: CurtainRawForm = CurtainRawForm(),
        differentialForm: CurtainDifferentialForm = CurtainDifferentialForm(),
        processed: String? = nil,
        password: String = "",
        selections: [String: [Any]]? = nil,
        selectionsMap: [String: Any]? = nil,
        selectedMap: [String: [String: Bool]]? = nil,
        selectionsName: [String]? = nil,
        settings: CurtainSettings = CurtainSettings(),
        fetchUniprot: Bool = true,
        annotatedData: Any? = nil,
        extraData: ExtraData? = nil,
        permanent: Bool = false,
        bypassUniProt: Bool = false,
        dbPath: URL? = nil,
        linkId: String? = nil
    ) {
        self.raw = raw
        self.rawForm = rawForm
        self.differentialForm = differentialForm
        self.processed = processed
        self.password = password
        self.selections = selections
        self.selectionsMap = selectionsMap
        self.selectedMap = selectedMap
        self.selectionsName = selectionsName
        self._settings = settings
        self.fetchUniprot = fetchUniprot
        self.annotatedData = annotatedData
        self.extraData = extraData
        self.permanent = permanent
        self.bypassUniProt = bypassUniProt
        self.dbPath = dbPath
        self._storedLinkId = linkId
    }
    
    // Helper method to convert JavaScript Map serialization formats
    private func convertDataMapToDict(_ dataMap: Any) -> [String: Any] {
        
        // Use the same logic as CurtainDataService.convertToMutableMap
        guard let dataDict = dataMap as? [String: Any] else {
            if let arrayData = dataMap as? [[Any]] {
                return convertArrayToDict(arrayData)
            }
            return [:]
        }
        
        
        // Check for JavaScript Map serialization format: {value: [[key, value], ...]}
        if let mapValue = dataDict["value"] as? [[Any]] {
            return convertArrayToDict(mapValue)
        }
        
        // Return the dictionary as-is if it's not in the special format
        return dataDict
    }
    
    private func convertArrayToDict(_ arrayData: [[Any]]) -> [String: Any] {
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
}

// MARK: - CurtainRawForm (Raw Data Configuration)

struct CurtainRawForm: Codable {
    let primaryIDs: String
    let samples: [String]
    let log2: Bool
    
    init(
        primaryIDs: String = "",
        samples: [String] = [],
        log2: Bool = false
    ) {
        self.primaryIDs = primaryIDs
        self.samples = samples
        self.log2 = log2
    }
}

// MARK: - CurtainDifferentialForm (Comparative Analysis Configuration)

struct CurtainDifferentialForm: Codable {
    let primaryIDs: String
    let geneNames: String
    let foldChange: String
    let transformFC: Bool
    let significant: String
    let transformSignificant: Bool
    let comparison: String
    let comparisonSelect: [String]
    let reverseFoldChange: Bool
    
    init(
        primaryIDs: String = "",
        geneNames: String = "",
        foldChange: String = "",
        transformFC: Bool = false,
        significant: String = "",
        transformSignificant: Bool = false,
        comparison: String = "",
        comparisonSelect: [String] = [],
        reverseFoldChange: Bool = false
    ) {
        self.primaryIDs = primaryIDs
        self.geneNames = geneNames
        self.foldChange = foldChange
        self.transformFC = transformFC
        self.significant = significant
        self.transformSignificant = transformSignificant
        self.comparison = comparison
        self.comparisonSelect = comparisonSelect
        self.reverseFoldChange = reverseFoldChange
    }
}

// MARK: - ExtraData (UniProt and Additional Data)

struct ExtraData {
    let uniprot: UniprotExtraData?
    let data: DataMapContainer?
    
    init(
        uniprot: UniprotExtraData? = nil,
        data: DataMapContainer? = nil
    ) {
        self.uniprot = uniprot
        self.data = data
    }
}

// MARK: - DataMapContainer (Proteomics Data Container)

struct DataMapContainer {
    let dataMap: [String: Any]? // Converted to dictionary
    let genesMap: [String: [String: Any]]?
    let primaryIDsMap: [String: [String: Any]]?
    let allGenes: [String]?
    
    init(
        dataMap: [String: Any]? = nil,
        genesMap: [String: [String: Any]]? = nil,
        primaryIDsMap: [String: [String: Any]]? = nil,
        allGenes: [String]? = nil
    ) {
        self.dataMap = dataMap
        self.genesMap = genesMap
        self.primaryIDsMap = primaryIDsMap
        self.allGenes = allGenes
    }
}

// MARK: - UniprotExtraData (UniProt Annotations)

struct UniprotExtraData {
    let results: [String: Any]
    let dataMap: [String: Any]?
    let db: [String: Any]?
    let organism: String?
    let accMap: [String: [String]]?
    let geneNameToAcc: [String: [String: Any]]?
    
    init(
        results: [String: Any] = [:],
        dataMap: [String: Any]? = nil,
        db: [String: Any]? = nil,
        organism: String? = nil,
        accMap: [String: [String]]? = nil,
        geneNameToAcc: [String: [String: Any]]? = nil
    ) {
        self.results = results
        self.dataMap = dataMap
        self.db = db
        self.organism = organism
        self.accMap = accMap
        self.geneNameToAcc = geneNameToAcc
    }
}

// MARK: - JSON Parsing Extensions

extension CurtainData {
    
    static func fromJSON(_ json: [String: Any]) -> CurtainData? {
        // Parse CurtainRawForm
        let rawForm: CurtainRawForm
        if let rawFormDict = json["rawForm"] as? [String: Any] {
            rawForm = CurtainRawForm(
                primaryIDs: rawFormDict["_primaryIDs"] as? String ?? "",
                samples: rawFormDict["_samples"] as? [String] ?? [],
                log2: rawFormDict["_log2"] as? Bool ?? false
            )
        } else {
            rawForm = CurtainRawForm()
        }
        
        // Parse CurtainDifferentialForm
        let differentialForm: CurtainDifferentialForm
        if let diffFormDict = json["differentialForm"] as? [String: Any] {
            differentialForm = CurtainDifferentialForm(
                primaryIDs: diffFormDict["_primaryIDs"] as? String ?? "",
                geneNames: diffFormDict["_geneNames"] as? String ?? "",
                foldChange: diffFormDict["_foldChange"] as? String ?? "",
                transformFC: diffFormDict["_transformFC"] as? Bool ?? false,
                significant: diffFormDict["_significant"] as? String ?? "",
                transformSignificant: diffFormDict["_transformSignificant"] as? Bool ?? false,
                comparison: diffFormDict["_comparison"] as? String ?? "",
                comparisonSelect: diffFormDict["_comparisonSelect"] as? [String] ?? [],
                reverseFoldChange: diffFormDict["_reverseFoldChange"] as? Bool ?? false
            )
        } else {
            differentialForm = CurtainDifferentialForm()
        }
        
        // Parse ExtraData
        let extraData: ExtraData?
        if let extraDataDict = json["extraData"] as? [String: Any] {
            // Parse UniProt data
            let uniprotData: UniprotExtraData?
            if let uniprotDict = extraDataDict["uniprot"] as? [String: Any] {
                uniprotData = UniprotExtraData(
                    results: uniprotDict["results"] as? [String: Any] ?? [:],
                    dataMap: uniprotDict["dataMap"] as? [String: Any],
                    db: uniprotDict["db"] as? [String: Any],
                    organism: uniprotDict["organism"] as? String,
                    accMap: uniprotDict["accMap"] as? [String: [String]],
                    geneNameToAcc: uniprotDict["geneNameToAcc"] as? [String: [String: Any]]
                )
            } else {
                uniprotData = nil
            }
            
            // Parse data container
            let dataContainer: DataMapContainer?
            if let dataDict = extraDataDict["data"] as? [String: Any] {
                dataContainer = DataMapContainer(
                    dataMap: dataDict["dataMap"] as? [String: Any],
                    genesMap: dataDict["genesMap"] as? [String: [String: Any]],
                    primaryIDsMap: dataDict["primaryIDsMap"] as? [String: [String: Any]],
                    allGenes: dataDict["allGenes"] as? [String]
                )
            } else {
                dataContainer = nil
            }
            
            extraData = ExtraData(uniprot: uniprotData, data: dataContainer)
        } else {
            extraData = nil
        }
        
        // Parse settings (assume already available from CurtainSettings parsing)
        let settings: CurtainSettings
        if let _ = json["settings"] as? [String: Any] {
            // This would use the existing CurtainSettings parsing logic
            settings = CurtainSettings() // Placeholder - would need full parsing
        } else {
            settings = CurtainSettings()
        }
        
        return CurtainData(
            raw: json["raw"] as? String,
            rawForm: rawForm,
            differentialForm: differentialForm,
            processed: json["processed"] as? String,
            password: json["password"] as? String ?? "",
            selections: json["selections"] as? [String: [Any]],
            selectionsMap: json["selectionsMap"] as? [String: Any],
            selectionsName: json["selectionsName"] as? [String],
            settings: settings,
            fetchUniprot: json["fetchUniprot"] as? Bool ?? true,
            annotatedData: json["annotatedData"],
            extraData: extraData,
            permanent: json["permanent"] as? Bool ?? false,
            bypassUniProt: json["bypassUniProt"] as? Bool ?? false
        )
    }
    
    /// Convert CurtainData to JSON dictionary
    func toJSON() -> [String: Any] {
        var json: [String: Any] = [:]
        
        json["raw"] = raw
        json["processed"] = processed
        json["password"] = password
        json["fetchUniprot"] = fetchUniprot
        json["permanent"] = permanent
        json["bypassUniProt"] = bypassUniProt
        
        // Convert RawForm
        json["rawForm"] = [
            "_primaryIDs": rawForm.primaryIDs,
            "_samples": rawForm.samples,
            "_log2": rawForm.log2
        ]
        
        // Convert DifferentialForm
        json["differentialForm"] = [
            "_primaryIDs": differentialForm.primaryIDs,
            "_geneNames": differentialForm.geneNames,
            "_foldChange": differentialForm.foldChange,
            "_transformFC": differentialForm.transformFC,
            "_significant": differentialForm.significant,
            "_transformSignificant": differentialForm.transformSignificant,
            "_comparison": differentialForm.comparison,
            "_comparisonSelect": differentialForm.comparisonSelect,
            "_reverseFoldChange": differentialForm.reverseFoldChange
        ]
        
        if let selections = selections {
            json["selections"] = selections
        }
        
        if let selectionsMap = selectionsMap {
            json["selectionsMap"] = selectionsMap
        }
        
        if let selectionsName = selectionsName {
            json["selectionsName"] = selectionsName
        }
        
        if let annotatedData = annotatedData {
            json["annotatedData"] = annotatedData
        }
        
        // Convert ExtraData
        if let extraData = extraData {
            var extraDataDict: [String: Any] = [:]
            
            if let uniprot = extraData.uniprot {
                extraDataDict["uniprot"] = [
                    "results": uniprot.results,
                    "dataMap": uniprot.dataMap as Any,
                    "db": uniprot.db as Any,
                    "organism": uniprot.organism as Any,
                    "accMap": uniprot.accMap as Any,
                    "geneNameToAcc": uniprot.geneNameToAcc as Any
                ]
            }
            
            if let data = extraData.data {
                extraDataDict["data"] = [
                    "dataMap": data.dataMap as Any,
                    "genesMap": data.genesMap as Any,
                    "primaryIDsMap": data.primaryIDsMap as Any,
                    "allGenes": data.allGenes as Any
                ]
            }
            
            json["extraData"] = extraDataDict
        }
        
        // Serialize settings using the raw _settings (not the computed property)
        json["settings"] = _settings.toDictionary()
        
        return json
    }
}



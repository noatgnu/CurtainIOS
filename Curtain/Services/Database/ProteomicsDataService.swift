//
//  ProteomicsDataService.swift
//  Curtain
//
//  Core service for proteomics data management using SQLite
//  Equivalent to Android's ProteomicsDataService
//

import Foundation
import GRDB

class ProteomicsDataService {

    // MARK: - Singleton

    static let shared = ProteomicsDataService()

    // MARK: - Dependencies

    private let databaseManager = ProteomicsDataDatabaseManager.shared

    private init() {}

    // MARK: - Load Data from Database

    /// Loads CurtainData from SQLite database
    func loadCurtainDataFromDatabase(linkId: String) -> CurtainData? {
        do {
            let db = try databaseManager.getDatabaseForLinkId(linkId)

            return try db.read { database in
                guard let metadata = try CurtainMetadata.fetchOne(database) else {
                    print("[ProteomicsDataService] No metadata found for \(linkId)")
                    return nil
                }

                // Parse settings JSON
                guard let settingsData = metadata.settingsJson.data(using: .utf8),
                      let settingsDict = try? JSONSerialization.jsonObject(with: settingsData) as? [String: Any] else {
                    print("[ProteomicsDataService] Failed to parse settings JSON")
                    return nil
                }
                let settings = CurtainSettings.fromDictionary(settingsDict)

                // Parse rawForm JSON
                guard let rawFormData = metadata.rawFormJson.data(using: .utf8),
                      let rawFormDict = try? JSONSerialization.jsonObject(with: rawFormData) as? [String: Any] else {
                    print("[ProteomicsDataService] Failed to parse rawForm JSON")
                    return nil
                }
                let rawForm = CurtainRawForm(
                    primaryIDs: rawFormDict["primaryIDs"] as? String ?? rawFormDict["_primaryIDs"] as? String ?? "",
                    samples: rawFormDict["samples"] as? [String] ?? rawFormDict["_samples"] as? [String] ?? [],
                    log2: rawFormDict["log2"] as? Bool ?? rawFormDict["_log2"] as? Bool ?? false
                )

                // Parse differentialForm JSON
                guard let diffFormData = metadata.differentialFormJson.data(using: .utf8),
                      let diffFormDict = try? JSONSerialization.jsonObject(with: diffFormData) as? [String: Any] else {
                    print("[ProteomicsDataService] Failed to parse differentialForm JSON")
                    return nil
                }
                let differentialForm = CurtainDifferentialForm(
                    primaryIDs: diffFormDict["primaryIDs"] as? String ?? diffFormDict["_primaryIDs"] as? String ?? "",
                    geneNames: diffFormDict["geneNames"] as? String ?? diffFormDict["_geneNames"] as? String ?? "",
                    foldChange: diffFormDict["foldChange"] as? String ?? diffFormDict["_foldChange"] as? String ?? "",
                    transformFC: diffFormDict["transformFC"] as? Bool ?? diffFormDict["_transformFC"] as? Bool ?? false,
                    significant: diffFormDict["significant"] as? String ?? diffFormDict["_significant"] as? String ?? "",
                    transformSignificant: diffFormDict["transformSignificant"] as? Bool ?? diffFormDict["_transformSignificant"] as? Bool ?? false,
                    comparison: diffFormDict["comparison"] as? String ?? diffFormDict["_comparison"] as? String ?? "",
                    comparisonSelect: diffFormDict["comparisonSelect"] as? [String] ?? diffFormDict["_comparisonSelect"] as? [String] ?? [],
                    reverseFoldChange: diffFormDict["reverseFoldChange"] as? Bool ?? diffFormDict["_reverseFoldChange"] as? Bool ?? false
                )

                // Parse selections
                var selectedMap: [String: [String: Bool]]? = nil
                if let json = metadata.selectedMapJson,
                   let data = json.data(using: .utf8) {
                    selectedMap = try? JSONDecoder().decode([String: [String: Bool]].self, from: data)
                }

                var selectionsName: [String]? = nil
                if let json = metadata.selectionsNameJson,
                   let data = json.data(using: .utf8) {
                    selectionsName = try? JSONDecoder().decode([String].self, from: data)
                }

                // Create CurtainData
                return CurtainData(
                    raw: nil,
                    rawForm: rawForm,
                    differentialForm: differentialForm,
                    processed: nil,
                    password: metadata.password,
                    selections: nil,
                    selectionsMap: nil,
                    selectedMap: selectedMap,
                    selectionsName: selectionsName,
                    settings: settings,
                    fetchUniprot: metadata.fetchUniprot,
                    annotatedData: nil,
                    extraData: nil,
                    permanent: metadata.permanent,
                    bypassUniProt: metadata.bypassUniProt,
                    dbPath: databaseManager.getDatabaseURL(for: linkId)
                )
            }
        } catch {
            print("[ProteomicsDataService] Error loading data: \(error)")
            return nil
        }
    }

    // MARK: - Build/Ingest Data

    /// Builds proteomics data if needed (called during data download)
    func buildProteomicsDataIfNeeded(
        linkId: String,
        rawTsv: String?,
        processedTsv: String?,
        rawForm: CurtainRawForm,
        differentialForm: CurtainDifferentialForm,
        curtainData: CurtainData,
        onProgress: @escaping (String) -> Void
    ) throws {
        // Check if data already exists with correct schema
        if databaseManager.checkDataExists(linkId) {
            print("[ProteomicsDataService] Proteomics data already exists for \(linkId)")
            return
        }

        print("[ProteomicsDataService] Building proteomics data for \(linkId)")
        databaseManager.clearAllData(linkId)

        onProgress("Parsing processed data...")
        let processedData = parseProcessedData(processedTsv: processedTsv, form: differentialForm)

        onProgress("Parsing raw data...")
        let rawData = parseRawData(rawTsv: rawTsv, form: rawForm)

        onProgress("Building settings...")
        let updatedCurtainData = buildSettingsFromSamples(curtainData: curtainData, samples: rawForm.samples)

        let db = try databaseManager.getDatabaseForLinkId(linkId)

        if !processedData.isEmpty {
            onProgress("Storing \(processedData.count) proteins...")
            print("[ProteomicsDataService] Inserting \(processedData.count) processed data entries")
            try db.write { database in
                for var data in processedData {
                    try data.insert(database)
                }
            }
        }

        if !rawData.isEmpty {
            onProgress("Storing \(rawData.count) raw data entries...")
            print("[ProteomicsDataService] Inserting \(rawData.count) raw data entries")
            try db.write { database in
                for var data in rawData {
                    try data.insert(database)
                }
            }
        }

        onProgress("Storing gene mappings...")
        try parseAndStoreExtraDataMaps(curtainData: updatedCurtainData, db: db)

        onProgress("Storing metadata...")
        try storeCurtainMetadata(curtainData: updatedCurtainData, db: db)

        databaseManager.storeSchemaVersion(linkId)
        print("[ProteomicsDataService] Proteomics data build complete for \(linkId)")
    }

    // MARK: - Settings Building

    /// Builds settings from sample names (condition/replicate extraction)
    func buildSettingsFromSamples(curtainData: CurtainData, samples: [String]) -> CurtainData {
        let settings = curtainData.settings

        var builtSampleMap: [String: [String: String]] = [:]
        var conditions: [String] = []
        var colorMap = settings.colorMap
        var sampleOrder = settings.sampleOrder
        var sampleVisible = settings.sampleVisible

        var colorPosition = 0

        for sample in samples {
            let parts = sample.split(separator: ".").map(String.init)
            let replicate = parts.last ?? ""
            let condition: String
            if parts.count > 1 {
                condition = parts.dropLast().joined(separator: ".")
            } else {
                condition = sample
            }

            let existingCondition: String
            if let existingSampleMap = settings.sampleMap[sample],
               let cond = existingSampleMap["condition"] {
                existingCondition = cond
            } else {
                existingCondition = condition
            }

            if !conditions.contains(existingCondition) {
                conditions.append(existingCondition)

                if colorMap[existingCondition] == nil {
                    if colorPosition >= settings.defaultColorList.count {
                        colorPosition = 0
                    }
                    colorMap[existingCondition] = settings.defaultColorList[colorPosition]
                    colorPosition += 1
                }
            }

            if sampleOrder[existingCondition] == nil {
                sampleOrder[existingCondition] = []
            }
            if !(sampleOrder[existingCondition]?.contains(sample) ?? false) {
                sampleOrder[existingCondition]?.append(sample)
            }

            if sampleVisible[sample] == nil {
                sampleVisible[sample] = true
            }

            builtSampleMap[sample] = [
                "replicate": replicate,
                "condition": existingCondition,
                "name": sample
            ]
        }

        let finalSampleMap: [String: [String: String]]
        if settings.sampleMap.isEmpty {
            finalSampleMap = builtSampleMap
        } else {
            var mergedMap = settings.sampleMap
            for (key, value) in builtSampleMap {
                if mergedMap[key] == nil {
                    mergedMap[key] = value
                }
            }
            finalSampleMap = mergedMap.filter { samples.contains($0.key) }
        }

        let cleanedSampleVisible = sampleVisible.filter { samples.contains($0.key) }

        let finalConditionOrder: [String]
        if settings.conditionOrder.isEmpty {
            finalConditionOrder = conditions
        } else {
            let existingConditions = settings.conditionOrder.filter { conditions.contains($0) }
            let newConditions = conditions.filter { !existingConditions.contains($0) }
            finalConditionOrder = existingConditions + newConditions
        }

        let cleanedSampleOrder = sampleOrder.filter { conditions.contains($0.key) }

        // Create updated settings
        let updatedSettings = CurtainSettings(
            fetchUniprot: settings.fetchUniprot,
            inputDataCols: settings.inputDataCols,
            probabilityFilterMap: settings.probabilityFilterMap,
            barchartColorMap: settings.barchartColorMap,
            pCutoff: settings.pCutoff,
            log2FCCutoff: settings.log2FCCutoff,
            description: settings.description,
            uniprot: settings.uniprot,
            colorMap: colorMap,
            academic: settings.academic,
            backGroundColorGrey: settings.backGroundColorGrey,
            currentComparison: settings.currentComparison,
            version: settings.version,
            currentId: settings.currentId,
            fdrCurveText: settings.fdrCurveText,
            fdrCurveTextEnable: settings.fdrCurveTextEnable,
            prideAccession: settings.prideAccession,
            project: settings.project,
            sampleOrder: cleanedSampleOrder,
            sampleVisible: cleanedSampleVisible,
            conditionOrder: finalConditionOrder,
            sampleMap: finalSampleMap,
            volcanoAxis: settings.volcanoAxis,
            textAnnotation: settings.textAnnotation,
            volcanoPlotTitle: settings.volcanoPlotTitle,
            visible: settings.visible,
            volcanoPlotGrid: settings.volcanoPlotGrid,
            volcanoPlotDimension: settings.volcanoPlotDimension,
            volcanoAdditionalShapes: settings.volcanoAdditionalShapes,
            volcanoPlotLegendX: settings.volcanoPlotLegendX,
            volcanoPlotLegendY: settings.volcanoPlotLegendY,
            defaultColorList: settings.defaultColorList,
            scatterPlotMarkerSize: settings.scatterPlotMarkerSize,
            plotFontFamily: settings.plotFontFamily,
            stringDBColorMap: settings.stringDBColorMap,
            interactomeAtlasColorMap: settings.interactomeAtlasColorMap,
            proteomicsDBColor: settings.proteomicsDBColor,
            networkInteractionSettings: settings.networkInteractionSettings,
            rankPlotColorMap: settings.rankPlotColorMap,
            rankPlotAnnotation: settings.rankPlotAnnotation,
            legendStatus: settings.legendStatus,
            selectedComparison: settings.selectedComparison,
            imputationMap: settings.imputationMap,
            enableImputation: settings.enableImputation,
            viewPeptideCount: settings.viewPeptideCount,
            peptideCountData: settings.peptideCountData,
            volcanoConditionLabels: settings.volcanoConditionLabels,
            volcanoTraceOrder: settings.volcanoTraceOrder,
            volcanoPlotYaxisPosition: settings.volcanoPlotYaxisPosition,
            customVolcanoTextCol: settings.customVolcanoTextCol,
            barChartConditionBracket: settings.barChartConditionBracket,
            columnSize: settings.columnSize,
            chartYAxisLimits: settings.chartYAxisLimits,
            individualYAxisLimits: settings.individualYAxisLimits,
            violinPointPos: settings.violinPointPos,
            networkInteractionData: settings.networkInteractionData,
            enrichrGeneRankMap: settings.enrichrGeneRankMap,
            enrichrRunList: settings.enrichrRunList,
            extraData: settings.extraData,
            enableMetabolomics: settings.enableMetabolomics,
            metabolomicsColumnMap: settings.metabolomicsColumnMap,
            encrypted: settings.encrypted,
            dataAnalysisContact: settings.dataAnalysisContact,
            markerSizeMap: settings.markerSizeMap
        )

        // Return updated CurtainData with new settings
        return CurtainData(
            raw: curtainData.raw,
            rawForm: curtainData.rawForm,
            differentialForm: curtainData.differentialForm,
            processed: curtainData.processed,
            password: curtainData.password,
            selections: curtainData.selections,
            selectionsMap: curtainData.selectionsMap,
            selectedMap: curtainData.selectedMap,
            selectionsName: curtainData.selectionsName,
            settings: updatedSettings,
            fetchUniprot: curtainData.fetchUniprot,
            annotatedData: curtainData.annotatedData,
            extraData: curtainData.extraData,
            permanent: curtainData.permanent,
            bypassUniProt: curtainData.bypassUniProt,
            dbPath: curtainData.dbPath,
            linkId: curtainData.linkId
        )
    }

    // MARK: - Parse TSV Data

    /// Parses processed/differential TSV data into entities
    func parseProcessedData(processedTsv: String?, form: CurtainDifferentialForm) -> [ProcessedProteomicsData] {
        guard let tsv = processedTsv, !tsv.isEmpty else { return [] }

        let lines = tsv.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard !lines.isEmpty else { return [] }

        let headers = lines[0].components(separatedBy: "\t")
        let primaryIdIndex = headers.firstIndex(of: form.primaryIDs)
        let geneNamesIndex = headers.firstIndex(of: form.geneNames)
        let foldChangeIndex = headers.firstIndex(of: form.foldChange)
        let significantIndex = headers.firstIndex(of: form.significant)
        let comparisonIndex = form.comparison.isEmpty ? nil : headers.firstIndex(of: form.comparison)

        // Debug: Log gene names column detection
        print("[ProteomicsDataService] parseProcessedData headers: \(headers)")
        print("[ProteomicsDataService] form.geneNames column name: '\(form.geneNames)'")
        print("[ProteomicsDataService] geneNamesIndex: \(geneNamesIndex?.description ?? "nil")")

        guard let primaryIdIdx = primaryIdIndex else {
            print("[ProteomicsDataService] Primary ID column '\(form.primaryIDs)' not found")
            return []
        }

        var result: [ProcessedProteomicsData] = []

        for i in 1..<lines.count {
            let values = lines[i].components(separatedBy: "\t")
            guard values.count > primaryIdIdx else { continue }

            let primaryId = values[primaryIdIdx]
            let geneNames: String? = geneNamesIndex.flatMap { idx in
                guard idx < values.count else { return nil }
                let value = values[idx]
                return value.isEmpty ? nil : value
            }

            var foldChange: Double? = nil
            if let fcIdx = foldChangeIndex, fcIdx < values.count {
                if var fc = Double(values[fcIdx]) {
                    if form.transformFC && fc > 0 {
                        fc = log2(fc)
                    }
                    if form.reverseFoldChange {
                        fc = -fc
                    }
                    foldChange = fc
                }
            }

            var significant: Double? = nil
            if let sigIdx = significantIndex, sigIdx < values.count {
                if var sig = Double(values[sigIdx]) {
                    if form.transformSignificant && sig > 0 {
                        sig = -log10(sig)
                    }
                    significant = sig
                }
            }

            var comparisonValue = "1"
            if let compIdx = comparisonIndex, compIdx < values.count {
                let value = values[compIdx]
                comparisonValue = value.isEmpty ? "1" : value
            }

            result.append(ProcessedProteomicsData(
                primaryId: primaryId,
                geneNames: geneNames,
                foldChange: foldChange,
                significant: significant,
                comparison: comparisonValue
            ))
        }

        return result
    }

    /// Parses raw TSV data into entities
    func parseRawData(rawTsv: String?, form: CurtainRawForm) -> [RawProteomicsData] {
        guard let tsv = rawTsv, !tsv.isEmpty, !form.samples.isEmpty else { return [] }

        let lines = tsv.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard !lines.isEmpty else { return [] }

        let headers = lines[0].components(separatedBy: "\t")
        guard let primaryIdIndex = headers.firstIndex(of: form.primaryIDs) else {
            print("[ProteomicsDataService] Primary ID column '\(form.primaryIDs)' not found in raw data")
            return []
        }

        let sampleIndices: [(String, Int)] = form.samples.compactMap { sampleName in
            if let index = headers.firstIndex(of: sampleName) {
                return (sampleName, index)
            }
            return nil
        }

        var result: [RawProteomicsData] = []

        for i in 1..<lines.count {
            let values = lines[i].components(separatedBy: "\t")
            guard values.count > primaryIdIndex else { continue }

            let primaryId = values[primaryIdIndex]

            for (sampleName, sampleIndex) in sampleIndices {
                guard sampleIndex < values.count else { continue }

                var sampleValue = Double(values[sampleIndex])

                if let value = sampleValue, form.log2 && value > 0 {
                    sampleValue = log2(value)
                }

                result.append(RawProteomicsData(
                    primaryId: primaryId,
                    sampleName: sampleName,
                    sampleValue: sampleValue
                ))
            }
        }

        return result
    }

    // MARK: - Store Metadata

    /// Stores curtain metadata to database
    func storeCurtainMetadata(curtainData: CurtainData, db: DatabaseQueue) throws {
        let encoder = JSONEncoder()

        let settingsJson = (try? String(data: JSONSerialization.data(withJSONObject: curtainData.settings.toDictionary()), encoding: .utf8)) ?? "{}"

        let rawFormDict: [String: Any] = [
            "primaryIDs": curtainData.rawForm.primaryIDs,
            "samples": curtainData.rawForm.samples,
            "log2": curtainData.rawForm.log2
        ]
        let rawFormJson = (try? String(data: JSONSerialization.data(withJSONObject: rawFormDict), encoding: .utf8)) ?? "{}"

        let diffFormDict: [String: Any] = [
            "primaryIDs": curtainData.differentialForm.primaryIDs,
            "geneNames": curtainData.differentialForm.geneNames,
            "foldChange": curtainData.differentialForm.foldChange,
            "transformFC": curtainData.differentialForm.transformFC,
            "significant": curtainData.differentialForm.significant,
            "transformSignificant": curtainData.differentialForm.transformSignificant,
            "comparison": curtainData.differentialForm.comparison,
            "comparisonSelect": curtainData.differentialForm.comparisonSelect,
            "reverseFoldChange": curtainData.differentialForm.reverseFoldChange
        ]
        let differentialFormJson = (try? String(data: JSONSerialization.data(withJSONObject: diffFormDict), encoding: .utf8)) ?? "{}"

        let selectionsJson: String? = curtainData.selections.flatMap { try? String(data: JSONSerialization.data(withJSONObject: $0), encoding: .utf8) }
        let selectionsMapJson: String? = curtainData.selectionsMap.flatMap { try? String(data: JSONSerialization.data(withJSONObject: $0), encoding: .utf8) }
        let selectedMapJson: String? = curtainData.selectedMap.flatMap { try? String(data: encoder.encode($0), encoding: .utf8) }
        let selectionsNameJson: String? = curtainData.selectionsName.flatMap { try? String(data: encoder.encode($0), encoding: .utf8) }

        let metadata = CurtainMetadata(
            id: 1,
            settingsJson: settingsJson,
            rawFormJson: rawFormJson,
            differentialFormJson: differentialFormJson,
            selectionsJson: selectionsJson,
            selectionsMapJson: selectionsMapJson,
            selectedMapJson: selectedMapJson,
            selectionsNameJson: selectionsNameJson,
            extraDataJson: nil,
            annotatedDataJson: nil,
            password: curtainData.password,
            fetchUniprot: curtainData.fetchUniprot,
            permanent: curtainData.permanent,
            bypassUniProt: curtainData.bypassUniProt
        )

        try db.write { database in
            try metadata.save(database)
        }
    }

    /// Parses and stores extra data maps (genes, primaryIds, etc.)
    func parseAndStoreExtraDataMaps(curtainData: CurtainData, db: DatabaseQueue) throws {
        guard let extraData = curtainData.extraData else { return }

        // Store data maps
        if let data = extraData.data {
            // GenesMap
            if let genesMap = data.genesMap {
                let entries = genesMap.map { key, value -> GenesMapEntry in
                    let jsonValue = (try? String(data: JSONSerialization.data(withJSONObject: value), encoding: .utf8)) ?? "{}"
                    return GenesMapEntry(key: key, value: jsonValue)
                }
                if !entries.isEmpty {
                    print("[ProteomicsDataService] Inserting \(entries.count) genesMap entries")
                    try db.write { database in
                        for entry in entries {
                            try entry.save(database)
                        }
                    }
                }
            }

            // PrimaryIDsMap
            if let primaryIDsMap = data.primaryIDsMap {
                let entries = primaryIDsMap.map { key, value -> PrimaryIdsMapEntry in
                    let jsonValue = (try? String(data: JSONSerialization.data(withJSONObject: value), encoding: .utf8)) ?? "{}"
                    return PrimaryIdsMapEntry(primaryId: key, value: jsonValue)
                }
                if !entries.isEmpty {
                    print("[ProteomicsDataService] Inserting \(entries.count) primaryIDsMap entries")
                    try db.write { database in
                        for entry in entries {
                            try entry.save(database)
                        }
                    }
                }
            }

            // AllGenes
            if let allGenes = data.allGenes, !allGenes.isEmpty {
                let entries = allGenes.map { AllGenesEntry(geneName: $0) }
                print("[ProteomicsDataService] Inserting \(entries.count) allGenes entries")
                try db.write { database in
                    for var entry in entries {
                        try entry.insert(database, onConflict: .ignore)
                    }
                }
            }
        }

        // Store UniProt maps
        if let uniprot = extraData.uniprot {
            if let geneNameToAcc = uniprot.geneNameToAcc {
                let entries = geneNameToAcc.compactMap { geneName, value -> GeneNameToAccEntry? in
                    let jsonValue = (try? String(data: JSONSerialization.data(withJSONObject: value), encoding: .utf8)) ?? ""
                    return GeneNameToAccEntry(geneName: geneName, accession: jsonValue)
                }
                if !entries.isEmpty {
                    print("[ProteomicsDataService] Inserting \(entries.count) geneNameToAcc entries")
                    try db.write { database in
                        for entry in entries {
                            try entry.save(database)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Query Methods

    /// Gets processed data for a specific protein
    func getProcessedDataForProtein(linkId: String, primaryId: String) throws -> [ProcessedProteomicsData] {
        let db = try databaseManager.getDatabaseForLinkId(linkId)
        return try db.read { database in
            try ProcessedProteomicsData
                .filter(Column("primaryId") == primaryId)
                .fetchAll(database)
        }
    }

    /// Gets raw data for a specific protein
    func getRawDataForProtein(linkId: String, primaryId: String) throws -> [RawProteomicsData] {
        let db = try databaseManager.getDatabaseForLinkId(linkId)
        return try db.read { database in
            try RawProteomicsData
                .filter(Column("primaryId") == primaryId)
                .fetchAll(database)
        }
    }

    /// Gets all processed data
    func getAllProcessedData(linkId: String) throws -> [ProcessedProteomicsData] {
        let db = try databaseManager.getDatabaseForLinkId(linkId)
        return try db.read { database in
            try ProcessedProteomicsData.fetchAll(database)
        }
    }

    /// Gets processed data by comparison
    func getProcessedDataByComparison(linkId: String, comparison: String) throws -> [ProcessedProteomicsData] {
        let db = try databaseManager.getDatabaseForLinkId(linkId)
        return try db.read { database in
            try ProcessedProteomicsData
                .filter(Column("comparison") == comparison)
                .fetchAll(database)
        }
    }

    /// Gets distinct primary IDs
    func getDistinctPrimaryIds(linkId: String) throws -> [String] {
        let db = try databaseManager.getDatabaseForLinkId(linkId)
        return try db.read { database in
            try String.fetchAll(database, sql: "SELECT DISTINCT primaryId FROM \(ProcessedProteomicsData.databaseTableName) ORDER BY primaryId")
        }
    }

    /// Gets processed data count
    func getProcessedDataCount(linkId: String) throws -> Int {
        let db = try databaseManager.getDatabaseForLinkId(linkId)
        return try db.read { database in
            try ProcessedProteomicsData.fetchCount(database)
        }
    }

    /// Gets raw data count
    func getRawDataCount(linkId: String) throws -> Int {
        let db = try databaseManager.getDatabaseForLinkId(linkId)
        return try db.read { database in
            try RawProteomicsData.fetchCount(database)
        }
    }

    /// Gets distinct protein count
    func getDistinctProteinCount(linkId: String) throws -> Int {
        let db = try databaseManager.getDatabaseForLinkId(linkId)
        return try db.read { database in
            try Int.fetchOne(database, sql: "SELECT COUNT(DISTINCT primaryId) FROM \(ProcessedProteomicsData.databaseTableName)") ?? 0
        }
    }

    /// Gets curtain metadata
    func getCurtainMetadata(linkId: String) throws -> CurtainMetadata? {
        let db = try databaseManager.getDatabaseForLinkId(linkId)
        return try db.read { database in
            try CurtainMetadata.fetchOne(database)
        }
    }

    /// Clears database for a linkId
    func clearDatabaseForLinkId(_ linkId: String) {
        databaseManager.clearAllData(linkId)
        print("[ProteomicsDataService] Cleared all proteomics data for \(linkId)")
    }

    // MARK: - Gene Name Resolution (Matching Android Pattern)

    /// Gets gene name for a protein ID from SQLite database
    /// This matches Android's approach where gene names are stored in processed_proteomics_data
    func getGeneNameForProtein(linkId: String, primaryId: String) -> String? {
        guard !linkId.isEmpty, !primaryId.isEmpty else { return nil }
        guard databaseManager.checkDataExists(linkId) else { return nil }

        do {
            let db = try databaseManager.getDatabaseForLinkId(linkId)
            return try db.read { database -> String? in
                // First try exact match
                if let data = try ProcessedProteomicsData
                    .filter(Column("primaryId") == primaryId)
                    .fetchOne(database),
                   let geneNames = data.geneNames, !geneNames.isEmpty {
                    return geneNames
                }

                // If not found, try matching any of the split IDs
                let splitIds = primaryId.split(separator: ";").map { String($0).trimmingCharacters(in: .whitespaces) }
                for splitId in splitIds {
                    if splitId.isEmpty { continue }
                    if let data = try ProcessedProteomicsData
                        .filter(Column("primaryId").like("%\(splitId)%"))
                        .fetchOne(database),
                       let geneNames = data.geneNames, !geneNames.isEmpty {
                        return geneNames
                    }
                }

                return nil
            }
        } catch {
            print("[ProteomicsDataService] Error getting gene name for \(primaryId): \(error)")
            return nil
        }
    }

    /// Gets gene names for multiple protein IDs (batch operation for efficiency)
    func getGeneNamesForProteins(linkId: String, primaryIds: [String]) -> [String: String] {
        guard !linkId.isEmpty, !primaryIds.isEmpty else { return [:] }
        guard databaseManager.checkDataExists(linkId) else { return [:] }

        var result: [String: String] = [:]

        do {
            let db = try databaseManager.getDatabaseForLinkId(linkId)
            try db.read { database in
                for primaryId in primaryIds {
                    if let data = try ProcessedProteomicsData
                        .filter(Column("primaryId") == primaryId)
                        .fetchOne(database),
                       let geneNames = data.geneNames, !geneNames.isEmpty {
                        result[primaryId] = geneNames
                    }
                }
            }
        } catch {
            print("[ProteomicsDataService] Error getting gene names batch: \(error)")
        }

        return result
    }
}

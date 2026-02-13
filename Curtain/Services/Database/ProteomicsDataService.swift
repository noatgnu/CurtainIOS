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
                    reverseFoldChange: diffFormDict["reverseFoldChange"] as? Bool ?? diffFormDict["_reverseFoldChange"] as? Bool ?? false,
                    // PTM-specific fields
                    accession: diffFormDict["accession"] as? String ?? diffFormDict["_accession"] as? String ?? "",
                    position: diffFormDict["position"] as? String ?? diffFormDict["_position"] as? String ?? "",
                    positionPeptide: diffFormDict["positionPeptide"] as? String ?? diffFormDict["_positionPeptide"] as? String ?? "",
                    peptideSequence: diffFormDict["peptideSequence"] as? String ?? diffFormDict["_peptideSequence"] as? String ?? "",
                    score: diffFormDict["score"] as? String ?? diffFormDict["_score"] as? String ?? ""
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
        var processedData = parseProcessedData(processedTsv: processedTsv, form: differentialForm)

        // Enrich PTM data with gene names from UniProt DB
        if differentialForm.isPTM {
            onProgress("Enriching PTM gene names...")
            processedData = enrichPTMGeneNames(processedData: processedData, curtainData: curtainData)
        }

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

        // PTM-specific column indices
        let accessionIndex = form.accession.isEmpty ? nil : headers.firstIndex(of: form.accession)
        let positionIndex = form.position.isEmpty ? nil : headers.firstIndex(of: form.position)
        let positionPeptideIndex = form.positionPeptide.isEmpty ? nil : headers.firstIndex(of: form.positionPeptide)
        let peptideSequenceIndex = form.peptideSequence.isEmpty ? nil : headers.firstIndex(of: form.peptideSequence)
        let scoreIndex = form.score.isEmpty ? nil : headers.firstIndex(of: form.score)

        // Debug: Log column detection
        print("[ProteomicsDataService] parseProcessedData headers: \(headers)")
        print("[ProteomicsDataService] form.geneNames column name: '\(form.geneNames)'")
        print("[ProteomicsDataService] geneNamesIndex: \(geneNamesIndex?.description ?? "nil")")
        if form.isPTM {
            print("[ProteomicsDataService] PTM mode detected - accession: \(accessionIndex?.description ?? "nil"), position: \(positionIndex?.description ?? "nil")")
        }

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

            // Parse PTM-specific fields
            let accession: String? = accessionIndex.flatMap { idx in
                guard idx < values.count else { return nil }
                let value = values[idx]
                return value.isEmpty ? nil : value
            }

            let position: String? = positionIndex.flatMap { idx in
                guard idx < values.count else { return nil }
                let value = values[idx]
                return value.isEmpty ? nil : value
            }

            let positionPeptide: String? = positionPeptideIndex.flatMap { idx in
                guard idx < values.count else { return nil }
                let value = values[idx]
                return value.isEmpty ? nil : value
            }

            let peptideSequence: String? = peptideSequenceIndex.flatMap { idx in
                guard idx < values.count else { return nil }
                let value = values[idx]
                return value.isEmpty ? nil : value
            }

            var score: Double? = nil
            if let scoreIdx = scoreIndex, scoreIdx < values.count {
                score = Double(values[scoreIdx])
            }

            result.append(ProcessedProteomicsData(
                primaryId: primaryId,
                geneNames: geneNames,
                foldChange: foldChange,
                significant: significant,
                comparison: comparisonValue,
                accession: accession,
                position: position,
                positionPeptide: positionPeptide,
                peptideSequence: peptideSequence,
                score: score
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

    // MARK: - PTM Gene Name Enrichment

    /// Enriches PTM data with gene names from UniProt DB
    /// This matches Android's enrichPTMGeneNames function
    func enrichPTMGeneNames(processedData: [ProcessedProteomicsData], curtainData: CurtainData) -> [ProcessedProteomicsData] {
        guard let uniprotDb = curtainData.extraData?.uniprot?.db as? [String: Any] else {
            print("[ProteomicsDataService] No UniProt DB found for PTM enrichment")
            return processedData
        }

        let accMap = curtainData.extraData?.uniprot?.accMap as? [String: Any]

        // Build accession -> geneName lookup
        var accessionToGeneName: [String: String] = [:]
        for (accession, record) in uniprotDb {
            guard let recordMap = record as? [String: Any],
                  let geneNames = recordMap["Gene Names"] as? String,
                  !geneNames.isEmpty else { continue }

            // Take first gene name (split by space, semicolon, or backslash)
            let separators = CharacterSet(charactersIn: " ;\\")
            let firstGene = geneNames.components(separatedBy: separators)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .first { !$0.isEmpty }

            if let firstGene = firstGene {
                accessionToGeneName[accession] = firstGene
            }
        }

        print("[ProteomicsDataService] Built accession→geneName map with \(accessionToGeneName.count) entries")

        // UniProt accession pattern
        let uniprotPattern = try? NSRegularExpression(
            pattern: "[OPQ][0-9][A-Z0-9]{3}[0-9]|[A-NR-Z][0-9]([A-Z][A-Z0-9]{2}[0-9]){1,2}",
            options: []
        )

        // Enrich gene names for entries missing them
        return processedData.map { entity in
            // Skip if already has gene name
            if let geneNames = entity.geneNames, !geneNames.isEmpty {
                return entity
            }

            guard let accession = entity.accession, !accession.isEmpty else {
                return entity
            }

            // Try direct lookup
            var geneName = accessionToGeneName[accession]

            // Try accMap lookup if direct lookup failed
            if geneName == nil, let accMap = accMap {
                if let canonical = accMap[accession] as? String {
                    geneName = accessionToGeneName[canonical]
                }
            }

            // Try regex extraction if still no match
            if geneName == nil, let pattern = uniprotPattern {
                let range = NSRange(accession.startIndex..., in: accession)
                if let match = pattern.firstMatch(in: accession, options: [], range: range),
                   let matchRange = Range(match.range, in: accession) {
                    let extractedAcc = String(accession[matchRange])
                    geneName = accessionToGeneName[extractedAcc]
                }
            }

            // Return enriched entity or original
            if let geneName = geneName {
                var enriched = entity
                enriched.geneNames = geneName
                return enriched
            }

            return entity
        }
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
            "reverseFoldChange": curtainData.differentialForm.reverseFoldChange,
            // PTM-specific fields
            "accession": curtainData.differentialForm.accession,
            "position": curtainData.differentialForm.position,
            "positionPeptide": curtainData.differentialForm.positionPeptide,
            "peptideSequence": curtainData.differentialForm.peptideSequence,
            "score": curtainData.differentialForm.score
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

    /// Safely serializes any value to JSON string
    /// JSONSerialization requires top-level type to be array or dictionary
    /// This wraps primitives in an array for serialization, then extracts just the value
    private func safeJsonSerialize(_ value: Any) -> String {
        // If it's already a dict or array, serialize directly
        if value is [String: Any] || value is [Any] {
            if let data = try? JSONSerialization.data(withJSONObject: value),
               let jsonString = String(data: data, encoding: .utf8) {
                return jsonString
            }
            return "{}"
        }

        // For primitives, wrap in array, serialize, then extract
        if let data = try? JSONSerialization.data(withJSONObject: [value]),
           let jsonString = String(data: data, encoding: .utf8),
           jsonString.hasPrefix("["),
           jsonString.hasSuffix("]") {
            // Remove the [ and ] wrapper
            let start = jsonString.index(after: jsonString.startIndex)
            let end = jsonString.index(before: jsonString.endIndex)
            return String(jsonString[start..<end])
        }

        // Fallback: convert to string
        return "\"\(value)\""
    }

    /// Unwraps special Map serialization format used by Curtain backend.
    /// Structure: { "dataType": "Map", "value": [ ["key1", value1], ["key2", value2], ... ] }
    /// Returns the unwrapped dictionary, or the original data if not in this format.
    private func unwrapMapData(_ data: Any?) -> [String: Any]? {
        guard let map = data as? [String: Any] else {
            return data as? [String: Any]
        }

        // Check for Map serialization format
        if let dataType = map["dataType"] as? String, dataType == "Map",
           let values = map["value"] as? [[Any]] {
            var result: [String: Any] = [:]
            for pair in values {
                if pair.count >= 2, let key = pair[0] as? String {
                    result[key] = pair[1]
                }
            }
            return result
        }

        // Return as-is if not Map serialization format
        return map
    }

    /// Parses and stores extra data maps (genes, primaryIds, etc.)
    func parseAndStoreExtraDataMaps(curtainData: CurtainData, db: DatabaseQueue) throws {
        guard let extraData = curtainData.extraData else { return }

        // Store data maps
        if let data = extraData.data {
            // GenesMap
            if let genesMap = data.genesMap {
                let entries = genesMap.map { key, value -> GenesMapEntry in
                    let jsonValue = safeJsonSerialize(value)
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
                    let jsonValue = safeJsonSerialize(value)
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
            // Handle geneNameToAcc - unwrap Map serialization format if present
            if let geneNameToAccRaw = uniprot.geneNameToAcc {
                // geneNameToAcc is already typed as [String: [String: Any]]? in UniprotExtraData
                // but we need to handle the case where it might be in Map serialization format
                let entries = geneNameToAccRaw.compactMap { geneName, value -> GeneNameToAccEntry? in
                    let jsonValue = safeJsonSerialize(value)
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

            // Store UniProt DB entries (accession -> full protein data)
            // First unwrap Map serialization format if present
            let uniprotDbData = unwrapMapData(uniprot.db)
            if let db_data = uniprotDbData {
                let entries = db_data.compactMap { accession, value -> UniProtDBEntry? in
                    let jsonString = safeJsonSerialize(value)
                    return UniProtDBEntry(accession: accession, dataJson: jsonString)
                }
                if !entries.isEmpty {
                    print("[ProteomicsDataService] Inserting \(entries.count) UniProt DB entries")
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

    /// Gets UniProt entry count from database
    func getUniProtEntryCount(linkId: String) throws -> Int {
        let db = try databaseManager.getDatabaseForLinkId(linkId)
        return try db.read { database in
            try UniProtDBEntry.fetchCount(database)
        }
    }

    /// Gets all genes count from database
    func getAllGenesCount(linkId: String) throws -> Int {
        let db = try databaseManager.getDatabaseForLinkId(linkId)
        return try db.read { database in
            try AllGenesEntry.fetchCount(database)
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

    // MARK: - PTM Data Methods

    /// Gets experimental PTM sites for a specific accession
    func getExperimentalPTMSites(
        linkId: String,
        accession: String,
        pCutoff: Double,
        fcCutoff: Double
    ) -> [ExperimentalPTMSite] {
        guard !linkId.isEmpty, !accession.isEmpty else {
            print("[ProteomicsDataService] getExperimentalPTMSites: Empty linkId or accession")
            return []
        }
        guard databaseManager.checkDataExists(linkId) else {
            print("[ProteomicsDataService] getExperimentalPTMSites: Database doesn't exist")
            return []
        }

        var sites: [ExperimentalPTMSite] = []

        do {
            let db = try databaseManager.getDatabaseForLinkId(linkId)
            try db.read { database in
                // Debug: Check how many rows have this accession
                let totalRows = try ProcessedProteomicsData.fetchCount(database)
                let matchingRows = try ProcessedProteomicsData
                    .filter(Column("accession") == accession)
                    .fetchCount(database)
                print("[ProteomicsDataService] getExperimentalPTMSites: Total rows=\(totalRows), matching '\(accession)'=\(matchingRows)")

                // Check sample accessions in DB
                if matchingRows == 0 {
                    let sampleAccessions = try ProcessedProteomicsData
                        .select(Column("accession"))
                        .distinct()
                        .limit(5)
                        .fetchAll(database)
                        .compactMap { $0.accession }
                    print("[ProteomicsDataService] Sample accessions in DB: \(sampleAccessions)")
                }

                let rows = try ProcessedProteomicsData
                    .filter(Column("accession") == accession)
                    .fetchAll(database)

                for row in rows {
                    guard let positionStr = row.position else { continue }

                    // Parse position from string (e.g., "S15" -> position 15)
                    let (position, positionResidue) = parsePositionString(positionStr)
                    guard let pos = position else { continue }

                    // Extract residue: prefer getting from peptide sequence using positionPeptide
                    let residue: Character
                    if let peptideSeq = row.peptideSequence,
                       let positionPeptideStr = row.positionPeptide,
                       let positionPeptide = Int(positionPeptideStr),
                       positionPeptide > 0 {
                        // Clean peptide sequence (remove modification annotations)
                        let cleanPeptide = cleanPeptideSequence(peptideSeq)
                        // positionPeptide is 1-based index
                        let idx = positionPeptide - 1
                        if idx >= 0 && idx < cleanPeptide.count {
                            let index = cleanPeptide.index(cleanPeptide.startIndex, offsetBy: idx)
                            residue = cleanPeptide[index]
                        } else if let r = positionResidue {
                            residue = r
                        } else {
                            residue = Character("?")
                        }
                    } else if let r = positionResidue {
                        // Fall back to residue from position string
                        residue = r
                    } else {
                        residue = Character("?")
                    }

                    // Calculate significance
                    let pValue = row.significant
                    let fc = row.foldChange
                    let isSignificant = (pValue ?? 1.0) <= pCutoff && abs(fc ?? 0.0) >= fcCutoff

                    sites.append(ExperimentalPTMSite(
                        primaryId: row.primaryId,
                        position: pos,
                        residue: residue,
                        modification: nil,
                        peptideSequence: row.peptideSequence,
                        foldChange: fc,
                        pValue: pValue,
                        isSignificant: isSignificant,
                        comparison: row.comparison,
                        score: row.score
                    ))
                }
            }
        } catch {
            print("[ProteomicsDataService] Error getting PTM sites for \(accession): \(error)")
        }

        return sites
    }

    /// Parses position string like "S15" into (position, residue)
    /// Matches Android's parsing logic using regex
    private func parsePositionString(_ positionStr: String) -> (Int?, Character?) {
        let trimmed = positionStr.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return (nil, nil) }

        // Extract position using regex to find digits
        let positionRegex = try? NSRegularExpression(pattern: "(\\d+)", options: [])
        let positionRange = NSRange(trimmed.startIndex..., in: trimmed)
        var position: Int? = nil

        if let match = positionRegex?.firstMatch(in: trimmed, options: [], range: positionRange),
           let range = Range(match.range(at: 1), in: trimmed) {
            position = Int(trimmed[range])
        }

        // Extract residue using regex to find uppercase letter followed by digits
        let residueRegex = try? NSRegularExpression(pattern: "([A-Z])\\d+", options: [])
        var residue: Character? = nil

        if let match = residueRegex?.firstMatch(in: trimmed, options: [], range: positionRange),
           let range = Range(match.range(at: 1), in: trimmed) {
            residue = trimmed[range].first
        }

        return (position, residue)
    }

    /// Cleans peptide sequence by removing modification annotations
    /// Matches Android's cleanPeptideSequence logic
    private func cleanPeptideSequence(_ peptide: String) -> String {
        var result = peptide
        // Remove bracketed annotations like [Phospho], [Oxidation]
        result = result.replacingOccurrences(of: "\\[.*?\\]", with: "", options: .regularExpression)
        // Remove parenthesized annotations like (ox), (ph)
        result = result.replacingOccurrences(of: "\\(.*?\\)", with: "", options: .regularExpression)
        // Remove common separators
        result = result.replacingOccurrences(of: "_", with: "")
        result = result.replacingOccurrences(of: ".", with: "")
        result = result.replacingOccurrences(of: "-", with: "")
        // Keep only letters and uppercase
        return result.filter { $0.isLetter }.uppercased()
    }

    /// Gets all PTM data for a specific accession
    func getPTMDataForAccession(linkId: String, accession: String) throws -> [ProcessedProteomicsData] {
        let db = try databaseManager.getDatabaseForLinkId(linkId)
        return try db.read { database in
            try ProcessedProteomicsData
                .filter(Column("accession") == accession)
                .fetchAll(database)
        }
    }

    /// Gets distinct accessions from PTM data
    func getDistinctAccessions(linkId: String) throws -> [String] {
        let db = try databaseManager.getDatabaseForLinkId(linkId)
        return try db.read { database in
            try String.fetchAll(database, sql: """
                SELECT DISTINCT accession FROM \(ProcessedProteomicsData.databaseTableName)
                WHERE accession IS NOT NULL AND accession != ''
                ORDER BY accession
                """)
        }
    }

    /// Gets UniProt data JSON for an accession
    func getUniProtDataJson(linkId: String, accession: String) -> [String: Any]? {
        guard !linkId.isEmpty, !accession.isEmpty else {
            print("[ProteomicsDataService] getUniProtDataJson: Empty linkId or accession")
            return nil
        }
        guard databaseManager.checkDataExists(linkId) else {
            print("[ProteomicsDataService] getUniProtDataJson: Database doesn't exist for \(linkId)")
            return nil
        }

        do {
            let db = try databaseManager.getDatabaseForLinkId(linkId)
            return try db.read { database -> [String: Any]? in
                // First check how many entries exist in uniprot_db
                let totalCount = try UniProtDBEntry.fetchCount(database)
                print("[ProteomicsDataService] Total UniProt DB entries: \(totalCount)")

                // Look up UniProt data in uniprot_db table
                if let entry = try UniProtDBEntry
                    .filter(Column("accession") == accession)
                    .fetchOne(database) {
                    print("[ProteomicsDataService] Found UniProt entry for accession: \(accession)")
                    if let data = entry.dataJson.data(using: .utf8),
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        print("[ProteomicsDataService] Parsed JSON with keys: \(json.keys.sorted())")
                        return json
                    } else {
                        print("[ProteomicsDataService] Failed to parse JSON for accession: \(accession)")
                    }
                } else {
                    print("[ProteomicsDataService] No UniProt entry found for accession: \(accession)")
                    // Try to list a few accessions that do exist
                    let sampleAccessions = try UniProtDBEntry.limit(5).fetchAll(database).map { $0.accession }
                    print("[ProteomicsDataService] Sample accessions in DB: \(sampleAccessions)")
                }
                return nil
            }
        } catch {
            print("[ProteomicsDataService] Error getting UniProt data for \(accession): \(error)")
            return nil
        }
    }

    /// Gets UniProt sequence for an accession
    func getUniProtSequence(linkId: String, accession: String) -> String? {
        guard let uniprotData = getUniProtDataJson(linkId: linkId, accession: accession) else {
            return nil
        }
        return SequenceAlignmentService.shared.extractSequence(uniprotData: uniprotData)
    }

    /// Gets gene name from UniProt data for an accession
    /// Used for PTM data where gene names need to be looked up via accession
    func getGeneNameFromAccession(linkId: String, accession: String) -> String? {
        guard let uniprotData = getUniProtDataJson(linkId: linkId, accession: accession) else {
            return nil
        }
        return SequenceAlignmentService.shared.extractGeneName(uniprotData: uniprotData)
    }
}

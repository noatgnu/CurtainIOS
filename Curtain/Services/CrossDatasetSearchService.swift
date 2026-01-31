//
//  CrossDatasetSearchService.swift
//  Curtain
//
//  Core engine for searching proteins across multiple datasets in parallel.
//

import Foundation

class CrossDatasetSearchService {

    private let dbManager = ProteomicsDataDatabaseManager.shared
    private let proteomicsDataService = ProteomicsDataService.shared
    private let proteinMappingService = ProteinMappingService.shared
    private let proteinSearchService = ProteinSearchService()

    var curtainRepository: CurtainRepository?

    // MARK: - Internal Types

    private struct DatasetSearchResult {
        var linkId: String
        var results: [String: ProteinDatasetResult] // keyed by searchTerm
    }

    private struct ProteinDatasetResult {
        var primaryId: String?
        var geneName: String?
        var found: Bool
        var hasSignificant: Bool
        var averageFoldChange: Double?
    }

    // MARK: - Input Parsing

    private func parseSearchInput(_ terms: [String]) -> [String] {
        terms.flatMap { term in
            term.components(separatedBy: CharacterSet.newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .flatMap { line in
                    if line.contains(";") {
                        return line.components(separatedBy: ";")
                            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                            .filter { !$0.isEmpty }
                    } else {
                        return [line]
                    }
                }
        }
        .reduce(into: [String]()) { result, term in
            if !result.contains(term) { result.append(term) }
        }
    }

    // MARK: - Dataset Name Resolution

    private func getDatasetDisplayName(linkId: String) -> String {
        guard let repo = curtainRepository,
              let curtain = repo.getCurtainById(linkId) else {
            return linkId
        }
        return curtain.dataDescription.isEmpty ? linkId : curtain.dataDescription
    }

    // MARK: - Gene Name Resolution (matches Android)

    private func getUniprotFromPrimary(_ id: String, curtainData: CurtainData) -> [String: Any]? {
        guard let uniprotDB = curtainData.extraData?.uniprot?.db as? [String: Any] else {
            return nil
        }

        if let record = uniprotDB[id] as? [String: Any] {
            return record
        }

        if let accMap = curtainData.extraData?.uniprot?.accMap {
            if let alternatives = accMap[id] {
                let dataMap = curtainData.extraData?.uniprot?.dataMap
                for alt in alternatives {
                    if let dataMap = dataMap,
                       let canonicalEntry = dataMap[alt] as? String,
                       let record = uniprotDB[canonicalEntry] as? [String: Any] {
                        return record
                    }
                }
            }
        }

        return nil
    }

    private func getGeneNameFromUniProt(_ id: String, curtainData: CurtainData) -> String? {
        guard let uniprotRecord = getUniprotFromPrimary(id, curtainData: curtainData) else {
            return nil
        }
        guard let geneNames = uniprotRecord["Gene Names"] as? String, !geneNames.isEmpty else {
            return nil
        }
        let parts = geneNames.components(separatedBy: CharacterSet(charactersIn: " ;\\"))
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return parts.first
    }

    private func getGeneNameForProtein(_ proteinId: String, linkId: String, curtainData: CurtainData) -> String? {
        var geneName: String?

        if curtainData.fetchUniprot {
            geneName = getGeneNameFromUniProt(proteinId, curtainData: curtainData)
        }

        if geneName == nil || geneName?.isEmpty == true {
            if let processedData = try? proteomicsDataService.getProcessedDataForProtein(linkId: linkId, primaryId: proteinId),
               let first = processedData.first,
               let gn = first.geneNames, !gn.isEmpty {
                geneName = gn
            }
        }

        return geneName
    }

    // MARK: - Main Entry Point

    func searchAcrossDatasets(
        config: CrossDatasetSearchConfig,
        onStatus: @escaping @Sendable (DatasetProcessingStatus) -> Void
    ) async -> CrossDatasetSearchResult {
        let searchTerms = parseSearchInput(config.searchTerms)
        let linkIds = config.datasetLinkIds

        let datasetResults = await withTaskGroup(of: DatasetSearchResult?.self, returning: [DatasetSearchResult].self) { group in
            for linkId in linkIds {
                group.addTask { [weak self] in
                    guard let self else { return nil }
                    return await self.searchInDataset(
                        linkId: linkId,
                        terms: searchTerms,
                        searchType: config.searchType,
                        useRegex: config.useRegex,
                        onStatus: onStatus
                    )
                }
            }

            var results: [DatasetSearchResult] = []
            for await result in group {
                if let result { results.append(result) }
            }
            return results
        }

        let summaries = aggregateResults(
            searchTerms: searchTerms,
            datasetResults: datasetResults,
            totalDatasets: linkIds.count,
            significantOnly: config.significantOnly,
            advancedFiltering: config.advancedFiltering
        )

        return CrossDatasetSearchResult(
            config: config,
            proteinSummaries: summaries,
            searchTimestamp: Date()
        )
    }

    // MARK: - Per-Dataset Search

    private func searchInDataset(
        linkId: String,
        terms: [String],
        searchType: SearchType,
        useRegex: Bool,
        onStatus: @escaping @Sendable (DatasetProcessingStatus) -> Void
    ) async -> DatasetSearchResult? {
        let datasetName = getDatasetDisplayName(linkId: linkId)
        var results: [String: ProteinDatasetResult] = [:]

        guard dbManager.checkDataExists(linkId) else {
            onStatus(DatasetProcessingStatus(id: linkId, datasetName: datasetName, state: .failed, error: "No data downloaded"))
            return DatasetSearchResult(linkId: linkId, results: [:])
        }

        onStatus(DatasetProcessingStatus(id: linkId, datasetName: datasetName, state: .loading))

        guard let curtainData = proteomicsDataService.loadCurtainDataFromDatabase(linkId: linkId) else {
            onStatus(DatasetProcessingStatus(id: linkId, datasetName: datasetName, state: .failed, error: "Failed to load dataset"))
            return DatasetSearchResult(linkId: linkId, results: [:])
        }

        onStatus(DatasetProcessingStatus(id: linkId, datasetName: datasetName, state: .building))
        proteinMappingService.ensureMappingsExist(linkId: linkId, curtainData: curtainData)

        onStatus(DatasetProcessingStatus(id: linkId, datasetName: datasetName, state: .searching))

        let inputText = terms.joined(separator: "\n")
        let searchResults = await proteinSearchService.performBatchSearch(
            inputText: inputText,
            searchType: searchType,
            linkId: linkId,
            idColumn: curtainData.differentialForm.primaryIDs,
            geneColumn: curtainData.differentialForm.geneNames,
            useRegex: useRegex
        )

        let pCutoff = curtainData.settings.pCutoff
        let fcCutoff = curtainData.settings.log2FCCutoff

        // Match Android's batchSearchProteins: iterate ALL matched primaryIds,
        // only include ones that have actual processedData in the database.
        for searchResult in searchResults {
            let searchTerm = searchResult.searchTerm
            guard !searchResult.matchedProteins.isEmpty else { continue }

            var resolvedPrimaryId: String?
            var resolvedGeneName: String?
            var foldChanges: [Double] = []
            var anySignificant = false
            var anyDataFound = false

            for primaryId in searchResult.matchedProteins {
                guard let processedData = try? proteomicsDataService.getProcessedDataForProtein(linkId: linkId, primaryId: primaryId),
                      !processedData.isEmpty else {
                    // Android skips primaryIds with no processedData
                    continue
                }

                anyDataFound = true

                // Use the first primaryId that has data (matches Android's firstResult)
                if resolvedPrimaryId == nil {
                    resolvedPrimaryId = primaryId
                    resolvedGeneName = getGeneNameForProtein(primaryId, linkId: linkId, curtainData: curtainData)
                }

                for entry in processedData {
                    let geneName = entry.geneNames
                    let fc = entry.foldChange
                    let p = entry.significant

                    if let fc { foldChanges.append(fc) }

                    // Match Android: p < pCutoff && abs(fc) > log2FCCutoff
                    let isSignificant: Bool = {
                        guard let pVal = p, let fcVal = fc else { return false }
                        return pVal < pCutoff && abs(fcVal) > fcCutoff
                    }()

                    if isSignificant { anySignificant = true }

                    // Use gene name from processedData if UniProt didn't resolve
                    if resolvedGeneName == nil, let gn = geneName, !gn.isEmpty {
                        resolvedGeneName = gn
                    }
                }
            }

            guard anyDataFound else { continue }

            let averageFoldChange = foldChanges.isEmpty ? nil : foldChanges.reduce(0, +) / Double(foldChanges.count)

            results[searchTerm] = ProteinDatasetResult(
                primaryId: resolvedPrimaryId,
                geneName: resolvedGeneName,
                found: true,
                hasSignificant: anySignificant,
                averageFoldChange: averageFoldChange
            )
        }

        onStatus(DatasetProcessingStatus(id: linkId, datasetName: datasetName, state: .completed))

        return DatasetSearchResult(linkId: linkId, results: results)
    }

    // MARK: - Aggregation

    private func aggregateResults(
        searchTerms: [String],
        datasetResults: [DatasetSearchResult],
        totalDatasets: Int,
        significantOnly: Bool,
        advancedFiltering: CrossDatasetAdvancedFilterParams? = nil
    ) -> [ProteinSearchSummary] {
        var summaries: [ProteinSearchSummary] = []

        for searchTerm in searchTerms {
            var resolvedPrimaryId: String?
            var accumulatedGeneNames: Set<String> = []
            var datasetsFoundIn = 0
            var hasSignificant = false
            var allFoldChanges: [Double] = []

            for datasetResult in datasetResults {
                if let result = datasetResult.results[searchTerm], result.found {
                    datasetsFoundIn += 1
                    if resolvedPrimaryId == nil { resolvedPrimaryId = result.primaryId }
                    if let geneName = result.geneName {
                        geneName.split(separator: ";").map { $0.trimmingCharacters(in: .whitespaces) }
                            .filter { !$0.isEmpty }
                            .forEach { accumulatedGeneNames.insert($0) }
                    }
                    if result.hasSignificant { hasSignificant = true }
                    if let fc = result.averageFoldChange { allFoldChanges.append(fc) }
                }
            }

            let resolvedGeneName = accumulatedGeneNames.isEmpty ? nil : accumulatedGeneNames.sorted().joined(separator: ";")

            guard datasetsFoundIn > 0 else { continue }

            let avgFC = allFoldChanges.isEmpty ? nil : allFoldChanges.reduce(0, +) / Double(allFoldChanges.count)

            // Apply advanced filtering (matches Android)
            let passesAdvancedFilter: Bool = {
                guard let params = advancedFiltering, let fc = avgFC else { return true }

                let passesLeftFilter: Bool
                if params.searchLeft && fc < 0 {
                    let absFC = abs(fc)
                    passesLeftFilter = (params.minFCLeft == nil || absFC >= params.minFCLeft!) &&
                                       (params.maxFCLeft == nil || absFC <= params.maxFCLeft!)
                } else {
                    passesLeftFilter = !params.searchLeft || fc >= 0
                }

                let passesRightFilter: Bool
                if params.searchRight && fc > 0 {
                    passesRightFilter = (params.minFCRight == nil || fc >= params.minFCRight!) &&
                                        (params.maxFCRight == nil || fc <= params.maxFCRight!)
                } else {
                    passesRightFilter = !params.searchRight || fc <= 0
                }

                if params.searchLeft && params.searchRight {
                    return passesLeftFilter || passesRightFilter
                } else if params.searchLeft {
                    return passesLeftFilter
                } else if params.searchRight {
                    return passesRightFilter
                }
                return true
            }()

            if (!significantOnly || hasSignificant) && passesAdvancedFilter {
                summaries.append(ProteinSearchSummary(
                    searchTerm: searchTerm,
                    primaryId: resolvedPrimaryId,
                    geneName: resolvedGeneName,
                    datasetsFoundIn: datasetsFoundIn,
                    totalDatasetsSearched: totalDatasets,
                    averageFoldChange: avgFC,
                    hasSignificantResult: hasSignificant
                ))
            }
        }

        return summaries.sorted { $0.datasetsFoundIn > $1.datasetsFoundIn }
    }

    // MARK: - Detailed Report

    func getProteinDetailedReport(
        searchTerm: String,
        primaryId: String?,
        datasetLinkIds: [String],
        searchType: SearchType
    ) async -> ProteinDetailedReport {
        var results: [DatasetComparisonResult] = []
        var resolvedPrimaryId = primaryId
        var accumulatedGeneNames: Set<String> = []

        for linkId in datasetLinkIds {
            let datasetName = getDatasetDisplayName(linkId: linkId)

            guard dbManager.checkDataExists(linkId) else {
                let info = DatasetComparisonInfo(linkId: linkId, datasetDescription: datasetName, comparison: "N/A")
                results.append(DatasetComparisonResult(datasetInfo: info, foldChange: nil, pValue: nil, isSignificant: false, found: false))
                continue
            }

            guard let curtainData = proteomicsDataService.loadCurtainDataFromDatabase(linkId: linkId) else {
                continue
            }

            proteinMappingService.ensureMappingsExist(linkId: linkId, curtainData: curtainData)

            // Match Android: use settings.currentComparison
            let comparison = curtainData.settings.currentComparison.isEmpty ? "1" : curtainData.settings.currentComparison

            let searchResults = await proteinSearchService.performBatchSearch(
                inputText: searchTerm,
                searchType: searchType,
                linkId: linkId,
                idColumn: curtainData.differentialForm.primaryIDs,
                geneColumn: curtainData.differentialForm.geneNames
            )

            let matchedIds = searchResults.flatMap { $0.matchedProteins }

            if matchedIds.isEmpty {
                let info = DatasetComparisonInfo(linkId: linkId, datasetDescription: datasetName, comparison: "N/A")
                results.append(DatasetComparisonResult(datasetInfo: info, foldChange: nil, pValue: nil, isSignificant: false, found: false))
            } else {
                let pCutoff = curtainData.settings.pCutoff
                let fcCutoff = curtainData.settings.log2FCCutoff
                var anyResultForDataset = false

                // Match Android: iterate all matched IDs, only use ones with processedData
                for matchedId in matchedIds {
                    guard let processedData = try? proteomicsDataService.getProcessedDataForProtein(linkId: linkId, primaryId: matchedId),
                          !processedData.isEmpty else {
                        continue
                    }

                    if resolvedPrimaryId == nil {
                        resolvedPrimaryId = matchedId
                    }

                    let geneName = getGeneNameForProtein(matchedId, linkId: linkId, curtainData: curtainData)
                    if let gn = geneName {
                        gn.split(separator: ";").map { $0.trimmingCharacters(in: .whitespaces) }
                            .filter { !$0.isEmpty }
                            .forEach { accumulatedGeneNames.insert($0) }
                    }

                    let info = DatasetComparisonInfo(linkId: linkId, datasetDescription: datasetName, comparison: comparison)

                    for entry in processedData {
                        let fc = entry.foldChange
                        let p = entry.significant

                        let isSignificant: Bool = {
                            guard let pVal = p, let fcVal = fc else { return false }
                            return pVal < pCutoff && abs(fcVal) > fcCutoff
                        }()

                        results.append(DatasetComparisonResult(
                            datasetInfo: info,
                            foldChange: fc,
                            pValue: p,
                            isSignificant: isSignificant,
                            found: true
                        ))
                        anyResultForDataset = true
                    }
                }

                // If no matched IDs had processedData, mark as not found
                if !anyResultForDataset {
                    let info = DatasetComparisonInfo(linkId: linkId, datasetDescription: datasetName, comparison: comparison)
                    results.append(DatasetComparisonResult(datasetInfo: info, foldChange: nil, pValue: nil, isSignificant: false, found: false))
                }
            }
        }

        let datasetsFoundIn = results.filter { $0.found }.map { $0.datasetInfo.linkId }.reduce(into: Set<String>()) { $0.insert($1) }.count
        let resolvedGeneName = accumulatedGeneNames.isEmpty ? nil : accumulatedGeneNames.sorted().joined(separator: ";")

        return ProteinDetailedReport(
            searchTerm: searchTerm,
            primaryId: resolvedPrimaryId,
            geneName: resolvedGeneName,
            results: results,
            datasetsFoundIn: datasetsFoundIn,
            totalDatasetsSearched: datasetLinkIds.count
        )
    }

    // MARK: - Matrix

    func buildCrossDatasetMatrix(
        searchResult: CrossDatasetSearchResult,
        filterOptions: MatrixFilterOptions
    ) async -> CrossDatasetMatrix {
        let datasetLinkIds = filterOptions.selectedDatasets.map { Array($0) } ?? searchResult.config.datasetLinkIds
        var proteinIds: [String] = []
        var proteinGeneNames: [String: String?] = [:]

        for summary in searchResult.proteinSummaries {
            let key = summary.primaryId ?? summary.searchTerm
            if !proteinIds.contains(key) {
                proteinIds.append(key)
                proteinGeneNames[key] = summary.geneName
            }
        }

        var rows: [MatrixRow] = []

        for linkId in datasetLinkIds {
            let datasetName = getDatasetDisplayName(linkId: linkId)

            guard let curtainData = proteomicsDataService.loadCurtainDataFromDatabase(linkId: linkId) else {
                continue
            }

            // Match Android: use settings.currentComparison
            let comparison = curtainData.settings.currentComparison.isEmpty ? "1" : curtainData.settings.currentComparison
            var cells: [String: MatrixCell] = [:]

            let pCutoff = curtainData.settings.pCutoff
            let fcCutoff = curtainData.settings.log2FCCutoff

            for summary in searchResult.proteinSummaries {
                let searchTerm = summary.searchTerm
                let proteinKey = summary.primaryId ?? searchTerm

                let searchResults = await proteinSearchService.performBatchSearch(
                    inputText: searchTerm,
                    searchType: searchResult.config.searchType,
                    linkId: linkId,
                    idColumn: curtainData.differentialForm.primaryIDs,
                    geneColumn: curtainData.differentialForm.geneNames,
                    useRegex: searchResult.config.useRegex
                )

                let matchedIds = searchResults.flatMap { $0.matchedProteins }

                if matchedIds.isEmpty {
                    cells[proteinKey] = MatrixCell(foldChange: nil, pValue: nil, isSignificant: false, found: false)
                } else {
                    // Match Android: iterate matched IDs, use first one with processedData
                    var cellCreated = false
                    for pid in matchedIds {
                        guard let processedData = try? proteomicsDataService.getProcessedDataForProtein(linkId: linkId, primaryId: pid),
                              let entry = processedData.first else {
                            continue
                        }

                        let fc = entry.foldChange
                        let p = entry.significant

                        let isSignificant: Bool = {
                            guard let pVal = p, let fcVal = fc else { return false }
                            return pVal < pCutoff && abs(fcVal) > fcCutoff
                        }()

                        let cell = MatrixCell(foldChange: fc, pValue: p, isSignificant: isSignificant, found: true)
                        let passesFilter = passesMatrixFilter(cell, options: filterOptions)
                        if passesFilter {
                            cells[proteinKey] = cell
                        } else {
                            cells[proteinKey] = MatrixCell(foldChange: fc, pValue: p, isSignificant: isSignificant, found: false)
                        }
                        cellCreated = true
                        break
                    }

                    if !cellCreated {
                        cells[proteinKey] = MatrixCell(foldChange: nil, pValue: nil, isSignificant: false, found: false)
                    }
                }
            }

            // Match Android: use settings.volcanoConditionLabels
            let conditionLabels = curtainData.settings.volcanoConditionLabels
            let condLeft: String? = (conditionLabels.enabled && !conditionLabels.leftCondition.isEmpty) ? conditionLabels.leftCondition : nil
            let condRight: String? = (conditionLabels.enabled && !conditionLabels.rightCondition.isEmpty) ? conditionLabels.rightCondition : nil

            rows.append(MatrixRow(
                datasetLinkId: linkId,
                datasetName: datasetName,
                comparison: comparison,
                conditionLeft: condLeft,
                conditionRight: condRight,
                cells: cells
            ))
        }

        return CrossDatasetMatrix(
            proteinIds: proteinIds,
            rows: rows,
            proteinGeneNames: proteinGeneNames
        )
    }

    private func passesMatrixFilter(_ cell: MatrixCell, options: MatrixFilterOptions) -> Bool {
        if !cell.found { return !options.hideNotFound }
        if options.showSignificantOnly && !cell.isSignificant { return false }
        if let minFC = options.minFoldChange, let fc = cell.foldChange, abs(fc) < minFC { return false }
        if let maxP = options.maxPValue, let p = cell.pValue, p > maxP { return false }
        return true
    }

    // MARK: - CSV Export

    func exportResultsAsCSV(result: CrossDatasetSearchResult) -> String {
        let header = "Search Term,Primary ID,Gene Name,Datasets Found,Total Datasets,Average FC,Has Significant"
        var rows: [String] = [header]
        for s in result.proteinSummaries {
            let row = [
                escapeCSV(s.searchTerm),
                escapeCSV(s.primaryId ?? ""),
                escapeCSV(s.geneName ?? ""),
                String(s.datasetsFoundIn),
                String(s.totalDatasetsSearched),
                s.averageFoldChange.map { String(format: "%.4f", $0) } ?? "",
                s.hasSignificantResult ? "Yes" : "No"
            ].joined(separator: ",")
            rows.append(row)
        }
        return rows.joined(separator: "\n")
    }

    func exportProteinReport(_ report: ProteinDetailedReport) -> String {
        let header = "Search Term,Primary ID,Gene Name,Dataset,Comparison,Fold Change,P-Value,Significant,Found"
        var rows: [String] = [header]
        for result in report.results {
            let row = [
                escapeCSV(report.searchTerm),
                escapeCSV(report.primaryId ?? ""),
                escapeCSV(report.geneName ?? ""),
                escapeCSV(result.datasetInfo.datasetDescription),
                escapeCSV(result.datasetInfo.comparison),
                result.foldChange.map { String(format: "%.4f", $0) } ?? "",
                result.pValue.map { String(format: "%.6f", $0) } ?? "",
                result.isSignificant ? "Yes" : "No",
                result.found ? "Yes" : "No"
            ].joined(separator: ",")
            rows.append(row)
        }
        return rows.joined(separator: "\n")
    }

    func exportMatrixAsCSV(matrix: CrossDatasetMatrix) -> String {
        var csv = "Dataset,Comparison,Condition Left,Condition Right"
        for pid in matrix.proteinIds {
            let name = matrix.proteinGeneNames[pid] ?? nil
            csv += ",\(name ?? pid)"
        }
        csv += "\n"

        for row in matrix.rows {
            csv += "\(escapeCSV(row.datasetName)),\(escapeCSV(row.comparison)),\(escapeCSV(row.conditionLeft ?? "")),\(escapeCSV(row.conditionRight ?? ""))"
            for pid in matrix.proteinIds {
                if let cell = row.cells[pid] {
                    if cell.found, let fc = cell.foldChange {
                        csv += ",\(String(format: "%.4f", fc))"
                    } else {
                        csv += ",N/F"
                    }
                } else {
                    csv += ",N/F"
                }
            }
            csv += "\n"
        }
        return csv
    }

    private func escapeCSV(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return value
    }
}

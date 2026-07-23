import XCTest
@testable import Curtain

final class CrossDatasetSearchTests: XCTestCase {

    private let searchService = CrossDatasetSearchService()
    private let proteomicsDataService = ProteomicsDataService.shared
    private let proteinMappingService = ProteinMappingService.shared
    private let dbManager = ProteomicsDataDatabaseManager.shared

    // MARK: - Helpers

    private func downloadCurtainData(linkId: String, hostname: String) async throws -> [String: Any] {
        let apiURL = "\(hostname)curtain/\(linkId)/download/token=/"
        let (urlData, urlResponse) = try await URLSession.shared.data(from: URL(string: apiURL)!)
        guard let httpResponse = urlResponse as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSError(domain: "Test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to get signed URL"])
        }
        guard let urlJson = try JSONSerialization.jsonObject(with: urlData) as? [String: Any],
              let signedUrl = urlJson["url"] as? String else {
            throw NSError(domain: "Test", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to parse signed URL"])
        }
        let (data, dataResponse) = try await URLSession.shared.data(from: URL(string: signedUrl)!)
        guard let s3Response = dataResponse as? HTTPURLResponse, s3Response.statusCode == 200 else {
            throw NSError(domain: "Test", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to download from S3"])
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "Test", code: 4, userInfo: [NSLocalizedDescriptionKey: "Failed to parse JSON"])
        }
        return json
    }

    private func buildCurtainDataForIngestion(jsonMap: [String: Any]) -> (CurtainData, CurtainRawForm, CurtainDifferentialForm) {
        let settingsDict = jsonMap["settings"] as? [String: Any] ?? [:]
        let settings = CurtainSettings.fromDictionary(settingsDict)

        let rawForm: CurtainRawForm
        if let rawFormDict = jsonMap["rawForm"] as? [String: Any] {
            rawForm = CurtainRawForm(
                primaryIDs: rawFormDict["_primaryIDs"] as? String ?? "",
                samples: rawFormDict["_samples"] as? [String] ?? [],
                log2: rawFormDict["_log2"] as? Bool ?? false
            )
        } else {
            rawForm = CurtainRawForm()
        }

        let differentialForm: CurtainDifferentialForm
        if let diffFormDict = jsonMap["differentialForm"] as? [String: Any] {
            differentialForm = CurtainDifferentialForm(
                primaryIDs: diffFormDict["_primaryIDs"] as? String ?? "",
                geneNames: diffFormDict["_geneNames"] as? String ?? "",
                foldChange: diffFormDict["_foldChange"] as? String ?? "",
                transformFC: diffFormDict["_transformFC"] as? Bool ?? false,
                significant: diffFormDict["_significant"] as? String ?? "",
                transformSignificant: diffFormDict["_transformSignificant"] as? Bool ?? false,
                comparison: diffFormDict["_comparison"] as? String ?? "",
                comparisonSelect: diffFormDict["_comparisonSelect"] as? [String] ?? [],
                reverseFoldChange: diffFormDict["_reverseFoldChange"] as? Bool ?? false,
                accession: diffFormDict["_accession"] as? String ?? "",
                position: diffFormDict["_position"] as? String ?? "",
                positionPeptide: diffFormDict["_positionPeptide"] as? String ?? "",
                peptideSequence: diffFormDict["_peptideSequence"] as? String ?? "",
                score: diffFormDict["_score"] as? String ?? ""
            )
        } else {
            differentialForm = CurtainDifferentialForm()
        }

        var extraData: ExtraData? = nil
        if let extraDataObj = jsonMap["extraData"] as? [String: Any] {
            var uniprotData: UniprotExtraData? = nil
            if let uniprotObj = extraDataObj["uniprot"] as? [String: Any] {
                uniprotData = UniprotExtraData(
                    results: uniprotObj["results"] as? [String: Any] ?? [:],
                    dataMap: uniprotObj["dataMap"] as? [String: Any],
                    db: uniprotObj["db"] as? [String: Any],
                    organism: uniprotObj["organism"] as? String,
                    accMap: uniprotObj["accMap"] as? [String: [String]],
                    geneNameToAcc: uniprotObj["geneNameToAcc"] as? [String: [String: Any]]
                )
            }
            var dataContainer: DataMapContainer? = nil
            if let dataObj = extraDataObj["data"] as? [String: Any] {
                dataContainer = DataMapContainer(
                    dataMap: dataObj["dataMap"] as? [String: Any],
                    genesMap: dataObj["genesMap"] as? [String: [String: Any]],
                    primaryIDsMap: dataObj["primaryIDsMap"] as? [String: [String: Any]],
                    allGenes: dataObj["allGenes"] as? [String]
                )
            }
            extraData = ExtraData(uniprot: uniprotData, data: dataContainer)
        }

        let selectedMap = jsonMap["selectionsMap"] as? [String: [String: Bool]]
        let selectionsName = jsonMap["selectionsName"] as? [String]

        let curtainData = CurtainData(
            raw: jsonMap["raw"] as? String,
            rawForm: rawForm,
            differentialForm: differentialForm,
            processed: jsonMap["processed"] as? String,
            password: jsonMap["password"] as? String ?? "",
            selections: jsonMap["selections"] as? [String: [Any]],
            selectionsMap: jsonMap["selectionsMap"] as? [String: Any],
            selectedMap: selectedMap,
            selectionsName: selectionsName,
            settings: settings,
            fetchUniprot: jsonMap["fetchUniprot"] as? Bool ?? true,
            annotatedData: jsonMap["annotatedData"],
            extraData: extraData,
            permanent: jsonMap["permanent"] as? Bool ?? false,
            bypassUniProt: jsonMap["bypassUniProt"] as? Bool ?? false
        )

        return (curtainData, rawForm, differentialForm)
    }

    private func setupDataset(linkId: String, hostname: String) async throws -> CurtainData {
        let json = try await downloadCurtainData(linkId: linkId, hostname: hostname)
        let (curtainData, rawForm, differentialForm) = buildCurtainDataForIngestion(jsonMap: json)

        let rawTsv = json["raw"] as? String
        let processedTsv = json["processed"] as? String

        dbManager.clearAllData(linkId)
        proteinMappingService.clearMappings(linkId: linkId)

        try proteomicsDataService.buildProteomicsDataIfNeeded(
            linkId: linkId,
            rawTsv: rawTsv,
            processedTsv: processedTsv,
            rawForm: rawForm,
            differentialForm: differentialForm,
            curtainData: curtainData,
            onProgress: { _ in }
        )
        proteinMappingService.ensureMappingsExist(linkId: linkId, curtainData: curtainData)

        return curtainData
    }

    private func performSearch(
        terms: [String],
        searchType: SearchType,
        datasetLinkIds: [String],
        significantOnly: Bool = false,
        useRegex: Bool = false
    ) async -> CrossDatasetSearchResult {
        let config = CrossDatasetSearchConfig(
            searchTerms: terms,
            searchType: searchType,
            datasetLinkIds: datasetLinkIds,
            significantOnly: significantOnly,
            useRegex: useRegex,
            advancedFiltering: nil
        )
        return await searchService.searchAcrossDatasets(config: config) { _ in }
    }

    // MARK: - Diagnostic: Verify Pipeline Steps

    func testDiagnosticPipelineTP() async throws {
        let linkId = TPDatasetConstants.linkId
        let curtainData = try await setupDataset(linkId: linkId, hostname: CurtainConstants.ExampleData.apiUrl)

        // Step 1: Verify data was ingested
        let dataExists = dbManager.checkDataExists(linkId)
        XCTAssertTrue(dataExists, "Step 1: Data should exist after ingestion")

        // Step 2: Verify processed data count
        let processedCount = try proteomicsDataService.getProcessedDataCount(linkId: linkId)
        XCTAssertGreaterThan(processedCount, 0, "Step 2: Should have processed data")
        print("Step 2: processedCount = \(processedCount)")

        // Step 3: Verify Q2M2I8 exists in processed data
        let q2m2i8 = try proteomicsDataService.getProcessedDataForProtein(linkId: linkId, primaryId: "Q2M2I8")
        XCTAssertFalse(q2m2i8.isEmpty, "Step 3: Q2M2I8 should exist in processed data")
        print("Step 3: Q2M2I8 rows = \(q2m2i8.count), geneNames = \(q2m2i8.first?.geneNames ?? "nil")")

        // Step 4: Verify UniProt data was available
        let uniprotDB = curtainData.extraData?.uniprot?.db as? [String: Any]
        let uniprotCount = uniprotDB?.count ?? 0
        XCTAssertGreaterThan(uniprotCount, 0, "Step 4: UniProt data should be present in CurtainData")
        print("Step 4: UniProt entries = \(uniprotCount)")

        // Step 5: Verify gene name mappings exist
        let aak1Ids = proteinMappingService.getPrimaryIdsFromGeneName(linkId: linkId, geneName: "AAK1")
        print("Step 5: getPrimaryIdsFromGeneName('AAK1') = \(aak1Ids)")
        XCTAssertFalse(aak1Ids.isEmpty, "Step 5: Gene name mapping for AAK1 should exist")
        XCTAssertTrue(aak1Ids.contains("Q2M2I8"), "Step 5: AAK1 should map to Q2M2I8")

        // Step 6: Verify primary ID mappings exist
        let q2m2i8Ids = proteinMappingService.getPrimaryIdsFromSplitId(linkId: linkId, splitId: "Q2M2I8")
        print("Step 6: getPrimaryIdsFromSplitId('Q2M2I8') = \(q2m2i8Ids)")
        XCTAssertFalse(q2m2i8Ids.isEmpty, "Step 6: Primary ID mapping for Q2M2I8 should exist")

        // Step 7: Verify loadCurtainDataFromDatabase works
        let loadedData = proteomicsDataService.loadCurtainDataFromDatabase(linkId: linkId)
        XCTAssertNotNil(loadedData, "Step 7: Should load CurtainData from database")
        print("Step 7: loadedData.differentialForm.primaryIDs = \(loadedData?.differentialForm.primaryIDs ?? "nil")")

        // Step 8: Direct performBatchSearch
        let proteinSearchService = ProteinSearchService()
        let searchResults = await proteinSearchService.performBatchSearch(
            inputText: "AAK1",
            searchType: .geneName,
            linkId: linkId,
            idColumn: loadedData?.differentialForm.primaryIDs ?? "Index",
            geneColumn: loadedData?.differentialForm.geneNames ?? ""
        )
        print("Step 8: performBatchSearch results = \(searchResults.count)")
        for sr in searchResults {
            print("  searchTerm=\(sr.searchTerm), matchedProteins=\(sr.matchedProteins)")
        }
        XCTAssertGreaterThan(searchResults.count, 0, "Step 8: performBatchSearch should find AAK1")

        // Step 9: Full searchAcrossDatasets
        let result = await performSearch(
            terms: ["AAK1"],
            searchType: .geneName,
            datasetLinkIds: [linkId]
        )
        print("Step 9: searchAcrossDatasets results = \(result.proteinSummaries.count)")
        for s in result.proteinSummaries {
            print("  term=\(s.searchTerm), primaryId=\(s.primaryId ?? "nil"), fc=\(s.averageFoldChange ?? 0)")
        }
        XCTAssertGreaterThan(result.proteinSummaries.count, 0, "Step 9: Cross-dataset search should find AAK1")
    }

    // MARK: - TP Search by Gene Name

    func testTPSearchByGeneName() async throws {
        let linkId = TPDatasetConstants.linkId
        let _ = try await setupDataset(linkId: linkId, hostname: CurtainConstants.ExampleData.apiUrl)

        let result = await performSearch(
            terms: ["AAK1", "AKT1", "ABL1"],
            searchType: .geneName,
            datasetLinkIds: [linkId]
        )

        XCTAssertEqual(result.proteinSummaries.count, 3, "Should find all 3 searched genes")

        for summary in result.proteinSummaries {
            XCTAssertEqual(summary.datasetsFoundIn, 1)
            XCTAssertEqual(summary.totalDatasetsSearched, 1)
            XCTAssertNotNil(summary.primaryId)
            XCTAssertNotNil(summary.averageFoldChange)
        }

        let aak1 = result.proteinSummaries.first { $0.searchTerm == "AAK1" }
        XCTAssertNotNil(aak1)
        XCTAssertEqual(aak1?.primaryId, "Q2M2I8")

        let akt1 = result.proteinSummaries.first { $0.searchTerm == "AKT1" }
        XCTAssertNotNil(akt1)
        XCTAssertEqual(akt1?.primaryId, "P31749")
    }

    // MARK: - TP Search by Primary ID

    func testTPSearchByPrimaryID() async throws {
        let linkId = TPDatasetConstants.linkId
        let _ = try await setupDataset(linkId: linkId, hostname: CurtainConstants.ExampleData.apiUrl)

        let result = await performSearch(
            terms: ["Q2M2I8", "P00519", "P31749"],
            searchType: .primaryID,
            datasetLinkIds: [linkId]
        )

        XCTAssertEqual(result.proteinSummaries.count, 3, "Should find all 3 primary IDs")

        let q2m2i8 = result.proteinSummaries.first { $0.searchTerm == "Q2M2I8" }
        XCTAssertNotNil(q2m2i8)
        XCTAssertEqual(q2m2i8?.primaryId, "Q2M2I8")
        if let fc = q2m2i8?.averageFoldChange {
            let expected = TPDatasetConstants.knownProteins.first { $0.id == "Q2M2I8" }!.foldChange
            XCTAssertEqual(fc, expected, accuracy: 0.01)
        }
    }

    // MARK: - TP Search Not Found

    func testTPSearchNotFound() async throws {
        let linkId = TPDatasetConstants.linkId
        let _ = try await setupDataset(linkId: linkId, hostname: CurtainConstants.ExampleData.apiUrl)

        let result = await performSearch(
            terms: ["NONEXISTENT_GENE_12345"],
            searchType: .geneName,
            datasetLinkIds: [linkId]
        )

        XCTAssertEqual(result.proteinSummaries.count, 0)
    }

    // MARK: - TP Significant Only Filter

    func testTPSearchSignificantOnly() async throws {
        let linkId = TPDatasetConstants.linkId
        let _ = try await setupDataset(linkId: linkId, hostname: CurtainConstants.ExampleData.apiUrl)

        let allResult = await performSearch(
            terms: ["AAK1", "AKT1"],
            searchType: .geneName,
            datasetLinkIds: [linkId]
        )

        let sigResult = await performSearch(
            terms: ["AAK1", "AKT1"],
            searchType: .geneName,
            datasetLinkIds: [linkId],
            significantOnly: true
        )

        XCTAssertGreaterThanOrEqual(allResult.proteinSummaries.count, sigResult.proteinSummaries.count)
    }

    // MARK: - PTM Search by Gene Name

    func testPTMSearchByGeneName() async throws {
        let linkId = PTMDatasetConstants.linkId
        let _ = try await setupDataset(linkId: linkId, hostname: CurtainConstants.ExamplePTMData.apiUrl)

        let result = await performSearch(
            terms: ["Nova2"],
            searchType: .geneName,
            datasetLinkIds: [linkId]
        )

        XCTAssertGreaterThanOrEqual(result.proteinSummaries.count, 1, "Should find Nova2")
    }

    // MARK: - PTM Search by Primary ID

    func testPTMSearchByPrimaryID() async throws {
        let linkId = PTMDatasetConstants.linkId
        let _ = try await setupDataset(linkId: linkId, hostname: CurtainConstants.ExamplePTMData.apiUrl)

        let result = await performSearch(
            terms: ["A0A1W2P872_K427"],
            searchType: .primaryID,
            datasetLinkIds: [linkId]
        )

        XCTAssertEqual(result.proteinSummaries.count, 1)

        let entry = result.proteinSummaries.first
        XCTAssertNotNil(entry)
        XCTAssertEqual(entry?.primaryId, "A0A1W2P872_K427")
        if let fc = entry?.averageFoldChange {
            XCTAssertEqual(fc, PTMDatasetConstants.samplePTMEntries.first!.foldChange, accuracy: 0.01)
        }
    }

    // MARK: - PTM Search by Accession

    func testPTMSearchByAccession() async throws {
        let linkId = PTMDatasetConstants.linkId
        let _ = try await setupDataset(linkId: linkId, hostname: CurtainConstants.ExamplePTMData.apiUrl)

        let result = await performSearch(
            terms: ["A0A1W2P872"],
            searchType: .accessionID,
            datasetLinkIds: [linkId]
        )

        XCTAssertGreaterThanOrEqual(result.proteinSummaries.count, 1)
    }

    // MARK: - PTM Results Grouped by Accession

    func testPTMResultsGroupByAccession() async throws {
        let linkId = PTMDatasetConstants.linkId
        let _ = try await setupDataset(linkId: linkId, hostname: CurtainConstants.ExamplePTMData.apiUrl)

        let allProcessed = try proteomicsDataService.getAllProcessedData(linkId: linkId)
        let grouped = Dictionary(grouping: allProcessed) { $0.accession ?? "Unknown" }

        XCTAssertGreaterThan(grouped.count, 100)

        let nova2Sites = grouped["A0A1W2P872"] ?? []
        XCTAssertGreaterThan(nova2Sites.count, 1)

        for site in nova2Sites {
            XCTAssertEqual(site.accession, "A0A1W2P872")
        }
    }

    // MARK: - TP and PTM Cannot Be Mixed

    func testTPAndPTMCannotBeMixed() async throws {
        let tpData = try await setupDataset(linkId: TPDatasetConstants.linkId, hostname: CurtainConstants.ExampleData.apiUrl)
        let ptmData = try await setupDataset(linkId: PTMDatasetConstants.linkId, hostname: CurtainConstants.ExamplePTMData.apiUrl)

        XCTAssertFalse(tpData.differentialForm.isPTM)
        XCTAssertTrue(ptmData.differentialForm.isPTM)
        XCTAssertEqual(tpData.curtainType, "TP")
        XCTAssertEqual(ptmData.curtainType, "PTM")
    }

    // MARK: - TP Fold Change Values Match Expected

    func testTPFoldChangeValues() async throws {
        let linkId = TPDatasetConstants.linkId
        let _ = try await setupDataset(linkId: linkId, hostname: CurtainConstants.ExampleData.apiUrl)

        let knownIds = TPDatasetConstants.knownProteins.map { $0.id }
        let result = await performSearch(
            terms: knownIds,
            searchType: .primaryID,
            datasetLinkIds: [linkId]
        )

        for known in TPDatasetConstants.knownProteins {
            let found = result.proteinSummaries.first { $0.primaryId == known.id }
            XCTAssertNotNil(found, "Should find \(known.id) (\(known.gene))")
            if let fc = found?.averageFoldChange {
                XCTAssertEqual(fc, known.foldChange, accuracy: 0.01, "\(known.id) fold change mismatch")
            }
        }
    }

    // MARK: - PTM Fold Change Values Match Expected

    func testPTMFoldChangeValues() async throws {
        let linkId = PTMDatasetConstants.linkId
        let _ = try await setupDataset(linkId: linkId, hostname: CurtainConstants.ExamplePTMData.apiUrl)

        let knownIds = PTMDatasetConstants.samplePTMEntries.map { $0.primaryId }
        let result = await performSearch(
            terms: knownIds,
            searchType: .primaryID,
            datasetLinkIds: [linkId]
        )

        for known in PTMDatasetConstants.samplePTMEntries {
            let found = result.proteinSummaries.first { $0.primaryId == known.primaryId }
            XCTAssertNotNil(found, "Should find \(known.primaryId)")
            if let fc = found?.averageFoldChange {
                XCTAssertEqual(fc, known.foldChange, accuracy: 0.01, "\(known.primaryId) fold change mismatch")
            }
        }
    }

    // MARK: - Search Result Metadata

    func testSearchResultMetadata() async throws {
        let linkId = TPDatasetConstants.linkId
        let _ = try await setupDataset(linkId: linkId, hostname: CurtainConstants.ExampleData.apiUrl)

        let result = await performSearch(
            terms: ["Q2M2I8"],
            searchType: .primaryID,
            datasetLinkIds: [linkId]
        )

        XCTAssertNotNil(result.searchTimestamp)
        XCTAssertEqual(result.config.searchTerms, ["Q2M2I8"])
        XCTAssertEqual(result.config.searchType, .primaryID)
        XCTAssertEqual(result.config.datasetLinkIds, [linkId])
        XCTAssertFalse(result.config.significantOnly)
        XCTAssertFalse(result.config.useRegex)
    }
}

//
//  ExampleDatasetTests.swift
//  CurtainTests
//
//  Tests using real data downloaded from the server
//

import XCTest
@testable import Curtain

final class ExampleDatasetTests: XCTestCase {

    // MARK: - Helper Methods

    /// Downloads data using the two-step process: API -> signed URL -> S3
    private func downloadCurtainData(linkId: String, hostname: String) async throws -> (Data, [String: Any]) {
        // Step 1: Get signed S3 URL from API
        let apiURL = "\(hostname)curtain/\(linkId)/download/token=/"

        let (urlData, urlResponse) = try await URLSession.shared.data(from: URL(string: apiURL)!)

        guard let httpResponse = urlResponse as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSError(domain: "ExampleDatasetTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to get signed URL"])
        }

        guard let urlJson = try JSONSerialization.jsonObject(with: urlData) as? [String: Any],
              let signedUrl = urlJson["url"] as? String else {
            throw NSError(domain: "ExampleDatasetTests", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to parse signed URL"])
        }

        // Step 2: Download actual data from S3
        let (data, dataResponse) = try await URLSession.shared.data(from: URL(string: signedUrl)!)

        guard let s3Response = dataResponse as? HTTPURLResponse, s3Response.statusCode == 200 else {
            throw NSError(domain: "ExampleDatasetTests", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to download from S3"])
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "ExampleDatasetTests", code: 4, userInfo: [NSLocalizedDescriptionKey: "Failed to parse JSON"])
        }

        return (data, json)
    }

    // MARK: - TP Dataset Tests

    func testTPDatasetRestoreSettings() async throws {
        // Download real TP data from server
        let linkId = CurtainConstants.ExampleData.uniqueId
        let hostname = CurtainConstants.ExampleData.apiUrl

        let (_, jsonObject) = try await downloadCurtainData(linkId: linkId, hostname: hostname)

        let service = CurtainDataService()
        try await service.restoreSettings(from: jsonObject)

        // Verify settings parsing - actual values from the TP dataset
        XCTAssertEqual(service.curtainSettings.pCutoff, 0.05, "pCutoff should be 0.05")
        XCTAssertEqual(service.curtainSettings.log2FCCutoff, 0.6, "log2FCCutoff should be 0.6")
        XCTAssertEqual(service.curtainSettings.conditionOrder, ["4Hr-AGB1", "24Hr-AGB1", "4Hr-Cis", "24Hr-Cis"], "conditionOrder should match")

        // Verify form parsing
        XCTAssertEqual(service.curtainData.differentialForm?.primaryIDs, "Index", "primaryIDs should be 'Index'")
        XCTAssertEqual(service.curtainData.differentialForm?.foldChange, "Difference(Log2): 4HrAGB1/4HrCis", "foldChange column should match")

        // Verify processed data exists
        let processedData = service.curtainData.dataMap?["processedDifferentialData"] as? [[String: Any]]
        XCTAssertNotNil(processedData, "processedDifferentialData should exist")
        XCTAssertGreaterThan(processedData?.count ?? 0, 0, "Should have processed data rows")

        if let firstRow = processedData?.first {
            XCTAssertNotNil(firstRow["Index"], "First row should have Index")
            XCTAssertNotNil(firstRow["Difference(Log2): 4HrAGB1/4HrCis"], "First row should have fold change")
            XCTAssertNotNil(firstRow["pValue(-Log10): 4HrAGB1/4HrCis"], "First row should have p-value")
        }
    }

    func testTPDatasetProcessesSampleMap() async throws {
        let linkId = CurtainConstants.ExampleData.uniqueId
        let hostname = CurtainConstants.ExampleData.apiUrl

        let (_, jsonObject) = try await downloadCurtainData(linkId: linkId, hostname: hostname)

        let service = CurtainDataService()
        try await service.restoreSettings(from: jsonObject)

        // Wrap in AppData as used in DetailsView
        let appData = CurtainData(
            raw: service.curtainData.raw?.originalFile,
            rawForm: CurtainRawForm(
                primaryIDs: service.curtainData.rawForm?.primaryIDs ?? "",
                samples: service.curtainData.rawForm?.samples ?? [],
                log2: service.curtainData.rawForm?.log2 ?? false
            ),
            differentialForm: CurtainDifferentialForm(
                primaryIDs: service.curtainData.differentialForm?.primaryIDs ?? "",
                geneNames: service.curtainData.differentialForm?.geneNames ?? "",
                foldChange: service.curtainData.differentialForm?.foldChange ?? "",
                transformFC: service.curtainData.differentialForm?.transformFC ?? false,
                significant: service.curtainData.differentialForm?.significant ?? "",
                transformSignificant: service.curtainData.differentialForm?.transformSignificant ?? false,
                comparison: service.curtainData.differentialForm?.comparison ?? "",
                comparisonSelect: service.curtainData.differentialForm?.comparisonSelect ?? [],
                reverseFoldChange: service.curtainData.differentialForm?.reverseFoldChange ?? false
            ),
            settings: service.curtainSettings
        )

        let processedSettings = appData.getProcessedSettings()

        // Verify sampleMap was reconstructed correctly
        XCTAssertFalse(processedSettings.sampleMap.isEmpty, "sampleMap should not be empty after processing")
        XCTAssertEqual(processedSettings.sampleMap["4Hr-AGB1.01"]?["condition"], "4Hr-AGB1")
        XCTAssertEqual(processedSettings.sampleMap["4Hr-AGB1.01"]?["replicate"], "01")
    }

    func testTPDatasetVolcanoPlotDataGeneration() async throws {
        let linkId = CurtainConstants.ExampleData.uniqueId
        let hostname = CurtainConstants.ExampleData.apiUrl

        let (_, jsonObject) = try await downloadCurtainData(linkId: linkId, hostname: hostname)

        let service = CurtainDataService()
        try await service.restoreSettings(from: jsonObject)

        // Wrap in AppData as used by VolcanoPlotDataService
        let appData = AppData()
        appData.dataMap = service.curtainData.dataMap
        appData.differentialForm = service.curtainData.differentialForm
        appData.selectedMap = service.curtainData.selectedMap
        appData.uniprotDB = service.uniprotData.db

        let volcanoService = VolcanoPlotDataService()
        let result = await volcanoService.processVolcanoData(curtainData: appData, settings: service.curtainSettings)

        XCTAssertFalse(result.jsonData.isEmpty, "Volcano plot should have data")

        // Verify a specific protein - AAK1 (Q2M2I8)
        let aak1 = result.jsonData.first { $0["id"] as? String == "Q2M2I8" }
        XCTAssertNotNil(aak1, "AAK1 (Q2M2I8) should be in volcano plot data")
        XCTAssertEqual(aak1?["gene"] as? String, "AAK1", "Gene name should be AAK1")

        // Verify x and y coordinates are correctly extracted
        XCTAssertNotNil(aak1?["x"] as? Double, "Should have x coordinate")
        XCTAssertNotNil(aak1?["y"] as? Double, "Should have y coordinate")

        // Verify colors are assigned
        XCTAssertNotNil(aak1?["color"] as? String, "Should have color assigned")
    }

    func testTPDatasetUniProtDBEntries() async throws {
        let linkId = CurtainConstants.ExampleData.uniqueId
        let hostname = CurtainConstants.ExampleData.apiUrl

        let (_, jsonObject) = try await downloadCurtainData(linkId: linkId, hostname: hostname)

        guard let curtainData = CurtainData.fromJSON(jsonObject) else {
            XCTFail("Failed to parse CurtainData")
            return
        }

        // Verify UniProt DB entries are present and correctly parsed
        guard let uniprotDb = curtainData.extraData?.uniprot?.db else {
            // Debug: check raw structure
            if let extraDataDict = jsonObject["extraData"] as? [String: Any],
               let uniprotDict = extraDataDict["uniprot"] as? [String: Any] {
                print("DEBUG: uniprot dict keys: \(uniprotDict.keys.sorted())")
                if let dbRaw = uniprotDict["db"] {
                    print("DEBUG: db type: \(type(of: dbRaw))")
                    if let dbDict = dbRaw as? [String: Any] {
                        if let dataType = dbDict["dataType"] as? String {
                            print("DEBUG: db has Map serialization format with dataType: \(dataType)")
                            if let values = dbDict["value"] as? [[Any]] {
                                print("DEBUG: Map has \(values.count) entries")
                            }
                        } else {
                            print("DEBUG: db is plain dictionary with \(dbDict.count) entries")
                        }
                    }
                }
            }
            XCTFail("UniProt DB should exist")
            return
        }

        // Should have many UniProt entries (not just 2)
        print("UniProt DB entry count: \(uniprotDb.count)")
        XCTAssertGreaterThan(uniprotDb.count, 100, "Should have more than 100 UniProt entries, got \(uniprotDb.count)")

        // Verify specific entry Q2M2I8 (AAK1) exists and has correct structure
        guard let aak1Entry = uniprotDb["Q2M2I8"] as? [String: Any] else {
            print("DEBUG: Available keys (first 10): \(Array(uniprotDb.keys.prefix(10)))")
            XCTFail("Q2M2I8 (AAK1) should exist in UniProt DB")
            return
        }

        XCTAssertNotNil(aak1Entry["Gene Names"], "Should have Gene Names field")
        XCTAssertNotNil(aak1Entry["Sequence"], "Should have Sequence field")
    }

    // MARK: - PTM Dataset Tests

    func testPTMDatasetRestoreSettings() async throws {
        let linkId = CurtainConstants.ExamplePTMData.uniqueId
        let hostname = CurtainConstants.ExamplePTMData.apiUrl

        let (_, jsonObject) = try await downloadCurtainData(linkId: linkId, hostname: hostname)

        let service = CurtainDataService()
        try await service.restoreSettings(from: jsonObject)

        // Verify it's PTM data
        XCTAssertTrue(service.curtainData.differentialForm?.isPTM ?? false, "Should be PTM data")

        // Verify PTM-specific fields are set
        XCTAssertFalse(service.curtainData.differentialForm?.accession.isEmpty ?? true, "Accession should be set for PTM")
        XCTAssertFalse(service.curtainData.differentialForm?.position.isEmpty ?? true, "Position should be set for PTM")
    }

    func testPTMDatasetUniProtDBEntries() async throws {
        let linkId = CurtainConstants.ExamplePTMData.uniqueId
        let hostname = CurtainConstants.ExamplePTMData.apiUrl

        let (_, jsonObject) = try await downloadCurtainData(linkId: linkId, hostname: hostname)

        guard let curtainData = CurtainData.fromJSON(jsonObject) else {
            XCTFail("Failed to parse PTM CurtainData")
            return
        }

        // Verify UniProt DB entries are present
        guard let uniprotDb = curtainData.extraData?.uniprot?.db else {
            XCTFail("PTM data should have UniProt DB")
            return
        }

        print("PTM UniProt DB entry count: \(uniprotDb.count)")
        XCTAssertGreaterThan(uniprotDb.count, 10, "Should have UniProt entries for PTM data")
    }

    // MARK: - Database Storage Tests

    func testTPDataStorageAndRetrieval() async throws {
        let linkId = CurtainConstants.ExampleData.uniqueId
        let hostname = CurtainConstants.ExampleData.apiUrl

        let (_, jsonObject) = try await downloadCurtainData(linkId: linkId, hostname: hostname)

        guard let curtainData = CurtainData.fromJSON(jsonObject) else {
            XCTFail("Failed to parse CurtainData")
            return
        }

        // Store in database
        let testLinkId = "test-storage-\(UUID().uuidString)"
        let service = ProteomicsDataService.shared

        defer {
            service.clearDatabaseForLinkId(testLinkId)
        }

        try service.buildProteomicsDataIfNeeded(
            linkId: testLinkId,
            rawTsv: jsonObject["raw"] as? String,
            processedTsv: jsonObject["processed"] as? String,
            rawForm: curtainData.rawForm,
            differentialForm: curtainData.differentialForm,
            curtainData: curtainData,
            onProgress: { _ in }
        )

        // Verify storage counts
        let processedCount = try service.getProcessedDataCount(linkId: testLinkId)
        let rawCount = try service.getRawDataCount(linkId: testLinkId)
        let uniprotCount = try service.getUniProtEntryCount(linkId: testLinkId)

        print("Stored - Processed: \(processedCount), Raw: \(rawCount), UniProt: \(uniprotCount)")

        XCTAssertGreaterThan(processedCount, 0, "Should have processed data stored")
        XCTAssertGreaterThan(rawCount, 0, "Should have raw data stored")
        XCTAssertGreaterThan(uniprotCount, 100, "Should have more than 100 UniProt entries stored")
    }
}

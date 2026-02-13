//
//  DiagnosticTest.swift
//  CurtainTests
//
//  Simple diagnostic test to identify pipeline issues
//

import XCTest
@testable import Curtain

final class DiagnosticTest: XCTestCase {

    /// Downloads curtain data using the two-step process:
    /// 1. Get signed URL from API
    /// 2. Download actual data from S3
    private func downloadCurtainData(linkId: String, hostname: String) async throws -> Data {
        // Step 1: Get the signed S3 URL
        let apiURL = "\(hostname)curtain/\(linkId)/download/token=/"
        let (urlData, _) = try await URLSession.shared.data(from: URL(string: apiURL)!)

        let urlJson = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: urlData) as? [String: Any],
            "API should return JSON"
        )

        let signedUrl = try XCTUnwrap(
            urlJson["url"] as? String,
            "API should return 'url' field. Got: \(urlJson.keys)"
        )

        // Step 2: Download actual data from S3
        let (data, response) = try await URLSession.shared.data(from: URL(string: signedUrl)!)

        let httpResponse = try XCTUnwrap(response as? HTTPURLResponse, "S3 response should be HTTP")
        XCTAssertEqual(httpResponse.statusCode, 200, "S3 status should be 200, got \(httpResponse.statusCode)")

        return data
    }

    func testDownloadAndDiagnose() async throws {
        // Step 1: Download
        let data = try await downloadCurtainData(
            linkId: CurtainConstants.ExampleData.uniqueId,
            hostname: CurtainConstants.ExampleData.apiUrl
        )

        XCTAssertGreaterThan(data.count, 1000, "Data should be > 1000 bytes, got \(data.count)")

        // Step 2: Parse JSON
        let json = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: data) as? [String: Any],
            "Should parse JSON"
        )

        XCTAssertNotNil(json["settings"], "JSON should have 'settings'. Keys: \(json.keys.sorted())")
        XCTAssertNotNil(json["differentialForm"], "JSON should have 'differentialForm'")
        XCTAssertNotNil(json["processed"], "JSON should have 'processed'")
        XCTAssertNotNil(json["raw"], "JSON should have 'raw'")

        // Step 3: Parse CurtainData
        let curtainData = try XCTUnwrap(
            CurtainData.fromJSON(json),
            "Should parse CurtainData"
        )

        XCTAssertEqual(curtainData.curtainType, "TP", "curtainType should be 'TP', got '\(curtainData.curtainType)'")
        XCTAssertFalse(curtainData.differentialForm.isPTM, "Should NOT be PTM")

        // Step 4: Check extraData
        let extraData = try XCTUnwrap(curtainData.extraData, "Should have extraData")
        let uniprot = try XCTUnwrap(extraData.uniprot, "Should have uniprot data")

        XCTAssertGreaterThan(uniprot.results.count, 0, "UniProt results should not be empty")

        let uniprotDb = try XCTUnwrap(uniprot.db as? [String: Any], "UniProt.db should be dictionary")
        XCTAssertGreaterThan(uniprotDb.count, 0, "UniProt.db should have entries, got \(uniprotDb.count)")

        // Step 5: Build database
        let testLinkId = "diag-test-\(UUID().uuidString)"
        let service = ProteomicsDataService.shared

        defer {
            service.clearDatabaseForLinkId(testLinkId)
        }

        try service.buildProteomicsDataIfNeeded(
            linkId: testLinkId,
            rawTsv: json["raw"] as? String,
            processedTsv: json["processed"] as? String,
            rawForm: curtainData.rawForm,
            differentialForm: curtainData.differentialForm,
            curtainData: curtainData,
            onProgress: { _ in }
        )

        // Step 6: Query counts
        let processedCount = try service.getProcessedDataCount(linkId: testLinkId)
        let rawCount = try service.getRawDataCount(linkId: testLinkId)
        let uniprotCount = try service.getUniProtEntryCount(linkId: testLinkId)
        let genesCount = try service.getAllGenesCount(linkId: testLinkId)

        XCTAssertGreaterThan(processedCount, 0, "Should have processed data, got \(processedCount)")
        XCTAssertGreaterThan(rawCount, 0, "Should have raw data, got \(rawCount)")
        XCTAssertGreaterThan(uniprotCount, 0, "Should have UniProt entries, got \(uniprotCount)")
        XCTAssertGreaterThan(genesCount, 0, "Should have genes, got \(genesCount)")
    }

    func testPTMDownloadAndDiagnose() async throws {
        // Step 1: Download
        let data = try await downloadCurtainData(
            linkId: CurtainConstants.ExamplePTMData.uniqueId,
            hostname: CurtainConstants.ExamplePTMData.apiUrl
        )

        XCTAssertGreaterThan(data.count, 1000, "Data should be > 1000 bytes, got \(data.count)")

        // Step 2: Parse JSON
        let json = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: data) as? [String: Any],
            "Should parse JSON"
        )

        // Step 3: Parse CurtainData
        let curtainData = try XCTUnwrap(CurtainData.fromJSON(json), "Should parse CurtainData")

        XCTAssertEqual(curtainData.curtainType, "PTM", "curtainType should be 'PTM', got '\(curtainData.curtainType)'")
        XCTAssertTrue(curtainData.differentialForm.isPTM, "Should be PTM, accession='\(curtainData.differentialForm.accession)', position='\(curtainData.differentialForm.position)'")

        // Step 4: Build database
        let testLinkId = "diag-ptm-\(UUID().uuidString)"
        let service = ProteomicsDataService.shared

        defer {
            service.clearDatabaseForLinkId(testLinkId)
        }

        try service.buildProteomicsDataIfNeeded(
            linkId: testLinkId,
            rawTsv: json["raw"] as? String,
            processedTsv: json["processed"] as? String,
            rawForm: curtainData.rawForm,
            differentialForm: curtainData.differentialForm,
            curtainData: curtainData,
            onProgress: { _ in }
        )

        // Step 5: Query counts
        let processedCount = try service.getProcessedDataCount(linkId: testLinkId)
        let uniprotCount = try service.getUniProtEntryCount(linkId: testLinkId)
        let accessions = try service.getDistinctAccessions(linkId: testLinkId)

        XCTAssertGreaterThan(processedCount, 0, "Should have processed PTM data, got \(processedCount)")
        XCTAssertGreaterThan(uniprotCount, 0, "Should have UniProt entries, got \(uniprotCount)")
        XCTAssertGreaterThan(accessions.count, 0, "Should have accessions, got \(accessions.count)")
    }
}

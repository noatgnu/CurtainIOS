//
//  RealDataIntegrationTests.swift
//  CurtainTests
//
//  End-to-end tests that download REAL data from the server
//

import XCTest
@testable import Curtain

final class RealDataIntegrationTests: XCTestCase {

    // MARK: - Helper Methods

    /// Downloads data using the two-step process: API -> signed URL -> S3
    private func downloadCurtainData(linkId: String, hostname: String) async throws -> (Data, [String: Any]) {
        // Step 1: Get signed S3 URL from API
        let apiURL = "\(hostname)curtain/\(linkId)/download/token=/"

        let (urlData, urlResponse) = try await URLSession.shared.data(from: URL(string: apiURL)!)

        guard let httpResponse = urlResponse as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSError(domain: "RealDataIntegrationTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to get signed URL"])
        }

        guard let urlJson = try JSONSerialization.jsonObject(with: urlData) as? [String: Any],
              let signedUrl = urlJson["url"] as? String else {
            throw NSError(domain: "RealDataIntegrationTests", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to parse signed URL"])
        }

        // Step 2: Download actual data from S3
        let (data, dataResponse) = try await URLSession.shared.data(from: URL(string: signedUrl)!)

        guard let s3Response = dataResponse as? HTTPURLResponse, s3Response.statusCode == 200 else {
            throw NSError(domain: "RealDataIntegrationTests", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to download from S3"])
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "RealDataIntegrationTests", code: 4, userInfo: [NSLocalizedDescriptionKey: "Failed to parse JSON"])
        }

        return (data, json)
    }

    // MARK: - Test TP Example Full Download and Parse

    func testDownloadAndParseTPExample() async throws {
        let linkId = CurtainConstants.ExampleData.uniqueId
        let hostname = CurtainConstants.ExampleData.apiUrl

        let (data, json) = try await downloadCurtainData(linkId: linkId, hostname: hostname)

        XCTAssertGreaterThan(data.count, 0, "Downloaded data should not be empty")
        print("TP - Downloaded \(data.count) bytes")

        // Parse using CurtainData.fromJSON
        guard let curtainData = CurtainData.fromJSON(json) else {
            XCTFail("CurtainData.fromJSON should succeed")
            return
        }

        // Verify it's TP data (not PTM)
        XCTAssertFalse(curtainData.differentialForm.isPTM, "TP example should NOT be PTM")
        XCTAssertEqual(curtainData.curtainType, "TP")

        // Verify differentialForm has required fields
        XCTAssertFalse(curtainData.differentialForm.primaryIDs.isEmpty, "primaryIDs should not be empty")
        XCTAssertFalse(curtainData.differentialForm.foldChange.isEmpty, "foldChange should not be empty")
        XCTAssertFalse(curtainData.differentialForm.significant.isEmpty, "significant should not be empty")

        // Verify PTM fields are empty for TP data
        XCTAssertTrue(curtainData.differentialForm.accession.isEmpty, "accession should be empty for TP")
        XCTAssertTrue(curtainData.differentialForm.position.isEmpty, "position should be empty for TP")

        print("TP - primaryIDs: \(curtainData.differentialForm.primaryIDs)")
        print("TP - geneNames: \(curtainData.differentialForm.geneNames)")
        print("TP - foldChange: \(curtainData.differentialForm.foldChange)")
        print("TP - significant: \(curtainData.differentialForm.significant)")
    }

    func testTPExampleExtraData() async throws {
        let linkId = CurtainConstants.ExampleData.uniqueId
        let hostname = CurtainConstants.ExampleData.apiUrl

        let (_, json) = try await downloadCurtainData(linkId: linkId, hostname: hostname)

        guard let curtainData = CurtainData.fromJSON(json) else {
            XCTFail("Failed to parse CurtainData")
            return
        }

        // Verify extraData exists
        XCTAssertNotNil(curtainData.extraData, "extraData should exist")

        // Verify UniProt data
        if let uniprot = curtainData.extraData?.uniprot {
            print("TP UniProt results count: \(uniprot.results.count)")
            XCTAssertGreaterThan(uniprot.results.count, 0, "Should have UniProt results")

            if let db = uniprot.db {
                print("TP UniProt DB entries: \(db.count)")
                XCTAssertGreaterThan(db.count, 0, "Should have UniProt DB entries")
            }
        } else {
            XCTFail("UniProt data should exist")
        }

        // Verify allGenes
        if let allGenes = curtainData.extraData?.data?.allGenes {
            print("TP allGenes count: \(allGenes.count)")
            XCTAssertGreaterThan(allGenes.count, 0, "Should have genes")
        }
    }

    func testTPExampleSettings() async throws {
        let linkId = CurtainConstants.ExampleData.uniqueId
        let hostname = CurtainConstants.ExampleData.apiUrl

        let (_, json) = try await downloadCurtainData(linkId: linkId, hostname: hostname)

        guard let curtainData = CurtainData.fromJSON(json) else {
            XCTFail("Failed to parse CurtainData")
            return
        }

        // Verify settings
        XCTAssertGreaterThan(curtainData.settings.pCutoff, 0)
        XCTAssertGreaterThan(curtainData.settings.log2FCCutoff, 0)

        print("TP Settings - pCutoff: \(curtainData.settings.pCutoff)")
        print("TP Settings - log2FCCutoff: \(curtainData.settings.log2FCCutoff)")
        print("TP Settings - uniprot: \(curtainData.settings.uniprot)")
    }

    func testTPExampleRawForm() async throws {
        let linkId = CurtainConstants.ExampleData.uniqueId
        let hostname = CurtainConstants.ExampleData.apiUrl

        let (_, json) = try await downloadCurtainData(linkId: linkId, hostname: hostname)

        guard let curtainData = CurtainData.fromJSON(json) else {
            XCTFail("Failed to parse CurtainData")
            return
        }

        // Verify raw form
        XCTAssertFalse(curtainData.rawForm.primaryIDs.isEmpty, "rawForm primaryIDs should not be empty")
        XCTAssertGreaterThan(curtainData.rawForm.samples.count, 0, "Should have samples")

        print("TP RawForm - primaryIDs: \(curtainData.rawForm.primaryIDs)")
        print("TP RawForm - samples count: \(curtainData.rawForm.samples.count)")
        print("TP RawForm - log2: \(curtainData.rawForm.log2)")
    }

    // MARK: - Test PTM Example Full Download and Parse

    func testDownloadAndParsePTMExample() async throws {
        let linkId = CurtainConstants.ExamplePTMData.uniqueId
        let hostname = CurtainConstants.ExamplePTMData.apiUrl

        let (data, json) = try await downloadCurtainData(linkId: linkId, hostname: hostname)

        XCTAssertGreaterThan(data.count, 0, "Downloaded data should not be empty")
        print("PTM - Downloaded \(data.count) bytes")

        // Parse using CurtainData.fromJSON
        guard let curtainData = CurtainData.fromJSON(json) else {
            XCTFail("CurtainData.fromJSON should succeed")
            return
        }

        // Verify it's PTM data
        XCTAssertTrue(curtainData.differentialForm.isPTM, "PTM example should be PTM")
        XCTAssertEqual(curtainData.curtainType, "PTM")

        // Verify PTM fields are present
        XCTAssertFalse(curtainData.differentialForm.accession.isEmpty, "accession should not be empty for PTM")
        XCTAssertFalse(curtainData.differentialForm.position.isEmpty, "position should not be empty for PTM")

        print("PTM - primaryIDs: \(curtainData.differentialForm.primaryIDs)")
        print("PTM - accession: \(curtainData.differentialForm.accession)")
        print("PTM - position: \(curtainData.differentialForm.position)")
        print("PTM - positionPeptide: \(curtainData.differentialForm.positionPeptide)")
        print("PTM - peptideSequence: \(curtainData.differentialForm.peptideSequence)")
        print("PTM - score: \(curtainData.differentialForm.score)")
    }

    func testPTMExampleExtraData() async throws {
        let linkId = CurtainConstants.ExamplePTMData.uniqueId
        let hostname = CurtainConstants.ExamplePTMData.apiUrl

        let (_, json) = try await downloadCurtainData(linkId: linkId, hostname: hostname)

        guard let curtainData = CurtainData.fromJSON(json) else {
            XCTFail("Failed to parse CurtainData")
            return
        }

        // Verify extraData exists
        XCTAssertNotNil(curtainData.extraData, "extraData should exist")

        // Verify UniProt data
        if let uniprot = curtainData.extraData?.uniprot {
            print("PTM UniProt results count: \(uniprot.results.count)")
            XCTAssertGreaterThan(uniprot.results.count, 0, "Should have UniProt results")

            if let db = uniprot.db {
                print("PTM UniProt DB entries: \(db.count)")
                XCTAssertGreaterThan(db.count, 0, "Should have UniProt DB entries")
            }
        } else {
            XCTFail("UniProt data should exist for PTM")
        }
    }

    func testPTMExampleSettings() async throws {
        let linkId = CurtainConstants.ExamplePTMData.uniqueId
        let hostname = CurtainConstants.ExamplePTMData.apiUrl

        let (_, json) = try await downloadCurtainData(linkId: linkId, hostname: hostname)

        guard let curtainData = CurtainData.fromJSON(json) else {
            XCTFail("Failed to parse CurtainData")
            return
        }

        // Verify settings
        XCTAssertGreaterThan(curtainData.settings.pCutoff, 0)
        XCTAssertGreaterThan(curtainData.settings.log2FCCutoff, 0)

        print("PTM Settings - pCutoff: \(curtainData.settings.pCutoff)")
        print("PTM Settings - log2FCCutoff: \(curtainData.settings.log2FCCutoff)")
    }

    // MARK: - Test Data Contains Raw and Processed TSV

    func testTPExampleHasRawAndProcessedData() async throws {
        let linkId = CurtainConstants.ExampleData.uniqueId
        let hostname = CurtainConstants.ExampleData.apiUrl

        let (_, json) = try await downloadCurtainData(linkId: linkId, hostname: hostname)

        // Verify processed data exists
        if let processed = json["processed"] as? String {
            XCTAssertGreaterThan(processed.count, 100, "Should have substantial processed data")
            print("TP - processed data length: \(processed.count) chars")

            // Verify it looks like TSV (has tabs and newlines)
            XCTAssertTrue(processed.contains("\t"), "Processed data should be TSV format")
            XCTAssertTrue(processed.contains("\n"), "Processed data should have multiple rows")
        } else {
            XCTFail("Should have processed data")
        }

        // Verify raw data exists
        if let raw = json["raw"] as? String {
            XCTAssertGreaterThan(raw.count, 100, "Should have substantial raw data")
            print("TP - raw data length: \(raw.count) chars")
        } else {
            XCTFail("Should have raw data")
        }
    }

    func testPTMExampleHasRawAndProcessedData() async throws {
        let linkId = CurtainConstants.ExamplePTMData.uniqueId
        let hostname = CurtainConstants.ExamplePTMData.apiUrl

        let (_, json) = try await downloadCurtainData(linkId: linkId, hostname: hostname)

        // Verify processed data exists
        if let processed = json["processed"] as? String {
            XCTAssertGreaterThan(processed.count, 100, "Should have substantial processed data")
            print("PTM - processed data length: \(processed.count) chars")
        } else {
            XCTFail("Should have processed data")
        }
    }

    // MARK: - Test Complete Pipeline

    func testTPExampleCompletePipeline() async throws {
        let linkId = CurtainConstants.ExampleData.uniqueId
        let hostname = CurtainConstants.ExampleData.apiUrl

        // Step 1: Download
        let (data, json) = try await downloadCurtainData(linkId: linkId, hostname: hostname)
        print("Step 1: Downloaded \(data.count) bytes")

        // Step 2: Parse CurtainData
        guard let curtainData = CurtainData.fromJSON(json) else {
            XCTFail("Step 2 failed: CurtainData parsing")
            return
        }
        print("Step 2: Created CurtainData")

        // Step 3: Verify data type
        XCTAssertEqual(curtainData.curtainType, "TP")
        print("Step 3: Verified curtainType = TP")

        // Step 4: Verify settings
        XCTAssertGreaterThan(curtainData.settings.pCutoff, 0)
        print("Step 4: Verified settings (pCutoff = \(curtainData.settings.pCutoff))")

        // Step 5: Verify UniProt data
        let uniprotCount = curtainData.extraData?.uniprot?.results.count ?? 0
        XCTAssertGreaterThan(uniprotCount, 0)
        print("Step 5: Verified UniProt data (\(uniprotCount) results)")

        // Step 6: Verify genes
        let genesCount = curtainData.extraData?.data?.allGenes?.count ?? 0
        XCTAssertGreaterThan(genesCount, 0)
        print("Step 6: Verified genes (\(genesCount) genes)")

        print("TP Example - All pipeline steps passed!")
    }

    func testPTMExampleCompletePipeline() async throws {
        let linkId = CurtainConstants.ExamplePTMData.uniqueId
        let hostname = CurtainConstants.ExamplePTMData.apiUrl

        // Step 1: Download
        let (data, json) = try await downloadCurtainData(linkId: linkId, hostname: hostname)
        print("Step 1: Downloaded \(data.count) bytes")

        // Step 2: Parse CurtainData
        guard let curtainData = CurtainData.fromJSON(json) else {
            XCTFail("Step 2 failed: CurtainData parsing")
            return
        }
        print("Step 2: Created CurtainData")

        // Step 3: Verify data type is PTM
        XCTAssertTrue(curtainData.differentialForm.isPTM)
        XCTAssertEqual(curtainData.curtainType, "PTM")
        print("Step 3: Verified curtainType = PTM")

        // Step 4: Verify PTM-specific fields
        XCTAssertFalse(curtainData.differentialForm.accession.isEmpty)
        XCTAssertFalse(curtainData.differentialForm.position.isEmpty)
        print("Step 4: Verified PTM fields (accession = \(curtainData.differentialForm.accession), position = \(curtainData.differentialForm.position))")

        // Step 5: Verify settings
        XCTAssertGreaterThan(curtainData.settings.pCutoff, 0)
        print("Step 5: Verified settings (pCutoff = \(curtainData.settings.pCutoff))")

        // Step 6: Verify UniProt data
        let uniprotCount = curtainData.extraData?.uniprot?.results.count ?? 0
        XCTAssertGreaterThan(uniprotCount, 0)
        print("Step 6: Verified UniProt data (\(uniprotCount) results)")

        print("PTM Example - All pipeline steps passed!")
    }
}

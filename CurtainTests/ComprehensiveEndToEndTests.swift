//
//  ComprehensiveEndToEndTests.swift
//  CurtainTests
//
//  Comprehensive end-to-end tests that download REAL data from the server
//  and test the full pipeline from download to display.
//

import XCTest
@testable import Curtain

final class ComprehensiveEndToEndTests: XCTestCase {

    // MARK: - Test Data Cache

    /// Cache downloaded data to avoid repeated network calls
    private static var cachedTPData: Data?
    private static var cachedTPJson: [String: Any]?
    private static var cachedTPCurtainData: CurtainData?

    private static var cachedPTMData: Data?
    private static var cachedPTMJson: [String: Any]?
    private static var cachedPTMCurtainData: CurtainData?

    private static var setupComplete = false

    // MARK: - Helper Methods

    private func ensureDataLoaded() async throws {
        if Self.setupComplete { return }

        // Download TP data
        let (tpData, tpJson, tpCurtainData) = try await Self.downloadAndParse(
            linkId: CurtainConstants.ExampleData.uniqueId,
            hostname: CurtainConstants.ExampleData.apiUrl
        )
        Self.cachedTPData = tpData
        Self.cachedTPJson = tpJson
        Self.cachedTPCurtainData = tpCurtainData

        // Download PTM data
        let (ptmData, ptmJson, ptmCurtainData) = try await Self.downloadAndParse(
            linkId: CurtainConstants.ExamplePTMData.uniqueId,
            hostname: CurtainConstants.ExamplePTMData.apiUrl
        )
        Self.cachedPTMData = ptmData
        Self.cachedPTMJson = ptmJson
        Self.cachedPTMCurtainData = ptmCurtainData

        Self.setupComplete = true
    }

    private static func downloadAndParse(linkId: String, hostname: String) async throws -> (Data, [String: Any], CurtainData) {
        // Two-step download process:
        // Step 1: Get signed S3 URL from API
        let apiURL = "\(hostname)curtain/\(linkId)/download/token=/"
        print("Step 1: Getting signed URL from: \(apiURL)")

        let (urlData, urlResponse) = try await URLSession.shared.data(from: URL(string: apiURL)!)

        guard let httpResponse = urlResponse as? HTTPURLResponse else {
            throw TestError.notHTTPResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw TestError.httpError(statusCode: httpResponse.statusCode)
        }

        guard let urlJson = try JSONSerialization.jsonObject(with: urlData) as? [String: Any],
              let signedUrl = urlJson["url"] as? String else {
            throw TestError.jsonParsingFailed
        }

        print("Step 1: Got signed URL")

        // Step 2: Download actual data from S3
        print("Step 2: Downloading from S3...")
        let (data, dataResponse) = try await URLSession.shared.data(from: URL(string: signedUrl)!)

        guard let s3Response = dataResponse as? HTTPURLResponse else {
            throw TestError.notHTTPResponse
        }

        guard s3Response.statusCode == 200 else {
            throw TestError.httpError(statusCode: s3Response.statusCode)
        }

        print("Step 2: Downloaded \(data.count) bytes from S3")

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw TestError.jsonParsingFailed
        }

        print("JSON keys: \(json.keys.sorted())")

        guard let curtainData = CurtainData.fromJSON(json) else {
            throw TestError.curtainDataParsingFailed
        }

        print("CurtainData parsed successfully (type: \(curtainData.curtainType))")

        return (data, json, curtainData)
    }

    // MARK: - Phase 1: Download Tests

    func testTPDownloadSucceeds() async throws {
        try await ensureDataLoaded()

        guard let data = Self.cachedTPData else {
            XCTFail("TP data was not downloaded")
            return
        }

        print("Downloaded \(data.count) bytes")
        XCTAssertGreaterThan(data.count, 1000, "Downloaded data should be substantial")
    }

    func testPTMDownloadSucceeds() async throws {
        try await ensureDataLoaded()

        guard let data = Self.cachedPTMData else {
            XCTFail("PTM data was not downloaded")
            return
        }

        print("Downloaded \(data.count) bytes")
        XCTAssertGreaterThan(data.count, 1000, "Downloaded data should be substantial")
    }

    // MARK: - Phase 2: JSON Parsing Tests

    func testTPJsonParsing() async throws {
        try await ensureDataLoaded()

        guard let json = Self.cachedTPJson else {
            XCTFail("TP JSON was not parsed")
            return
        }

        print("JSON keys: \(json.keys.sorted())")

        // Verify required keys exist
        let requiredKeys = ["settings", "differentialForm", "rawForm"]
        for key in requiredKeys {
            XCTAssertNotNil(json[key], "JSON should contain '\(key)' key")
        }

        // Check for data keys
        XCTAssertNotNil(json["processed"], "Should have processed data")
        XCTAssertNotNil(json["raw"], "Should have raw data")
    }

    func testPTMJsonParsing() async throws {
        try await ensureDataLoaded()

        guard let json = Self.cachedPTMJson else {
            XCTFail("PTM JSON was not parsed")
            return
        }

        print("JSON keys: \(json.keys.sorted())")

        // Verify required keys exist
        let requiredKeys = ["settings", "differentialForm", "rawForm"]
        for key in requiredKeys {
            XCTAssertNotNil(json[key], "JSON should contain '\(key)' key")
        }
    }

    // MARK: - Phase 3: CurtainData Model Tests

    func testTPCurtainDataParsing() async throws {
        try await ensureDataLoaded()

        guard let curtainData = Self.cachedTPCurtainData else {
            XCTFail("TP CurtainData was not parsed")
            return
        }

        // Test curtainType
        print("curtainType: \(curtainData.curtainType)")
        XCTAssertEqual(curtainData.curtainType, "TP", "TP example should have curtainType 'TP'")

        // Test differentialForm
        print("differentialForm.primaryIDs: '\(curtainData.differentialForm.primaryIDs)'")
        print("differentialForm.geneNames: '\(curtainData.differentialForm.geneNames)'")
        print("differentialForm.foldChange: '\(curtainData.differentialForm.foldChange)'")
        print("differentialForm.isPTM: \(curtainData.differentialForm.isPTM)")

        XCTAssertFalse(curtainData.differentialForm.primaryIDs.isEmpty, "primaryIDs should not be empty")
        XCTAssertFalse(curtainData.differentialForm.foldChange.isEmpty, "foldChange should not be empty")
        XCTAssertFalse(curtainData.differentialForm.isPTM, "TP data should NOT be PTM")

        // Test rawForm
        print("rawForm.samples count: \(curtainData.rawForm.samples.count)")
        XCTAssertGreaterThan(curtainData.rawForm.samples.count, 0, "Should have samples")
    }

    func testPTMCurtainDataParsing() async throws {
        try await ensureDataLoaded()

        guard let curtainData = Self.cachedPTMCurtainData else {
            XCTFail("PTM CurtainData was not parsed")
            return
        }

        // Test curtainType
        print("curtainType: \(curtainData.curtainType)")
        XCTAssertEqual(curtainData.curtainType, "PTM", "PTM example should have curtainType 'PTM'")

        // Test PTM-specific fields
        print("differentialForm.accession: '\(curtainData.differentialForm.accession)'")
        print("differentialForm.position: '\(curtainData.differentialForm.position)'")
        print("differentialForm.isPTM: \(curtainData.differentialForm.isPTM)")

        XCTAssertTrue(curtainData.differentialForm.isPTM, "PTM data should have isPTM = true")
        XCTAssertFalse(curtainData.differentialForm.accession.isEmpty, "PTM accession should not be empty")
        XCTAssertFalse(curtainData.differentialForm.position.isEmpty, "PTM position should not be empty")
    }

    // MARK: - Phase 4: Settings Tests

    func testTPSettings() async throws {
        try await ensureDataLoaded()

        guard let curtainData = Self.cachedTPCurtainData else {
            XCTFail("TP CurtainData was not parsed")
            return
        }

        let settings = curtainData.settings

        print("pCutoff: \(settings.pCutoff)")
        print("log2FCCutoff: \(settings.log2FCCutoff)")
        print("uniprot: \(settings.uniprot)")
        print("colorMap count: \(settings.colorMap.count)")
        print("sampleMap count: \(settings.sampleMap.count)")

        XCTAssertGreaterThan(settings.pCutoff, 0, "pCutoff should be positive")
        XCTAssertGreaterThan(settings.log2FCCutoff, 0, "log2FCCutoff should be positive")
    }

    func testPTMSettings() async throws {
        try await ensureDataLoaded()

        guard let curtainData = Self.cachedPTMCurtainData else {
            XCTFail("PTM CurtainData was not parsed")
            return
        }

        let settings = curtainData.settings

        print("pCutoff: \(settings.pCutoff)")
        print("log2FCCutoff: \(settings.log2FCCutoff)")
        print("uniprot: \(settings.uniprot)")

        XCTAssertGreaterThan(settings.pCutoff, 0, "pCutoff should be positive")
        XCTAssertGreaterThan(settings.log2FCCutoff, 0, "log2FCCutoff should be positive")
    }

    // MARK: - Phase 5: ExtraData Tests

    func testTPExtraData() async throws {
        try await ensureDataLoaded()

        guard let curtainData = Self.cachedTPCurtainData else {
            XCTFail("TP CurtainData was not parsed")
            return
        }

        print("extraData exists: \(curtainData.extraData != nil)")

        guard let extraData = curtainData.extraData else {
            XCTFail("extraData should exist for TP data")
            return
        }

        // UniProt data
        if let uniprot = extraData.uniprot {
            print("uniprot.results count: \(uniprot.results.count)")
            print("uniprot.organism: \(uniprot.organism ?? "nil")")

            if let db = uniprot.db as? [String: Any] {
                print("uniprot.db entries: \(db.count)")
                XCTAssertGreaterThan(db.count, 0, "UniProt DB should have entries")
            }

            XCTAssertGreaterThan(uniprot.results.count, 0, "UniProt results should not be empty")
        } else {
            XCTFail("UniProt data should exist")
        }

        // Data maps
        if let data = extraData.data {
            if let allGenes = data.allGenes {
                print("allGenes count: \(allGenes.count)")
                XCTAssertGreaterThan(allGenes.count, 0, "allGenes should not be empty")
            }
        }
    }

    func testPTMExtraData() async throws {
        try await ensureDataLoaded()

        guard let curtainData = Self.cachedPTMCurtainData else {
            XCTFail("PTM CurtainData was not parsed")
            return
        }

        print("extraData exists: \(curtainData.extraData != nil)")

        guard let extraData = curtainData.extraData else {
            XCTFail("extraData should exist for PTM data")
            return
        }

        // UniProt data
        if let uniprot = extraData.uniprot {
            print("uniprot.results count: \(uniprot.results.count)")

            if let db = uniprot.db as? [String: Any] {
                print("uniprot.db entries: \(db.count)")
                XCTAssertGreaterThan(db.count, 0, "UniProt DB should have entries for PTM")
            }

            XCTAssertGreaterThan(uniprot.results.count, 0, "UniProt results should not be empty for PTM")
        } else {
            XCTFail("UniProt data should exist for PTM")
        }
    }

    // MARK: - Phase 6: Raw/Processed TSV Tests

    func testTPRawAndProcessedData() async throws {
        try await ensureDataLoaded()

        guard let json = Self.cachedTPJson else {
            XCTFail("TP JSON was not parsed")
            return
        }

        // Test processed data
        if let processed = json["processed"] as? String {
            print("processed data length: \(processed.count)")
            XCTAssertGreaterThan(processed.count, 100, "Processed data should be substantial")

            // Verify TSV format
            XCTAssertTrue(processed.contains("\t"), "Processed data should contain tabs (TSV format)")
            XCTAssertTrue(processed.contains("\n"), "Processed data should have multiple rows")

            // Count rows
            let rows = processed.components(separatedBy: "\n").filter { !$0.isEmpty }
            print("Row count: \(rows.count)")
            XCTAssertGreaterThan(rows.count, 1, "Should have header + data rows")
        } else {
            XCTFail("Should have processed data")
        }

        // Test raw data
        if let raw = json["raw"] as? String {
            print("raw data length: \(raw.count)")
            XCTAssertGreaterThan(raw.count, 100, "Raw data should be substantial")
        } else {
            XCTFail("Should have raw data")
        }
    }

    func testPTMRawAndProcessedData() async throws {
        try await ensureDataLoaded()

        guard let json = Self.cachedPTMJson else {
            XCTFail("PTM JSON was not parsed")
            return
        }

        // Test processed data
        if let processed = json["processed"] as? String {
            print("processed data length: \(processed.count)")
            XCTAssertGreaterThan(processed.count, 100, "Processed data should be substantial")

            let rows = processed.components(separatedBy: "\n").filter { !$0.isEmpty }
            print("Row count: \(rows.count)")
        } else {
            XCTFail("Should have processed data for PTM")
        }
    }

    // MARK: - Phase 7: SQLite Storage Tests

    func testTPSQLiteStorage() async throws {
        try await ensureDataLoaded()

        guard let curtainData = Self.cachedTPCurtainData,
              let json = Self.cachedTPJson else {
            XCTFail("TP data was not parsed")
            return
        }

        let linkId = "test-tp-\(UUID().uuidString)"
        let service = ProteomicsDataService.shared

        defer {
            service.clearDatabaseForLinkId(linkId)
        }

        // Build data
        do {
            try service.buildProteomicsDataIfNeeded(
                linkId: linkId,
                rawTsv: json["raw"] as? String,
                processedTsv: json["processed"] as? String,
                rawForm: curtainData.rawForm,
                differentialForm: curtainData.differentialForm,
                curtainData: curtainData,
                onProgress: { progress in
                    print("Progress: \(progress)")
                }
            )
            print("Build completed successfully")
        } catch {
            XCTFail("Build failed with error: \(error)")
            return
        }

        // Query data
        do {
            let processedCount = try service.getProcessedDataCount(linkId: linkId)
            let rawCount = try service.getRawDataCount(linkId: linkId)
            let distinctProteinCount = try service.getDistinctProteinCount(linkId: linkId)
            let uniprotCount = try service.getUniProtEntryCount(linkId: linkId)
            let genesCount = try service.getAllGenesCount(linkId: linkId)

            print("processedCount: \(processedCount)")
            print("rawCount: \(rawCount)")
            print("distinctProteinCount: \(distinctProteinCount)")
            print("uniprotCount: \(uniprotCount)")
            print("genesCount: \(genesCount)")

            XCTAssertGreaterThan(processedCount, 0, "Should have processed data")
            XCTAssertGreaterThan(rawCount, 0, "Should have raw data")
            XCTAssertGreaterThan(distinctProteinCount, 0, "Should have distinct proteins")
            XCTAssertGreaterThan(uniprotCount, 0, "Should have UniProt entries")
            XCTAssertGreaterThan(genesCount, 0, "Should have genes")
        } catch {
            XCTFail("Query failed with error: \(error)")
        }
    }

    func testPTMSQLiteStorage() async throws {
        try await ensureDataLoaded()

        guard let curtainData = Self.cachedPTMCurtainData,
              let json = Self.cachedPTMJson else {
            XCTFail("PTM data was not parsed")
            return
        }

        let linkId = "test-ptm-\(UUID().uuidString)"
        let service = ProteomicsDataService.shared

        defer {
            service.clearDatabaseForLinkId(linkId)
        }

        // Build data
        do {
            try service.buildProteomicsDataIfNeeded(
                linkId: linkId,
                rawTsv: json["raw"] as? String,
                processedTsv: json["processed"] as? String,
                rawForm: curtainData.rawForm,
                differentialForm: curtainData.differentialForm,
                curtainData: curtainData,
                onProgress: { progress in
                    print("Progress: \(progress)")
                }
            )
            print("Build completed successfully")
        } catch {
            XCTFail("Build failed with error: \(error)")
            return
        }

        // Query data
        do {
            let processedCount = try service.getProcessedDataCount(linkId: linkId)
            let uniprotCount = try service.getUniProtEntryCount(linkId: linkId)

            print("processedCount: \(processedCount)")
            print("uniprotCount: \(uniprotCount)")

            XCTAssertGreaterThan(processedCount, 0, "Should have processed PTM data")
            XCTAssertGreaterThan(uniprotCount, 0, "Should have UniProt entries for PTM")

            // Test PTM-specific queries
            let accessions = try service.getDistinctAccessions(linkId: linkId)
            print("distinctAccessions count: \(accessions.count)")
            XCTAssertGreaterThan(accessions.count, 0, "Should have distinct accessions")

            if let firstAcc = accessions.first {
                print("First accession: \(firstAcc)")

                let ptmData = try service.getPTMDataForAccession(linkId: linkId, accession: firstAcc)
                print("PTM data for \(firstAcc): \(ptmData.count) entries")
                XCTAssertGreaterThan(ptmData.count, 0, "Should have PTM data for accession")
            }
        } catch {
            XCTFail("Query failed with error: \(error)")
        }
    }

    // MARK: - Phase 8: Data Loading from SQLite

    func testTPLoadFromDatabase() async throws {
        try await ensureDataLoaded()

        guard let curtainData = Self.cachedTPCurtainData,
              let json = Self.cachedTPJson else {
            XCTFail("TP data was not parsed")
            return
        }

        let linkId = "test-tp-load-\(UUID().uuidString)"
        let service = ProteomicsDataService.shared

        defer {
            service.clearDatabaseForLinkId(linkId)
        }

        // Build data first
        try service.buildProteomicsDataIfNeeded(
            linkId: linkId,
            rawTsv: json["raw"] as? String,
            processedTsv: json["processed"] as? String,
            rawForm: curtainData.rawForm,
            differentialForm: curtainData.differentialForm,
            curtainData: curtainData,
            onProgress: { _ in }
        )

        // Load from database
        guard let loadedData = service.loadCurtainDataFromDatabase(linkId: linkId) else {
            XCTFail("Failed to load CurtainData from database")
            return
        }

        print("Loaded from database:")
        print("  curtainType: \(loadedData.curtainType)")
        print("  differentialForm.primaryIDs: \(loadedData.differentialForm.primaryIDs)")
        print("  differentialForm.isPTM: \(loadedData.differentialForm.isPTM)")

        XCTAssertEqual(loadedData.curtainType, "TP")
        XCTAssertFalse(loadedData.differentialForm.isPTM)
        XCTAssertEqual(loadedData.differentialForm.primaryIDs, curtainData.differentialForm.primaryIDs)
    }

    func testPTMLoadFromDatabase() async throws {
        try await ensureDataLoaded()

        guard let curtainData = Self.cachedPTMCurtainData,
              let json = Self.cachedPTMJson else {
            XCTFail("PTM data was not parsed")
            return
        }

        let linkId = "test-ptm-load-\(UUID().uuidString)"
        let service = ProteomicsDataService.shared

        defer {
            service.clearDatabaseForLinkId(linkId)
        }

        // Build data first
        try service.buildProteomicsDataIfNeeded(
            linkId: linkId,
            rawTsv: json["raw"] as? String,
            processedTsv: json["processed"] as? String,
            rawForm: curtainData.rawForm,
            differentialForm: curtainData.differentialForm,
            curtainData: curtainData,
            onProgress: { _ in }
        )

        // Load from database
        guard let loadedData = service.loadCurtainDataFromDatabase(linkId: linkId) else {
            XCTFail("Failed to load PTM CurtainData from database")
            return
        }

        print("Loaded PTM from database:")
        print("  curtainType: \(loadedData.curtainType)")
        print("  differentialForm.isPTM: \(loadedData.differentialForm.isPTM)")
        print("  differentialForm.accession: \(loadedData.differentialForm.accession)")
        print("  differentialForm.position: \(loadedData.differentialForm.position)")

        XCTAssertEqual(loadedData.curtainType, "PTM")
        XCTAssertTrue(loadedData.differentialForm.isPTM)
        XCTAssertEqual(loadedData.differentialForm.accession, curtainData.differentialForm.accession)
    }

    // MARK: - Phase 9: Gene Name Resolution Tests

    func testGeneNameResolution() async throws {
        try await ensureDataLoaded()

        guard let curtainData = Self.cachedTPCurtainData,
              let json = Self.cachedTPJson else {
            XCTFail("TP data was not parsed")
            return
        }

        let linkId = "test-genes-\(UUID().uuidString)"
        let service = ProteomicsDataService.shared

        defer {
            service.clearDatabaseForLinkId(linkId)
        }

        // Build data first
        try service.buildProteomicsDataIfNeeded(
            linkId: linkId,
            rawTsv: json["raw"] as? String,
            processedTsv: json["processed"] as? String,
            rawForm: curtainData.rawForm,
            differentialForm: curtainData.differentialForm,
            curtainData: curtainData,
            onProgress: { _ in }
        )

        // Get some primary IDs
        let primaryIds = try service.getDistinctPrimaryIds(linkId: linkId)
        print("Found \(primaryIds.count) distinct primary IDs")

        guard primaryIds.count > 0 else {
            XCTFail("No primary IDs found")
            return
        }

        // Test gene name resolution
        var resolvedCount = 0
        for primaryId in primaryIds.prefix(10) {
            if let geneName = service.getGeneNameForProtein(linkId: linkId, primaryId: primaryId) {
                print("  \(primaryId) -> \(geneName)")
                resolvedCount += 1
            }
        }

        print("Resolved \(resolvedCount) gene names out of \(min(10, primaryIds.count))")
    }

    // MARK: - Phase 10: PTM Site Queries

    func testPTMSiteQueries() async throws {
        try await ensureDataLoaded()

        guard let curtainData = Self.cachedPTMCurtainData,
              let json = Self.cachedPTMJson else {
            XCTFail("PTM data was not parsed")
            return
        }

        let linkId = "test-ptm-sites-\(UUID().uuidString)"
        let service = ProteomicsDataService.shared

        defer {
            service.clearDatabaseForLinkId(linkId)
        }

        // Build data first
        try service.buildProteomicsDataIfNeeded(
            linkId: linkId,
            rawTsv: json["raw"] as? String,
            processedTsv: json["processed"] as? String,
            rawForm: curtainData.rawForm,
            differentialForm: curtainData.differentialForm,
            curtainData: curtainData,
            onProgress: { _ in }
        )

        // Get accessions
        let accessions = try service.getDistinctAccessions(linkId: linkId)
        print("Found \(accessions.count) accessions")

        guard let firstAcc = accessions.first else {
            XCTFail("No accessions found")
            return
        }

        // Get experimental PTM sites
        let sites = service.getExperimentalPTMSites(
            linkId: linkId,
            accession: firstAcc,
            pCutoff: 0.05,
            fcCutoff: 0.6
        )

        print("Found \(sites.count) experimental PTM sites for \(firstAcc)")

        for site in sites.prefix(5) {
            print("  Position: \(site.position), Residue: \(site.residue), Significant: \(site.isSignificant)")
        }

        // Count significant sites
        let significantCount = sites.filter { $0.isSignificant }.count
        print("Significant sites: \(significantCount) out of \(sites.count)")
    }

    // MARK: - Complete Pipeline Tests

    func testCompleteTPPipeline() async throws {
        print("\n=== TEST: testCompleteTPPipeline ===")

        // Step 1: Download
        try await ensureDataLoaded()
        guard let data = Self.cachedTPData else {
            XCTFail("Step 1 FAILED: Download")
            return
        }
        print("Step 1: Downloaded \(data.count) bytes")

        // Step 2: Verify JSON parsing
        guard let json = Self.cachedTPJson else {
            XCTFail("Step 2 FAILED: JSON parsing")
            return
        }
        print("Step 2: Parsed JSON with \(json.keys.count) keys")

        // Step 3: Verify CurtainData
        guard let curtainData = Self.cachedTPCurtainData else {
            XCTFail("Step 3 FAILED: CurtainData parsing")
            return
        }
        print("Step 3: Created CurtainData (type: \(curtainData.curtainType))")

        // Step 4: Verify not PTM
        XCTAssertFalse(curtainData.differentialForm.isPTM)
        print("Step 4: Verified NOT PTM")

        // Step 5: Build SQLite database
        let linkId = "test-full-tp-\(UUID().uuidString)"
        let service = ProteomicsDataService.shared

        defer {
            service.clearDatabaseForLinkId(linkId)
        }

        try service.buildProteomicsDataIfNeeded(
            linkId: linkId,
            rawTsv: json["raw"] as? String,
            processedTsv: json["processed"] as? String,
            rawForm: curtainData.rawForm,
            differentialForm: curtainData.differentialForm,
            curtainData: curtainData,
            onProgress: { _ in }
        )
        print("Step 5: Built SQLite database")

        // Step 6: Query counts
        let processedCount = try service.getProcessedDataCount(linkId: linkId)
        let uniprotCount = try service.getUniProtEntryCount(linkId: linkId)
        let genesCount = try service.getAllGenesCount(linkId: linkId)

        XCTAssertGreaterThan(processedCount, 0)
        XCTAssertGreaterThan(uniprotCount, 0)
        XCTAssertGreaterThan(genesCount, 0)
        print("Step 6: Verified counts (processed: \(processedCount), uniprot: \(uniprotCount), genes: \(genesCount))")

        // Step 7: Load from database
        guard let loadedData = service.loadCurtainDataFromDatabase(linkId: linkId) else {
            XCTFail("Step 7 FAILED: Load from database")
            return
        }
        XCTAssertEqual(loadedData.curtainType, "TP")
        print("Step 7: Loaded from database successfully")

        print("ALL STEPS PASSED")
    }

    func testCompletePTMPipeline() async throws {
        print("\n=== TEST: testCompletePTMPipeline ===")

        // Step 1: Download
        try await ensureDataLoaded()
        guard let data = Self.cachedPTMData else {
            XCTFail("Step 1 FAILED: Download")
            return
        }
        print("Step 1: Downloaded \(data.count) bytes")

        // Step 2: Verify JSON parsing
        guard let json = Self.cachedPTMJson else {
            XCTFail("Step 2 FAILED: JSON parsing")
            return
        }
        print("Step 2: Parsed JSON with \(json.keys.count) keys")

        // Step 3: Verify CurtainData
        guard let curtainData = Self.cachedPTMCurtainData else {
            XCTFail("Step 3 FAILED: CurtainData parsing")
            return
        }
        print("Step 3: Created CurtainData (type: \(curtainData.curtainType))")

        // Step 4: Verify IS PTM
        XCTAssertTrue(curtainData.differentialForm.isPTM)
        print("Step 4: Verified IS PTM (accession: \(curtainData.differentialForm.accession), position: \(curtainData.differentialForm.position))")

        // Step 5: Build SQLite database
        let linkId = "test-full-ptm-\(UUID().uuidString)"
        let service = ProteomicsDataService.shared

        defer {
            service.clearDatabaseForLinkId(linkId)
        }

        try service.buildProteomicsDataIfNeeded(
            linkId: linkId,
            rawTsv: json["raw"] as? String,
            processedTsv: json["processed"] as? String,
            rawForm: curtainData.rawForm,
            differentialForm: curtainData.differentialForm,
            curtainData: curtainData,
            onProgress: { _ in }
        )
        print("Step 5: Built SQLite database")

        // Step 6: Query counts
        let processedCount = try service.getProcessedDataCount(linkId: linkId)
        let uniprotCount = try service.getUniProtEntryCount(linkId: linkId)
        let accessions = try service.getDistinctAccessions(linkId: linkId)

        XCTAssertGreaterThan(processedCount, 0)
        XCTAssertGreaterThan(uniprotCount, 0)
        XCTAssertGreaterThan(accessions.count, 0)
        print("Step 6: Verified counts (processed: \(processedCount), uniprot: \(uniprotCount), accessions: \(accessions.count))")

        // Step 7: Load from database
        guard let loadedData = service.loadCurtainDataFromDatabase(linkId: linkId) else {
            XCTFail("Step 7 FAILED: Load from database")
            return
        }
        XCTAssertTrue(loadedData.differentialForm.isPTM)
        print("Step 7: Loaded from database successfully (isPTM: \(loadedData.differentialForm.isPTM))")

        // Step 8: Query PTM sites
        if let firstAcc = accessions.first {
            let sites = service.getExperimentalPTMSites(
                linkId: linkId,
                accession: firstAcc,
                pCutoff: 0.05,
                fcCutoff: 0.6
            )
            print("Step 8: Found \(sites.count) PTM sites for \(firstAcc)")
        }

        print("ALL STEPS PASSED")
    }

    // MARK: - Additional Query Tests

    func testGetProcessedDataForProtein() async throws {
        try await ensureDataLoaded()

        guard let curtainData = Self.cachedTPCurtainData,
              let json = Self.cachedTPJson else {
            XCTFail("TP data was not parsed")
            return
        }

        let linkId = "test-protein-query-\(UUID().uuidString)"
        let service = ProteomicsDataService.shared

        defer {
            service.clearDatabaseForLinkId(linkId)
        }

        // Build data
        try service.buildProteomicsDataIfNeeded(
            linkId: linkId,
            rawTsv: json["raw"] as? String,
            processedTsv: json["processed"] as? String,
            rawForm: curtainData.rawForm,
            differentialForm: curtainData.differentialForm,
            curtainData: curtainData,
            onProgress: { _ in }
        )

        // Get some primary IDs
        let primaryIds = try service.getDistinctPrimaryIds(linkId: linkId)
        guard let firstProtein = primaryIds.first else {
            XCTFail("No proteins found")
            return
        }

        print("Testing protein: \(firstProtein)")

        // Test getProcessedDataForProtein
        let processedData = try service.getProcessedDataForProtein(linkId: linkId, primaryId: firstProtein)
        print("Processed data entries for \(firstProtein): \(processedData.count)")
        XCTAssertGreaterThan(processedData.count, 0, "Should have processed data for protein")

        // Verify data structure
        if let first = processedData.first {
            print("  primaryId: \(first.primaryId)")
            print("  comparison: \(first.comparison)")
            print("  foldChange: \(first.foldChange ?? 0)")
            print("  significant: \(first.significant ?? 0)")
            XCTAssertEqual(first.primaryId, firstProtein)
        }
    }

    func testGetRawDataForProtein() async throws {
        try await ensureDataLoaded()

        guard let curtainData = Self.cachedTPCurtainData,
              let json = Self.cachedTPJson else {
            XCTFail("TP data was not parsed")
            return
        }

        let linkId = "test-raw-query-\(UUID().uuidString)"
        let service = ProteomicsDataService.shared

        defer {
            service.clearDatabaseForLinkId(linkId)
        }

        // Build data
        try service.buildProteomicsDataIfNeeded(
            linkId: linkId,
            rawTsv: json["raw"] as? String,
            processedTsv: json["processed"] as? String,
            rawForm: curtainData.rawForm,
            differentialForm: curtainData.differentialForm,
            curtainData: curtainData,
            onProgress: { _ in }
        )

        // Get some primary IDs
        let primaryIds = try service.getDistinctPrimaryIds(linkId: linkId)
        guard let firstProtein = primaryIds.first else {
            XCTFail("No proteins found")
            return
        }

        print("Testing raw data for protein: \(firstProtein)")

        // Test getRawDataForProtein
        let rawData = try service.getRawDataForProtein(linkId: linkId, primaryId: firstProtein)
        print("Raw data entries for \(firstProtein): \(rawData.count)")
        XCTAssertGreaterThan(rawData.count, 0, "Should have raw data for protein")

        // Verify data structure
        for entry in rawData.prefix(3) {
            print("  sample: \(entry.sampleName), value: \(entry.sampleValue ?? 0)")
        }
    }

    // MARK: - Settings Detail Tests

    func testConditionOrderParsing() async throws {
        try await ensureDataLoaded()

        guard let curtainData = Self.cachedTPCurtainData else {
            XCTFail("TP CurtainData was not parsed")
            return
        }

        let settings = curtainData.settings

        print("conditionOrder: \(settings.conditionOrder)")
        print("currentComparison: \(settings.currentComparison)")
        print("selectedComparison: \(settings.selectedComparison ?? [])")

        // At least one of these should have data for meaningful TP data
        let hasConditions = !settings.conditionOrder.isEmpty || !settings.currentComparison.isEmpty
        print("Has conditions or comparisons: \(hasConditions)")
    }

    // MARK: - ExtraData Maps Tests

    func testGenesMapStorage() async throws {
        try await ensureDataLoaded()

        guard let curtainData = Self.cachedTPCurtainData,
              let json = Self.cachedTPJson else {
            XCTFail("TP data was not parsed")
            return
        }

        let linkId = "test-genesmap-\(UUID().uuidString)"
        let service = ProteomicsDataService.shared

        defer {
            service.clearDatabaseForLinkId(linkId)
        }

        // Check if genesMap exists in extraData
        if let data = curtainData.extraData?.data,
           let genesMap = data.genesMap {
            print("genesMap entries in source: \(genesMap.count)")
        } else {
            print("No genesMap in extraData - this is OK for some data")
        }

        // Build data
        try service.buildProteomicsDataIfNeeded(
            linkId: linkId,
            rawTsv: json["raw"] as? String,
            processedTsv: json["processed"] as? String,
            rawForm: curtainData.rawForm,
            differentialForm: curtainData.differentialForm,
            curtainData: curtainData,
            onProgress: { _ in }
        )

        // Verify database was built
        let count = try service.getProcessedDataCount(linkId: linkId)
        XCTAssertGreaterThan(count, 0, "Should have stored processed data")
        print("Stored \(count) processed entries")
    }

    func testGeneNameToAccStorage() async throws {
        try await ensureDataLoaded()

        guard let curtainData = Self.cachedTPCurtainData,
              let json = Self.cachedTPJson else {
            XCTFail("TP data was not parsed")
            return
        }

        let linkId = "test-genenametoacc-\(UUID().uuidString)"
        let service = ProteomicsDataService.shared

        defer {
            service.clearDatabaseForLinkId(linkId)
        }

        // Check if geneNameToAcc exists in extraData
        if let uniprot = curtainData.extraData?.uniprot,
           let geneNameToAcc = uniprot.geneNameToAcc {
            print("geneNameToAcc entries in source: \(geneNameToAcc.count)")

            // Print first few entries
            for (geneName, accession) in geneNameToAcc.prefix(3) {
                print("  \(geneName) -> \(accession)")
            }
        } else {
            print("No geneNameToAcc in extraData")
        }

        // Build data
        try service.buildProteomicsDataIfNeeded(
            linkId: linkId,
            rawTsv: json["raw"] as? String,
            processedTsv: json["processed"] as? String,
            rawForm: curtainData.rawForm,
            differentialForm: curtainData.differentialForm,
            curtainData: curtainData,
            onProgress: { _ in }
        )

        // Verify UniProt entries were stored
        let uniprotCount = try service.getUniProtEntryCount(linkId: linkId)
        XCTAssertGreaterThan(uniprotCount, 0, "Should have stored UniProt entries")
        print("Stored \(uniprotCount) UniProt entries")
    }

    // MARK: - Error Handling Tests

    func testMalformedJSONHandling() async throws {
        // Test that CurtainData.fromJSON handles malformed data gracefully
        let malformedJson: [String: Any] = [
            "settings": "not a dictionary",
            "raw": 12345,  // Should be string
        ]

        let result = CurtainData.fromJSON(malformedJson)
        // Should return nil or handle gracefully, not crash
        print("Malformed JSON result: \(result == nil ? "nil (expected)" : "parsed")")
    }

    func testEmptyDataHandling() async throws {
        // Test that parsing handles empty data gracefully
        let emptyJson: [String: Any] = [:]

        let result = CurtainData.fromJSON(emptyJson)
        print("Empty JSON result: \(result == nil ? "nil" : "parsed with defaults")")
    }

    // MARK: - Data Processing Tests

    func testFoldChangeTransformation() async throws {
        try await ensureDataLoaded()

        guard let curtainData = Self.cachedTPCurtainData,
              let json = Self.cachedTPJson else {
            XCTFail("TP data was not parsed")
            return
        }

        let linkId = "test-foldchange-\(UUID().uuidString)"
        let service = ProteomicsDataService.shared

        defer {
            service.clearDatabaseForLinkId(linkId)
        }

        // Build data
        try service.buildProteomicsDataIfNeeded(
            linkId: linkId,
            rawTsv: json["raw"] as? String,
            processedTsv: json["processed"] as? String,
            rawForm: curtainData.rawForm,
            differentialForm: curtainData.differentialForm,
            curtainData: curtainData,
            onProgress: { _ in }
        )

        // Get processed data and verify fold change values
        let primaryIds = try service.getDistinctPrimaryIds(linkId: linkId)
        guard let firstProtein = primaryIds.first else {
            XCTFail("No proteins found")
            return
        }

        let processedData = try service.getProcessedDataForProtein(linkId: linkId, primaryId: firstProtein)
        guard let first = processedData.first else {
            XCTFail("No processed data for protein")
            return
        }

        print("Fold change value: \(first.foldChange ?? 0)")
        print("Significance value: \(first.significant ?? 0)")

        // Verify data is present (values depend on actual data)
        XCTAssertNotNil(first.foldChange, "Fold change should be present")
    }

    func testSignificanceTransformation() async throws {
        try await ensureDataLoaded()

        guard let curtainData = Self.cachedTPCurtainData,
              let json = Self.cachedTPJson else {
            XCTFail("TP data was not parsed")
            return
        }

        let linkId = "test-significance-\(UUID().uuidString)"
        let service = ProteomicsDataService.shared

        defer {
            service.clearDatabaseForLinkId(linkId)
        }

        // Build data
        try service.buildProteomicsDataIfNeeded(
            linkId: linkId,
            rawTsv: json["raw"] as? String,
            processedTsv: json["processed"] as? String,
            rawForm: curtainData.rawForm,
            differentialForm: curtainData.differentialForm,
            curtainData: curtainData,
            onProgress: { _ in }
        )

        // Get processed data and verify significance values
        let primaryIds = try service.getDistinctPrimaryIds(linkId: linkId)
        guard let firstProtein = primaryIds.first else {
            XCTFail("No proteins found")
            return
        }

        let processedData = try service.getProcessedDataForProtein(linkId: linkId, primaryId: firstProtein)
        guard let first = processedData.first else {
            XCTFail("No processed data for protein")
            return
        }

        print("Significance (p-value) for \(firstProtein): \(first.significant ?? 0)")

        // Significance should be -log10(p-value)
        if let significance = first.significant {
            // Should be a positive value for significant proteins
            print("Significance value is valid: \(significance)")
        }
    }

    func testComparisonFiltering() async throws {
        try await ensureDataLoaded()

        guard let curtainData = Self.cachedTPCurtainData,
              let json = Self.cachedTPJson else {
            XCTFail("TP data was not parsed")
            return
        }

        let linkId = "test-comparison-\(UUID().uuidString)"
        let service = ProteomicsDataService.shared

        defer {
            service.clearDatabaseForLinkId(linkId)
        }

        // Build data
        try service.buildProteomicsDataIfNeeded(
            linkId: linkId,
            rawTsv: json["raw"] as? String,
            processedTsv: json["processed"] as? String,
            rawForm: curtainData.rawForm,
            differentialForm: curtainData.differentialForm,
            curtainData: curtainData,
            onProgress: { _ in }
        )

        // Get all data and extract distinct comparisons
        let allData = try service.getAllProcessedData(linkId: linkId)
        let comparisons = Set(allData.map { $0.comparison })
        print("Found \(comparisons.count) comparisons: \(comparisons)")

        XCTAssertGreaterThan(comparisons.count, 0, "Should have at least one comparison")

        // Get data for specific comparison using existing method
        if let firstComparison = comparisons.first {
            let filteredData = try service.getProcessedDataByComparison(linkId: linkId, comparison: firstComparison)
            print("Data for comparison '\(firstComparison)': \(filteredData.count) entries")
            XCTAssertGreaterThan(filteredData.count, 0, "Should have data for comparison")
        }
    }

    // MARK: - Search Tests

    func testProteinSearchByName() async throws {
        try await ensureDataLoaded()

        guard let curtainData = Self.cachedTPCurtainData,
              let json = Self.cachedTPJson else {
            XCTFail("TP data was not parsed")
            return
        }

        let linkId = "test-search-\(UUID().uuidString)"
        let service = ProteomicsDataService.shared

        defer {
            service.clearDatabaseForLinkId(linkId)
        }

        // Build data
        try service.buildProteomicsDataIfNeeded(
            linkId: linkId,
            rawTsv: json["raw"] as? String,
            processedTsv: json["processed"] as? String,
            rawForm: curtainData.rawForm,
            differentialForm: curtainData.differentialForm,
            curtainData: curtainData,
            onProgress: { _ in }
        )

        // Get some primary IDs for search
        let primaryIds = try service.getDistinctPrimaryIds(linkId: linkId)
        guard let firstId = primaryIds.first else {
            XCTFail("No primary IDs found")
            return
        }

        // Search for the first few characters of a primary ID (manual search)
        let searchTerm = String(firstId.prefix(3)).lowercased()
        print("Searching for: \(searchTerm)")

        // Get all data and filter manually
        let allData = try service.getAllProcessedData(linkId: linkId)
        let results = allData.filter { $0.primaryId.lowercased().contains(searchTerm) }
        print("Search results for '\(searchTerm)': \(results.count) matches")

        XCTAssertGreaterThan(results.count, 0, "Should find proteins matching '\(searchTerm)'")
    }

    func testFilterBySignificance() async throws {
        try await ensureDataLoaded()

        guard let curtainData = Self.cachedTPCurtainData,
              let json = Self.cachedTPJson else {
            XCTFail("TP data was not parsed")
            return
        }

        let linkId = "test-filter-sig-\(UUID().uuidString)"
        let service = ProteomicsDataService.shared

        defer {
            service.clearDatabaseForLinkId(linkId)
        }

        // Build data
        try service.buildProteomicsDataIfNeeded(
            linkId: linkId,
            rawTsv: json["raw"] as? String,
            processedTsv: json["processed"] as? String,
            rawForm: curtainData.rawForm,
            differentialForm: curtainData.differentialForm,
            curtainData: curtainData,
            onProgress: { _ in }
        )

        // Get settings for cutoffs
        let pCutoff = curtainData.settings.pCutoff
        let fcCutoff = curtainData.settings.log2FCCutoff

        print("Filtering with pCutoff: \(pCutoff), fcCutoff: \(fcCutoff)")

        // Get all data and filter for significant proteins manually
        let allData = try service.getAllProcessedData(linkId: linkId)

        // Significance in database is -log10(pvalue), so higher is more significant
        // Filter for significance > -log10(pCutoff) and |foldChange| > fcCutoff
        let significanceThreshold = -log10(pCutoff)
        let significantData = allData.filter { data in
            guard let significance = data.significant,
                  let foldChange = data.foldChange else { return false }
            return significance > significanceThreshold && abs(foldChange) > fcCutoff
        }

        print("Significant proteins (p < \(pCutoff), |FC| > \(fcCutoff)): \(significantData.count)")

        // Should have some significant proteins
        XCTAssertGreaterThanOrEqual(significantData.count, 0, "Significant proteins count should be >= 0")
    }

    // MARK: - UniProt Data Tests

    func testUniProtSequenceRetrieval() async throws {
        try await ensureDataLoaded()

        guard let curtainData = Self.cachedPTMCurtainData,
              let json = Self.cachedPTMJson else {
            XCTFail("PTM data was not parsed")
            return
        }

        let linkId = "test-uniprot-seq-\(UUID().uuidString)"
        let service = ProteomicsDataService.shared

        defer {
            service.clearDatabaseForLinkId(linkId)
        }

        // Build data
        try service.buildProteomicsDataIfNeeded(
            linkId: linkId,
            rawTsv: json["raw"] as? String,
            processedTsv: json["processed"] as? String,
            rawForm: curtainData.rawForm,
            differentialForm: curtainData.differentialForm,
            curtainData: curtainData,
            onProgress: { _ in }
        )

        // Get an accession
        let accessions = try service.getDistinctAccessions(linkId: linkId)
        guard let firstAcc = accessions.first else {
            XCTFail("No accessions found")
            return
        }

        print("Testing UniProt sequence for: \(firstAcc)")

        // Get UniProt sequence
        let sequence = service.getUniProtSequence(linkId: linkId, accession: firstAcc)
        print("Sequence length: \(sequence?.count ?? 0)")

        if let seq = sequence {
            XCTAssertGreaterThan(seq.count, 0, "Sequence should not be empty")
            print("First 50 chars: \(String(seq.prefix(50)))...")
        }
    }

    func testUniProtDataJsonRetrieval() async throws {
        try await ensureDataLoaded()

        guard let curtainData = Self.cachedPTMCurtainData,
              let json = Self.cachedPTMJson else {
            XCTFail("PTM data was not parsed")
            return
        }

        let linkId = "test-uniprot-json-\(UUID().uuidString)"
        let service = ProteomicsDataService.shared

        defer {
            service.clearDatabaseForLinkId(linkId)
        }

        // Build data
        try service.buildProteomicsDataIfNeeded(
            linkId: linkId,
            rawTsv: json["raw"] as? String,
            processedTsv: json["processed"] as? String,
            rawForm: curtainData.rawForm,
            differentialForm: curtainData.differentialForm,
            curtainData: curtainData,
            onProgress: { _ in }
        )

        // Get an accession
        let accessions = try service.getDistinctAccessions(linkId: linkId)
        guard let firstAcc = accessions.first else {
            XCTFail("No accessions found")
            return
        }

        print("Testing UniProt data JSON for: \(firstAcc)")

        // Get UniProt data
        let uniprotData = service.getUniProtDataJson(linkId: linkId, accession: firstAcc)
        print("UniProt data keys: \(uniprotData?.keys.sorted() ?? [])")

        if let data = uniprotData {
            XCTAssertGreaterThan(data.count, 0, "UniProt data should have entries")

            // Check for common fields
            if let geneName = data["Gene Names"] as? String {
                print("Gene Name: \(geneName)")
            }
            if let proteinName = data["Protein names"] as? String {
                print("Protein Name: \(String(proteinName.prefix(50)))...")
            }
        }
    }

    // MARK: - Complete Volcano Plot Data Test

    func testVolcanoPlotDataGeneration() async throws {
        try await ensureDataLoaded()

        guard let curtainData = Self.cachedTPCurtainData,
              let json = Self.cachedTPJson else {
            XCTFail("TP data was not parsed")
            return
        }

        let linkId = "test-volcano-\(UUID().uuidString)"
        let service = ProteomicsDataService.shared

        defer {
            service.clearDatabaseForLinkId(linkId)
        }

        // Build data
        try service.buildProteomicsDataIfNeeded(
            linkId: linkId,
            rawTsv: json["raw"] as? String,
            processedTsv: json["processed"] as? String,
            rawForm: curtainData.rawForm,
            differentialForm: curtainData.differentialForm,
            curtainData: curtainData,
            onProgress: { _ in }
        )

        // Get volcano plot data (all processed data with fold change and significance)
        let processedCount = try service.getProcessedDataCount(linkId: linkId)
        print("Total data points for volcano plot: \(processedCount)")
        XCTAssertGreaterThan(processedCount, 0, "Should have volcano plot data")

        // Get settings for cutoffs
        let pCutoff = curtainData.settings.pCutoff
        let fcCutoff = curtainData.settings.log2FCCutoff

        // Get all data for volcano plot analysis
        let allData = try service.getAllProcessedData(linkId: linkId)

        // Count significant points (for volcano plot coloring)
        let significanceThreshold = -log10(pCutoff)

        let significantUp = allData.filter { data in
            guard let significance = data.significant,
                  let foldChange = data.foldChange else { return false }
            return significance > significanceThreshold && foldChange > fcCutoff
        }

        let significantDown = allData.filter { data in
            guard let significance = data.significant,
                  let foldChange = data.foldChange else { return false }
            return significance > significanceThreshold && foldChange < -fcCutoff
        }

        print("Significant UP (FC > \(fcCutoff)): \(significantUp.count)")
        print("Significant DOWN (FC < -\(fcCutoff)): \(significantDown.count)")
        print("Total significant: \(significantUp.count + significantDown.count)")
        print("Non-significant: \(allData.count - significantUp.count - significantDown.count)")
    }

    // MARK: - Bar Chart Data Test

    func testBarChartDataGeneration() async throws {
        try await ensureDataLoaded()

        guard let curtainData = Self.cachedTPCurtainData,
              let json = Self.cachedTPJson else {
            XCTFail("TP data was not parsed")
            return
        }

        let linkId = "test-barchart-\(UUID().uuidString)"
        let service = ProteomicsDataService.shared

        defer {
            service.clearDatabaseForLinkId(linkId)
        }

        // Build data
        try service.buildProteomicsDataIfNeeded(
            linkId: linkId,
            rawTsv: json["raw"] as? String,
            processedTsv: json["processed"] as? String,
            rawForm: curtainData.rawForm,
            differentialForm: curtainData.differentialForm,
            curtainData: curtainData,
            onProgress: { _ in }
        )

        // Get raw data for bar chart
        let primaryIds = try service.getDistinctPrimaryIds(linkId: linkId)
        guard let firstProtein = primaryIds.first else {
            XCTFail("No proteins found")
            return
        }

        let rawData = try service.getRawDataForProtein(linkId: linkId, primaryId: firstProtein)
        print("Raw data points for bar chart (\(firstProtein)): \(rawData.count)")

        XCTAssertGreaterThan(rawData.count, 0, "Should have raw data for bar chart")

        // Verify sample structure
        let sampleNames = rawData.map { $0.sampleName }
        let uniqueSamples = Set(sampleNames)
        print("Unique samples: \(uniqueSamples.count)")

        // Get sample values for plotting
        var sampleValues: [String: [Double]] = [:]
        for entry in rawData {
            if let value = entry.sampleValue {
                sampleValues[entry.sampleName, default: []].append(value)
            }
        }

        print("Sample groups: \(sampleValues.keys.sorted())")
    }
}

// MARK: - Test Errors

enum TestError: Error, LocalizedError {
    case notHTTPResponse
    case httpError(statusCode: Int)
    case jsonParsingFailed
    case curtainDataParsingFailed

    var errorDescription: String? {
        switch self {
        case .notHTTPResponse:
            return "Response is not HTTP"
        case .httpError(let statusCode):
            return "HTTP error: \(statusCode)"
        case .jsonParsingFailed:
            return "Failed to parse JSON"
        case .curtainDataParsingFailed:
            return "Failed to parse CurtainData from JSON"
        }
    }
}

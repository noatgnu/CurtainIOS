//
//  DataCorrectnessIntegrationTests.swift
//  CurtainTests
//
//  Comprehensive integration tests that verify data correctness
//  by comparing parsed data against known expected values from real datasets.
//

import XCTest
@testable import Curtain

final class DataCorrectnessIntegrationTests: XCTestCase {

    // MARK: - Helper Methods

    /// Downloads data using the two-step process: API -> signed URL -> S3
    private func downloadCurtainData(linkId: String, hostname: String) async throws -> (Data, [String: Any]) {
        let apiURL = "\(hostname)curtain/\(linkId)/download/token=/"

        let (urlData, urlResponse) = try await URLSession.shared.data(from: URL(string: apiURL)!)

        guard let httpResponse = urlResponse as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSError(domain: "DataCorrectnessIntegrationTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to get signed URL"])
        }

        guard let urlJson = try JSONSerialization.jsonObject(with: urlData) as? [String: Any],
              let signedUrl = urlJson["url"] as? String else {
            throw NSError(domain: "DataCorrectnessIntegrationTests", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to parse signed URL"])
        }

        let (data, dataResponse) = try await URLSession.shared.data(from: URL(string: signedUrl)!)

        guard let s3Response = dataResponse as? HTTPURLResponse, s3Response.statusCode == 200 else {
            throw NSError(domain: "DataCorrectnessIntegrationTests", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to download from S3"])
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "DataCorrectnessIntegrationTests", code: 4, userInfo: [NSLocalizedDescriptionKey: "Failed to parse JSON"])
        }

        return (data, json)
    }

    // MARK: - TP Dataset Data Correctness Tests

    func testTPDatasetHasExpectedProteins() async throws {
        let linkId = CurtainConstants.ExampleData.uniqueId
        let hostname = CurtainConstants.ExampleData.apiUrl

        let (_, json) = try await downloadCurtainData(linkId: linkId, hostname: hostname)

        guard let curtainData = CurtainData.fromJSON(json) else {
            XCTFail("Failed to parse CurtainData")
            return
        }

        // Verify UniProt DB has proteins
        guard let uniprotDb = curtainData.extraData?.uniprot?.db else {
            XCTFail("UniProt DB should exist")
            return
        }

        // Real data has 8612 UniProt entries
        print("TP Dataset: Found \(uniprotDb.count) UniProt entries")
        XCTAssertGreaterThan(uniprotDb.count, 8000, "Should have ~8612 UniProt entries, got \(uniprotDb.count)")

        // Verify specific known protein Q2M2I8 (AAK1) is present
        // In real data: Q2M2I8 has Gene Names "AAK1;KIAA1048"
        guard let aak1Entry = uniprotDb["Q2M2I8"] as? [String: Any] else {
            XCTFail("Q2M2I8 (AAK1) should exist in UniProt DB")
            return
        }

        let geneNames = aak1Entry["Gene Names"] as? String ?? ""
        XCTAssertTrue(geneNames.contains("AAK1"), "Q2M2I8 should have Gene Name containing AAK1, got: \(geneNames)")
        print("Q2M2I8 Gene Names: \(geneNames)")

        // Verify P00519 (ABL1) is present
        guard let abl1Entry = uniprotDb["P00519"] as? [String: Any] else {
            XCTFail("P00519 (ABL1) should exist in UniProt DB")
            return
        }

        let abl1GeneNames = abl1Entry["Gene Names"] as? String ?? ""
        print("P00519 Gene Names: \(abl1GeneNames)")
    }

    func testTPDatasetGeneNameResolution() async throws {
        let linkId = CurtainConstants.ExampleData.uniqueId
        let hostname = CurtainConstants.ExampleData.apiUrl

        let (_, json) = try await downloadCurtainData(linkId: linkId, hostname: hostname)

        guard let curtainData = CurtainData.fromJSON(json) else {
            XCTFail("Failed to parse CurtainData")
            return
        }

        guard let uniprotDb = curtainData.extraData?.uniprot?.db else {
            XCTFail("UniProt DB should exist")
            return
        }

        // Test specific protein -> gene name mappings from REAL data
        // Q2M2I8 -> AAK1;KIAA1048 (verified from actual dataset)
        if let aak1Entry = uniprotDb["Q2M2I8"] as? [String: Any],
           let geneNames = aak1Entry["Gene Names"] as? String {
            XCTAssertTrue(geneNames.contains("AAK1"), "Q2M2I8 should have gene name AAK1, got: \(geneNames)")
            XCTAssertTrue(geneNames.contains("KIAA1048"), "Q2M2I8 should have gene name KIAA1048, got: \(geneNames)")
            print("Q2M2I8 -> \(geneNames)")
        } else {
            XCTFail("Q2M2I8 should have Gene Names field")
        }

        // P00519 -> ABL1 (verified from processed data)
        if let abl1Entry = uniprotDb["P00519"] as? [String: Any],
           let geneNames = abl1Entry["Gene Names"] as? String {
            XCTAssertTrue(geneNames.contains("ABL1"), "P00519 should have gene name ABL1, got: \(geneNames)")
            print("P00519 -> \(geneNames)")
        } else {
            XCTFail("P00519 should have Gene Names field")
        }

        // P42684 (from processed data) - verify it exists
        if let entry = uniprotDb["P42684"] as? [String: Any],
           let geneNames = entry["Gene Names"] as? String {
            print("P42684 -> \(geneNames)")
        } else {
            // This protein may not have Gene Names, just verify it exists
            XCTAssertNotNil(uniprotDb["P42684"], "P42684 should exist in UniProt DB")
        }
    }

    func testTPDatasetDifferentialFormColumns() async throws {
        let linkId = CurtainConstants.ExampleData.uniqueId
        let hostname = CurtainConstants.ExampleData.apiUrl

        let (_, json) = try await downloadCurtainData(linkId: linkId, hostname: hostname)

        guard let curtainData = CurtainData.fromJSON(json) else {
            XCTFail("Failed to parse CurtainData")
            return
        }

        // Verify differential form has expected column names from TP dataset
        let diffForm = curtainData.differentialForm

        XCTAssertFalse(diffForm.primaryIDs.isEmpty, "primaryIDs column should be set")
        XCTAssertFalse(diffForm.foldChange.isEmpty, "foldChange column should be set")
        XCTAssertFalse(diffForm.significant.isEmpty, "significant column should be set")

        print("TP DifferentialForm:")
        print("  primaryIDs: \(diffForm.primaryIDs)")
        print("  geneNames: \(diffForm.geneNames)")
        print("  foldChange: \(diffForm.foldChange)")
        print("  significant: \(diffForm.significant)")
        print("  comparison: \(diffForm.comparison)")

        // Verify it's NOT PTM data
        XCTAssertFalse(diffForm.isPTM, "TP data should NOT be PTM")
        XCTAssertTrue(diffForm.accession.isEmpty, "TP data should not have accession column")
        XCTAssertTrue(diffForm.position.isEmpty, "TP data should not have position column")
    }

    func testTPDatasetSettingsValues() async throws {
        let linkId = CurtainConstants.ExampleData.uniqueId
        let hostname = CurtainConstants.ExampleData.apiUrl

        let (_, json) = try await downloadCurtainData(linkId: linkId, hostname: hostname)

        let service = CurtainDataService()
        try await service.restoreSettings(from: json)

        // Verify expected settings values from TP dataset
        XCTAssertEqual(service.curtainSettings.pCutoff, 0.05, accuracy: 0.001, "pCutoff should be 0.05")
        XCTAssertEqual(service.curtainSettings.log2FCCutoff, 0.6, accuracy: 0.001, "log2FCCutoff should be 0.6")

        // Verify condition order exists and has values
        XCTAssertFalse(service.curtainSettings.conditionOrder.isEmpty, "conditionOrder should not be empty")
        print("TP Settings conditionOrder: \(service.curtainSettings.conditionOrder)")

        // Verify UniProt fetching is enabled
        XCTAssertTrue(service.curtainSettings.fetchUniprot, "fetchUniprot should be enabled")
        print("TP Settings fetchUniprot: \(service.curtainSettings.fetchUniprot)")
    }

    // MARK: - PTM Dataset Data Correctness Tests

    func testPTMDatasetHasExpectedFields() async throws {
        let linkId = CurtainConstants.ExamplePTMData.uniqueId
        let hostname = CurtainConstants.ExamplePTMData.apiUrl

        let (_, json) = try await downloadCurtainData(linkId: linkId, hostname: hostname)

        guard let curtainData = CurtainData.fromJSON(json) else {
            XCTFail("Failed to parse PTM CurtainData")
            return
        }

        let diffForm = curtainData.differentialForm

        // Verify PTM-specific fields are present
        XCTAssertTrue(diffForm.isPTM, "PTM data should be detected as PTM")
        XCTAssertFalse(diffForm.accession.isEmpty, "PTM should have accession column: \(diffForm.accession)")
        XCTAssertFalse(diffForm.position.isEmpty, "PTM should have position column: \(diffForm.position)")

        print("PTM DifferentialForm:")
        print("  isPTM: \(diffForm.isPTM)")
        print("  primaryIDs: \(diffForm.primaryIDs)")
        print("  accession: \(diffForm.accession)")
        print("  position: \(diffForm.position)")
        print("  positionPeptide: \(diffForm.positionPeptide)")
        print("  peptideSequence: \(diffForm.peptideSequence)")
        print("  score: \(diffForm.score)")
        print("  foldChange: \(diffForm.foldChange)")
        print("  significant: \(diffForm.significant)")
    }

    func testPTMDatasetUniProtSequences() async throws {
        let linkId = CurtainConstants.ExamplePTMData.uniqueId
        let hostname = CurtainConstants.ExamplePTMData.apiUrl

        let (_, json) = try await downloadCurtainData(linkId: linkId, hostname: hostname)

        guard let curtainData = CurtainData.fromJSON(json) else {
            XCTFail("Failed to parse PTM CurtainData")
            return
        }

        guard let uniprotDb = curtainData.extraData?.uniprot?.db else {
            XCTFail("PTM data should have UniProt DB")
            return
        }

        // Verify UniProt entries have sequence data for PTM alignment
        var entriesWithSequence = 0
        var sampleEntries: [(String, Int)] = []

        for (accession, entry) in uniprotDb {
            if let entryDict = entry as? [String: Any],
               let sequence = entryDict["Sequence"] as? String,
               !sequence.isEmpty {
                entriesWithSequence += 1
                if sampleEntries.count < 3 {
                    sampleEntries.append((accession, sequence.count))
                }
            }
        }

        print("PTM UniProt entries with sequences: \(entriesWithSequence)/\(uniprotDb.count)")
        for (acc, len) in sampleEntries {
            print("  \(acc): \(len) residues")
        }

        XCTAssertGreaterThan(entriesWithSequence, 0, "Should have UniProt entries with sequences for PTM alignment")
    }

    // MARK: - Volcano Plot Data Correctness Tests

    func testTPVolcanoPlotDataGeneration() async throws {
        let linkId = CurtainConstants.ExampleData.uniqueId
        let hostname = CurtainConstants.ExampleData.apiUrl

        let (_, json) = try await downloadCurtainData(linkId: linkId, hostname: hostname)

        let service = CurtainDataService()
        try await service.restoreSettings(from: json)

        // Create AppData for volcano plot processing
        let appData = AppData()
        appData.dataMap = service.curtainData.dataMap
        appData.differentialForm = service.curtainData.differentialForm
        appData.selectedMap = service.curtainData.selectedMap ?? [:]
        appData.uniprotDB = service.uniprotData.db

        let volcanoService = VolcanoPlotDataService()
        let result = await volcanoService.processVolcanoData(curtainData: appData, settings: service.curtainSettings)

        // Verify volcano plot data was generated
        XCTAssertFalse(result.jsonData.isEmpty, "Volcano plot should have data points")
        print("Volcano plot generated \(result.jsonData.count) data points")

        // Verify data point structure
        if let firstPoint = result.jsonData.first {
            XCTAssertNotNil(firstPoint["x"], "Data point should have x (fold change)")
            XCTAssertNotNil(firstPoint["y"], "Data point should have y (significance)")
            XCTAssertNotNil(firstPoint["id"], "Data point should have id")
            XCTAssertNotNil(firstPoint["gene"], "Data point should have gene name")
            XCTAssertNotNil(firstPoint["color"], "Data point should have color")
            XCTAssertNotNil(firstPoint["selections"], "Data point should have selections")

            print("Sample data point:")
            print("  id: \(firstPoint["id"] ?? "nil")")
            print("  gene: \(firstPoint["gene"] ?? "nil")")
            print("  x: \(firstPoint["x"] ?? "nil")")
            print("  y: \(firstPoint["y"] ?? "nil")")
            print("  color: \(firstPoint["color"] ?? "nil")")
        }

        // Verify axis configuration
        XCTAssertNotNil(result.updatedVolcanoAxis.minX, "Should have minX")
        XCTAssertNotNil(result.updatedVolcanoAxis.maxX, "Should have maxX")
        XCTAssertNotNil(result.updatedVolcanoAxis.maxY, "Should have maxY")

        print("Volcano axis: x=[\(result.updatedVolcanoAxis.minX ?? 0), \(result.updatedVolcanoAxis.maxX ?? 0)], y=[0, \(result.updatedVolcanoAxis.maxY ?? 0)]")
    }

    func testTPVolcanoPlotColorAssignment() async throws {
        let linkId = CurtainConstants.ExampleData.uniqueId
        let hostname = CurtainConstants.ExampleData.apiUrl

        let (_, json) = try await downloadCurtainData(linkId: linkId, hostname: hostname)

        let service = CurtainDataService()
        try await service.restoreSettings(from: json)

        let appData = AppData()
        appData.dataMap = service.curtainData.dataMap
        appData.differentialForm = service.curtainData.differentialForm
        appData.selectedMap = service.curtainData.selectedMap ?? [:]
        appData.uniprotDB = service.uniprotData.db

        let volcanoService = VolcanoPlotDataService()
        let result = await volcanoService.processVolcanoData(curtainData: appData, settings: service.curtainSettings)

        // Collect unique colors
        var colorCounts: [String: Int] = [:]
        for point in result.jsonData {
            if let color = point["color"] as? String {
                colorCounts[color, default: 0] += 1
            }
        }

        print("Volcano plot color distribution:")
        for (color, count) in colorCounts.sorted(by: { $0.value > $1.value }) {
            print("  \(color): \(count) points")
        }

        // Verify colors are assigned
        XCTAssertFalse(colorCounts.isEmpty, "Should have colors assigned")

        // Verify color map is populated
        XCTAssertFalse(result.colorMap.isEmpty, "Color map should be populated")
        print("Color map entries: \(result.colorMap.count)")
        for (name, color) in result.colorMap {
            print("  '\(name)' -> \(color)")
        }
    }

    func testTPVolcanoPlotSignificanceGroups() async throws {
        let linkId = CurtainConstants.ExampleData.uniqueId
        let hostname = CurtainConstants.ExampleData.apiUrl

        let (_, json) = try await downloadCurtainData(linkId: linkId, hostname: hostname)

        let service = CurtainDataService()
        try await service.restoreSettings(from: json)

        let appData = AppData()
        appData.dataMap = service.curtainData.dataMap
        appData.differentialForm = service.curtainData.differentialForm
        appData.selectedMap = service.curtainData.selectedMap ?? [:]
        appData.uniprotDB = service.uniprotData.db

        let volcanoService = VolcanoPlotDataService()
        let result = await volcanoService.processVolcanoData(curtainData: appData, settings: service.curtainSettings)

        let pCutoff = service.curtainSettings.pCutoff
        let fcCutoff = service.curtainSettings.log2FCCutoff
        let yLogCutoff = -log10(pCutoff)

        // Count points in each significance quadrant
        var upRegulated = 0      // High FC, significant
        var downRegulated = 0    // Low FC, significant
        var notSignificant = 0   // Not meeting criteria

        for point in result.jsonData {
            guard let x = point["x"] as? Double,
                  let y = point["y"] as? Double else { continue }

            if y >= yLogCutoff {
                if x > fcCutoff {
                    upRegulated += 1
                } else if x < -fcCutoff {
                    downRegulated += 1
                } else {
                    notSignificant += 1
                }
            } else {
                notSignificant += 1
            }
        }

        print("Significance distribution (pCutoff=\(pCutoff), fcCutoff=\(fcCutoff)):")
        print("  Up-regulated (FC > \(fcCutoff), p < \(pCutoff)): \(upRegulated)")
        print("  Down-regulated (FC < -\(fcCutoff), p < \(pCutoff)): \(downRegulated)")
        print("  Not significant: \(notSignificant)")

        // Verify we have data in expected ranges
        XCTAssertGreaterThan(result.jsonData.count, 0, "Should have data points")
    }

    // MARK: - Selection/Annotation Tests

    func testTPDatasetSelectionHandling() async throws {
        let linkId = CurtainConstants.ExampleData.uniqueId
        let hostname = CurtainConstants.ExampleData.apiUrl

        let (_, json) = try await downloadCurtainData(linkId: linkId, hostname: hostname)

        let service = CurtainDataService()
        try await service.restoreSettings(from: json)

        // Check if there are pre-existing selections in the data
        let selectedMap = service.curtainData.selectedMap ?? [:]

        print("Pre-existing selections in TP data: \(selectedMap.count) proteins")

        if !selectedMap.isEmpty {
            // Show first few selections
            for (proteinId, selections) in selectedMap.prefix(5) {
                let activeSelections = selections.filter { $0.value }.map { $0.key }
                if !activeSelections.isEmpty {
                    print("  \(proteinId): \(activeSelections)")
                }
            }
        }

        // Simulate adding a selection
        var mutableSelectedMap = selectedMap
        let testProteinId = "Q2M2I8"  // AAK1
        let testSelectionName = "Test Selection (1)"

        if mutableSelectedMap[testProteinId] == nil {
            mutableSelectedMap[testProteinId] = [:]
        }
        mutableSelectedMap[testProteinId]?[testSelectionName] = true

        // Process volcano data with the new selection
        let appData = AppData()
        appData.dataMap = service.curtainData.dataMap
        appData.differentialForm = service.curtainData.differentialForm
        appData.selectedMap = mutableSelectedMap
        appData.uniprotDB = service.uniprotData.db

        // Update color map for the new selection
        var settings = service.curtainSettings
        settings.colorMap[testSelectionName] = "#FF0000"  // Red

        let volcanoService = VolcanoPlotDataService()
        let result = await volcanoService.processVolcanoData(curtainData: appData, settings: settings)

        // Find the test protein and verify it has the selection color
        let testPoint = result.jsonData.first { ($0["id"] as? String) == testProteinId }
        if let point = testPoint {
            let selections = point["selections"] as? [String] ?? []
            let colors = point["colors"] as? [String] ?? []
            let primaryColor = point["color"] as? String

            print("Test protein \(testProteinId) after selection:")
            print("  selections: \(selections)")
            print("  colors: \(colors)")
            print("  primaryColor: \(primaryColor ?? "nil")")

            XCTAssertTrue(selections.contains(testSelectionName), "Should have test selection")
            XCTAssertEqual(primaryColor, "#FF0000", "Should have red color from selection")
        }
    }

    // MARK: - PTM Volcano Plot Tests

    func testPTMVolcanoPlotDataGeneration() async throws {
        let linkId = CurtainConstants.ExamplePTMData.uniqueId
        let hostname = CurtainConstants.ExamplePTMData.apiUrl

        let (_, json) = try await downloadCurtainData(linkId: linkId, hostname: hostname)

        let service = CurtainDataService()
        try await service.restoreSettings(from: json)

        let appData = AppData()
        appData.dataMap = service.curtainData.dataMap
        appData.differentialForm = service.curtainData.differentialForm
        appData.selectedMap = service.curtainData.selectedMap ?? [:]
        appData.uniprotDB = service.uniprotData.db

        let volcanoService = VolcanoPlotDataService()
        let result = await volcanoService.processVolcanoData(curtainData: appData, settings: service.curtainSettings)

        XCTAssertFalse(result.jsonData.isEmpty, "PTM Volcano plot should have data points")
        print("PTM Volcano plot generated \(result.jsonData.count) data points")

        // Verify PTM-specific fields in data points
        var pointsWithAccession = 0
        var pointsWithPosition = 0

        for point in result.jsonData {
            if let accession = point["accession"] as? String, !accession.isEmpty {
                pointsWithAccession += 1
            }
            if let position = point["position"] as? String, !position.isEmpty {
                pointsWithPosition += 1
            }
        }

        print("PTM data points with accession: \(pointsWithAccession)")
        print("PTM data points with position: \(pointsWithPosition)")

        // Show sample PTM data points
        for point in result.jsonData.prefix(3) {
            print("Sample PTM point:")
            print("  id: \(point["id"] ?? "nil")")
            print("  accession: \(point["accession"] ?? "nil")")
            print("  position: \(point["position"] ?? "nil")")
            print("  x: \(point["x"] ?? "nil")")
            print("  y: \(point["y"] ?? "nil")")
        }
    }

    // MARK: - Database Storage and Retrieval Tests

    func testTPDataStorageAndQueryCorrectness() async throws {
        let linkId = CurtainConstants.ExampleData.uniqueId
        let hostname = CurtainConstants.ExampleData.apiUrl

        let (_, json) = try await downloadCurtainData(linkId: linkId, hostname: hostname)

        guard let curtainData = CurtainData.fromJSON(json) else {
            XCTFail("Failed to parse CurtainData")
            return
        }

        // Use a unique test linkId to avoid conflicts
        let testLinkId = "test-correctness-\(UUID().uuidString)"
        let service = ProteomicsDataService.shared

        defer {
            service.clearDatabaseForLinkId(testLinkId)
        }

        // Store data
        try service.buildProteomicsDataIfNeeded(
            linkId: testLinkId,
            rawTsv: json["raw"] as? String,
            processedTsv: json["processed"] as? String,
            rawForm: curtainData.rawForm,
            differentialForm: curtainData.differentialForm,
            curtainData: curtainData,
            onProgress: { _ in }
        )

        // Verify counts
        let processedCount = try service.getProcessedDataCount(linkId: testLinkId)
        let rawCount = try service.getRawDataCount(linkId: testLinkId)
        let uniprotCount = try service.getUniProtEntryCount(linkId: testLinkId)

        print("Stored data counts:")
        print("  Processed: \(processedCount)")
        print("  Raw: \(rawCount)")
        print("  UniProt: \(uniprotCount)")

        XCTAssertGreaterThan(processedCount, 0, "Should have processed data")
        XCTAssertGreaterThan(rawCount, 0, "Should have raw data")
        XCTAssertGreaterThan(uniprotCount, 0, "Should have UniProt entries")

        // Query proteins and verify data structure
        let processedData = try service.getAllProcessedData(linkId: testLinkId)
        XCTAssertGreaterThan(processedData.count, 0, "Should retrieve processed data")

        // Take first protein from actual data
        if let firstProtein = processedData.first {
            print("Sample protein from stored data:")
            print("  primaryId: \(firstProtein.primaryId)")
            print("  geneNames: \(firstProtein.geneNames ?? "nil")")
            print("  foldChange: \(firstProtein.foldChange ?? 0)")
            print("  significant: \(firstProtein.significant ?? 0)")

            // Try to get UniProt data for this protein
            let uniprotData = service.getUniProtDataJson(linkId: testLinkId, accession: firstProtein.primaryId)

            if let upData = uniprotData {
                print("Retrieved UniProt data for \(firstProtein.primaryId):")
                print("  keys: \(upData.keys.sorted().prefix(5))")
            }
        }

        // Count proteins with gene names
        let proteinsWithGenes = processedData.filter { $0.geneNames != nil && !($0.geneNames?.isEmpty ?? true) }.count
        print("Proteins with gene names: \(proteinsWithGenes)/\(processedData.count)")
    }

    // MARK: - Data Transformation Tests

    func testFoldChangeTransformation() async throws {
        let linkId = CurtainConstants.ExampleData.uniqueId
        let hostname = CurtainConstants.ExampleData.apiUrl

        let (_, json) = try await downloadCurtainData(linkId: linkId, hostname: hostname)

        let service = CurtainDataService()
        try await service.restoreSettings(from: json)

        let diffForm = service.curtainData.differentialForm

        print("Fold change transformation settings:")
        print("  transformFC: \(diffForm?.transformFC ?? false)")
        print("  reverseFoldChange: \(diffForm?.reverseFoldChange ?? false)")

        // Get processed data and check fold change values are in expected range
        let appData = AppData()
        appData.dataMap = service.curtainData.dataMap
        appData.differentialForm = service.curtainData.differentialForm

        let volcanoService = VolcanoPlotDataService()
        let result = await volcanoService.processVolcanoData(curtainData: appData, settings: service.curtainSettings)

        // Collect fold change statistics
        var fcValues: [Double] = []
        for point in result.jsonData {
            if let fc = point["x"] as? Double, !fc.isNaN && !fc.isInfinite {
                fcValues.append(fc)
            }
        }

        if !fcValues.isEmpty {
            let minFC = fcValues.min() ?? 0
            let maxFC = fcValues.max() ?? 0
            let avgFC = fcValues.reduce(0, +) / Double(fcValues.count)

            print("Fold change statistics:")
            print("  min: \(minFC)")
            print("  max: \(maxFC)")
            print("  avg: \(avgFC)")
            print("  count: \(fcValues.count)")

            // If transformFC is false, values should be log2 already (typical range -10 to 10)
            // If transformFC is true, original values were transformed
            if !(diffForm?.transformFC ?? false) {
                XCTAssertGreaterThan(minFC, -20, "Log2 FC should be > -20")
                XCTAssertLessThan(maxFC, 20, "Log2 FC should be < 20")
            }
        }
    }

    func testSignificanceTransformation() async throws {
        let linkId = CurtainConstants.ExampleData.uniqueId
        let hostname = CurtainConstants.ExampleData.apiUrl

        let (_, json) = try await downloadCurtainData(linkId: linkId, hostname: hostname)

        let service = CurtainDataService()
        try await service.restoreSettings(from: json)

        let diffForm = service.curtainData.differentialForm

        print("Significance transformation settings:")
        print("  transformSignificant: \(diffForm?.transformSignificant ?? false)")

        let appData = AppData()
        appData.dataMap = service.curtainData.dataMap
        appData.differentialForm = service.curtainData.differentialForm

        let volcanoService = VolcanoPlotDataService()
        let result = await volcanoService.processVolcanoData(curtainData: appData, settings: service.curtainSettings)

        // Collect significance statistics
        var sigValues: [Double] = []
        for point in result.jsonData {
            if let sig = point["y"] as? Double, !sig.isNaN && !sig.isInfinite {
                sigValues.append(sig)
            }
        }

        if !sigValues.isEmpty {
            let minSig = sigValues.min() ?? 0
            let maxSig = sigValues.max() ?? 0

            print("Significance (-log10 p-value) statistics:")
            print("  min: \(minSig)")
            print("  max: \(maxSig)")
            print("  count: \(sigValues.count)")

            // -log10(p-value) should be >= 0 (since p-values are 0-1)
            XCTAssertGreaterThanOrEqual(minSig, 0, "-log10(p) should be >= 0")
        }
    }
}

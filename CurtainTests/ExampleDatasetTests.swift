import XCTest
@testable import Curtain
#if canImport(DuckDB)
import DuckDB
#endif

final class ExampleDatasetTests: XCTestCase {
    
    func testRestoreSettingsFromExampleSubset() async throws {
        // Load the subset JSON from bundle/resources
        // For this environment, we'll read it directly from the file path
        let bundle = Bundle(for: type(of: self))
        let filePath = "/Users/toanphung/iOSProject/Curtain/CurtainTests/Resources/example_subset.json"
        let data = try Data(contentsOf: URL(fileURLWithPath: filePath))
        let jsonObject = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        
        let service = CurtainDataService()
        try await service.restoreSettings(from: jsonObject)
        
        // Verify settings parsing
        XCTAssertEqual(service.curtainSettings.pCutoff, 0.05)
        XCTAssertEqual(service.curtainSettings.log2FCCutoff, 0.6)
        XCTAssertEqual(service.curtainSettings.conditionOrder, ["4Hr-AGB1", "24Hr-AGB1", "4Hr-Cis", "24Hr-Cis"])
        
        // Verify form parsing
        XCTAssertEqual(service.curtainData.differentialForm?.primaryIDs, "Index")
        XCTAssertEqual(service.curtainData.differentialForm?.foldChange, "Difference(Log2): 4HrAGB1/4HrCis")
        
        // Verify processed data
        let processedData = service.curtainData.dataMap?["processedDifferentialData"] as? [[String: Any]]
        XCTAssertNotNil(processedData)
        XCTAssertGreaterThan(processedData?.count ?? 0, 0)
        
        if let firstRow = processedData?.first {
            XCTAssertNotNil(firstRow["Index"])
            XCTAssertNotNil(firstRow["Difference(Log2): 4HrAGB1/4HrCis"])
            XCTAssertNotNil(firstRow["pValue(-Log10): 4HrAGB1/4HrCis"])
        }
    }
    
    func testDataProcessingReconstructsSampleMap() async throws {
        let filePath = "/Users/toanphung/iOSProject/Curtain/CurtainTests/Resources/example_subset.json"
        let data = try Data(contentsOf: URL(fileURLWithPath: filePath))
        let jsonObject = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        
        let service = CurtainDataService()
        try await service.restoreSettings(from: jsonObject)
        
        // The example subset settings.sampleMap is empty in the JSON
        XCTAssertTrue(service.curtainSettings.sampleMap.isEmpty)
        
        // Process data
        let curtainData = service.curtainData
        // Need to wrap in CurtainData struct as used in DetailsView
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
        XCTAssertFalse(processedSettings.sampleMap.isEmpty)
        XCTAssertEqual(processedSettings.sampleMap["4Hr-AGB1.01"]?["condition"], "4Hr-AGB1")
        XCTAssertEqual(processedSettings.sampleMap["4Hr-AGB1.01"]?["replicate"], "01")
    }
    
    func testVolcanoPlotDataGeneration() async throws {
        let filePath = "/Users/toanphung/iOSProject/Curtain/CurtainTests/Resources/example_subset.json"
        let data = try Data(contentsOf: URL(fileURLWithPath: filePath))
        let jsonObject = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        
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
        
        XCTAssertFalse(result.jsonData.isEmpty)
        
        // Verify a specific point (e.g. AAK1 which has ID Q2M2I8)
        // Now that Uniprot data is available, it should resolve to the gene name
        let aak1 = result.jsonData.first { $0["id"] as? String == "Q2M2I8" }
        XCTAssertNotNil(aak1)
        XCTAssertEqual(aak1?["gene"] as? String, "AAK1")
        
        // Verify x and y coordinates are correctly extracted
        XCTAssertNotNil(aak1?["x"] as? Double)
        XCTAssertNotNil(aak1?["y"] as? Double)
        
        // Verify colors are assigned
        XCTAssertNotNil(aak1?["color"] as? String)
        XCTAssertFalse((aak1?["colors"] as? [String])?.isEmpty ?? true)
    }
    
    // MARK: - DuckDB Tests (Disabled - migrated to GRDB/SQLite)
    // These tests are commented out as DuckDB has been removed in favor of GRDB/SQLite.
    // See ProteomicsDataService and ProteomicsDataDatabaseManager for the new implementation.

    #if canImport(DuckDB)
    func testDuckDBIngestionWithFullDataset() async throws {
        // Load the full JSON from bundle/resources
        let filePath = "/Users/toanphung/iOSProject/Curtain/CurtainTests/Resources/example_full.json"

        // Skip if file doesn't exist (e.g. CI environment)
        guard FileManager.default.fileExists(atPath: filePath) else {
            print("Skipping testDuckDBIngestionWithFullDataset: example_full.json not found")
            return
        }

        let data = try Data(contentsOf: URL(fileURLWithPath: filePath))
        let jsonObject = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        // Extract raw and processed strings
        let rawTsv = jsonObject["raw"] as? String
        let processedTsv = jsonObject["processed"] as? String

        XCTAssertNotNil(rawTsv, "Raw TSV data should be present")
        XCTAssertNotNil(processedTsv, "Processed TSV data should be present")

        // Ingest into DuckDB
        let linkId = "test_ingestion_\(UUID().uuidString)"
        let dbURL: URL
        do {
            dbURL = try await DuckDBIngestionService.shared.ingestData(
                linkId: linkId,
                rawTsv: rawTsv,
                processedTsv: processedTsv,
                extraData: jsonObject["extraData"] as? [String: Any]
            )
        } catch {
            XCTFail("Ingestion Failed: \(error)")
            throw error
        }

        // Verify DB file exists
        XCTAssertTrue(FileManager.default.fileExists(atPath: dbURL.path))

        // Verify data content via SQL
        try await CurtainDatabaseManager.shared.initializeDatabase(at: dbURL)

        // Check processed_data count
        do {
            let processedCountResult = try await CurtainDatabaseManager.shared.executeQuery("SELECT COUNT(*) FROM processed_data")
            print("Processed Result Row Count: \(processedCountResult.rowCount)")

            if processedCountResult.rowCount > 0 {
                let countVal = processedCountResult[0].cast(to: Int64.self)[0]
                print("Processed Count: \(String(describing: countVal))")
                XCTAssertGreaterThan(countVal ?? 0, 0)
            } else {
                XCTFail("processed_data query returned no rows")
            }
        } catch {
            XCTFail("Query processed_data Failed: \(error)")
        }

        // Cleanup
        await CurtainDatabaseManager.shared.closeDatabase()
        try? FileManager.default.removeItem(at: dbURL)
    }

    func testGeneNameLookupWithDuckDB() async throws {
        // 1. Setup DB
        let filePath = "/Users/toanphung/iOSProject/Curtain/CurtainTests/Resources/example_full.json"
        guard FileManager.default.fileExists(atPath: filePath) else {
            print("Skipping testGeneNameLookupWithDuckDB: example_full.json not found")
            return
        }
        let data = try Data(contentsOf: URL(fileURLWithPath: filePath))
        let jsonObject = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let rawTsv = jsonObject["raw"] as? String
        let processedTsv = jsonObject["processed"] as? String

        let linkId = "test_lookup_\(UUID().uuidString)"
        let dbURL: URL
        do {
            dbURL = try await DuckDBIngestionService.shared.ingestData(
                linkId: linkId,
                rawTsv: rawTsv,
                processedTsv: processedTsv,
                extraData: jsonObject["extraData"] as? [String: Any]
            )
        } catch {
            throw error
        }

        // 2. Setup CurtainData (Struct)
        let service = CurtainDataService()
        try await service.restoreSettings(from: jsonObject)

        let testCurtainData = CurtainData(
            rawForm: CurtainRawForm(
                primaryIDs: service.curtainData.rawForm?.primaryIDs ?? "",
                samples: service.curtainData.rawForm?.samples ?? [],
                log2: service.curtainData.rawForm?.log2 ?? false
            ),
            differentialForm: CurtainDifferentialForm(
                primaryIDs: service.curtainData.differentialForm?.primaryIDs ?? "",
                geneNames: "Gene",
                foldChange: service.curtainData.differentialForm?.foldChange ?? "",
                transformFC: service.curtainData.differentialForm?.transformFC ?? false,
                significant: service.curtainData.differentialForm?.significant ?? "",
                transformSignificant: service.curtainData.differentialForm?.transformSignificant ?? false,
                comparison: service.curtainData.differentialForm?.comparison ?? "",
                comparisonSelect: service.curtainData.differentialForm?.comparisonSelect ?? [],
                reverseFoldChange: service.curtainData.differentialForm?.reverseFoldChange ?? false
            ),
            settings: service.curtainSettings,
            fetchUniprot: false,
            dbPath: dbURL
        )

        // 3. Test ProteinSearchService
        let searchService = ProteinSearchService()
        let expectedGeneName = "AAK1"
        let expectedID = "Q2M2I8"

        // A. Exact Search by Gene Name -> Should return ID
        let searchResultsGene = await searchService.performExactSearch(
            searchTerm: expectedGeneName,
            searchType: .geneName,
            curtainData: testCurtainData
        )

        XCTAssertTrue(searchResultsGene.contains(expectedID), "Searching for gene '\(expectedGeneName)' should return ID '\(expectedID)'")

        // Cleanup
        await CurtainDatabaseManager.shared.closeDatabase()
        try? FileManager.default.removeItem(at: dbURL)
    }
    #endif
}

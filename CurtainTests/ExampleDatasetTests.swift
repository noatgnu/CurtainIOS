import XCTest
@testable import Curtain

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
}

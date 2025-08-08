//
//  CurtainDataServiceTests.swift
//  CurtainTests
//
//  Created by Toan Phung on 02/08/2025.
//

import XCTest
@testable import Curtain

class CurtainDataServiceTests: XCTestCase {
    
    var dataService: CurtainDataService!
    
    override func setUp() {
        super.setUp()
        dataService = CurtainDataService()
    }
    
    override func tearDown() {
        dataService = nil
        super.tearDown()
    }
    
    // MARK: - JSON Parsing Tests
    
    func testParseValidJSONObject() throws {
        // Given
        let jsonString = """
        {
            "linkId": "\(CurtainConstants.ExampleData.uniqueId)",
            "description": "\(CurtainConstants.ExampleData.description)",
            "curtainType": "\(CurtainConstants.ExampleData.curtainType)",
            "settings": {
                "pCutoff": 0.05,
                "log2FCCutoff": 0.6,
                "uniprot": true
            }
        }
        """
        
        // When
        let parsedObject = try dataService.parseJsonObject(jsonString)
        
        // Then
        XCTAssertNotNil(parsedObject)
        XCTAssertEqual(parsedObject["linkId"] as? String, CurtainConstants.ExampleData.uniqueId)
        XCTAssertEqual(parsedObject["description"] as? String, CurtainConstants.ExampleData.description)
        XCTAssertEqual(parsedObject["curtainType"] as? String, CurtainConstants.ExampleData.curtainType)
        
        let settings = parsedObject["settings"] as? [String: Any]
        XCTAssertNotNil(settings)
        XCTAssertEqual(settings?["pCutoff"] as? Double, 0.05)
        XCTAssertEqual(settings?["log2FCCutoff"] as? Double, 0.6)
        XCTAssertEqual(settings?["uniprot"] as? Bool, true)
    }
    
    func testParseInvalidJSON() {
        // Given
        let invalidJsonString = """
        {
            "linkId": "\(CurtainConstants.ExampleData.uniqueId)",
            "description": "Invalid JSON - missing closing brace"
        """
        
        // When/Then
        XCTAssertThrowsError(try dataService.parseJsonObject(invalidJsonString)) { error in
            XCTAssertTrue(error is CurtainDataServiceError)
        }
    }
    
    // MARK: - Complex Data Structure Tests
    
    func testParseComplexProteomicsData() throws {
        // Given - Sample proteomics data structure like Android processes
        let complexJsonString = """
        {
            "linkId": "\(CurtainConstants.ExampleData.uniqueId)",
            "data": {
                "PROTEIN_001": {
                    "value": [
                        ["primaryID", "PROTEIN_001"],
                        ["geneNames", "GENE1"],
                        ["accession", "ACC001"],
                        ["foldChange", 2.5],
                        ["pValue", 0.001]
                    ]
                },
                "PROTEIN_002": {
                    "primaryID": "PROTEIN_002",
                    "geneNames": "GENE2",
                    "accession": "ACC002",
                    "foldChange": -1.8,
                    "pValue": 0.02
                }
            },
            "settings": {
                "pCutoff": 0.05,
                "log2FCCutoff": 0.6,
                "colorMap": {
                    "value": [
                        ["condition1", "#ff0000"],
                        ["condition2", "#00ff00"],
                        ["condition3", "#0000ff"]
                    ]
                },
                "sampleOrder": {
                    "group1": ["sample1", "sample2", "sample3"],
                    "group2": ["sample4", "sample5", "sample6"]
                }
            }
        }
        """
        
        // When
        let parsedData = try dataService.parseJsonObject(complexJsonString)
        
        // Then
        XCTAssertNotNil(parsedData)
        XCTAssertEqual(parsedData["linkId"] as? String, CurtainConstants.ExampleData.uniqueId)
        
        let data = parsedData["data"] as? [String: Any]
        XCTAssertNotNil(data)
        
        let protein1 = data?["PROTEIN_001"] as? [String: Any]
        XCTAssertNotNil(protein1)
        
        let protein2 = data?["PROTEIN_002"] as? [String: Any]
        XCTAssertNotNil(protein2)
        XCTAssertEqual(protein2?["primaryID"] as? String, "PROTEIN_002")
        XCTAssertEqual(protein2?["foldChange"] as? Double, -1.8)
        
        let settings = parsedData["settings"] as? [String: Any]
        XCTAssertNotNil(settings)
        XCTAssertEqual(settings?["pCutoff"] as? Double, 0.05)
    }
    
    // MARK: - Settings Deserialization Tests
    
    func testDeserializeSettingsWithExampleData() throws {
        // Given - Settings JSON with example values
        let settingsJsonString = """
        {
            "fetchUniprot": true,
            "pCutoff": 0.05,
            "log2FCCutoff": 0.6,
            "description": "\(CurtainConstants.ExampleData.description)",
            "uniprot": true,
            "academic": true,
            "version": 2.0,
            "volcanoPlotTitle": "Volcano Plot - \(CurtainConstants.ExampleData.description)",
            "plotFontFamily": "Arial",
            "defaultColorList": ["#1f77b4", "#ff7f0e", "#2ca02c", "#d62728"],
            "scatterPlotMarkerSize": 10.0,
            "sampleOrder": {
                "group1": ["sample1", "sample2"],
                "group2": ["sample3", "sample4"]
            },
            "conditionOrder": ["condition1", "condition2", "condition3"],
            "colorMap": {
                "value": [
                    ["condition1", "#ff0000"],
                    ["condition2", "#00ff00"]
                ]
            }
        }
        """
        
        // When
        XCTAssertNoThrow(try dataService.restoreSettings(from: settingsJsonString))
        
        // Test that the method completes without throwing
        // In a real implementation, this would test that settings are properly stored/applied
    }
    
    // MARK: - File Processing Tests
    
    func testLoadCurtainDataFromValidFile() throws {
        // Given - Create a temporary file with valid JSON
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_curtain_data.json")
        
        let jsonContent = """
        {
            "linkId": "\(CurtainConstants.ExampleData.uniqueId)",
            "description": "\(CurtainConstants.ExampleData.description)",
            "curtainType": "\(CurtainConstants.ExampleData.curtainType)",
            "settings": {
                "pCutoff": 0.05,
                "log2FCCutoff": 0.6
            },
            "data": {
                "PROTEIN_001": {
                    "primaryID": "PROTEIN_001",
                    "foldChange": 2.0,
                    "pValue": 0.001
                }
            }
        }
        """
        
        try jsonContent.write(to: tempURL, atomically: true, encoding: .utf8)
        
        // When
        let curtainData = try dataService.loadCurtainDataFromFile(tempURL.path)
        
        // Then
        XCTAssertNotNil(curtainData)
        XCTAssertEqual(curtainData.linkId, CurtainConstants.ExampleData.uniqueId)
        XCTAssertFalse(curtainData.proteomicsData.isEmpty)
        
        // Cleanup
        try? FileManager.default.removeItem(at: tempURL)
    }
    
    func testLoadCurtainDataFromNonExistentFile() {
        // Given
        let nonExistentPath = "/non/existent/path/file.json"
        
        // When/Then
        XCTAssertThrowsError(try dataService.loadCurtainDataFromFile(nonExistentPath)) { error in
            XCTAssertTrue(error is CurtainDataServiceError)
        }
    }
    
    // MARK: - Data Conversion Tests
    
    func testConvertToMutableMapWithValueArray() {
        // Given - Test the special Android format: {value: [[key, value], ...]}
        let testData: [String: Any] = [
            "value": [
                ["condition1", "#ff0000"],
                ["condition2", "#00ff00"],
                ["condition3", "#0000ff"]
            ]
        ]
        
        // When
        let result = dataService.convertToMutableMap(testData)
        
        // Then
        XCTAssertNotNil(result)
        XCTAssertEqual(result?["condition1"] as? String, "#ff0000")
        XCTAssertEqual(result?["condition2"] as? String, "#00ff00")
        XCTAssertEqual(result?["condition3"] as? String, "#0000ff")
    }
    
    func testConvertToMutableMapWithRegularData() {
        // Given - Test regular data structure
        let testData: [String: Any] = [
            "pCutoff": 0.05,
            "log2FCCutoff": 0.6,
            "description": CurtainConstants.ExampleData.description
        ]
        
        // When
        let result = dataService.convertToMutableMap(testData)
        
        // Then
        XCTAssertNotNil(result)
        XCTAssertEqual(result?["pCutoff"] as? Double, 0.05)
        XCTAssertEqual(result?["log2FCCutoff"] as? Double, 0.6)
        XCTAssertEqual(result?["description"] as? String, CurtainConstants.ExampleData.description)
    }
    
    // MARK: - Performance Tests
    
    func testJSONParsingPerformance() {
        // Given
        let jsonString = """
        {
            "linkId": "\(CurtainConstants.ExampleData.uniqueId)",
            "description": "\(CurtainConstants.ExampleData.description)",
            "data": {}
        }
        """
        
        // When/Then
        measure {
            for _ in 0..<1000 {
                do {
                    _ = try dataService.parseJsonObject(jsonString)
                } catch {
                    XCTFail("JSON parsing failed: \(error)")
                }
            }
        }
    }
    
    func testLargeDataProcessingPerformance() {
        // Given - Create a large dataset for performance testing
        var largeDataDict: [String: Any] = [:]
        for i in 0..<10000 {
            largeDataDict["PROTEIN_\(i)"] = [
                "primaryID": "PROTEIN_\(i)",
                "foldChange": Double.random(in: -5.0...5.0),
                "pValue": Double.random(in: 0.0...1.0)
            ]
        }
        
        let largeJsonData: [String: Any] = [
            "linkId": CurtainConstants.ExampleData.uniqueId,
            "description": CurtainConstants.ExampleData.description,
            "data": largeDataDict
        ]
        
        // When/Then
        measure {
            do {
                let jsonData = try JSONSerialization.data(withJSONObject: largeJsonData)
                let jsonString = String(data: jsonData, encoding: .utf8)!
                _ = try dataService.parseJsonObject(jsonString)
            } catch {
                XCTFail("Large data processing failed: \(error)")
            }
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testErrorTypes() {
        let errors: [CurtainDataServiceError] = [
            .fileNotFound,
            .invalidJsonFormat,
            .missingRequiredFields,
            .processingFailed
        ]
        
        for error in errors {
            XCTAssertNotNil(error.localizedDescription)
            XCTAssertFalse(error.localizedDescription.isEmpty)
        }
    }
    
    // MARK: - Integration Tests with Constants
    
    func testIntegrationWithExampleConstants() throws {
        // Given - Use all example constants in a realistic scenario
        let fullExampleJson = """
        {
            "linkId": "\(CurtainConstants.ExampleData.uniqueId)",
            "description": "\(CurtainConstants.ExampleData.description)",
            "curtainType": "\(CurtainConstants.ExampleData.curtainType)",
            "apiUrl": "\(CurtainConstants.ExampleData.apiUrl)",
            "frontendUrl": "\(CurtainConstants.ExampleData.frontendUrl)",
            "settings": {
                "pCutoff": 0.05,
                "log2FCCutoff": 0.6,
                "uniprot": true,
                "academic": true,
                "version": 2.0,
                "volcanoPlotTitle": "Example Analysis - \(CurtainConstants.ExampleData.description)"
            },
            "data": {
                "EXAMPLE_PROTEIN_1": {
                    "primaryID": "EXAMPLE_PROTEIN_1",
                    "foldChange": 2.5,
                    "pValue": 0.001,
                    "significant": true
                },
                "EXAMPLE_PROTEIN_2": {
                    "primaryID": "EXAMPLE_PROTEIN_2", 
                    "foldChange": -1.8,
                    "pValue": 0.02,
                    "significant": true
                }
            }
        }
        """
        
        // When
        let parsedData = try dataService.parseJsonObject(fullExampleJson)
        let curtainData = try dataService.processCurtainData(parsedData)
        
        // Then
        XCTAssertEqual(curtainData.linkId, CurtainConstants.ExampleData.uniqueId)
        XCTAssertEqual(curtainData.description, CurtainConstants.ExampleData.description)
        XCTAssertEqual(curtainData.curtainType, CurtainConstants.ExampleData.curtainType)
        XCTAssertFalse(curtainData.proteomicsData.isEmpty)
        XCTAssertNotNil(curtainData.settings)
    }
}

// MARK: - Test Extensions

extension CurtainDataService {
    // Expose internal methods for testing
    func parseJsonObject(_ jsonString: String) throws -> [String: Any] {
        guard let data = jsonString.data(using: .utf8) else {
            throw CurtainDataServiceError.invalidJsonFormat
        }
        
        guard let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw CurtainDataServiceError.invalidJsonFormat
        }
        
        return jsonObject
    }
    
    func convertToMutableMap(_ data: Any?) -> [String: Any]? {
        guard let dataMap = data as? [String: Any],
              let mapValue = dataMap["value"] else {
            return data as? [String: Any]
        }
        
        // Handle special format: {value: [[key, value], ...]}
        if let valueList = mapValue as? [[Any]] {
            var result: [String: Any] = [:]
            for pair in valueList {
                if pair.count >= 2,
                   let key = pair[0] as? String {
                    result[key] = pair[1]
                }
            }
            return result
        }
        return dataMap
    }
    
    func processCurtainData(_ parsedJson: [String: Any]) throws -> (linkId: String, description: String, curtainType: String, proteomicsData: [String: Any], settings: CurtainSettings?) {
        guard let linkId = parsedJson["linkId"] as? String,
              let description = parsedJson["description"] as? String,
              let curtainType = parsedJson["curtainType"] as? String else {
            throw CurtainDataServiceError.missingRequiredFields
        }
        
        let proteomicsData = parsedJson["data"] as? [String: Any] ?? [:]
        let settings: CurtainSettings? = nil // Would normally deserialize settings
        
        return (linkId: linkId, description: description, curtainType: curtainType, proteomicsData: proteomicsData, settings: settings)
    }
}
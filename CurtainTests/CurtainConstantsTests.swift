//
//  CurtainConstantsTests.swift
//  CurtainTests
//
//  Created by Toan Phung on 02/08/2025.
//

import XCTest
@testable import Curtain

class CurtainConstantsTests: XCTestCase {
    
    // MARK: - Predefined Hosts Tests
    
    func testPredefinedHostsValues() {
        // Test that predefined hosts match Android values
        XCTAssertEqual(CurtainConstants.PredefinedHosts.celsusBackend, "https://celsus.muttsu.xyz")
        XCTAssertEqual(CurtainConstants.PredefinedHosts.questBackend, "https://curtain-backend.omics.quest")
        XCTAssertEqual(CurtainConstants.PredefinedHosts.proteoFrontend, "https://curtain.proteo.info")
    }
    
    func testCommonHostnamesContainsPredefinedHosts() {
        // Test that common hostnames include the predefined hosts
        XCTAssertTrue(CurtainConstants.commonHostnames.contains(CurtainConstants.PredefinedHosts.celsusBackend))
        XCTAssertTrue(CurtainConstants.commonHostnames.contains(CurtainConstants.PredefinedHosts.questBackend))
        XCTAssertTrue(CurtainConstants.commonHostnames.contains("localhost"))
    }
    
    // MARK: - Example Data Tests
    
    func testExampleDataValues() {
        // Test example data matches Android MainActivity.kt values
        XCTAssertEqual(CurtainConstants.ExampleData.uniqueId, "f4b009f3-ac3c-470a-a68b-55fcadf68d0f")
        XCTAssertEqual(CurtainConstants.ExampleData.apiUrl, "https://celsus.muttsu.xyz/")
        XCTAssertEqual(CurtainConstants.ExampleData.frontendUrl, "https://curtain.proteo.info/")
        XCTAssertEqual(CurtainConstants.ExampleData.description, "Example Proteomics Dataset")
        XCTAssertEqual(CurtainConstants.ExampleData.curtainType, "TP")
    }
    
    func testExampleDataUniqueIdFormat() {
        // Test that example unique ID is a valid UUID format
        let uuid = UUID(uuidString: CurtainConstants.ExampleData.uniqueId)
        XCTAssertNotNil(uuid, "Example unique ID should be a valid UUID format")
    }
    
    func testExampleDataURLsAreValid() {
        // Test that example URLs are valid
        XCTAssertNotNil(URL(string: CurtainConstants.ExampleData.apiUrl))
        XCTAssertNotNil(URL(string: CurtainConstants.ExampleData.frontendUrl))
    }
    
    // MARK: - URL Pattern Tests
    
    func testProteoURLPatternRecognition() {
        // Test valid curtain.proteo.info URLs
        let validURLs = [
            "https://curtain.proteo.info/#/test-link-id",
            "https://curtain.proteo.info/#/f4b009f3-ac3c-470a-a68b-55fcadf68d0f",
            "https://curtain.proteo.info/#/another-dataset"
        ]
        
        for url in validURLs {
            XCTAssertTrue(CurtainConstants.URLPatterns.isProteoURL(url), "Should recognize \(url) as proteo URL")
        }
    }
    
    func testProteoURLPatternRejection() {
        // Test invalid URLs that should not be recognized as proteo URLs
        let invalidURLs = [
            "https://other-site.com/#/test-link-id",
            "https://curtain.proteo.info/without-fragment",
            "https://curtain.proteo.info/",
            "not-a-url",
            "https://curtain-fake.proteo.info/#/test"
        ]
        
        for url in invalidURLs {
            XCTAssertFalse(CurtainConstants.URLPatterns.isProteoURL(url), "Should NOT recognize \(url) as proteo URL")
        }
    }
    
    func testLinkIdExtractionFromProteoURL() {
        let testCases = [
            ("https://curtain.proteo.info/#/test-link-id", "test-link-id"),
            ("https://curtain.proteo.info/#/f4b009f3-ac3c-470a-a68b-55fcadf68d0f", "f4b009f3-ac3c-470a-a68b-55fcadf68d0f"),
            ("https://curtain.proteo.info/#/complex_dataset-123", "complex_dataset-123"),
            ("https://curtain.proteo.info/#/", "")
        ]
        
        for (url, expectedLinkId) in testCases {
            let extractedLinkId = CurtainConstants.URLPatterns.extractLinkIdFromProteoURL(url)
            XCTAssertEqual(extractedLinkId, expectedLinkId, "Failed to extract link ID from \(url)")
        }
    }
    
    func testLinkIdExtractionFromInvalidURL() {
        let invalidURLs = [
            "https://other-site.com/#/test-link-id",
            "https://curtain.proteo.info/without-fragment",
            "not-a-url"
        ]
        
        for url in invalidURLs {
            let extractedLinkId = CurtainConstants.URLPatterns.extractLinkIdFromProteoURL(url)
            XCTAssertNil(extractedLinkId, "Should return nil for invalid URL: \(url)")
        }
    }
    
    // MARK: - Integration Tests with Example Data
    
    func testExampleDataConsistency() {
        // Test that example data components work together
        let apiHost = String(CurtainConstants.ExampleData.apiUrl.dropLast()) // Remove trailing slash
        XCTAssertEqual(apiHost, CurtainConstants.PredefinedHosts.celsusBackend)
        
        let frontendHost = CurtainConstants.ExampleData.frontendUrl.dropLast() // Remove trailing slash
        XCTAssertEqual(String(frontendHost), CurtainConstants.PredefinedHosts.proteoFrontend)
    }
    
    func testExampleProteoURLConstruction() {
        // Test creating a proteo URL with example data
        let constructedURL = "\(CurtainConstants.ExampleData.frontendUrl)#/\(CurtainConstants.ExampleData.uniqueId)"
        
        XCTAssertTrue(CurtainConstants.URLPatterns.isProteoURL(constructedURL))
        
        let extractedLinkId = CurtainConstants.URLPatterns.extractLinkIdFromProteoURL(constructedURL)
        XCTAssertEqual(extractedLinkId, CurtainConstants.ExampleData.uniqueId)
    }
}
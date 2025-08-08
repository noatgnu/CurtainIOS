//
//  CurtainTests.swift
//  CurtainTests
//
//  Created by Toan Phung on 02/08/2025.
//

import Testing
@testable import Curtain

struct CurtainTests {
    
    // MARK: - Example Constants Integration Tests
    
    @Test("Example constants work together properly")
    func exampleConstantsIntegration() async throws {
        // Test UUID format
        let uuid = UUID(uuidString: CurtainConstants.ExampleData.uniqueId)
        #expect(uuid != nil, "Example UUID should be valid")
        
        // Test URL validity
        let apiURL = URL(string: CurtainConstants.ExampleData.apiUrl)
        let frontendURL = URL(string: CurtainConstants.ExampleData.frontendUrl)
        #expect(apiURL != nil, "Example API URL should be valid")
        #expect(frontendURL != nil, "Example frontend URL should be valid")
        
        // Test that predefined hosts are accessible
        #expect(!CurtainConstants.PredefinedHosts.celsusBackend.isEmpty)
        #expect(!CurtainConstants.PredefinedHosts.questBackend.isEmpty)
        #expect(!CurtainConstants.PredefinedHosts.proteoFrontend.isEmpty)
        
        // Test common hostnames array
        #expect(CurtainConstants.commonHostnames.count > 0)
        #expect(CurtainConstants.commonHostnames.contains(CurtainConstants.PredefinedHosts.celsusBackend))
    }
    
    @Test("Example data creates valid curtain entity")
    func exampleDataCreatesValidCurtainEntity() async throws {
        // Test that example constants can create a valid curtain entity
        let curtain = CurtainEntity(
            linkId: CurtainConstants.ExampleData.uniqueId,
            dataDescription: CurtainConstants.ExampleData.description,
            curtainType: CurtainConstants.ExampleData.curtainType,
            sourceHostname: CurtainConstants.ExampleData.apiUrl
        )
        
        #expect(curtain.linkId == CurtainConstants.ExampleData.uniqueId)
        #expect(curtain.dataDescription == CurtainConstants.ExampleData.description)
        #expect(curtain.curtainType == CurtainConstants.ExampleData.curtainType)
        #expect(curtain.sourceHostname == CurtainConstants.ExampleData.apiUrl)
        #expect(curtain.isPinned == false) // Default value
        #expect(curtain.file == nil) // Initially no file
    }
    
    @Test("Proteo URL workflow with example data")
    func proteoURLWorkflowWithExampleData() async throws {
        // Test the complete proteo URL workflow using example data
        let proteoURL = "\(CurtainConstants.ExampleData.frontendUrl)#/\(CurtainConstants.ExampleData.uniqueId)"
        
        // Should be recognized as proteo URL
        #expect(CurtainConstants.URLPatterns.isProteoURL(proteoURL))
        
        // Should extract correct link ID
        let extractedLinkId = CurtainConstants.URLPatterns.extractLinkIdFromProteoURL(proteoURL)
        #expect(extractedLinkId == CurtainConstants.ExampleData.uniqueId)
        
        // Should use correct predefined backend
        let expectedBackend = CurtainConstants.PredefinedHosts.celsusBackend
        let expectedFrontend = CurtainConstants.PredefinedHosts.proteoFrontend
        
        #expect(CurtainConstants.ExampleData.apiUrl.trimmingCharacters(in: CharacterSet(charactersIn: "/")) == expectedBackend)
        #expect(CurtainConstants.ExampleData.frontendUrl.trimmingCharacters(in: CharacterSet(charactersIn: "/")) == expectedFrontend)
    }
    
    // MARK: - Android Compatibility Tests
    
    @Test("iOS constants match Android values exactly")
    func androidEquivalentValues() async throws {
        // Ensure iOS constants match Android values exactly
        
        // From Android MainActivity.kt
        #expect(CurtainConstants.ExampleData.uniqueId == "f4b009f3-ac3c-470a-a68b-55fcadf68d0f")
        #expect(CurtainConstants.ExampleData.apiUrl == "https://celsus.muttsu.xyz/")
        #expect(CurtainConstants.ExampleData.frontendUrl == "https://curtain.proteo.info/")
        
        // From Android AddCurtainDialog.kt
        #expect(CurtainConstants.PredefinedHosts.celsusBackend == "https://celsus.muttsu.xyz")
        #expect(CurtainConstants.PredefinedHosts.questBackend == "https://curtain-backend.omics.quest")
        
        // URL pattern matching
        #expect(CurtainConstants.URLPatterns.proteoHost == "curtain.proteo.info")
    }
    
    @Test("Constants remain immutable")
    func constantsImmutability() async throws {
        // Test that constants are properly immutable (struct-based)
        let originalUniqueId = CurtainConstants.ExampleData.uniqueId
        let originalApiUrl = CurtainConstants.ExampleData.apiUrl
        
        // These should remain constant throughout app lifecycle
        #expect(CurtainConstants.ExampleData.uniqueId == originalUniqueId)
        #expect(CurtainConstants.ExampleData.apiUrl == originalApiUrl)
        
        // Test that arrays are properly populated
        let hostnamesCount = CurtainConstants.commonHostnames.count
        #expect(hostnamesCount > 0)
        #expect(CurtainConstants.commonHostnames.count == hostnamesCount) // Should remain constant
    }
    
    // MARK: - Error Condition Tests
    
    @Test("Error conditions with constants")
    func errorConditionsWithConstants() async throws {
        // Test error conditions using constants
        
        // Test invalid URL extraction
        let invalidURL = "https://invalid-site.com/#/\(CurtainConstants.ExampleData.uniqueId)"
        #expect(!CurtainConstants.URLPatterns.isProteoURL(invalidURL))
        #expect(CurtainConstants.URLPatterns.extractLinkIdFromProteoURL(invalidURL) == nil)
        
        // Test empty/nil cases
        #expect(!CurtainConstants.URLPatterns.isProteoURL(""))
        #expect(CurtainConstants.URLPatterns.extractLinkIdFromProteoURL("") == nil)
        
        // Test malformed proteo URLs
        let malformedURL = "https://curtain.proteo.info/no-fragment"
        #expect(!CurtainConstants.URLPatterns.isProteoURL(malformedURL))
    }
    
    // MARK: - Performance Tests
    
    @Test("Performance with example data", .timeLimit(.seconds(5)))
    func performanceWithExampleData() async throws {
        // Performance test using example constants
        for _ in 0..<1000 {
            // Test rapid constant access
            let linkId = CurtainConstants.ExampleData.uniqueId
            let apiUrl = CurtainConstants.ExampleData.apiUrl
            let description = CurtainConstants.ExampleData.description
            
            // Test URL validation
            let url = URL(string: apiUrl)
            #expect(url != nil)
            
            // Test UUID validation
            let uuid = UUID(uuidString: linkId)
            #expect(uuid != nil)
            
            // Test string operations
            #expect(!description.isEmpty)
        }
    }
}

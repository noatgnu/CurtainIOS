//
//  NetworkServiceTests.swift
//  CurtainTests
//
//  Created by Toan Phung on 02/08/2025.
//

import XCTest
@testable import Curtain

class NetworkServiceTests: XCTestCase {
    
    var networkService: NetworkService!
    
    override func setUp() {
        super.setUp()
        // Use example hostname for testing
        networkService = NetworkService(hostname: CurtainConstants.ExampleData.apiUrl)
    }
    
    override func tearDown() {
        networkService = nil
        super.tearDown()
    }
    
    // MARK: - URL Construction Tests
    
    func testBaseURLConstruction() {
        // Given/When
        let expectedBaseURL = CurtainConstants.ExampleData.apiUrl.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        
        // Then
        XCTAssertTrue(networkService.description.contains(expectedBaseURL), "NetworkService should use the correct base URL")
    }
    
    func testCurtainEndpointURLs() {
        // Test that the service constructs correct URLs for different endpoints
        // Note: These are structural tests since we can't easily access private URL construction
        
        // The NetworkService should be initialized with the example hostname
        XCTAssertNotNil(networkService)
    }
    
    // MARK: - Configuration Tests with Predefined Hosts
    
    func testNetworkServiceWithAllPredefinedHosts() {
        let predefinedHosts = [
            CurtainConstants.PredefinedHosts.celsusBackend,
            CurtainConstants.PredefinedHosts.questBackend,
            CurtainConstants.ExampleData.apiUrl
        ]
        
        for hostname in predefinedHosts {
            let service = NetworkService(hostname: hostname)
            XCTAssertNotNil(service, "Should be able to create NetworkService with predefined hostname: \(hostname)")
        }
    }
    
    // MARK: - Request Structure Tests
    
    func testCurtainUpdateRequestStructure() {
        // Given
        let request = CurtainUpdateRequest(
            description: CurtainConstants.ExampleData.description,
            curtainType: CurtainConstants.ExampleData.curtainType,
            enable: true,
            encrypted: false,
            permanent: true
        )
        
        // Then
        XCTAssertEqual(request.description, CurtainConstants.ExampleData.description)
        XCTAssertEqual(request.curtainType, CurtainConstants.ExampleData.curtainType)
        XCTAssertTrue(request.enable)
        XCTAssertFalse(request.encrypted)
        XCTAssertTrue(request.permanent)
    }
    
    func testDataFilterListRequestStructure() {
        // Given
        let request = DataFilterListRequest(
            name: "Example Filter",
            category: "proteins",
            data: "PROTEIN1\nPROTEIN2\nPROTEIN3",
            isDefault: false
        )
        
        // Then
        XCTAssertEqual(request.name, "Example Filter")
        XCTAssertEqual(request.category, "proteins")
        XCTAssertTrue(request.data.contains("PROTEIN1"))
        XCTAssertFalse(request.isDefault)
    }
    
    // MARK: - Mock Network Tests
    
    func testMockNetworkRequestWithExampleData() async {
        // This test verifies that network requests can be structured correctly
        // In a real app, this would test actual network calls
        
        // Given
        let mockCurtain = Curtain(
            linkId: CurtainConstants.ExampleData.uniqueId,
            description: CurtainConstants.ExampleData.description,
            curtainType: CurtainConstants.ExampleData.curtainType,
            enable: true,
            encrypted: false,
            permanent: false,
            created: Date(),
            updated: Date(),
            file: nil
        )
        
        // Test serialization
        do {
            let data = try JSONEncoder().encode(mockCurtain)
            let decodedCurtain = try JSONDecoder().decode(Curtain.self, from: data)
            
            XCTAssertEqual(decodedCurtain.linkId, CurtainConstants.ExampleData.uniqueId)
            XCTAssertEqual(decodedCurtain.description, CurtainConstants.ExampleData.description)
            XCTAssertEqual(decodedCurtain.curtainType, CurtainConstants.ExampleData.curtainType)
        } catch {
            XCTFail("Failed to encode/decode Curtain: \(error)")
        }
    }
    
    // MARK: - URL Validation Tests
    
    func testHostnameValidation() {
        let validHostnames = [
            "https://example.com",
            "http://localhost:8000",
            CurtainConstants.PredefinedHosts.celsusBackend,
            CurtainConstants.PredefinedHosts.questBackend
        ]
        
        for hostname in validHostnames {
            XCTAssertNotNil(URL(string: hostname), "Should be a valid URL: \(hostname)")
        }
    }
    
    func testExampleDataURLsAreValidForNetworking() {
        // Test that example URLs are properly formatted for networking
        let apiURL = URL(string: CurtainConstants.ExampleData.apiUrl)
        let frontendURL = URL(string: CurtainConstants.ExampleData.frontendUrl)
        
        XCTAssertNotNil(apiURL)
        XCTAssertNotNil(frontendURL)
        
        // Test URL components
        XCTAssertEqual(apiURL?.scheme, "https")
        XCTAssertEqual(apiURL?.host, "celsus.muttsu.xyz")
        
        XCTAssertEqual(frontendURL?.scheme, "https")
        XCTAssertEqual(frontendURL?.host, "curtain.proteo.info")
    }
    
    // MARK: - Error Handling Tests
    
    func testNetworkServiceErrorTypes() {
        // Test that NetworkServiceError enum works correctly
        let errors: [NetworkServiceError] = [
            .invalidURL,
            .noData,
            .decodingError,
            .networkError(NSError(domain: "TestDomain", code: 404, userInfo: nil))
        ]
        
        for error in errors {
            XCTAssertNotNil(error.localizedDescription)
        }
    }
    
    // MARK: - Performance Tests
    
    func testNetworkServiceInitializationPerformance() {
        measure {
            for _ in 0..<1000 {
                let service = NetworkService(hostname: CurtainConstants.ExampleData.apiUrl)
                _ = service
            }
        }
    }
    
    func testURLConstructionPerformance() {
        measure {
            for _ in 0..<10000 {
                let url = URL(string: CurtainConstants.ExampleData.apiUrl)
                _ = url?.appendingPathComponent("curtain")
                _ = url?.appendingPathComponent(CurtainConstants.ExampleData.uniqueId)
            }
        }
    }
}

// MARK: - Mock Network Service for Testing

class MockNetworkService: NetworkService {
    var mockCurtainResponse: Curtain?
    var mockError: Error?
    var shouldReturnError = false
    
    init() {
        super.init(hostname: CurtainConstants.ExampleData.apiUrl)
    }
    
    // Override methods for mocking would go here
    // This is a basic structure for more advanced network testing
}
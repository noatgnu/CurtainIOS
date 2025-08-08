//
//  CurtainViewModelTests.swift
//  CurtainTests
//
//  Created by Toan Phung on 02/08/2025.
//

import XCTest
import SwiftData
@testable import Curtain

@MainActor
class CurtainViewModelTests: XCTestCase {
    
    var viewModel: CurtainViewModel!
    var mockRepository: MockCurtainRepository!
    var mockDataService: MockCurtainDataService!
    
    override func setUp() {
        super.setUp()
        mockRepository = MockCurtainRepository()
        mockDataService = MockCurtainDataService()
        viewModel = CurtainViewModel(
            curtainRepository: mockRepository,
            curtainDataService: mockDataService
        )
    }
    
    override func tearDown() {
        viewModel = nil
        mockRepository = nil
        mockDataService = nil
        super.tearDown()
    }
    
    // MARK: - Example Data Loading Tests
    
    func testLoadExampleCurtain() async {
        // Given
        let expectedCurtain = CurtainEntity(
            linkId: CurtainConstants.ExampleData.uniqueId,
            dataDescription: CurtainConstants.ExampleData.description,
            curtainType: CurtainConstants.ExampleData.curtainType,
            sourceHostname: CurtainConstants.ExampleData.apiUrl
        )
        mockRepository.mockFetchResult = expectedCurtain
        
        // When
        await viewModel.loadExampleCurtain()
        
        // Then
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.error)
        XCTAssertEqual(mockRepository.lastFetchLinkId, CurtainConstants.ExampleData.uniqueId)
        XCTAssertEqual(mockRepository.lastFetchHostname, CurtainConstants.ExampleData.apiUrl)
        XCTAssertEqual(mockRepository.lastFetchFrontendURL, CurtainConstants.ExampleData.frontendUrl)
    }
    
    func testLoadExampleCurtainWithError() async {
        // Given
        mockRepository.shouldFailFetch = true
        
        // When
        await viewModel.loadExampleCurtain()
        
        // Then
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNotNil(viewModel.error)
        XCTAssertTrue(viewModel.error!.contains("Failed to load example curtain"))
    }
    
    // MARK: - Proteo URL Handling Tests
    
    func testHandleValidProteoURL() async {
        // Given
        let linkId = "test-dataset-123"
        let proteoURL = "https://curtain.proteo.info/#/\(linkId)"
        let expectedCurtain = CurtainEntity(
            linkId: linkId,
            dataDescription: "Test Dataset",
            curtainType: "TP",
            sourceHostname: CurtainConstants.PredefinedHosts.celsusBackend
        )
        mockRepository.mockFetchResult = expectedCurtain
        
        // When
        await viewModel.handleProteoURL(proteoURL)
        
        // Then
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.error)
        XCTAssertEqual(mockRepository.lastFetchLinkId, linkId)
        XCTAssertEqual(mockRepository.lastFetchHostname, CurtainConstants.PredefinedHosts.celsusBackend)
        XCTAssertEqual(mockRepository.lastFetchFrontendURL, CurtainConstants.PredefinedHosts.proteoFrontend)
    }
    
    func testHandleInvalidProteoURL() async {
        // Given
        let invalidURL = "https://invalid-site.com/#/test"
        
        // When
        await viewModel.handleProteoURL(invalidURL)
        
        // Then
        XCTAssertNotNil(viewModel.error)
        XCTAssertTrue(viewModel.error!.contains("Invalid curtain.proteo.info URL format"))
    }
    
    func testHandleProteoURLWithExampleData() async {
        // Given
        let proteoURL = "https://curtain.proteo.info/#/\(CurtainConstants.ExampleData.uniqueId)"
        let expectedCurtain = CurtainEntity(
            linkId: CurtainConstants.ExampleData.uniqueId,
            dataDescription: CurtainConstants.ExampleData.description,
            curtainType: CurtainConstants.ExampleData.curtainType,
            sourceHostname: CurtainConstants.PredefinedHosts.celsusBackend
        )
        mockRepository.mockFetchResult = expectedCurtain
        
        // When
        await viewModel.handleProteoURL(proteoURL)
        
        // Then
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.error)
        XCTAssertEqual(mockRepository.lastFetchLinkId, CurtainConstants.ExampleData.uniqueId)
    }
    
    // MARK: - Generic Curtain Loading Tests
    
    func testLoadCurtainWithPredefinedHosts() async {
        // Given
        let linkId = "custom-dataset"
        let expectedCurtain = CurtainEntity(
            linkId: linkId,
            dataDescription: "Custom Dataset",
            curtainType: "TP",
            sourceHostname: CurtainConstants.PredefinedHosts.questBackend
        )
        mockRepository.mockFetchResult = expectedCurtain
        
        // When
        await viewModel.loadCurtain(
            linkId: linkId,
            apiUrl: CurtainConstants.PredefinedHosts.questBackend,
            frontendUrl: CurtainConstants.PredefinedHosts.proteoFrontend
        )
        
        // Then
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.error)
        XCTAssertEqual(mockRepository.lastFetchLinkId, linkId)
        XCTAssertEqual(mockRepository.lastFetchHostname, CurtainConstants.PredefinedHosts.questBackend)
        XCTAssertEqual(mockRepository.lastFetchFrontendURL, CurtainConstants.PredefinedHosts.proteoFrontend)
    }
    
    // MARK: - Pagination Tests
    
    func testPaginationMethods() {
        // Given
        viewModel.totalCurtains = 50
        viewModel.curtains = Array(0..<20).map { index in
            CurtainEntity(
                linkId: "test-\(index)",
                dataDescription: "Test Dataset \(index)",
                curtainType: "TP",
                sourceHostname: "localhost"
            )
        }
        
        // Test hasMoreCurtains
        XCTAssertTrue(viewModel.hasMoreCurtains())
        
        // Test getRemainingCurtainCount
        XCTAssertEqual(viewModel.getRemainingCurtainCount(), 30)
        
        // Test getPaginationInfo
        let paginationInfo = viewModel.getPaginationInfo()
        XCTAssertEqual(paginationInfo, "Showing 20 of 50 curtains")
        
        // Test when all curtains are loaded
        viewModel.curtains = Array(0..<50).map { index in
            CurtainEntity(
                linkId: "test-\(index)",
                dataDescription: "Test Dataset \(index)",
                curtainType: "TP",
                sourceHostname: "localhost"
            )
        }
        
        XCTAssertFalse(viewModel.hasMoreCurtains())
        XCTAssertEqual(viewModel.getRemainingCurtainCount(), 0)
        XCTAssertEqual(viewModel.getPaginationInfo(), "Showing all 50 curtains")
    }
    
    // MARK: - Search Tests
    
    func testSearchCurtains() {
        // Given
        viewModel.curtains = [
            CurtainEntity(
                linkId: CurtainConstants.ExampleData.uniqueId,
                dataDescription: CurtainConstants.ExampleData.description,
                curtainType: CurtainConstants.ExampleData.curtainType,
                sourceHostname: CurtainConstants.ExampleData.apiUrl
            ),
            CurtainEntity(
                linkId: "other-dataset",
                dataDescription: "Other Dataset",
                curtainType: "TP",
                sourceHostname: "localhost"
            )
        ]
        
        // Test search by description
        let proteomicsResults = viewModel.searchCurtains("Proteomics")
        XCTAssertEqual(proteomicsResults.count, 1)
        XCTAssertEqual(proteomicsResults.first?.linkId, CurtainConstants.ExampleData.uniqueId)
        
        // Test search by link ID
        let linkIdResults = viewModel.searchCurtains("f4b009f3")
        XCTAssertEqual(linkIdResults.count, 1)
        XCTAssertEqual(linkIdResults.first?.linkId, CurtainConstants.ExampleData.uniqueId)
        
        // Test search by curtain type
        let typeResults = viewModel.searchCurtains("TP")
        XCTAssertEqual(typeResults.count, 2)
        
        // Test empty search
        let emptyResults = viewModel.searchCurtains("")
        XCTAssertEqual(emptyResults.count, 2)
    }
}

// MARK: - Mock Classes

class MockCurtainRepository: CurtainRepository {
    var mockFetchResult: CurtainEntity?
    var shouldFailFetch = false
    var lastFetchLinkId: String?
    var lastFetchHostname: String?
    var lastFetchFrontendURL: String?
    
    init() {
        // Create a mock ModelContext - this won't be used in tests
        let container = try! ModelContainer(for: CurtainEntity.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        super.init(modelContext: container.mainContext)
    }
    
    override func fetchCurtainByLinkIdAndHost(
        linkId: String,
        hostname: String,
        frontendURL: String? = nil
    ) async throws -> CurtainEntity {
        lastFetchLinkId = linkId
        lastFetchHostname = hostname
        lastFetchFrontendURL = frontendURL
        
        if shouldFailFetch {
            throw CurtainRepositoryError.networkError
        }
        
        return mockFetchResult ?? CurtainEntity(
            linkId: linkId,
            dataDescription: "Mock Dataset",
            curtainType: "TP",
            sourceHostname: hostname
        )
    }
    
    override func getAllCurtains() -> [CurtainEntity] {
        return []
    }
    
    override func loadMoreCurtains(offset: Int, limit: Int) throws -> [CurtainEntity] {
        return []
    }
}

class MockCurtainDataService: CurtainDataService {
    var shouldFailRestore = false
    
    override func restoreSettings(from jsonString: String) async throws {
        if shouldFailRestore {
            throw CurtainDataServiceError.invalidJsonFormat
        }
    }
}
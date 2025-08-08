//
//  CurtainRepositoryTests.swift
//  CurtainTests
//
//  Created by Toan Phung on 02/08/2025.
//

import XCTest
import SwiftData
@testable import Curtain

class CurtainRepositoryTests: XCTestCase {
    
    var repository: CurtainRepository!
    var modelContext: ModelContext!
    var container: ModelContainer!
    
    override func setUp() {
        super.setUp()
        
        // Create in-memory container for testing
        do {
            container = try ModelContainer(
                for: CurtainEntity.self, CurtainSiteSettings.self, DataFilterListEntity.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
            modelContext = container.mainContext
            repository = CurtainRepository(modelContext: modelContext)
        } catch {
            XCTFail("Failed to create test container: \(error)")
        }
    }
    
    override func tearDown() {
        repository = nil
        modelContext = nil
        container = nil
        super.tearDown()
    }
    
    // MARK: - Site Settings Tests
    
    func testCreateSiteSettingsWithExampleData() throws {
        // Given
        let siteSettings = CurtainSiteSettings(
            hostname: CurtainConstants.ExampleData.apiUrl,
            description: "Example API Server",
            apiKey: nil,
            isActive: true,
            requiresAuthentication: false
        )
        
        // When
        modelContext.insert(siteSettings)
        try modelContext.save()
        
        // Then
        let fetchedSettings = repository.getAllSiteSettings()
        XCTAssertEqual(fetchedSettings.count, 1)
        XCTAssertEqual(fetchedSettings.first?.hostname, CurtainConstants.ExampleData.apiUrl)
        XCTAssertTrue(fetchedSettings.first?.isActive ?? false)
    }
    
    func testCreateSiteSettingsWithPredefinedHosts() throws {
        // Given
        let predefinedHosts = [
            CurtainConstants.PredefinedHosts.celsusBackend,
            CurtainConstants.PredefinedHosts.questBackend,
            CurtainConstants.PredefinedHosts.proteoFrontend
        ]
        
        // When
        for (index, hostname) in predefinedHosts.enumerated() {
            let siteSettings = CurtainSiteSettings(
                hostname: hostname,
                description: "Predefined host \(index + 1)",
                apiKey: nil,
                isActive: true,
                requiresAuthentication: false
            )
            modelContext.insert(siteSettings)
        }
        try modelContext.save()
        
        // Then
        let fetchedSettings = repository.getAllSiteSettings()
        XCTAssertEqual(fetchedSettings.count, 3)
        
        let hostnames = Set(fetchedSettings.map { $0.hostname })
        XCTAssertTrue(hostnames.contains(CurtainConstants.PredefinedHosts.celsusBackend))
        XCTAssertTrue(hostnames.contains(CurtainConstants.PredefinedHosts.questBackend))
        XCTAssertTrue(hostnames.contains(CurtainConstants.PredefinedHosts.proteoFrontend))
    }
    
    func testGetActiveSiteSettings() throws {
        // Given
        let activeSite = CurtainSiteSettings(
            hostname: CurtainConstants.PredefinedHosts.celsusBackend,
            description: "Active site",
            apiKey: nil,
            isActive: true,
            requiresAuthentication: false
        )
        
        let inactiveSite = CurtainSiteSettings(
            hostname: CurtainConstants.PredefinedHosts.questBackend,
            description: "Inactive site",
            apiKey: nil,
            isActive: false,
            requiresAuthentication: false
        )
        
        modelContext.insert(activeSite)
        modelContext.insert(inactiveSite)
        try modelContext.save()
        
        // When
        let activeSettings = repository.getActiveSiteSettings()
        
        // Then
        XCTAssertEqual(activeSettings.count, 1)
        XCTAssertEqual(activeSettings.first?.hostname, CurtainConstants.PredefinedHosts.celsusBackend)
        XCTAssertTrue(activeSettings.first?.isActive ?? false)
    }
    
    // MARK: - Curtain Entity Tests
    
    func testCreateCurtainWithExampleData() throws {
        // Given
        let siteSettings = CurtainSiteSettings(
            hostname: CurtainConstants.ExampleData.apiUrl,
            description: "Example site",
            apiKey: nil,
            isActive: true,
            requiresAuthentication: false
        )
        modelContext.insert(siteSettings)
        
        let curtain = CurtainEntity(
            linkId: CurtainConstants.ExampleData.uniqueId,
            dataDescription: CurtainConstants.ExampleData.description,
            curtainType: CurtainConstants.ExampleData.curtainType,
            sourceHostname: CurtainConstants.ExampleData.apiUrl
        )
        curtain.siteSettings = siteSettings
        
        // When
        modelContext.insert(curtain)
        try modelContext.save()
        
        // Then
        let fetchedCurtains = repository.getAllCurtains()
        XCTAssertEqual(fetchedCurtains.count, 1)
        
        let fetchedCurtain = fetchedCurtains.first!
        XCTAssertEqual(fetchedCurtain.linkId, CurtainConstants.ExampleData.uniqueId)
        XCTAssertEqual(fetchedCurtain.dataDescription, CurtainConstants.ExampleData.description)
        XCTAssertEqual(fetchedCurtain.curtainType, CurtainConstants.ExampleData.curtainType)
        XCTAssertEqual(fetchedCurtain.sourceHostname, CurtainConstants.ExampleData.apiUrl)
        XCTAssertNotNil(fetchedCurtain.siteSettings)
    }
    
    func testGetCurtainById() throws {
        // Given
        let siteSettings = CurtainSiteSettings(
            hostname: CurtainConstants.ExampleData.apiUrl,
            description: "Example site",
            apiKey: nil,
            isActive: true,
            requiresAuthentication: false
        )
        modelContext.insert(siteSettings)
        
        let curtain = CurtainEntity(
            linkId: CurtainConstants.ExampleData.uniqueId,
            dataDescription: CurtainConstants.ExampleData.description,
            curtainType: CurtainConstants.ExampleData.curtainType,
            sourceHostname: CurtainConstants.ExampleData.apiUrl
        )
        curtain.siteSettings = siteSettings
        modelContext.insert(curtain)
        try modelContext.save()
        
        // When
        let fetchedCurtain = repository.getCurtainById(CurtainConstants.ExampleData.uniqueId)
        
        // Then
        XCTAssertNotNil(fetchedCurtain)
        XCTAssertEqual(fetchedCurtain?.linkId, CurtainConstants.ExampleData.uniqueId)
    }
    
    func testGetCurtainsByHostname() throws {
        // Given
        let celsusSettings = CurtainSiteSettings(
            hostname: CurtainConstants.PredefinedHosts.celsusBackend,
            description: "Celsus site",
            apiKey: nil,
            isActive: true,
            requiresAuthentication: false
        )
        
        let questSettings = CurtainSiteSettings(
            hostname: CurtainConstants.PredefinedHosts.questBackend,
            description: "Quest site",
            apiKey: nil,
            isActive: true,
            requiresAuthentication: false
        )
        
        modelContext.insert(celsusSettings)
        modelContext.insert(questSettings)
        
        let celsusCurtain = CurtainEntity(
            linkId: "celsus-dataset",
            dataDescription: "Dataset from Celsus",
            curtainType: "TP",
            sourceHostname: CurtainConstants.PredefinedHosts.celsusBackend
        )
        celsusCurtain.siteSettings = celsusSettings
        
        let questCurtain = CurtainEntity(
            linkId: "quest-dataset",
            dataDescription: "Dataset from Quest",
            curtainType: "TP",
            sourceHostname: CurtainConstants.PredefinedHosts.questBackend
        )
        questCurtain.siteSettings = questSettings
        
        modelContext.insert(celsusCurtain)
        modelContext.insert(questCurtain)
        try modelContext.save()
        
        // When
        let celsusCurtains = repository.getCurtainsByHostname(CurtainConstants.PredefinedHosts.celsusBackend)
        let questCurtains = repository.getCurtainsByHostname(CurtainConstants.PredefinedHosts.questBackend)
        
        // Then
        XCTAssertEqual(celsusCurtains.count, 1)
        XCTAssertEqual(celsusCurtains.first?.linkId, "celsus-dataset")
        
        XCTAssertEqual(questCurtains.count, 1)
        XCTAssertEqual(questCurtains.first?.linkId, "quest-dataset")
    }
    
    // MARK: - CRUD Operations Tests
    
    func testUpdateCurtainDescription() throws {
        // Given
        let siteSettings = CurtainSiteSettings(
            hostname: CurtainConstants.ExampleData.apiUrl,
            description: "Example site",
            apiKey: nil,
            isActive: true,
            requiresAuthentication: false
        )
        modelContext.insert(siteSettings)
        
        let curtain = CurtainEntity(
            linkId: CurtainConstants.ExampleData.uniqueId,
            dataDescription: CurtainConstants.ExampleData.description,
            curtainType: CurtainConstants.ExampleData.curtainType,
            sourceHostname: CurtainConstants.ExampleData.apiUrl
        )
        curtain.siteSettings = siteSettings
        modelContext.insert(curtain)
        try modelContext.save()
        
        let newDescription = "Updated Example Dataset Description"
        
        // When
        try repository.updateCurtainDescription(CurtainConstants.ExampleData.uniqueId, description: newDescription)
        
        // Then
        let updatedCurtain = repository.getCurtainById(CurtainConstants.ExampleData.uniqueId)
        XCTAssertEqual(updatedCurtain?.dataDescription, newDescription)
    }
    
    func testUpdatePinStatus() throws {
        // Given
        let siteSettings = CurtainSiteSettings(
            hostname: CurtainConstants.ExampleData.apiUrl,
            description: "Example site",
            apiKey: nil,
            isActive: true,
            requiresAuthentication: false
        )
        modelContext.insert(siteSettings)
        
        let curtain = CurtainEntity(
            linkId: CurtainConstants.ExampleData.uniqueId,
            dataDescription: CurtainConstants.ExampleData.description,
            curtainType: CurtainConstants.ExampleData.curtainType,
            sourceHostname: CurtainConstants.ExampleData.apiUrl
        )
        curtain.siteSettings = siteSettings
        curtain.isPinned = false
        modelContext.insert(curtain)
        try modelContext.save()
        
        // When
        try repository.updatePinStatus(CurtainConstants.ExampleData.uniqueId, isPinned: true)
        
        // Then
        let updatedCurtain = repository.getCurtainById(CurtainConstants.ExampleData.uniqueId)
        XCTAssertTrue(updatedCurtain?.isPinned ?? false)
    }
    
    func testDeleteCurtain() throws {
        // Given
        let siteSettings = CurtainSiteSettings(
            hostname: CurtainConstants.ExampleData.apiUrl,
            description: "Example site",
            apiKey: nil,
            isActive: true,
            requiresAuthentication: false
        )
        modelContext.insert(siteSettings)
        
        let curtain = CurtainEntity(
            linkId: CurtainConstants.ExampleData.uniqueId,
            dataDescription: CurtainConstants.ExampleData.description,
            curtainType: CurtainConstants.ExampleData.curtainType,
            sourceHostname: CurtainConstants.ExampleData.apiUrl
        )
        curtain.siteSettings = siteSettings
        modelContext.insert(curtain)
        try modelContext.save()
        
        // Verify it exists
        XCTAssertNotNil(repository.getCurtainById(CurtainConstants.ExampleData.uniqueId))
        
        // When
        try repository.deleteCurtain(CurtainConstants.ExampleData.uniqueId)
        
        // Then
        XCTAssertNil(repository.getCurtainById(CurtainConstants.ExampleData.uniqueId))
        XCTAssertEqual(repository.getAllCurtains().count, 0)
    }
    
    // MARK: - Error Handling Tests
    
    func testDeleteNonExistentCurtain() {
        // When/Then
        XCTAssertThrowsError(try repository.deleteCurtain("non-existent-id")) { error in
            XCTAssertTrue(error is CurtainRepositoryError)
        }
    }
    
    func testUpdateNonExistentCurtain() {
        // When/Then
        XCTAssertThrowsError(try repository.updateCurtainDescription("non-existent-id", description: "New description")) { error in
            XCTAssertTrue(error is CurtainRepositoryError)
        }
    }
}
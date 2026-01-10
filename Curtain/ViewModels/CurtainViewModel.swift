//
//  CurtainViewModel.swift
//  Curtain
//
//  Created by Toan Phung on 02/08/2025.
//

import Foundation
import SwiftData

// MARK: - CurtainViewModel 

@MainActor
@Observable
class CurtainViewModel {
    private var curtainRepository: CurtainRepository
    private let curtainDataService: CurtainDataService
    
    
    // Curtain List State
    var curtains: [CurtainEntity] = []
    private var allCurtains: [CurtainEntity] = []
    private var loadedCurtains: [CurtainEntity] = []
    
    private var currentPage = 0
    private var hasMoreData = true
    private static let pageSize = 10
    private static let initialPageSize = 5
    
    // Loading States
    var isLoading = false
    var isLoadingMore = false
    var isDownloading = false
    
    var downloadProgress = 0
    var downloadSpeed = 0.0
    
    // Error Handling
    var error: String?
    
    // Counts
    var totalCurtains = 0
    
    private var hasBeenSetup = false
    
    init(curtainRepository: CurtainRepository? = nil, curtainDataService: CurtainDataService? = nil) {
        // Use dependency injection or create defaults
        self.curtainDataService = curtainDataService ?? CurtainDataService()
        
        // For curtainRepository, we'll set it up in onAppear to use proper ModelContext
        if let repository = curtainRepository {
            self.curtainRepository = repository
            hasBeenSetup = true
            loadCurtains()
        } else {
            // Create a temporary repository - will be replaced in setupWithModelContext
            do {
                let schema = Schema([
                    CurtainEntity.self,
                    CurtainSiteSettings.self,
                    DataFilterListEntity.self
                ])
                let modelContainer = try ModelContainer(for: schema)
                let tempModelContext = ModelContext(modelContainer)
                self.curtainRepository = CurtainRepository(modelContext: tempModelContext)
            } catch {
                // Create minimal repository to prevent crashes
                fatalError("Unable to initialize CurtainViewModel")
            }
        }
    }
    
    /// Setup the ViewModel with the proper ModelContext from environment
    func setupWithModelContext(_ modelContext: ModelContext) {
        guard !hasBeenSetup else { 
            return 
        }
        
        self.curtainRepository = CurtainRepository(modelContext: modelContext)
        hasBeenSetup = true
        loadCurtains()
    }
    
    
    func loadCurtains() {
        isLoading = true
        error = nil
        
        // Reset pagination state 
        currentPage = 0
        hasMoreData = true
        allCurtains.removeAll()
        loadedCurtains.removeAll()
        
        // Get all curtains from repository
        allCurtains = curtainRepository.getAllCurtains()
        totalCurtains = allCurtains.count

        // Load initial page
        loadInitialPage()

        // Database ready for user to add data via + button

        isLoading = false
    }
    
    private func loadInitialPage() {
        let initialCurtains = Array(allCurtains.prefix(Self.initialPageSize))
        loadedCurtains.removeAll()
        loadedCurtains.append(contentsOf: initialCurtains)
        curtains = loadedCurtains
        
        hasMoreData = allCurtains.count > Self.initialPageSize
    }
    
    func loadMoreCurtains() {
        guard !isLoadingMore && hasMoreData else { return }
        
        isLoadingMore = true
        
        Task {
            defer { isLoadingMore = false }

            currentPage += 1
            let startIndex = Self.initialPageSize + (currentPage - 1) * Self.pageSize
            let endIndex = min(startIndex + Self.pageSize, allCurtains.count)

            guard startIndex < allCurtains.count else {
                hasMoreData = false
                return
            }

            let newCurtains = Array(allCurtains[startIndex..<endIndex])
            loadedCurtains.append(contentsOf: newCurtains)
            curtains = loadedCurtains

            hasMoreData = loadedCurtains.count < allCurtains.count
        }
    }
    
    func getPaginationInfo() -> String {
        return "Showing \(loadedCurtains.count) of \(allCurtains.count) curtains"
    }
    
    
    /// Downloads the curtain data when a user clicks on a curtain item
    /// Shows progress updates during the download
    func downloadCurtainData(_ curtain: CurtainEntity) async throws -> String {
        isDownloading = true
        downloadProgress = 0
        downloadSpeed = 0.0
        error = nil
        
        do {
            // Download the curtain data with progress tracking 
            let result = try await curtainRepository.downloadCurtainData(
                linkId: curtain.linkId,
                hostname: curtain.sourceHostname,
                progressCallback: { [weak self] progress, speed in
                    Task { @MainActor in
                        self?.downloadProgress = progress
                        self?.downloadSpeed = speed
                    }
                }
            )
            
            isDownloading = false
            return result
            
        } catch {
            isDownloading = false
            downloadSpeed = 0.0
            self.error = error.localizedDescription
            throw error
        }
    }
    
    /// Deletes the existing curtain file and redownloads the data
    /// Shows progress updates during the download
    func redownloadCurtainData(_ curtain: CurtainEntity) async throws -> String {
        isDownloading = true
        downloadProgress = 0
        downloadSpeed = 0.0
        error = nil
        
        do {
            // Delete old file if it exists 
            if let filePath = curtain.file {
                try? FileManager.default.removeItem(atPath: filePath)
            }
            
            // Download the curtain data with progress tracking and force download
            let result = try await curtainRepository.downloadCurtainData(
                linkId: curtain.linkId,
                hostname: curtain.sourceHostname,
                progressCallback: { [weak self] progress, speed in
                    Task { @MainActor in
                        self?.downloadProgress = progress
                        self?.downloadSpeed = speed
                    }
                },
                forceDownload: true
            )
            
            isDownloading = false
            return result
            
        } catch {
            isDownloading = false
            downloadSpeed = 0.0
            self.error = error.localizedDescription
            throw error
        }
    }
    
    // MARK: - Data Processing Methods
    
    /// Loads and processes curtain data using CurtainDataService
    func loadAndProcessCurtainData(_ curtain: CurtainEntity) async throws {
        guard let filePath = curtain.file else {
            throw CurtainViewModelError.noDataFile
        }
        
        // Read the JSON file
        let jsonString = try String(contentsOfFile: filePath, encoding: .utf8)
        
        // Process using CurtainDataService 
        try await curtainDataService.restoreSettings(from: jsonString)
        
    }
    
    // MARK: - CRUD Operations
    
    func updateCurtainDescription(_ curtain: CurtainEntity, description: String) {
        do {
            try curtainRepository.updateCurtainDescription(curtain.linkId, description: description)
            loadCurtains() // Refresh list
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    func updatePinStatus(_ curtain: CurtainEntity, isPinned: Bool) {
        do {
            try curtainRepository.updatePinStatus(curtain.linkId, isPinned: isPinned)
            loadCurtains() // Refresh list
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    func deleteCurtain(_ curtain: CurtainEntity) {
        do {
            try curtainRepository.deleteCurtain(curtain.linkId)
            loadCurtains() // Refresh list
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    // MARK: - Network Operations
    
    func fetchCurtainByLinkId(linkId: String, hostname: String, frontendURL: String? = nil) async {
        isLoading = true
        error = nil
        
        do {
            _ = try await curtainRepository.fetchCurtainByLinkIdAndHost(
                linkId: linkId,
                hostname: hostname,
                frontendURL: frontendURL
            )
            loadCurtains() // Refresh list after fetch
        } catch {
            self.error = error.localizedDescription
            isLoading = false
        }
    }
    
    func createCurtainEntry(linkId: String, hostname: String, frontendURL: String? = nil, description: String = "") async {
        isLoading = true
        error = nil

        do {
            _ = try await curtainRepository.createCurtainEntry(
                linkId: linkId,
                hostname: hostname,
                frontendURL: frontendURL,
                description: description
            )
            loadCurtains() // Refresh list after creation
        } catch {
            self.error = error.localizedDescription
            isLoading = false
        }
    }

    /// Create a CurtainEntity from DOI session data
    /// The session data is already loaded, so we save it to a file and create the entity
    func createCurtainFromDOISession(sessionData: [String: Any], doi: String, description: String = "") async throws -> CurtainEntity {
        // Generate a unique linkId for this DOI session
        let linkId = "doi-\(UUID().uuidString)"

        // Save session data to file
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let curtainDataDir = documentsPath.appendingPathComponent("CurtainData", isDirectory: true)
        try? FileManager.default.createDirectory(at: curtainDataDir, withIntermediateDirectories: true)

        let filePath = curtainDataDir.appendingPathComponent("\(linkId).json").path
        let jsonData = try JSONSerialization.data(withJSONObject: sessionData, options: .prettyPrinted)
        FileManager.default.createFile(atPath: filePath, contents: jsonData)

        // Create CurtainEntity with DOI metadata
        let descriptionText = description.isEmpty ? "DOI: \(doi)" : description
        let curtainEntity = CurtainEntity(
            linkId: linkId,
            created: Date(),
            updated: Date(),
            file: filePath,
            dataDescription: descriptionText,
            enable: true,
            curtainType: "DOI",
            sourceHostname: "doi.org",
            frontendURL: nil,
            isPinned: false
        )

        // Ensure site settings exist for doi.org
        if curtainRepository.getSiteSettingsByHostname("doi.org") == nil {
            let doiSettings = CurtainSiteSettings(
                hostname: "doi.org",
                active: true,
                siteDescription: "DOI Sessions"
            )
            curtainRepository.insertSiteSettings(doiSettings)
        }

        // Insert into database
        curtainRepository.insertCurtain(curtainEntity)

        // Refresh list
        loadCurtains()

        return curtainEntity
    }

    // MARK: - Utility Methods
    
    func cancelDownload() {
        curtainRepository.cancelDownload()
        isDownloading = false
        downloadProgress = 0
        downloadSpeed = 0.0
    }
    
    func clearError() {
        error = nil
    }
    
    func getPinnedCurtains() -> [CurtainEntity] {
        return curtainRepository.getPinnedCurtains()
    }
    
    // MARK: - Filtering and Search
    
    func getCurtainsByHostname(_ hostname: String) -> [CurtainEntity] {
        return curtainRepository.getCurtainsByHostname(hostname)
    }
    
    func searchCurtains(_ searchText: String) -> [CurtainEntity] {
        guard !searchText.isEmpty else { return curtains }
        
        return curtains.filter { curtain in
            curtain.dataDescription.localizedCaseInsensitiveContains(searchText) ||
            curtain.linkId.localizedCaseInsensitiveContains(searchText) ||
            curtain.curtainType.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    
    func hasMoreCurtains() -> Bool {
        return curtains.count < totalCurtains
    }
    
    func getRemainingCurtainCount() -> Int {
        return max(0, totalCurtains - curtains.count)
    }
    
    
    func loadExampleCurtain() async {
        isLoading = true
        error = nil
        
        do {
            _ = try await curtainRepository.fetchCurtainByLinkIdAndHost(
                linkId: CurtainConstants.ExampleData.uniqueId,
                hostname: CurtainConstants.ExampleData.apiUrl,
                frontendURL: CurtainConstants.ExampleData.frontendUrl
            )
            
            await MainActor.run {
                loadCurtains() // Refresh the list
                isLoading = false
            }
        } catch {
            await MainActor.run {
                self.error = "Failed to load example curtain: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
    
    func loadCurtain(linkId: String, apiUrl: String, frontendUrl: String? = nil) async {
        isLoading = true
        error = nil
        
        do {
            _ = try await curtainRepository.fetchCurtainByLinkIdAndHost(
                linkId: linkId,
                hostname: apiUrl,
                frontendURL: frontendUrl
            )
            
            await MainActor.run {
                loadCurtains() // Refresh the list
                isLoading = false
            }
        } catch {
            await MainActor.run {
                self.error = "Failed to load curtain: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
    
    func handleProteoURL(_ urlString: String) async {
        guard CurtainConstants.URLPatterns.isProteoURL(urlString),
              let linkId = CurtainConstants.URLPatterns.extractLinkIdFromProteoURL(urlString) else {
            error = "Invalid curtain.proteo.info URL format"
            return
        }
        
        // Use predefined backend and frontend URLs for curtain.proteo.info
        await loadCurtain(
            linkId: linkId,
            apiUrl: CurtainConstants.PredefinedHosts.celsusBackend,
            frontendUrl: CurtainConstants.PredefinedHosts.proteoFrontend
        )
    }
    
    /// Get active site settings (exposed for sync operations)
    func getActiveSiteSettings() -> [CurtainSiteSettings] {
        return curtainRepository.getActiveSiteSettings()
    }
    
}

// MARK: - ViewModel Errors

enum CurtainViewModelError: Error, LocalizedError {
    case noDataFile
    case processingFailed
    case downloadFailed
    
    var errorDescription: String? {
        switch self {
        case .noDataFile:
            return "No data file available for this curtain"
        case .processingFailed:
            return "Failed to process curtain data"
        case .downloadFailed:
            return "Failed to download curtain data"
        }
    }
}
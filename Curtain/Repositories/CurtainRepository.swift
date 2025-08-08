//
//  CurtainRepository.swift
//  Curtain
//
//  Created by Toan Phung on 02/08/2025.
//

import Foundation
import SwiftData

// MARK: - CurtainRepository (Direct port from Android CurtainRepository.kt)

@Observable
class CurtainRepository {
    private let modelContext: ModelContext
    private let networkManager: MultiHostNetworkManager
    private let downloadClient: DownloadClient
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.networkManager = MultiHostNetworkManager.shared
        self.downloadClient = DownloadClient.shared
    }
    
    // MARK: - Thread Safety Helper
    
    /// Ensures all ModelContext operations are performed on the main thread
    private func performDatabaseOperation<T>(_ operation: () -> T) -> T {
        if Thread.isMainThread {
            return operation()
        } else {
            return DispatchQueue.main.sync {
                return operation()
            }
        }
    }
    
    // MARK: - Local Database Operations (Direct from Android)
    
    func getAllCurtains() -> [CurtainEntity] {
        return performDatabaseOperation {
            let descriptor = FetchDescriptor<CurtainEntity>(
                sortBy: [SortDescriptor(\.updated, order: .reverse)]
            )
            return (try? modelContext.fetch(descriptor)) ?? []
        }
    }
    
    func getCurtainsByHostname(_ hostname: String) -> [CurtainEntity] {
        return performDatabaseOperation {
            let predicate = #Predicate<CurtainEntity> { curtain in
                curtain.sourceHostname == hostname
            }
            let descriptor = FetchDescriptor<CurtainEntity>(predicate: predicate)
            return (try? modelContext.fetch(descriptor)) ?? []
        }
    }
    
    func getAllSiteSettings() -> [CurtainSiteSettings] {
        return performDatabaseOperation {
            let descriptor = FetchDescriptor<CurtainSiteSettings>()
            return (try? modelContext.fetch(descriptor)) ?? []
        }
    }
    
    func getActiveSiteSettings() -> [CurtainSiteSettings] {
        return performDatabaseOperation {
            let predicate = #Predicate<CurtainSiteSettings> { settings in
                settings.active == true
            }
            let descriptor = FetchDescriptor<CurtainSiteSettings>(predicate: predicate)
            return (try? modelContext.fetch(descriptor)) ?? []
        }
    }
    
    func getCurtainById(_ linkId: String) -> CurtainEntity? {
        return performDatabaseOperation {
            let predicate = #Predicate<CurtainEntity> { curtain in
                curtain.linkId == linkId
            }
            let descriptor = FetchDescriptor<CurtainEntity>(predicate: predicate)
            return try? modelContext.fetch(descriptor).first
        }
    }
    
    func getSiteSettingsByHostname(_ hostname: String) -> CurtainSiteSettings? {
        return performDatabaseOperation {
            let predicate = #Predicate<CurtainSiteSettings> { settings in
                settings.hostname == hostname
            }
            let descriptor = FetchDescriptor<CurtainSiteSettings>(predicate: predicate)
            return try? modelContext.fetch(descriptor).first
        }
    }
    
    // MARK: - Network Sync Operations (From Android)
    
    func syncCurtains(hostname: String) async throws -> [CurtainEntity] {
        let curtains = try await networkManager.getAllCurtains(hostname: hostname)
        
        let entities = curtains.map { curtain in
            curtain.toCurtainEntity(hostname: hostname)
        }
        
        // Insert all entities on main thread
        await MainActor.run {
            for entity in entities {
                modelContext.insert(entity)
            }
            
            try? modelContext.save()
        }
        return entities
    }
    
    func fetchCurtainByLinkIdAndHost(linkId: String, hostname: String, frontendURL: String? = nil) async throws -> CurtainEntity {
        // First check if we already have this curtain stored locally (like Android)
        if let localCurtain = getCurtainById(linkId) {
            return localCurtain
        }
        
        // Otherwise fetch from the network
        let curtain = try await networkManager.getCurtainByLinkId(hostname: hostname, linkId: linkId)
        
        // Check and store the site settings BEFORE inserting the curtain (foreign key constraint)
        try await ensureSiteSettingsExist(hostname: hostname)
        
        // Convert API response to entity
        var curtainEntity = curtain.toCurtainEntity(hostname: hostname)
        curtainEntity.frontendURL = frontendURL
        
        // Insert the curtain after site settings have been created
        await MainActor.run {
            modelContext.insert(curtainEntity)
            try? modelContext.save()
        }
        
        return curtainEntity
    }
    
    func createCurtainEntry(
        linkId: String,
        hostname: String,
        frontendURL: String? = nil,
        description: String = ""
    ) async throws -> CurtainEntity {
        // Check if curtain already exists (like Android)
        if let existingCurtain = getCurtainById(linkId) {
            return existingCurtain
        }
        
        // Ensure site settings exist (foreign key constraint)
        try await ensureSiteSettingsExist(hostname: hostname)
        
        // Create curtain entity without network data (like Android)
        let curtainEntity = CurtainEntity(
            linkId: linkId,
            created: Date(),
            updated: Date(),
            file: nil, // Will be populated when downloaded
            dataDescription: description.isEmpty ? "Manual import" : description,
            enable: true,
            curtainType: "TP",
            sourceHostname: hostname,
            frontendURL: frontendURL,
            isPinned: false
        )
        
        // Insert into database on main thread
        await MainActor.run {
            modelContext.insert(curtainEntity)
            try? modelContext.save()
        }
        
        return curtainEntity
    }
    
    // MARK: - Download Operations (Based on Android download logic)
    
    func downloadCurtainData(
        linkId: String,
        hostname: String,
        token: String? = nil,
        progressCallback: ((Int, Double) -> Void)? = nil,
        forceDownload: Bool = false
    ) async throws -> String {
        
        progressCallback?(0, 0.0) // Start at 0%
        
        // Check if we already have the file locally and not forcing a redownload (like Android)
        let localFilePath = getLocalFilePath(linkId: linkId)
        if !forceDownload && FileManager.default.fileExists(atPath: localFilePath) {
            // If file exists, make sure the entity has the file path set
            try await updateCurtainEntityWithLocalFilePath(linkId: linkId, filePath: localFilePath)
            progressCallback?(100, 0.0) // Already complete
            return localFilePath
        }
        
        // Build download endpoint like Android: "{linkId}/download/token={token}"
        let downloadEndpoint = if let token = token {
            "\(linkId)/download/token=\(token)"
        } else {
            "\(linkId)/download/token="
        }
        
        progressCallback?(10, 0.0) // API request started
        let responseData = try await networkManager.downloadCurtain(hostname: hostname, downloadPath: downloadEndpoint)
        
        progressCallback?(20, 0.0)
        let responseString = String(data: responseData, encoding: .utf8) ?? ""
        var filePath: String? = nil
        
        do {
            // Try to parse as JSON to check for "url" field (like Android)
            if let jsonData = responseString.data(using: .utf8),
               let jsonMap = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
               let downloadUrl = jsonMap["url"] as? String {
                
                progressCallback?(30, 0.0)
                
                // Ensure we have an absolute URL (like Android)
                let absoluteUrl: String
                if downloadUrl.hasPrefix("http") {
                    absoluteUrl = downloadUrl // Already an absolute URL
                } else {
                    // In case it's a relative URL, prepend the base URL
                    let baseUrl = hostname.hasSuffix("/") ? hostname : "\(hostname)/"
                    absoluteUrl = baseUrl + downloadUrl
                }
                
                print("CurtainRepository: Using download client for URL: \(absoluteUrl)")
                
                // Download file using DownloadClient (like Android)
                let fileURL = try await downloadClient.downloadFile(
                    from: absoluteUrl,
                    to: getLocalFilePath(linkId: linkId),
                    progressCallback: { progress, speed in
                        // Map progress from 40-90% (like Android)
                        let mappedProgress = min((progress * 50 / 100) + 40, 90)
                        progressCallback?(mappedProgress, speed)
                    }
                )
                
                filePath = fileURL.path
                
            } else {
                // Direct response data (like Android fallback)
                progressCallback?(40, 0.0) // Writing direct response to file
                try responseString.write(toFile: localFilePath, atomically: true, encoding: .utf8)
                progressCallback?(70, 0.0)
                filePath = localFilePath
            }
        } catch {
            // Fallback to raw response (like Android)
            progressCallback?(40, 0.0)
            try responseString.write(toFile: localFilePath, atomically: true, encoding: .utf8)
            progressCallback?(70, 0.0)
            filePath = localFilePath
        }
        
        if let filePath = filePath {
            progressCallback?(90, 0.0) // Updating database
            try await updateCurtainEntityWithLocalFilePath(linkId: linkId, filePath: filePath)
            progressCallback?(100, 0.0) // Complete
            return filePath
        }
        
        throw CurtainError.downloadFailed
    }
    
    // MARK: - CRUD Operations (From Android)
    
    func updateCurtainDescription(_ linkId: String, description: String) throws {
        performDatabaseOperation {
            if let curtain = getCurtainById(linkId) {
                curtain.dataDescription = description
                curtain.updated = Date()
                try? modelContext.save()
            }
        }
    }
    
    func updatePinStatus(_ linkId: String, isPinned: Bool) throws {
        performDatabaseOperation {
            if let curtain = getCurtainById(linkId) {
                curtain.isPinned = isPinned
                try? modelContext.save()
            }
        }
    }
    
    func deleteCurtain(_ linkId: String) throws {
        performDatabaseOperation {
            if let curtain = getCurtainById(linkId) {
                // Delete associated local file if it exists (like Android)
                if let filePath = curtain.file {
                    try? FileManager.default.removeItem(atPath: filePath)
                }
                
                // Delete from local database
                modelContext.delete(curtain)
                try? modelContext.save()
            }
        }
    }
    
    func updateSiteSettings(_ siteSettings: CurtainSiteSettings) throws {
        performDatabaseOperation {
            modelContext.insert(siteSettings)
            try? modelContext.save()
        }
    }
    
    func getPinnedCurtains() -> [CurtainEntity] {
        return performDatabaseOperation {
            let predicate = #Predicate<CurtainEntity> { curtain in
                curtain.isPinned == true
            }
            let descriptor = FetchDescriptor<CurtainEntity>(predicate: predicate)
            return (try? modelContext.fetch(descriptor)) ?? []
        }
    }
    
    // MARK: - Private Helper Methods (Like Android)
    
    private func getLocalFilePath(linkId: String) -> String {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent("\(linkId).json").path
    }
    
    private func updateCurtainEntityWithLocalFilePath(linkId: String, filePath: String) async throws {
        await MainActor.run {
            if let curtain = getCurtainById(linkId),
               curtain.file == nil || curtain.file != filePath {
                curtain.file = filePath
                try? modelContext.save()
            }
        }
    }
    
    private func ensureSiteSettingsExist(hostname: String) async throws {
        await MainActor.run {
            if getSiteSettingsByHostname(hostname) == nil {
                let siteSettings = CurtainSiteSettings(hostname: hostname, active: true)
                modelContext.insert(siteSettings)
                try? modelContext.save()
            }
        }
    }
    
    private func parseCreatedDateToTimestamp(_ createdDateString: String) -> Date {
        // Multiple date format fallbacks (like Android)
        let formatters = [
            ISO8601DateFormatter(),
        ]
        
        for formatter in formatters {
            if let date = formatter.date(from: createdDateString) {
                return date
            }
        }
        
        // Fallback to current time
        return Date()
    }
    
    // MARK: - Download Methods
    
    /// Download curtain data and save to local persistent storage (NOT synced to iCloud)
    func downloadCurtainData(_ curtain: CurtainEntity, progressCallback: @escaping (Double) -> Void) async throws -> String {
        print("🔄 CurtainRepository: Starting download for curtain: \(curtain.linkId)")
        
        guard let hostname = getSiteSettingsByHostname(curtain.sourceHostname) else {
            throw CurtainError.invalidResponse
        }
        
        // Create URL for downloading the curtain data
        let downloadURL = "\(curtain.sourceHostname)/api/curtain/\(curtain.linkId)"
        
        // Create local file path in Documents directory (excludes from iCloud)
        let localFilePath = getSecureLocalFilePath(linkId: curtain.linkId)
        
        do {
            // Download the data using the download client
            let _ = try await downloadClient.downloadFile(
                from: downloadURL,
                to: localFilePath,
                progressCallback: { progress, speed in
                    progressCallback(Double(progress) / 100.0)
                }
            )
            
            // Exclude from iCloud backup to keep it local only
            try excludeFromiCloudBackup(path: localFilePath)
            
            // Update the curtain entity with the file path
            await MainActor.run {
                curtain.file = localFilePath
                try? modelContext.save()
            }
            
            print("✅ CurtainRepository: Download completed, saved to: \(localFilePath)")
            
            return localFilePath
            
        } catch {
            print("❌ CurtainRepository: Download failed: \(error)")
            // Clean up partial file if it exists
            try? FileManager.default.removeItem(atPath: localFilePath)
            throw CurtainError.downloadFailed
        }
    }
    
    /// Get a secure local file path for storing downloaded data
    private func getSecureLocalFilePath(linkId: String) -> String {
        // Use Documents directory which is persistent but not synced to iCloud
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let curtainDataDir = documentsURL.appendingPathComponent("CurtainData", isDirectory: true)
        
        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(at: curtainDataDir, withIntermediateDirectories: true)
        
        return curtainDataDir.appendingPathComponent("\(linkId).json").path
    }
    
    /// Exclude file from iCloud backup to keep it local only
    private func excludeFromiCloudBackup(path: String) throws {
        var url = URL(fileURLWithPath: path)
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        try url.setResourceValues(resourceValues)
        print("🚫 CurtainRepository: Excluded from iCloud backup: \(path)")
    }
    
    /// Update curtain entity with file path and save
    func updateCurtain(_ curtain: CurtainEntity) throws {
        performDatabaseOperation {
            try? modelContext.save()
            print("💾 CurtainRepository: Updated curtain entity: \(curtain.linkId)")
        }
    }
    
    /// Cancels the current download operation
    func cancelDownload() {
        downloadClient.cancelDownload()
    }
}

// MARK: - Extension for Converting API Models to Entities (Like Android toCurtainEntity)

private extension Curtain {
    func toCurtainEntity(hostname: String) -> CurtainEntity {
        return CurtainEntity(
            linkId: self.linkId,
            created: parseCreatedDate(self.created),
            updated: Date(),
            file: nil,
            dataDescription: self.description,
            enable: self.enable,
            curtainType: self.curtainType,
            sourceHostname: hostname
        )
    }
    
    private func parseCreatedDate(_ dateString: String) -> Date {
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: dateString) ?? Date()
    }
}

// MARK: - Repository Errors

enum CurtainError: Error, LocalizedError {
    case invalidResponse
    case downloadFailed
    case entityNotFound
    case saveError
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server"
        case .downloadFailed:
            return "Failed to download curtain data"
        case .entityNotFound:
            return "Curtain entity not found"
        case .saveError:
            return "Failed to save to database"
        }
    }
}
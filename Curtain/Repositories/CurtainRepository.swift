//
//  CurtainRepository.swift
//  Curtain
//
//  Created by Toan Phung on 02/08/2025.
//

import Foundation
import SwiftData

// MARK: - CurtainRepository 

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
    
    // MARK: - Local Database Operations 
    
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
    
    
    func syncCurtains(hostname: String) async throws -> [CurtainEntity] {
        let curtains = try await networkManager.getAllCurtains(hostname: hostname)
        
        let entities = curtains.map { curtain in
            curtain.toCurtainEntity(hostname: hostname)
        }

        // Insert all entities on main thread
        performDatabaseOperation {
            for entity in entities {
                modelContext.insert(entity)
            }

            try? modelContext.save()
        }
        return entities
    }
    
    func fetchCurtainByLinkIdAndHost(linkId: String, hostname: String, frontendURL: String? = nil) async throws -> CurtainEntity {
        // First check if we already have this curtain stored locally
        if let localCurtain = getCurtainById(linkId) {
            return localCurtain
        }

        // Otherwise fetch from the network
        let curtain = try await networkManager.getCurtainByLinkId(hostname: hostname, linkId: linkId)

        // Check and store the site settings BEFORE inserting the curtain (foreign key constraint)
        try await ensureSiteSettingsExist(hostname: hostname)

        // Convert API response to entity
        let curtainEntity = curtain.toCurtainEntity(hostname: hostname, frontendURL: frontendURL)

        // Insert the curtain after site settings have been created
        // Use upsert behavior: delete existing if found, then insert
        return performDatabaseOperation {
            // Double-check for existing entity to prevent duplicates
            // (the initial check might have missed it due to timing/context issues)
            let predicate = #Predicate<CurtainEntity> { c in
                c.linkId == linkId
            }
            let descriptor = FetchDescriptor<CurtainEntity>(predicate: predicate)

            if let existingEntities = try? modelContext.fetch(descriptor), !existingEntities.isEmpty {
                // Already exists, return the existing one instead of inserting duplicate
                print("[CurtainRepository] Entity already exists for linkId: \(linkId), returning existing")
                return existingEntities[0]
            }

            modelContext.insert(curtainEntity)
            try? modelContext.save()
            return curtainEntity
        }
    }
    
    func createCurtainEntry(
        linkId: String,
        hostname: String,
        frontendURL: String? = nil,
        description: String = ""
    ) async throws -> CurtainEntity {
        // Check if curtain already exists
        if let existingCurtain = getCurtainById(linkId) {
            return existingCurtain
        }

        // Ensure site settings exist (foreign key constraint)
        try await ensureSiteSettingsExist(hostname: hostname)

        // Create curtain entity without network data
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

        // Insert into database with duplicate protection
        return performDatabaseOperation {
            // Double-check for existing entity to prevent duplicates
            let predicate = #Predicate<CurtainEntity> { c in
                c.linkId == linkId
            }
            let descriptor = FetchDescriptor<CurtainEntity>(predicate: predicate)

            if let existingEntities = try? modelContext.fetch(descriptor), !existingEntities.isEmpty {
                print("[CurtainRepository] Entity already exists for linkId: \(linkId), returning existing")
                return existingEntities[0]
            }

            modelContext.insert(curtainEntity)
            try? modelContext.save()
            return curtainEntity
        }
    }
    
    func getCurtainSettings(linkId: String) -> CurtainSettingsEntity? {
        return performDatabaseOperation {
            let predicate = #Predicate<CurtainSettingsEntity> { settings in
                settings.linkId == linkId
            }
            let descriptor = FetchDescriptor<CurtainSettingsEntity>(predicate: predicate)
            return try? modelContext.fetch(descriptor).first
        }
    }

    func saveCurtainSettings(linkId: String, settings: CurtainSettings, rawForm: CurtainRawForm, differentialForm: CurtainDifferentialForm) {
        print("[CurtainRepository] saveCurtainSettings called for linkId: \(linkId)")
        performDatabaseOperation {
            // Check if settings already exist
            let predicate = #Predicate<CurtainSettingsEntity> { s in
                s.linkId == linkId
            }
            let descriptor = FetchDescriptor<CurtainSettingsEntity>(predicate: predicate)

            if let existingSettings = try? modelContext.fetch(descriptor).first {
                // Update existing
                print("[CurtainRepository] Deleting existing CurtainSettingsEntity for linkId: \(linkId)")
                modelContext.delete(existingSettings)
            }

            // Create new
            let newSettings = CurtainSettingsEntity(
                linkId: linkId,
                settings: settings,
                rawForm: rawForm,
                differentialForm: differentialForm
            )
            print("[CurtainRepository] Created CurtainSettingsEntity object with linkId: \(newSettings.linkId)")
            print("[CurtainRepository] settingsData size: \(newSettings.settingsData.count) bytes")

            modelContext.insert(newSettings)
            print("[CurtainRepository] Inserted into modelContext")

            do {
                try modelContext.save()
                print("[CurtainRepository] CurtainSettingsEntity saved successfully for linkId: \(linkId)")

                // Immediately verify by fetching ALL entities (no predicate)
                let allDescriptor = FetchDescriptor<CurtainSettingsEntity>()
                let allEntities = try? modelContext.fetch(allDescriptor)
                print("[CurtainRepository] Total CurtainSettingsEntity count after save: \(allEntities?.count ?? -1)")

                // Now try with predicate
                let verifyResults = try? modelContext.fetch(descriptor)
                print("[CurtainRepository] Verification fetch with predicate returned: \(verifyResults?.count ?? -1) results")
                if let first = verifyResults?.first {
                    print("[CurtainRepository] Verification found entity with linkId: \(first.linkId)")
                }
            } catch {
                print("[CurtainRepository] ERROR: Failed to save CurtainSettingsEntity: \(error)")
            }
        }
    }
    
    // MARK: - Dependencies

    private let proteomicsDataService = ProteomicsDataService.shared
    private let proteomicsDataDatabaseManager = ProteomicsDataDatabaseManager.shared
    private let proteinMappingService = ProteinMappingService.shared

    // MARK: - Download Operations
    // Progress mapping for two-level downloads:
    // 0-5%: Initialization
    // 5-40%: First download (API metadata)
    // 40-45%: Processing first response
    // 45-90%: Second download (actual file, if needed) / SQLite ingestion
    // 90-95%: Database update
    // 95-100%: Completion

    func downloadCurtainData(
        linkId: String,
        hostname: String,
        token: String? = nil,
        progressCallback: ((Int, Double) -> Void)? = nil,
        forceDownload: Bool = false
    ) async throws -> String {

        progressCallback?(0, 0.0)

        // Check if we already have the SQLite database locally and not forcing a redownload
        let localFilePath = proteomicsDataDatabaseManager.getDatabasePath(for: linkId)
        let dataExists = proteomicsDataDatabaseManager.checkDataExists(linkId)
        if !forceDownload && dataExists {
            // If database exists with valid data, make sure the entity has the file path set
            try await updateCurtainEntityWithLocalFilePath(linkId: linkId, filePath: localFilePath)

            // Also ensure CurtainSettingsEntity exists in SwiftData (migration for old data)
            let settingsResult = await ensureSettingsEntityExists(linkId: linkId)

            // If metadata is missing/corrupt, we need to re-download
            if settingsResult == .needsRedownload {
                print("[CurtainRepository] Metadata missing, proceeding with re-download for linkId: \(linkId)")
                // Don't return early - fall through to download
            } else {
                progressCallback?(100, 0.0)
                return localFilePath
            }
        }

        let downloadEndpoint = if let token = token {
            "\(linkId)/download/token=\(token)"
        } else {
            "\(linkId)/download/token="
        }

        progressCallback?(5, 0.0)

        // Create a wrapper callback that maps first network progress (0-100) to our range (5-40)
        let firstNetworkProgressCallback: ((Int, Double) -> Void)? = progressCallback != nil ? { networkProgress, speed in
            let adjustedProgress = 5 + (networkProgress * 35 / 100)
            progressCallback?(adjustedProgress, speed)
        } : nil

        let responseData = try await networkManager.downloadCurtain(hostname: hostname, downloadPath: downloadEndpoint, progressCallback: firstNetworkProgressCallback)

        progressCallback?(40, 0.0)
        let responseString = String(data: responseData, encoding: .utf8) ?? ""
        var filePath: String? = nil

        // Use SQLite ingestion service (replacing DuckDB)
        // First we need to parse the JSON to get the raw/processed strings if possible
        // Or if it's a redirect URL, handle that first (legacy logic kept for redirect check)

        do {
            if let jsonData = responseString.data(using: .utf8),
               let jsonMap = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {

                // Case 1: Redirect URL (AWS S3 signed URL pattern)
                if let downloadUrl = jsonMap["url"] as? String {
                    progressCallback?(45, 0.0)

                    let absoluteUrl: String
                    if downloadUrl.hasPrefix("http") {
                        absoluteUrl = downloadUrl
                    } else {
                        let baseUrl = hostname.hasSuffix("/") ? hostname : "\(hostname)/"
                        absoluteUrl = baseUrl + downloadUrl
                    }

                    let secondDownloadProgressCallback: ((Int, Double) -> Void)? = { progress, speed in
                        let mappedProgress = 45 + (progress * 35 / 100)
                        progressCallback?(mappedProgress, speed)
                    }

                    // Download actual data file to PERMANENT location (like Android's ${linkId}.json)
                    let jsonFileURL = getJsonFilePath(linkId: linkId)
                    _ = try await downloadClient.downloadFile(
                        from: absoluteUrl,
                        to: jsonFileURL.path,
                        progressCallback: secondDownloadProgressCallback
                    )
                    print("[CurtainRepository] JSON file saved permanently at: \(jsonFileURL.path)")

                    // Read the JSON file
                    let fullData = try Data(contentsOf: jsonFileURL)
                    if let fullJsonMap = try JSONSerialization.jsonObject(with: fullData) as? [String: Any] {
                        let rawTsv = fullJsonMap["raw"] as? String
                        let processedTsv = fullJsonMap["processed"] as? String

                        progressCallback?(80, 0.0)

                        // Build CurtainData for ingestion
                        let (curtainData, rawForm, differentialForm) = buildCurtainDataForIngestion(jsonMap: fullJsonMap)

                        // Ingest into SQLite using ProteomicsDataService
                        try proteomicsDataService.buildProteomicsDataIfNeeded(
                            linkId: linkId,
                            rawTsv: rawTsv,
                            processedTsv: processedTsv,
                            rawForm: rawForm,
                            differentialForm: differentialForm,
                            curtainData: curtainData,
                            onProgress: { status in
                                print("[CurtainRepository] Ingestion: \(status)")
                            }
                        )

                        // Build denormalized lookup tables (matching Android ProteinMappingService)
                        proteinMappingService.ensureMappingsExist(linkId: linkId, curtainData: curtainData)

                        filePath = proteomicsDataDatabaseManager.getDatabasePath(for: linkId)
                        print("[CurtainRepository] SQLite file path: \(filePath ?? "nil")")
                        print("[CurtainRepository] SQLite file exists: \(FileManager.default.fileExists(atPath: filePath ?? ""))")

                        // Extract and Save Metadata to SwiftData
                        saveMetadataToSwiftData(linkId: linkId, jsonMap: fullJsonMap)
                        print("[CurtainRepository] Metadata saved to SwiftData for linkId: \(linkId)")
                    }

                    // NOTE: DO NOT delete JSON file - keep it for migration/rebuild (like Android)

                } else {
                    // Case 2: Direct JSON response
                    progressCallback?(50, 0.0)

                    // Save JSON file permanently (like Android's ${linkId}.json)
                    let jsonFileURL = getJsonFilePath(linkId: linkId)
                    try responseData.write(to: jsonFileURL)
                    print("[CurtainRepository] JSON file saved permanently at: \(jsonFileURL.path)")

                    let rawTsv = jsonMap["raw"] as? String
                    let processedTsv = jsonMap["processed"] as? String

                    // Build CurtainData for ingestion
                    let (curtainData, rawForm, differentialForm) = buildCurtainDataForIngestion(jsonMap: jsonMap)

                    progressCallback?(60, 0.0)

                    // Ingest into SQLite using ProteomicsDataService
                    try proteomicsDataService.buildProteomicsDataIfNeeded(
                        linkId: linkId,
                        rawTsv: rawTsv,
                        processedTsv: processedTsv,
                        rawForm: rawForm,
                        differentialForm: differentialForm,
                        curtainData: curtainData,
                        onProgress: { status in
                            print("[CurtainRepository] Ingestion: \(status)")
                        }
                    )

                    // Build denormalized lookup tables (matching Android ProteinMappingService)
                    proteinMappingService.ensureMappingsExist(linkId: linkId, curtainData: curtainData)

                    // Extract and Save Metadata to SwiftData
                    saveMetadataToSwiftData(linkId: linkId, jsonMap: jsonMap)
                    print("[CurtainRepository] Metadata saved to SwiftData for linkId: \(linkId)")

                    progressCallback?(80, 0.0)
                    filePath = proteomicsDataDatabaseManager.getDatabasePath(for: linkId)
                    print("[CurtainRepository] SQLite file path: \(filePath ?? "nil")")
                    print("[CurtainRepository] SQLite file exists: \(FileManager.default.fileExists(atPath: filePath ?? ""))")
                }
            } else {
                // Fallback for non-JSON response (unlikely for new flow but kept safe)
                throw CurtainError.invalidResponse
            }
        } catch {
            throw CurtainError.downloadFailed
        }

        if let filePath = filePath {
            progressCallback?(95, 0.0)
            try await updateCurtainEntityWithLocalFilePath(linkId: linkId, filePath: filePath)
            progressCallback?(100, 0.0)
            return filePath
        }

        throw CurtainError.downloadFailed
    }

    /// Builds CurtainData from JSON for ingestion
    private func buildCurtainDataForIngestion(jsonMap: [String: Any]) -> (CurtainData, CurtainRawForm, CurtainDifferentialForm) {
        // Parse settings
        let settingsDict = jsonMap["settings"] as? [String: Any] ?? [:]
        let settings = CurtainSettings.fromDictionary(settingsDict)

        // Parse rawForm
        let rawForm: CurtainRawForm
        if let rawFormDict = jsonMap["rawForm"] as? [String: Any] {
            rawForm = CurtainRawForm(
                primaryIDs: rawFormDict["_primaryIDs"] as? String ?? "",
                samples: rawFormDict["_samples"] as? [String] ?? [],
                log2: rawFormDict["_log2"] as? Bool ?? false
            )
        } else {
            rawForm = CurtainRawForm()
        }

        // Parse differentialForm
        let differentialForm: CurtainDifferentialForm
        if let diffFormDict = jsonMap["differentialForm"] as? [String: Any] {
            let geneNamesColumn = diffFormDict["_geneNames"] as? String ?? ""
            print("[CurtainRepository] Parsed differentialForm._geneNames: '\(geneNamesColumn)'")
            print("[CurtainRepository] Full diffFormDict keys: \(diffFormDict.keys)")
            differentialForm = CurtainDifferentialForm(
                primaryIDs: diffFormDict["_primaryIDs"] as? String ?? "",
                geneNames: geneNamesColumn,
                foldChange: diffFormDict["_foldChange"] as? String ?? "",
                transformFC: diffFormDict["_transformFC"] as? Bool ?? false,
                significant: diffFormDict["_significant"] as? String ?? "",
                transformSignificant: diffFormDict["_transformSignificant"] as? Bool ?? false,
                comparison: diffFormDict["_comparison"] as? String ?? "",
                comparisonSelect: diffFormDict["_comparisonSelect"] as? [String] ?? [],
                reverseFoldChange: diffFormDict["_reverseFoldChange"] as? Bool ?? false
            )
        } else {
            differentialForm = CurtainDifferentialForm()
        }

        // Parse extraData for UniProt and gene maps
        var extraData: ExtraData? = nil
        if let extraDataObj = jsonMap["extraData"] as? [String: Any] {
            var uniprotData: UniprotExtraData? = nil
            if let uniprotObj = extraDataObj["uniprot"] as? [String: Any] {
                uniprotData = UniprotExtraData(
                    results: uniprotObj["results"] as? [String: Any] ?? [:],
                    dataMap: uniprotObj["dataMap"] as? [String: Any],
                    db: uniprotObj["db"] as? [String: Any],
                    organism: uniprotObj["organism"] as? String,
                    accMap: uniprotObj["accMap"] as? [String: [String]],
                    geneNameToAcc: uniprotObj["geneNameToAcc"] as? [String: [String: Any]]
                )
            }

            var dataContainer: DataMapContainer? = nil
            if let dataObj = extraDataObj["data"] as? [String: Any] {
                dataContainer = DataMapContainer(
                    dataMap: dataObj["dataMap"] as? [String: Any],
                    genesMap: dataObj["genesMap"] as? [String: [String: Any]],
                    primaryIDsMap: dataObj["primaryIDsMap"] as? [String: [String: Any]],
                    allGenes: dataObj["allGenes"] as? [String]
                )
            }

            extraData = ExtraData(uniprot: uniprotData, data: dataContainer)
        }

        // Parse selections
        let selectedMap = jsonMap["selectionsMap"] as? [String: [String: Bool]]
        let selectionsName = jsonMap["selectionsName"] as? [String]

        let curtainData = CurtainData(
            raw: jsonMap["raw"] as? String,
            rawForm: rawForm,
            differentialForm: differentialForm,
            processed: jsonMap["processed"] as? String,
            password: jsonMap["password"] as? String ?? "",
            selections: jsonMap["selections"] as? [String: [Any]],
            selectionsMap: jsonMap["selectionsMap"] as? [String: Any],
            selectedMap: selectedMap,
            selectionsName: selectionsName,
            settings: settings,
            fetchUniprot: jsonMap["fetchUniprot"] as? Bool ?? true,
            annotatedData: jsonMap["annotatedData"],
            extraData: extraData,
            permanent: jsonMap["permanent"] as? Bool ?? false,
            bypassUniProt: jsonMap["bypassUniProt"] as? Bool ?? false
        )

        return (curtainData, rawForm, differentialForm)
    }
    
    private func saveMetadataToSwiftData(linkId: String, jsonMap: [String: Any]) {
        // Parse settings
        let settingsDict = jsonMap["settings"] as? [String: Any] ?? [:]
        let settings = CurtainSettings.fromDictionary(settingsDict)

        // Parse rawForm
        let rawForm: CurtainRawForm
        if let rawFormDict = jsonMap["rawForm"] as? [String: Any] {
            rawForm = CurtainRawForm(
                primaryIDs: rawFormDict["_primaryIDs"] as? String ?? "",
                samples: rawFormDict["_samples"] as? [String] ?? [],
                log2: rawFormDict["_log2"] as? Bool ?? false
            )
        } else {
            rawForm = CurtainRawForm()
        }

        let differentialForm: CurtainDifferentialForm
        if let diffFormDict = jsonMap["differentialForm"] as? [String: Any] {
            differentialForm = CurtainDifferentialForm(
                primaryIDs: diffFormDict["_primaryIDs"] as? String ?? "",
                geneNames: diffFormDict["_geneNames"] as? String ?? "",
                foldChange: diffFormDict["_foldChange"] as? String ?? "",
                transformFC: diffFormDict["_transformFC"] as? Bool ?? false,
                significant: diffFormDict["_significant"] as? String ?? "",
                transformSignificant: diffFormDict["_transformSignificant"] as? Bool ?? false,
                comparison: diffFormDict["_comparison"] as? String ?? "",
                comparisonSelect: diffFormDict["_comparisonSelect"] as? [String] ?? [],
                reverseFoldChange: diffFormDict["_reverseFoldChange"] as? Bool ?? false
            )
        } else {
            differentialForm = CurtainDifferentialForm()
        }

        // Save to SwiftData
        saveCurtainSettings(linkId: linkId, settings: settings, rawForm: rawForm, differentialForm: differentialForm)
    }
    
    
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
                // Delete associated local file if it exists 
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

    func insertCurtain(_ curtain: CurtainEntity) {
        performDatabaseOperation {
            modelContext.insert(curtain)
            try? modelContext.save()
        }
    }

    func insertSiteSettings(_ siteSettings: CurtainSiteSettings) {
        performDatabaseOperation {
            modelContext.insert(siteSettings)
            try? modelContext.save()
        }
    }

    
    private func getLocalFilePath(linkId: String) -> String {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let curtainDataDir = documentsPath.appendingPathComponent("CurtainData", isDirectory: true)

        // Create CurtainData directory if it doesn't exist
        try? FileManager.default.createDirectory(at: curtainDataDir, withIntermediateDirectories: true)

        // Now using SQLite instead of DuckDB
        return curtainDataDir.appendingPathComponent("proteomics_data_\(linkId).sqlite").path
    }
    
    private func getMetadataFilePath(linkId: String) -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let curtainDataDir = documentsPath.appendingPathComponent("CurtainData", isDirectory: true)

        // Create CurtainData directory if it doesn't exist
        try? FileManager.default.createDirectory(at: curtainDataDir, withIntermediateDirectories: true)

        return curtainDataDir.appendingPathComponent("\(linkId)_metadata.json")
    }

    /// Gets the path for the permanently stored JSON file (like Android's ${linkId}.json)
    /// This file is kept for migration/rebuild purposes
    private func getJsonFilePath(linkId: String) -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let curtainDataDir = documentsPath.appendingPathComponent("CurtainData", isDirectory: true)

        // Create CurtainData directory if it doesn't exist
        try? FileManager.default.createDirectory(at: curtainDataDir, withIntermediateDirectories: true)

        return curtainDataDir.appendingPathComponent("\(linkId).json")
    }

    /// Checks if JSON file exists for a linkId
    func jsonFileExists(linkId: String) -> Bool {
        return FileManager.default.fileExists(atPath: getJsonFilePath(linkId: linkId).path)
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

    /// Result of ensuring settings entity exists
    enum SettingsEntityResult {
        case exists           // Settings already exist in SwiftData
        case migrated         // Settings were migrated from SQLite to SwiftData
        case rebuilt          // Database was rebuilt from stored JSON file
        case needsRedownload  // No stored JSON file - needs re-download from server
        case noData           // No data exists at all
    }

    /// Ensures CurtainSettingsEntity exists in SwiftData for a given linkId.
    /// This is used for migration when SQLite data exists but SwiftData metadata was not saved (old data).
    /// If SQLite metadata is missing but JSON file exists, rebuilds everything from JSON (like Android).
    /// Called from CurtainDetailsView to ensure data consistency.
    /// Returns the result status to allow caller to handle re-download if needed.
    func ensureSettingsEntityExists(linkId: String) async -> SettingsEntityResult {
        // Check if settings already exist in SwiftData
        if getCurtainSettings(linkId: linkId) != nil {
            print("[CurtainRepository] CurtainSettingsEntity already exists for linkId: \(linkId)")
            return .exists
        }

        print("[CurtainRepository] CurtainSettingsEntity not found in SwiftData for linkId: \(linkId)")

        // First, try to load from SQLite metadata (fast path)
        if proteomicsDataDatabaseManager.databaseFileExists(for: linkId) {
            do {
                if let metadata = try proteomicsDataService.getCurtainMetadata(linkId: linkId) {
                    print("[CurtainRepository] Found CurtainMetadata in SQLite, migrating to SwiftData")
                    if let result = migrateMetadataFromSQLite(linkId: linkId, metadata: metadata) {
                        return result
                    }
                }
            } catch {
                print("[CurtainRepository] Error reading SQLite metadata: \(error)")
            }
        }

        // SQLite metadata missing or corrupt - try to rebuild from stored JSON file (like Android)
        let jsonFileURL = getJsonFilePath(linkId: linkId)
        if FileManager.default.fileExists(atPath: jsonFileURL.path) {
            print("[CurtainRepository] Found stored JSON file, rebuilding database from JSON")
            do {
                let result = try await rebuildFromStoredJson(linkId: linkId, jsonFileURL: jsonFileURL)
                return result
            } catch {
                print("[CurtainRepository] ERROR: Failed to rebuild from JSON: \(error)")
                // Delete corrupted files
                try? FileManager.default.removeItem(at: jsonFileURL)
                try? proteomicsDataDatabaseManager.deleteDatabaseFile(for: linkId)
                return .needsRedownload
            }
        }

        // No stored JSON file - check if SQLite exists but is corrupt
        if proteomicsDataDatabaseManager.databaseFileExists(for: linkId) {
            print("[CurtainRepository] SQLite exists but no JSON file for rebuild, deleting corrupt database")
            try? proteomicsDataDatabaseManager.deleteDatabaseFile(for: linkId)
        }

        print("[CurtainRepository] No data available for linkId: \(linkId), needs re-download")
        return .needsRedownload
    }

    /// Migrates metadata from SQLite CurtainMetadata table to SwiftData
    /// Returns nil if migration fails (triggers fallback to JSON rebuild)
    private func migrateMetadataFromSQLite(linkId: String, metadata: CurtainMetadata) -> SettingsEntityResult? {
        // Parse settings JSON
        guard let settingsData = metadata.settingsJson.data(using: .utf8),
              let settingsDict = try? JSONSerialization.jsonObject(with: settingsData) as? [String: Any] else {
            print("[CurtainRepository] ERROR: Failed to parse settings JSON from SQLite")
            return nil
        }
        let settings = CurtainSettings.fromDictionary(settingsDict)

        // Parse rawForm JSON
        guard let rawFormData = metadata.rawFormJson.data(using: .utf8),
              let rawFormDict = try? JSONSerialization.jsonObject(with: rawFormData) as? [String: Any] else {
            print("[CurtainRepository] ERROR: Failed to parse rawForm JSON from SQLite")
            return nil
        }
        let rawForm = CurtainRawForm(
            primaryIDs: rawFormDict["primaryIDs"] as? String ?? rawFormDict["_primaryIDs"] as? String ?? "",
            samples: rawFormDict["samples"] as? [String] ?? rawFormDict["_samples"] as? [String] ?? [],
            log2: rawFormDict["log2"] as? Bool ?? rawFormDict["_log2"] as? Bool ?? false
        )

        // Parse differentialForm JSON
        guard let diffFormData = metadata.differentialFormJson.data(using: .utf8),
              let diffFormDict = try? JSONSerialization.jsonObject(with: diffFormData) as? [String: Any] else {
            print("[CurtainRepository] ERROR: Failed to parse differentialForm JSON from SQLite")
            return nil
        }
        let differentialForm = CurtainDifferentialForm(
            primaryIDs: diffFormDict["primaryIDs"] as? String ?? diffFormDict["_primaryIDs"] as? String ?? "",
            geneNames: diffFormDict["geneNames"] as? String ?? diffFormDict["_geneNames"] as? String ?? "",
            foldChange: diffFormDict["foldChange"] as? String ?? diffFormDict["_foldChange"] as? String ?? "",
            transformFC: diffFormDict["transformFC"] as? Bool ?? diffFormDict["_transformFC"] as? Bool ?? false,
            significant: diffFormDict["significant"] as? String ?? diffFormDict["_significant"] as? String ?? "",
            transformSignificant: diffFormDict["transformSignificant"] as? Bool ?? diffFormDict["_transformSignificant"] as? Bool ?? false,
            comparison: diffFormDict["comparison"] as? String ?? diffFormDict["_comparison"] as? String ?? "",
            comparisonSelect: diffFormDict["comparisonSelect"] as? [String] ?? diffFormDict["_comparisonSelect"] as? [String] ?? [],
            reverseFoldChange: diffFormDict["reverseFoldChange"] as? Bool ?? diffFormDict["_reverseFoldChange"] as? Bool ?? false
        )

        // Save to SwiftData
        saveCurtainSettings(linkId: linkId, settings: settings, rawForm: rawForm, differentialForm: differentialForm)

        // VERIFY the save actually worked by fetching it back
        if getCurtainSettings(linkId: linkId) != nil {
            print("[CurtainRepository] Successfully migrated and verified settings from SQLite to SwiftData for linkId: \(linkId)")
            return .migrated
        } else {
            // Save reported success but fetch failed - treat as migration failure
            print("[CurtainRepository] ERROR: Migration save reported success but verification fetch failed for linkId: \(linkId)")
            print("[CurtainRepository] Treating as migration failure, will try rebuild from JSON")
            return nil
        }
    }

    /// Rebuilds entire database from stored JSON file (like Android's migration behavior)
    private func rebuildFromStoredJson(linkId: String, jsonFileURL: URL) async throws -> SettingsEntityResult {
        print("[CurtainRepository] Rebuilding from stored JSON: \(jsonFileURL.path)")

        // Delete old SQLite database if exists
        try? proteomicsDataDatabaseManager.deleteDatabaseFile(for: linkId)

        // Read JSON file
        let jsonData = try Data(contentsOf: jsonFileURL)
        guard let jsonMap = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            throw CurtainError.invalidResponse
        }

        let rawTsv = jsonMap["raw"] as? String
        let processedTsv = jsonMap["processed"] as? String

        // Build CurtainData for ingestion
        let (curtainData, rawForm, differentialForm) = buildCurtainDataForIngestion(jsonMap: jsonMap)

        // Ingest into SQLite
        try proteomicsDataService.buildProteomicsDataIfNeeded(
            linkId: linkId,
            rawTsv: rawTsv,
            processedTsv: processedTsv,
            rawForm: rawForm,
            differentialForm: differentialForm,
            curtainData: curtainData,
            onProgress: { status in
                print("[CurtainRepository] Rebuild ingestion: \(status)")
            }
        )

        // Build denormalized lookup tables (matching Android ProteinMappingService)
        proteinMappingService.ensureMappingsExist(linkId: linkId, curtainData: curtainData)

        // Save metadata to SwiftData
        saveMetadataToSwiftData(linkId: linkId, jsonMap: jsonMap)
        print("[CurtainRepository] Successfully rebuilt database from JSON for linkId: \(linkId)")

        return .rebuilt
    }

    // Keep old catch block for backward compatibility
    private func handleMigrationError(linkId: String, error: Error) -> SettingsEntityResult {
        print("[CurtainRepository] ERROR: Failed to load metadata from SQLite: \(error)")
        try? proteomicsDataDatabaseManager.deleteDatabaseFile(for: linkId)
        return .needsRedownload
    }
    
    private func parseCreatedDateToTimestamp(_ createdDateString: String) -> Date {
        // Multiple date format fallbacks 
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

        guard getSiteSettingsByHostname(curtain.sourceHostname) != nil else {
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
            performDatabaseOperation {
                curtain.file = localFilePath
                try? modelContext.save()
            }

            
            return localFilePath
            
        } catch {
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

        // Now using SQLite instead of DuckDB
        return curtainDataDir.appendingPathComponent("proteomics_data_\(linkId).sqlite").path
    }
    
    /// Exclude file from iCloud backup to keep it local only
    private func excludeFromiCloudBackup(path: String) throws {
        var url = URL(fileURLWithPath: path)
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        try url.setResourceValues(resourceValues)
    }
    
    /// Update curtain entity with file path and save
    func updateCurtain(_ curtain: CurtainEntity) throws {
        performDatabaseOperation {
            try? modelContext.save()
        }
    }
    
    /// Cancels the current download operation
    func cancelDownload() {
        downloadClient.cancelDownload()
    }
}


private extension Curtain {
    func toCurtainEntity(hostname: String, frontendURL: String? = nil) -> CurtainEntity {
        return CurtainEntity(
            linkId: self.linkId,
            created: parseCreatedDate(self.created),
            updated: Date(),
            file: nil,
            dataDescription: self.description,
            enable: self.enable,
            curtainType: self.curtainType,
            sourceHostname: hostname,
            frontendURL: frontendURL
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
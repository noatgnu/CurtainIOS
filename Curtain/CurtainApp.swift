//
//  CurtainApp.swift
//  Curtain
//
//  Created by Toan Phung on 02/08/2025.
//

import SwiftUI
import SwiftData

@main
struct CurtainApp: App {
    @State private var deepLinkViewModel = DeepLinkViewModel()

    /// Check if running under UI tests
    private static var isUITesting: Bool {
        CommandLine.arguments.contains("--uitesting")
    }

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            CurtainEntity.self,
            CurtainSiteSettings.self,
            DataFilterListEntity.self,
            CurtainSettingsEntity.self,  // Added for SQLite metadata migration
            CurtainCollectionEntity.self,
            CollectionSessionEntity.self,
            SavedCrossDatasetSearchEntity.self,
        ])

        // Use in-memory storage for UI tests to ensure clean state
        let isInMemory = CurtainApp.isUITesting
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: isInMemory)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            // If migration fails (e.g., new table needed), delete old database and recreate
            print("[CurtainApp] ModelContainer creation failed, attempting to recreate database: \(error)")

            // Delete the old database file to allow fresh creation with new schema
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let storeURL = appSupport.appendingPathComponent("default.store")
            let walURL = appSupport.appendingPathComponent("default.store-wal")
            let shmURL = appSupport.appendingPathComponent("default.store-shm")

            try? FileManager.default.removeItem(at: storeURL)
            try? FileManager.default.removeItem(at: walURL)
            try? FileManager.default.removeItem(at: shmURL)

            print("[CurtainApp] Deleted old database, creating fresh ModelContainer")

            do {
                return try ModelContainer(for: schema, configurations: [modelConfiguration])
            } catch {
                fatalError("Could not create ModelContainer even after reset: \(error)")
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(deepLinkViewModel)
                .onOpenURL { url in
                    Task {
                        await handleDeepLink(url)
                    }
                }
        }
        .modelContainer(sharedModelContainer)
    }

    private func handleDeepLink(_ url: URL) async {

        let result = await DeepLinkHandler.shared.processURL(url)

        if result.isValid {
            deepLinkViewModel.handleDeepLinkResult(result)
        } else {
        }
    }
}

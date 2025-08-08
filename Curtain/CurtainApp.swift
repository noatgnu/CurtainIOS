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
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            CurtainEntity.self,
            CurtainSiteSettings.self,
            DataFilterListEntity.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    Task {
                        await handleDeepLink(url)
                    }
                }
        }
        .modelContainer(sharedModelContainer)
    }
    
    private func handleDeepLink(_ url: URL) async {
        print("🔗 CurtainApp: Received deep link: \(url.absoluteString)")
        
        let result = await DeepLinkHandler.shared.processURL(url)
        
        if result.isValid {
            print("🔗 CurtainApp: Deep link processed successfully")
            // The deep link processing will be handled by the views
            // For now, just log the success
        } else {
            print("🔗 CurtainApp: Deep link processing failed: \(result.error ?? "Unknown error")")
        }
    }
}

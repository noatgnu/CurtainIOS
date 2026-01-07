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

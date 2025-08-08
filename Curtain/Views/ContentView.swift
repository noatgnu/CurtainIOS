//
//  ContentView.swift
//  Curtain
//
//  Created by Toan Phung on 02/08/2025.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        TabView {
            CurtainListView()
                .tabItem {
                    Image(systemName: "list.bullet.clipboard")
                    Text("Datasets")
                }
            
            DataFilterListView()
                .tabItem {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                    Text("Filters")
                }
            
            SiteSettingsView()
                .tabItem {
                    Image(systemName: "server.rack")
                    Text("Sites")
                }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: CurtainEntity.self, inMemory: true)
}

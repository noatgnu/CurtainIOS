//
//  DemoUsageGuide.swift
//  Curtain
//
//  Created by Toan Phung on 02/08/2025.
//

import SwiftUI

/// Quick guide showing how to use the main view features
struct DemoUsageGuide: View {
    var body: some View {
        NavigationStack {
            List {
                Section("Loading Example Data") {
                    GuideItem(
                        icon: "doc.badge.plus",
                        title: "From Empty State",
                        description: "When you first open the app, click 'Load Example Dataset' to get started with demo data"
                    )
                    
                    GuideItem(
                        icon: "plus.circle",
                        title: "From Add Dialog",
                        description: "Click the + button → 'Load Example Dataset' in Quick Actions"
                    )
                    
                    GuideItem(
                        icon: "info.circle",
                        title: "Example Data Info",
                        description: "Uses curtain.proteo.info example: \(CurtainConstants.ExampleData.uniqueId)"
                    )
                }
                
                Section("Adding Custom Datasets") {
                    GuideItem(
                        icon: "textfield",
                        title: "Individual Fields Method",
                        description: "Enter Link ID, Hostname, and Description separately"
                    )
                    
                    GuideItem(
                        icon: "link",
                        title: "Full URL Method", 
                        description: "Paste complete URL like: https://curtain.proteo.info/#/your-link-id"
                    )
                    
                    GuideItem(
                        icon: "list.bullet",
                        title: "Common Hostnames",
                        description: "Use the 'Common' button to select from predefined servers"
                    )
                }
                
                Section("Predefined Hosts") {
                    ForEach(CurtainConstants.commonHostnames, id: \.self) { hostname in
                        Label(hostname, systemImage: "server.rack")
                            .font(.caption)
                    }
                }
                
                Section("URL Pattern Examples") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Proteo URL:")
                            .font(.caption)
                            .fontWeight(.medium)
                        Text("https://curtain.proteo.info/#/f4b009f3-ac3c-470a-a68b-55fcadf68d0f")
                            .font(.caption)
                            .foregroundColor(.blue)
                            .textSelection(.enabled)
                        
                        Text("Custom Server:")
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.top, 4)
                        Text("https://your-server.com/api/curtain/dataset-id")
                            .font(.caption)
                            .foregroundColor(.blue)
                            .textSelection(.enabled)
                    }
                }
            }
            .navigationTitle("Usage Guide")
        }
    }
}

struct GuideItem: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    DemoUsageGuide()
}
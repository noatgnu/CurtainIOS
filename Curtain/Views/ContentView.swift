//
//  ContentView.swift
//  Curtain
//
//  Created by Toan Phung on 02/08/2025.
//

import SwiftUI
import SwiftData

enum AppTab: String, CaseIterable {
    case datasets, search, results, filters, sites

    var title: String {
        switch self {
        case .datasets: "Datasets"
        case .search: "Search"
        case .results: "Results"
        case .filters: "Filters"
        case .sites: "Sites"
        }
    }

    var icon: String {
        switch self {
        case .datasets: "list.bullet.clipboard"
        case .search: "magnifyingglass"
        case .results: "chart.bar.doc.horizontal"
        case .filters: "line.3.horizontal.decrease.circle"
        case .sites: "server.rack"
        }
    }
}

struct ContentView: View {
    @State private var selectedTab: AppTab = .datasets
    @State private var crossDatasetViewModel = CrossDatasetSearchViewModel()
    @AppStorage("appearanceMode") private var appearanceMode: String = "auto"

    var body: some View {
        if UIDevice.current.userInterfaceIdiom == .pad || UIDevice.current.userInterfaceIdiom == .mac {
            wideLayout
        } else {
            compactLayout
        }
    }

    private var compactLayout: some View {
        TabView(selection: $selectedTab) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                NavigationStack {
                    tabContent(for: tab)
                        .navigationTitle(tab.title)
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                AppearanceToggleButton(appearanceMode: $appearanceMode)
                            }
                        }
                }
                .tabItem {
                    Image(systemName: tab.icon)
                    Text(tab.title)
                }
                .tag(tab)
            }
        }
    }

    private var wideLayout: some View {
        HStack(spacing: 0) {
            CompactSideBar(selectedTab: $selectedTab)
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text(selectedTab.title)
                        .font(.title2)
                        .fontWeight(.bold)
                    Spacer()
                    AppearanceToggleButton(appearanceMode: $appearanceMode)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 8)

                tabContent(for: selectedTab)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(Color(.systemGroupedBackground))
        }
    }

    @ViewBuilder
    private func tabContent(for tab: AppTab) -> some View {
        switch tab {
        case .datasets: CurtainListView()
        case .search: CrossDatasetSearchView(viewModel: crossDatasetViewModel)
        case .results: CrossDatasetResultsView(viewModel: crossDatasetViewModel)
        case .filters: DataFilterListView()
        case .sites: SiteSettingsView()
        }
    }
}

struct CompactSideBar: View {
    @Binding var selectedTab: AppTab
    @State private var isExpanded = false
    @State private var collapseTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 0) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                sidebarButton(for: tab)
            }
            Spacer()
        }
        .frame(width: isExpanded ? 160 : 56)
        .padding(.vertical, 8)
        .background(Color(.systemGroupedBackground))
        .animation(.easeInOut(duration: 0.2), value: isExpanded)
    }

    private func sidebarButton(for tab: AppTab) -> some View {
        Button {
            selectedTab = tab
            scheduleCollapse()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: tab.icon)
                    .font(.title3)
                    .frame(width: 24)

                if isExpanded {
                    Text(tab.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    Spacer()
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(selectedTab == tab ? Color.accentColor.opacity(0.15) : Color.clear)
            .foregroundColor(selectedTab == tab ? .accentColor : .secondary)
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 4)
        .onHover { hovering in
            if hovering {
                collapseTask?.cancel()
                withAnimation { isExpanded = true }
            } else {
                scheduleCollapse()
            }
        }
    }

    private func scheduleCollapse() {
        collapseTask?.cancel()
        collapseTask = Task {
            try? await Task.sleep(for: .seconds(1.5))
            if !Task.isCancelled {
                await MainActor.run {
                    withAnimation { isExpanded = false }
                }
            }
        }
    }
}

// MARK: - Appearance Toggle

struct AppearanceToggleButton: View {
    @Binding var appearanceMode: String

    private var icon: String {
        switch appearanceMode {
        case "light": return "sun.max.fill"
        case "dark": return "moon.fill"
        default: return "circle.lefthalf.filled"
        }
    }

    private var label: String {
        switch appearanceMode {
        case "light": return "Light"
        case "dark": return "Dark"
        default: return "Auto"
        }
    }

    var body: some View {
        Menu {
            Button {
                appearanceMode = "auto"
            } label: {
                Label("Auto", systemImage: "circle.lefthalf.filled")
            }
            Button {
                appearanceMode = "light"
            } label: {
                Label("Light", systemImage: "sun.max.fill")
            }
            Button {
                appearanceMode = "dark"
            } label: {
                Label("Dark", systemImage: "moon.fill")
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: icon)
                Text(label)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }
}

#Preview {
    ContentView()
        .modelContainer(for: CurtainEntity.self, inMemory: true)
}

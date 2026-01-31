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
                tabContent(for: tab)
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
            Divider()
            NavigationStack {
                tabContent(for: selectedTab)
                    .navigationTitle(selectedTab.title)
                    .navigationBarTitleDisplayMode(.inline)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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

#Preview {
    ContentView()
        .modelContainer(for: CurtainEntity.self, inMemory: true)
}

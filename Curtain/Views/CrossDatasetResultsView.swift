//
//  CrossDatasetResultsView.swift
//  Curtain
//
//  Results display for cross-dataset protein search.
//

import SwiftUI
import SwiftData

struct CrossDatasetResultsView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var viewModel: CrossDatasetSearchViewModel
    @State private var showSaveSheet = false
    @State private var saveSearchName = ""
    @State private var searchText = ""

    var body: some View {
        Group {
            if UIDevice.current.userInterfaceIdiom == .pad || UIDevice.current.userInterfaceIdiom == .mac {
                iPadLayout
            } else {
                iPhoneLayout
            }
        }
        .onAppear {
            viewModel.setupWithModelContext(modelContext)
        }
        .alert("Save Search", isPresented: $showSaveSheet) {
            TextField("Search Name", text: $saveSearchName)
            Button("Save") {
                if !saveSearchName.isEmpty {
                    viewModel.saveCurrentSearch(name: saveSearchName)
                    saveSearchName = ""
                }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: - iPad Layout (3-panel)

    private var iPadLayout: some View {
        HStack(spacing: 0) {
            // Left: Saved searches
            VStack(spacing: 0) {
                HStack {
                    Text("Searches")
                        .font(.headline)
                    Spacer()
                    if viewModel.searchResult != nil && viewModel.currentSavedSearchId == nil {
                        Button { showSaveSheet = true } label: {
                            Image(systemName: "square.and.arrow.down")
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 10)

                Divider()

                SavedSearchesList(viewModel: viewModel, onSave: { showSaveSheet = true })
            }
            .frame(width: 200)
            .background(Color(.secondarySystemGroupedBackground))

            Divider()

            // Middle: Protein summaries
            VStack(spacing: 0) {
                HStack {
                    Text("Proteins (\(viewModel.searchResult?.proteinSummaries.count ?? 0))")
                        .font(.headline)
                    Spacer()
                    sortMenu
                }
                .padding(.horizontal)
                .padding(.vertical, 10)

                Divider()

                if viewModel.searchResult != nil {
                    ProteinSummaryList(viewModel: viewModel, searchText: $searchText)
                } else {
                    Spacer()
                    Text("Select a search to view proteins")
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
            .frame(width: 240)

            Divider()

            // Right: Matrix/Detail
            VStack(spacing: 0) {
                if let selected = viewModel.selectedProtein {
                    let summary = viewModel.searchResult?.proteinSummaries.first {
                        ($0.primaryId ?? $0.searchTerm) == (selected.primaryId ?? selected.searchTerm)
                    }
                    HStack {
                        Text(summary?.geneName ?? summary?.primaryId ?? "Detail")
                            .font(.headline)
                        Spacer()
                        if let csv = viewModel.exportResultsCSV() {
                            ShareLink("Export CSV", item: csv)
                                .font(.subheadline)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 10)

                    Divider()
                }

                detailPanel
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - iPhone Layout (panel-based navigation)

    private var iPhoneLayout: some View {
        NavigationStack {
            Group {
                switch viewModel.currentPanel {
                case 0:
                    savedSearchesPhonePanel
                case 1:
                    proteinsPhonePanel
                case 2:
                    matrixPhonePanel
                default:
                    EmptyView()
                }
            }
            .navigationTitle(phoneTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if viewModel.currentPanel > 0 {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button { viewModel.currentPanel -= 1 } label: {
                            Image(systemName: "chevron.left")
                        }
                    }
                }
                if viewModel.currentPanel == 1 && viewModel.searchResult != nil && viewModel.currentSavedSearchId == nil {
                    ToolbarItem(placement: .primaryAction) {
                        Button { showSaveSheet = true } label: {
                            Image(systemName: "square.and.arrow.down")
                        }
                    }
                }
            }
        }
    }

    private var phoneTitle: String {
        switch viewModel.currentPanel {
        case 0: return "Saved Searches"
        case 1: return "Proteins Found (\(viewModel.searchResult?.proteinSummaries.count ?? 0))"
        case 2:
            if let selected = viewModel.selectedProtein {
                let summary = viewModel.searchResult?.proteinSummaries.first {
                    ($0.primaryId ?? $0.searchTerm) == (selected.primaryId ?? selected.searchTerm)
                }
                return summary?.geneName ?? summary?.primaryId ?? "Dataset vs Comparison"
            }
            return "Dataset vs Comparison"
        default: return ""
        }
    }

    // MARK: - Phone Panels

    private var savedSearchesPhonePanel: some View {
        ZStack(alignment: .bottom) {
            SavedSearchesList(viewModel: viewModel, onLoadSearch: { _ in
                viewModel.currentPanel = 1
            })

            if viewModel.searchResult != nil {
                Button {
                    viewModel.currentPanel = 1
                } label: {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Current Search")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text("\(viewModel.searchResult!.proteinSummaries.count) proteins found")
                                .font(.caption)
                        }
                        Spacer()
                        Image(systemName: "arrow.up.forward.square")
                    }
                    .padding()
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding()
            }
        }
    }

    private var proteinsPhonePanel: some View {
        VStack(spacing: 0) {
            if viewModel.searchResult != nil {
                ProteinSummaryList(viewModel: viewModel, searchText: $searchText, onSelect: { _ in
                    viewModel.currentPanel = 2
                })
            } else {
                Spacer()
                Text("No search results")
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
    }

    private var matrixPhonePanel: some View {
        detailPanel
    }

    // MARK: - Detail Panel

    @ViewBuilder
    private var detailPanel: some View {
        if viewModel.selectedProtein == nil {
            VStack {
                Spacer()
                Text("Select a protein to view matrix")
                    .foregroundStyle(.secondary)
                Spacer()
            }
        } else if viewModel.isLoadingMatrix {
            VStack {
                Spacer()
                ProgressView()
                Spacer()
            }
        } else if let matrix = viewModel.matrixData, let selected = viewModel.selectedProtein {
            CrossDatasetMatrixView(
                viewModel: viewModel,
                selectedProteinId: selected.primaryId ?? selected.searchTerm
            )
        } else {
            VStack {
                Spacer()
                Text("Building matrix...")
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
    }

    // MARK: - Sort Menu

    private var sortMenu: some View {
        Menu {
            ForEach(ProteinSortOption.allCases, id: \.self) { option in
                Button {
                    viewModel.sortOption = option
                    viewModel.applySorting()
                } label: {
                    HStack {
                        Text(option.displayName)
                        if viewModel.sortOption == option {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
        }
    }
}

// MARK: - Saved Searches List

struct SavedSearchesList: View {
    @Bindable var viewModel: CrossDatasetSearchViewModel
    var onLoadSearch: ((SavedCrossDatasetSearchEntity) -> Void)?
    var onSave: (() -> Void)?

    var body: some View {
        List {
            // Current (unsaved) card
            if viewModel.searchResult != nil && viewModel.currentSavedSearchId == nil {
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.caption)
                        Text("Current (unsaved)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    Spacer()
                    HStack(spacing: 4) {
                        if let save = onSave {
                            Button { save() } label: {
                                Image(systemName: "square.and.arrow.down")
                                    .font(.caption)
                                    .foregroundStyle(.tint)
                            }
                            .buttonStyle(.plain)
                        }
                        Image(systemName: "checkmark")
                            .font(.caption)
                            .foregroundStyle(.tint)
                    }
                }
                .padding(.vertical, 4)
                .listRowBackground(Color.accentColor.opacity(0.08))
            }

            if viewModel.savedSearches.isEmpty && !(viewModel.searchResult != nil && viewModel.currentSavedSearchId == nil) {
                Text("No saved searches")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            }

            ForEach(viewModel.savedSearches, id: \.searchId) { search in
                Button {
                    viewModel.loadSavedSearch(search)
                    onLoadSearch?(search)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(search.name)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text("\(search.proteinCount) proteins \u{2022} \(search.created, style: .date)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if viewModel.currentSavedSearchId == search.searchId {
                            Image(systemName: "checkmark")
                                .font(.caption)
                                .foregroundStyle(.tint)
                        }
                    }
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        viewModel.deleteSavedSearch(search.searchId)
                    } label: {
                        Image(systemName: "trash")
                    }
                }
                .listRowBackground(
                    viewModel.currentSavedSearchId == search.searchId
                        ? Color.accentColor.opacity(0.08) : Color.clear
                )
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.clear)
    }
}

// MARK: - Protein Summary List

struct ProteinSummaryList: View {
    @Bindable var viewModel: CrossDatasetSearchViewModel
    @Binding var searchText: String
    var onSelect: ((ProteinSearchSummary) -> Void)?

    private var filteredSummaries: [ProteinSearchSummary] {
        guard let summaries = viewModel.searchResult?.proteinSummaries else { return [] }
        if searchText.isEmpty { return summaries }
        return summaries.filter { summary in
            summary.searchTerm.localizedCaseInsensitiveContains(searchText) ||
            (summary.geneName?.localizedCaseInsensitiveContains(searchText) ?? false) ||
            (summary.primaryId?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            TextField("Filter proteins...", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)
                .padding(.bottom, 8)

            Divider()

            if filteredSummaries.isEmpty {
                Spacer()
                Text("No results")
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                List(filteredSummaries) { summary in
                    Button {
                        Task {
                            await viewModel.selectProtein(summary)
                            onSelect?(summary)
                        }
                    } label: {
                        ProteinSummaryItem(
                            summary: summary,
                            isSelected: (viewModel.selectedProtein?.primaryId ?? viewModel.selectedProtein?.searchTerm) ==
                                        (summary.primaryId ?? summary.searchTerm)
                        )
                    }
                    .listRowBackground(
                        (viewModel.selectedProtein?.primaryId ?? viewModel.selectedProtein?.searchTerm) ==
                        (summary.primaryId ?? summary.searchTerm)
                            ? Color.accentColor.opacity(0.1)
                            : Color.clear
                    )
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
            }
        }
    }
}

// MARK: - Protein Summary Item (matches Android's ProteinSummaryItem)

struct ProteinSummaryItem: View {
    let summary: ProteinSearchSummary
    let isSelected: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    let displayName = summary.geneName ?? summary.primaryId ?? summary.searchTerm
                    Text(displayName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(1)

                    if summary.hasSignificantResult {
                        Text("\u{2605}")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }

                let hasGeneName = summary.geneName != nil
                if hasGeneName, let primaryId = summary.primaryId {
                    Text(primaryId)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else if !hasGeneName, let primaryId = summary.primaryId,
                          primaryId != (summary.geneName ?? summary.primaryId ?? summary.searchTerm) {
                    Text("(\(summary.searchTerm))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Text("\(summary.datasetsFoundIn)/\(summary.totalDatasetsSearched) datasets")
                    .font(.caption2)
                    .foregroundStyle(.tint)
                    .fontWeight(.medium)
            }

            Spacer()

            Image(systemName: "arrow.up.forward.square")
                .font(.caption)
                .foregroundStyle(.secondary.opacity(0.6))
        }
        .padding(.vertical, 4)
    }
}

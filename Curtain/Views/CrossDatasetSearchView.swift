//
//  CrossDatasetSearchView.swift
//  Curtain
//
//  Search configuration screen for cross-dataset protein search.
//

import SwiftUI
import SwiftData

struct CrossDatasetSearchView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var viewModel: CrossDatasetSearchViewModel
    @State private var showFilterListPicker = false
    @State private var showSavedSearches = false
    @State private var showSaveDialog = false

    var body: some View {
        if UIDevice.current.userInterfaceIdiom == .pad || UIDevice.current.userInterfaceIdiom == .mac {
            iPadLayout
        } else {
            iPhoneLayout
        }
    }

    // MARK: - iPad Layout

    private var iPadLayout: some View {
        HStack(spacing: 0) {
            datasetSelectionContent
                .frame(width: 320)

            VStack(spacing: 0) {
                // Inline toolbar for wide layout (no NavigationStack)
                HStack {
                    Spacer()

                    Button {
                        showFilterListPicker = true
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                    .buttonStyle(.plain)

                    Button {
                        withAnimation { showSavedSearches.toggle() }
                    } label: {
                        Image(systemName: showSavedSearches ? "bookmark.fill" : "clock.arrow.circlepath")
                    }
                    .buttonStyle(.plain)

                    if viewModel.searchResult != nil {
                        Button {
                            showSaveDialog = true
                        } label: {
                            Image(systemName: viewModel.currentSavedSearchId != nil ? "bookmark.fill" : "bookmark")
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)

                searchDetailContent
            }
            .frame(maxWidth: .infinity)
        }
        .onAppear {
            viewModel.setupWithModelContext(modelContext)
        }
        .sheet(isPresented: $showFilterListPicker) {
            FilterListPickerSheet(viewModel: viewModel, isPresented: $showFilterListPicker)
        }
        .alert("Save Search", isPresented: $showSaveDialog) {
            saveSearchAlert
        }
    }

    // MARK: - iPhone Layout

    private var iPhoneLayout: some View {
        NavigationStack {
            datasetSelectionContent
                .navigationTitle("Search")
                .navigationBarTitleDisplayMode(.inline)
                .navigationDestination(isPresented: Binding(
                    get: { viewModel.showSearchInput },
                    set: { viewModel.showSearchInput = $0 }
                )) {
                    searchDetailContent
                        .navigationTitle("Cross-Dataset Search")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            searchToolbarItems
                        }
                }
        }
        .onAppear {
            viewModel.setupWithModelContext(modelContext)
        }
        .sheet(isPresented: $showFilterListPicker) {
            FilterListPickerSheet(viewModel: viewModel, isPresented: $showFilterListPicker)
        }
        .alert("Save Search", isPresented: $showSaveDialog) {
            saveSearchAlert
        }
    }

    // MARK: - Toolbar Items (matches Android TopAppBar actions)

    @ToolbarContentBuilder
    private var searchToolbarItems: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Button {
                showFilterListPicker = true
            } label: {
                Image(systemName: "line.3.horizontal.decrease.circle")
            }

            Button {
                withAnimation { showSavedSearches.toggle() }
            } label: {
                Image(systemName: showSavedSearches ? "bookmark.fill" : "clock.arrow.circlepath")
            }

            if viewModel.searchResult != nil {
                Button {
                    showSaveDialog = true
                } label: {
                    Image(systemName: viewModel.currentSavedSearchId != nil ? "bookmark.fill" : "bookmark")
                }
            }
        }
    }

    // MARK: - Save Search Alert

    @State private var saveSearchName = ""

    @ViewBuilder
    private var saveSearchAlert: some View {
        TextField("Search name", text: $saveSearchName)
        Button("Save") {
            let name = saveSearchName.isEmpty ? "Search \(Date().formatted(date: .abbreviated, time: .shortened))" : saveSearchName
            viewModel.saveCurrentSearch(name: name)
            saveSearchName = ""
        }
        Button("Cancel", role: .cancel) {
            saveSearchName = ""
        }
    }

    // MARK: - Dataset Selection Content

    private var datasetSelectionContent: some View {
        VStack(spacing: 0) {
            Picker("View", selection: $viewModel.selectionTab) {
                Text("Sessions").tag(0)
                Text("Collections").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top, 8)

            HStack {
                Text("\(viewModel.selectedDatasetIds.count) selected")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button("All") { viewModel.selectAllDatasets() }
                    .font(.caption)
                Button("None") { viewModel.deselectAllDatasets() }
                    .font(.caption)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            if viewModel.selectionTab == 0 {
                sessionsContent
            } else {
                collectionsContent
            }

            if UIDevice.current.userInterfaceIdiom == .phone {
                Button {
                    viewModel.showSearchInput = true
                } label: {
                    HStack {
                        Text("Continue with \(viewModel.selectedDatasetIds.count) datasets")
                        Spacer()
                        Image(systemName: "magnifyingglass")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.selectedDatasetIds.isEmpty)
                .padding()
            }
        }
    }

    // MARK: - Sessions Content

    private var sessionsContent: some View {
        VStack(spacing: 0) {
            if viewModel.availableDatasets.isEmpty {
                VStack(spacing: 24) {
                    Image(systemName: "tray")
                        .font(.system(size: 64))
                        .foregroundColor(.secondary)
                    VStack(spacing: 8) {
                        Text("No Datasets")
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text("Download datasets first to search across them")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                List {
                    ForEach(viewModel.availableDatasets, id: \.linkId) { dataset in
                        SelectableDatasetRow(
                            dataset: dataset,
                            isSelected: viewModel.selectedDatasetIds.contains(dataset.linkId),
                            onToggle: { viewModel.toggleDatasetSelection(dataset.linkId) }
                        )
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    // MARK: - Collections Content

    private var collectionsContent: some View {
        VStack(spacing: 0) {
            if viewModel.collections.isEmpty {
                VStack(spacing: 24) {
                    Image(systemName: "folder")
                        .font(.system(size: 64))
                        .foregroundColor(.secondary)
                    VStack(spacing: 8) {
                        Text("No Collections")
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text("Collections group multiple curtain datasets together")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.collections, id: \.collectionId) { collection in
                            SelectableCollectionCard(
                                collection: collection,
                                viewModel: viewModel
                            )
                        }
                    }
                    .padding()
                }
            }
        }
    }

    // MARK: - Search Detail Content (matches Android SearchInputSection + saved searches)

    private var searchDetailContent: some View {
        VStack(spacing: 0) {
            // Saved searches panel (matches Android AnimatedVisibility SavedSearchesSection)
            if showSavedSearches {
                SavedSearchesPanel(viewModel: viewModel, showSavedSearches: $showSavedSearches)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    // Search input (matches Android OutlinedTextField)
                    TextEditor(text: $viewModel.searchInput)
                        .frame(minHeight: 80, maxHeight: 120)
                        .font(.body)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(.separator), lineWidth: 1)
                        )
                        .overlay(alignment: .topLeading) {
                            if viewModel.searchInput.isEmpty {
                                Text("Proteins (one per line)")
                                    .font(.body)
                                    .foregroundColor(Color(.placeholderText))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 10)
                                    .allowsHitTesting(false)
                            }
                        }

                    // Search type chips (matches Android FilterChip row)
                    HStack(spacing: 8) {
                        ForEach(SearchType.allCases, id: \.self) { type in
                            Button {
                                viewModel.searchType = type
                            } label: {
                                HStack(spacing: 4) {
                                    if viewModel.searchType == type {
                                        Image(systemName: "checkmark")
                                            .font(.caption2)
                                    }
                                    Text(type.displayName)
                                        .font(.caption)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(viewModel.searchType == type ? Color.accentColor.opacity(0.2) : Color(.systemGray5))
                                .foregroundColor(viewModel.searchType == type ? .accentColor : .primary)
                                .cornerRadius(16)
                            }
                        }

                        Spacer()

                        // Options toggle (matches Android settings icon)
                        Button {
                            withAnimation { viewModel.showAdvancedFiltering.toggle() }
                        } label: {
                            Image(systemName: viewModel.showAdvancedFiltering ? "chevron.up" : "gearshape")
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                    }

                    // Options card (matches Android AnimatedVisibility options card)
                    if viewModel.showAdvancedFiltering {
                        VStack(spacing: 0) {
                            HStack {
                                Text("Use Regex")
                                    .font(.subheadline)
                                Spacer()
                                Toggle("", isOn: $viewModel.useRegex)
                                    .labelsHidden()
                            }
                            .padding(.vertical, 8)

                            Divider()

                            HStack {
                                Text("Significant Only")
                                    .font(.subheadline)
                                Spacer()
                                Toggle("", isOn: $viewModel.significantOnly)
                                    .labelsHidden()
                            }
                            .padding(.vertical, 8)
                        }
                        .padding(.horizontal, 12)
                        .background(Color(.secondarySystemGroupedBackground))
                        .cornerRadius(10)
                    }

                    // Search button row (matches Android Row with dataset count + Search button)
                    HStack {
                        Text("\(viewModel.selectedDatasetIds.count) datasets selected")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.accentColor)

                        Spacer()

                        Button {
                            Task {
                                await viewModel.performSearch()
                            }
                        } label: {
                            HStack(spacing: 4) {
                                if viewModel.isSearching {
                                    ProgressView()
                                        .controlSize(.small)
                                        .tint(.white)
                                } else {
                                    Image(systemName: "magnifyingglass")
                                        .font(.caption)
                                }
                                Text(viewModel.isSearching ? "Searching..." : "Search")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(viewModel.isSearching || viewModel.searchInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.selectedDatasetIds.isEmpty)
                    }

                    // Processing status (matches Android DatasetProcessingStatusPanel)
                    if viewModel.isSearching && !viewModel.datasetStatuses.isEmpty {
                        DatasetProcessingStatusPanel(viewModel: viewModel)
                    }

                    // Error
                    if let error = viewModel.error {
                        ErrorView(message: error) {
                            viewModel.error = nil
                        }
                    }

                    // Empty state (matches Android EmptySearchState)
                    if viewModel.searchResult == nil && !viewModel.isSearching {
                        VStack(spacing: 16) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary)
                            Text("Search for proteins across datasets")
                                .font(.body)
                                .foregroundColor(.secondary)
                            Text("Enter gene names or protein IDs above")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                    }
                }
                .padding(12)
            }
        }
    }
}

// MARK: - Saved Searches Panel (matches Android SavedSearchesSection)

struct SavedSearchesPanel: View {
    @Bindable var viewModel: CrossDatasetSearchViewModel
    @Binding var showSavedSearches: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Saved Searches")
                    .font(.caption)
                    .fontWeight(.medium)
                Spacer()
                Text("\(viewModel.savedSearches.count) saved")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            if viewModel.savedSearches.isEmpty {
                Text("No saved searches")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(viewModel.savedSearches, id: \.searchId) { search in
                            SavedSearchRow(
                                search: search,
                                isSelected: viewModel.currentSavedSearchId == search.searchId,
                                onLoad: {
                                    viewModel.loadSavedSearch(search)
                                    showSavedSearches = false
                                },
                                onDelete: {
                                    viewModel.deleteSavedSearch(search.searchId)
                                }
                            )
                        }
                    }
                }
                .frame(maxHeight: 150)
            }
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(10)
    }
}

struct SavedSearchRow: View {
    let search: SavedCrossDatasetSearchEntity
    let isSelected: Bool
    let onLoad: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(search.name)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .medium : .regular)
                    .lineLimit(1)
                HStack(spacing: 8) {
                    Text("\(search.proteinCount) proteins")
                        .font(.caption2)
                        .foregroundColor(.accentColor)
                    Text("\(search.datasetCount) datasets")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(search.lastOpened, format: .dateTime.month(.abbreviated).day().hour().minute())
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Button(role: .destructive) {
                onDelete()
            } label: {
                Image(systemName: "trash")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundColor(.red)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color(.systemBackground))
        .cornerRadius(8)
        .contentShape(Rectangle())
        .onTapGesture { onLoad() }
    }
}

// MARK: - Selectable Dataset Row (matches UniversalCurtainRow)

struct SelectableDatasetRow: View {
    let dataset: CurtainEntity
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isSelected ? .accentColor : .secondary)
                .font(.title3)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(dataset.dataDescription.isEmpty ? dataset.linkId : dataset.dataDescription)
                        .font(.body)
                        .fontWeight(.medium)
                        .lineLimit(2)

                    Spacer()

                    if dataset.isPinned {
                        Image(systemName: "pin.fill")
                            .foregroundColor(.orange)
                            .font(.caption)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("ID: \(dataset.linkId.prefix(12))...")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    HStack(spacing: 8) {
                        Text(dataset.created, format: .dateTime.day().month().year())
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text(dataset.sourceHostname
                            .replacingOccurrences(of: "https://", with: "")
                            .replacingOccurrences(of: "http://", with: ""))
                            .font(.caption)
                            .foregroundColor(.blue)
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(8)
        .contentShape(Rectangle())
        .onTapGesture {
            onToggle()
        }
    }
}

// MARK: - Selectable Collection Card (matches CollectionCardView)

struct SelectableCollectionCard: View {
    let collection: CurtainCollectionEntity
    @Bindable var viewModel: CrossDatasetSearchViewModel

    private var isExpanded: Bool {
        viewModel.expandedCollectionIds.contains(collection.collectionId)
    }

    private var selectedInCollection: Int {
        viewModel.selectedCountInCollection(collection.collectionId)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            cardHeader
            if isExpanded {
                Divider()
                selectionToolbar
                Divider()
                sessionsContent
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    private var cardHeader: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(collection.name)
                    .font(.headline)
                    .lineLimit(2)

                if !collection.collectionDescription.isEmpty {
                    Text(collection.collectionDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                HStack(spacing: 8) {
                    let accessibleCount = collection.sessions.count
                    let totalCount = collection.curtainCount
                    if accessibleCount < totalCount {
                        Label("\(accessibleCount)/\(totalCount) sessions", systemImage: "doc.on.doc")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    } else {
                        Label("\(accessibleCount) sessions", systemImage: "doc.on.doc")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    Text(collection.sourceHostname
                        .replacingOccurrences(of: "https://", with: "")
                        .replacingOccurrences(of: "http://", with: ""))
                        .font(.caption2)
                        .foregroundColor(.blue)
                        .lineLimit(1)
                }
            }

            Spacer()

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.toggleCollectionExpanded(id: collection.collectionId)
                }
            } label: {
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .foregroundColor(.secondary)
                    .font(.body)
            }
        }
        .padding()
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                viewModel.toggleCollectionExpanded(id: collection.collectionId)
            }
        }
    }

    private var selectionToolbar: some View {
        HStack {
            Button("All") {
                viewModel.selectAllSessionsInCollection(collection.collectionId)
            }
            .font(.caption)

            Button("None") {
                viewModel.deselectAllSessionsInCollection(collection.collectionId)
            }
            .font(.caption)

            Spacer()

            Text("\(selectedInCollection)/\(collection.sessions.count) selected")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private var sessionsContent: some View {
        VStack(spacing: 0) {
            let sessions = viewModel.collectionSessions[collection.collectionId] ?? collection.sessions
            ForEach(sessions, id: \.linkId) { session in
                SelectableSessionRow(
                    session: session,
                    isSelected: viewModel.selectedDatasetIds.contains(session.linkId),
                    onToggle: { viewModel.toggleDatasetSelection(session.linkId) }
                )

                if session.linkId != sessions.last?.linkId {
                    Divider()
                        .padding(.leading, 48)
                }
            }
        }
    }
}

// MARK: - Selectable Session Row (matches CollectionSessionRowView)

struct SelectableSessionRow: View {
    let session: CollectionSessionEntity
    let isSelected: Bool
    let onToggle: () -> Void

    private var sessionDisplayName: String {
        if let name = session.sessionName, !name.isEmpty {
            return name
        }
        if !session.sessionDescription.isEmpty {
            return session.sessionDescription
        }
        return session.linkId
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isSelected ? .accentColor : .secondary)
                .font(.title3)

            VStack(alignment: .leading, spacing: 4) {
                Text(sessionDisplayName)
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(2)

                VStack(alignment: .leading, spacing: 2) {
                    Text("ID: \(session.linkId.prefix(12))...")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    HStack(spacing: 8) {
                        Text(session.created, format: .dateTime.day().month().year())
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text(session.sourceHostname
                            .replacingOccurrences(of: "https://", with: "")
                            .replacingOccurrences(of: "http://", with: ""))
                            .font(.caption)
                            .foregroundColor(.blue)
                            .lineLimit(1)

                        if let curtainType = session.curtainType {
                            Text(curtainType)
                                .font(.caption2)
                                .fontWeight(.medium)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.accentColor.opacity(0.15))
                                .cornerRadius(4)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .onTapGesture {
            onToggle()
        }
    }
}

// MARK: - Filter List Picker Sheet (matches Android FilterListPickerDialog)

struct FilterListPickerSheet: View {
    @Bindable var viewModel: CrossDatasetSearchViewModel
    @Binding var isPresented: Bool
    @State private var searchQuery = ""
    @State private var selectedCategory = "All"

    private var allCategories: [String] {
        let cats = Array(Set(viewModel.filterLists.map { $0.category })).sorted()
        return ["All"] + cats
    }

    private var filteredLists: [DataFilterListEntity] {
        viewModel.filterLists.filter { filterList in
            let matchesSearch = searchQuery.isEmpty ||
                filterList.name.localizedCaseInsensitiveContains(searchQuery) ||
                filterList.category.localizedCaseInsensitiveContains(searchQuery)
            let matchesCategory = selectedCategory == "All" || filterList.category == selectedCategory
            return matchesSearch && matchesCategory
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search field
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                    TextField("Search filter lists...", text: $searchQuery)
                        .font(.subheadline)
                    if !searchQuery.isEmpty {
                        Button {
                            searchQuery = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                }
                .padding(10)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal)
                .padding(.top, 8)

                // Category chips (matches Android LazyRow of FilterChips)
                if allCategories.count > 2 {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(allCategories, id: \.self) { category in
                                Button {
                                    selectedCategory = category
                                } label: {
                                    HStack(spacing: 4) {
                                        if selectedCategory == category {
                                            Image(systemName: "checkmark")
                                                .font(.caption2)
                                        }
                                        Text(category)
                                            .font(.caption)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(selectedCategory == category ? Color.accentColor.opacity(0.2) : Color(.systemGray5))
                                    .foregroundColor(selectedCategory == category ? .accentColor : .primary)
                                    .cornerRadius(16)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.top, 8)
                }

                // Count + info
                HStack {
                    Text("\(filteredLists.count) filter lists")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 4)

                // List (matches Android LazyColumn of Cards)
                if filteredLists.isEmpty {
                    VStack(spacing: 12) {
                        Text("No filter lists available")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("Sync filter lists from the Filters tab")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                } else {
                    List {
                        ForEach(filteredLists, id: \.apiId) { filterList in
                            Button {
                                viewModel.loadFilterListIntoSearch(filterList)
                                isPresented = false
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack(spacing: 8) {
                                            Text(filterList.name)
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                                .foregroundColor(.primary)
                                            if filterList.isDefault {
                                                Text("Curated")
                                                    .font(.caption2)
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 2)
                                                    .background(Color.accentColor.opacity(0.15))
                                                    .cornerRadius(4)
                                                    .foregroundColor(.accentColor)
                                            }
                                        }
                                        if !filterList.category.isEmpty {
                                            Text(filterList.category)
                                                .font(.caption)
                                                .foregroundColor(.accentColor)
                                        }
                                    }
                                    Spacer()
                                    Text("\(filterList.data.components(separatedBy: "\n").filter { !$0.isEmpty }.count)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Select Filter List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                    .fixedSize()
                }
            }
        }
        .presentationDetents([.medium, .large])
        .onAppear {
            viewModel.refreshFilterLists()
        }
    }
}

// MARK: - Dataset Processing Status Panel

struct DatasetProcessingStatusPanel: View {
    @Bindable var viewModel: CrossDatasetSearchViewModel
    @State private var expanded = true

    var body: some View {
        if !viewModel.datasetStatuses.isEmpty {
            let statuses = Array(viewModel.datasetStatuses.values).sorted { $0.datasetName < $1.datasetName }
            let completedCount = statuses.filter { $0.state == .completed }.count
            let failedCount = statuses.filter { $0.state == .failed }.count

            VStack(spacing: 0) {
                // Header (matches Android collapsible header)
                HStack {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Processing datasets...")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    Spacer()
                    HStack(spacing: 8) {
                        Text("\(completedCount)/\(statuses.count)")
                            .font(.caption2)
                            .foregroundColor(.accentColor)
                        if failedCount > 0 {
                            Text("\(failedCount) failed")
                                .font(.caption2)
                                .foregroundColor(.red)
                        }
                        Button {
                            withAnimation { expanded.toggle() }
                        } label: {
                            Image(systemName: expanded ? "chevron.up" : "chevron.down")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                if expanded {
                    VStack(spacing: 4) {
                        ForEach(statuses, id: \.id) { status in
                            HStack {
                                HStack(spacing: 8) {
                                    statusIcon(status.state)
                                    Text(status.datasetName.isEmpty ? "Untitled" : status.datasetName)
                                        .font(.caption)
                                        .lineLimit(1)
                                }
                                Spacer()
                                HStack(spacing: 4) {
                                    Text(status.state.rawValue.capitalized)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    if status.state == .loading || status.state == .building || status.state == .searching {
                                        ProgressView()
                                            .controlSize(.mini)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.top, 8)
                }
            }
            .padding(12)
            .background(Color(.secondarySystemGroupedBackground).opacity(0.5))
            .cornerRadius(10)
        }
    }

    @ViewBuilder
    private func statusIcon(_ state: ProcessingState) -> some View {
        switch state {
        case .pending:
            Image(systemName: "clock").foregroundColor(.secondary).font(.caption)
        case .loading:
            Image(systemName: "icloud.and.arrow.down").foregroundColor(.accentColor).font(.caption)
        case .building:
            Image(systemName: "hammer").foregroundColor(.orange).font(.caption)
        case .searching:
            Image(systemName: "magnifyingglass").foregroundColor(.secondary).font(.caption)
        case .completed:
            Image(systemName: "checkmark.circle.fill").foregroundColor(.green).font(.caption)
        case .failed:
            Image(systemName: "xmark.circle.fill").foregroundColor(.red).font(.caption)
        }
    }
}

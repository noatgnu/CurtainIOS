//
//  DataFilterListView.swift
//  Curtain
//
//  Created by Toan Phung on 02/08/2025.
//

import SwiftUI
import SwiftData


struct DataFilterListView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: DataFilterListViewModel?
    @State private var showingAddFilterSheet = false
    @State private var showingSyncProgress = false
    @State private var selectedCategory = "All"
    @State private var searchText = ""
    @State private var selectedHostname = CurtainConstants.PredefinedHosts.celsusBackend
    
    private var isWideLayout: Bool {
        UIDevice.current.userInterfaceIdiom == .pad || UIDevice.current.userInterfaceIdiom == .mac
    }

    var body: some View {
        if isWideLayout {
            mainBody
        } else {
            NavigationStack {
                mainBody
            }
        }
    }

    private var mainBody: some View {
        Group {
                if let viewModel = viewModel {
                    VStack(spacing: 0) {
                        // Host Selection
                        HostSelectionView(selectedHostname: $selectedHostname)
                        
                        // Category Filter
                        CategoryFilterView(
                            categories: viewModel.categories,
                            selectedCategory: $selectedCategory
                        )
                        
                        // Search Bar
                        SearchBar(text: $searchText)
                            .padding(.horizontal)
                        
                        if viewModel.isSyncing {
                            SyncProgressView(
                                progress: viewModel.getSyncProgressPercentage(),
                                currentCategory: viewModel.currentSyncCategory,
                                progressText: viewModel.getSyncProgressText()
                            )
                            .padding()
                        }
                        
                        // Error Message
                        if let error = viewModel.error {
                            ErrorView(message: error) {
                                viewModel.clearError()
                            }
                            .padding()
                        }
                        
                        // Main Content
                        if viewModel.isLoading && viewModel.filterLists.isEmpty {
                            ProgressView("Loading filter lists...")
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            FilterListContent(
                                filterLists: filteredLists,
                                viewModel: viewModel,
                                selectedHostname: selectedHostname,
                                showingAddSheet: $showingAddFilterSheet
                            )
                        }
                    }
                } else {
                    ProgressView("Setting up filters...")
                        .onAppear {
                            setupViewModel()
                        }
                }
            }
            .navigationTitle("Filter Lists")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Sync") {
                        Task {
                            await viewModel?.syncDataFilterLists(hostname: selectedHostname)
                        }
                    }
                    .disabled(viewModel?.isSyncing ?? true)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        showingAddFilterSheet = true
                    }
                    .disabled(viewModel == nil)
                }
            }
            .sheet(isPresented: $showingAddFilterSheet) {
                if let viewModel = viewModel {
                    AddFilterListSheet(viewModel: viewModel, hostname: selectedHostname)
                }
            }
        }

    // MARK: - Computed Properties
    
    private var filteredLists: [DataFilterListEntity] {
        guard let viewModel = viewModel else { return [] }
        var lists = viewModel.filterLists
        
        // Filter by category
        if selectedCategory != "All" {
            lists = lists.filter { $0.category == selectedCategory }
        }
        
        // Filter by search text
        if !searchText.isEmpty {
            lists = viewModel.searchFilterLists(searchText)
        }
        
        return lists
    }
    
    private func setupViewModel() {
        let repository = DataFilterListRepository(modelContext: modelContext)
        self.viewModel = DataFilterListViewModel(repository: repository)
    }
}

// MARK: - Supporting Views

struct HostSelectionView: View {
    @Binding var selectedHostname: String
    @Query private var siteSettings: [CurtainSiteSettings]

    private var hosts: [String] {
        let configured = siteSettings.filter { $0.isActive }.map { $0.hostname }
        if configured.isEmpty {
            return [CurtainConstants.PredefinedHosts.celsusBackend]
        }
        return configured
    }

    var body: some View {
        HStack {
            Text("Host:")
                .font(.caption)
                .foregroundColor(.secondary)

            Picker("Host", selection: $selectedHostname) {
                ForEach(hosts, id: \.self) { host in
                    Text(host).tag(host)
                }
            }
            .pickerStyle(MenuPickerStyle())

            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

struct CategoryFilterView: View {
    let categories: [String]
    @Binding var selectedCategory: String
    
    var allCategories: [String] {
        ["All"] + categories
    }
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(allCategories, id: \.self) { category in
                    CategoryChip(
                        title: category,
                        isSelected: selectedCategory == category
                    ) {
                        selectedCategory = category
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
    }
}

struct CategoryChip: View {
    let title: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Text(title)
            .font(.caption)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color.accentColor : Color(.secondarySystemFill))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(16)
            .onTapGesture(perform: onTap)
    }
}

struct SyncProgressView: View {
    let progress: Double
    let currentCategory: String?
    let progressText: String
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Syncing Filter Lists")
                    .font(.headline)
                Spacer()
                Text(String(format: "%.0f%%", progress))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            ProgressView(value: progress, total: 100)
                .progressViewStyle(LinearProgressViewStyle())
            
            if !progressText.isEmpty {
                Text(progressText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBlue).opacity(0.1))
        .cornerRadius(8)
    }
}

struct FilterListContent: View {
    let filterLists: [DataFilterListEntity]
    let viewModel: DataFilterListViewModel
    let selectedHostname: String
    @Binding var showingAddSheet: Bool
    
    var body: some View {
        List {
            // Default Filter Lists Section
            let defaultLists = filterLists.filter { $0.isDefault }
            if !defaultLists.isEmpty {
                Section("Default Filter Lists") {
                    ForEach(defaultLists, id: \.id) { filterList in
                        FilterListRowView(
                            filterList: filterList,
                            viewModel: viewModel,
                            selectedHostname: selectedHostname
                        )
                    }
                }
            }
            
            // User Filter Lists Section
            let userLists = filterLists.filter { !$0.isDefault }
            if !userLists.isEmpty {
                Section("User Filter Lists") {
                    ForEach(userLists, id: \.id) { filterList in
                        FilterListRowView(
                            filterList: filterList,
                            viewModel: viewModel,
                            selectedHostname: selectedHostname
                        )
                    }
                }
            }
            
            if filterLists.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)
                    
                    Text("No Filter Lists")
                        .font(.title2)
                        .fontWeight(.medium)
                    
                    Text("Tap \"Sync\" to load filter lists from the server, or \"Add\" to create a custom filter list")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    HStack(spacing: 12) {
                        Button("Sync from Server") {
                            Task {
                                await viewModel.syncDataFilterLists(hostname: selectedHostname)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(viewModel.isSyncing)
                        
                        Button("Add Custom") {
                            showingAddSheet = true
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            }
        }
        .scrollContentBackground(.hidden)
        .refreshable {
            // Only refresh local data, don't auto-sync with server
            viewModel.loadDataFilterLists()
        }
    }
}

struct FilterListRowView: View {
    let filterList: DataFilterListEntity
    let viewModel: DataFilterListViewModel
    let selectedHostname: String
    
    @State private var showingEditSheet = false
    @State private var showingExportSheet = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(filterList.name)
                        .font(.headline)
                        .lineLimit(1)
                    
                    if !filterList.category.isEmpty {
                        Text("Category: \(filterList.category)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text("\(filterList.data.components(separatedBy: "\n").count) items")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if filterList.isDefault {
                    Image(systemName: "star.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                }
            }
        }
        .contentShape(Rectangle())
        .contextMenu {
            if !filterList.isDefault {
                Button("Edit") {
                    showingEditSheet = true
                }
            }
            
            Button("Export") {
                showingExportSheet = true
            }
            
            if !filterList.isDefault {
                Button("Delete", role: .destructive) {
                    Task {
                        await viewModel.deleteDataFilterList(
                            hostname: selectedHostname,
                            filterList: filterList
                        )
                    }
                }
            }
        }
        .swipeActions(edge: .trailing) {
            if !filterList.isDefault {
                Button("Delete", role: .destructive) {
                    Task {
                        await viewModel.deleteDataFilterList(
                            hostname: selectedHostname,
                            filterList: filterList
                        )
                    }
                }
                
                Button("Edit") {
                    showingEditSheet = true
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            EditFilterListSheet(
                filterList: filterList,
                viewModel: viewModel,
                hostname: selectedHostname
            )
        }
        .sheet(isPresented: $showingExportSheet) {
            ExportFilterListSheet(filterList: filterList, viewModel: viewModel)
        }
    }
}

// MARK: - Sheet Views

struct AddFilterListSheet: View {
    @Environment(\.dismiss) private var dismiss
    let viewModel: DataFilterListViewModel
    let hostname: String
    
    @State private var name = ""
    @State private var category = ""
    @State private var data = ""
    @State private var isDefault = false
    
    var body: some View {
        NavigationView {
            Form {
                Section("Filter List Information") {
                    TextField("Name", text: $name)
                    TextField("Category", text: $category)
                    Toggle("Default List", isOn: $isDefault)
                }
                
                Section("Filter Data") {
                    TextField("Enter filter data (one item per line)", text: $data, axis: .vertical)
                        .lineLimit(5...10)
                }
            }
            .navigationTitle("Add Filter List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        Task {
                            await viewModel.createDataFilterList(
                                hostname: hostname,
                                name: name,
                                category: category,
                                data: data,
                                isDefault: isDefault
                            )
                            dismiss()
                        }
                    }
                    .disabled(name.isEmpty || category.isEmpty || data.isEmpty)
                }
            }
        }
    }
}

struct EditFilterListSheet: View {
    @Environment(\.dismiss) private var dismiss
    let filterList: DataFilterListEntity
    let viewModel: DataFilterListViewModel
    let hostname: String
    
    @State private var name: String
    @State private var category: String
    @State private var data: String
    @State private var isDefault: Bool
    
    init(filterList: DataFilterListEntity, viewModel: DataFilterListViewModel, hostname: String) {
        self.filterList = filterList
        self.viewModel = viewModel
        self.hostname = hostname
        
        _name = State(initialValue: filterList.name)
        _category = State(initialValue: filterList.category)
        _data = State(initialValue: filterList.data)
        _isDefault = State(initialValue: filterList.isDefault)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Filter List Information") {
                    TextField("Name", text: $name)
                    TextField("Category", text: $category)
                    Toggle("Default List", isOn: $isDefault)
                }
                
                Section("Filter Data") {
                    TextField("Enter filter data (one item per line)", text: $data, axis: .vertical)
                        .lineLimit(5...10)
                }
            }
            .navigationTitle("Edit Filter List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task {
                            await viewModel.updateDataFilterList(
                                hostname: hostname,
                                id: filterList.apiId,
                                name: name,
                                category: category,
                                data: data,
                                isDefault: isDefault
                            )
                            dismiss()
                        }
                    }
                }
            }
        }
    }
}

struct ExportFilterListSheet: View {
    @Environment(\.dismiss) private var dismiss
    let filterList: DataFilterListEntity
    let viewModel: DataFilterListViewModel
    
    @State private var exportData = ""
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Export Filter List")
                    .font(.headline)
                    .padding()
                
                ScrollView {
                    Text(exportData)
                        .font(.system(.body, design: .monospaced))
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .padding()
                }
                
                Button("Copy to Clipboard") {
                    UIPasteboard.general.string = exportData
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .onAppear {
            exportData = viewModel.exportFilterListData(filterList) ?? "Export failed"
        }
    }
}

#Preview {
    DataFilterListView()
}
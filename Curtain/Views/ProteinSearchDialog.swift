//
//  ProteinSearchDialog.swift
//  Curtain
//
//  Created by Toan Phung on 04/08/2025.
//

import SwiftUI
import SwiftData


struct ProteinSearchDialog: View {
    @Binding var curtainData: CurtainData
    @ObservedObject var searchManager: ProteinSearchManager
    @Binding var isPresented: Bool
    @Environment(\.modelContext) private var modelContext
    
    @State private var searchName = ""
    @State private var searchText = ""
    @State private var selectedSearchType: SearchType = .primaryID
    @State private var isTypeaheadMode = true
    @State private var typeaheadQuery = ""
    @State private var typeaheadSuggestions: [TypeaheadSuggestion] = []
    @State private var isLoadingSuggestions = false
    @State private var showingBulkInput = false
    
    // Data filter list functionality
    @State private var showingFilterListPicker = false
    @State private var filterListSearchQuery = ""
    @State private var availableFilterLists: [DataFilterListEntity] = []
    
    // Debouncing for typeahead
    @State private var searchTask: Task<Void, Never>?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with mode toggle
                headerView
                
                // Search type picker
                searchTypePicker
                
                // Main content area
                if isTypeaheadMode {
                    typeaheadSearchView
                } else {
                    bulkInputView
                }
                
                // Search progress (when loading)
                if searchManager.isLoading {
                    searchProgressView
                }
                
                Spacer()
                
                // Action buttons
                actionButtonsView
            }
            .navigationTitle("Protein Search")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    isPresented = false
                },
                trailing: Button("Done") {
                    performSearch()
                    isPresented = false
                }
                .disabled(!canPerformSearch)
            )
        }
        .onChange(of: typeaheadQuery) { oldValue, newValue in
            performTypeaheadSearch(query: newValue)
        }
        .onAppear {
            loadDataFilterLists()
        }
        .sheet(isPresented: $showingFilterListPicker) {
            DataFilterListPickerView(
                availableFilterLists: filteredDataFilterLists,
                searchQuery: $filterListSearchQuery,
                onFilterListSelected: { filterList in
                    importDataFilterList(filterList)
                    showingFilterListPicker = false
                }
            )
        }
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        VStack(spacing: 16) {
            // Search name input
            VStack(alignment: .leading, spacing: 8) {
                Text("Search List Name")
                    .font(.headline)
                
                TextField("Enter search list name...", text: $searchName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            
            Picker("Search Mode", selection: $isTypeaheadMode) {
                Text("Typeahead").tag(true)
                Text("Bulk Input").tag(false)
            }
            .pickerStyle(SegmentedPickerStyle())
        }
        .padding()
        .background(Color(.systemGray6))
    }
    
    // MARK: - Search Type Picker
    
    private var searchTypePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Search Type")
                .font(.headline)
                .padding(.horizontal)
            
            Picker("Search Type", selection: $selectedSearchType) {
                ForEach(SearchType.allCases, id: \.self) { type in
                    Text(type.displayName).tag(type)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)
        }
        .padding(.vertical)
    }
    
    // MARK: - Typeahead Search View
    
    private var typeaheadSearchView: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Search Terms (Typeahead)")
                    .font(.headline)
                    .padding(.horizontal)
                
                HStack {
                    TextField("Start typing to search...", text: $typeaheadQuery)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    if isLoadingSuggestions {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
                .padding(.horizontal)
            }
            
            if !typeaheadSuggestions.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Suggestions")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                    
                    ScrollView {
                        LazyVStack(spacing: 4) {
                            ForEach(typeaheadSuggestions.indices, id: \.self) { index in
                                suggestionRow(typeaheadSuggestions[index])
                            }
                        }
                        .padding(.horizontal)
                    }
                    .frame(maxHeight: 300)
                }
            }
            
            // Selected terms display
            if !searchText.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Selected Terms")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .padding(.horizontal)
                    
                    ScrollView {
                        Text(searchText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                            .padding(.horizontal)
                    }
                    .frame(maxHeight: 120)
                }
            }
        }
    }
    
    private func suggestionRow(_ suggestion: TypeaheadSuggestion) -> some View {
        Button(action: {
            addSuggestionToSearch(suggestion)
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(suggestion.text)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    HStack {
                        Text(suggestion.searchType.displayName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(suggestion.matchType.capitalized)
                            .font(.caption)
                            .foregroundColor(suggestion.matchType == "exact" ? .green : .orange)
                    }
                }
                
                Spacer()
                
                Image(systemName: "plus.circle")
                    .foregroundColor(.blue)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color(.systemBackground))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Bulk Input View
    
    private var bulkInputView: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Data filter list selection
            VStack(alignment: .leading, spacing: 8) {
                Text("Import from Data Filter List")
                    .font(.headline)
                    .padding(.horizontal)
                
                Button(action: {
                    showingFilterListPicker = true
                }) {
                    HStack {
                        Image(systemName: "list.bullet")
                        Text("Select Data Filter List")
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
                .padding(.horizontal)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Search Terms (Bulk Input)")
                    .font(.headline)
                    .padding(.horizontal)
                
                Text("Enter one search term per line. Semicolon-separated terms on the same line will be grouped.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                
                TextEditor(text: $searchText)
                    .frame(minHeight: 200)
                    .padding(8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    .padding(.horizontal)
            }
            
        }
    }
    
    // MARK: - Search Progress View
    
    private var searchProgressView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.2)
            
            if !searchManager.searchProgress.isEmpty {
                Text(searchManager.searchProgress)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            if searchManager.proteinsFound > 0 {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.blue)
                    Text("\(searchManager.proteinsFound) proteins found")
                        .font(.headline)
                        .foregroundColor(.blue)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    // MARK: - Action Buttons
    
    private var actionButtonsView: some View {
        HStack(spacing: 16) {
            Button("Clear") {
                clearSearch()
            }
            .foregroundColor(.red)
            
            Spacer()
            
            Button("Search") {
                performSearch()
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canPerformSearch || searchManager.isLoading)
        }
        .padding()
    }
    
    // MARK: - Helper Methods
    
    private var canPerformSearch: Bool {
        return !searchName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
               !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private func performTypeaheadSearch(query: String) {
        // Cancel previous search task
        searchTask?.cancel()
        
        guard query.count >= 2 else {
            typeaheadSuggestions = []
            return
        }
        
        searchTask = Task {
            isLoadingSuggestions = true
            
            try? await Task.sleep(nanoseconds: 300_000_000)
            
            if !Task.isCancelled {
                let suggestions = await searchManager.performTypeaheadSearch(
                    query: query,
                    searchType: selectedSearchType,
                    curtainData: curtainData
                )
                
                await MainActor.run {
                    if !Task.isCancelled {
                        typeaheadSuggestions = suggestions
                        isLoadingSuggestions = false
                    }
                }
            }
        }
    }
    
    private func addSuggestionToSearch(_ suggestion: TypeaheadSuggestion) {
        let currentTerms = searchText.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        if !currentTerms.contains(suggestion.text) {
            if searchText.isEmpty {
                searchText = suggestion.text
            } else {
                searchText += "\n" + suggestion.text
            }
        }
        
        // Clear typeahead query after selection
        typeaheadQuery = ""
        typeaheadSuggestions = []
    }
    
    private func clearSearch() {
        searchText = ""
        typeaheadQuery = ""
        typeaheadSuggestions = []
    }
    
    private func performSearch() {
        guard canPerformSearch else { return }
        
        Task {
            var localCurtainData = curtainData
            let searchList = await searchManager.createSearchList(
                name: searchName.trimmingCharacters(in: .whitespacesAndNewlines),
                searchText: searchText,
                searchType: selectedSearchType,
                curtainData: &localCurtainData,
                description: nil
            )
            
            // Update the binding with the modified data and close dialog if successful
            await MainActor.run {
                curtainData = localCurtainData
                
                // Only close if search was successful
                if searchList != nil {
                    // Add a small delay to show the "Search completed!" message
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        isPresented = false
                    }
                }
            }
        }
    }
    
    // MARK: - Data Filter List Support
    
    private var filteredDataFilterLists: [DataFilterListEntity] {
        if filterListSearchQuery.isEmpty {
            return availableFilterLists
        } else {
            return availableFilterLists.filter { filterList in
                filterList.name.localizedCaseInsensitiveContains(filterListSearchQuery) ||
                filterList.category.localizedCaseInsensitiveContains(filterListSearchQuery)
            }
        }
    }
    
    private func loadDataFilterLists() {
        let repository = DataFilterListRepository(modelContext: modelContext)
        availableFilterLists = repository.getAllDataFilterLists()
    }
    
    private func importDataFilterList(_ filterList: DataFilterListEntity) {
        // Replace search text with filter list data
        searchText = filterList.data
        
        // Replace search list name with filter list name
        searchName = filterList.name
    }
}

// MARK: - Data Filter List Picker View

struct DataFilterListPickerView: View {
    let availableFilterLists: [DataFilterListEntity]
    @Binding var searchQuery: String
    let onFilterListSelected: (DataFilterListEntity) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search bar
                FilterListSearchBar(text: $searchQuery)
                    .padding()
                
                // Filter lists
                if availableFilterLists.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        
                        Text("No Filter Lists Found")
                            .font(.title2)
                            .fontWeight(.medium)
                        
                        Text(searchQuery.isEmpty ? 
                             "No data filter lists are available. You can create them in the Data Filter Lists section." :
                             "No filter lists match your search query."
                        )
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(availableFilterLists, id: \.id) { filterList in
                            FilterListPickerRow(
                                filterList: filterList,
                                onTap: {
                                    onFilterListSelected(filterList)
                                }
                            )
                        }
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("Select Filter List")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                trailing: Button("Cancel") {
                    dismiss()
                }
            )
        }
    }
}

struct FilterListPickerRow: View {
    let filterList: DataFilterListEntity
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(filterList.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    HStack {
                        Text("Category: \(filterList.category)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("\(filterList.data.components(separatedBy: "\n").count) items")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                HStack {
                    if filterList.isDefault {
                        Image(systemName: "star.fill")
                            .foregroundColor(.orange)
                            .font(.caption)
                    }
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct FilterListSearchBar: View {
    @Binding var text: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("Search filter lists...", text: $text)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            if !text.isEmpty {
                Button("Clear") {
                    text = ""
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
        }
    }
}
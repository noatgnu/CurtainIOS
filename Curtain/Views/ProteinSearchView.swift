//
//  ProteinSearchView.swift
//  Curtain
//
//  Created by Toan Phung on 04/08/2025.
//

import SwiftUI


struct ProteinSearchView: View {
    @Binding var curtainData: CurtainData
    @StateObject private var searchManager = ProteinSearchManager()
    @State private var showingSearchDialog = false
    @State private var showingExportSheet = false
    @State private var exportContent = ""
    @State private var editingSearchListId: String?
    @State private var newSearchListName = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search controls header
                headerView
                
                // Search lists
                if searchManager.searchSession.searchLists.isEmpty {
                    emptyStateView
                } else {
                    searchListsView
                }
            }
            .navigationTitle("Protein Search")
            .navigationBarItems(
                trailing: Button("New Search") {
                    showingSearchDialog = true
                }
            )
        }
        .sheet(isPresented: $showingSearchDialog) {
            ProteinSearchDialog(
                curtainData: $curtainData,
                searchManager: searchManager,
                isPresented: $showingSearchDialog
            )
        }
        .sheet(isPresented: $showingExportSheet) {
            ShareSheet(activityItems: [exportContent])
        }
        .onAppear {
            // Restore search lists from CurtainData 
            searchManager.restoreSearchListsFromCurtainData(curtainData: curtainData)
        }
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        VStack(spacing: 16) {
            // Active filters count
            if !searchManager.searchSession.activeFilters.isEmpty {
                HStack {
                    Text("\(searchManager.searchSession.activeFilters.count) active filter(s)")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                    
                    Spacer()
                    
                    Button("Clear All") {
                        for searchList in searchManager.searchSession.searchLists {
                            searchManager.toggleSearchListFilter(id: searchList.id, curtainData: &curtainData)
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.red)
                }
                .padding(.horizontal)
            }
            
            // Bulk actions
            if !searchManager.searchSession.searchLists.isEmpty {
                HStack(spacing: 16) {
                    Button("Select All") {
                        for searchList in searchManager.searchSession.searchLists {
                            if !searchManager.searchSession.activeFilters.contains(searchList.id) {
                                searchManager.toggleSearchListFilter(id: searchList.id, curtainData: &curtainData)
                            }
                        }
                    }
                    .font(.caption)
                    
                    Button("Deselect All") {
                        for searchList in searchManager.searchSession.searchLists {
                            if searchManager.searchSession.activeFilters.contains(searchList.id) {
                                searchManager.toggleSearchListFilter(id: searchList.id, curtainData: &curtainData)
                            }
                        }
                    }
                    .font(.caption)
                    
                    Spacer()
                    
                    Button("Export All") {
                        exportContent = searchManager.exportAllSearchLists()
                        showingExportSheet = true
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                    .disabled(searchManager.searchSession.searchLists.isEmpty)
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
        .background(Color(.systemGray6))
    }
    
    // MARK: - Empty State View
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "magnifyingglass.circle")
                .font(.system(size: 64))
                .foregroundColor(.gray)
            
            Text("No Search Lists")
                .font(.title2)
                .fontWeight(.medium)
            
            Text("Create search lists to filter and highlight proteins in your data visualizations.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Button("Create First Search") {
                showingSearchDialog = true
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Search Lists View
    
    private var searchListsView: some View {
        List {
            ForEach(searchManager.searchSession.searchLists, id: \.id) { searchList in
                searchListRow(searchList)
            }
            .onDelete(perform: deleteSearchLists)
        }
        .listStyle(PlainListStyle())
    }
    
    private func searchListRow(_ searchList: SearchList) -> some View {
        HStack(spacing: 12) {
            // Filter toggle button
            Button(action: {
                searchManager.toggleSearchListFilter(id: searchList.id, curtainData: &curtainData)
            }) {
                Image(systemName: searchManager.searchSession.activeFilters.contains(searchList.id) ? "checkmark.square.fill" : "square")
                    .foregroundColor(searchManager.searchSession.activeFilters.contains(searchList.id) ? .blue : .gray)
                    .font(.title3)
            }
            .buttonStyle(PlainButtonStyle())
            
            // Color indicator
            Circle()
                .fill(Color(hex: searchList.color) ?? .gray)
                .frame(width: 16, height: 16)
            
            // Search list info
            VStack(alignment: .leading, spacing: 4) {
                if editingSearchListId == searchList.id {
                    TextField("Search list name", text: $newSearchListName, onCommit: {
                        searchManager.renameSearchList(id: searchList.id, newName: newSearchListName, curtainData: &curtainData)
                        editingSearchListId = nil
                    })
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                } else {
                    Text(searchList.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .onTapGesture(count: 2) {
                            editingSearchListId = searchList.id
                            newSearchListName = searchList.name
                        }
                }
                
                Text("\(searchList.proteinIds.count) proteins")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Action buttons
            VStack(spacing: 8) {
                Button(action: {
                    exportContent = searchManager.exportSearchList(searchList)
                    showingExportSheet = true
                }) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
        }
        .padding(.vertical, 8)
        .contextMenu {
            Button("Rename") {
                editingSearchListId = searchList.id
                newSearchListName = searchList.name
            }
            
            Button("Export") {
                exportContent = searchManager.exportSearchList(searchList)
                showingExportSheet = true
            }
            
            Button("Duplicate") {
                let duplicatedList = SearchList(
                    name: "\(searchList.name) Copy",
                    proteinIds: searchList.proteinIds,
                    searchTerms: searchList.searchTerms,
                    searchType: searchList.searchType,
                    color: searchList.color
                )
                searchManager.searchSession.searchLists.append(duplicatedList)
                searchManager.saveSearchListsToCurtainData(curtainData: &curtainData)
            }
            
            Divider()
            
            Button("Delete", role: .destructive) {
                searchManager.removeSearchList(id: searchList.id, curtainData: &curtainData)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func deleteSearchLists(offsets: IndexSet) {
        for index in offsets {
            let searchList = searchManager.searchSession.searchLists[index]
            searchManager.removeSearchList(id: searchList.id, curtainData: &curtainData)
        }
    }
}

// MARK: - Color Extension

extension Color {
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
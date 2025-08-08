//
//  CurtainListView.swift
//  Curtain
//
//  Created by Toan Phung on 02/08/2025.
//

import SwiftUI
import SwiftData

// MARK: - CurtainListView (Based on Android CurtainListFragment.kt)

struct CurtainListView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = CurtainViewModel()
    @State private var showingAddCurtainSheet = false
    @State private var showingEditDescriptionSheet = false
    @State private var selectedCurtain: CurtainEntity?
    @State private var searchText = ""
    @State private var curtainForDetails: CurtainEntity? // Use item-based sheet presentation
    @State private var showingDeleteConfirmation = false
    @State private var curtainToDelete: CurtainEntity?
    @State private var toastMessage: String?
    @State private var showingToast = false
    @State private var showingDownloadConfirmation = false
    @State private var curtainToDownload: CurtainEntity?
    
    var body: some View {
        NavigationView {
            ZStack {
                VStack(spacing: 0) {
                    // Search Bar
                    SearchBar(text: $searchText)
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                    
                    // Download Progress Indicator (Like Android)
                    if viewModel.isDownloading {
                        DownloadProgressView(
                            progress: viewModel.downloadProgress,
                            speed: viewModel.downloadSpeed,
                            onCancel: {
                                viewModel.cancelDownload()
                            }
                        )
                        .padding()
                        .background(Color(.systemGray6))
                    }
                    
                    // Error Message
                    if let error = viewModel.error {
                        ErrorView(message: error) {
                            viewModel.clearError()
                        }
                        .padding()
                    }
                    
                    // Main Content
                    if viewModel.isLoading && viewModel.curtains.isEmpty {
                        // Initial Loading
                        ProgressView("Loading curtains...")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if viewModel.curtains.isEmpty && !viewModel.isLoading {
                        // Empty State (Like Android)
                        EmptyStateView(onLoadExample: {
                            Task {
                                await viewModel.loadExampleCurtain()
                            }
                        })
                    } else {
                        // Curtain List with Pagination (Like Android)
                        CurtainListContent(
                            curtains: filteredCurtains,
                            viewModel: viewModel,
                            onCurtainTap: handleCurtainTap,
                            onEditDescription: { curtain in
                                selectedCurtain = curtain
                                showingEditDescriptionSheet = true
                            },
                            onDelete: { curtain in
                                // Show confirmation dialog like Android
                                curtainToDelete = curtain
                                showingDeleteConfirmation = true
                            },
                            onTogglePin: { curtain in
                                viewModel.updatePinStatus(curtain, isPinned: !curtain.isPinned)
                                showToast(curtain.isPinned ? "Unpinned curtain" : "Pinned curtain")
                            }
                        )
                        
                        // Pagination Info (Like Android)
                        if !viewModel.curtains.isEmpty {
                            Text(viewModel.getPaginationInfo())
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding()
                        }
                    }
                }
                
                // Floating Action Button (Like Android)
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: {
                            print("🔵 CurtainListView: + button tapped, showing AddCurtainSheet")
                            showingAddCurtainSheet = true
                        }) {
                            Image(systemName: "plus")
                                .font(.title2)
                                .foregroundColor(.white)
                                .frame(width: 56, height: 56)
                                .background(Color.blue)
                                .clipShape(Circle())
                                .shadow(radius: 4)
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Curtain Datasets")
            .navigationBarTitleDisplayMode(.large)
            .navigationBarItems(trailing:
                Menu {
                    Button("Sync All", action: syncAllCurtains)
                    Button("Refresh", action: refreshCurtains)
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            )
            .sheet(isPresented: $showingAddCurtainSheet) {
                AddCurtainSheet(viewModel: viewModel)
            }
            .sheet(isPresented: $showingEditDescriptionSheet) {
                if let curtain = selectedCurtain {
                    EditDescriptionSheet(curtain: curtain, viewModel: viewModel)
                }
            }
            .sheet(item: $curtainForDetails) { curtain in
                VStack {
                    HStack {
                        Button("Close") {
                            curtainForDetails = nil
                        }
                        Spacer()
                        Text("Details")
                            .font(.headline)
                        Spacer()
                    }
                    .padding()
                    
                    CurtainDetailsView(curtain: curtain)
                }
                .onAppear {
                    print("🟢 CurtainListView: Sheet appeared with curtain: \(curtain.linkId)")
                }
            }
            .alert("Delete Curtain", isPresented: $showingDeleteConfirmation, presenting: curtainToDelete) { curtain in
                Button("Delete", role: .destructive) {
                    viewModel.deleteCurtain(curtain)
                    showToast("Curtain deleted")
                }
                Button("Cancel", role: .cancel) { }
            } message: { curtain in
                Text("Are you sure you want to delete this curtain?\n\nID: \(curtain.linkId)\nDescription: \(curtain.dataDescription.isEmpty ? "No description" : curtain.dataDescription)")
            }
            .alert("Download Data", isPresented: $showingDownloadConfirmation, presenting: curtainToDownload) { curtain in
                Button("Download") {
                    Task {
                        do {
                            print("🔄 CurtainListView: Starting download...")
                            _ = try await viewModel.downloadCurtainData(curtain)
                            print("✅ CurtainListView: Download completed successfully")
                            // After successful download, navigate to details
                            await MainActor.run {
                                // Refresh the curtains list to ensure we have the updated entity
                                viewModel.loadCurtains()
                                
                                // Find the refreshed entity and set it for the details view
                                if let refreshedCurtain = viewModel.curtains.first(where: { $0.linkId == curtain.linkId }) {
                                    curtainForDetails = refreshedCurtain
                                    print("🟢 CurtainListView: Opening details view after download for: \(refreshedCurtain.linkId)")
                                } else {
                                    print("❌ CurtainListView: Could not find refreshed curtain with linkId: \(curtain.linkId)")
                                    // Optionally show an error to the user
                                }
                            }
                        } catch {
                            print("❌ CurtainListView: Download failed with error: \(error)")
                            // Error is handled by viewModel
                        }
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: { curtain in
                Text("This dataset needs to be downloaded to view its details.\n\nDataset: \(curtain.dataDescription)\nID: \(curtain.linkId)\nHost: \(curtain.sourceHostname)\n\nWould you like to download it now?")
            }
            .overlay(alignment: .top) {
                if showingToast, let message = toastMessage {
                    ToastView(message: message)
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                withAnimation {
                                    showingToast = false
                                }
                            }
                        }
                }
            }
            .onAppear {
                print("🟢 CurtainListView: onAppear called")
                // Setup ViewModel with proper ModelContext and load data
                viewModel.setupWithModelContext(modelContext)
                print("🟢 CurtainListView: ViewModel setup completed, curtains count: \(viewModel.curtains.count)")
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var filteredCurtains: [CurtainEntity] {
        if searchText.isEmpty {
            return viewModel.curtains
        } else {
            return viewModel.searchCurtains(searchText)
        }
    }
    
    // MARK: - Action Methods
    
    private func handleCurtainTap(_ curtain: CurtainEntity) {
        print("🟡 CurtainListView: handleCurtainTap called for curtain: \(curtain.dataDescription)")
        print("🟡 CurtainListView: curtain.file = \(curtain.file ?? "nil")")
        
        // Capture the linkId early to avoid any potential entity invalidation issues
        let curtainLinkId = curtain.linkId
        print("🔍 CurtainListView: Captured linkId: \(curtainLinkId)")
        
        // Check if we're running in simulator
        #if targetEnvironment(simulator)
        let isSimulator = true
        #else
        let isSimulator = false
        #endif
        
        // Always construct the current path based on current Documents directory
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let curtainDataDir = documentsURL.appendingPathComponent("CurtainData", isDirectory: true)
        let currentFilePath = curtainDataDir.appendingPathComponent("\(curtainLinkId).json").path
        
        print("🔍 CurtainListView: Checking file at current path: \(currentFilePath)")
        
        let fileExistsAtCurrentPath = FileManager.default.fileExists(atPath: currentFilePath)
        
        print("🔍 CurtainListView: File exists at current path: \(fileExistsAtCurrentPath)")
        print("🔍 CurtainListView: Is simulator: \(isSimulator)")
        
        if let oldFilePath = curtain.file {
            print("🔍 CurtainListView: Old file path in database: \(oldFilePath)")
        }
        
        if fileExistsAtCurrentPath {
            print("🟢 CurtainListView: File exists at current path")
            
            // Update the database synchronously if file path needs updating
            if curtain.file != currentFilePath {
                print("🔄 CurtainListView: File path needs updating (sync update)")
                curtain.file = currentFilePath
                do {
                    try modelContext.save()
                    print("🟢 CurtainListView: Sync file path update completed")
                } catch {
                    print("❌ CurtainListView: Failed to update file path: \(error)")
                }
            }
            
            // Store the entity that will be used by the sheet
            print("🔍 CurtainListView: Setting curtainForDetails entity")
            curtainForDetails = curtain
            
        } else if isSimulator || curtain.file == nil {
            print("🔴 CurtainListView: File not found or running in simulator - asking user to download")
            // File missing or we're in simulator - ask user to download
            curtainToDownload = curtain
            showingDownloadConfirmation = true
            
        } else {
            print("🔴 CurtainListView: File path exists in database but file not found - asking user to redownload")
            // File path is set but file doesn't exist - ask user to redownload
            curtainToDownload = curtain
            showingDownloadConfirmation = true
        }
    }
    
    private func syncAllCurtains() {
        // Get active site settings and sync
        let siteSettings = viewModel.getActiveSiteSettings()
        for site in siteSettings {
            Task {
                await viewModel.syncCurtains(hostname: site.hostname)
            }
        }
    }
    
    private func refreshCurtains() {
        viewModel.loadCurtains()
    }
    
    private func showToast(_ message: String) {
        toastMessage = message
        withAnimation {
            showingToast = true
        }
    }
}

// MARK: - CurtainListContent (Like Android RecyclerView)

struct CurtainListContent: View {
    let curtains: [CurtainEntity]
    let viewModel: CurtainViewModel
    let onCurtainTap: (CurtainEntity) -> Void
    let onEditDescription: (CurtainEntity) -> Void
    let onDelete: (CurtainEntity) -> Void
    let onTogglePin: (CurtainEntity) -> Void
    
    var body: some View {
        List {
            ForEach(curtains, id: \.linkId) { curtain in
                CurtainRowView(
                    curtain: curtain,
                    onTap: { onCurtainTap(curtain) },
                    onEditDescription: { onEditDescription(curtain) },
                    onDelete: { onDelete(curtain) },
                    onTogglePin: { onTogglePin(curtain) },
                    onRedownload: {
                        Task {
                            do {
                                _ = try await viewModel.redownloadCurtainData(curtain)
                            } catch {
                                // Error handled by viewModel
                            }
                        }
                    }
                )
            }
            
            // Load More Button (Like Android pagination)
            if viewModel.hasMoreCurtains() || viewModel.isLoadingMore {
                LoadMoreView(
                    isLoading: viewModel.isLoadingMore,
                    hasMoreCurtains: viewModel.hasMoreCurtains(),
                    remainingCount: viewModel.getRemainingCurtainCount(),
                    onLoadMore: {
                        viewModel.loadMoreCurtains()
                    }
                )
            }
        }
        .refreshable {
            viewModel.loadCurtains()
        }
    }
}

// MARK: - CurtainRowView (Like Android CurtainAdapter item)

struct CurtainRowView: View {
    let curtain: CurtainEntity
    let onTap: () -> Void
    let onEditDescription: () -> Void
    let onDelete: () -> Void
    let onTogglePin: () -> Void
    let onRedownload: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(curtain.dataDescription)
                        .font(.headline)
                        .lineLimit(2)
                    
                    Text("ID: \(curtain.linkId)")
                        .font(.caption)
                        .foregroundColor(.primary)
                    
                    Text("Created: \(curtain.created, format: .dateTime)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("Host: \(curtain.sourceHostname)")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                
                Spacer()
                
                VStack(spacing: 4) {
                    // Pin Status
                    if curtain.isPinned {
                        Image(systemName: "pin.fill")
                            .foregroundColor(.orange)
                    }
                    
                    // Download Status
                    if let filePath = curtain.file {
                        if FileManager.default.fileExists(atPath: filePath) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        } else {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                        }
                    } else {
                        Image(systemName: "cloud.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            print("🟡 CurtainRowView: Row tapped for curtain: \(curtain.dataDescription)")
            onTap()
        }
        .contextMenu {
            Button("Edit Description", action: onEditDescription)
            Button(curtain.isPinned ? "Unpin" : "Pin", action: onTogglePin)
            if curtain.file != nil {
                Button("Redownload", action: onRedownload)
            }
            Button("Delete", role: .destructive, action: onDelete)
        }
        .swipeActions(edge: .trailing) {
            Button("Delete", role: .destructive, action: onDelete)
            Button(curtain.isPinned ? "Unpin" : "Pin", action: onTogglePin)
        }
    }
}

// MARK: - Supporting Views

struct SearchBar: View {
    @Binding var text: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("Search curtains...", text: $text)
                .textFieldStyle(RoundedBorderTextFieldStyle())
        }
    }
}

struct DownloadProgressView: View {
    let progress: Int
    let speed: Double
    let onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Downloading...")
                    .font(.headline)
                Spacer()
                Button("Cancel", action: onCancel)
                    .foregroundColor(.red)
            }
            
            ProgressView(value: Double(progress), total: 100)
                .progressViewStyle(LinearProgressViewStyle())
            
            HStack {
                Text("\(progress)%")
                Spacer()
                Text(String(format: "%.1f KB/s", speed))
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct ErrorView: View {
    let message: String
    let onDismiss: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle")
                .foregroundColor(.orange)
            Text(message)
                .font(.caption)
            Spacer()
            Button("Dismiss", action: onDismiss)
                .font(.caption)
        }
        .padding()
        .background(Color(.systemYellow).opacity(0.1))
        .cornerRadius(8)
    }
}

struct LoadMoreView: View {
    let isLoading: Bool
    let hasMoreCurtains: Bool
    let remainingCount: Int
    let onLoadMore: () -> Void
    
    var body: some View {
        HStack {
            Spacer()
            if isLoading {
                ProgressView()
                    .scaleEffect(0.8)
                Text("Loading...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Button(action: onLoadMore) {
                    Text(buttonText)
                        .font(.caption)
                }
                .disabled(!hasMoreCurtains)
            }
            Spacer()
        }
        .padding(.vertical, 8)
    }
    
    private var buttonText: String {
        if hasMoreCurtains {
            return "Load More Curtains (\(remainingCount) remaining)"
        } else {
            return "All curtains loaded"
        }
    }
}

struct EmptyStateView: View {
    let onLoadExample: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Curtain Datasets")
                .font(.title2)
                .fontWeight(.medium)
            
            Text("Add your first proteomics dataset to get started")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            VStack(spacing: 12) {
                Button("Load Example Dataset") {
                    onLoadExample()
                }
                .buttonStyle(.borderedProminent)
                
                Text("or add your own dataset using the + button")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ToastView: View {
    let message: String
    
    var body: some View {
        Text(message)
            .font(.subheadline)
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.8))
            .cornerRadius(8)
            .padding(.top, 8)
    }
}

// MARK: - Sheet Views

struct AddCurtainSheet: View {
    @Environment(\.dismiss) private var dismiss
    let viewModel: CurtainViewModel
    
    @State private var linkId = ""
    @State private var hostname = ""
    @State private var description = ""
    @State private var frontendURL = ""
    @State private var fullURL = ""
    @State private var selectedInputMethod = 0
    @State private var showingQRScanner = false
    
    private let inputMethods = ["Individual Fields", "Full URL", "QR Code"]
    
    var body: some View {
        NavigationView {
            Form {
                Section("Input Method") {
                    Picker("Method", selection: $selectedInputMethod) {
                        ForEach(0..<inputMethods.count, id: \.self) { index in
                            Text(inputMethods[index])
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                if selectedInputMethod == 0 {
                    // Individual Fields (Original method)
                    Section("Curtain Information") {
                        TextField("Link ID", text: $linkId)
                        
                        HStack {
                            TextField("Hostname", text: $hostname)
                            Menu("Common") {
                                ForEach(CurtainConstants.commonHostnames, id: \.self) { host in
                                    Button(host) {
                                        hostname = host
                                    }
                                }
                            }
                            .font(.caption)
                        }
                        
                        TextField("Description", text: $description)
                        TextField("Frontend URL (Optional)", text: $frontendURL)
                    }
                } else if selectedInputMethod == 1 {
                    // Full URL Input (Like Android special URL handling)
                    Section("Full URL") {
                        TextField("https://curtain.proteo.info/#/your-link-id", text: $fullURL)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                        
                        if !fullURL.isEmpty {
                            Text("Detected: \(getURLDescription())")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Section("Additional Information") {
                        TextField("Description (Optional)", text: $description)
                    }
                } else {
                    // QR Code Scanning (New method)
                    Section("QR Code Scanner") {
                        VStack(spacing: 16) {
                            Image(systemName: "qrcode.viewfinder")
                                .font(.system(size: 50))
                                .foregroundColor(.blue)
                            
                            Text("Scan QR Code")
                                .font(.headline)
                            
                            Text("Scan a QR code containing Curtain session data or deep link URL")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                            
                            Button("Open Camera") {
                                showingQRScanner = true
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical)
                    }
                    
                    if !linkId.isEmpty {
                        Section("Scanned Information") {
                            HStack {
                                Text("Link ID:")
                                Spacer()
                                Text(linkId)
                                    .foregroundColor(.secondary)
                            }
                            
                            HStack {
                                Text("API URL:")
                                Spacer()
                                Text(hostname)
                                    .foregroundColor(.secondary)
                            }
                            
                            if !frontendURL.isEmpty {
                                HStack {
                                    Text("Frontend URL:")
                                    Spacer()
                                    Text(frontendURL)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            TextField("Description (Optional)", text: $description)
                        }
                    }
                }
                
                Section("Quick Actions") {
                    Button("Load Example Dataset") {
                        Task {
                            await viewModel.loadExampleCurtain()
                            dismiss()
                        }
                    }
                    .foregroundColor(.blue)
                }
            }
            .navigationTitle("Add Curtain")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        Task {
                            if selectedInputMethod == 0 {
                                // Individual fields method
                                await viewModel.createCurtainEntry(
                                    linkId: linkId,
                                    hostname: hostname,
                                    frontendURL: frontendURL.isEmpty ? nil : frontendURL,
                                    description: description
                                )
                            } else if selectedInputMethod == 1 {
                                // Full URL method with special handling
                                if CurtainConstants.URLPatterns.isProteoURL(fullURL) {
                                    await viewModel.handleProteoURL(fullURL)
                                } else {
                                    // Try to parse as regular URL
                                    await parseAndAddURL()
                                }
                            } else {
                                // QR Code method - use parsed data
                                await viewModel.createCurtainEntry(
                                    linkId: linkId,
                                    hostname: hostname,
                                    frontendURL: frontendURL.isEmpty ? nil : frontendURL,
                                    description: description
                                )
                            }
                            dismiss()
                        }
                    }
                    .disabled(isAddButtonDisabled)
                }
            }
            .sheet(isPresented: $showingQRScanner) {
                QRCodeScannerView { scannedContent in
                    Task {
                        await processQRCodeContent(scannedContent)
                    }
                }
            }
        }
    }
    
    private var isAddButtonDisabled: Bool {
        if selectedInputMethod == 0 {
            return linkId.isEmpty || hostname.isEmpty
        } else if selectedInputMethod == 1 {
            return fullURL.isEmpty
        } else {
            return linkId.isEmpty || hostname.isEmpty
        }
    }
    
    private func getURLDescription() -> String {
        if CurtainConstants.URLPatterns.isProteoURL(fullURL) {
            if let linkId = CurtainConstants.URLPatterns.extractLinkIdFromProteoURL(fullURL) {
                return "curtain.proteo.info link: \(linkId)"
            }
        }
        return "Custom URL"
    }
    
    private func parseAndAddURL() async {
        // Simple URL parsing for non-proteo URLs
        guard let url = URL(string: fullURL),
              let host = url.host else {
            viewModel.error = "Invalid URL format"
            return
        }
        
        let baseURL = "\(url.scheme ?? "https")://\(host)"
        let pathComponents = url.pathComponents.filter { $0 != "/" }
        let linkId = pathComponents.last ?? ""
        
        if linkId.isEmpty {
            viewModel.error = "Could not extract link ID from URL"
            return
        }
        
        await viewModel.createCurtainEntry(
            linkId: linkId,
            hostname: baseURL,
            frontendURL: nil,
            description: description.isEmpty ? "Dataset from \(host)" : description
        )
    }
    
    private func processQRCodeContent(_ content: String) async {
        let result = await DeepLinkHandler.shared.processQRCode(content)
        
        await MainActor.run {
            if result.isValid, let linkId = result.linkId, let apiUrl = result.apiUrl {
                // Fill in the form fields with scanned data
                self.linkId = linkId
                self.hostname = apiUrl
                self.frontendURL = result.frontendUrl ?? ""
                self.description = result.description ?? ""
                
                print("🔍 QR Code processed successfully: \(linkId) at \(apiUrl)")
            } else {
                // Show error
                viewModel.error = result.error ?? "Failed to parse QR code content"
                print("🔍 QR Code processing failed: \(result.error ?? "Unknown error")")
            }
        }
    }
}

struct EditDescriptionSheet: View {
    @Environment(\.dismiss) private var dismiss
    let curtain: CurtainEntity
    let viewModel: CurtainViewModel
    
    @State private var description: String
    
    init(curtain: CurtainEntity, viewModel: CurtainViewModel) {
        self.curtain = curtain
        self.viewModel = viewModel
        _description = State(initialValue: curtain.dataDescription)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Description") {
                    TextField("Enter description", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Edit Description")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        viewModel.updateCurtainDescription(curtain, description: description)
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    CurtainListView()
}

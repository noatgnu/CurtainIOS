//
//  CurtainListView.swift
//  Curtain
//
//  Created by Toan Phung on 02/08/2025.
//

import SwiftUI
import SwiftData

struct CurtainListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(DeepLinkViewModel.self) private var deepLinkViewModel
    @State private var viewModel = CurtainViewModel()
    @State private var showingAddCurtainSheet = false
    @State private var showingEditDescriptionSheet = false
    @State private var selectedCurtain: CurtainEntity?
    @State private var searchText = ""
    @State private var curtainForDetails: CurtainEntity?
    @State private var showingDeleteConfirmation = false
    @State private var curtainToDelete: CurtainEntity?
    @State private var toastMessage: String?
    @State private var showingToast = false
    @State private var showingDownloadConfirmation = false
    @State private var curtainToDownload: CurtainEntity?
    @State private var selectedTab = 0

    var body: some View {
        if UIDevice.current.userInterfaceIdiom == .pad || UIDevice.current.userInterfaceIdiom == .mac {
            splitViewLayout
        } else {
            stackViewLayout
        }
    }

    private var splitViewLayout: some View {
        HStack(spacing: 0) {
            mainContent
                .frame(width: 360)

            Group {
                if let curtain = curtainForDetails {
                    CurtainDetailsView(curtain: curtain)
                } else {
                    emptyDetailView
                }
            }
            .frame(maxWidth: .infinity)
        }
        .applySharedModifiers(
            viewModel: viewModel,
            deepLinkViewModel: deepLinkViewModel,
            showingAddCurtainSheet: $showingAddCurtainSheet,
            showingEditDescriptionSheet: $showingEditDescriptionSheet,
            selectedCurtain: $selectedCurtain,
            showingDeleteConfirmation: $showingDeleteConfirmation,
            curtainToDelete: $curtainToDelete,
            curtainForDetails: $curtainForDetails,
            showingDownloadConfirmation: $showingDownloadConfirmation,
            curtainToDownload: $curtainToDownload,
            showingToast: $showingToast,
            toastMessage: $toastMessage,
            onDOISessionLoaded: handleDOISessionLoaded,
            onShowToast: showToast,
            modelContext: modelContext
        )
    }

    private var stackViewLayout: some View {
        NavigationStack {
            mainContent
                .navigationTitle("Curtain Datasets")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button(action: refreshCurtains) {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }
                    }
                    ToolbarItem(placement: .cancellationAction) {
                        Button(action: { showingAddCurtainSheet = true }) {
                            Label("Add", systemImage: "plus")
                        }
                    }
                }
                .navigationDestination(item: $curtainForDetails) { curtain in
                    CurtainDetailsView(curtain: curtain)
                        .navigationTitle(curtain.dataDescription)
                        .navigationBarTitleDisplayMode(.inline)
                }
        }
        .applySharedModifiers(
            viewModel: viewModel,
            deepLinkViewModel: deepLinkViewModel,
            showingAddCurtainSheet: $showingAddCurtainSheet,
            showingEditDescriptionSheet: $showingEditDescriptionSheet,
            selectedCurtain: $selectedCurtain,
            showingDeleteConfirmation: $showingDeleteConfirmation,
            curtainToDelete: $curtainToDelete,
            curtainForDetails: $curtainForDetails,
            showingDownloadConfirmation: $showingDownloadConfirmation,
            curtainToDownload: $curtainToDownload,
            showingToast: $showingToast,
            toastMessage: $toastMessage,
            onDOISessionLoaded: handleDOISessionLoaded,
            onShowToast: showToast,
            modelContext: modelContext
        )
    }

    private var mainContent: some View {
        VStack(spacing: 0) {
            HStack {
                Picker("View", selection: $selectedTab) {
                    Text("Sessions").tag(0)
                    Text("Collections").tag(1)
                }
                .pickerStyle(.segmented)

                Spacer()

                Button(action: { showingAddCurtainSheet = true }) {
                    Image(systemName: "plus")
                }
                .buttonStyle(.plain)

                Button(action: refreshCurtains) {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
            .padding(.top, 8)

            if selectedTab == 0 {
                sessionsContent
            } else {
                collectionsContent
            }
        }
        .refreshable {
            if selectedTab == 0 {
                viewModel.loadCurtains()
            } else {
                viewModel.loadCollections()
            }
        }
    }

    private var sessionsContent: some View {
        VStack(spacing: 0) {
            SearchBar(text: $searchText)
                .padding()

            if viewModel.isDownloading {
                DownloadProgressView(
                    progress: viewModel.downloadProgress,
                    speed: viewModel.downloadSpeed,
                    onCancel: { viewModel.cancelDownload() }
                )
                .padding(.horizontal)
                .padding(.bottom, 8)
            }

            if let error = viewModel.error {
                ErrorView(message: error) {
                    viewModel.clearError()
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }

            if viewModel.isLoading && viewModel.curtains.isEmpty {
                ProgressView("Loading curtains...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.curtains.isEmpty && !viewModel.isLoading {
                EmptyStateView(onLoadExample: {
                    Task {
                        await viewModel.loadExampleCurtain()
                    }
                })
            } else {
                curtainList

                if !viewModel.curtains.isEmpty {
                    Text(viewModel.getPaginationInfo())
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding()
                }
            }
        }
    }

    private var collectionsContent: some View {
        VStack(spacing: 0) {
            if viewModel.isDownloading {
                DownloadProgressView(
                    progress: viewModel.downloadProgress,
                    speed: viewModel.downloadSpeed,
                    onCancel: { viewModel.cancelDownload() }
                )
                .padding(.horizontal)
                .padding(.bottom, 8)
            }

            if let error = viewModel.error {
                ErrorView(message: error) {
                    viewModel.clearError()
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }

            CollectionsTabView(
                viewModel: viewModel,
                onSessionTap: { session, collection in
                    handleCollectionSessionTap(session: session, collection: collection)
                },
                onEditSession: { curtain in
                    selectedCurtain = curtain
                    showingEditDescriptionSheet = true
                },
                onTogglePinSession: { curtain in
                    viewModel.updatePinStatus(curtain, isPinned: !curtain.isPinned)
                },
                onRedownloadSession: { curtain in
                    Task {
                        _ = try? await viewModel.redownloadCurtainData(curtain)
                    }
                },
                onDeleteSessionData: { curtain in
                    curtainToDelete = curtain
                    showingDeleteConfirmation = true
                }
            )
        }
    }

    private var curtainList: some View {
        List {
            ForEach(filteredCurtains, id: \.linkId) { curtain in
                UniversalCurtainRow(
                    curtain: curtain,
                    isInCollection: viewModel.isInCollection(linkId: curtain.linkId),
                    isSelected: curtainForDetails?.linkId == curtain.linkId,
                    onTap: { handleCurtainTap(curtain) },
                    onEdit: {
                        selectedCurtain = curtain
                        showingEditDescriptionSheet = true
                    },
                    onDelete: {
                        curtainToDelete = curtain
                        showingDeleteConfirmation = true
                    },
                    onTogglePin: {
                        viewModel.updatePinStatus(curtain, isPinned: !curtain.isPinned)
                        showToast(curtain.isPinned ? "Unpinned" : "Pinned")
                    },
                    onRedownload: {
                        Task {
                            do {
                                _ = try await viewModel.redownloadCurtainData(curtain)
                            } catch {
                            }
                        }
                    }
                )
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }

            if viewModel.hasMoreCurtains() || viewModel.isLoadingMore {
                LoadMoreView(
                    isLoading: viewModel.isLoadingMore,
                    hasMoreCurtains: viewModel.hasMoreCurtains(),
                    remainingCount: viewModel.getRemainingCurtainCount(),
                    onLoadMore: { viewModel.loadMoreCurtains() }
                )
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private var emptyDetailView: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text("Select a Dataset")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Choose a dataset from the sidebar to view its details and analysis tools")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var filteredCurtains: [CurtainEntity] {
        if searchText.isEmpty {
            return viewModel.curtains
        } else {
            return viewModel.searchCurtains(searchText)
        }
    }

    private func handleCurtainTap(_ curtain: CurtainEntity) {
        let curtainLinkId = curtain.linkId

        #if targetEnvironment(simulator)
        let isSimulator = true
        #else
        let isSimulator = false
        #endif

        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let curtainDataDir = documentsURL.appendingPathComponent("CurtainData", isDirectory: true)
        let currentFilePath = curtainDataDir.appendingPathComponent("\(curtainLinkId).json").path

        let fileExistsAtCurrentPath = FileManager.default.fileExists(atPath: currentFilePath)

        if fileExistsAtCurrentPath {
            if curtain.file != currentFilePath {
                curtain.file = currentFilePath
                do {
                    try modelContext.save()
                } catch {
                }
            }
            curtainForDetails = curtain
        } else if isSimulator || curtain.file == nil {
            curtainToDownload = curtain
            showingDownloadConfirmation = true
        } else {
            curtainToDownload = curtain
            showingDownloadConfirmation = true
        }
    }

    private func handleCollectionSessionTap(session: CollectionSessionEntity, collection: CurtainCollectionEntity) {
        // If we already have a local CurtainEntity, use it directly
        if let curtain = viewModel.getCurtainEntity(linkId: session.linkId) {
            handleCurtainTap(curtain)
            return
        }

        // Otherwise, fetch/create the CurtainEntity first, then open it
        Task {
            await viewModel.loadSessionFromCollection(session: session, collection: collection)
            if let curtain = viewModel.getCurtainEntity(linkId: session.linkId) {
                handleCurtainTap(curtain)
            }
        }
    }

    private func handleDOISessionLoaded(sessionData: [String: Any], doi: String) {
        Task {
            do {
                var description = "DOI: \(doi)"
                if let metadata = sessionData["metadata"] as? [String: Any],
                   let title = metadata["title"] as? String {
                    description = title
                }

                let curtainEntity = try await viewModel.createCurtainFromDOISession(
                    sessionData: sessionData,
                    doi: doi,
                    description: description
                )

                await MainActor.run {
                    deepLinkViewModel.clearDOIState()
                    curtainForDetails = curtainEntity
                    showToast("DOI session loaded successfully")
                }
            } catch {
                await MainActor.run {
                    deepLinkViewModel.clearDOIState()
                    showToast("Failed to load DOI session: \(error.localizedDescription)")
                }
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

struct UniversalCurtainRow: View {
    let curtain: CurtainEntity
    var isInCollection: Bool = false
    var isSelected: Bool = false
    let onTap: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onTogglePin: () -> Void
    let onRedownload: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            statusIcon

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(curtain.dataDescription)
                        .font(.body)
                        .fontWeight(.medium)
                        .lineLimit(2)

                    Spacer()

                    if isInCollection {
                        Image(systemName: "folder.fill")
                            .foregroundColor(.purple)
                            .font(.caption)
                    }

                    if curtain.isPinned {
                        Image(systemName: "pin.fill")
                            .foregroundColor(.orange)
                            .font(.caption)
                    }

                    Menu {
                        Button {
                            onEdit()
                        } label: {
                            Label("Edit Description", systemImage: "pencil")
                        }

                        Button {
                            onTogglePin()
                        } label: {
                            Label(curtain.isPinned ? "Unpin" : "Pin", systemImage: curtain.isPinned ? "pin.slash" : "pin")
                        }

                        if curtain.file != nil {
                            Button {
                                onRedownload()
                            } label: {
                                Label("Redownload", systemImage: "arrow.down.circle")
                            }
                        }

                        if !isInCollection {
                            Divider()

                            Button(role: .destructive) {
                                onDelete()
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(.secondary)
                            .font(.title3)
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("ID: \(curtain.linkId.prefix(12))...")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(curtain.created, format: .dateTime.day().month().year())
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(curtain.sourceHostname.replacingOccurrences(of: "https://", with: "").replacingOccurrences(of: "http://", with: ""))
                        .font(.caption)
                        .foregroundColor(.blue)
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isSelected ? Color.accentColor.opacity(0.15) : Color(.secondarySystemGroupedBackground))
        .cornerRadius(10)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }

    private var statusIcon: some View {
        Group {
            if let filePath = curtain.file {
                if FileManager.default.fileExists(atPath: filePath) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                } else {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                }
            } else {
                Image(systemName: "icloud.and.arrow.down")
                    .foregroundColor(.blue)
            }
        }
        .font(.title3)
        .frame(width: 20)
    }
}

struct SearchBar: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)

            TextField("Search curtains...", text: $text)
                .textFieldStyle(.plain)

            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(10)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

struct DownloadProgressView: View {
    let progress: Int
    let speed: Double
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Downloading Data")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text("\(progress)% • \(String(format: "%.1f KB/s", speed))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button("Cancel", action: onCancel)
                    .font(.subheadline)
                    .foregroundColor(.red)
            }

            ProgressView(value: Double(progress), total: 100)
                .progressViewStyle(LinearProgressViewStyle(tint: .blue))
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct ErrorView: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
                .font(.title3)

            Text(message)
                .font(.subheadline)
                .foregroundColor(.primary)

            Spacer()

            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
    }
}

struct EmptyStateView: View {
    let onLoadExample: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "tray")
                .font(.system(size: 64))
                .foregroundColor(.secondary)

            VStack(spacing: 8) {
                Text("No Datasets")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Add a curtain dataset to get started")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button(action: onLoadExample) {
                Label("Load Example Dataset", systemImage: "arrow.down.circle")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
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
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading more...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            } else if hasMoreCurtains {
                Button(action: onLoadMore) {
                    Label("Load \(remainingCount) more", systemImage: "arrow.down")
                        .font(.subheadline)
                }
            } else {
                Text("No more curtains")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 12)
    }
}

struct ToastView: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.subheadline)
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.black.opacity(0.8))
            .cornerRadius(10)
            .shadow(radius: 10)
            .padding(.top, 8)
            .transition(.move(edge: .top).combined(with: .opacity))
    }
}

struct AddCurtainSheet: View {
    @Environment(\.dismiss) private var dismiss
    let viewModel: CurtainViewModel

    @State private var addMode: AddMode = .session
    @State private var linkId = ""
    @State private var apiUrl = "https://celsus.muttsu.xyz"
    @State private var frontendUrl = ""
    @State private var description = ""
    @State private var collectionIdText = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingQRScanner = false

    enum AddMode: String, CaseIterable {
        case session = "Session"
        case collection = "Collection"
    }

    private let commonApiUrls = [
        "https://celsus.muttsu.xyz",
        "https://curtain-backend.omics.quest"
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button {
                        showingQRScanner = true
                    } label: {
                        Label("Scan QR Code", systemImage: "qrcode.viewfinder")
                    }
                }

                Section {
                    Picker("Type", selection: $addMode) {
                        ForEach(AddMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                if addMode == .session {
                    sessionFields
                } else {
                    collectionFields
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle(addMode == .session ? "Add Session" : "Add Collection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .fixedSize()
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        if addMode == .session {
                            addCurtain()
                        } else {
                            addCollection()
                        }
                    }
                    .fixedSize()
                    .disabled(!isValid || isLoading)
                }
            }
            .disabled(isLoading)
            .overlay {
                if isLoading {
                    ProgressView()
                }
            }
            .sheet(isPresented: $showingQRScanner) {
                QRCodeScannerView { code in
                    handleScannedCode(code)
                }
            }
        }
    }

    private var sessionFields: some View {
        Section {
            TextField("Unique ID", text: $linkId)
                .autocapitalization(.none)
                .autocorrectionDisabled()

            Picker("API URL", selection: $apiUrl) {
                ForEach(commonApiUrls, id: \.self) { url in
                    Text(url).tag(url)
                }
            }

            TextField("Frontend URL (Optional)", text: $frontendUrl)
                .autocapitalization(.none)
                .autocorrectionDisabled()

            TextField("Description", text: $description)
        } header: {
            Text("Session Details")
        } footer: {
            Text("Enter the unique identifier and API URL of the curtain dataset")
        }
    }

    private var collectionFields: some View {
        Section {
            TextField("Collection ID", text: $collectionIdText)
                .keyboardType(.numberPad)

            Picker("API URL", selection: $apiUrl) {
                ForEach(commonApiUrls, id: \.self) { url in
                    Text(url).tag(url)
                }
            }

            TextField("Frontend URL (Optional)", text: $frontendUrl)
                .autocapitalization(.none)
                .autocorrectionDisabled()
        } header: {
            Text("Collection Details")
        } footer: {
            Text("Enter the collection ID and API URL to fetch the collection")
        }
    }

    private var isValid: Bool {
        if addMode == .session {
            return !linkId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                   !apiUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        } else {
            return Int(collectionIdText) != nil &&
                   !apiUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private func addCurtain() {
        isLoading = true
        errorMessage = nil

        Task {
            await viewModel.createCurtainEntry(
                linkId: linkId.trimmingCharacters(in: .whitespacesAndNewlines),
                hostname: apiUrl.trimmingCharacters(in: .whitespacesAndNewlines),
                frontendURL: frontendUrl.isEmpty ? nil : frontendUrl.trimmingCharacters(in: .whitespacesAndNewlines),
                description: description.isEmpty ? "Manual import" : description.trimmingCharacters(in: .whitespacesAndNewlines)
            )

            await MainActor.run {
                isLoading = false
                if viewModel.error == nil {
                    dismiss()
                } else {
                    errorMessage = viewModel.error
                }
            }
        }
    }

    private func addCollection() {
        guard let collectionId = Int(collectionIdText) else { return }
        isLoading = true
        errorMessage = nil

        Task {
            await viewModel.loadCollection(
                collectionId: collectionId,
                apiUrl: apiUrl.trimmingCharacters(in: .whitespacesAndNewlines),
                frontendUrl: frontendUrl.isEmpty ? nil : frontendUrl.trimmingCharacters(in: .whitespacesAndNewlines)
            )

            await MainActor.run {
                isLoading = false
                if viewModel.error == nil {
                    dismiss()
                } else {
                    errorMessage = viewModel.error
                }
            }
        }
    }

    private func handleScannedCode(_ code: String) {
        Task {
            let result = await DeepLinkHandler.shared.processQRCode(code)

            await MainActor.run {
                switch result.type {
                case .curtainSession:
                    addMode = .session
                    linkId = result.linkId ?? ""
                    if let url = result.apiUrl {
                        apiUrl = url
                    }
                    frontendUrl = result.frontendUrl ?? ""
                    description = result.description ?? ""

                case .collection:
                    addMode = .collection
                    if let id = result.collectionId {
                        collectionIdText = String(id)
                    }
                    if let url = result.collectionApiUrl {
                        apiUrl = url
                    }
                    frontendUrl = result.frontendUrl ?? ""

                case .doiSession:
                    // DOI sessions go through DOI loader, not the add form
                    errorMessage = "DOI QR codes are handled separately"

                case .invalid:
                    errorMessage = result.error ?? "Could not parse QR code"
                }
            }
        }
    }
}

struct EditDescriptionSheet: View {
    @Environment(\.dismiss) private var dismiss
    let curtain: CurtainEntity
    let viewModel: CurtainViewModel

    @State private var description: String
    @FocusState private var isTextFieldFocused: Bool

    init(curtain: CurtainEntity, viewModel: CurtainViewModel) {
        self.curtain = curtain
        self.viewModel = viewModel
        _description = State(initialValue: curtain.dataDescription)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(curtain.linkId)
                        .font(.caption)
                        .foregroundColor(.secondary)
                } header: {
                    Text("Curtain ID")
                }

                Section {
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                        .focused($isTextFieldFocused)
                } header: {
                    Text("Description")
                }
            }
            .navigationTitle("Edit Description")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .fixedSize()
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveDescription()
                    }
                    .fixedSize()
                    .disabled(!hasChanged)
                }
            }
            .onAppear {
                isTextFieldFocused = true
            }
        }
    }

    private var hasChanged: Bool {
        description.trimmingCharacters(in: .whitespacesAndNewlines) != curtain.dataDescription.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func saveDescription() {
        viewModel.updateCurtainDescription(curtain, description: description.trimmingCharacters(in: .whitespacesAndNewlines))
        dismiss()
    }
}

extension View {
    func applySharedModifiers(
        viewModel: CurtainViewModel,
        deepLinkViewModel: DeepLinkViewModel,
        showingAddCurtainSheet: Binding<Bool>,
        showingEditDescriptionSheet: Binding<Bool>,
        selectedCurtain: Binding<CurtainEntity?>,
        showingDeleteConfirmation: Binding<Bool>,
        curtainToDelete: Binding<CurtainEntity?>,
        curtainForDetails: Binding<CurtainEntity?>,
        showingDownloadConfirmation: Binding<Bool>,
        curtainToDownload: Binding<CurtainEntity?>,
        showingToast: Binding<Bool>,
        toastMessage: Binding<String?>,
        onDOISessionLoaded: @escaping ([String: Any], String) -> Void,
        onShowToast: @escaping (String) -> Void,
        modelContext: ModelContext
    ) -> some View {
        self
            .sheet(isPresented: showingAddCurtainSheet) {
                AddCurtainSheet(viewModel: viewModel)
            }
            .sheet(isPresented: showingEditDescriptionSheet) {
                if let curtain = selectedCurtain.wrappedValue {
                    EditDescriptionSheet(curtain: curtain, viewModel: viewModel)
                }
            }
            .sheet(isPresented: Binding(
                get: { deepLinkViewModel.showDOILoader },
                set: { if !$0 { deepLinkViewModel.clearDOIState() } }
            )) {
                if let doi = deepLinkViewModel.pendingDOI {
                    DOILoaderView(
                        doi: doi,
                        sessionId: deepLinkViewModel.pendingSessionId,
                        onSessionLoaded: { sessionData in
                            onDOISessionLoaded(sessionData, doi)
                        },
                        onDismiss: {
                            deepLinkViewModel.clearDOIState()
                        }
                    )
                }
            }
            .alert("Delete Curtain", isPresented: showingDeleteConfirmation, presenting: curtainToDelete.wrappedValue) { curtain in
                Button("Delete", role: .destructive) {
                    viewModel.deleteCurtain(curtain)
                    onShowToast("Curtain deleted")
                    if curtainForDetails.wrappedValue?.linkId == curtain.linkId {
                        curtainForDetails.wrappedValue = nil
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: { curtain in
                Text("Are you sure you want to delete this curtain?\n\nID: \(curtain.linkId)\nDescription: \(curtain.dataDescription.isEmpty ? "No description" : curtain.dataDescription)")
            }
            .alert("Download Data", isPresented: showingDownloadConfirmation, presenting: curtainToDownload.wrappedValue) { curtain in
                Button("Download") {
                    Task {
                        do {
                            _ = try await viewModel.downloadCurtainData(curtain)
                            await MainActor.run {
                                viewModel.loadCurtains()
                                if let refreshedCurtain = viewModel.curtains.first(where: { $0.linkId == curtain.linkId }) {
                                    curtainForDetails.wrappedValue = refreshedCurtain
                                }
                            }
                        } catch {
                        }
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: { curtain in
                Text("This dataset needs to be downloaded to view its details.\n\nDataset: \(curtain.dataDescription)\nID: \(curtain.linkId)\nHost: \(curtain.sourceHostname)\n\nWould you like to download it now?")
            }
            .overlay(alignment: .top) {
                if showingToast.wrappedValue, let message = toastMessage.wrappedValue {
                    ToastView(message: message)
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                withAnimation {
                                    showingToast.wrappedValue = false
                                }
                            }
                        }
                }
            }
            .onAppear {
                viewModel.setupWithModelContext(modelContext)
            }
            .onChange(of: deepLinkViewModel.pendingCollectionId) { _, newValue in
                if let collectionId = newValue,
                   let apiUrl = deepLinkViewModel.pendingCollectionApiUrl {
                    Task {
                        await viewModel.loadCollection(
                            collectionId: collectionId,
                            apiUrl: apiUrl,
                            frontendUrl: deepLinkViewModel.pendingCollectionFrontendUrl
                        )
                        deepLinkViewModel.clearCollectionState()
                    }
                }
            }
    }
}

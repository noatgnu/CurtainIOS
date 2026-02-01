//
//  CollectionsTabView.swift
//  Curtain
//
//  Created by Toan Phung on 29/01/2026.
//

import SwiftUI

struct CollectionsTabView: View {
    let viewModel: CurtainViewModel
    let onSessionTap: (CollectionSessionEntity, CurtainCollectionEntity) -> Void
    var onEditSession: ((CurtainEntity) -> Void)?
    var onTogglePinSession: ((CurtainEntity) -> Void)?
    var onRedownloadSession: ((CurtainEntity) -> Void)?
    var onDeleteSessionData: ((CurtainEntity) -> Void)?

    var body: some View {
        if viewModel.isLoadingCollections && viewModel.collections.isEmpty {
            ProgressView("Loading collections...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.collections.isEmpty {
            collectionsEmptyState
        } else {
            collectionsList
        }
    }

    private var collectionsEmptyState: some View {
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

            Button(action: {
                Task {
                    await viewModel.loadExampleCollection()
                }
            }) {
                Label("Load Example Collection", systemImage: "arrow.down.circle")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var collectionsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.collections, id: \.collectionId) { collection in
                    CollectionCardView(
                        collection: collection,
                        viewModel: viewModel,
                        onSessionTap: onSessionTap,
                        onEditSession: onEditSession,
                        onTogglePinSession: onTogglePinSession,
                        onRedownloadSession: onRedownloadSession,
                        onDeleteSessionData: onDeleteSessionData
                    )
                }
            }
            .padding()
        }
    }
}

// MARK: - Collection Card View

struct CollectionCardView: View {
    let collection: CurtainCollectionEntity
    let viewModel: CurtainViewModel
    let onSessionTap: (CollectionSessionEntity, CurtainCollectionEntity) -> Void
    var onEditSession: ((CurtainEntity) -> Void)?
    var onTogglePinSession: ((CurtainEntity) -> Void)?
    var onRedownloadSession: ((CurtainEntity) -> Void)?
    var onDeleteSessionData: ((CurtainEntity) -> Void)?

    private var isExpanded: Bool {
        viewModel.expandedCollectionIds.contains(collection.collectionId)
    }

    private var isSelectionMode: Bool {
        viewModel.selectionModeCollectionId == collection.collectionId
    }

    private var selectedCount: Int {
        viewModel.selectedSessionIds[collection.collectionId]?.count ?? 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            cardHeader
            if isExpanded {
                Divider()
                if isSelectionMode {
                    selectionToolbar
                    Divider()
                }
                sessionsContent
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
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

            Menu {
                Button {
                    Task {
                        await viewModel.refreshCollection(id: collection.collectionId)
                    }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }

                Button {
                    viewModel.enterSelectionMode(collectionId: collection.collectionId)
                    if !isExpanded {
                        viewModel.toggleCollectionExpanded(id: collection.collectionId)
                    }
                } label: {
                    Label("Select Multiple", systemImage: "checkmark.circle")
                }

                Divider()

                Button(role: .destructive) {
                    viewModel.deleteCollection(id: collection.collectionId)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundColor(.secondary)
                    .font(.title3)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)

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
            Button("Select All") {
                viewModel.selectAllSessions(collectionId: collection.collectionId)
            }
            .font(.caption)

            Button("Deselect All") {
                viewModel.deselectAllSessions(collectionId: collection.collectionId)
            }
            .font(.caption)

            Spacer()

            Text("\(selectedCount) selected")
                .font(.caption)
                .foregroundColor(.secondary)

            Button("Download") {
                Task {
                    await viewModel.downloadSelectedSessions(collectionId: collection.collectionId)
                }
            }
            .font(.caption)
            .fontWeight(.medium)
            .disabled(selectedCount == 0)

            Button("Cancel") {
                viewModel.exitSelectionMode()
            }
            .font(.caption)
            .foregroundColor(.red)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private var sessionsContent: some View {
        VStack(spacing: 0) {
            let sessions = viewModel.collectionSessions[collection.collectionId] ?? collection.sessions
            ForEach(sessions, id: \.linkId) { session in
                CollectionSessionRowView(
                    session: session,
                    collection: collection,
                    viewModel: viewModel,
                    isSelectionMode: isSelectionMode,
                    isSelected: viewModel.selectedSessionIds[collection.collectionId]?.contains(session.linkId) ?? false,
                    onTap: {
                        if isSelectionMode {
                            viewModel.toggleSessionSelection(collectionId: collection.collectionId, sessionLinkId: session.linkId)
                        } else {
                            onSessionTap(session, collection)
                        }
                    },
                    onEdit: onEditSession,
                    onTogglePin: onTogglePinSession,
                    onRedownload: onRedownloadSession,
                    onDeleteData: onDeleteSessionData
                )

                if session.linkId != sessions.last?.linkId {
                    Divider()
                        .padding(.leading, isSelectionMode ? 48 : 16)
                }
            }
        }
    }
}

// MARK: - Collection Session Row

struct CollectionSessionRowView: View {
    let session: CollectionSessionEntity
    let collection: CurtainCollectionEntity
    let viewModel: CurtainViewModel
    let isSelectionMode: Bool
    let isSelected: Bool
    let onTap: () -> Void
    var onEdit: ((CurtainEntity) -> Void)?
    var onTogglePin: ((CurtainEntity) -> Void)?
    var onRedownload: ((CurtainEntity) -> Void)?
    var onDeleteData: ((CurtainEntity) -> Void)?

    private var localCurtain: CurtainEntity? {
        viewModel.getCurtainEntity(linkId: session.linkId)
    }

    private var sessionDisplayName: String {
        // Prefer local CurtainEntity description if available
        if let curtain = localCurtain, !curtain.dataDescription.isEmpty {
            return curtain.dataDescription
        }
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
            if isSelectionMode {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .accentColor : .secondary)
                    .font(.title3)
            } else {
                statusIcon
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(sessionDisplayName)
                        .font(.body)
                        .fontWeight(.medium)
                        .lineLimit(2)

                    Spacer()

                    if let curtain = localCurtain, curtain.isPinned {
                        Image(systemName: "pin.fill")
                            .foregroundColor(.orange)
                            .font(.caption)
                    }

                    if !isSelectionMode, localCurtain != nil {
                        sessionMenu
                    }
                }

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
            onTap()
        }
    }

    private var sessionMenu: some View {
        Menu {
            if let curtain = localCurtain {
                Button {
                    onEdit?(curtain)
                } label: {
                    Label("Edit Description", systemImage: "pencil")
                }

                Button {
                    onTogglePin?(curtain)
                } label: {
                    Label(curtain.isPinned ? "Unpin" : "Pin",
                          systemImage: curtain.isPinned ? "pin.slash" : "pin")
                }

                if curtain.file != nil {
                    Button {
                        onRedownload?(curtain)
                    } label: {
                        Label("Redownload", systemImage: "arrow.down.circle")
                    }

                    Divider()

                    Button(role: .destructive) {
                        onDeleteData?(curtain)
                    } label: {
                        Label("Delete Downloaded Data", systemImage: "trash")
                    }
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

    private var statusIcon: some View {
        Group {
            if let curtain = localCurtain, let filePath = curtain.file {
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

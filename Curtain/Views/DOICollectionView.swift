//
//  DOICollectionView.swift
//  Curtain
//
//  Created by Toan Phung on 07/01/2026.
//

import SwiftUI

struct DOICollectionView: View {
    let doi: String
    let metadata: DataCiteMetadata
    let parsedData: DOIParsedData
    let onSessionSelected: (String) -> Void
    let onDismiss: () -> Void

    @State private var selectedSession: DOISessionLink?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    doiHeader

                    if let collection = parsedData.collectionMetadata {
                        collectionInfo(collection)

                        sessionsList(collection)
                    }

                    if let mainSessionUrl = parsedData.mainSessionUrl {
                        mainSessionCard(mainSessionUrl)
                    }
                }
                .padding()
            }
            .navigationTitle("DOI Collection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onDismiss()
                    }
                    .fixedSize()
                }
            }
        }
    }

    private var doiHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("DOI Reference")
                .font(.headline)
                .foregroundColor(.secondary)

            Text(doi)
                .font(.system(.body, design: .monospaced))
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemGray6))
                .cornerRadius(8)

            if let title = metadata.data.attributes.titles.first?.title {
                Text(title)
                    .font(.title2)
                    .fontWeight(.semibold)
            }

            if let description = metadata.data.attributes.descriptions?.first?.description {
                Text(description)
                    .font(.body)
                    .foregroundColor(.secondary)
            }

            if !metadata.data.attributes.creators.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Authors")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    ForEach(metadata.data.attributes.creators.prefix(3), id: \.name) { creator in
                        Text(creator.name)
                            .font(.caption)
                    }

                    if metadata.data.attributes.creators.count > 3 {
                        Text("+ \(metadata.data.attributes.creators.count - 3) more")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.top, 8)
            }

            Divider()
        }
    }

    private func collectionInfo(_ collection: DOICollectionMetadata) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Collection")
                .font(.headline)

            if let title = collection.title {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }

            if let description = collection.description {
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text("\(collection.allSessionLinks.count) session\(collection.allSessionLinks.count == 1 ? "" : "s") available")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 4)

            Divider()
        }
    }

    private func sessionsList(_ collection: DOICollectionMetadata) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Available Sessions")
                .font(.headline)

            ForEach(collection.allSessionLinks, id: \.sessionId) { session in
                sessionCard(session)
            }
        }
    }

    private func sessionCard(_ session: DOISessionLink) -> some View {
        Button(action: {
            selectedSession = session
            onSessionSelected(session.sessionUrl)
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    if let title = session.title, !title.isEmpty {
                        Text(title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                    } else {
                        Text("Session \(session.sessionId)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                    }

                    Text(session.sessionId)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(selectedSession?.sessionId == session.sessionId ? Color.accentColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func mainSessionCard(_ mainSessionUrl: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Main Session")
                .font(.headline)

            Button(action: {
                onSessionSelected(mainSessionUrl)
            }) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Load Default Session")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)

                        Text("Primary session for this DOI")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Image(systemName: "arrow.right.circle.fill")
                        .foregroundColor(.accentColor)
                        .font(.title3)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.accentColor.opacity(0.1))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.accentColor, lineWidth: 1)
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.top)
    }
}

struct DOILoadingView: View {
    let doi: String
    let status: String

    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)

            Text("Loading DOI")
                .font(.headline)

            Text(doi)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)

            Text(status)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

struct DOIErrorView: View {
    let doi: String
    let error: Error
    let onRetry: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(.orange)

            Text("Failed to Load DOI")
                .font(.headline)

            Text(doi)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)

            Text(error.localizedDescription)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            HStack(spacing: 16) {
                Button("Retry") {
                    onRetry()
                }
                .buttonStyle(.borderedProminent)

                Button("Cancel") {
                    onDismiss()
                }
                .buttonStyle(.bordered)
            }
            .padding(.top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

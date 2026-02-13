//
//  PTMViewerContent.swift
//  Curtain
//
//  Main content view for PTM viewer
//

import SwiftUI

struct PTMViewerContent: View {
    @ObservedObject var viewModel: PTMViewerViewModel
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            PTMViewerHeader(viewModel: viewModel, onDismiss: onDismiss)

            Divider()

            // Content states
            if viewModel.isLoading {
                Spacer()
                ProgressView("Loading PTM data...")
                    .progressViewStyle(CircularProgressViewStyle())
                Spacer()
            } else if let error = viewModel.error {
                PTMErrorView(error: error)
            } else if let state = viewModel.ptmViewerState {
                PTMSequenceTab(state: state, viewModel: viewModel)
            } else {
                Spacer()
                Text("No PTM data available")
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
        .background(Color(.systemBackground))
    }
}

// MARK: - PTMViewerHeader

struct PTMViewerHeader: View {
    @ObservedObject var viewModel: PTMViewerViewModel
    let onDismiss: () -> Void
    @Environment(\.horizontalSizeClass) var horizontalSizeClass

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                if let state = viewModel.ptmViewerState {
                    Text(state.accession)
                        .font(.headline)
                        .fontWeight(.bold)

                    if let geneName = state.geneName {
                        Text(geneName)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text("PTM Viewer")
                        .font(.headline)
                }
            }

            Spacer()

            // Close button for tablet/Mac
            if horizontalSizeClass == .regular {
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
    }
}

// MARK: - PTMErrorView

struct PTMErrorView: View {
    let error: String

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.orange)

            Text("Error Loading PTM Data")
                .font(.headline)

            Text(error)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer()
        }
        .padding()
    }
}

#Preview {
    PTMViewerContent(
        viewModel: PTMViewerViewModel(),
        onDismiss: {}
    )
}

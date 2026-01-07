//
//  DOILoaderView.swift
//  Curtain
//
//  Created by Toan Phung on 07/01/2026.
//

import SwiftUI

struct DOILoaderView: View {
    let doi: String
    let sessionId: String?
    let onSessionLoaded: ([String: Any]) -> Void
    let onDismiss: () -> Void

    @State private var viewModel = DOIViewModel()

    var body: some View {
        Group {
            switch viewModel.state {
            case .idle:
                ProgressView()
                    .onAppear {
                        Task {
                            await viewModel.loadDOI(doi, sessionId: sessionId)
                        }
                    }

            case .loading(let status):
                DOILoadingView(doi: doi, status: status)

            case .collection(let metadata, let parsedData):
                DOICollectionView(
                    doi: doi,
                    metadata: metadata,
                    parsedData: parsedData,
                    onSessionSelected: { sessionUrl in
                        Task {
                            await viewModel.loadSessionFromCollection(sessionUrl)
                        }
                    },
                    onDismiss: onDismiss
                )

            case .loadingSession(let status):
                DOILoadingView(doi: doi, status: status)

            case .completed(let sessionData):
                Color.clear
                    .onAppear {
                        onSessionLoaded(sessionData)
                    }

            case .error(let error):
                DOIErrorView(
                    doi: doi,
                    error: error,
                    onRetry: {
                        Task {
                            await viewModel.retry()
                        }
                    },
                    onDismiss: onDismiss
                )
            }
        }
    }
}

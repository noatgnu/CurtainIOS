//
//  PTMViewerScreen.swift
//  Curtain
//
//  Main PTM viewer screen with responsive layout
//

import SwiftUI

struct PTMViewerScreen: View {
    let linkId: String
    let accession: String
    let pCutoff: Double
    let fcCutoff: Double
    let customPTMData: [String: Any]
    let variantCorrection: [String: Any]
    let customSequences: [String: Any]
    let onDismiss: () -> Void

    @StateObject private var viewModel = PTMViewerViewModel()
    @Environment(\.horizontalSizeClass) var horizontalSizeClass

    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                // Tablet/Mac: Show as dialog
                PTMViewerContent(viewModel: viewModel, onDismiss: onDismiss)
                    .frame(minWidth: 600, maxWidth: 900, minHeight: 500, maxHeight: 700)
            } else {
                // Phone: Full screen with navigation
                NavigationStack {
                    PTMViewerContent(viewModel: viewModel, onDismiss: onDismiss)
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarLeading) {
                                Button("Close") {
                                    onDismiss()
                                }
                            }
                        }
                }
            }
        }
        .task {
            print("[PTMViewerScreen] Loading PTM data for linkId: \(linkId), accession: \(accession)")
            await viewModel.loadData(
                linkId: linkId,
                accession: accession,
                pCutoff: pCutoff,
                fcCutoff: fcCutoff,
                customPTMData: customPTMData,
                variantCorrection: variantCorrection,
                customSequences: customSequences
            )
        }
    }
}

#Preview {
    PTMViewerScreen(
        linkId: "test",
        accession: "P12345",
        pCutoff: 0.05,
        fcCutoff: 0.6,
        customPTMData: [:],
        variantCorrection: [:],
        customSequences: [:],
        onDismiss: {}
    )
}

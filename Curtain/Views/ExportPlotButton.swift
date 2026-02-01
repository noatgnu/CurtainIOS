//
//  ExportPlotButton.swift
//  Curtain
//
//  Created by Toan Phung on 09/08/2025.
//

import SwiftUI
import WebKit

// MARK: - Simple Export Plot Button

struct ExportPlotButton: View {
    var useToolbarStyle: Bool = false
    @State private var isExporting = false
    @State private var showingShareSheet = false
    @State private var exportedImage: UIImage?
    @State private var showingError = false
    @State private var errorMessage = ""

    var body: some View {
        Button(action: {
            captureAndShare()
        }) {
            if useToolbarStyle {
                Image(systemName: isExporting ? "arrow.up.circle.fill" : "square.and.arrow.up")
                    .font(.body)
                    .foregroundColor(isExporting ? .gray : .accentColor)
            } else {
                Image(systemName: isExporting ? "arrow.up.circle.fill" : "square.and.arrow.up")
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(isExporting ? Color.gray : Color.purple)
                    .clipShape(Circle())
                    .shadow(radius: 4)
            }
        }
        .buttonStyle(.plain)
        .disabled(isExporting)
        .overlay(alignment: .topTrailing) {
            if isExporting {
                ProgressView()
                    .scaleEffect(0.6)
                    .background(Circle().fill(Color.white.opacity(0.8)))
                    .offset(x: 8, y: -8)
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            if let image = exportedImage {
                ShareSheet(activityItems: [image])
            }
        }
        .alert("Export Failed", isPresented: $showingError) {
            Button("OK") {}
        } message: {
            Text(errorMessage)
        }
    }

    private func captureAndShare() {
        guard let webView = PlotlyCoordinator.getCurrentWebView() else {
            errorMessage = "No plot available to export"
            showingError = true
            return
        }

        isExporting = true

        let config = WKSnapshotConfiguration()
        webView.takeSnapshot(with: config) { image, error in
            DispatchQueue.main.async {
                isExporting = false
                if let image = image {
                    exportedImage = image
                    showingShareSheet = true
                } else {
                    errorMessage = error?.localizedDescription ?? "Failed to capture plot"
                    showingError = true
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    VStack {
        Text("Export Plot Preview")
        ExportPlotButton()
            .padding()
    }
}

//
//  ExportPlotButton.swift
//  Curtain
//
//  Created by Toan Phung on 09/08/2025.
//

import SwiftUI

// MARK: - Simple Export Plot Button

struct ExportPlotButton: View {
    var useToolbarStyle: Bool = false
    @ObservedObject private var exportService = PlotExportService.shared
    @State private var showingShareSheet = false
    @State private var showingError = false
    @State private var errorMessage = ""

    var body: some View {
        Button(action: {
            exportPlot()
        }) {
            if useToolbarStyle {
                Image(systemName: exportService.isExporting ? "arrow.up.circle.fill" : "square.and.arrow.up")
                    .font(.body)
                    .foregroundColor(exportService.isExporting ? .gray : .accentColor)
            } else {
                Image(systemName: exportService.isExporting ? "arrow.up.circle.fill" : "square.and.arrow.up")
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(exportService.isExporting ? Color.gray : Color.purple)
                    .clipShape(Circle())
                    .shadow(radius: 4)
            }
        }
        .buttonStyle(.plain)
        .disabled(exportService.isExporting)
        .overlay(alignment: .topTrailing) {
            if exportService.isExporting {
                ProgressView()
                    .scaleEffect(0.6)
                    .background(Circle().fill(Color.white.opacity(0.8)))
                    .offset(x: 8, y: -8)
            }
        }
        .sheet(isPresented: $showingShareSheet, onDismiss: {
            exportService.exportedShareItems = nil
        }) {
            if let items = exportService.exportedShareItems {
                ShareSheet(activityItems: items)
            }
        }
        .alert("Export Failed", isPresented: $showingError) {
            Button("OK") {}
        } message: {
            Text(errorMessage)
        }
        .onReceive(exportService.$exportedShareItems) { items in
            if items != nil {
                showingShareSheet = true
            }
        }
        .onReceive(exportService.$exportError) { error in
            if let error = error {
                errorMessage = error
                showingError = true
            }
        }
    }

    private func exportPlot() {
        guard PlotlyCoordinator.getCurrentWebView() != nil else {
            errorMessage = "No plot available to export"
            showingError = true
            return
        }

        // Use Plotly's native PNG export
        let dimensions = PlotExportOptions.ExportQuality.high.dimensions
        PlotlyWebView.exportCurrentPlotAsPNG(width: dimensions.width, height: dimensions.height)
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

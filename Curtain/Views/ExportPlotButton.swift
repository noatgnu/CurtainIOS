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
    @ObservedObject private var exportService = PlotExportService.shared
    @State private var showingOptions = false
    @State private var showingShareSheet = false
    @State private var showingFileSaver = false
    @State private var showingError = false
    @State private var errorMessage = ""

    var body: some View {
        HStack(spacing: 4) {
            if showingOptions {
                exportOptionsButtons
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showingOptions.toggle()
                }
            } label: {
                if useToolbarStyle {
                    Image(systemName: showingOptions ? "xmark.circle" : "square.and.arrow.up")
                        .font(.body)
                        .foregroundColor(exportService.isExporting ? .gray : .accentColor)
                } else {
                    Image(systemName: showingOptions ? "xmark.circle.fill" : "square.and.arrow.up")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(showingOptions ? Color.gray : Color.purple)
                        .clipShape(Circle())
                        .shadow(radius: 4)
                }
            }
            .disabled(exportService.isExporting)
        }
        .sheet(isPresented: $showingShareSheet, onDismiss: {
            exportService.exportedShareItems = nil
        }) {
            if let items = exportService.exportedShareItems {
                ShareSheet(activityItems: items)
            }
        }
        .sheet(isPresented: $showingFileSaver) {
            if let url = exportService.exportedFileURL {
                DocumentExportView(fileURL: url) {
                    showingFileSaver = false
                    try? FileManager.default.removeItem(at: url)
                    exportService.exportedFileURL = nil
                }
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
        .onReceive(exportService.$exportedFileURL) { url in
            if url != nil {
                showingFileSaver = true
            }
        }
        .onReceive(exportService.$exportError) { error in
            if let error = error {
                errorMessage = error
                showingError = true
            }
        }
    }

    @ViewBuilder
    private var exportOptionsButtons: some View {
        if useToolbarStyle {
            Button("PNG") { triggerExport(format: "png", action: .saveToFile) }
                .font(.caption)
            Button("SVG") { triggerExport(format: "svg", action: .saveToFile) }
                .font(.caption)
            Button {
                triggerExport(format: "png", action: .share)
            } label: {
                Image(systemName: "square.and.arrow.up.on.square")
                    .font(.caption)
            }
        } else {
            Button("PNG") { triggerExport(format: "png", action: .saveToFile) }
                .buttonStyle(.bordered)
            Button("SVG") { triggerExport(format: "svg", action: .saveToFile) }
                .buttonStyle(.bordered)
            Button {
                triggerExport(format: "png", action: .share)
            } label: {
                Image(systemName: "square.and.arrow.up.on.square")
            }
            .buttonStyle(.bordered)
        }
    }

    private func triggerExport(format: String, action: PlotExportService.ExportAction) {
        guard PlotlyCoordinator.getCurrentWebView() != nil else {
            errorMessage = "No plot available to export"
            showingError = true
            return
        }

        withAnimation(.easeInOut(duration: 0.2)) {
            showingOptions = false
        }

        exportService.pendingAction = action
        let dimensions = PlotExportOptions.ExportQuality.high.dimensions

        switch format {
        case "png":
            PlotlyWebView.exportCurrentPlotAsPNG(width: dimensions.width, height: dimensions.height)
        case "svg":
            PlotlyWebView.exportCurrentPlotAsSVG(width: dimensions.width, height: dimensions.height)
        default:
            break
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

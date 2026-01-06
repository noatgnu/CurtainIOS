//
//  PlotExportButton.swift
//  Curtain
//
//  Created by Toan Phung on 09/08/2025.
//

import SwiftUI

// MARK: - Plot Export Button

struct PlotExportButton: View {
    let plotlyWebView: PlotlyWebView?
    @ObservedObject private var exportService = PlotExportService.shared
    @State private var showingExportOptions = false
    @State private var selectedFormat: PlotExportOptions.ExportFormat = .png
    @State private var selectedQuality: PlotExportOptions.ExportQuality = .high
    @State private var customWidth = 1200
    @State private var customHeight = 800
    @State private var showingSuccessMessage = false
    @State private var successMessage = ""
    
    var body: some View {
        Group {
            if UIDevice.current.userInterfaceIdiom == .pad {
                // iPad: Menu button in toolbar
                Menu {
                    exportMenuItems
                } label: {
                    Label("Export Plot", systemImage: "square.and.arrow.up")
                } primaryAction: {
                    quickExport()
                }
            } else {
                // iPhone: Button that shows action sheet
                Button(action: {
                    showingExportOptions = true
                }) {
                    Label("Export", systemImage: "square.and.arrow.up")
                        .font(.caption)
                }
            }
        }
        .disabled(exportService.isExporting)
        .overlay(alignment: .topTrailing) {
            if exportService.isExporting {
                ProgressView()
                    .scaleEffect(0.7)
                    .offset(x: 4, y: -4)
            }
        }
        .actionSheet(isPresented: $showingExportOptions) {
            ActionSheet(
                title: Text("Export Plot"),
                message: Text("Choose export format and quality"),
                buttons: [
                    .default(Text("PNG - High Quality")) {
                        exportPlot(format: .png, quality: .high)
                    },
                    .default(Text("PNG - Publication")) {
                        exportPlot(format: .png, quality: .publication)
                    },
                    .default(Text("SVG - High Quality")) {
                        exportPlot(format: .svg, quality: .high)
                    },
                    .default(Text("SVG - Publication")) {
                        exportPlot(format: .svg, quality: .publication)
                    },
                    .default(Text("Custom Settings...")) {
                        showingExportOptions = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            showingExportOptions = false // Will trigger sheet instead
                        }
                    },
                    .cancel()
                ]
            )
        }
        .sheet(isPresented: $showingExportOptions) {
            if UIDevice.current.userInterfaceIdiom == .pad {
                ExportOptionsSheet(
                    exportService: exportService,
                    selectedFormat: $selectedFormat,
                    selectedQuality: $selectedQuality,
                    customWidth: $customWidth,
                    customHeight: $customHeight,
                    onExport: { format, quality, width, height in
                        exportPlot(format: format, quality: quality, width: width, height: height)
                    }
                )
                .presentationDetents([.medium])
            }
        }
        .alert("Export Successful", isPresented: $showingSuccessMessage) {
            Button("OK") { }
        } message: {
            Text(successMessage)
        }
        .alert("Export Error", isPresented: .constant(exportService.exportError != nil)) {
            Button("OK") { 
                exportService.exportError = nil
            }
        } message: {
            Text(exportService.exportError ?? "Unknown error")
        }
        .onReceive(exportService.$lastExportResult) { result in
            if let result = result, result.success {
                successMessage = "Exported \(result.filename) to Files app"
                showingSuccessMessage = true
            }
        }
    }
    
    // MARK: - Menu Items (iPad)
    
    @ViewBuilder
    private var exportMenuItems: some View {
        Button(action: {
            exportPlot(format: .png, quality: .high)
        }) {
            Label("PNG - High Quality", systemImage: "photo")
        }
        
        Button(action: {
            exportPlot(format: .png, quality: .publication)
        }) {
            Label("PNG - Publication", systemImage: "photo.badge.plus")
        }
        
        Button(action: {
            exportPlot(format: .svg, quality: .high)
        }) {
            Label("SVG - High Quality", systemImage: "doc.richtext")
        }
        
        Button(action: {
            exportPlot(format: .svg, quality: .publication)
        }) {
            Label("SVG - Publication", systemImage: "doc.richtext.badge.plus")
        }
        
        Divider()
        
        Button(action: {
            showingExportOptions = true
        }) {
            Label("Custom Settings...", systemImage: "gearshape")
        }
    }
    
    // MARK: - Export Methods
    
    private func quickExport() {
        exportPlot(format: .png, quality: .high)
    }
    
    private func exportPlot(
        format: PlotExportOptions.ExportFormat, 
        quality: PlotExportOptions.ExportQuality,
        width: Int? = nil,
        height: Int? = nil
    ) {
        guard let plotlyWebView = plotlyWebView else {
            print("❌ PlotExportButton: PlotlyWebView not available")
            return
        }
        
        let dimensions = quality.dimensions
        let finalWidth = width ?? dimensions.width
        let finalHeight = height ?? dimensions.height
        
        print("📤 PlotExportButton: Exporting \(format.rawValue.uppercased()) at \(finalWidth)x\(finalHeight)")
        
        switch format {
        case .png:
            plotlyWebView.exportAsPNG(width: finalWidth, height: finalHeight)
        case .svg:
            plotlyWebView.exportAsSVG(width: finalWidth, height: finalHeight)
        }
    }
}

// MARK: - Export Options Sheet

struct ExportOptionsSheet: View {
    @ObservedObject var exportService: PlotExportService
    @Binding var selectedFormat: PlotExportOptions.ExportFormat
    @Binding var selectedQuality: PlotExportOptions.ExportQuality
    @Binding var customWidth: Int
    @Binding var customHeight: Int
    let onExport: (PlotExportOptions.ExportFormat, PlotExportOptions.ExportQuality, Int, Int) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("Export Format") {
                    Picker("Format", selection: $selectedFormat) {
                        ForEach(PlotExportOptions.ExportFormat.allCases, id: \.self) { format in
                            HStack {
                                Image(systemName: format == .png ? "photo" : "doc.richtext")
                                Text(format.rawValue.uppercased())
                            }
                            .tag(format)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    Text(selectedFormat == .png ? 
                         "PNG files are ideal for presentations and web use" : 
                         "SVG files are perfect for publications and printing")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section("Quality & Size") {
                    Picker("Quality", selection: $selectedQuality) {
                        ForEach(PlotExportOptions.ExportQuality.allCases, id: \.self) { quality in
                            Text(quality.displayName).tag(quality)
                        }
                    }
                    
                    if selectedQuality == .custom {
                        HStack {
                            Text("Width")
                            Spacer()
                            TextField("Width", value: $customWidth, formatter: NumberFormatter())
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                            Text("px")
                        }
                        
                        HStack {
                            Text("Height")
                            Spacer()
                            TextField("Height", value: $customHeight, formatter: NumberFormatter())
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                            Text("px")
                        }
                    }
                }
                
                Section("Export Location") {
                    HStack {
                        Image(systemName: "folder")
                        Text("Files App > Curtain_Exports")
                        Spacer()
                        Text("Local Storage")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Export Options")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    dismiss()
                },
                trailing: Button("Export") {
                    let dimensions = selectedQuality == .custom ?
                        (customWidth, customHeight) :
                        selectedQuality.dimensions

                    onExport(selectedFormat, selectedQuality, dimensions.0, dimensions.1)
                    dismiss()
                }
                .disabled(exportService.isExporting)
            )
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationView {
        VStack {
            Text("Plot Export Preview")
            PlotExportButton(plotlyWebView: nil)
                .padding()
        }
    }
}
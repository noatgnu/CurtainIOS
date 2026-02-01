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
    @State private var showingExportOptions = false
    @State private var isExporting = false

    var body: some View {
        Button(action: {
            if UIDevice.current.userInterfaceIdiom == .pad {
                // iPad: Show export sheet
                showingExportOptions = true
            } else {
                // iPhone: Quick export
                quickExport()
            }
        }) {
            if useToolbarStyle {
                Image(systemName: isExporting ? "arrow.up.circle.fill" : "square.and.arrow.up")
                    .font(.body)
                    .foregroundColor(isExporting ? .gray : .purple)
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
        .sheet(isPresented: $showingExportOptions) {
            ExportOptionsView(onExport: { format, quality in
                performExport(format: format, quality: quality)
            })
        }
        .overlay(alignment: .topTrailing) {
            if isExporting {
                ProgressView()
                    .scaleEffect(0.6)
                    .background(Circle().fill(Color.white.opacity(0.8)))
                    .offset(x: 8, y: -8)
            }
        }
    }
    
    private func quickExport() {
        performExport(format: .png, quality: .high)
    }
    
    private func performExport(format: PlotExportOptions.ExportFormat, quality: PlotExportOptions.ExportQuality) {
        isExporting = true
        
        // Get the dimensions for the quality setting
        let dimensions = quality.dimensions
        
        // Use the static PlotlyWebView method to trigger export
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            switch format {
            case .png:
                PlotlyWebView.exportCurrentPlotAsPNG(width: dimensions.width, height: dimensions.height)
            case .svg:
                PlotlyWebView.exportCurrentPlotAsSVG(width: dimensions.width, height: dimensions.height)
            }
            
            // Reset the exporting state after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                isExporting = false
            }
        }
    }
}

// MARK: - Export Options View

struct ExportOptionsView: View {
    let onExport: (PlotExportOptions.ExportFormat, PlotExportOptions.ExportQuality) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var selectedFormat: PlotExportOptions.ExportFormat = .png
    @State private var selectedQuality: PlotExportOptions.ExportQuality = .high
    
    var body: some View {
        NavigationStack {
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
                         "PNG files are ideal for presentations and sharing" : 
                         "SVG files are perfect for publications and printing")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section("Quality & Size") {
                    Picker("Quality", selection: $selectedQuality) {
                        ForEach(PlotExportOptions.ExportQuality.allCases.filter { $0 != .custom }, id: \.self) { quality in
                            Text(quality.displayName).tag(quality)
                        }
                    }
                    .pickerStyle(.wheel)
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
                
                Section {
                    Button("Export Plot") {
                        onExport(selectedFormat, selectedQuality)
                        dismiss()
                    }
                    .frame(maxWidth: .infinity)
                    .buttonStyle(.borderedProminent)
                }
            }
            .navigationTitle("Export Plot")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .fixedSize()
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
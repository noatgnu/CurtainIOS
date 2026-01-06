//
//  PlotExportService.swift
//  Curtain
//
//  Created by Toan Phung on 09/08/2025.
//

import Foundation
import UIKit

// MARK: - Export Models

struct PlotExportOptions {
    let format: ExportFormat
    let width: Int
    let height: Int
    let filename: String
    let quality: ExportQuality
    
    enum ExportFormat: String, CaseIterable {
        case png = "png"
        case svg = "svg"
        
        var fileExtension: String { rawValue }
        var mimeType: String {
            switch self {
            case .png: return "image/png"
            case .svg: return "image/svg+xml"
            }
        }
    }
    
    enum ExportQuality: String, CaseIterable {
        case standard = "standard"     // 1200x800
        case high = "high"            // 1800x1200  
        case publication = "publication" // 2400x1600
        case custom = "custom"
        
        var dimensions: (width: Int, height: Int) {
            switch self {
            case .standard: return (1200, 800)
            case .high: return (1800, 1200)
            case .publication: return (2400, 1600)
            case .custom: return (1200, 800) // Will be overridden
            }
        }
        
        var displayName: String {
            switch self {
            case .standard: return "Standard (1200×800)"
            case .high: return "High (1800×1200)"
            case .publication: return "Publication (2400×1600)"
            case .custom: return "Custom Size"
            }
        }
    }
}

struct PlotExportResult {
    let success: Bool
    let filename: String
    let filePath: String?
    let format: PlotExportOptions.ExportFormat
    let error: String?
    let fileSize: Int64?
}

// MARK: - Export Service

@MainActor
class PlotExportService: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = PlotExportService()
    
    // MARK: - Published Properties
    
    @Published var isExporting = false
    @Published var exportProgress: Double = 0.0
    @Published var lastExportResult: PlotExportResult?
    @Published var exportError: String?
    
    // MARK: - Private Properties
    
    private let fileManager = FileManager.default
    
    private init() {} // Private initializer for singleton
    
    // MARK: - Public Methods
    
    /// Generate a filename for plot export based on plot type and timestamp
    func generateFilename(plotType: String, title: String, format: PlotExportOptions.ExportFormat) -> String {
        let cleanTitle = title.replacingOccurrences(of: " ", with: "_")
                              .replacingOccurrences(of: "[^a-zA-Z0-9_-]", with: "", options: .regularExpression)
                              .prefix(30)
        
        let timestamp = DateFormatter.filenameSafe.string(from: Date())
        return "\(plotType)_\(cleanTitle)_\(timestamp).\(format.fileExtension)"
    }
    
    /// Process plot export data from JavaScript and save to Files app
    func processExportData(_ exportData: [String: Any]) async -> PlotExportResult {
        isExporting = true
        exportProgress = 0.1
        exportError = nil
        
        defer {
            isExporting = false
            exportProgress = 0.0
        }
        
        guard let formatString = exportData["format"] as? String,
              let format = PlotExportOptions.ExportFormat(rawValue: formatString),
              let dataURL = exportData["dataURL"] as? String,
              let filename = exportData["filename"] as? String else {
            
            let error = "Invalid export data format"
            exportError = error
            let result = PlotExportResult(success: false, filename: "", filePath: nil, format: .png, error: error, fileSize: nil)
            lastExportResult = result
            return result
        }
        
        exportProgress = 0.3
        
        do {
            // Convert data URL to Data
            let imageData = try convertDataURLToData(dataURL)
            exportProgress = 0.6
            
            // Save to Files app
            let filePath = try await saveToFiles(data: imageData, filename: filename, format: format)
            exportProgress = 0.9
            
            let fileSize = Int64(imageData.count)
            exportProgress = 1.0
            
            let result = PlotExportResult(
                success: true,
                filename: filename,
                filePath: filePath,
                format: format,
                error: nil,
                fileSize: fileSize
            )
            
            lastExportResult = result
            print("✅ PlotExportService: Successfully exported \(format.rawValue.uppercased()) plot to \(filePath)")
            return result
            
        } catch {
            let errorMessage = "Export failed: \(error.localizedDescription)"
            exportError = errorMessage
            let result = PlotExportResult(success: false, filename: filename, filePath: nil, format: format, error: errorMessage, fileSize: nil)
            lastExportResult = result
            print("❌ PlotExportService: Export failed - \(errorMessage)")
            return result
        }
    }
    
    /// Get default export options for a given plot type
    func getDefaultExportOptions(plotType: String, title: String) -> PlotExportOptions {
        let format: PlotExportOptions.ExportFormat = plotType.lowercased().contains("volcano") ? .png : .svg
        let quality: PlotExportOptions.ExportQuality = .high
        let dimensions = quality.dimensions
        
        return PlotExportOptions(
            format: format,
            width: dimensions.width,
            height: dimensions.height,
            filename: generateFilename(plotType: plotType, title: title, format: format),
            quality: quality
        )
    }
    
    /// Get available export directory path
    func getExportsDirectory() -> URL {
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let exportsURL = documentsURL.appendingPathComponent("Curtain_Exports", isDirectory: true)
        
        // Create directory if it doesn't exist
        try? fileManager.createDirectory(at: exportsURL, withIntermediateDirectories: true)
        
        return exportsURL
    }
    
    // MARK: - Private Methods
    
    private func convertDataURLToData(_ dataURL: String) throws -> Data {
        // Extract the base64 part from data URL (format: "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAA...")
        guard let range = dataURL.range(of: ","),
              let base64String = String(dataURL[range.upperBound...]).removingPercentEncoding,
              let data = Data(base64Encoded: base64String) else {
            throw PlotExportError.invalidDataURL
        }
        
        return data
    }
    
    private func saveToFiles(data: Data, filename: String, format: PlotExportOptions.ExportFormat) async throws -> String {
        let exportsDirectory = getExportsDirectory()
        let fileURL = exportsDirectory.appendingPathComponent(filename)
        
        // Write the file
        try data.write(to: fileURL)
        
        // Exclude from iCloud backup to keep it local
        try excludeFromiCloudBackup(url: fileURL)
        
        return fileURL.path
    }
    
    private func excludeFromiCloudBackup(url: URL) throws {
        var mutableURL = url
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        try mutableURL.setResourceValues(resourceValues)
    }
}

// MARK: - Export Errors

enum PlotExportError: Error, LocalizedError {
    case invalidDataURL
    case unsupportedFormat
    case fileWriteError
    case insufficientStorage
    
    var errorDescription: String? {
        switch self {
        case .invalidDataURL:
            return "Invalid image data received from plot"
        case .unsupportedFormat:
            return "Unsupported export format"
        case .fileWriteError:
            return "Failed to save exported file"
        case .insufficientStorage:
            return "Insufficient storage space"
        }
    }
}

// MARK: - Extensions

extension DateFormatter {
    static let filenameSafe: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
}
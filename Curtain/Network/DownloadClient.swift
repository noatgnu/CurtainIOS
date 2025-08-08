//
//  DownloadClient.swift
//  Curtain
//
//  Created by Toan Phung on 02/08/2025.
//

import Foundation

// MARK: - Download Client (Based on Android DownloadClient.kt)

class DownloadClient {
    private let session: URLSession
    private var currentTask: URLSessionDataTask?
    private let bufferSize = 8192 // 8KB buffer like Android
    
    static let shared = DownloadClient()
    
    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        configuration.httpAdditionalHeaders = [:]
        
        self.session = URLSession(configuration: configuration)
    }
    
    // MARK: - Public Methods
    
    /// Downloads a file from URL to the specified file path
    /// - Parameters:
    ///   - url: The URL to download from
    ///   - destinationPath: The path where the file should be saved
    ///   - progressCallback: Optional callback for progress updates (progress: Int, speedKBps: Double)
    /// - Returns: The downloaded file URL
    /// - Throws: DownloadError if the download fails
    func downloadFile(
        from url: String,
        to destinationPath: String,
        progressCallback: ((Int, Double) -> Void)? = nil
    ) async throws -> URL {
        
        guard let downloadURL = URL(string: url) else {
            throw DownloadError.invalidURL
        }
        
        print("DownloadClient: Starting download from: \(url)")
        progressCallback?(0, 0.0)
        
        let destinationURL = URL(fileURLWithPath: destinationPath)
        
        // Create parent directories if needed
        try FileManager.default.createDirectory(
            at: destinationURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        
        return try await withCheckedThrowingContinuation { continuation in
            currentTask = session.dataTask(with: downloadURL) { [weak self] data, response, error in
                
                if let error = error {
                    if (error as NSError).code == NSURLErrorCancelled {
                        continuation.resume(throwing: DownloadError.cancelled)
                    } else {
                        continuation.resume(throwing: DownloadError.networkError(error))
                    }
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    continuation.resume(throwing: DownloadError.invalidResponse)
                    return
                }
                
                guard 200...299 ~= httpResponse.statusCode else {
                    continuation.resume(throwing: DownloadError.serverError(httpResponse.statusCode))
                    return
                }
                
                guard let data = data else {
                    continuation.resume(throwing: DownloadError.noData)
                    return
                }
                
                progressCallback?(10, 0.0) // Connected, starting file write
                
                do {
                    // Write data to file
                    try self?.writeDataToFile(
                        data: data,
                        destinationURL: destinationURL,
                        contentLength: httpResponse.expectedContentLength,
                        progressCallback: progressCallback
                    )
                    
                    progressCallback?(100, 0.0)
                    self?.currentTask = nil
                    continuation.resume(returning: destinationURL)
                    
                } catch {
                    continuation.resume(throwing: error)
                }
            }
            
            currentTask?.resume()
        }
    }
    
    /// Downloads file with streaming support for large files
    func downloadFileWithStreaming(
        from url: String,
        to destinationPath: String,
        progressCallback: ((Int, Double) -> Void)? = nil
    ) async throws -> URL {
        
        guard let downloadURL = URL(string: url) else {
            throw DownloadError.invalidURL
        }
        
        print("DownloadClient: Starting streaming download from: \(url)")
        progressCallback?(0, 0.0)
        
        let destinationURL = URL(fileURLWithPath: destinationPath)
        
        // Create parent directories if needed
        try FileManager.default.createDirectory(
            at: destinationURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        
        return try await withCheckedThrowingContinuation { continuation in
            var receivedData = Data()
            var totalBytesReceived: Int64 = 0
            var expectedContentLength: Int64 = 0
            let startTime = Date()
            var lastSpeedUpdate = startTime
            var hasCompleted = false
            
            currentTask = session.dataTask(with: downloadURL) { [weak self] data, response, error in
                
                // Prevent multiple completion calls
                guard !hasCompleted else { return }
                
                if let error = error {
                    hasCompleted = true
                    self?.currentTask = nil
                    if (error as NSError).code == NSURLErrorCancelled {
                        continuation.resume(throwing: DownloadError.cancelled)
                    } else {
                        continuation.resume(throwing: DownloadError.networkError(error))
                    }
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    hasCompleted = true
                    self?.currentTask = nil
                    continuation.resume(throwing: DownloadError.invalidResponse)
                    return
                }
                
                guard 200...299 ~= httpResponse.statusCode else {
                    hasCompleted = true
                    self?.currentTask = nil
                    continuation.resume(throwing: DownloadError.serverError(httpResponse.statusCode))
                    return
                }
                
                if expectedContentLength == 0 {
                    expectedContentLength = httpResponse.expectedContentLength
                    progressCallback?(10, 0.0)
                }
                
                if let data = data {
                    receivedData.append(data)
                    totalBytesReceived += Int64(data.count)
                    
                    // Calculate progress and speed (like Android - every 500ms)
                    let currentTime = Date()
                    if expectedContentLength > 0 && currentTime.timeIntervalSince(lastSpeedUpdate) >= 0.5 {
                        let progress = min(Int((totalBytesReceived * 90 / expectedContentLength)) + 10, 100)
                        
                        let elapsedSeconds = currentTime.timeIntervalSince(startTime)
                        let speedKBps = elapsedSeconds > 0 ? Double(totalBytesReceived) / 1024.0 / elapsedSeconds : 0.0
                        
                        progressCallback?(progress, speedKBps)
                        lastSpeedUpdate = currentTime
                    }
                } else {
                    // No more data - download complete
                    hasCompleted = true
                    self?.currentTask = nil
                    
                    do {
                        try receivedData.write(to: destinationURL)
                        progressCallback?(100, 0.0)
                        continuation.resume(returning: destinationURL)
                    } catch {
                        continuation.resume(throwing: DownloadError.fileWriteError(error))
                    }
                }
            }
            
            currentTask?.resume()
        }
    }
    
    /// Cancels the current download
    func cancelDownload() {
        currentTask?.cancel()
        currentTask = nil
    }
    
    // MARK: - Private Methods
    
    private func writeDataToFile(
        data: Data,
        destinationURL: URL,
        contentLength: Int64,
        progressCallback: ((Int, Double) -> Void)?
    ) throws {
        
        let startTime = Date()
        
        try data.write(to: destinationURL)
        
        // Simulate progress for small files
        let elapsedSeconds = Date().timeIntervalSince(startTime)
        let speedKBps = elapsedSeconds > 0 ? Double(data.count) / 1024.0 / elapsedSeconds : 0.0
        
        progressCallback?(70, speedKBps)
    }
}

// MARK: - Download Errors

enum DownloadError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case serverError(Int)
    case networkError(Error)
    case noData
    case cancelled
    case fileWriteError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid download URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .serverError(let code):
            return "Server error: \(code)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .noData:
            return "No data received"
        case .cancelled:
            return "Download cancelled"
        case .fileWriteError(let error):
            return "File write error: \(error.localizedDescription)"
        }
    }
}
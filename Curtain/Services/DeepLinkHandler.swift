//
//  DeepLinkHandler.swift
//  Curtain
//
//  Created by Toan Phung on 02/08/2025.
//

import Foundation
import SwiftUI

// MARK: - Deep Link Handler (Based on Android Intent handling)

@MainActor
@Observable
class DeepLinkHandler {
    static let shared = DeepLinkHandler()
    
    // State for pending deep link processing
    var pendingURL: URL?
    var isProcessing = false
    var error: String?
    
    private init() {}
    
    // MARK: - Deep Link Processing (Like Android Intent.ACTION_VIEW)
    
    /// Process a deep link URL (from QR code, share, or app launch)
    func processURL(_ url: URL) async -> DeepLinkResult {
        print("🔗 DeepLinkHandler: Processing URL: \(url.absoluteString)")
        
        isProcessing = true
        defer { isProcessing = false }
        
        // Check for different URL patterns (like Android)
        if let result = await processCurtainProteoURL(url) {
            return result
        }
        
        if let result = await processCurtainSessionURL(url) {
            return result
        }
        
        if let result = await processGenericCurtainURL(url) {
            return result
        }
        
        // If no pattern matches, try to extract components
        return await processUnknownURL(url)
    }
    
    // MARK: - URL Pattern Processors (Like Android URL parsing)
    
    /// Process curtain.proteo.info URLs (like Android proteo intent handling)
    private func processCurtainProteoURL(_ url: URL) async -> DeepLinkResult? {
        let urlString = url.absoluteString
        
        // Check if it's a proteo URL
        guard CurtainConstants.URLPatterns.isProteoURL(urlString),
              let linkId = CurtainConstants.URLPatterns.extractLinkIdFromProteoURL(urlString) else {
            return nil
        }
        
        print("🔗 DeepLinkHandler: Detected curtain.proteo.info URL with linkId: \(linkId)")
        
        return DeepLinkResult(
            type: .curtainSession,
            linkId: linkId,
            apiUrl: CurtainConstants.PredefinedHosts.celsusBackend,
            frontendUrl: CurtainConstants.PredefinedHosts.proteoFrontend,
            description: "Curtain Proteo Session"
        )
    }
    
    /// Process custom Curtain session URLs (like Android curtain://open scheme handling)
    private func processCurtainSessionURL(_ url: URL) async -> DeepLinkResult? {
        // Handle curtain:// URLs - must match Android pattern: curtain://open
        guard url.scheme == "curtain" && url.host == "open" else {
            return nil
        }
        
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let queryItems = components?.queryItems
        
        // Extract parameters using Android parameter names (with fallbacks)
        let linkId = queryItems?.first(where: { $0.name == "uniqueId" || $0.name == "unique_id" || $0.name == "id" })?.value
        let apiUrl = queryItems?.first(where: { $0.name == "apiURL" || $0.name == "api_url" || $0.name == "api" || $0.name == "host" })?.value
        let frontendUrl = queryItems?.first(where: { $0.name == "frontendURL" || $0.name == "frontend_url" || $0.name == "frontend" })?.value
        let description = queryItems?.first(where: { $0.name == "desc" || $0.name == "description" })?.value
        
        guard let linkId = linkId, let apiUrl = apiUrl else {
            return DeepLinkResult(
                type: .invalid,
                error: "Invalid link: Missing required parameters (uniqueId and apiURL)"
            )
        }
        
        print("🔗 DeepLinkHandler: Detected Android-compatible Curtain URL: \(linkId) at \(apiUrl)")
        
        return DeepLinkResult(
            type: .curtainSession,
            linkId: linkId,
            apiUrl: apiUrl,
            frontendUrl: frontendUrl,
            description: description ?? "Shared Curtain Session"
        )
    }
    
    /// Process generic Curtain URLs (like Android web intent handling)
    private func processGenericCurtainURL(_ url: URL) async -> DeepLinkResult? {
        guard let host = url.host else { return nil }
        
        // Check if it's a known Curtain host
        let knownHosts = [
            "curtain.proteo.info",
            "celsus.muttsu.xyz",
            "curtain-web.org"
        ]
        
        guard knownHosts.contains(where: { host.contains($0) }) else {
            return nil
        }
        
        // Try to extract linkId from path
        let pathComponents = url.pathComponents.filter { $0 != "/" }
        guard let linkId = pathComponents.last, !linkId.isEmpty else {
            return DeepLinkResult(
                type: .invalid,
                error: "Could not extract session ID from URL path"
            )
        }
        
        // Determine API URL based on host
        let apiUrl: String
        if host.contains("curtain.proteo.info") {
            apiUrl = CurtainConstants.PredefinedHosts.celsusBackend
        } else {
            apiUrl = "https://\(host)/"
        }
        
        print("🔗 DeepLinkHandler: Detected generic Curtain URL: \(linkId) at \(apiUrl)")
        
        return DeepLinkResult(
            type: .curtainSession,
            linkId: linkId,
            apiUrl: apiUrl,
            frontendUrl: url.absoluteString,
            description: "Web Curtain Session"
        )
    }
    
    /// Process unknown URLs (fallback parser)
    private func processUnknownURL(_ url: URL) async -> DeepLinkResult {
        print("🔗 DeepLinkHandler: Unknown URL pattern: \(url.absoluteString)")
        
        // Try to extract any UUID-like strings as potential linkIds
        let uuidPattern = "[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}"
        let regex = try? NSRegularExpression(pattern: uuidPattern)
        
        if let match = regex?.firstMatch(in: url.absoluteString, range: NSRange(location: 0, length: url.absoluteString.count)) {
            let linkId = String(url.absoluteString[Range(match.range, in: url.absoluteString)!])
            let apiUrl = url.host.map { "https://\($0)/" } ?? ""
            
            print("🔗 DeepLinkHandler: Extracted potential linkId: \(linkId)")
            
            return DeepLinkResult(
                type: .curtainSession,
                linkId: linkId,
                apiUrl: apiUrl,
                frontendUrl: url.absoluteString,
                description: "Detected Curtain Session"
            )
        }
        
        return DeepLinkResult(
            type: .invalid,
            error: "Could not parse URL as Curtain session: \(url.absoluteString)"
        )
    }
    
    // MARK: - QR Code Processing
    
    /// Process QR code content (which might be a URL or encoded data)
    func processQRCode(_ content: String) async -> DeepLinkResult {
        print("🔗 DeepLinkHandler: Processing QR code content: \(content)")
        
        // First, try to parse as URL
        if let url = URL(string: content) {
            return await processURL(url)
        }
        
        // Try to parse as JSON (for encoded session data)
        if let jsonResult = await parseQRCodeJSON(content) {
            return jsonResult
        }
        
        // Try to parse as base64 encoded data
        if let decodedData = Data(base64Encoded: content),
           let decodedString = String(data: decodedData, encoding: .utf8) {
            return await processQRCode(decodedString) // Recursive call with decoded content
        }
        
        return DeepLinkResult(
            type: .invalid,
            error: "QR code content is not a valid URL or Curtain session data"
        )
    }
    
    /// Parse QR code as JSON session data
    private func parseQRCodeJSON(_ content: String) async -> DeepLinkResult? {
        guard let data = content.data(using: .utf8) else { return nil }
        
        do {
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            
            // Look for Curtain session data structure (Android parameter names first)
            if let linkId = json?["uniqueId"] as? String ?? json?["unique_id"] as? String ?? json?["linkId"] as? String ?? json?["id"] as? String,
               let apiUrl = json?["apiURL"] as? String ?? json?["api_url"] as? String ?? json?["apiUrl"] as? String ?? json?["api"] as? String ?? json?["host"] as? String {
                
                let frontendUrl = json?["frontendURL"] as? String ?? json?["frontend_url"] as? String ?? json?["frontendUrl"] as? String ?? json?["frontend"] as? String
                let description = json?["description"] as? String ?? json?["title"] as? String
                
                print("🔗 DeepLinkHandler: Parsed JSON session data: \(linkId)")
                
                return DeepLinkResult(
                    type: .curtainSession,
                    linkId: linkId,
                    apiUrl: apiUrl,
                    frontendUrl: frontendUrl,
                    description: description ?? "JSON Curtain Session"
                )
            }
        } catch {
            print("🔗 DeepLinkHandler: Failed to parse QR code as JSON: \(error)")
        }
        
        return nil
    }
}

// MARK: - Deep Link Result

struct DeepLinkResult {
    let type: DeepLinkType
    let linkId: String?
    let apiUrl: String?
    let frontendUrl: String?
    let description: String?
    let error: String?
    
    init(type: DeepLinkType, linkId: String? = nil, apiUrl: String? = nil, frontendUrl: String? = nil, description: String? = nil, error: String? = nil) {
        self.type = type
        self.linkId = linkId
        self.apiUrl = apiUrl
        self.frontendUrl = frontendUrl
        self.description = description
        self.error = error
    }
    
    var isValid: Bool {
        return type != .invalid && linkId != nil && apiUrl != nil
    }
}

enum DeepLinkType {
    case curtainSession
    case invalid
}

// MARK: - Deep Link Extensions

extension CurtainConstants {
    struct DeepLinks {
        static let scheme = "curtain"
        static let host = "open"
        
        /// Generate Android-compatible deep link URL for sharing a Curtain session
        /// Format: curtain://open?uniqueId=[UNIQUE_ID]&apiURL=[API_URL]&frontendURL=[FRONTEND_URL]
        static func generateSessionURL(linkId: String, apiUrl: String, frontendUrl: String? = nil) -> URL? {
            var components = URLComponents()
            components.scheme = scheme
            components.host = host
            
            var queryItems: [URLQueryItem] = [
                URLQueryItem(name: "uniqueId", value: linkId),
                URLQueryItem(name: "apiURL", value: apiUrl)
            ]
            
            if let frontendUrl = frontendUrl {
                queryItems.append(URLQueryItem(name: "frontendURL", value: frontendUrl))
            }
            
            components.queryItems = queryItems
            return components.url
        }
        
        /// Generate web share URL (like Android WebShareFragment)
        /// Format: [FRONTEND_URL]/#/[UNIQUE_ID]
        static func generateWebShareURL(linkId: String, frontendUrl: String) -> URL? {
            let cleanUrl = frontendUrl.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            let webUrlString = "\(cleanUrl)/#/\(linkId)"
            return URL(string: webUrlString)
        }
        
        /// Generate Android-compatible QR code content (deep link format)
        static func generateAndroidQRCode(linkId: String, apiUrl: String, frontendUrl: String? = nil) -> String? {
            return generateSessionURL(linkId: linkId, apiUrl: apiUrl, frontendUrl: frontendUrl)?.absoluteString
        }
        
        /// Generate web QR code content (web share format)
        static func generateWebQRCode(linkId: String, frontendUrl: String) -> String? {
            return generateWebShareURL(linkId: linkId, frontendUrl: frontendUrl)?.absoluteString
        }
        
        /// Generate JSON QR code data (custom format with extra metadata)
        static func generateJSONQRCodeData(linkId: String, apiUrl: String, frontendUrl: String? = nil, description: String? = nil) -> String? {
            let sessionData: [String: Any] = [
                "uniqueId": linkId,
                "apiURL": apiUrl,
                "frontendURL": frontendUrl ?? "",
                "description": description ?? "",
                "type": "curtain-session",
                "version": "1.0",
                "platform": "ios"
            ]
            
            do {
                let jsonData = try JSONSerialization.data(withJSONObject: sessionData)
                return String(data: jsonData, encoding: .utf8)
            } catch {
                print("Failed to generate JSON QR code data: \(error)")
                return nil
            }
        }
    }
}
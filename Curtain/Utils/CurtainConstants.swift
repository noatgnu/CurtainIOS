//
//  CurtainConstants.swift
//  Curtain
//
//  Created by Toan Phung on 02/08/2025.
//

import Foundation


struct CurtainConstants {
    
    
    struct PredefinedHosts {
        static let celsusBackend = "https://celsus.muttsu.xyz"
        static let questBackend = "https://curtain-backend.omics.quest"
        static let proteoFrontend = "https://curtain.proteo.info"
    }
    
    
    struct ExampleData {
        static let uniqueId = "f4b009f3-ac3c-470a-a68b-55fcadf68d0f"
        static let apiUrl = "https://celsus.muttsu.xyz/"
        static let frontendUrl = "https://curtain.proteo.info/"

        // Default description for example curtain
        static let description = "Example Proteomics Dataset"
        static let curtainType = "TP"
    }

    /// PTM (Post-Translational Modification) example dataset
    struct ExamplePTMData {
        static let uniqueId = "85970b1d-8052-4d6f-bf67-654396534d76"
        static let apiUrl = "https://celsus.muttsu.xyz/"
        static let frontendUrl = "https://curtainptm.proteo.info/"

        // Default description for PTM example curtain
        static let description = "Example PTM Dataset"
        static let curtainType = "PTM"
    }
    
    struct ExampleCollection {
        static let collectionId = 2
        static let apiUrl = "https://celsus.muttsu.xyz"
        static let frontendUrl = "https://curtain.proteo.info"
    }

    // MARK: - Common Hostnames for Site Settings
    
    static let commonHostnames = [
        PredefinedHosts.celsusBackend,
        PredefinedHosts.questBackend,
        "localhost",
        "https://your-curtain-server.com"
    ]
    
    
    struct URLPatterns {
        static let proteoHost = "curtain.proteo.info"
        
        /// Check if URL is curtain.proteo.info format: https://curtain.proteo.info/#/linkid
        static func isProteoURL(_ urlString: String) -> Bool {
            guard let url = URL(string: urlString),
                  let host = url.host else { return false }
            return host == proteoHost && url.fragment != nil
        }
        
        /// Extract link ID from curtain.proteo.info URL fragment
        static func extractLinkIdFromProteoURL(_ urlString: String) -> String? {
            guard let url = URL(string: urlString),
                  let host = url.host,
                  host == proteoHost,
                  let fragment = url.fragment else { return nil }
            // Remove leading "/" if present
            return fragment.hasPrefix("/") ? String(fragment.dropFirst()) : fragment
        }
    }
}
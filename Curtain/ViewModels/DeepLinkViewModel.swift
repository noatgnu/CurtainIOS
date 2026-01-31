//
//  DeepLinkViewModel.swift
//  Curtain
//
//  Created by Toan Phung on 07/01/2026.
//

import Foundation
import SwiftUI

@MainActor
@Observable
class DeepLinkViewModel {
    // DOI-related state
    var showDOILoader = false
    var pendingDOI: String?
    var pendingSessionId: String?

    // Regular Curtain session state
    var pendingCurtainSession: DeepLinkResult?

    // Collection state
    var pendingCollectionId: Int?
    var pendingCollectionApiUrl: String?
    var pendingCollectionFrontendUrl: String?

    /// Handle a deep link result from DeepLinkHandler
    func handleDeepLinkResult(_ result: DeepLinkResult) {
        guard result.isValid else {
            return
        }

        switch result.type {
        case .doiSession:
            if let doi = result.doi {
                pendingDOI = doi
                pendingSessionId = result.sessionId
                showDOILoader = true
            }

        case .curtainSession:
            pendingCurtainSession = result

        case .collection:
            if let collectionId = result.collectionId {
                pendingCollectionId = collectionId
                pendingCollectionApiUrl = result.collectionApiUrl
                pendingCollectionFrontendUrl = result.frontendUrl
            }

        case .invalid:
            break
        }
    }

    /// Clear DOI state after processing
    func clearDOIState() {
        showDOILoader = false
        pendingDOI = nil
        pendingSessionId = nil
    }

    /// Clear Curtain session state after processing
    func clearCurtainSessionState() {
        pendingCurtainSession = nil
    }

    /// Clear collection state after processing
    func clearCollectionState() {
        pendingCollectionId = nil
        pendingCollectionApiUrl = nil
        pendingCollectionFrontendUrl = nil
    }
}

//
//  ProteinColorResolver.swift
//  Curtain
//
//  Created by Toan Phung on 06/01/2026.
//

import Foundation
import Observation

// MARK: - Protein Color Resolver

/// Resolves protein colors based on selection groups and significance
/// Singleton service with caching for performance
@Observable
class ProteinColorResolver {

    // MARK: - Singleton

    static let shared = ProteinColorResolver()

    // MARK: - Cache

    private var colorCache: [String: String] = [:]

    private init() {}

    // MARK: - Public API

    /// Determine protein color based on selection groups and significance
    /// Extracted from PlotlyWebView.swift lines 781-840
    func resolveColor(
        proteinId: String,
        fcValue: Double,
        pValue: Double,
        curtainData: CurtainData,
        colorMap: [String: String]
    ) -> String {
        // Check cache first
        let cacheKey = "\(proteinId)-\(fcValue)-\(pValue)"
        if let cached = colorCache[cacheKey] {
            return cached
        }

        // Calculate color
        let color = calculateColor(
            proteinId: proteinId,
            fcValue: fcValue,
            pValue: pValue,
            curtainData: curtainData,
            colorMap: colorMap
        )

        // Cache result
        colorCache[cacheKey] = color
        return color
    }

    /// Clear cache when data changes
    func clearCache() {
        colorCache.removeAll()
    }

    // MARK: - Private Methods

    /// Determine protein color based on selection groups and significance 
    private func calculateColor(
        proteinId: String,
        fcValue: Double,
        pValue: Double,
        curtainData: CurtainData,
        colorMap: [String: String]
    ) -> String {

        // Check user selections first (highest priority)
        if let selectedMap = curtainData.selectedMap,
           let selectionForId = selectedMap[proteinId] {
            for (selectionName, isSelected) in selectionForId {
                if isSelected, let selectionColor = colorMap[selectionName] {
                    return selectionColor
                }
            }
        }

        // If no user selections, determine significance group and get its color
        let significanceGroup = getSignificanceGroup(
            fcValue: fcValue,
            pValue: pValue,
            settings: curtainData.settings
        )

        let groupColor = colorMap[significanceGroup] ?? "#cccccc"
        return groupColor
    }

    private func getSignificanceGroup(
        fcValue: Double,
        pValue: Double,
        settings: CurtainSettings
    ) -> String {
        let ylog = -log10(settings.pCutoff)
        let transformedPValue = -log10(max(pValue, 1e-300))
        var groups: [String] = []

        // P-value classification
        if transformedPValue < ylog {
            groups.append("P-value > \(settings.pCutoff)")
        } else {
            groups.append("P-value <= \(settings.pCutoff)")
        }

        // Fold change classification
        if abs(fcValue) > settings.log2FCCutoff {
            groups.append("FC > \(settings.log2FCCutoff)")
        } else {
            groups.append("FC <= \(settings.log2FCCutoff)")
        }

        // Create full group name with comparison
        let groupText = groups.joined(separator: ";")
        let comparison = settings.currentComparison.isEmpty ? "1" : settings.currentComparison
        return "\(groupText) (\(comparison))"
    }
}

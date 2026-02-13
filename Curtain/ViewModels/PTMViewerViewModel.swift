//
//  PTMViewerViewModel.swift
//  Curtain
//
//  ViewModel for PTM Viewer - manages state and data loading
//

import Foundation
import SwiftUI

@MainActor
class PTMViewerViewModel: ObservableObject {

    // MARK: - Published State

    @Published var ptmViewerState: PTMViewerState?
    @Published var selectedModTypes: Set<String> = []
    @Published var selectedCustomDatabases: Set<String> = []
    @Published var selectedVariant: String?
    @Published var customSequence: String?
    @Published var selectedSite: ExperimentalPTMSite?
    @Published var pCutoff: Double = 0.05
    @Published var fcCutoff: Double = 0.6
    @Published var error: String?
    @Published var isLoading: Bool = false

    // MARK: - Private Dependencies

    private let sequenceAlignmentService = SequenceAlignmentService.shared
    private let proteomicsDataService = ProteomicsDataService.shared

    // MARK: - Data Loading

    /// Main data loading function
    func loadData(
        linkId: String,
        accession: String,
        pCutoff: Double,
        fcCutoff: Double,
        customPTMData: [String: Any],
        variantCorrection: [String: Any],
        customSequences: [String: Any]
    ) async {
        isLoading = true
        error = nil
        self.pCutoff = pCutoff
        self.fcCutoff = fcCutoff

        do {
            // Load experimental PTM sites
            let experimentalSites = proteomicsDataService.getExperimentalPTMSites(
                linkId: linkId,
                accession: accession,
                pCutoff: pCutoff,
                fcCutoff: fcCutoff
            )
            print("[PTMViewerViewModel] Loaded \(experimentalSites.count) experimental sites for accession: \(accession)")

            // Get UniProt data
            let uniprotData = proteomicsDataService.getUniProtDataJson(
                linkId: linkId,
                accession: accession
            ) ?? [:]
            print("[PTMViewerViewModel] UniProt data keys: \(uniprotData.keys.sorted())")

            // Extract sequence
            var canonicalSequence = sequenceAlignmentService.extractSequence(uniprotData: uniprotData) ?? ""
            print("[PTMViewerViewModel] Extracted sequence length: \(canonicalSequence.count)")

            // Check for variant correction or custom sequence
            let resolvedSequence = resolveExperimentalSequence(
                variants: variantCorrection,
                custom: customSequences,
                accession: accession,
                uniprotData: uniprotData
            )

            let experimentalSequenceSource: String?
            if let resolved = resolvedSequence {
                canonicalSequence = resolved.sequence
                experimentalSequenceSource = resolved.source
            } else {
                experimentalSequenceSource = nil
            }

            // Parse UniProt features
            let uniprotFeatures = sequenceAlignmentService.parseUniProtFeatures(uniprotData: uniprotData)

            // Extract domains
            let domains = sequenceAlignmentService.extractDomains(uniprotData: uniprotData)

            // Parse modifications
            let parsedModifications = sequenceAlignmentService.parseModifications(uniprotData: uniprotData)
            let availableModTypes = sequenceAlignmentService.getAvailableModTypes(modifications: parsedModifications)

            // Create aligned peptides
            let alignedPeptides = createAlignedPeptides(
                experimentalSites: experimentalSites,
                canonicalSequence: canonicalSequence
            )

            // Perform sequence alignment - ALWAYS create alignedSequencePair
            // Use canonical sequence as experimental if no variant/custom sequence
            let alignedSequencePair: AlignedSequencePair?
            let originalCanonical = sequenceAlignmentService.extractSequence(uniprotData: uniprotData) ?? canonicalSequence

            if let expSeqSource = experimentalSequenceSource,
               !expSeqSource.isEmpty && expSeqSource != "canonical",
               let resolved = resolvedSequence {
                // Align variant/custom sequence against canonical
                let alignment = sequenceAlignmentService.alignSequences(
                    experimentalSequence: resolved.sequence,
                    canonicalSequence: originalCanonical
                )
                alignedSequencePair = alignment
                print("[PTMViewerViewModel] Aligned variant sequence, source: \(expSeqSource)")
            } else if !canonicalSequence.isEmpty {
                // Always show alignment even with canonical - use canonical as both
                let alignment = sequenceAlignmentService.alignSequences(
                    experimentalSequence: canonicalSequence,
                    canonicalSequence: canonicalSequence
                )
                alignedSequencePair = alignment
                print("[PTMViewerViewModel] Created alignment with canonical sequence, length: \(canonicalSequence.count)")
            } else {
                alignedSequencePair = nil
            }

            // Extract available isoforms
            let availableIsoforms = sequenceAlignmentService.extractAvailableIsoforms(uniprotData: uniprotData)

            // Parse custom PTM data
            let customPTMSites = parseCustomPTMData(customPTMData, accession: accession)
            let availableCustomDatabases = Array(customPTMSites.keys).sorted()

            // Extract metadata
            let geneName = sequenceAlignmentService.extractGeneName(uniprotData: uniprotData)
            let proteinName = sequenceAlignmentService.extractProteinName(uniprotData: uniprotData)
            let organism = sequenceAlignmentService.extractOrganism(uniprotData: uniprotData)

            // Create state
            let state = PTMViewerState(
                accession: accession,
                geneName: geneName,
                proteinName: proteinName,
                organism: organism,
                canonicalSequence: canonicalSequence,
                sequenceLength: canonicalSequence.count,
                experimentalSites: experimentalSites,
                uniprotFeatures: uniprotFeatures,
                alignedPeptides: alignedPeptides,
                domains: domains,
                alignedSequencePair: alignedSequencePair,
                experimentalSequenceSource: experimentalSequenceSource,
                parsedModifications: parsedModifications,
                availableModTypes: availableModTypes,
                availableIsoforms: availableIsoforms,
                selectedVariant: selectedVariant,
                customSequence: customSequence,
                customPTMSites: customPTMSites,
                availableCustomDatabases: availableCustomDatabases,
                selectedCustomDatabases: selectedCustomDatabases
            )

            self.ptmViewerState = state
            self.selectedModTypes = Set(availableModTypes)
            self.selectedCustomDatabases = Set(availableCustomDatabases)

        } catch {
            self.error = "Failed to load PTM data: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - Filter Methods

    /// Updates selected modification types
    func updateSelectedModTypes(_ modTypes: Set<String>) {
        selectedModTypes = modTypes
    }

    /// Updates selected custom databases
    func updateSelectedCustomDatabases(_ databases: Set<String>) {
        selectedCustomDatabases = databases
    }

    /// Selects a variant/isoform
    func selectVariant(_ variant: String?) {
        selectedVariant = variant
        // Trigger reload with new variant
    }

    /// Sets custom sequence
    func setCustomSequence(_ sequence: String?) {
        customSequence = sequence
        // Trigger reload with custom sequence
    }

    /// Resets to default canonical sequence
    func resetToDefault() {
        selectedVariant = nil
        customSequence = nil
    }

    // MARK: - Computed Properties

    /// Filtered experimental sites based on selected mod types
    var filteredExperimentalSites: [ExperimentalPTMSite] {
        guard let state = ptmViewerState else { return [] }

        if selectedModTypes.isEmpty {
            return state.experimentalSites
        }

        return state.experimentalSites.filter { site in
            guard let mod = site.modification else { return true }
            return selectedModTypes.contains(mod)
        }
    }

    /// Filtered custom PTM sites based on selected databases
    var filteredCustomPTMSites: [String: [CustomPTMSite]] {
        guard let state = ptmViewerState else { return [:] }

        if selectedCustomDatabases.isEmpty {
            return [:]
        }

        return state.customPTMSites.filter { selectedCustomDatabases.contains($0.key) }
    }

    /// Get PTM site comparisons
    var ptmSiteComparisons: [PTMSiteComparison] {
        guard let state = ptmViewerState else { return [] }

        return sequenceAlignmentService.comparePTMSites(
            experimentalSites: filteredExperimentalSites,
            uniprotFeatures: state.uniprotFeatures,
            canonicalSequence: state.canonicalSequence
        )
    }

    // MARK: - Private Helpers

    private func createAlignedPeptides(
        experimentalSites: [ExperimentalPTMSite],
        canonicalSequence: String
    ) -> [AlignedPeptide] {
        var peptides: [AlignedPeptide] = []

        for site in experimentalSites {
            guard let peptideSeq = site.peptideSequence else { continue }

            if let aligned = sequenceAlignmentService.createAlignedPeptide(
                primaryId: site.primaryId,
                peptideSequence: peptideSeq,
                canonicalSequence: canonicalSequence,
                isSignificant: site.isSignificant
            ) {
                peptides.append(aligned)
            }
        }

        return peptides
    }

    private func parseCustomPTMData(
        _ data: [String: Any],
        accession: String
    ) -> [String: [CustomPTMSite]] {
        var result: [String: [CustomPTMSite]] = [:]

        // Get both experimental accession and base accession (without isoform suffix)
        let experimentalAccession = getFirstAccession(accession)
        let baseAccession = getBaseAccession(accession)
        let relevantAccessions = [experimentalAccession, baseAccession].filter { !$0.isEmpty }

        for (databaseName, databaseData) in data {
            guard let accessionMap = databaseData as? [String: Any] else {
                continue
            }

            var customSites: [CustomPTMSite] = []

            // Try each relevant accession key
            for accKey in relevantAccessions {
                if let accData = accessionMap[accKey] as? [String: Any] {
                    // Nested structure: databaseName -> accessionKey -> fullAccession -> [sites]
                    for (_, siteList) in accData {
                        if let sites = siteList as? [[String: Any]] {
                            for siteData in sites {
                                // Position is 0-based in the data, convert to 1-based
                                let position: Int
                                if let pos = siteData["position"] as? Int {
                                    position = pos + 1
                                } else if let posStr = siteData["position"] as? String,
                                          let pos = Int(posStr) {
                                    position = pos + 1
                                } else {
                                    continue
                                }

                                let residue = siteData["residue"] as? String ?? ""

                                customSites.append(CustomPTMSite(
                                    databaseName: databaseName,
                                    position: position,
                                    residue: residue
                                ))
                            }
                        }
                    }
                } else if let sites = accessionMap[accKey] as? [[String: Any]] {
                    // Simpler structure: databaseName -> accession -> [sites]
                    for siteData in sites {
                        let position: Int
                        if let pos = siteData["position"] as? Int {
                            position = pos + 1
                        } else if let posStr = siteData["position"] as? String,
                                  let pos = Int(posStr) {
                            position = pos + 1
                        } else {
                            continue
                        }

                        let residue = siteData["residue"] as? String ?? ""

                        customSites.append(CustomPTMSite(
                            databaseName: databaseName,
                            position: position,
                            residue: residue
                        ))
                    }
                }
            }

            if !customSites.isEmpty {
                // Remove duplicates by position and sort
                let uniqueSites = Dictionary(grouping: customSites, by: { $0.position })
                    .values
                    .compactMap { $0.first }
                    .sorted { $0.position < $1.position }
                result[databaseName] = uniqueSites
            }
        }

        return result
    }

    /// Extracts the first accession from a semicolon-separated list
    private func getFirstAccession(_ accession: String) -> String {
        return accession.split(separator: ";").first.map(String.init)?.trimmingCharacters(in: .whitespaces) ?? accession
    }

    /// Extracts the base accession by removing isoform suffix (e.g., P12345-2 -> P12345)
    private func getBaseAccession(_ accession: String) -> String {
        let firstAccession = getFirstAccession(accession)
        // Remove isoform suffix like "-2"
        if let range = firstAccession.range(of: "-\\d+$", options: .regularExpression) {
            return String(firstAccession[..<range.lowerBound])
        }
        return firstAccession
    }

    private func resolveExperimentalSequence(
        variants: [String: Any],
        custom: [String: Any],
        accession: String,
        uniprotData: [String: Any]
    ) -> (sequence: String, source: String)? {
        // Check for custom sequence first
        if let customSeq = custom[accession] as? String, !customSeq.isEmpty {
            return (customSeq, "custom")
        }

        // Check for variant correction
        if let variantData = variants[accession] as? [String: Any] {
            if let sequence = variantData["sequence"] as? String, !sequence.isEmpty {
                let source = variantData["isoform"] as? String ?? "variant"
                return (sequence, source)
            }
        }

        // Fall back to canonical
        if let canonicalSeq = sequenceAlignmentService.extractSequence(uniprotData: uniprotData) {
            return (canonicalSeq, "canonical")
        }

        return nil
    }
}

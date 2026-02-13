//
//  PTMViewerModels.swift
//  Curtain
//
//  Models for PTM (Post-Translational Modification) visualization
//  Equivalent to Android's PTMViewerModels
//

import Foundation

// MARK: - PTMViewerState

/// Main state container for PTM viewer
struct PTMViewerState {
    let accession: String
    let geneName: String?
    let proteinName: String?
    let organism: String?
    let canonicalSequence: String
    let sequenceLength: Int
    let experimentalSites: [ExperimentalPTMSite]
    let uniprotFeatures: [UniProtFeature]
    let alignedPeptides: [AlignedPeptide]
    let domains: [ProteinDomain]
    let alignedSequencePair: AlignedSequencePair?
    let experimentalSequenceSource: String?
    let parsedModifications: [ParsedModification]
    let availableModTypes: [String]
    let availableIsoforms: [String]
    let selectedVariant: String?
    let customSequence: String?
    let customPTMSites: [String: [CustomPTMSite]]
    let availableCustomDatabases: [String]
    let selectedCustomDatabases: Set<String>

    init(
        accession: String,
        geneName: String? = nil,
        proteinName: String? = nil,
        organism: String? = nil,
        canonicalSequence: String,
        sequenceLength: Int = 0,
        experimentalSites: [ExperimentalPTMSite] = [],
        uniprotFeatures: [UniProtFeature] = [],
        alignedPeptides: [AlignedPeptide] = [],
        domains: [ProteinDomain] = [],
        alignedSequencePair: AlignedSequencePair? = nil,
        experimentalSequenceSource: String? = nil,
        parsedModifications: [ParsedModification] = [],
        availableModTypes: [String] = [],
        availableIsoforms: [String] = [],
        selectedVariant: String? = nil,
        customSequence: String? = nil,
        customPTMSites: [String: [CustomPTMSite]] = [:],
        availableCustomDatabases: [String] = [],
        selectedCustomDatabases: Set<String> = []
    ) {
        self.accession = accession
        self.geneName = geneName
        self.proteinName = proteinName
        self.organism = organism
        self.canonicalSequence = canonicalSequence
        self.sequenceLength = sequenceLength > 0 ? sequenceLength : canonicalSequence.count
        self.experimentalSites = experimentalSites
        self.uniprotFeatures = uniprotFeatures
        self.alignedPeptides = alignedPeptides
        self.domains = domains
        self.alignedSequencePair = alignedSequencePair
        self.experimentalSequenceSource = experimentalSequenceSource
        self.parsedModifications = parsedModifications
        self.availableModTypes = availableModTypes
        self.availableIsoforms = availableIsoforms
        self.selectedVariant = selectedVariant
        self.customSequence = customSequence
        self.customPTMSites = customPTMSites
        self.availableCustomDatabases = availableCustomDatabases
        self.selectedCustomDatabases = selectedCustomDatabases
    }
}

// MARK: - ExperimentalPTMSite

/// Experimental PTM site from proteomics data
struct ExperimentalPTMSite: Identifiable, Hashable {
    let id: String
    let primaryId: String
    let position: Int
    let residue: Character
    let modification: String?
    let peptideSequence: String?
    let foldChange: Double?
    let pValue: Double?
    let isSignificant: Bool
    let comparison: String?
    let score: Double?

    init(
        primaryId: String,
        position: Int,
        residue: Character,
        modification: String? = nil,
        peptideSequence: String? = nil,
        foldChange: Double? = nil,
        pValue: Double? = nil,
        isSignificant: Bool = false,
        comparison: String? = nil,
        score: Double? = nil
    ) {
        self.id = "\(primaryId)_\(position)_\(comparison ?? "default")"
        self.primaryId = primaryId
        self.position = position
        self.residue = residue
        self.modification = modification
        self.peptideSequence = peptideSequence
        self.foldChange = foldChange
        self.pValue = pValue
        self.isSignificant = isSignificant
        self.comparison = comparison
        self.score = score
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: ExperimentalPTMSite, rhs: ExperimentalPTMSite) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - CustomPTMSite

/// Custom PTM site from external databases
struct CustomPTMSite: Identifiable, Hashable {
    let id: String
    let databaseName: String
    let position: Int
    let residue: String

    init(databaseName: String, position: Int, residue: String) {
        self.id = "\(databaseName)_\(position)_\(residue)"
        self.databaseName = databaseName
        self.position = position
        self.residue = residue
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: CustomPTMSite, rhs: CustomPTMSite) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - UniProtFeature

/// UniProt feature annotation
struct UniProtFeature: Identifiable, Hashable {
    let id: String
    let type: FeatureType
    let startPosition: Int
    let endPosition: Int
    let description: String
    let evidence: String?

    init(
        type: FeatureType,
        startPosition: Int,
        endPosition: Int,
        description: String,
        evidence: String? = nil
    ) {
        self.id = "\(type.rawValue)_\(startPosition)_\(endPosition)"
        self.type = type
        self.startPosition = startPosition
        self.endPosition = endPosition
        self.description = description
        self.evidence = evidence
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: UniProtFeature, rhs: UniProtFeature) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - FeatureType

/// Types of UniProt features
enum FeatureType: String, CaseIterable {
    case modifiedResidue = "Modified residue"
    case activeSite = "Active site"
    case bindingSite = "Binding site"
    case domain = "Domain"
    case region = "Region"
    case motif = "Motif"
    case signalPeptide = "Signal peptide"
    case transmembrane = "Transmembrane"
    case disulfideBond = "Disulfide bond"
    case glycosylation = "Glycosylation"
    case lipidation = "Lipidation"
    case other = "Other"

    static func fromString(_ string: String) -> FeatureType {
        let lowercased = string.lowercased()
        if lowercased.contains("modified") || lowercased.contains("phospho") ||
           lowercased.contains("acetyl") || lowercased.contains("methyl") ||
           lowercased.contains("ubiquit") {
            return .modifiedResidue
        } else if lowercased.contains("active") {
            return .activeSite
        } else if lowercased.contains("binding") {
            return .bindingSite
        } else if lowercased.contains("domain") {
            return .domain
        } else if lowercased.contains("region") {
            return .region
        } else if lowercased.contains("motif") {
            return .motif
        } else if lowercased.contains("signal") {
            return .signalPeptide
        } else if lowercased.contains("transmembrane") || lowercased.contains("helix") {
            return .transmembrane
        } else if lowercased.contains("disulfide") {
            return .disulfideBond
        } else if lowercased.contains("glyco") {
            return .glycosylation
        } else if lowercased.contains("lipid") {
            return .lipidation
        }
        return .other
    }
}

// MARK: - ProteinDomain

/// Protein domain information
struct ProteinDomain: Identifiable, Hashable {
    let id: String
    let name: String
    let startPosition: Int
    let endPosition: Int
    let description: String?

    init(
        name: String,
        startPosition: Int,
        endPosition: Int,
        description: String? = nil
    ) {
        self.id = "\(name)_\(startPosition)_\(endPosition)"
        self.name = name
        self.startPosition = startPosition
        self.endPosition = endPosition
        self.description = description
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: ProteinDomain, rhs: ProteinDomain) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - AlignedPeptide

/// Aligned peptide with PTM positions
struct AlignedPeptide: Identifiable, Hashable {
    let id: String
    let peptideSequence: String
    let startPosition: Int
    let endPosition: Int
    let ptmPositions: [PTMPosition]
    let primaryId: String
    let isSignificant: Bool

    init(
        peptideSequence: String,
        startPosition: Int,
        endPosition: Int,
        ptmPositions: [PTMPosition] = [],
        primaryId: String,
        isSignificant: Bool = false
    ) {
        self.id = "\(primaryId)_\(startPosition)_\(endPosition)"
        self.peptideSequence = peptideSequence
        self.startPosition = startPosition
        self.endPosition = endPosition
        self.ptmPositions = ptmPositions
        self.primaryId = primaryId
        self.isSignificant = isSignificant
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: AlignedPeptide, rhs: AlignedPeptide) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - PTMPosition

/// PTM position within a peptide
struct PTMPosition: Hashable {
    let positionInPeptide: Int
    let positionInProtein: Int
    let residue: Character
    let modification: String?

    init(
        positionInPeptide: Int,
        positionInProtein: Int,
        residue: Character,
        modification: String? = nil
    ) {
        self.positionInPeptide = positionInPeptide
        self.positionInProtein = positionInProtein
        self.residue = residue
        self.modification = modification
    }
}

// MARK: - AlignedSequencePair

/// Sequence alignment result
struct AlignedSequencePair {
    let experimentalSequence: String
    let canonicalSequence: String
    let experimentalAligned: String
    let canonicalAligned: String
    let experimentalPositionMap: [Int: Int]  // original -> aligned
    let canonicalPositionMap: [Int: Int]      // original -> aligned

    init(
        experimentalSequence: String,
        canonicalSequence: String,
        experimentalAligned: String,
        canonicalAligned: String,
        experimentalPositionMap: [Int: Int] = [:],
        canonicalPositionMap: [Int: Int] = [:]
    ) {
        self.experimentalSequence = experimentalSequence
        self.canonicalSequence = canonicalSequence
        self.experimentalAligned = experimentalAligned
        self.canonicalAligned = canonicalAligned
        self.experimentalPositionMap = experimentalPositionMap
        self.canonicalPositionMap = canonicalPositionMap
    }
}

// MARK: - ParsedModification

/// Parsed modification from UniProt
struct ParsedModification: Identifiable, Hashable {
    let id: String
    let position: Int
    let residue: Character
    let modType: String

    init(position: Int, residue: Character, modType: String) {
        self.id = "\(position)_\(residue)_\(modType)"
        self.position = position
        self.residue = residue
        self.modType = modType
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: ParsedModification, rhs: ParsedModification) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - PTMSiteComparison

/// PTM site comparison between experimental and UniProt
struct PTMSiteComparison: Identifiable, Hashable {
    let id: String
    let position: Int
    let residue: Character
    let isExperimental: Bool
    let isKnownUniprot: Bool
    let experimentalData: ExperimentalPTMSite?
    let uniprotFeature: UniProtFeature?

    var comparisonType: PTMComparisonType {
        switch (isExperimental, isKnownUniprot) {
        case (true, true): return .matched
        case (true, false): return .novel
        case (false, true): return .knownOnly
        default: return .none
        }
    }

    init(
        position: Int,
        residue: Character,
        isExperimental: Bool,
        isKnownUniprot: Bool,
        experimentalData: ExperimentalPTMSite? = nil,
        uniprotFeature: UniProtFeature? = nil
    ) {
        self.id = "\(position)_\(residue)_\(isExperimental)_\(isKnownUniprot)"
        self.position = position
        self.residue = residue
        self.isExperimental = isExperimental
        self.isKnownUniprot = isKnownUniprot
        self.experimentalData = experimentalData
        self.uniprotFeature = uniprotFeature
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: PTMSiteComparison, rhs: PTMSiteComparison) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - PTMComparisonType

/// Types of PTM site comparison
enum PTMComparisonType {
    case matched      // Both experimental and UniProt
    case novel        // Experimental only
    case knownOnly    // UniProt only
    case none

    var displayName: String {
        switch self {
        case .matched: return "Confirmed"
        case .novel: return "Novel"
        case .knownOnly: return "Known (UniProt)"
        case .none: return "Unknown"
        }
    }

    var colorHex: String {
        switch self {
        case .matched: return "#4CAF50"   // Green
        case .novel: return "#FF5722"      // Orange
        case .knownOnly: return "#2196F3"  // Blue
        case .none: return "#9E9E9E"       // Gray
        }
    }
}

// MARK: - AlignmentColors

/// Color definitions for alignment visualization
struct AlignmentColors {
    static let match = "#4CAF50"           // Green
    static let mismatch = "#F44336"        // Red
    static let gap = "#9E9E9E"             // Gray
    static let experimentalPTM = "#FF5722" // Orange
    static let uniprotPTM = "#2196F3"      // Blue
    static let customPTM = "#9C27B0"       // Purple
    static let background = "#FFFFFF"      // White
    static let text = "#212121"            // Dark gray
}

// MARK: - PTMDataRow

/// Row data for PTM data table display
struct PTMDataRow: Identifiable {
    let id: String
    let accession: String
    let position: String
    let peptideSequence: String
    let foldChange: Double?
    let pValue: Double?
    let score: Double?
    let comparison: String?
    let isSignificant: Bool

    init(
        accession: String,
        position: String,
        peptideSequence: String,
        foldChange: Double? = nil,
        pValue: Double? = nil,
        score: Double? = nil,
        comparison: String? = nil,
        isSignificant: Bool = false
    ) {
        self.id = "\(accession)_\(position)_\(comparison ?? "default")"
        self.accession = accession
        self.position = position
        self.peptideSequence = peptideSequence
        self.foldChange = foldChange
        self.pValue = pValue
        self.score = score
        self.comparison = comparison
        self.isSignificant = isSignificant
    }
}

//
//  SequenceAlignmentServiceTests.swift
//  CurtainTests
//
//  Unit tests for SequenceAlignmentService
//

import XCTest
@testable import Curtain

final class SequenceAlignmentServiceTests: XCTestCase {

    var service: SequenceAlignmentService!

    override func setUp() {
        super.setUp()
        service = SequenceAlignmentService.shared
    }

    // MARK: - Smith-Waterman Alignment Tests

    func testAlignSequencesIdentical() {
        let sequence = "MKLPVRGSS"
        let result = service.alignSequences(
            experimentalSequence: sequence,
            canonicalSequence: sequence
        )

        XCTAssertEqual(result.experimentalSequence, sequence)
        XCTAssertEqual(result.canonicalSequence, sequence)
        // Aligned sequences should be identical for identical input
        XCTAssertEqual(result.experimentalAligned, result.canonicalAligned)
    }

    func testAlignSequencesWithMismatch() {
        let exp = "MKLPVRGSS"
        let can = "MKLPARGSS"  // V -> A mismatch

        let result = service.alignSequences(
            experimentalSequence: exp,
            canonicalSequence: can
        )

        XCTAssertFalse(result.experimentalAligned.isEmpty)
        XCTAssertFalse(result.canonicalAligned.isEmpty)
        XCTAssertEqual(result.experimentalAligned.count, result.canonicalAligned.count)
    }

    func testAlignSequencesWithGap() {
        let exp = "MKLPVRGSS"
        let can = "MKLPVRXGSS"  // X insertion

        let result = service.alignSequences(
            experimentalSequence: exp,
            canonicalSequence: can
        )

        XCTAssertFalse(result.experimentalAligned.isEmpty)
        XCTAssertFalse(result.canonicalAligned.isEmpty)
    }

    // MARK: - Peptide Alignment Tests

    func testAlignPeptideToSequenceExactMatch() {
        let peptide = "TESTPEP"
        let sequence = "MKLPVRGSSTESTPEPTIDE"

        let result = service.alignPeptideToSequence(
            peptideSequence: peptide,
            canonicalSequence: sequence
        )

        XCTAssertNotNil(result)
        // TESTPEP starts at position 10 (1-indexed) in MKLPVRGSSTESTPEPTIDE
        XCTAssertEqual(result?.start, 10)
        XCTAssertEqual(result?.end, 16)
    }

    func testAlignPeptideToSequenceNoMatch() {
        let peptide = "ZZZZZ"
        let sequence = "MKLPVRGSSTESTPEPTIDE"

        let result = service.alignPeptideToSequence(
            peptideSequence: peptide,
            canonicalSequence: sequence
        )

        XCTAssertNil(result)
    }

    func testAlignPeptideWithModifications() {
        let peptide = "TEST[Phospho]PEP"
        let sequence = "MKLPVRGSSTESTPEPTIDE"

        let result = service.alignPeptideToSequence(
            peptideSequence: peptide,
            canonicalSequence: sequence
        )

        XCTAssertNotNil(result)
        // Should match after removing modification notation
        // TESTPEP starts at position 10 (1-indexed)
        XCTAssertEqual(result?.start, 10)
    }

    // MARK: - Clean Peptide Sequence Tests

    func testCleanPeptideSequenceWithBrackets() {
        let peptide = "TESTS[Phospho]PEP"
        let cleaned = service.cleanPeptideSequence(peptide)

        XCTAssertEqual(cleaned, "TESTSPEP")
    }

    func testCleanPeptideSequenceWithParentheses() {
        let peptide = "TEST(ph)SPEP"
        let cleaned = service.cleanPeptideSequence(peptide)

        XCTAssertEqual(cleaned, "TESTSPEP")
    }

    func testCleanPeptideSequenceWithMultipleModifications() {
        let peptide = "M[Ox]TESTS[Phospho]PEP[Label]"
        let cleaned = service.cleanPeptideSequence(peptide)

        XCTAssertEqual(cleaned, "MTESTSPEP")
    }

    func testCleanPeptideSequenceAlreadyClean() {
        let peptide = "TESTSPEP"
        let cleaned = service.cleanPeptideSequence(peptide)

        XCTAssertEqual(cleaned, "TESTSPEP")
    }

    // MARK: - PTM Position Extraction Tests

    func testExtractPTMPositionFromPeptide() {
        let peptide = "RLS[Phospho]SK"
        let startPosition = 10

        let positions = service.extractPTMPositionFromPeptide(
            peptideSequence: peptide,
            startPosition: startPosition
        )

        XCTAssertEqual(positions.count, 1)
        XCTAssertEqual(positions[0].positionInPeptide, 3)
        XCTAssertEqual(positions[0].positionInProtein, 12)
        XCTAssertEqual(positions[0].residue, "S")
        XCTAssertEqual(positions[0].modification, "Phospho")
    }

    func testExtractPTMPositionMultipleModifications() {
        let peptide = "RS[Phospho]T[Phospho]K"
        let startPosition = 1

        let positions = service.extractPTMPositionFromPeptide(
            peptideSequence: peptide,
            startPosition: startPosition
        )

        XCTAssertEqual(positions.count, 2)
        XCTAssertEqual(positions[0].positionInProtein, 2)
        XCTAssertEqual(positions[1].positionInProtein, 3)
    }

    func testExtractPTMPositionNoModifications() {
        let peptide = "RLSSK"
        let startPosition = 10

        let positions = service.extractPTMPositionFromPeptide(
            peptideSequence: peptide,
            startPosition: startPosition
        )

        XCTAssertEqual(positions.count, 0)
    }

    // MARK: - UniProt Feature Parsing Tests

    func testParseUniProtFeaturesFromNewFormat() {
        let uniprotData: [String: Any] = [
            "features": [
                [
                    "type": "Modified residue",
                    "location": [
                        "start": ["value": 15],
                        "end": ["value": 15]
                    ],
                    "description": "Phosphoserine"
                ]
            ]
        ]

        let features = service.parseUniProtFeatures(uniprotData: uniprotData)

        XCTAssertEqual(features.count, 1)
        XCTAssertEqual(features[0].type, .modifiedResidue)
        XCTAssertEqual(features[0].startPosition, 15)
        XCTAssertEqual(features[0].endPosition, 15)
        XCTAssertEqual(features[0].description, "Phosphoserine")
    }

    func testParseUniProtFeaturesEmpty() {
        let uniprotData: [String: Any] = [:]

        let features = service.parseUniProtFeatures(uniprotData: uniprotData)

        XCTAssertEqual(features.count, 0)
    }

    // MARK: - Domain Extraction Tests

    func testExtractDomains() {
        let uniprotData: [String: Any] = [
            "features": [
                [
                    "type": "Domain",
                    "location": [
                        "start": ["value": 100],
                        "end": ["value": 200]
                    ],
                    "description": "DNA-binding"
                ],
                [
                    "type": "Domain",
                    "location": [
                        "start": ["value": 300],
                        "end": ["value": 350]
                    ],
                    "description": "Transactivation"
                ]
            ]
        ]

        let domains = service.extractDomains(uniprotData: uniprotData)

        XCTAssertEqual(domains.count, 2)
        XCTAssertEqual(domains[0].name, "DNA-binding")
        XCTAssertEqual(domains[0].startPosition, 100)
        XCTAssertEqual(domains[0].endPosition, 200)
    }

    // MARK: - Modification Parsing Tests

    func testGetAvailableModTypes() {
        let modifications = [
            ParsedModification(position: 15, residue: "S", modType: "Phosphorylation"),
            ParsedModification(position: 20, residue: "K", modType: "Acetylation"),
            ParsedModification(position: 25, residue: "S", modType: "Phosphorylation")
        ]

        let modTypes = service.getAvailableModTypes(modifications: modifications)

        XCTAssertEqual(modTypes.count, 2)
        XCTAssertTrue(modTypes.contains("Phosphorylation"))
        XCTAssertTrue(modTypes.contains("Acetylation"))
    }

    // MARK: - PTM Site Comparison Tests

    func testComparePTMSites() {
        let experimentalSites = [
            ExperimentalPTMSite(primaryId: "P1_S15", position: 15, residue: "S", isSignificant: true),
            ExperimentalPTMSite(primaryId: "P1_S20", position: 20, residue: "S", isSignificant: true)
        ]

        let uniprotFeatures = [
            UniProtFeature(type: .modifiedResidue, startPosition: 15, endPosition: 15, description: "Phosphoserine"),
            UniProtFeature(type: .modifiedResidue, startPosition: 25, endPosition: 25, description: "Phosphoserine")
        ]

        let comparisons = service.comparePTMSites(
            experimentalSites: experimentalSites,
            uniprotFeatures: uniprotFeatures,
            canonicalSequence: "MKLPVRGSSTESTSEQUENCEWITHSOMEMORERESIDUESMKLPVRGSS"
        )

        // Should have 3 entries: position 15 (matched), 20 (novel), 25 (known only)
        XCTAssertGreaterThanOrEqual(comparisons.count, 3)

        // Find matched site (position 15)
        let matchedSite = comparisons.first { $0.position == 15 }
        XCTAssertNotNil(matchedSite)
        XCTAssertEqual(matchedSite?.comparisonType, .matched)

        // Find novel site (position 20)
        let novelSite = comparisons.first { $0.position == 20 }
        XCTAssertNotNil(novelSite)
        XCTAssertEqual(novelSite?.comparisonType, .novel)

        // Find known-only site (position 25)
        let knownOnlySite = comparisons.first { $0.position == 25 }
        XCTAssertNotNil(knownOnlySite)
        XCTAssertEqual(knownOnlySite?.comparisonType, .knownOnly)
    }

    // MARK: - Aligned Peptide Creation Tests

    func testCreateAlignedPeptide() {
        let result = service.createAlignedPeptide(
            primaryId: "P12345",
            peptideSequence: "TESTPEP",
            canonicalSequence: "MKLPVRGSSTESTPEPTIDE",
            isSignificant: true
        )

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.primaryId, "P12345")
        XCTAssertEqual(result?.peptideSequence, "TESTPEP")
        // TESTPEP starts at position 10 (1-indexed) and ends at position 16
        XCTAssertEqual(result?.startPosition, 10)
        XCTAssertEqual(result?.endPosition, 16)
        XCTAssertTrue(result?.isSignificant ?? false)
    }

    func testCreateAlignedPeptideNoMatch() {
        let result = service.createAlignedPeptide(
            primaryId: "P12345",
            peptideSequence: "ZZZZZ",
            canonicalSequence: "MKLPVRGSSTESTPEPTIDE",
            isSignificant: true
        )

        XCTAssertNil(result)
    }

    // MARK: - UniProt Data Extraction Tests

    func testExtractSequence() {
        let uniprotData: [String: Any] = [
            "sequence": ["value": "MKLPVRGSS"]
        ]

        let sequence = service.extractSequence(uniprotData: uniprotData)

        XCTAssertEqual(sequence, "MKLPVRGSS")
    }

    func testExtractSequenceStringFormat() {
        let uniprotData: [String: Any] = [
            "sequence": "MKLPVRGSS"
        ]

        let sequence = service.extractSequence(uniprotData: uniprotData)

        XCTAssertEqual(sequence, "MKLPVRGSS")
    }

    func testExtractGeneName() {
        let uniprotData: [String: Any] = [
            "genes": [
                ["geneName": ["value": "TP53"]]
            ]
        ]

        let geneName = service.extractGeneName(uniprotData: uniprotData)

        XCTAssertEqual(geneName, "TP53")
    }

    func testExtractProteinName() {
        let uniprotData: [String: Any] = [
            "proteinDescription": [
                "recommendedName": [
                    "fullName": ["value": "Cellular tumor antigen p53"]
                ]
            ]
        ]

        let proteinName = service.extractProteinName(uniprotData: uniprotData)

        XCTAssertEqual(proteinName, "Cellular tumor antigen p53")
    }

    func testExtractOrganism() {
        let uniprotData: [String: Any] = [
            "organism": ["scientificName": "Homo sapiens"]
        ]

        let organism = service.extractOrganism(uniprotData: uniprotData)

        XCTAssertEqual(organism, "Homo sapiens")
    }

    func testExtractAvailableIsoforms() {
        let uniprotData: [String: Any] = [
            "comments": [
                [
                    "type": "ALTERNATIVE PRODUCTS",
                    "isoforms": [
                        ["ids": ["P12345-1", "P12345-2"]],
                        ["id": "P12345-3"]
                    ]
                ]
            ]
        ]

        let isoforms = service.extractAvailableIsoforms(uniprotData: uniprotData)

        XCTAssertEqual(isoforms.count, 3)
        XCTAssertTrue(isoforms.contains("P12345-1"))
        XCTAssertTrue(isoforms.contains("P12345-2"))
        XCTAssertTrue(isoforms.contains("P12345-3"))
    }
}

//
//  PTMViewerModelsTests.swift
//  CurtainTests
//
//  Unit tests for PTM data models
//

import XCTest
@testable import Curtain

final class PTMViewerModelsTests: XCTestCase {

    // MARK: - ExperimentalPTMSite Tests

    func testExperimentalPTMSiteCreation() {
        let site = ExperimentalPTMSite(
            primaryId: "P12345_S15",
            position: 15,
            residue: "S",
            modification: "Phosphorylation",
            peptideSequence: "RLSSK",
            foldChange: 2.5,
            pValue: 0.001,
            isSignificant: true,
            comparison: "Treatment vs Control",
            score: 0.95
        )

        XCTAssertEqual(site.primaryId, "P12345_S15")
        XCTAssertEqual(site.position, 15)
        XCTAssertEqual(site.residue, "S")
        XCTAssertEqual(site.modification, "Phosphorylation")
        XCTAssertEqual(site.peptideSequence, "RLSSK")
        XCTAssertEqual(site.foldChange, 2.5)
        XCTAssertEqual(site.pValue, 0.001)
        XCTAssertTrue(site.isSignificant)
        XCTAssertEqual(site.comparison, "Treatment vs Control")
        XCTAssertEqual(site.score, 0.95)
    }

    func testExperimentalPTMSiteEquality() {
        let site1 = ExperimentalPTMSite(primaryId: "P12345_S15", position: 15, residue: "S", comparison: "A")
        let site2 = ExperimentalPTMSite(primaryId: "P12345_S15", position: 15, residue: "S", comparison: "A")
        let site3 = ExperimentalPTMSite(primaryId: "P12345_S15", position: 15, residue: "S", comparison: "B")

        XCTAssertEqual(site1, site2)
        XCTAssertNotEqual(site1, site3)
    }

    // MARK: - CustomPTMSite Tests

    func testCustomPTMSiteCreation() {
        let site = CustomPTMSite(databaseName: "PhosphoSitePlus", position: 15, residue: "S")

        XCTAssertEqual(site.databaseName, "PhosphoSitePlus")
        XCTAssertEqual(site.position, 15)
        XCTAssertEqual(site.residue, "S")
    }

    // MARK: - UniProtFeature Tests

    func testUniProtFeatureCreation() {
        let feature = UniProtFeature(
            type: .modifiedResidue,
            startPosition: 15,
            endPosition: 15,
            description: "Phosphoserine",
            evidence: "ECO:0000269"
        )

        XCTAssertEqual(feature.type, .modifiedResidue)
        XCTAssertEqual(feature.startPosition, 15)
        XCTAssertEqual(feature.endPosition, 15)
        XCTAssertEqual(feature.description, "Phosphoserine")
        XCTAssertEqual(feature.evidence, "ECO:0000269")
    }

    // MARK: - FeatureType Tests

    func testFeatureTypeFromString() {
        XCTAssertEqual(FeatureType.fromString("Modified residue"), .modifiedResidue)
        XCTAssertEqual(FeatureType.fromString("Phosphorylation"), .modifiedResidue)
        XCTAssertEqual(FeatureType.fromString("Active site"), .activeSite)
        XCTAssertEqual(FeatureType.fromString("Binding site"), .bindingSite)
        XCTAssertEqual(FeatureType.fromString("Domain"), .domain)
        XCTAssertEqual(FeatureType.fromString("Region"), .region)
        XCTAssertEqual(FeatureType.fromString("Motif"), .motif)
        XCTAssertEqual(FeatureType.fromString("Signal peptide"), .signalPeptide)
        XCTAssertEqual(FeatureType.fromString("Transmembrane"), .transmembrane)
        XCTAssertEqual(FeatureType.fromString("Disulfide bond"), .disulfideBond)
        XCTAssertEqual(FeatureType.fromString("Glycosylation"), .glycosylation)
        XCTAssertEqual(FeatureType.fromString("Unknown type"), .other)
    }

    // MARK: - ProteinDomain Tests

    func testProteinDomainCreation() {
        let domain = ProteinDomain(
            name: "DNA-binding",
            startPosition: 100,
            endPosition: 200,
            description: "DNA-binding domain"
        )

        XCTAssertEqual(domain.name, "DNA-binding")
        XCTAssertEqual(domain.startPosition, 100)
        XCTAssertEqual(domain.endPosition, 200)
        XCTAssertEqual(domain.description, "DNA-binding domain")
    }

    // MARK: - AlignedPeptide Tests

    func testAlignedPeptideCreation() {
        let ptmPositions = [
            PTMPosition(positionInPeptide: 3, positionInProtein: 15, residue: "S", modification: "Phospho")
        ]

        let peptide = AlignedPeptide(
            peptideSequence: "RLSSK",
            startPosition: 13,
            endPosition: 17,
            ptmPositions: ptmPositions,
            primaryId: "P12345",
            isSignificant: true
        )

        XCTAssertEqual(peptide.peptideSequence, "RLSSK")
        XCTAssertEqual(peptide.startPosition, 13)
        XCTAssertEqual(peptide.endPosition, 17)
        XCTAssertEqual(peptide.ptmPositions.count, 1)
        XCTAssertEqual(peptide.primaryId, "P12345")
        XCTAssertTrue(peptide.isSignificant)
    }

    // MARK: - PTMPosition Tests

    func testPTMPositionCreation() {
        let position = PTMPosition(
            positionInPeptide: 3,
            positionInProtein: 15,
            residue: "S",
            modification: "Phosphorylation"
        )

        XCTAssertEqual(position.positionInPeptide, 3)
        XCTAssertEqual(position.positionInProtein, 15)
        XCTAssertEqual(position.residue, "S")
        XCTAssertEqual(position.modification, "Phosphorylation")
    }

    // MARK: - PTMSiteComparison Tests

    func testPTMSiteComparisonTypes() {
        // Matched - both experimental and UniProt
        let matched = PTMSiteComparison(
            position: 15,
            residue: "S",
            isExperimental: true,
            isKnownUniprot: true
        )
        XCTAssertEqual(matched.comparisonType, .matched)

        // Novel - experimental only
        let novel = PTMSiteComparison(
            position: 20,
            residue: "T",
            isExperimental: true,
            isKnownUniprot: false
        )
        XCTAssertEqual(novel.comparisonType, .novel)

        // Known only - UniProt only
        let knownOnly = PTMSiteComparison(
            position: 25,
            residue: "Y",
            isExperimental: false,
            isKnownUniprot: true
        )
        XCTAssertEqual(knownOnly.comparisonType, .knownOnly)

        // None
        let none = PTMSiteComparison(
            position: 30,
            residue: "K",
            isExperimental: false,
            isKnownUniprot: false
        )
        XCTAssertEqual(none.comparisonType, .none)
    }

    // MARK: - PTMComparisonType Tests

    func testPTMComparisonTypeDisplayName() {
        XCTAssertEqual(PTMComparisonType.matched.displayName, "Confirmed")
        XCTAssertEqual(PTMComparisonType.novel.displayName, "Novel")
        XCTAssertEqual(PTMComparisonType.knownOnly.displayName, "Known (UniProt)")
        XCTAssertEqual(PTMComparisonType.none.displayName, "Unknown")
    }

    func testPTMComparisonTypeColorHex() {
        XCTAssertEqual(PTMComparisonType.matched.colorHex, "#4CAF50")
        XCTAssertEqual(PTMComparisonType.novel.colorHex, "#FF5722")
        XCTAssertEqual(PTMComparisonType.knownOnly.colorHex, "#2196F3")
        XCTAssertEqual(PTMComparisonType.none.colorHex, "#9E9E9E")
    }

    // MARK: - PTMViewerState Tests

    func testPTMViewerStateCreation() {
        let state = PTMViewerState(
            accession: "P12345",
            geneName: "TP53",
            proteinName: "Cellular tumor antigen p53",
            organism: "Homo sapiens",
            canonicalSequence: "MEEPQSDPSVEPPLSQETFSDLWKLLPENNVLSPLPSQAMDDLMLSPDDIEQWFTEDPGP"
        )

        XCTAssertEqual(state.accession, "P12345")
        XCTAssertEqual(state.geneName, "TP53")
        XCTAssertEqual(state.proteinName, "Cellular tumor antigen p53")
        XCTAssertEqual(state.organism, "Homo sapiens")
        XCTAssertEqual(state.sequenceLength, 60)
    }

    func testPTMViewerStateSequenceLengthCalculation() {
        let state = PTMViewerState(
            accession: "P12345",
            canonicalSequence: "ABCDEFGHIJ"
        )

        XCTAssertEqual(state.sequenceLength, 10)
    }

    // MARK: - AlignmentColors Tests

    func testAlignmentColorsValues() {
        XCTAssertEqual(AlignmentColors.match, "#4CAF50")
        XCTAssertEqual(AlignmentColors.mismatch, "#F44336")
        XCTAssertEqual(AlignmentColors.gap, "#9E9E9E")
        XCTAssertEqual(AlignmentColors.experimentalPTM, "#FF5722")
        XCTAssertEqual(AlignmentColors.uniprotPTM, "#2196F3")
        XCTAssertEqual(AlignmentColors.customPTM, "#9C27B0")
    }

    // MARK: - CurtainDifferentialForm PTM Detection Tests

    func testCurtainDifferentialFormIsPTM() {
        // With accession field
        let ptmForm1 = CurtainDifferentialForm(
            primaryIDs: "ID",
            accession: "Accession"
        )
        XCTAssertTrue(ptmForm1.isPTM)

        // With position field
        let ptmForm2 = CurtainDifferentialForm(
            primaryIDs: "ID",
            position: "Position"
        )
        XCTAssertTrue(ptmForm2.isPTM)

        // Without PTM fields
        let nonPTMForm = CurtainDifferentialForm(
            primaryIDs: "ID"
        )
        XCTAssertFalse(nonPTMForm.isPTM)
    }
}

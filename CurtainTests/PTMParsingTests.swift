//
//  PTMParsingTests.swift
//  CurtainTests
//
//  Tests for PTM (Post-Translational Modification) data parsing
//

import XCTest
@testable import Curtain

final class PTMParsingTests: XCTestCase {

    // MARK: - Test PTM Detection from DifferentialForm

    func testPTMDetectionWithAccessionAndPosition() {
        // Given: a differentialForm with accession and position fields
        let differentialForm = CurtainDifferentialForm(
            primaryIDs: "Index",
            geneNames: "",
            foldChange: "Welch's T-test Difference AO_UT",
            transformFC: false,
            significant: "-Log Welch's T-test p-value AO_UT",
            transformSignificant: false,
            comparison: "CurtainSetComparison",
            comparisonSelect: ["1"],
            reverseFoldChange: false,
            accession: "ProteinID",
            position: "Position",
            positionPeptide: "Position.in.peptide",
            peptideSequence: "Peptide",
            score: "MaxPepProb"
        )

        // Then: isPTM should return true
        XCTAssertTrue(differentialForm.isPTM, "differentialForm with accession and position should be detected as PTM")
        XCTAssertEqual(differentialForm.accession, "ProteinID")
        XCTAssertEqual(differentialForm.position, "Position")
    }

    func testPTMDetectionWithOnlyAccession() {
        // Given: a differentialForm with only accession field
        let differentialForm = CurtainDifferentialForm(
            accession: "ProteinID"
        )

        // Then: isPTM should return true
        XCTAssertTrue(differentialForm.isPTM, "differentialForm with only accession should be detected as PTM")
    }

    func testPTMDetectionWithOnlyPosition() {
        // Given: a differentialForm with only position field
        let differentialForm = CurtainDifferentialForm(
            position: "Position"
        )

        // Then: isPTM should return true
        XCTAssertTrue(differentialForm.isPTM, "differentialForm with only position should be detected as PTM")
    }

    func testNonPTMDetection() {
        // Given: a differentialForm without accession or position
        let differentialForm = CurtainDifferentialForm(
            primaryIDs: "ProteinID",
            geneNames: "GeneName",
            foldChange: "log2FC",
            significant: "pValue"
        )

        // Then: isPTM should return false
        XCTAssertFalse(differentialForm.isPTM, "differentialForm without accession and position should NOT be detected as PTM")
    }

    func testEmptyDifferentialFormIsNotPTM() {
        // Given: an empty differentialForm
        let differentialForm = CurtainDifferentialForm()

        // Then: isPTM should return false
        XCTAssertFalse(differentialForm.isPTM, "empty differentialForm should NOT be detected as PTM")
    }

    // MARK: - Test JSON Parsing

    func testPTMDifferentialFormDecodingFromJSON() throws {
        // Given: JSON data matching PTM fixture format
        let json = """
        {
            "primaryIDs": "Index",
            "geneNames": "",
            "foldChange": "Welch's T-test Difference AO_UT",
            "transformFC": false,
            "significant": "-Log Welch's T-test p-value AO_UT",
            "transformSignificant": false,
            "comparison": "CurtainSetComparison",
            "comparisonSelect": ["1"],
            "reverseFoldChange": false,
            "accession": "ProteinID",
            "position": "Position",
            "positionPeptide": "Position.in.peptide",
            "peptideSequence": "Peptide",
            "score": "MaxPepProb"
        }
        """
        let data = json.data(using: .utf8)!

        // When: decoding the JSON
        let differentialForm = try JSONDecoder().decode(CurtainDifferentialForm.self, from: data)

        // Then: PTM fields should be correctly parsed
        XCTAssertTrue(differentialForm.isPTM)
        XCTAssertEqual(differentialForm.accession, "ProteinID")
        XCTAssertEqual(differentialForm.position, "Position")
        XCTAssertEqual(differentialForm.positionPeptide, "Position.in.peptide")
        XCTAssertEqual(differentialForm.peptideSequence, "Peptide")
        XCTAssertEqual(differentialForm.score, "MaxPepProb")
    }

    func testNonPTMDifferentialFormDecodingFromJSON() throws {
        // Given: JSON data without PTM fields
        let json = """
        {
            "primaryIDs": "ProteinID",
            "geneNames": "GeneName",
            "foldChange": "log2FC",
            "transformFC": true,
            "significant": "pValue",
            "transformSignificant": true,
            "comparison": "",
            "comparisonSelect": [],
            "reverseFoldChange": false
        }
        """
        let data = json.data(using: .utf8)!

        // When: decoding the JSON (PTM fields should default to empty)
        let differentialForm = try JSONDecoder().decode(CurtainDifferentialForm.self, from: data)

        // Then: isPTM should be false
        XCTAssertFalse(differentialForm.isPTM)
        XCTAssertEqual(differentialForm.accession, "")
        XCTAssertEqual(differentialForm.position, "")
    }

    func testBackwardsCompatibilityDecodingWithoutPTMFields() throws {
        // Given: JSON data from old format without PTM fields at all
        let json = """
        {
            "primaryIDs": "ProteinID",
            "geneNames": "GeneName",
            "foldChange": "log2FC",
            "transformFC": false,
            "significant": "pValue",
            "transformSignificant": false,
            "comparison": "",
            "comparisonSelect": [],
            "reverseFoldChange": false
        }
        """
        let data = json.data(using: .utf8)!

        // When: decoding the JSON
        let differentialForm = try JSONDecoder().decode(CurtainDifferentialForm.self, from: data)

        // Then: should decode successfully with empty PTM fields
        XCTAssertFalse(differentialForm.isPTM)
        XCTAssertEqual(differentialForm.accession, "")
        XCTAssertEqual(differentialForm.position, "")
        XCTAssertEqual(differentialForm.positionPeptide, "")
        XCTAssertEqual(differentialForm.peptideSequence, "")
        XCTAssertEqual(differentialForm.score, "")
    }

    // MARK: - Test CurtainSettingsEntity Serialization

    func testPTMFieldsPreservedThroughEntitySerialization() throws {
        // Given: a differentialForm with PTM fields
        let originalForm = CurtainDifferentialForm(
            primaryIDs: "Index",
            geneNames: "",
            foldChange: "FC",
            transformFC: false,
            significant: "pValue",
            transformSignificant: false,
            comparison: "",
            comparisonSelect: [],
            reverseFoldChange: false,
            accession: "ProteinID",
            position: "Position",
            positionPeptide: "PosInPeptide",
            peptideSequence: "Peptide",
            score: "Score"
        )

        // When: encoding and decoding through JSON (simulating SwiftData storage)
        let encoded = try JSONEncoder().encode(originalForm)
        let decoded = try JSONDecoder().decode(CurtainDifferentialForm.self, from: encoded)

        // Then: PTM fields should be preserved
        XCTAssertTrue(decoded.isPTM)
        XCTAssertEqual(decoded.accession, "ProteinID")
        XCTAssertEqual(decoded.position, "Position")
        XCTAssertEqual(decoded.positionPeptide, "PosInPeptide")
        XCTAssertEqual(decoded.peptideSequence, "Peptide")
        XCTAssertEqual(decoded.score, "Score")
    }
}

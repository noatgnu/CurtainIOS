//
//  DataLoadingTests.swift
//  CurtainTests
//
//  Tests to ensure data is loaded correctly from SQLite
//

import XCTest
@testable import Curtain

final class DataLoadingTests: XCTestCase {

    // MARK: - UniProt DB Entry Tests

    func testUniProtDBEntryCreation() {
        let entry = UniProtDBEntry(
            accession: "P12345",
            dataJson: "{\"Gene Names\": \"BRCA1\", \"Protein names\": \"Test protein\"}"
        )

        XCTAssertEqual(entry.accession, "P12345")
        XCTAssertTrue(entry.dataJson.contains("BRCA1"))
    }

    func testUniProtDBEntryJsonParsing() {
        let jsonString = """
        {"Gene Names": "TP53 P53", "Protein names": "Cellular tumor antigen p53", "Length": "393"}
        """
        let entry = UniProtDBEntry(accession: "P04637", dataJson: jsonString)

        // Verify JSON can be parsed back
        if let data = entry.dataJson.data(using: .utf8),
           let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            XCTAssertEqual(parsed["Gene Names"] as? String, "TP53 P53")
            XCTAssertEqual(parsed["Length"] as? String, "393")
        } else {
            XCTFail("Failed to parse UniProt JSON")
        }
    }

    // MARK: - PTM Fields Tests

    func testPTMFieldsInDifferentialForm() {
        let form = CurtainDifferentialForm(
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

        XCTAssertTrue(form.isPTM, "Form with accession and position should be PTM")
        XCTAssertEqual(form.accession, "ProteinID")
        XCTAssertEqual(form.position, "Position")
        XCTAssertEqual(form.positionPeptide, "PosInPeptide")
        XCTAssertEqual(form.peptideSequence, "Peptide")
        XCTAssertEqual(form.score, "Score")
    }

    func testNonPTMDifferentialForm() {
        let form = CurtainDifferentialForm(
            primaryIDs: "ProteinID",
            geneNames: "GeneName",
            foldChange: "log2FC",
            transformFC: true,
            significant: "pValue",
            transformSignificant: true,
            comparison: "",
            comparisonSelect: [],
            reverseFoldChange: false
        )

        XCTAssertFalse(form.isPTM, "Form without accession and position should NOT be PTM")
        XCTAssertEqual(form.accession, "")
        XCTAssertEqual(form.position, "")
    }

    // MARK: - JSON Parsing Tests

    func testDifferentialFormJsonParsing() throws {
        let json = """
        {
            "primaryIDs": "Index",
            "geneNames": "GeneName",
            "foldChange": "FC",
            "transformFC": false,
            "significant": "pValue",
            "transformSignificant": true,
            "comparison": "CurtainSetComparison",
            "comparisonSelect": ["1", "2"],
            "reverseFoldChange": false,
            "accession": "ProteinAccession",
            "position": "PTMPosition",
            "positionPeptide": "PosInPeptide",
            "peptideSequence": "Sequence",
            "score": "MaxScore"
        }
        """
        let data = json.data(using: .utf8)!
        let form = try JSONDecoder().decode(CurtainDifferentialForm.self, from: data)

        XCTAssertEqual(form.primaryIDs, "Index")
        XCTAssertEqual(form.geneNames, "GeneName")
        XCTAssertEqual(form.foldChange, "FC")
        XCTAssertFalse(form.transformFC)
        XCTAssertEqual(form.significant, "pValue")
        XCTAssertTrue(form.transformSignificant)
        XCTAssertEqual(form.comparison, "CurtainSetComparison")
        XCTAssertEqual(form.comparisonSelect, ["1", "2"])

        // PTM fields
        XCTAssertTrue(form.isPTM)
        XCTAssertEqual(form.accession, "ProteinAccession")
        XCTAssertEqual(form.position, "PTMPosition")
        XCTAssertEqual(form.positionPeptide, "PosInPeptide")
        XCTAssertEqual(form.peptideSequence, "Sequence")
        XCTAssertEqual(form.score, "MaxScore")
    }

    func testDifferentialFormBackwardsCompatibility() throws {
        // JSON without PTM fields (old format)
        let json = """
        {
            "primaryIDs": "ProteinID",
            "geneNames": "Gene",
            "foldChange": "log2FC",
            "transformFC": true,
            "significant": "pValue",
            "transformSignificant": false,
            "comparison": "",
            "comparisonSelect": [],
            "reverseFoldChange": false
        }
        """
        let data = json.data(using: .utf8)!
        let form = try JSONDecoder().decode(CurtainDifferentialForm.self, from: data)

        // Should decode successfully with empty PTM fields
        XCTAssertFalse(form.isPTM)
        XCTAssertEqual(form.accession, "")
        XCTAssertEqual(form.position, "")
        XCTAssertEqual(form.positionPeptide, "")
        XCTAssertEqual(form.peptideSequence, "")
        XCTAssertEqual(form.score, "")
    }

    // MARK: - Settings Tests

    func testCurtainSettingsFromDictionary() {
        let dict: [String: Any] = [
            "pCutoff": 0.05,
            "log2FCCutoff": 0.6,
            "uniprot": true,
            "textAnnotation": ["GeneNames", "Accession"],
            "conditionOrder": ["Control", "Treatment"]
        ]

        let settings = CurtainSettings.fromDictionary(dict)

        XCTAssertEqual(settings.pCutoff, 0.05)
        XCTAssertEqual(settings.log2FCCutoff, 0.6)
        XCTAssertTrue(settings.uniprot)
    }

    func testCurtainSettingsDefaultValues() {
        let settings = CurtainSettings()

        // Default cutoffs
        XCTAssertEqual(settings.pCutoff, 0.05)
        XCTAssertEqual(settings.log2FCCutoff, 0.6)
        XCTAssertTrue(settings.uniprot)
    }

    // MARK: - CurtainData Tests

    func testCurtainDataCurtainTypeForTP() {
        // TP data (non-PTM) - form without accession and position
        let tpForm = CurtainDifferentialForm(
            primaryIDs: "ProteinID",
            geneNames: "Gene"
        )
        XCTAssertFalse(tpForm.isPTM)
    }

    func testCurtainDataCurtainTypeForPTM() {
        // PTM data - form with accession and position
        let ptmForm = CurtainDifferentialForm(
            primaryIDs: "Index",
            accession: "ProteinID",
            position: "Position"
        )
        XCTAssertTrue(ptmForm.isPTM)
    }

    // MARK: - Encoding/Decoding Round Trip Tests

    func testDifferentialFormEncodingRoundTrip() throws {
        let original = CurtainDifferentialForm(
            primaryIDs: "Index",
            geneNames: "Gene",
            foldChange: "FC",
            transformFC: true,
            significant: "pValue",
            transformSignificant: false,
            comparison: "Test",
            comparisonSelect: ["1"],
            reverseFoldChange: true,
            accession: "Acc",
            position: "Pos",
            positionPeptide: "PosInPep",
            peptideSequence: "Seq",
            score: "Score"
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CurtainDifferentialForm.self, from: encoded)

        XCTAssertEqual(decoded.primaryIDs, original.primaryIDs)
        XCTAssertEqual(decoded.geneNames, original.geneNames)
        XCTAssertEqual(decoded.foldChange, original.foldChange)
        XCTAssertEqual(decoded.transformFC, original.transformFC)
        XCTAssertEqual(decoded.significant, original.significant)
        XCTAssertEqual(decoded.transformSignificant, original.transformSignificant)
        XCTAssertEqual(decoded.comparison, original.comparison)
        XCTAssertEqual(decoded.comparisonSelect, original.comparisonSelect)
        XCTAssertEqual(decoded.reverseFoldChange, original.reverseFoldChange)
        XCTAssertEqual(decoded.accession, original.accession)
        XCTAssertEqual(decoded.position, original.position)
        XCTAssertEqual(decoded.positionPeptide, original.positionPeptide)
        XCTAssertEqual(decoded.peptideSequence, original.peptideSequence)
        XCTAssertEqual(decoded.score, original.score)
        XCTAssertEqual(decoded.isPTM, original.isPTM)
    }
}

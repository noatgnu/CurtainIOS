//
//  PTMDataIntegrationTests.swift
//  CurtainTests
//
//  Integration tests for PTM data handling using ONLY real PTM example data.
//  All tests download and use actual data from the server.
//

import XCTest
@testable import Curtain

final class PTMDataIntegrationTests: XCTestCase {

    var sequenceAlignmentService: SequenceAlignmentService!

    override func setUp() {
        super.setUp()
        sequenceAlignmentService = SequenceAlignmentService.shared
    }

    // MARK: - Helper Methods

    private func downloadCurtainData(linkId: String, hostname: String) async throws -> (Data, [String: Any]) {
        let apiURL = "\(hostname)curtain/\(linkId)/download/token=/"

        let (urlData, urlResponse) = try await URLSession.shared.data(from: URL(string: apiURL)!)

        guard let httpResponse = urlResponse as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSError(domain: "PTMDataIntegrationTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to get signed URL"])
        }

        guard let urlJson = try JSONSerialization.jsonObject(with: urlData) as? [String: Any],
              let signedUrl = urlJson["url"] as? String else {
            throw NSError(domain: "PTMDataIntegrationTests", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to parse signed URL"])
        }

        let (data, dataResponse) = try await URLSession.shared.data(from: URL(string: signedUrl)!)

        guard let s3Response = dataResponse as? HTTPURLResponse, s3Response.statusCode == 200 else {
            throw NSError(domain: "PTMDataIntegrationTests", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to download from S3"])
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "PTMDataIntegrationTests", code: 4, userInfo: [NSLocalizedDescriptionKey: "Failed to parse JSON"])
        }

        return (data, json)
    }

    // MARK: - PTM Data Structure Tests

    func testPTMDatasetTypeDetection() async throws {
        let linkId = CurtainConstants.ExamplePTMData.uniqueId
        let hostname = CurtainConstants.ExamplePTMData.apiUrl

        let (_, json) = try await downloadCurtainData(linkId: linkId, hostname: hostname)

        guard let curtainData = CurtainData.fromJSON(json) else {
            XCTFail("Failed to parse PTM CurtainData")
            return
        }

        // Verify curtainType is detected correctly
        XCTAssertEqual(curtainData.curtainType, "PTM", "Should detect PTM curtain type")
        XCTAssertTrue(curtainData.differentialForm.isPTM, "differentialForm.isPTM should be true")

        // Compare with TP data
        let tpLinkId = CurtainConstants.ExampleData.uniqueId
        let tpHostname = CurtainConstants.ExampleData.apiUrl
        let (_, tpJson) = try await downloadCurtainData(linkId: tpLinkId, hostname: tpHostname)

        guard let tpCurtainData = CurtainData.fromJSON(tpJson) else {
            XCTFail("Failed to parse TP CurtainData")
            return
        }

        XCTAssertEqual(tpCurtainData.curtainType, "TP", "TP data should have TP curtain type")
        XCTAssertFalse(tpCurtainData.differentialForm.isPTM, "TP differentialForm.isPTM should be false")

        print("PTM curtainType: \(curtainData.curtainType)")
        print("TP curtainType: \(tpCurtainData.curtainType)")
    }

    func testPTMColumnNames() async throws {
        let linkId = CurtainConstants.ExamplePTMData.uniqueId
        let hostname = CurtainConstants.ExamplePTMData.apiUrl

        let (_, json) = try await downloadCurtainData(linkId: linkId, hostname: hostname)

        guard let curtainData = CurtainData.fromJSON(json) else {
            XCTFail("Failed to parse PTM CurtainData")
            return
        }

        let diffForm = curtainData.differentialForm

        // Log all PTM-specific column names
        print("PTM Column Configuration:")
        print("  accession: '\(diffForm.accession)'")
        print("  position: '\(diffForm.position)'")
        print("  positionPeptide: '\(diffForm.positionPeptide)'")
        print("  peptideSequence: '\(diffForm.peptideSequence)'")
        print("  score: '\(diffForm.score)'")

        // Verify PTM columns are populated
        XCTAssertFalse(diffForm.accession.isEmpty, "accession column should be configured")
        XCTAssertFalse(diffForm.position.isEmpty, "position column should be configured")

        // These may or may not be present depending on dataset
        print("  peptideSequence present: \(!diffForm.peptideSequence.isEmpty)")
        print("  score present: \(!diffForm.score.isEmpty)")
    }

    // MARK: - Sequence Alignment Tests with Real Data

    func testSequenceAlignmentWithRealUniProtSequence() async throws {
        let linkId = CurtainConstants.ExamplePTMData.uniqueId
        let hostname = CurtainConstants.ExamplePTMData.apiUrl

        let (_, json) = try await downloadCurtainData(linkId: linkId, hostname: hostname)

        guard let curtainData = CurtainData.fromJSON(json) else {
            XCTFail("Failed to parse PTM CurtainData")
            return
        }

        guard let uniprotDb = curtainData.extraData?.uniprot?.db else {
            XCTFail("PTM data should have UniProt DB")
            return
        }

        // Find a protein with sequence data
        var testAccession: String?
        var testSequence: String?

        for (accession, entry) in uniprotDb {
            if let entryDict = entry as? [String: Any],
               let sequence = entryDict["Sequence"] as? String,
               sequence.count > 50 {  // Need reasonable length for testing
                testAccession = accession
                testSequence = sequence
                break
            }
        }

        guard let accession = testAccession,
              let sequence = testSequence else {
            print("No protein with sequence found in UniProt DB - this may be expected for some datasets")
            // Don't fail - just skip this test if no sequences available
            return
        }

        print("Testing alignment with \(accession), sequence length: \(sequence.count)")

        // Test sequence extraction
        let extractedSequence = sequenceAlignmentService.extractSequence(uniprotData: ["Sequence": sequence])
        XCTAssertEqual(extractedSequence, sequence, "Should extract sequence correctly")

        // Test self-alignment (should be perfect)
        let selfAlignment = sequenceAlignmentService.alignSequences(
            experimentalSequence: sequence,
            canonicalSequence: sequence
        )

        XCTAssertEqual(selfAlignment.experimentalAligned, selfAlignment.canonicalAligned,
                       "Self-alignment should produce identical aligned sequences")
        print("Self-alignment successful, aligned length: \(selfAlignment.experimentalAligned.count)")
    }

    func testPeptideAlignmentWithRealSequence() async throws {
        let linkId = CurtainConstants.ExamplePTMData.uniqueId
        let hostname = CurtainConstants.ExamplePTMData.apiUrl

        let (_, json) = try await downloadCurtainData(linkId: linkId, hostname: hostname)

        guard let curtainData = CurtainData.fromJSON(json) else {
            XCTFail("Failed to parse PTM CurtainData")
            return
        }

        guard let uniprotDb = curtainData.extraData?.uniprot?.db else {
            XCTFail("PTM data should have UniProt DB")
            return
        }

        // Find a protein with sequence
        var foundAlignment = false
        for (accession, entry) in uniprotDb.prefix(10) {
            guard let entryDict = entry as? [String: Any],
                  let sequence = entryDict["Sequence"] as? String,
                  sequence.count > 20 else { continue }

            // Create a peptide from the actual sequence (positions 10-20)
            let peptideStart = min(10, sequence.count - 1)
            let peptideEnd = min(20, sequence.count)
            let startIdx = sequence.index(sequence.startIndex, offsetBy: peptideStart)
            let endIdx = sequence.index(sequence.startIndex, offsetBy: peptideEnd)
            let peptide = String(sequence[startIdx..<endIdx])

            // Test peptide alignment
            let alignment = sequenceAlignmentService.alignPeptideToSequence(
                peptideSequence: peptide,
                canonicalSequence: sequence
            )

            if let result = alignment {
                print("Real peptide '\(peptide)' from \(accession) aligned: positions \(result.start)-\(result.end)")
                // The peptide should be found at approximately position peptideStart + 1 (1-indexed)
                XCTAssertGreaterThan(result.start, 0, "Start position should be positive")
                XCTAssertLessThanOrEqual(result.end, sequence.count, "End position should be within sequence")
                foundAlignment = true
                break
            }
        }

        if !foundAlignment {
            print("No suitable protein with sequence found for peptide alignment test")
        }
    }

    // MARK: - PTM Position Extraction Tests with Real Data

    func testPTMPositionExtractionFromRealData() async throws {
        let linkId = CurtainConstants.ExamplePTMData.uniqueId
        let hostname = CurtainConstants.ExamplePTMData.apiUrl

        let (_, json) = try await downloadCurtainData(linkId: linkId, hostname: hostname)

        // Get processed TSV data
        guard let processedTsv = json["processed"] as? String, !processedTsv.isEmpty else {
            XCTFail("PTM data should have processed TSV")
            return
        }

        guard let curtainData = CurtainData.fromJSON(json) else {
            XCTFail("Failed to parse PTM CurtainData")
            return
        }

        let diffForm = curtainData.differentialForm
        print("Peptide sequence column: '\(diffForm.peptideSequence)'")

        // Parse the TSV to find peptides with modifications
        let lines = processedTsv.components(separatedBy: .newlines)
        guard lines.count > 1 else {
            XCTFail("Processed data should have rows")
            return
        }

        let headers = lines[0].components(separatedBy: "\t")

        // Find peptide sequence column index
        var peptideColIndex: Int?
        if !diffForm.peptideSequence.isEmpty {
            peptideColIndex = headers.firstIndex(of: diffForm.peptideSequence)
        }

        // Look for any column that might contain peptide sequences
        if peptideColIndex == nil {
            for (index, header) in headers.enumerated() {
                let lowerHeader = header.lowercased()
                if lowerHeader.contains("peptide") || lowerHeader.contains("sequence") {
                    peptideColIndex = index
                    print("Found peptide column: '\(header)' at index \(index)")
                    break
                }
            }
        }

        // Find and analyze real peptides from the data
        var peptidesWithMods = 0
        var totalPeptides = 0

        for lineIndex in 1..<min(100, lines.count) {
            let cols = lines[lineIndex].components(separatedBy: "\t")

            if let peptideIdx = peptideColIndex, peptideIdx < cols.count {
                let peptide = cols[peptideIdx]
                if !peptide.isEmpty {
                    totalPeptides += 1

                    // Check if peptide has modification notation
                    if peptide.contains("[") || peptide.contains("(") {
                        peptidesWithMods += 1

                        // Extract PTM positions
                        let positions = sequenceAlignmentService.extractPTMPositionFromPeptide(
                            peptideSequence: peptide,
                            startPosition: 1
                        )

                        if lineIndex < 5 {
                            print("Real peptide: '\(peptide)'")
                            print("  Cleaned: '\(sequenceAlignmentService.cleanPeptideSequence(peptide))'")
                            print("  PTM positions: \(positions.map { "\($0.residue)\($0.positionInPeptide) [\($0.modification ?? "unknown")]" })")
                        }
                    }
                }
            }
        }

        print("Total peptides analyzed: \(totalPeptides)")
        print("Peptides with modifications: \(peptidesWithMods)")
    }

    func testCleanPeptideSequenceWithRealData() async throws {
        let linkId = CurtainConstants.ExamplePTMData.uniqueId
        let hostname = CurtainConstants.ExamplePTMData.apiUrl

        let (_, json) = try await downloadCurtainData(linkId: linkId, hostname: hostname)

        guard let processedTsv = json["processed"] as? String, !processedTsv.isEmpty else {
            XCTFail("PTM data should have processed TSV")
            return
        }

        guard let curtainData = CurtainData.fromJSON(json) else {
            XCTFail("Failed to parse PTM CurtainData")
            return
        }

        let diffForm = curtainData.differentialForm
        let lines = processedTsv.components(separatedBy: .newlines)
        guard lines.count > 1 else { return }

        let headers = lines[0].components(separatedBy: "\t")

        // Find peptide column
        var peptideColIndex: Int?
        if !diffForm.peptideSequence.isEmpty {
            peptideColIndex = headers.firstIndex(of: diffForm.peptideSequence)
        }
        if peptideColIndex == nil {
            for (index, header) in headers.enumerated() {
                if header.lowercased().contains("peptide") || header.lowercased().contains("sequence") {
                    peptideColIndex = index
                    break
                }
            }
        }

        guard let pepIdx = peptideColIndex else {
            print("No peptide column found in data")
            return
        }

        // Test cleaning real peptides
        var cleanedCount = 0
        for lineIndex in 1..<min(20, lines.count) {
            let cols = lines[lineIndex].components(separatedBy: "\t")
            if pepIdx < cols.count {
                let peptide = cols[pepIdx]
                if !peptide.isEmpty {
                    let cleaned = sequenceAlignmentService.cleanPeptideSequence(peptide)

                    // Cleaned sequence should only contain amino acid letters
                    let allowedChars = CharacterSet(charactersIn: "ACDEFGHIKLMNPQRSTVWYacdefghiklmnpqrstvwy")
                    let cleanedScalars = cleaned.unicodeScalars.filter { allowedChars.contains($0) }
                    XCTAssertEqual(cleaned.count, cleanedScalars.count,
                                   "Cleaned peptide should only contain amino acid letters")

                    if cleanedCount < 5 {
                        print("Original: '\(peptide)' -> Cleaned: '\(cleaned)'")
                    }
                    cleanedCount += 1
                }
            }
        }

        print("Cleaned \(cleanedCount) real peptides successfully")
    }

    // MARK: - UniProt Feature Parsing Tests

    func testParseUniProtFeaturesFromRealData() async throws {
        let linkId = CurtainConstants.ExamplePTMData.uniqueId
        let hostname = CurtainConstants.ExamplePTMData.apiUrl

        let (_, json) = try await downloadCurtainData(linkId: linkId, hostname: hostname)

        guard let curtainData = CurtainData.fromJSON(json) else {
            XCTFail("Failed to parse PTM CurtainData")
            return
        }

        guard let uniprotDb = curtainData.extraData?.uniprot?.db else {
            XCTFail("PTM data should have UniProt DB")
            return
        }

        var totalFeatures = 0
        var proteinsWithFeatures = 0

        for (accession, entry) in uniprotDb.prefix(10) {
            guard let entryDict = entry as? [String: Any] else { continue }

            let features = sequenceAlignmentService.parseUniProtFeatures(uniprotData: entryDict)

            if !features.isEmpty {
                proteinsWithFeatures += 1
                totalFeatures += features.count
                print("\(accession): \(features.count) features")
                for feature in features.prefix(3) {
                    print("  - \(feature.type) at \(feature.startPosition)-\(feature.endPosition): \(feature.description)")
                }
            }
        }

        print("Total: \(proteinsWithFeatures) proteins with \(totalFeatures) features (from first 10)")
    }

    func testExtractDomainsFromRealData() async throws {
        let linkId = CurtainConstants.ExamplePTMData.uniqueId
        let hostname = CurtainConstants.ExamplePTMData.apiUrl

        let (_, json) = try await downloadCurtainData(linkId: linkId, hostname: hostname)

        guard let curtainData = CurtainData.fromJSON(json) else {
            XCTFail("Failed to parse PTM CurtainData")
            return
        }

        guard let uniprotDb = curtainData.extraData?.uniprot?.db else {
            XCTFail("PTM data should have UniProt DB")
            return
        }

        var totalDomains = 0

        for (accession, entry) in uniprotDb.prefix(20) {
            guard let entryDict = entry as? [String: Any] else { continue }

            let domains = sequenceAlignmentService.extractDomains(uniprotData: entryDict)

            if !domains.isEmpty {
                totalDomains += domains.count
                print("\(accession) domains:")
                for domain in domains {
                    print("  - \(domain.name) (\(domain.startPosition)-\(domain.endPosition))")
                }
            }
        }

        print("Total domains found: \(totalDomains)")
    }

    // MARK: - PTM Site Comparison Tests with Real Data

    func testComparePTMSitesWithRealData() async throws {
        let linkId = CurtainConstants.ExamplePTMData.uniqueId
        let hostname = CurtainConstants.ExamplePTMData.apiUrl

        let (_, json) = try await downloadCurtainData(linkId: linkId, hostname: hostname)

        guard let curtainData = CurtainData.fromJSON(json) else {
            XCTFail("Failed to parse PTM CurtainData")
            return
        }

        guard let uniprotDb = curtainData.extraData?.uniprot?.db else {
            XCTFail("PTM data should have UniProt DB")
            return
        }

        // Find a protein with both sequence and features
        for (accession, entry) in uniprotDb.prefix(20) {
            guard let entryDict = entry as? [String: Any],
                  let sequence = entryDict["Sequence"] as? String,
                  sequence.count > 50 else { continue }

            let features = sequenceAlignmentService.parseUniProtFeatures(uniprotData: entryDict)
            let modifiedResidues = features.filter { $0.type == .modifiedResidue }

            if modifiedResidues.isEmpty { continue }

            // Create experimental sites from the first few known positions
            // (simulating experimental data that matches some UniProt annotations)
            var experimentalSites: [ExperimentalPTMSite] = []
            for (index, feature) in modifiedResidues.prefix(3).enumerated() {
                let pos = feature.startPosition
                let residue: Character = pos <= sequence.count ?
                    sequence[sequence.index(sequence.startIndex, offsetBy: pos - 1)] : "X"

                experimentalSites.append(ExperimentalPTMSite(
                    primaryId: "\(accession)_\(pos)",
                    position: pos,
                    residue: residue,
                    isSignificant: index == 0  // First one significant
                ))
            }

            // Compare with UniProt features
            let comparisons = sequenceAlignmentService.comparePTMSites(
                experimentalSites: experimentalSites,
                uniprotFeatures: features,
                canonicalSequence: sequence
            )

            let matched = comparisons.filter { $0.comparisonType == .matched }
            let knownOnly = comparisons.filter { $0.comparisonType == .knownOnly }

            print("\(accession) PTM Site Comparison:")
            print("  Experimental sites: \(experimentalSites.count)")
            print("  UniProt modified residues: \(modifiedResidues.count)")
            print("  Matched: \(matched.count)")
            print("  Known only (UniProt): \(knownOnly.count)")

            // All experimental sites should be matched since we derived them from UniProt
            XCTAssertEqual(matched.count, experimentalSites.count,
                           "All experimental sites should match UniProt annotations")
            break
        }
    }

    // MARK: - Aligned Peptide Creation Tests

    func testCreateAlignedPeptideWithRealSequence() async throws {
        let linkId = CurtainConstants.ExamplePTMData.uniqueId
        let hostname = CurtainConstants.ExamplePTMData.apiUrl

        let (_, json) = try await downloadCurtainData(linkId: linkId, hostname: hostname)

        guard let curtainData = CurtainData.fromJSON(json) else {
            XCTFail("Failed to parse PTM CurtainData")
            return
        }

        guard let uniprotDb = curtainData.extraData?.uniprot?.db else {
            XCTFail("PTM data should have UniProt DB")
            return
        }

        // Find a protein with sequence
        for (accession, entry) in uniprotDb.prefix(5) {
            guard let entryDict = entry as? [String: Any],
                  let sequence = entryDict["Sequence"] as? String,
                  sequence.count > 30 else { continue }

            // Create a real peptide from the sequence (positions 10-20)
            let startPos = min(10, sequence.count - 10)
            let endPos = min(startPos + 10, sequence.count)
            let startIdx = sequence.index(sequence.startIndex, offsetBy: startPos)
            let endIdx = sequence.index(sequence.startIndex, offsetBy: endPos)
            let rawPeptide = String(sequence[startIdx..<endIdx])

            let alignedPeptide = sequenceAlignmentService.createAlignedPeptide(
                primaryId: "\(accession)_test",
                peptideSequence: rawPeptide,
                canonicalSequence: sequence,
                isSignificant: true
            )

            XCTAssertNotNil(alignedPeptide, "Should create aligned peptide")
            if let aligned = alignedPeptide {
                print("Created aligned peptide for \(accession):")
                print("  peptide: \(aligned.peptideSequence)")
                print("  position: \(aligned.startPosition)-\(aligned.endPosition)")
                print("  isSignificant: \(aligned.isSignificant)")

                XCTAssertGreaterThan(aligned.startPosition, 0, "Start should be positive")
                XCTAssertLessThanOrEqual(aligned.endPosition, sequence.count, "End should be within sequence")
            }
            break
        }
    }

    // MARK: - UniProt Data Extraction Tests

    func testExtractUniProtMetadataFromRealData() async throws {
        let linkId = CurtainConstants.ExamplePTMData.uniqueId
        let hostname = CurtainConstants.ExamplePTMData.apiUrl

        let (_, json) = try await downloadCurtainData(linkId: linkId, hostname: hostname)

        guard let curtainData = CurtainData.fromJSON(json) else {
            XCTFail("Failed to parse PTM CurtainData")
            return
        }

        guard let uniprotDb = curtainData.extraData?.uniprot?.db else {
            XCTFail("PTM data should have UniProt DB")
            return
        }

        var extractedCount = 0

        for (accession, entry) in uniprotDb.prefix(5) {
            guard let entryDict = entry as? [String: Any] else { continue }

            let geneName = sequenceAlignmentService.extractGeneName(uniprotData: entryDict)
            let proteinName = sequenceAlignmentService.extractProteinName(uniprotData: entryDict)
            let organism = sequenceAlignmentService.extractOrganism(uniprotData: entryDict)
            let sequence = sequenceAlignmentService.extractSequence(uniprotData: entryDict)

            print("\(accession):")
            print("  Gene: \(geneName ?? "nil")")
            print("  Protein: \(proteinName ?? "nil")")
            print("  Organism: \(organism ?? "nil")")
            print("  Sequence length: \(sequence?.count ?? 0)")

            if geneName != nil || proteinName != nil {
                extractedCount += 1
            }
        }

        print("Extracted metadata from \(extractedCount)/5 entries")
    }

    // MARK: - PTM ViewModel Integration Tests

    @MainActor
    func testPTMViewerViewModelInitialState() async {
        let viewModel = PTMViewerViewModel()

        XCTAssertNil(viewModel.ptmViewerState, "Initial state should be nil")
        XCTAssertTrue(viewModel.selectedModTypes.isEmpty, "Initial mod types should be empty")
        XCTAssertFalse(viewModel.isLoading, "Should not be loading initially")
        XCTAssertNil(viewModel.error, "Should have no error initially")
    }

    @MainActor
    func testPTMViewerViewModelFiltering() async {
        let viewModel = PTMViewerViewModel()

        // Test mod type filtering
        let modTypes: Set<String> = ["Phosphorylation", "Acetylation"]
        viewModel.updateSelectedModTypes(modTypes)
        XCTAssertEqual(viewModel.selectedModTypes, modTypes)

        // Test custom database filtering
        let databases: Set<String> = ["PhosphoSitePlus"]
        viewModel.updateSelectedCustomDatabases(databases)
        XCTAssertEqual(viewModel.selectedCustomDatabases, databases)

        // Test variant selection
        viewModel.selectVariant("P12345-2")
        XCTAssertEqual(viewModel.selectedVariant, "P12345-2")

        // Test reset
        viewModel.resetToDefault()
        XCTAssertNil(viewModel.selectedVariant)
        XCTAssertNil(viewModel.customSequence)
    }
}

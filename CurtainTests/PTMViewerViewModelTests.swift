//
//  PTMViewerViewModelTests.swift
//  CurtainTests
//
//  Unit tests for PTMViewerViewModel
//

import XCTest
@testable import Curtain

@MainActor
final class PTMViewerViewModelTests: XCTestCase {

    var viewModel: PTMViewerViewModel!

    override func setUp() {
        super.setUp()
        viewModel = PTMViewerViewModel()
    }

    override func tearDown() {
        viewModel = nil
        super.tearDown()
    }

    // MARK: - Initial State Tests

    func testInitialState() {
        XCTAssertNil(viewModel.ptmViewerState)
        XCTAssertTrue(viewModel.selectedModTypes.isEmpty)
        XCTAssertTrue(viewModel.selectedCustomDatabases.isEmpty)
        XCTAssertNil(viewModel.selectedVariant)
        XCTAssertNil(viewModel.customSequence)
        XCTAssertNil(viewModel.selectedSite)
        XCTAssertEqual(viewModel.pCutoff, 0.05)
        XCTAssertEqual(viewModel.fcCutoff, 0.6)
        XCTAssertNil(viewModel.error)
        XCTAssertFalse(viewModel.isLoading)
    }

    // MARK: - Filter Tests

    func testUpdateSelectedModTypes() {
        let modTypes: Set<String> = ["Phosphorylation", "Acetylation"]

        viewModel.updateSelectedModTypes(modTypes)

        XCTAssertEqual(viewModel.selectedModTypes, modTypes)
    }

    func testUpdateSelectedCustomDatabases() {
        let databases: Set<String> = ["PhosphoSitePlus", "UniProt"]

        viewModel.updateSelectedCustomDatabases(databases)

        XCTAssertEqual(viewModel.selectedCustomDatabases, databases)
    }

    // MARK: - Variant Selection Tests

    func testSelectVariant() {
        viewModel.selectVariant("P12345-2")

        XCTAssertEqual(viewModel.selectedVariant, "P12345-2")
    }

    func testSelectVariantNil() {
        viewModel.selectVariant("P12345-2")
        viewModel.selectVariant(nil)

        XCTAssertNil(viewModel.selectedVariant)
    }

    // MARK: - Custom Sequence Tests

    func testSetCustomSequence() {
        viewModel.setCustomSequence("MKLPVRGSS")

        XCTAssertEqual(viewModel.customSequence, "MKLPVRGSS")
    }

    func testSetCustomSequenceNil() {
        viewModel.setCustomSequence("MKLPVRGSS")
        viewModel.setCustomSequence(nil)

        XCTAssertNil(viewModel.customSequence)
    }

    // MARK: - Reset Tests

    func testResetToDefault() {
        viewModel.selectVariant("P12345-2")
        viewModel.setCustomSequence("MKLPVRGSS")

        viewModel.resetToDefault()

        XCTAssertNil(viewModel.selectedVariant)
        XCTAssertNil(viewModel.customSequence)
    }

    // MARK: - Computed Properties Tests

    func testFilteredExperimentalSitesWithNoState() {
        let sites = viewModel.filteredExperimentalSites

        XCTAssertTrue(sites.isEmpty)
    }

    func testFilteredCustomPTMSitesWithNoState() {
        let sites = viewModel.filteredCustomPTMSites

        XCTAssertTrue(sites.isEmpty)
    }

    func testPTMSiteComparisonsWithNoState() {
        let comparisons = viewModel.ptmSiteComparisons

        XCTAssertTrue(comparisons.isEmpty)
    }

    // MARK: - Loading State Tests

    func testIsLoadingInitiallyFalse() {
        XCTAssertFalse(viewModel.isLoading)
    }

    // MARK: - Error State Tests

    func testErrorInitiallyNil() {
        XCTAssertNil(viewModel.error)
    }
}

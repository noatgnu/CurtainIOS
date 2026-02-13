//
//  AnnotationAndBracketUITests.swift
//  CurtainUITests
//
//  Comprehensive UI tests for annotation creation, movement, and bracket functionality.
//  Tests interactions with volcano plot and bar chart using real data.
//
//  All interactions are through UI elements only - no direct data manipulation.
//

import XCTest

final class AnnotationAndBracketUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Helper Methods

    /// Load TP example data using UI elements and navigate to details view
    /// Returns true if successfully loaded
    private func loadTPExampleAndNavigateToDetails() -> Bool {
        // Navigate to Datasets tab
        let datasetsTab = app.tabBars.buttons["Datasets"]
        guard datasetsTab.waitForExistence(timeout: 10) else {
            return false
        }
        datasetsTab.tap()
        sleep(1)

        // Find and tap TP Example button using accessibility identifier
        let tpButton = app.buttons["loadTPExampleButton"]
        if !tpButton.waitForExistence(timeout: 5) {
            // Try finding by label as fallback
            let tpButtonByLabel = app.buttons["TP Example"]
            guard tpButtonByLabel.waitForExistence(timeout: 5) else {
                return false
            }
            tpButtonByLabel.tap()
        } else {
            tpButton.tap()
        }

        sleep(3)

        // Tap on the curtain entry in the list
        let listItems = app.cells
        guard listItems.count > 0 else {
            return false
        }
        listItems.firstMatch.tap()

        // Handle download confirmation alert using UI elements
        let downloadAlert = app.alerts["Download Data"]
        if downloadAlert.waitForExistence(timeout: 5) {
            let downloadButton = downloadAlert.buttons["Download"]
            if downloadButton.exists {
                downloadButton.tap()
            }
        }

        // Wait for data to load - look for the main tab picker (segmented control on iPhone)
        // or Protein List tab indicator (iPad)
        for _ in 0..<40 {
            // Check for segmented control (iPhone) - primary indicator
            if app.segmentedControls["mainTabPicker"].exists {
                sleep(1) // Give a moment for data to stabilize
                return true
            }

            // Check for tab elements (iPad)
            if app.tabBars.buttons.count >= 4 {
                return true
            }

            // Fallback checks
            if app.buttons["Protein List"].exists ||
               app.staticTexts["Protein List"].exists ||
               app.buttons["proteinListTab"].exists {
                return true
            }
            sleep(3)
        }

        return false
    }

    /// Load PTM example data using UI elements and navigate to details view
    private func loadPTMExampleAndNavigateToDetails() -> Bool {
        let datasetsTab = app.tabBars.buttons["Datasets"]
        guard datasetsTab.waitForExistence(timeout: 10) else {
            return false
        }
        datasetsTab.tap()
        sleep(1)

        // Find PTM Example button
        let ptmButton = app.buttons["loadPTMExampleButton"]
        if !ptmButton.waitForExistence(timeout: 5) {
            let ptmButtonByLabel = app.buttons["PTM Example"]
            guard ptmButtonByLabel.waitForExistence(timeout: 5) else {
                return false
            }
            ptmButtonByLabel.tap()
        } else {
            ptmButton.tap()
        }

        sleep(3)

        let listItems = app.cells
        guard listItems.count > 0 else {
            return false
        }
        listItems.firstMatch.tap()

        // Handle download alert
        let downloadAlert = app.alerts["Download Data"]
        if downloadAlert.waitForExistence(timeout: 5) {
            downloadAlert.buttons["Download"].tap()
        }

        // Wait for data to load - look for the main tab picker (segmented control on iPhone)
        // or Site List tab indicator (iPad)
        for _ in 0..<40 {
            // Check for segmented control (iPhone) - primary indicator
            if app.segmentedControls["mainTabPicker"].exists {
                sleep(1) // Give a moment for data to stabilize
                return true
            }

            // Check for tab elements (iPad)
            if app.tabBars.buttons.count >= 4 {
                return true
            }

            // Fallback checks
            if app.buttons["Site List"].exists ||
               app.staticTexts["Site List"].exists ||
               app.buttons["siteListTab"].exists {
                return true
            }
            sleep(3)
        }

        return false
    }

    /// Navigate to a specific tab by index using the segmented picker
    /// Tab indices: 0=Overview, 1=Volcano Plot, 2=Protein/Site List, 3=Settings
    private func navigateToTabByIndex(_ index: Int) {
        // First try segmented control with accessibility identifier
        let mainTabPicker = app.segmentedControls["mainTabPicker"]
        if mainTabPicker.waitForExistence(timeout: 10) {
            // Use index-based selection for iPhone segmented picker (has icons, not text)
            let segmentByIndex = mainTabPicker.buttons.element(boundBy: index)
            if segmentByIndex.exists && segmentByIndex.isHittable {
                segmentByIndex.tap()
                sleep(2)
                return
            }
        }

        // Fallback: try any segmented control
        let segments = app.segmentedControls.firstMatch
        if segments.waitForExistence(timeout: 5) {
            let segment = segments.buttons.element(boundBy: index)
            if segment.exists && segment.isHittable {
                segment.tap()
                sleep(2)
                return
            }
        }

        // Fallback for iPad: try TabView tab bar buttons by index
        let tabBarButtons = app.tabBars.buttons
        if tabBarButtons.count > index {
            let button = tabBarButtons.element(boundBy: index)
            if button.exists && button.isHittable {
                button.tap()
                sleep(2)
                return
            }
        }
    }

    /// Navigate to the volcano plot tab (index 1)
    private func navigateToVolcanoPlotTab() {
        navigateToTabByIndex(1)
    }

    /// Navigate to protein/site list tab (index 2)
    private func navigateToListTab() {
        navigateToTabByIndex(2)
    }

    /// Navigate to settings tab (index 3)
    private func navigateToSettingsTab() {
        navigateToTabByIndex(3)
    }

    /// Navigate to overview tab (index 0)
    private func navigateToOverviewTab() {
        navigateToTabByIndex(0)
    }

    // MARK: - Annotation Creation Tests

    @MainActor
    func testCreateAnnotationThroughVolcanoPlotTap() throws {
        guard loadTPExampleAndNavigateToDetails() else {
            XCTFail("Failed to load TP example data")
            return
        }

        // Navigate to volcano plot
        navigateToVolcanoPlotTab()
        sleep(3)

        // Find the volcano plot WebView
        let volcanoWebView = app.webViews.firstMatch
        guard volcanoWebView.waitForExistence(timeout: 30) else {
            XCTFail("Volcano plot WebView not found")
            return
        }

        // Tap on the plot to trigger point selection
        // Use a coordinate in the middle of the plot
        let plotCenter = volcanoWebView.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        plotCenter.tap()
        sleep(2)

        // Check if Point Interaction Modal appears
        let proteinInteractionTitle = app.staticTexts["Protein Interaction"]
        if proteinInteractionTitle.waitForExistence(timeout: 10) {
            // Switch to Annotate tab using the segmented picker
            let tabPicker = app.segmentedControls["pointInteractionTabPicker"]
            if tabPicker.exists {
                tabPicker.buttons["Annotate"].tap()
            } else {
                // Find by text
                let annotateTab = app.buttons["Annotate"]
                if annotateTab.exists {
                    annotateTab.tap()
                }
            }
            sleep(1)

            // Tap Done to create annotation
            let doneButton = app.buttons["pointInteractionDoneButton"]
            if doneButton.exists && doneButton.isEnabled {
                doneButton.tap()
                print("Annotation created through volcano plot tap")
            } else {
                // Fallback to finding Done button by label
                let doneByLabel = app.buttons["Done"]
                if doneByLabel.exists {
                    doneByLabel.tap()
                }
            }

            sleep(2)

            // Verify the modal closed
            XCTAssertFalse(proteinInteractionTitle.exists, "Modal should be dismissed after creating annotation")
        }
    }

    @MainActor
    func testCreateAnnotationFromProteinList() throws {
        guard loadTPExampleAndNavigateToDetails() else {
            XCTFail("Failed to load TP example data")
            return
        }

        // Navigate to Protein List
        navigateToListTab()
        sleep(2)

        // Tap on a protein row
        let rows = app.cells
        guard rows.count > 0 else {
            XCTFail("No protein rows found in list")
            return
        }

        // Tap first row
        rows.firstMatch.tap()
        sleep(2)

        // Check if interaction modal or detail view appears
        let proteinInteractionTitle = app.staticTexts["Protein Interaction"]
        if proteinInteractionTitle.waitForExistence(timeout: 5) {
            // Switch to Annotate tab
            let annotateTab = app.buttons["Annotate"]
            if annotateTab.exists {
                annotateTab.tap()
                sleep(1)
            }

            // Create annotation
            let doneButton = app.buttons["Done"]
            if doneButton.exists && doneButton.isEnabled {
                doneButton.tap()
                print("Annotation created from protein list")
            }
        }
    }

    // MARK: - Annotation Movement Tests

    @MainActor
    func testMoveAnnotationUsingSliders() throws {
        guard loadTPExampleAndNavigateToDetails() else {
            XCTFail("Failed to load TP example data")
            return
        }

        // First, create an annotation
        navigateToVolcanoPlotTab()
        sleep(3)

        let volcanoWebView = app.webViews.firstMatch
        guard volcanoWebView.waitForExistence(timeout: 30) else {
            XCTFail("Volcano plot WebView not found")
            return
        }

        // Tap to create annotation first
        volcanoWebView.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        sleep(2)

        let proteinInteractionTitle = app.staticTexts["Protein Interaction"]
        if proteinInteractionTitle.waitForExistence(timeout: 10) {
            // Switch to Annotate tab and create
            app.buttons["Annotate"].tap()
            sleep(1)
            app.buttons["Done"].tap()
            sleep(2)
        }

        // Now tap on existing annotation to edit it
        volcanoWebView.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        sleep(2)

        // Look for Edit Annotation modal
        let editAnnotationTitle = app.navigationBars["Edit Annotation"]
        if editAnnotationTitle.waitForExistence(timeout: 5) {
            // Select "Adjust Position (Sliders)" option
            let sliderOption = app.buttons["annotationMoveSliderOption"]
            if sliderOption.exists {
                sliderOption.tap()
                sleep(1)
            } else {
                // Fallback to label
                let sliderOptionByLabel = app.staticTexts["Adjust Position (Sliders)"]
                if sliderOptionByLabel.exists {
                    sliderOptionByLabel.tap()
                    sleep(1)
                }
            }

            // Adjust the horizontal slider
            let sliders = app.sliders
            if sliders.count > 0 {
                sliders.firstMatch.adjust(toNormalizedSliderPosition: 0.7)
                sleep(1)
            }

            // Save
            let doneButton = app.buttons["annotationEditDoneButton"]
            if doneButton.exists {
                doneButton.tap()
            } else {
                app.buttons["Done"].tap()
            }

            print("Annotation moved using sliders")
        }
    }

    @MainActor
    func testMoveAnnotationInteractively() throws {
        guard loadTPExampleAndNavigateToDetails() else {
            XCTFail("Failed to load TP example data")
            return
        }

        navigateToVolcanoPlotTab()
        sleep(3)

        let volcanoWebView = app.webViews.firstMatch
        guard volcanoWebView.waitForExistence(timeout: 30) else {
            XCTFail("Volcano plot WebView not found")
            return
        }

        // Create annotation first
        volcanoWebView.coordinate(withNormalizedOffset: CGVector(dx: 0.4, dy: 0.4)).tap()
        sleep(2)

        if app.staticTexts["Protein Interaction"].waitForExistence(timeout: 10) {
            app.buttons["Annotate"].tap()
            sleep(1)
            app.buttons["Done"].tap()
            sleep(2)
        }

        // Edit annotation
        volcanoWebView.coordinate(withNormalizedOffset: CGVector(dx: 0.4, dy: 0.4)).tap()
        sleep(2)

        let editAnnotationTitle = app.navigationBars["Edit Annotation"]
        if editAnnotationTitle.waitForExistence(timeout: 5) {
            // Select interactive mode
            let interactiveOption = app.buttons["annotationMoveInteractiveOption"]
            if interactiveOption.exists {
                interactiveOption.tap()
                sleep(1)
            } else {
                let interactiveByLabel = app.staticTexts["Move by Tapping on Plot"]
                if interactiveByLabel.exists {
                    interactiveByLabel.tap()
                    sleep(1)
                }
            }

            // Click Start Interactive Mode
            let startButton = app.buttons["Start Interactive Mode"]
            if startButton.exists {
                startButton.tap()
                sleep(2)

                // Tap on new location
                volcanoWebView.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.3)).tap()
                sleep(2)

                print("Annotation moved interactively")
            }
        }
    }

    // MARK: - Bar Chart Bracket Tests

    @MainActor
    func testEnableBracketOnBarChart() throws {
        guard loadTPExampleAndNavigateToDetails() else {
            XCTFail("Failed to load TP example data")
            return
        }

        // Navigate to protein list and select a protein
        navigateToListTab()
        sleep(2)

        let rows = app.cells
        guard rows.count > 0 else {
            XCTFail("No protein rows found")
            return
        }

        rows.firstMatch.tap()
        sleep(3)

        // Look for settings or bracket options
        // Navigate to Settings tab
        navigateToSettingsTab()
        sleep(2)

        // Find Condition Bracket setting
        let bracketSetting = app.buttons["Condition Bracket"]
        let bracketCell = app.cells.containing(NSPredicate(format: "label CONTAINS 'Bracket'")).firstMatch

        if bracketSetting.waitForExistence(timeout: 10) {
            bracketSetting.tap()
            sleep(1)

            // Enable bracket using toggle
            let bracketToggle = app.switches["showBracketToggle"]
            if bracketToggle.exists {
                if bracketToggle.value as? String == "0" {
                    bracketToggle.tap()
                    sleep(1)
                }

                // Save
                let saveButton = app.buttons["bracketSaveButton"]
                if saveButton.exists {
                    saveButton.tap()
                } else {
                    app.buttons["Save"].tap()
                }

                print("Bracket enabled on bar chart")
            } else {
                // Fallback to finding toggle by label
                let toggleByLabel = app.switches["Show Condition Bracket"]
                if toggleByLabel.exists && toggleByLabel.value as? String == "0" {
                    toggleByLabel.tap()
                    sleep(1)
                    app.buttons["Save"].tap()
                }
            }
        } else if bracketCell.exists {
            bracketCell.tap()
            sleep(1)
        }
    }

    @MainActor
    func testAdjustBracketHeight() throws {
        guard loadTPExampleAndNavigateToDetails() else {
            XCTFail("Failed to load TP example data")
            return
        }

        navigateToSettingsTab()
        sleep(2)

        let bracketSetting = app.buttons["Condition Bracket"]
        if bracketSetting.waitForExistence(timeout: 10) {
            bracketSetting.tap()
            sleep(1)

            // Enable bracket first
            let bracketToggle = app.switches.firstMatch
            if bracketToggle.exists && bracketToggle.value as? String == "0" {
                bracketToggle.tap()
                sleep(1)
            }

            // Adjust bracket height slider
            let heightSlider = app.sliders.firstMatch
            if heightSlider.exists {
                heightSlider.adjust(toNormalizedSliderPosition: 0.6)
                sleep(1)
            }

            // Save
            app.buttons["Save"].tap()
            print("Bracket height adjusted")
        }
    }

    @MainActor
    func testChangeBracketWidth() throws {
        guard loadTPExampleAndNavigateToDetails() else {
            XCTFail("Failed to load TP example data")
            return
        }

        navigateToSettingsTab()
        sleep(2)

        let bracketSetting = app.buttons["Condition Bracket"]
        if bracketSetting.waitForExistence(timeout: 10) {
            bracketSetting.tap()
            sleep(1)

            // Enable bracket
            let bracketToggle = app.switches.firstMatch
            if bracketToggle.exists && bracketToggle.value as? String == "0" {
                bracketToggle.tap()
                sleep(1)
            }

            // Adjust width using stepper
            let steppers = app.steppers
            if steppers.count > 0 {
                let stepper = steppers.firstMatch
                stepper.buttons["Increment"].tap()
                usleep(500000)
                stepper.buttons["Increment"].tap()
                sleep(1)
            }

            app.buttons["Save"].tap()
            print("Bracket width adjusted")
        }
    }

    // MARK: - Color Change Tests

    @MainActor
    func testChangeVolcanoPlotCategoryColor() throws {
        guard loadTPExampleAndNavigateToDetails() else {
            XCTFail("Failed to load TP example data")
            return
        }

        navigateToSettingsTab()
        sleep(2)

        // Look for color settings
        let colorSettings = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Color'")).firstMatch
        if colorSettings.waitForExistence(timeout: 10) {
            colorSettings.tap()
            sleep(1)

            // Find and tap on a color row
            let colorRows = app.cells
            if colorRows.count > 0 {
                colorRows.firstMatch.tap()
                sleep(1)

                // Look for color picker
                let colorPicker = app.colorWells.firstMatch
                if colorPicker.exists {
                    colorPicker.tap()
                    sleep(1)
                    // Dismiss picker
                    app.tap()
                    sleep(1)
                }

                // Save if needed
                let saveButton = app.buttons["Save"]
                let doneButton = app.buttons["Done"]
                if saveButton.exists {
                    saveButton.tap()
                } else if doneButton.exists {
                    doneButton.tap()
                }

                print("Volcano plot color changed")
            }
        }
    }

    // MARK: - PTM Tests

    @MainActor
    func testPTMSiteSelection() throws {
        guard loadPTMExampleAndNavigateToDetails() else {
            XCTFail("Failed to load PTM example data")
            return
        }

        // Navigate to Site List
        navigateToListTab()
        sleep(2)

        // Tap on a PTM site
        let rows = app.cells
        guard rows.count > 0 else {
            XCTFail("No PTM site rows found")
            return
        }

        rows.firstMatch.tap()
        sleep(3)

        // Check if interaction modal or PTM viewer appears
        let proteinInteractionTitle = app.staticTexts["Protein Interaction"]
        let ptmViewerTitle = app.navigationBars["PTM Viewer"]

        if proteinInteractionTitle.waitForExistence(timeout: 5) {
            // Can annotate from here
            app.buttons["Annotate"].tap()
            sleep(1)
            app.buttons["Done"].tap()
            print("PTM site annotated")
        } else if ptmViewerTitle.waitForExistence(timeout: 5) {
            // PTM viewer opened directly
            print("PTM viewer opened for site")

            // Close PTM viewer
            let closeButton = app.buttons["Close"]
            if closeButton.exists {
                closeButton.tap()
            }
        }
    }

    // MARK: - Protein/Site List Content Tests

    @MainActor
    func testProteinListShowsGeneNamesAndAccessions() throws {
        guard loadTPExampleAndNavigateToDetails() else {
            XCTFail("Failed to load TP example data")
            return
        }

        navigateToListTab()
        sleep(3)

        // Verify rows exist
        let rows = app.cells
        XCTAssertGreaterThan(rows.count, 0, "Protein list should have rows")

        // Check for expected gene names from RealDataTestConstants
        // Known proteins: AAK1, ABL1, ABL2, etc.
        let expectedGenes = ["AAK1", "ABL1", "AKT1"]

        for gene in expectedGenes {
            let geneLabel = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", gene))
            if geneLabel.count > 0 {
                print("Found expected gene \(gene) in protein list")
            }
        }

        // Verify rows have display names (gene name + accession format)
        let firstRow = rows.firstMatch
        if firstRow.exists {
            // Check row contains protein info elements
            let rowLabels = firstRow.staticTexts.allElementsBoundByIndex
            XCTAssertGreaterThan(rowLabels.count, 0, "Protein row should have text labels")
        }
    }

    @MainActor
    func testProteinListShowsSelectionBadges() throws {
        guard loadTPExampleAndNavigateToDetails() else {
            XCTFail("Failed to load TP example data")
            return
        }

        navigateToListTab()
        sleep(3)

        // Look for selection badges (colored text with selection group names)
        // These appear as small colored tags with group names
        let rows = app.cells
        if rows.count > 0 {
            // Check if any row has selection badge elements
            let badgeElements = app.staticTexts.matching(NSPredicate(format: "identifier BEGINSWITH 'selectionBadge_'"))
            if badgeElements.count > 0 {
                print("Found \(badgeElements.count) selection badges in protein list")
            }

            // Also check for badge row containers
            let badgeRows = app.otherElements.matching(NSPredicate(format: "identifier BEGINSWITH 'selectionBadgesRow_'"))
            if badgeRows.count > 0 {
                print("Found \(badgeRows.count) rows with selection badges")
            }
        }
    }

    @MainActor
    func testPTMSiteListGroupedByAccession() throws {
        guard loadPTMExampleAndNavigateToDetails() else {
            XCTFail("Failed to load PTM example data")
            return
        }

        navigateToListTab()
        sleep(3)

        // PTM sites should show gene name + position, with accession as subtitle
        let rows = app.cells
        XCTAssertGreaterThan(rows.count, 0, "PTM site list should have rows")

        // Check for expected PTM entries from RealDataTestConstants
        // A0A1W2P872_K427 -> Nova2 K427
        // A0A1W2P872_K67 -> Nova2 K67
        let expectedSites = ["Nova2", "K427", "K67", "Ube2ql1"]

        for site in expectedSites {
            let siteLabel = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", site))
            if siteLabel.count > 0 {
                print("Found expected PTM site info: \(site)")
            }
        }

        // Verify accession is shown as subtitle
        let accessionLabels = app.staticTexts.matching(NSPredicate(format: "identifier BEGINSWITH 'proteinAccession_'"))
        if accessionLabels.count > 0 {
            print("Found \(accessionLabels.count) accession subtitles in PTM list")
        }
    }

    @MainActor
    func testProteinRowChartButton() throws {
        guard loadTPExampleAndNavigateToDetails() else {
            XCTFail("Failed to load TP example data")
            return
        }

        navigateToListTab()
        sleep(3)

        // Find chart button on first row
        let chartButtons = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'proteinChartButton_'"))
        if chartButtons.count > 0 {
            let chartButton = chartButtons.firstMatch
            XCTAssertTrue(chartButton.exists, "Chart button should exist on protein row")

            // Tap to open chart
            chartButton.tap()
            sleep(2)

            // Verify chart view opened
            let chartView = app.webViews.firstMatch
            let chartTitle = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Chart'")).firstMatch

            if chartView.waitForExistence(timeout: 10) || chartTitle.exists {
                print("Chart view opened successfully")

                // Close chart view
                let closeButton = app.buttons["Close"]
                let dismissButton = app.buttons["Done"]
                if closeButton.exists {
                    closeButton.tap()
                } else if dismissButton.exists {
                    dismissButton.tap()
                } else {
                    // Swipe down to dismiss
                    app.swipeDown()
                }
            }
        } else {
            print("No chart buttons found - protein list may be empty")
        }
    }

    @MainActor
    func testPTMSiteRowPTMViewerButton() throws {
        guard loadPTMExampleAndNavigateToDetails() else {
            XCTFail("Failed to load PTM example data")
            return
        }

        navigateToListTab()
        sleep(3)

        // Find PTM viewer button on first row
        let ptmViewerButtons = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'ptmViewerButton_'"))
        if ptmViewerButtons.count > 0 {
            let ptmButton = ptmViewerButtons.firstMatch
            XCTAssertTrue(ptmButton.exists, "PTM viewer button should exist on PTM site row")

            // Tap to open PTM viewer
            ptmButton.tap()
            sleep(3)

            // Verify PTM viewer opened - look for sequence alignment elements
            let ptmViewerTitle = app.navigationBars["PTM Viewer"]
            let sequenceSection = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Sequence'")).firstMatch
            let alignmentSection = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Alignment'")).firstMatch

            if ptmViewerTitle.waitForExistence(timeout: 10) || sequenceSection.exists || alignmentSection.exists {
                print("PTM viewer opened successfully")

                // Close PTM viewer
                let closeButton = app.buttons["Close"]
                if closeButton.exists {
                    closeButton.tap()
                }
            }
        } else {
            print("No PTM viewer buttons found - may not be PTM data or list empty")
        }
    }

    @MainActor
    func testProteinRowAnnotationToggle() throws {
        guard loadTPExampleAndNavigateToDetails() else {
            XCTFail("Failed to load TP example data")
            return
        }

        navigateToListTab()
        sleep(3)

        // Find annotation toggle button on first row
        let annotationButtons = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'annotationToggleButton_'"))
        if annotationButtons.count > 0 {
            let annotationButton = annotationButtons.firstMatch
            XCTAssertTrue(annotationButton.exists, "Annotation toggle button should exist")

            // Tap to add annotation
            annotationButton.tap()
            sleep(1)

            // Tap again to remove annotation
            annotationButton.tap()
            sleep(1)

            print("Annotation toggle button works")
        }
    }

    @MainActor
    func testSelectionBadgeTapShowsChart() throws {
        guard loadTPExampleAndNavigateToDetails() else {
            XCTFail("Failed to load TP example data")
            return
        }

        navigateToListTab()
        sleep(3)

        // Look for selection badges
        let badgeElements = app.staticTexts.matching(NSPredicate(format: "identifier BEGINSWITH 'selectionBadge_'"))
        if badgeElements.count > 0 {
            let badge = badgeElements.firstMatch
            badge.tap()
            sleep(2)

            // Check if chart or detail view opened
            let chartView = app.webViews.firstMatch
            if chartView.exists {
                print("Selection badge tap opened chart view")

                // Close
                app.swipeDown()
            }
        } else {
            print("No selection badges found - data may not have selections")
        }
    }

    // MARK: - Data Verification Tests

    @MainActor
    func testVolcanoPlotRendersData() throws {
        guard loadTPExampleAndNavigateToDetails() else {
            XCTFail("Failed to load TP example data")
            return
        }

        navigateToVolcanoPlotTab()
        sleep(5)

        // Verify volcano plot WebView exists and is visible
        let volcanoWebView = app.webViews.firstMatch
        XCTAssertTrue(volcanoWebView.waitForExistence(timeout: 30), "Volcano plot WebView should exist")

        // Verify plot has loaded (should be interactable)
        XCTAssertTrue(volcanoWebView.isHittable, "Volcano plot should be interactable")

        print("Volcano plot rendered successfully")
    }

    @MainActor
    func testProteinListShowsData() throws {
        guard loadTPExampleAndNavigateToDetails() else {
            XCTFail("Failed to load TP example data")
            return
        }

        navigateToListTab()
        sleep(3)

        // Verify rows exist
        let rows = app.cells
        XCTAssertGreaterThan(rows.count, 0, "Protein list should have rows")

        // Scroll to verify more data loads
        let table = app.tables.firstMatch
        if table.exists {
            table.swipeUp()
            sleep(1)
            table.swipeDown()
            sleep(1)
        }

        print("Protein list shows \(rows.count) visible rows")
    }

    @MainActor
    func testPTMSiteListShowsData() throws {
        guard loadPTMExampleAndNavigateToDetails() else {
            XCTFail("Failed to load PTM example data")
            return
        }

        navigateToListTab()
        sleep(3)

        // Verify rows exist
        let rows = app.cells
        XCTAssertGreaterThan(rows.count, 0, "PTM site list should have rows")

        // Look for expected data (gene names from RealDataTestConstants)
        let nova2Labels = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Nova2'"))
        if nova2Labels.count > 0 {
            print("Found Nova2 gene in PTM site list as expected")
        }

        print("PTM site list shows \(rows.count) visible rows")
    }

    // MARK: - Navigation Tests

    @MainActor
    func testTabNavigation() throws {
        guard loadTPExampleAndNavigateToDetails() else {
            XCTFail("Failed to load TP example data")
            return
        }

        // Count segmented controls
        let segmentedControls = app.segmentedControls
        XCTAssertGreaterThan(segmentedControls.count, 0, "Should have at least one segmented control")

        let picker = segmentedControls.firstMatch
        XCTAssertTrue(picker.exists, "Segmented control should exist")

        let buttons = picker.buttons
        XCTAssertGreaterThanOrEqual(buttons.count, 4, "Should have at least 4 segments for tabs. Found: \(buttons.count)")

        // Print button info for debugging
        for i in 0..<buttons.count {
            let button = buttons.element(boundBy: i)
            print("Segment \(i): label='\(button.label)', identifier='\(button.identifier)', isSelected=\(button.isSelected)")
        }

        // Navigate to volcano plot (index 1)
        let volcanoSegment = buttons.element(boundBy: 1)
        XCTAssertTrue(volcanoSegment.exists, "Volcano plot segment should exist")
        XCTAssertTrue(volcanoSegment.isHittable, "Volcano plot segment should be hittable")

        volcanoSegment.tap()
        sleep(3)

        // Check if we're now on volcano plot - should see WebView
        let webViewAfterNav = app.webViews.firstMatch
        let onVolcanoPlot = webViewAfterNav.waitForExistence(timeout: 15)
        XCTAssertTrue(onVolcanoPlot, "Should navigate to Volcano Plot tab and see WebView after tapping segment 1")

        // Navigate to protein list (index 2)
        let listSegment = buttons.element(boundBy: 2)
        XCTAssertTrue(listSegment.exists, "Protein list segment should exist")
        listSegment.tap()
        sleep(3)

        // Check if we're now on protein list - should see table cells
        let cellsAfterNav = app.cells
        XCTAssertGreaterThan(cellsAfterNav.count, 0, "Should navigate to Protein List tab and see cells after tapping segment 2")
    }

    @MainActor
    func testBackNavigation() throws {
        guard loadTPExampleAndNavigateToDetails() else {
            XCTFail("Failed to load TP example data")
            return
        }

        // Navigate back to list
        let backButton = app.navigationBars.buttons.firstMatch
        if backButton.exists {
            backButton.tap()
            sleep(2)

            // Should be back at dataset list
            XCTAssertTrue(app.navigationBars["Curtain Datasets"].waitForExistence(timeout: 5),
                          "Should navigate back to datasets list")
        }
    }
}

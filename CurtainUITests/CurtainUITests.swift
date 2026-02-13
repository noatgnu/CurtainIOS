//
//  CurtainUITests.swift
//  CurtainUITests
//
//  Created by Toan Phung on 02/08/2025.
//

import XCTest

final class CurtainUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        // Use in-memory storage for clean test state
        app.launchArguments = ["--uitesting"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }
    
    // MARK: - Tab Navigation Tests
    
    @MainActor
    func testTabNavigation() throws {
        // Test that all main tabs are accessible
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.exists)
        
        // Test Datasets tab
        let datasetsTab = tabBar.buttons["Datasets"]
        XCTAssertTrue(datasetsTab.exists)
        datasetsTab.tap()
        
        // Should show Curtain Datasets navigation title
        XCTAssertTrue(app.navigationBars["Curtain Datasets"].exists)
        
        // Test Filters tab
        let filtersTab = tabBar.buttons["Filters"]
        XCTAssertTrue(filtersTab.exists)
        filtersTab.tap()
        
        // Should show Filter Lists navigation title
        XCTAssertTrue(app.navigationBars["Filter Lists"].exists)
        
        // Test Sites tab
        let sitesTab = tabBar.buttons["Sites"]
        XCTAssertTrue(sitesTab.exists)
        sitesTab.tap()
        
        // Should show API Sites navigation title
        XCTAssertTrue(app.navigationBars["API Sites"].exists)
    }
    
    // MARK: - Empty State and Example Data Tests
    
    @MainActor
    func testEmptyStateAndExampleDataLoading() throws {
        // Navigate to Datasets tab
        app.tabBars.buttons["Datasets"].tap()
        
        // Check for empty state
        let emptyStateText = app.staticTexts["No Curtain Datasets"]
        if emptyStateText.exists {
            // Test Load Example Dataset button
            let loadExampleButton = app.buttons["Load Example Dataset"]
            XCTAssertTrue(loadExampleButton.exists)
            
            // Tap the button (this would normally load example data)
            loadExampleButton.tap()
            
            // Wait for potential loading
            sleep(2)
        }
        
        // Test that we can access the add curtain sheet
        let addButton = app.buttons.matching(identifier: "plus").firstMatch
        if addButton.exists {
            addButton.tap()
            
            // Should show Add Curtain sheet
            XCTAssertTrue(app.navigationBars["Add Curtain"].exists)
            
            // Test that Load Example Dataset button exists in sheet
            let quickActionButton = app.buttons["Load Example Dataset"]
            XCTAssertTrue(quickActionButton.exists)
            
            // Cancel the sheet
            app.buttons["Cancel"].tap()
        }
    }
    
    // MARK: - Add Curtain Sheet Tests
    
    @MainActor
    func testAddCurtainSheetFunctionality() throws {
        // Navigate to Datasets tab
        app.tabBars.buttons["Datasets"].tap()
        
        // Find and tap the add button (could be FAB or toolbar button)
        let addButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Add' OR identifier = 'plus'")).firstMatch
        XCTAssertTrue(addButton.exists)
        addButton.tap()
        
        // Verify Add Curtain sheet is presented
        XCTAssertTrue(app.navigationBars["Add Curtain"].exists)
        
        // Test input method picker
        let inputMethodPicker = app.segmentedControls.firstMatch
        if inputMethodPicker.exists {
            // Test switching between input methods
            inputMethodPicker.buttons["Full URL"].tap()
            
            // Should show URL input field
            let urlField = app.textFields.matching(NSPredicate(format: "placeholderValue CONTAINS 'curtain.proteo.info'")).firstMatch
            XCTAssertTrue(urlField.exists)
            
            // Test entering a proteo URL
            urlField.tap()
            urlField.typeText("https://curtain.proteo.info/#/test-dataset")
            
            // Should show detected text
            let detectedText = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Detected:'")).firstMatch
            XCTAssertTrue(detectedText.exists)
            
            // Switch back to individual fields
            inputMethodPicker.buttons["Individual Fields"].tap()
        }
        
        // Test individual fields input
        let linkIdField = app.textFields["Link ID"]
        if linkIdField.exists {
            linkIdField.tap()
            linkIdField.typeText("test-dataset-123")
        }
        
        let hostnameField = app.textFields["Hostname"]
        if hostnameField.exists {
            hostnameField.tap()
            hostnameField.typeText("https://example.com")
            
            // Test common hostnames menu
            let commonButton = app.buttons["Common"]
            if commonButton.exists {
                commonButton.tap()
                // Menu should show predefined hosts
                XCTAssertTrue(app.menus.firstMatch.exists)
                // Tap outside to close menu
                app.tap()
            }
        }
        
        // Test Load Example Dataset in Quick Actions
        let exampleButton = app.buttons["Load Example Dataset"]
        XCTAssertTrue(exampleButton.exists)
        
        // Cancel the sheet
        app.buttons["Cancel"].tap()
        XCTAssertFalse(app.navigationBars["Add Curtain"].exists)
    }
    
    // MARK: - Site Settings Tests
    
    @MainActor
    func testSiteSettingsManagement() throws {
        // Navigate to Sites tab
        app.tabBars.buttons["Sites"].tap()
        
        // Should show API Sites navigation
        XCTAssertTrue(app.navigationBars["API Sites"].exists)
        
        // Test Add Site button
        let addSiteButton = app.buttons["Add Site"]
        XCTAssertTrue(addSiteButton.exists)
        addSiteButton.tap()
        
        // Should show Add API Site sheet
        XCTAssertTrue(app.navigationBars["Add API Site"].exists)
        
        // Test hostname field with common hostnames
        let hostnameField = app.textFields.matching(NSPredicate(format: "placeholderValue CONTAINS 'curtain-web.org'")).firstMatch
        XCTAssertTrue(hostnameField.exists)
        
        // Test common hostnames menu
        let commonButton = app.buttons["Common"]
        if commonButton.exists {
            commonButton.tap()
            // Should show predefined hostnames
            XCTAssertTrue(app.menus.firstMatch.exists)
            app.tap() // Close menu
        }
        
        // Test authentication toggle
        let authToggle = app.switches["Requires API Key"]
        if authToggle.exists {
            authToggle.tap()
            // Should show API key field
            let apiKeyField = app.secureTextFields["API Key"]
            XCTAssertTrue(apiKeyField.exists)
        }
        
        // Cancel the sheet
        app.buttons["Cancel"].tap()
        XCTAssertFalse(app.navigationBars["Add API Site"].exists)
    }
    
    // MARK: - Search and Filter Tests
    
    @MainActor
    func testSearchFunctionality() throws {
        // Navigate to Datasets tab
        app.tabBars.buttons["Datasets"].tap()
        
        // Look for search field
        let searchField = app.textFields.matching(NSPredicate(format: "placeholderValue CONTAINS 'Search'")).firstMatch
        if searchField.exists {
            searchField.tap()
            searchField.typeText("example")
            
            // Test that search is functional (keyboard should be visible)
            XCTAssertTrue(app.keyboards.firstMatch.exists)
            
            // Clear search
            searchField.clearText()
        }
        
        // Test Filters tab search
        app.tabBars.buttons["Filters"].tap()
        
        let filterSearchField = app.textFields.matching(NSPredicate(format: "placeholderValue CONTAINS 'Search'")).firstMatch
        if filterSearchField.exists {
            filterSearchField.tap()
            filterSearchField.typeText("proteins")
            XCTAssertTrue(app.keyboards.firstMatch.exists)
        }
    }
    
    // MARK: - Performance Tests
    
    @MainActor
    func testLaunchPerformance() throws {
        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 7.0, *) {
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                XCUIApplication().launch()
            }
        }
    }
    
    @MainActor
    func testTabSwitchingPerformance() throws {
        measure {
            app.tabBars.buttons["Datasets"].tap()
            app.tabBars.buttons["Filters"].tap()
            app.tabBars.buttons["Sites"].tap()
            app.tabBars.buttons["Datasets"].tap()
        }
    }
    
    // MARK: - PTM and TP Data Tests

    @MainActor
    func testPTMExampleShowsSiteListTabWithGeneNames() throws {
        // Navigate to Datasets tab
        let datasetsTab = app.tabBars.buttons["Datasets"]
        XCTAssertTrue(datasetsTab.waitForExistence(timeout: 10), "Datasets tab should exist")
        datasetsTab.tap()
        sleep(1)

        // Find PTM button by label text
        let ptmButton = app.buttons["PTM Example"]

        if ptmButton.waitForExistence(timeout: 5) {
            ptmButton.tap()
        } else {
            XCTFail("PTM Example button not found")
            return
        }

        // Wait for the entry to be added to the list
        sleep(3)

        // Find and tap on the newly added PTM curtain entry
        // Look for any cell or button in the list
        let listItems = app.cells
        if listItems.count > 0 {
            // Tap the first cell (the PTM entry we just added)
            listItems.firstMatch.tap()
        } else {
            // Try to find by PTM badge or description
            let ptmEntry = app.staticTexts["PTM"].firstMatch
            if ptmEntry.waitForExistence(timeout: 5) {
                ptmEntry.tap()
            } else {
                XCTFail("Could not find PTM entry in list")
                return
            }
        }

        // Handle download confirmation alert
        let downloadAlert = app.alerts["Download Data"]
        if downloadAlert.waitForExistence(timeout: 5) {
            downloadAlert.buttons["Download"].tap()
        }

        // Wait for download to complete and details view to load
        // Check for Site List text in tab or navigation
        let siteListText = app.staticTexts["Site List"]
        let proteinListText = app.staticTexts["Protein List"]

        // Wait up to 120 seconds for download and load
        var foundSiteList = false
        var foundProteinList = false

        for _ in 0..<40 {
            if siteListText.exists {
                foundSiteList = true
                break
            }
            if proteinListText.exists {
                foundProteinList = true
                break
            }
            sleep(3)
        }

        XCTAssertTrue(foundSiteList, "PTM data should show 'Site List' tab")
        XCTAssertFalse(foundProteinList, "PTM data should NOT show 'Protein List' tab")
    }

    @MainActor
    func testTPExampleShowsProteinListTabWithGeneNames() throws {
        // Navigate to Datasets tab
        let datasetsTab = app.tabBars.buttons["Datasets"]
        XCTAssertTrue(datasetsTab.waitForExistence(timeout: 10), "Datasets tab should exist")
        datasetsTab.tap()
        sleep(1)

        // Find TP button by label text
        let tpButton = app.buttons["TP Example"]

        if tpButton.waitForExistence(timeout: 5) {
            tpButton.tap()
        } else {
            XCTFail("TP Example button not found")
            return
        }

        // Wait for the entry to be added to the list
        sleep(3)

        // Find and tap on the newly added TP curtain entry
        let listItems = app.cells
        if listItems.count > 0 {
            listItems.firstMatch.tap()
        } else {
            // Try to find by TP badge or description
            let tpEntry = app.staticTexts["TP"].firstMatch
            if tpEntry.waitForExistence(timeout: 5) {
                tpEntry.tap()
            } else {
                XCTFail("Could not find TP entry in list")
                return
            }
        }

        // Handle download confirmation alert
        let downloadAlert = app.alerts["Download Data"]
        if downloadAlert.waitForExistence(timeout: 5) {
            downloadAlert.buttons["Download"].tap()
        }

        // Wait for download to complete and details view to load
        let proteinListText = app.staticTexts["Protein List"]
        let siteListText = app.staticTexts["Site List"]

        // Wait up to 120 seconds for download and load
        var foundProteinList = false
        var foundSiteList = false

        for _ in 0..<40 {
            if proteinListText.exists {
                foundProteinList = true
                break
            }
            if siteListText.exists {
                foundSiteList = true
                break
            }
            sleep(3)
        }

        XCTAssertTrue(foundProteinList, "TP data should show 'Protein List' tab")
        XCTAssertFalse(foundSiteList, "TP data should NOT show 'Site List' tab")
    }

    // MARK: - Edge Cases and Error Handling

    @MainActor
    func testInvalidURLInput() throws {
        // Navigate to Datasets tab and open Add Curtain
        app.tabBars.buttons["Datasets"].tap()
        
        let addButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Add' OR identifier = 'plus'")).firstMatch
        if addButton.exists {
            addButton.tap()
            
            // Switch to Full URL method
            let inputMethodPicker = app.segmentedControls.firstMatch
            if inputMethodPicker.exists {
                inputMethodPicker.buttons["Full URL"].tap()
                
                // Enter invalid URL
                let urlField = app.textFields.matching(NSPredicate(format: "placeholderValue CONTAINS 'curtain.proteo.info'")).firstMatch
                if urlField.exists {
                    urlField.tap()
                    urlField.typeText("invalid-url-format")
                    
                    // Add button should still be enabled (validation happens on submit)
                    let addSubmitButton = app.buttons["Add"]
                    XCTAssertTrue(addSubmitButton.exists)
                }
            }
            
            app.buttons["Cancel"].tap()
        }
    }

    // MARK: - Volcano Plot Interaction Tests

    @MainActor
    func testVolcanoPlotInteractions() throws {
        // Load example data first
        app.tabBars.buttons["Datasets"].tap()

        let tpButton = app.buttons["TP Example"]
        if tpButton.waitForExistence(timeout: 5) {
            tpButton.tap()
        } else {
            // Skip if no example button
            return
        }

        sleep(3)

        // Tap on the curtain entry
        let listItems = app.cells
        if listItems.count > 0 {
            listItems.firstMatch.tap()
        } else {
            return
        }

        // Handle download if needed
        let downloadAlert = app.alerts["Download Data"]
        if downloadAlert.waitForExistence(timeout: 5) {
            downloadAlert.buttons["Download"].tap()
        }

        // Wait for data to load
        sleep(10)

        // Look for volcano plot elements
        let volcanoPlot = app.otherElements["VolcanoPlot"]
        if volcanoPlot.waitForExistence(timeout: 30) {
            print("Volcano plot found")

            // Test tap on plot (should select a point)
            volcanoPlot.tap()

            // Test pinch to zoom (if supported)
            volcanoPlot.pinch(withScale: 2.0, velocity: 1.0)
            sleep(1)
            volcanoPlot.pinch(withScale: 0.5, velocity: 1.0)
        }

        // Look for plot controls
        let resetZoomButton = app.buttons["Reset Zoom"]
        if resetZoomButton.exists {
            resetZoomButton.tap()
        }
    }

    @MainActor
    func testDataTableInteractions() throws {
        // Load example data
        app.tabBars.buttons["Datasets"].tap()

        let tpButton = app.buttons["TP Example"]
        if tpButton.waitForExistence(timeout: 5) {
            tpButton.tap()
        } else {
            return
        }

        sleep(3)

        let listItems = app.cells
        if listItems.count > 0 {
            listItems.firstMatch.tap()
        } else {
            return
        }

        // Handle download
        let downloadAlert = app.alerts["Download Data"]
        if downloadAlert.waitForExistence(timeout: 5) {
            downloadAlert.buttons["Download"].tap()
        }

        // Wait for load
        sleep(15)

        // Look for Protein List or Site List tab
        let proteinListTab = app.buttons["Protein List"]
        let siteListTab = app.buttons["Site List"]

        if proteinListTab.waitForExistence(timeout: 30) {
            proteinListTab.tap()
            sleep(2)

            // Test scrolling in data table
            let table = app.tables.firstMatch
            if table.exists {
                table.swipeUp()
                sleep(1)
                table.swipeDown()
            }

            // Test tapping on a row
            let rows = app.cells
            if rows.count > 0 {
                rows.firstMatch.tap()
                sleep(1)
            }
        } else if siteListTab.waitForExistence(timeout: 30) {
            siteListTab.tap()
            sleep(2)
        }
    }

    @MainActor
    func testBarChartInteractions() throws {
        // Load example data
        app.tabBars.buttons["Datasets"].tap()

        let tpButton = app.buttons["TP Example"]
        if tpButton.waitForExistence(timeout: 5) {
            tpButton.tap()
        } else {
            return
        }

        sleep(3)

        let listItems = app.cells
        if listItems.count > 0 {
            listItems.firstMatch.tap()
        } else {
            return
        }

        // Handle download
        let downloadAlert = app.alerts["Download Data"]
        if downloadAlert.waitForExistence(timeout: 5) {
            downloadAlert.buttons["Download"].tap()
        }

        // Wait for load
        sleep(15)

        // Go to protein list and select a protein to see bar chart
        let proteinListTab = app.buttons["Protein List"]
        if proteinListTab.waitForExistence(timeout: 30) {
            proteinListTab.tap()
            sleep(2)

            // Tap on first protein
            let rows = app.cells
            if rows.count > 0 {
                rows.firstMatch.tap()
                sleep(2)

                // Look for bar chart
                let barChart = app.otherElements["BarChart"]
                if barChart.exists {
                    print("Bar chart found")
                    barChart.tap()
                }
            }
        }
    }

    @MainActor
    func testPTMViewerInteractions() throws {
        // Load PTM example data
        app.tabBars.buttons["Datasets"].tap()

        let ptmButton = app.buttons["PTM Example"]
        if ptmButton.waitForExistence(timeout: 5) {
            ptmButton.tap()
        } else {
            return
        }

        sleep(3)

        let listItems = app.cells
        if listItems.count > 0 {
            listItems.firstMatch.tap()
        } else {
            return
        }

        // Handle download
        let downloadAlert = app.alerts["Download Data"]
        if downloadAlert.waitForExistence(timeout: 5) {
            downloadAlert.buttons["Download"].tap()
        }

        // Wait for load
        sleep(20)

        // Go to Site List and tap on a site
        let siteListTab = app.buttons["Site List"]
        if siteListTab.waitForExistence(timeout: 60) {
            siteListTab.tap()
            sleep(2)

            // Tap on a site to open PTM viewer
            let rows = app.cells
            if rows.count > 0 {
                rows.firstMatch.tap()
                sleep(3)

                // Look for PTM viewer elements
                let ptmViewer = app.otherElements["PTMViewer"]
                let sequenceView = app.scrollViews["SequenceAlignment"]

                if ptmViewer.exists || sequenceView.exists {
                    print("PTM viewer found")

                    // Test scrolling in sequence view
                    if sequenceView.exists {
                        sequenceView.swipeLeft()
                        sleep(1)
                        sequenceView.swipeRight()
                    }
                }

                // Close PTM viewer if modal
                let closeButton = app.buttons["Close"]
                if closeButton.exists {
                    closeButton.tap()
                }
            }
        }
    }

    @MainActor
    func testExportFunctionality() throws {
        // Load example data
        app.tabBars.buttons["Datasets"].tap()

        let tpButton = app.buttons["TP Example"]
        if tpButton.waitForExistence(timeout: 5) {
            tpButton.tap()
        } else {
            return
        }

        sleep(3)

        let listItems = app.cells
        if listItems.count > 0 {
            listItems.firstMatch.tap()
        } else {
            return
        }

        // Handle download
        let downloadAlert = app.alerts["Download Data"]
        if downloadAlert.waitForExistence(timeout: 5) {
            downloadAlert.buttons["Download"].tap()
        }

        // Wait for load
        sleep(15)

        // Look for export button
        let exportButton = app.buttons["Export"]
        let shareButton = app.buttons["Share"]
        let moreButton = app.buttons["More"]

        if exportButton.waitForExistence(timeout: 30) {
            exportButton.tap()
            sleep(1)

            // Should show export options
            let exportPlotButton = app.buttons["Export Plot"]
            let exportDataButton = app.buttons["Export Data"]

            if exportPlotButton.exists {
                print("Export options available")
            }

            // Dismiss menu
            app.tap()
        } else if shareButton.exists {
            shareButton.tap()
            sleep(1)
            app.tap()
        } else if moreButton.exists {
            moreButton.tap()
            sleep(1)
            app.tap()
        }
    }

    @MainActor
    func testComparisonSwitching() throws {
        // Load example data
        app.tabBars.buttons["Datasets"].tap()

        let tpButton = app.buttons["TP Example"]
        if tpButton.waitForExistence(timeout: 5) {
            tpButton.tap()
        } else {
            return
        }

        sleep(3)

        let listItems = app.cells
        if listItems.count > 0 {
            listItems.firstMatch.tap()
        } else {
            return
        }

        // Handle download
        let downloadAlert = app.alerts["Download Data"]
        if downloadAlert.waitForExistence(timeout: 5) {
            downloadAlert.buttons["Download"].tap()
        }

        // Wait for load
        sleep(15)

        // Look for comparison picker/selector
        let comparisonPicker = app.buttons["Comparison"]
        let comparisonSegment = app.segmentedControls.firstMatch

        if comparisonPicker.waitForExistence(timeout: 30) {
            comparisonPicker.tap()
            sleep(1)

            // Should show comparison options
            let comparisonMenu = app.menus.firstMatch
            if comparisonMenu.exists {
                // Select first option
                let options = comparisonMenu.buttons
                if options.count > 0 {
                    options.firstMatch.tap()
                    sleep(2)
                }
            } else {
                app.tap() // Dismiss
            }
        } else if comparisonSegment.exists {
            // Try switching between segments
            let buttons = comparisonSegment.buttons
            if buttons.count > 1 {
                buttons.element(boundBy: 1).tap()
                sleep(2)
                buttons.element(boundBy: 0).tap()
                sleep(2)
            }
        }
    }

    @MainActor
    func testFilterListManagement() throws {
        // Navigate to Filters tab
        app.tabBars.buttons["Filters"].tap()
        sleep(1)

        // Should show Filter Lists
        XCTAssertTrue(app.navigationBars["Filter Lists"].exists)

        // Test creating a new filter list
        let addButton = app.buttons["Add Filter List"]
        if addButton.exists {
            addButton.tap()
            sleep(1)

            // Fill in filter list name
            let nameField = app.textFields["Name"]
            if nameField.exists {
                nameField.tap()
                nameField.typeText("Test Filter")
            }

            // Add some proteins
            let proteinsField = app.textFields["Proteins"]
            if proteinsField.exists {
                proteinsField.tap()
                proteinsField.typeText("PROTEIN1,PROTEIN2,PROTEIN3")
            }

            // Cancel to not actually create
            let cancelButton = app.buttons["Cancel"]
            if cancelButton.exists {
                cancelButton.tap()
            }
        }

        // Test search in filter lists
        let searchField = app.searchFields.firstMatch
        if searchField.exists {
            searchField.tap()
            searchField.typeText("test")
            sleep(1)
            searchField.clearText()
        }
    }

    @MainActor
    func testSettingsAndCutoffAdjustment() throws {
        // Load example data
        app.tabBars.buttons["Datasets"].tap()

        let tpButton = app.buttons["TP Example"]
        if tpButton.waitForExistence(timeout: 5) {
            tpButton.tap()
        } else {
            return
        }

        sleep(3)

        let listItems = app.cells
        if listItems.count > 0 {
            listItems.firstMatch.tap()
        } else {
            return
        }

        // Handle download
        let downloadAlert = app.alerts["Download Data"]
        if downloadAlert.waitForExistence(timeout: 5) {
            downloadAlert.buttons["Download"].tap()
        }

        // Wait for load
        sleep(15)

        // Look for settings/cutoff controls
        let settingsButton = app.buttons["Settings"]
        let cutoffButton = app.buttons["Cutoffs"]

        if settingsButton.waitForExistence(timeout: 30) {
            settingsButton.tap()
            sleep(1)

            // Look for p-value and fold change sliders
            let pValueSlider = app.sliders["P-Value Cutoff"]
            let fcSlider = app.sliders["Fold Change Cutoff"]

            if pValueSlider.exists {
                pValueSlider.adjust(toNormalizedSliderPosition: 0.3)
                sleep(1)
            }

            if fcSlider.exists {
                fcSlider.adjust(toNormalizedSliderPosition: 0.7)
                sleep(1)
            }

            // Close settings
            let doneButton = app.buttons["Done"]
            if doneButton.exists {
                doneButton.tap()
            } else {
                app.tap()
            }
        } else if cutoffButton.exists {
            cutoffButton.tap()
            sleep(1)
            app.tap()
        }
    }

    @MainActor
    func testNavigationBackAndForth() throws {
        // Test navigation flow
        app.tabBars.buttons["Datasets"].tap()
        sleep(1)

        // Load example
        let tpButton = app.buttons["TP Example"]
        if tpButton.waitForExistence(timeout: 5) {
            tpButton.tap()
        }

        sleep(3)

        // Enter details
        let listItems = app.cells
        if listItems.count > 0 {
            listItems.firstMatch.tap()
        }

        // Handle download
        let downloadAlert = app.alerts["Download Data"]
        if downloadAlert.waitForExistence(timeout: 5) {
            downloadAlert.buttons["Download"].tap()
        }

        sleep(10)

        // Navigate back
        let backButton = app.navigationBars.buttons.firstMatch
        if backButton.exists && backButton.label != "Curtain Datasets" {
            backButton.tap()
            sleep(1)

            // Should be back at list
            XCTAssertTrue(app.navigationBars["Curtain Datasets"].waitForExistence(timeout: 5))
        }

        // Navigate to other tabs and back
        app.tabBars.buttons["Filters"].tap()
        sleep(1)
        XCTAssertTrue(app.navigationBars["Filter Lists"].exists)

        app.tabBars.buttons["Sites"].tap()
        sleep(1)
        XCTAssertTrue(app.navigationBars["API Sites"].exists)

        app.tabBars.buttons["Datasets"].tap()
        sleep(1)
        XCTAssertTrue(app.navigationBars["Curtain Datasets"].exists)
    }

    @MainActor
    func testAccessibilityIdentifiers() throws {
        // Verify accessibility identifiers exist for main UI elements
        app.tabBars.buttons["Datasets"].tap()
        sleep(1)

        // Check for main navigation elements
        XCTAssertTrue(app.tabBars.firstMatch.exists, "Tab bar should be accessible")
        XCTAssertTrue(app.navigationBars.firstMatch.exists, "Navigation bar should be accessible")

        // Check for add button accessibility
        let addButton = app.buttons.matching(NSPredicate(format: "identifier = 'plus' OR label CONTAINS 'Add'")).firstMatch
        XCTAssertTrue(addButton.exists, "Add button should be accessible")
    }
}

// MARK: - XCUIElement Extensions for Testing

extension XCUIElement {
    func clearText() {
        guard let stringValue = self.value as? String else {
            return
        }
        
        let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: stringValue.count)
        self.typeText(deleteString)
    }
}

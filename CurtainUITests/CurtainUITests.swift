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

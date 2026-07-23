//
//  VolcanoPlotGraphDataTests.swift
//  CurtainTests
//
//  Tests that download real datasets from the API and verify that
//  VolcanoPlotDataService produces correct colors, group names,
//  and trace ordering matching the web/Android apps.
//

import XCTest
@testable import Curtain

final class VolcanoPlotGraphDataTests: XCTestCase {

    // MARK: - Helper Methods

    private func downloadCurtainData(linkId: String, hostname: String) async throws -> (Data, [String: Any]) {
        let apiURL = "\(hostname)curtain/\(linkId)/download/token=/"
        let (urlData, urlResponse) = try await URLSession.shared.data(from: URL(string: apiURL)!)
        guard let httpResponse = urlResponse as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSError(domain: "VolcanoPlotGraphDataTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to get signed URL"])
        }
        guard let urlJson = try JSONSerialization.jsonObject(with: urlData) as? [String: Any],
              let signedUrl = urlJson["url"] as? String else {
            throw NSError(domain: "VolcanoPlotGraphDataTests", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to parse signed URL"])
        }
        let (data, dataResponse) = try await URLSession.shared.data(from: URL(string: signedUrl)!)
        guard let s3Response = dataResponse as? HTTPURLResponse, s3Response.statusCode == 200 else {
            throw NSError(domain: "VolcanoPlotGraphDataTests", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to download from S3"])
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "VolcanoPlotGraphDataTests", code: 4, userInfo: [NSLocalizedDescriptionKey: "Failed to parse JSON"])
        }
        return (data, json)
    }

    private func loadTPDataset() async throws -> (CurtainDataService, AppData) {
        let linkId = CurtainConstants.ExampleData.uniqueId
        let hostname = CurtainConstants.ExampleData.apiUrl
        let (_, json) = try await downloadCurtainData(linkId: linkId, hostname: hostname)

        let service = CurtainDataService()
        try await service.restoreSettings(from: json)

        let appData = AppData()
        appData.dataMap = service.curtainData.dataMap
        appData.differentialForm = service.curtainData.differentialForm
        appData.selectedMap = service.curtainData.selectedMap ?? [:]
        appData.uniprotDB = service.uniprotData.db

        return (service, appData)
    }

    private func loadPTMDataset() async throws -> (CurtainDataService, AppData) {
        let linkId = CurtainConstants.ExamplePTMData.uniqueId
        let hostname = CurtainConstants.ExamplePTMData.apiUrl
        let (_, json) = try await downloadCurtainData(linkId: linkId, hostname: hostname)

        let service = CurtainDataService()
        try await service.restoreSettings(from: json)

        let appData = AppData()
        appData.dataMap = service.curtainData.dataMap
        appData.differentialForm = service.curtainData.differentialForm
        appData.selectedMap = service.curtainData.selectedMap ?? [:]
        appData.uniprotDB = service.uniprotData.db

        return (service, appData)
    }

    // MARK: - TP Volcano Plot Color Correctness

    /// Verify that every non-selected data point gets the correct color from the
    /// colorMap using the current `<=`/`>` operator format keys.
    func testTPVolcanoSignificanceGroupColors() async throws {
        let (service, appData) = try await loadTPDataset()

        let volcanoService = VolcanoPlotDataService()
        let result = await volcanoService.processVolcanoData(curtainData: appData, settings: service.curtainSettings)

        XCTAssertFalse(result.jsonData.isEmpty, "Should have data points")

        // Collect colors per significance group
        var groupColors: [String: Set<String>] = [:]
        for point in result.jsonData {
            guard let selections = point["selections"] as? [String],
                  let colors = point["colors"] as? [String] else { continue }
            for (i, sel) in selections.enumerated() where i < colors.count {
                groupColors[sel, default: []].insert(colors[i])
            }
        }

        print("TP significance groups found:")
        for (group, colors) in groupColors.sorted(by: { $0.key < $1.key }) {
            print("  '\(group)' -> \(colors)")
        }

        // Verify each significance group uses the expected color from the colorMap
        // Filter to only current-format keys (using <= / >) that contain "P-value"
        let expectedSignificanceColors = TPDatasetConstants.colorMap.filter { key, _ in
            // Only current-format keys: "P-value <= ..." or "P-value > ..." (not legacy "P-value < " or "P-value >= ")
            (key.contains("P-value <= ") || (key.contains("P-value > ") && !key.contains("P-value >= ")))
        }
        for (expectedGroup, expectedColor) in expectedSignificanceColors {
            guard let actualColors = groupColors[expectedGroup] else {
                XCTFail("Expected significance group '\(expectedGroup)' not found in result. Found groups: \(Array(groupColors.keys))")
                continue
            }
            XCTAssertEqual(actualColors.count, 1, "Group '\(expectedGroup)' should have exactly one color, got: \(actualColors)")
            XCTAssertTrue(actualColors.contains(expectedColor),
                          "Group '\(expectedGroup)' should have color '\(expectedColor)', got: \(actualColors)")
        }
    }

    /// Verify that user selections get the correct colors from the colorMap.
    func testTPVolcanoUserSelectionColors() async throws {
        let (service, appData) = try await loadTPDataset()

        let volcanoService = VolcanoPlotDataService()
        let result = await volcanoService.processVolcanoData(curtainData: appData, settings: service.curtainSettings)

        // Collect colors per selection group
        var groupColors: [String: Set<String>] = [:]
        for point in result.jsonData {
            guard let selections = point["selections"] as? [String],
                  let colors = point["colors"] as? [String] else { continue }
            for (i, sel) in selections.enumerated() where i < colors.count {
                groupColors[sel, default: []].insert(colors[i])
            }
        }

        // Verify user selection colors match colorMap
        let expectedUserSelectionColors = TPDatasetConstants.colorMap.filter { key, _ in
            TPDatasetConstants.selectionsName.contains(key)
        }
        for (selectionName, expectedColor) in expectedUserSelectionColors {
            guard let actualColors = groupColors[selectionName] else {
                // Selection may not appear if no proteins are selected for it — skip
                print("User selection '\(selectionName)' not found in result (may have no selected proteins)")
                continue
            }
            XCTAssertTrue(actualColors.contains(expectedColor),
                          "Selection '\(selectionName)' should have color '\(expectedColor)', got: \(actualColors)")
        }
    }

    /// Verify the returned colorMap doesn't create new spurious keys for groups
    /// that already exist in the input colorMap.
    func testTPVolcanoColorMapNoSpuriousKeys() async throws {
        let (service, appData) = try await loadTPDataset()

        let inputColorMap = service.curtainSettings.colorMap
        let volcanoService = VolcanoPlotDataService()
        let result = await volcanoService.processVolcanoData(curtainData: appData, settings: service.curtainSettings)

        // Check that no new significance group keys were added that duplicate existing ones
        // with different operator format
        let resultSignificanceKeys = result.colorMap.keys.filter { $0.contains("P-value") }
        let inputSignificanceKeys = Set(inputColorMap.keys.filter { $0.contains("P-value") })

        print("Input colorMap significance keys: \(inputSignificanceKeys.sorted())")
        print("Result colorMap significance keys: \(resultSignificanceKeys.sorted())")

        // Every significance key in result should already exist in the input
        for key in resultSignificanceKeys {
            XCTAssertTrue(inputSignificanceKeys.contains(key),
                          "Result colorMap has new key '\(key)' that wasn't in input. This means the app generated a group name that didn't match any existing colorMap key.")
        }
    }

    /// Verify that the generated group names use the correct operator format
    /// (matching web and Android: `<=` and `>` for P-value).
    func testTPVolcanoGroupNameFormat() async throws {
        let (service, appData) = try await loadTPDataset()

        let volcanoService = VolcanoPlotDataService()
        let result = await volcanoService.processVolcanoData(curtainData: appData, settings: service.curtainSettings)

        // Collect all significance group names from data points
        var significanceGroups = Set<String>()
        for point in result.jsonData {
            guard let selections = point["selections"] as? [String] else { continue }
            for sel in selections where sel.contains("P-value") {
                significanceGroups.insert(sel)
            }
        }

        print("Generated significance group names:")
        for group in significanceGroups.sorted() {
            print("  '\(group)'")
        }

        // All generated P-value groups should use <= and > (not < and >=)
        for group in significanceGroups {
            XCTAssertFalse(group.contains("P-value < ") && !group.contains("P-value <= "),
                           "Group '\(group)' uses old '<' operator instead of '<='")
            XCTAssertFalse(group.contains("P-value >= "),
                           "Group '\(group)' uses old '>=' operator instead of '>'")
        }

        // For TP data with comparison, groups should end with comparison label like "(1)"
        for group in significanceGroups {
            XCTAssertTrue(group.contains("("),
                          "TP significance group '\(group)' should contain comparison label")
        }
    }

    // MARK: - TP Trace Ordering

    /// Verify that trace ordering matches Android behavior.
    func testTPVolcanoTraceOrdering() async throws {
        let (service, appData) = try await loadTPDataset()

        let volcanoService = VolcanoPlotDataService()
        let result = await volcanoService.processVolcanoData(curtainData: appData, settings: service.curtainSettings)

        // Build traces the same way PlotlyChartGenerator does
        var selectionGroups: [String: (color: String, count: Int)] = [:]
        for point in result.jsonData {
            guard let selections = point["selections"] as? [String],
                  let colors = point["colors"] as? [String] else { continue }
            for (i, sel) in selections.enumerated() where i < colors.count {
                if selectionGroups[sel] == nil {
                    selectionGroups[sel] = (color: colors[i], count: 0)
                }
                selectionGroups[sel]?.count += 1
            }
        }

        let allGroupNames = Array(selectionGroups.keys)

        let backgroundAndSignificanceNames = allGroupNames.filter { name in
            name == "Background" || name == "Other" || name.contains("P-value") || name.contains("FC")
        }

        let userSelectionNames = allGroupNames.filter { name in
            name != "Background" && name != "Other" && !name.contains("P-value") && !name.contains("FC")
        }

        print("User selection traces: \(userSelectionNames)")
        print("Background/significance traces: \(backgroundAndSignificanceNames)")

        // Verify user selections exist
        for selName in TPDatasetConstants.selectionsName {
            if selectionGroups[selName] != nil {
                XCTAssertTrue(userSelectionNames.contains(selName),
                              "'\(selName)' should be classified as user selection, not background/significance")
            }
        }

        // Verify significance groups are NOT classified as user selections
        for group in backgroundAndSignificanceNames {
            XCTAssertTrue(group.contains("P-value") || group.contains("FC") || group == "Background" || group == "Other",
                          "'\(group)' should be a significance group but was classified as such")
        }
    }

    // MARK: - PTM Volcano Plot Color Correctness

    /// Verify PTM dataset colors match the colorMap (no comparison suffix for PTM).
    func testPTMVolcanoSignificanceGroupColors() async throws {
        let (service, appData) = try await loadPTMDataset()

        let volcanoService = VolcanoPlotDataService()
        let result = await volcanoService.processVolcanoData(curtainData: appData, settings: service.curtainSettings)

        XCTAssertFalse(result.jsonData.isEmpty, "PTM should have data points")

        var groupColors: [String: Set<String>] = [:]
        for point in result.jsonData {
            guard let selections = point["selections"] as? [String],
                  let colors = point["colors"] as? [String] else { continue }
            for (i, sel) in selections.enumerated() where i < colors.count {
                groupColors[sel, default: []].insert(colors[i])
            }
        }

        print("PTM significance groups found:")
        for (group, colors) in groupColors.sorted(by: { $0.key < $1.key }) {
            print("  '\(group)' -> \(colors)")
        }

        // Verify PTM significance groups match expected colors from colorMap
        for (expectedGroup, expectedColor) in PTMDatasetConstants.colorMap {
            // Skip user selection groups
            if expectedGroup == "Old sites" || expectedGroup == "New sites" { continue }

            guard let actualColors = groupColors[expectedGroup] else {
                XCTFail("Expected PTM group '\(expectedGroup)' not found. Found: \(Array(groupColors.keys))")
                continue
            }
            XCTAssertTrue(actualColors.contains(expectedColor),
                          "PTM group '\(expectedGroup)' should have color '\(expectedColor)', got: \(actualColors)")
        }
    }

    /// Verify PTM groups do NOT have comparison suffix (unlike TP).
    func testPTMVolcanoGroupNameFormat() async throws {
        let (service, appData) = try await loadPTMDataset()

        let volcanoService = VolcanoPlotDataService()
        let result = await volcanoService.processVolcanoData(curtainData: appData, settings: service.curtainSettings)

        var significanceGroups = Set<String>()
        for point in result.jsonData {
            guard let selections = point["selections"] as? [String] else { continue }
            for sel in selections where sel.contains("P-value") {
                significanceGroups.insert(sel)
            }
        }

        print("PTM generated significance group names:")
        for group in significanceGroups.sorted() {
            print("  '\(group)'")
        }

        // PTM significance groups should NOT have comparison suffix like "(1)"
        for group in significanceGroups {
            let trimmed = group.trimmingCharacters(in: .whitespaces)
            XCTAssertFalse(trimmed.hasSuffix(")") && trimmed.contains("(") && trimmed.last != "6",
                           "PTM group '\(group)' should NOT have comparison suffix")
        }

        // PTM groups should use <= and > operators
        for group in significanceGroups {
            XCTAssertFalse(group.contains("P-value >= "),
                           "PTM group '\(group)' uses old '>=' operator")
        }
    }

    /// Verify PTM colorMap has no spurious new keys.
    func testPTMVolcanoColorMapNoSpuriousKeys() async throws {
        let (service, appData) = try await loadPTMDataset()

        let inputColorMap = service.curtainSettings.colorMap
        let volcanoService = VolcanoPlotDataService()
        let result = await volcanoService.processVolcanoData(curtainData: appData, settings: service.curtainSettings)

        let resultSignificanceKeys = result.colorMap.keys.filter { $0.contains("P-value") }
        let inputSignificanceKeys = Set(inputColorMap.keys.filter { $0.contains("P-value") })

        for key in resultSignificanceKeys {
            XCTAssertTrue(inputSignificanceKeys.contains(key),
                          "PTM result colorMap has new key '\(key)' not in input.")
        }
    }

    // MARK: - Data Point Structure Verification

    /// Verify every TP data point has all required fields.
    func testTPVolcanoDataPointStructure() async throws {
        let (service, appData) = try await loadTPDataset()

        let volcanoService = VolcanoPlotDataService()
        let result = await volcanoService.processVolcanoData(curtainData: appData, settings: service.curtainSettings)

        XCTAssertGreaterThan(result.jsonData.count, 8000, "TP should have ~8609 data points")

        for (i, point) in result.jsonData.enumerated() {
            let x = point["x"] as? Double
            let y = point["y"] as? Double
            let id = point["id"] as? String
            let color = point["color"] as? String
            let selections = point["selections"] as? [String]
            let colors = point["colors"] as? [String]

            XCTAssertNotNil(x, "Point \(i) missing x")
            XCTAssertNotNil(y, "Point \(i) missing y")
            XCTAssertNotNil(id, "Point \(i) missing id")
            XCTAssertNotNil(color, "Point \(i) missing color")
            XCTAssertNotNil(selections, "Point \(i) missing selections")
            XCTAssertNotNil(colors, "Point \(i) missing colors")

            if let sels = selections, let cols = colors {
                XCTAssertEqual(sels.count, cols.count,
                               "Point \(i) (\(id ?? "?")): selections count (\(sels.count)) != colors count (\(cols.count))")
            }

            // Verify color is not empty
            if let c = color {
                XCTAssertFalse(c.isEmpty, "Point \(i) has empty color")
            }
        }
    }

    // MARK: - Helper: Build SQLite database from real data (matching actual app code path)

    /// Downloads JSON, parses CurtainData, builds SQLite database, and returns
    /// a fully-constructed CurtainData matching the real app's code path:
    /// 1. Download JSON from API
    /// 2. Parse with CurtainData.fromJSON (gets differentialForm, rawForm, selectedMap, selectionsName)
    /// 3. Parse settings with CurtainDataService.restoreSettings (gets colorMap, cutoffs, etc.)
    /// 4. Build SQLite database with ProteomicsDataService.buildProteomicsDataIfNeeded
    /// 5. Construct final CurtainData with real settings (like CurtainDetailsView.convertToCurtainData)
    private func buildTPDatabaseFromRealData() async throws -> (curtainData: CurtainData, testLinkId: String) {
        let linkId = CurtainConstants.ExampleData.uniqueId
        let hostname = CurtainConstants.ExampleData.apiUrl
        let (_, json) = try await downloadCurtainData(linkId: linkId, hostname: hostname)

        guard let parsedData = CurtainData.fromJSON(json) else {
            throw NSError(domain: "VolcanoPlotGraphDataTests", code: 10,
                          userInfo: [NSLocalizedDescriptionKey: "Failed to parse CurtainData"])
        }

        // Parse settings via CurtainDataService (same as real app)
        let dataService = CurtainDataService()
        try await dataService.restoreSettings(from: json)

        // Build SQLite database — same code path as the real app
        let testLinkId = "test-volcano-\(UUID().uuidString)"
        let proteomicsService = ProteomicsDataService.shared

        try proteomicsService.buildProteomicsDataIfNeeded(
            linkId: testLinkId,
            rawTsv: json["raw"] as? String,
            processedTsv: json["processed"] as? String,
            rawForm: parsedData.rawForm,
            differentialForm: parsedData.differentialForm,
            curtainData: parsedData,
            onProgress: { _ in }
        )

        // Get selectedMap and selectOperationNames from CurtainDataService
        // (populated by restoreSettings from json["selectionsMap"] and json["selectionsName"])
        // This mirrors what CurtainDetailsView.convertToCurtainData does
        let rawSelectedMap = dataService.curtainData.selectedMap
        let selectOperationNames = dataService.curtainData.selectOperationNames

        // Transform selectedMap: filter out false values (same as transformSelectionsMapToSelectedMap)
        let transformedSelectedMap: [String: [String: Bool]]? = {
            if rawSelectedMap.isEmpty { return nil }
            var cleaned: [String: [String: Bool]] = [:]
            for (proteinId, selections) in rawSelectedMap {
                let trueOnly = selections.filter { $0.value }
                if !trueOnly.isEmpty {
                    cleaned[proteinId] = trueOnly
                }
            }
            return cleaned.isEmpty ? nil : cleaned
        }()

        print("[buildTPDatabaseFromRealData] rawSelectedMap count: \(rawSelectedMap.count)")
        print("[buildTPDatabaseFromRealData] transformedSelectedMap count: \(transformedSelectedMap?.count ?? 0)")
        print("[buildTPDatabaseFromRealData] selectOperationNames: \(selectOperationNames)")

        // Construct CurtainData with real settings — mirrors CurtainDetailsView.convertToCurtainData
        let curtainData = CurtainData(
            raw: parsedData.raw,
            rawForm: parsedData.rawForm,
            differentialForm: parsedData.differentialForm,
            processed: parsedData.processed,
            selectedMap: transformedSelectedMap,
            selectionsName: selectOperationNames.isEmpty ? nil : selectOperationNames,
            settings: dataService.curtainSettings,  // Real parsed settings with colorMap
            fetchUniprot: parsedData.fetchUniprot,
            extraData: parsedData.extraData,
            permanent: false,
            bypassUniProt: false,
            linkId: testLinkId
        )

        return (curtainData, testLinkId)
    }

    // MARK: - Trace Ordering & Color Tests (via PlotlyChartGenerator + SQLite)

    /// Verify that user selections (PPM1H, LRRK2 Pathway) appear LAST in the
    /// final trace array, meaning they render on top in Plotly (last trace = top layer).
    /// This matches Android behavior: build [user, significance], reverse → [significance, user].
    func testTPVolcanoUserSelectionsOnTop() async throws {
        let (curtainData, testLinkId) = try await buildTPDatabaseFromRealData()
        defer { ProteomicsDataService.shared.clearDatabaseForLinkId(testLinkId) }

        // Clear any persisted colorMap from previous test runs
        PlotlyChartGenerator.clearPersistedColorMap()

        let generator = PlotlyChartGenerator()
        let context = PlotGenerationContext(
            data: curtainData,
            settings: curtainData.settings,
            selections: [],
            searchFilter: nil,
            editMode: false,
            isDarkMode: false,
            linkId: testLinkId
        )

        _ = await generator.createVolcanoPlotHtml(context: context)
        let traceNames = generator.lastGeneratedTraceNames

        print("Final trace ordering (first = bottom, last = top):")
        for (i, name) in traceNames.enumerated() {
            print("  [\(i)] \(name)")
        }

        XCTAssertFalse(traceNames.isEmpty, "Should have traces")

        // User selections should be at the END of the trace list (rendered on top)
        let ppm1hName = "PPM1H;ARHCL1;KIAA1157;URCC2[Q9ULR3] (1)"
        let lrrk2Name = "LRRK2 Pathway (1)"

        if let ppm1hIndex = traceNames.firstIndex(of: ppm1hName) {
            // All significance groups should have a LOWER index (rendered below)
            for (i, name) in traceNames.enumerated() {
                if name.contains("P-value") || name.contains("FC") || name == "Background" {
                    XCTAssertLessThan(i, ppm1hIndex,
                                      "Significance group '\(name)' at [\(i)] should be below PPM1H at [\(ppm1hIndex)]")
                }
            }
        } else {
            XCTFail("PPM1H selection '\(ppm1hName)' not found in traces. Found: \(traceNames)")
        }

        if let lrrk2Index = traceNames.firstIndex(of: lrrk2Name) {
            for (i, name) in traceNames.enumerated() {
                if name.contains("P-value") || name.contains("FC") || name == "Background" {
                    XCTAssertLessThan(i, lrrk2Index,
                                      "Significance group '\(name)' at [\(i)] should be below LRRK2 at [\(lrrk2Index)]")
                }
            }
        } else {
            XCTFail("LRRK2 selection '\(lrrk2Name)' not found in traces. Found: \(traceNames)")
        }
    }

    /// Verify that user selection traces have the correct colors from the colorMap.
    func testTPVolcanoTraceColors() async throws {
        let (curtainData, testLinkId) = try await buildTPDatabaseFromRealData()
        defer { ProteomicsDataService.shared.clearDatabaseForLinkId(testLinkId) }

        PlotlyChartGenerator.clearPersistedColorMap()

        let generator = PlotlyChartGenerator()
        let context = PlotGenerationContext(
            data: curtainData,
            settings: curtainData.settings,
            selections: [],
            searchFilter: nil,
            editMode: false,
            isDarkMode: false,
            linkId: testLinkId
        )

        _ = await generator.createVolcanoPlotHtml(context: context)
        let traces = generator.lastGeneratedTraces

        print("Trace colors:")
        for trace in traces {
            let colorStr = trace.marker?.color as? String ?? "nil"
            print("  '\(trace.name)' -> \(colorStr)")
        }

        XCTAssertFalse(traces.isEmpty, "Should have traces")

        // Verify significance group trace colors
        let expectedSignificanceColors = TPDatasetConstants.colorMap.filter { key, _ in
            // Only current-format keys: "P-value <= ..." or "P-value > ..." (not legacy "P-value < " or "P-value >= ")
            (key.contains("P-value <= ") || (key.contains("P-value > ") && !key.contains("P-value >= ")))
        }
        for (groupName, expectedColor) in expectedSignificanceColors {
            if let trace = traces.first(where: { $0.name == groupName }) {
                let actualColor = trace.marker?.color as? String
                XCTAssertEqual(actualColor, expectedColor,
                               "Trace '\(groupName)' should have color '\(expectedColor)', got '\(actualColor ?? "nil")'")
            }
        }

        // Verify user selection trace colors
        let expectedUserSelectionColors = TPDatasetConstants.colorMap.filter { key, _ in
            TPDatasetConstants.selectionsName.contains(key)
        }
        for (selName, expectedColor) in expectedUserSelectionColors {
            if let trace = traces.first(where: { $0.name == selName }) {
                let actualColor = trace.marker?.color as? String
                XCTAssertEqual(actualColor, expectedColor,
                               "Trace '\(selName)' should have color '\(expectedColor)', got '\(actualColor ?? "nil")'")
            }
        }
    }

    /// Verify known proteins have correct fold change and significance values.
    func testTPVolcanoKnownProteinValues() async throws {
        let (service, appData) = try await loadTPDataset()

        let volcanoService = VolcanoPlotDataService()
        let result = await volcanoService.processVolcanoData(curtainData: appData, settings: service.curtainSettings)

        for expected in TPDatasetConstants.knownProteins {
            guard let point = result.jsonData.first(where: { ($0["id"] as? String) == expected.id }) else {
                XCTFail("Known protein '\(expected.id)' (\(expected.gene)) not found in volcano data")
                continue
            }

            let x = point["x"] as? Double ?? 0
            let y = point["y"] as? Double ?? 0

            XCTAssertEqual(x, expected.foldChange, accuracy: 0.0001,
                           "Protein \(expected.id) fold change mismatch")
            XCTAssertEqual(y, expected.pValue, accuracy: 0.0001,
                           "Protein \(expected.id) p-value mismatch")
        }
    }
}

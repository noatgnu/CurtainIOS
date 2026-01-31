//
//  CurtainDetailsView.swift
//  Curtain
//
//  Created by Toan Phung on 02/08/2025.
//

import SwiftUI
import SwiftData
import Foundation

// MARK: - Helper Structs

// MARK: - CurtainDetailsView 

struct CurtainDetailsView: View {
    let curtain: CurtainEntity
    @Environment(\.modelContext) private var modelContext
    @State private var dataService = CurtainDataService()
    @State private var curtainData: CurtainData?
    @State private var isLoading = true
    @State private var error: String?
    @State private var selectedTab = 0
    @State private var annotationEditMode = false // Shared annotation edit mode state
    
    private var isWideLayout: Bool {
        UIDevice.current.userInterfaceIdiom == .pad || UIDevice.current.userInterfaceIdiom == .mac
    }

    var body: some View {
        VStack(spacing: 0) {
                // Header Information
                CurtainHeaderView(curtain: curtain)

                if isLoading {
                    LoadingDataView()
                } else if let error = error {
                    ErrorDataView(message: error) {
                        loadCurtainData()
                    }
                } else if let data = curtainData {
                    if isWideLayout {
                        // iPad: use TabView with tab bar
                        TabView(selection: $selectedTab) {
                            DataOverviewTab(data: data)
                                .tabItem {
                                    Image(systemName: "info.circle")
                                    Text("Overview")
                                }
                                .tag(0)

                            VolcanoPlotTab(data: $curtainData, annotationEditMode: $annotationEditMode)
                                .tabItem {
                                    Image(systemName: "chart.xyaxis.line")
                                    Text("Volcano Plot")
                                }
                                .tag(1)

                            ProteinDetailsTab(data: $curtainData)
                                .tabItem {
                                    Image(systemName: "list.bullet.rectangle")
                                    Text("Protein Details")
                                }
                                .tag(2)

                            SettingsTab(data: Binding(
                                get: { data },
                                set: { newValue in
                                    DispatchQueue.main.async {
                                        curtainData = newValue
                                    }
                                }
                            ))
                                .tabItem {
                                    Image(systemName: "gearshape")
                                    Text("Settings")
                                }
                                .tag(3)
                        }
                    } else {
                        // iPhone: use segmented picker to avoid double tab bar
                        Picker("Section", selection: $selectedTab) {
                            Image(systemName: "info.circle").tag(0)
                            Image(systemName: "chart.xyaxis.line").tag(1)
                            Image(systemName: "list.bullet.rectangle").tag(2)
                            Image(systemName: "gearshape").tag(3)
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)
                        .padding(.vertical, 8)

                        Group {
                            switch selectedTab {
                            case 0:
                                DataOverviewTab(data: data)
                            case 1:
                                VolcanoPlotTab(data: $curtainData, annotationEditMode: $annotationEditMode)
                            case 2:
                                ProteinDetailsTab(data: $curtainData)
                            case 3:
                                SettingsTab(data: Binding(
                                    get: { data },
                                    set: { newValue in
                                        DispatchQueue.main.async {
                                            curtainData = newValue
                                        }
                                    }
                                ))
                            default:
                                EmptyView()
                            }
                        }
                    }
                } else {
                    NoDataView()
                }
        }
        .navigationTitle(curtain.dataDescription)
        .navigationBarTitleDisplayMode(.inline)
        // Remove conditional toolbar - let each tab handle its own toolbar
        .onAppear {
            loadCurtainData()
        }
        // Protein search sheet is now handled by individual tabs
    }
    
    private func loadCurtainData() {

        isLoading = true
        error = nil

        Task {
            do {
                // Determine file path and type
                // 1. Check for SQLite file in CurtainData
                let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let curtainDataDir = documentsURL.appendingPathComponent("CurtainData", isDirectory: true)
                let dbFilePath = curtainDataDir.appendingPathComponent("proteomics_data_\(curtain.linkId).sqlite").path
                let jsonFilePath = curtainDataDir.appendingPathComponent("\(curtain.linkId).json").path

                print("[CurtainDetailsView] Loading data for linkId: \(curtain.linkId)")
                print("[CurtainDetailsView] Checking SQLite path: \(dbFilePath)")
                print("[CurtainDetailsView] SQLite exists: \(FileManager.default.fileExists(atPath: dbFilePath))")
                print("[CurtainDetailsView] Checking JSON path: \(jsonFilePath)")
                print("[CurtainDetailsView] JSON exists: \(FileManager.default.fileExists(atPath: jsonFilePath))")
                print("[CurtainDetailsView] curtain.file: \(curtain.file ?? "nil")")

                if FileManager.default.fileExists(atPath: dbFilePath) {
                    // Hybrid Mode: Load from SQLite + SwiftData
                    print("[CurtainDetailsView] SQLite file found, attempting hybrid load")
                    let dbURL = URL(fileURLWithPath: dbFilePath)
                    // Use the main JSON file for metadata (contains UniProt data)
                    let jsonFileURL = curtainDataDir.appendingPathComponent("\(curtain.linkId).json")
                    let metadataURL = FileManager.default.fileExists(atPath: jsonFileURL.path) ? jsonFileURL : nil
                    print("[CurtainDetailsView] Using metadataURL: \(metadataURL?.path ?? "nil")")

                    // Fetch settings from SwiftData
                    let linkId = curtain.linkId

                    // First, ensure settings entity exists (migrate from SQLite or rebuild from JSON if needed)
                    // IMPORTANT: Use the SAME modelContext for both ensure and fetch
                    let repository = CurtainRepository(modelContext: modelContext)
                    let settingsResult = await repository.ensureSettingsEntityExists(linkId: linkId)

                    // Handle the result
                    switch settingsResult {
                    case .exists, .migrated, .rebuilt:
                        // Data is ready, continue to load
                        print("[CurtainDetailsView] Settings ready (result: \(settingsResult))")
                    case .needsRedownload, .noData:
                        // No data available, user needs to re-download
                        print("[CurtainDetailsView] No data available, needs re-download")
                        await MainActor.run {
                            self.error = "Data not found. Please re-download the dataset."
                            self.isLoading = false
                        }
                        return
                    }

                    // Fetch settings from SwiftData using the SAME repository instance
                    // This ensures we see the data that was just saved
                    await MainActor.run {
                        if let settingsEntity = repository.getCurtainSettings(linkId: linkId) {
                            print("[CurtainDetailsView] Found CurtainSettingsEntity for linkId: \(linkId)")
                            print("[CurtainDetailsView] Passing metadataURL to restoreFromDatabase: \(metadataURL?.path ?? "nil")")
                            Task {
                                await dataService.restoreFromDatabase(dbPath: dbURL, settingsEntity: settingsEntity, metadataURL: metadataURL)

                                await MainActor.run {
                                    self.curtainData = convertToCurtainData(from: dataService, dbPath: dbURL, linkId: curtain.linkId)
                                    print("[CurtainDetailsView] Data loaded successfully")
                                    self.isLoading = false
                                }
                            }
                        } else {
                            print("[CurtainDetailsView] ERROR: No CurtainSettingsEntity found after migration for linkId: \(linkId)")
                            self.error = "Failed to load metadata after migration. Please re-download."
                            self.isLoading = false
                        }
                    }
                    
                } else if FileManager.default.fileExists(atPath: jsonFilePath) {
                    // Legacy Mode: Load from JSON
                    let fileURL = URL(fileURLWithPath: jsonFilePath)
                    let jsonData = try Data(contentsOf: fileURL)
                    let jsonObject = try JSONSerialization.jsonObject(with: jsonData, options: [])
                    
                    try await dataService.restoreSettings(from: jsonObject)
                    
                    await MainActor.run {
                        self.curtainData = convertToCurtainData(from: dataService, linkId: curtain.linkId)
                        self.isLoading = false
                    }
                } else {
                    await MainActor.run {
                        self.error = "Data file not found. Please re-download the dataset."
                        self.isLoading = false
                    }
                }
            } catch {
                await MainActor.run {
                    self.error = "Failed to load data: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
    
    private func convertToCurtainData(from service: CurtainDataService, dbPath: URL? = nil, linkId: String? = nil) -> CurtainData {
        
        let transformedSelectedMap = transformSelectionsMapToSelectedMap(service.curtainData.selectedMap.isEmpty ? nil : service.curtainData.selectedMap)

        print("[convertToCurtainData] service.curtainData.selectedMap count: \(service.curtainData.selectedMap.count)")
        print("[convertToCurtainData] transformedSelectedMap count: \(transformedSelectedMap?.count ?? 0)")
        print("[convertToCurtainData] selectOperationNames: \(service.curtainData.selectOperationNames)")
        if let first = transformedSelectedMap?.first {
            print("[convertToCurtainData] First entry: \(first.key) -> \(first.value)")
        }

        var appData = CurtainData(
            raw: service.curtainData.raw?.originalFile,
            rawForm: CurtainRawForm(
                primaryIDs: service.curtainData.rawForm?.primaryIDs ?? "",
                samples: service.curtainData.rawForm?.samples ?? [],
                log2: service.curtainData.rawForm?.log2 ?? false
            ),
            differentialForm: CurtainDifferentialForm(
                primaryIDs: service.curtainData.differentialForm?.primaryIDs ?? "",
                geneNames: service.curtainData.differentialForm?.geneNames ?? "",
                foldChange: service.curtainData.differentialForm?.foldChange ?? "",
                transformFC: service.curtainData.differentialForm?.transformFC ?? false,
                significant: service.curtainData.differentialForm?.significant ?? "",
                transformSignificant: service.curtainData.differentialForm?.transformSignificant ?? false,
                comparison: service.curtainData.differentialForm?.comparison ?? "",
                comparisonSelect: service.curtainData.differentialForm?.comparisonSelect ?? [],
                reverseFoldChange: service.curtainData.differentialForm?.reverseFoldChange ?? false
            ),
            processed: service.curtainData.differential?.originalFile,
            selectionsMap: service.curtainData.dataMap,
            selectedMap: transformedSelectedMap,
            selectionsName: service.curtainData.selectOperationNames.isEmpty ? nil : service.curtainData.selectOperationNames,
            settings: service.curtainSettings,
            fetchUniprot: service.curtainSettings.fetchUniprot,
            extraData: ExtraData(
                uniprot: UniprotExtraData(
                    results: service.uniprotData.results,
                    dataMap: service.uniprotData.dataMap,
                    db: service.uniprotData.db,
                    organism: service.uniprotData.organism,
                    accMap: service.uniprotData.accMap,
                    geneNameToAcc: service.uniprotData.geneNameToAcc as? [String: [String: Any]]
                ),
                data: DataMapContainer(
                    dataMap: service.curtainData.dataMap,
                    genesMap: service.curtainData.genesMap as? [String: [String: Any]],
                    primaryIDsMap: service.curtainData.primaryIDsMap as? [String: [String: Any]],
                    allGenes: service.curtainData.allGenes
                )
            ),
            permanent: false, // Default to false if not available in service
            bypassUniProt: service.bypassUniProt,
            dbPath: dbPath,
            linkId: linkId
        )
        
        // Ensure uniprotDB is populated for correct gene name resolution
        if let db = service.uniprotData.db {
            appData.uniprotDB = db
        }
        
        return appData
    }
    
    
    private func transformSelectionsMapToSelectedMap(_ selectedMap: [String: [String: Bool]]?) -> [String: [String: Bool]]? {
        
        
        guard let selectedMap = selectedMap else { return nil }
        
        // Filter out false values 
        var cleanedSelectedMap: [String: [String: Bool]] = [:]
        
        for (proteinId, selections) in selectedMap {
            var cleanedSelections: [String: Bool] = [:]
            for (selectionName, isSelected) in selections {
                if isSelected { 
                    cleanedSelections[selectionName] = true
                }
            }
            
            if !cleanedSelections.isEmpty {
                cleanedSelectedMap[proteinId] = cleanedSelections
            }
        }
        
        
        return cleanedSelectedMap.isEmpty ? nil : cleanedSelectedMap
    }
}

// MARK: - Header Views

struct CurtainHeaderView: View {
    let curtain: CurtainEntity
    let onSearchTapped: (() -> Void)?
    
    init(curtain: CurtainEntity, onSearchTapped: (() -> Void)? = nil) {
        self.curtain = curtain
        self.onSearchTapped = onSearchTapped
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(curtain.dataDescription)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("ID: \(curtain.linkId)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .textSelection(.enabled)
                }
                
                Spacer()
                
                // Search button (when onSearchTapped is provided)
                if let searchAction = onSearchTapped {
                    Button(action: searchAction) {
                        Image(systemName: "magnifyingglass")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                    .padding(.trailing, 8)
                }
                
                if curtain.isPinned {
                    Image(systemName: "pin.fill")
                        .foregroundColor(.orange)
                }
            }
            
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
    }
}

struct InfoPill: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.15))
        .cornerRadius(8)
    }
}

// MARK: - State Views

struct LoadingDataView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading proteomics data...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ErrorDataView: View {
    let message: String
    let onRetry: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.orange)
            
            Text("Error Loading Data")
                .font(.title2)
                .fontWeight(.medium)
            
            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Retry", action: onRetry)
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct NoDataView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text")
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            
            Text("No Data Available")
                .font(.title2)
                .fontWeight(.medium)
            
            Text("Please download the dataset first to view its contents")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Tab Content Views

struct DataOverviewTab: View {
    let data: CurtainData
    
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                OverviewSection(title: "Data Statistics") {
                    OverviewRow(label: "Raw Data Rows", value: "\(data.rawDataRowCount)")
                    OverviewRow(label: "Differential Data Rows", value: "\(data.differentialDataRowCount)")
                    
                    if !data.rawForm.samples.isEmpty {
                        OverviewRow(label: "Raw Data Samples", value: "\(data.rawForm.samples.count)")
                    }
                    OverviewRow(label: "Total Proteins", value: "\(data.proteomicsData.count)")
                    OverviewRow(label: "Conditions", value: "\(data.settings.conditionOrder.count)")
                    
                    if !data.rawForm.samples.isEmpty {
                        let samplesInfo = data.rawForm.samples.joined(separator: ", ")
                        OverviewRow(label: "Samples", value: samplesInfo, isExpandable: true)
                    }
                }
                
                OverviewSection(title: "Data Processing") {
                    let uniprotStatus = data.fetchUniprot ? "UniProt data loaded" : "UniProt data not loaded"
                    OverviewRow(label: "UniProt Status", value: uniprotStatus)
                    OverviewRow(label: "UniProt Integration", value: data.settings.uniprot ? "Enabled" : "Disabled")
                    OverviewRow(label: "Fetch UniProt", value: data.fetchUniprot ? "Yes" : "No")
                }
                
                if !data.differentialForm.primaryIDs.isEmpty || !data.differentialForm.foldChange.isEmpty {
                    OverviewSection(title: "Differential Analysis Configuration") {
                        if !data.differentialForm.primaryIDs.isEmpty {
                            OverviewRow(label: "Primary IDs Column", value: data.differentialForm.primaryIDs)
                        }
                        if !data.differentialForm.geneNames.isEmpty {
                            OverviewRow(label: "Gene Names Column", value: data.differentialForm.geneNames)
                        }
                        if !data.differentialForm.foldChange.isEmpty {
                            OverviewRow(label: "Fold Change Column", value: data.differentialForm.foldChange)
                        }
                        OverviewRow(label: "Transform FC", value: data.differentialForm.transformFC ? "Yes" : "No")
                        if !data.differentialForm.significant.isEmpty {
                            OverviewRow(label: "Significance Column", value: data.differentialForm.significant)
                        }
                        OverviewRow(label: "Transform Significance", value: data.differentialForm.transformSignificant ? "Yes" : "No")
                        if !data.differentialForm.comparison.isEmpty {
                            OverviewRow(label: "Comparison Column", value: data.differentialForm.comparison)
                        }
                        if !data.differentialForm.comparisonSelect.isEmpty {
                            let comparisons = data.differentialForm.comparisonSelect.joined(separator: ", ")
                            OverviewRow(label: "Selected Comparisons", value: comparisons, isExpandable: true)
                        }
                        OverviewRow(label: "Reverse Fold Change", value: data.differentialForm.reverseFoldChange ? "Yes" : "No")
                    }
                }
                
                // Analysis Cutoffs
                OverviewSection(title: "Analysis Parameters") {
                    OverviewRow(label: "P-value Cutoff", value: String(format: "%.3f", data.settings.pCutoff))
                    OverviewRow(label: "Log2FC Cutoff", value: String(format: "%.2f", data.settings.log2FCCutoff))
                    OverviewRow(label: "Academic Mode", value: data.settings.academic ? "Yes" : "No")
                    OverviewRow(label: "Version", value: "\(data.settings.version)")
                }
                
                // Project Details (if available)
                if !data.settings.project.title.isEmpty {
                    let project = data.settings.project
                    OverviewSection(title: "Project Information") {
                        if !project.title.isEmpty {
                            OverviewRow(label: "Title", value: project.title)
                        }
                        if !project.projectDescription.isEmpty {
                            OverviewRow(label: "Description", value: project.projectDescription, isExpandable: true)
                        }
                    }
                }
                
                // Additional Data Information
                if let extraData = data.extraData {
                    OverviewSection(title: "Additional Data") {
                        if let uniprotData = extraData.uniprot {
                            OverviewRow(label: "UniProt Results", value: "\(uniprotData.results.count) entries")
                            if let organism = uniprotData.organism, !organism.isEmpty {
                                OverviewRow(label: "Organism", value: organism)
                            }
                        }
                        
                        if let dataContainer = extraData.data {
                            if let allGenes = dataContainer.allGenes {
                                OverviewRow(label: "Total Genes", value: "\(allGenes.count)")
                            }
                        }
                    }
                }
            }
            .padding()
        }
    }
}

struct VolcanoPlotTab: View {
    @Binding var data: CurtainData?
    @Binding var annotationEditMode: Bool
    @State private var showingProteinSearch = false
    @State private var showingVolcanoColorManager = false
    @State private var showingConditionLabelsSettings = false
    @State private var showingTextColumnSettings = false
    @State private var showingTraceOrderSettings = false
    @State private var showingYAxisPositionSettings = false

    var body: some View {
        if data != nil {
            ZStack {
                InteractiveVolcanoPlotView(
                    curtainData: Binding(
                        get: { data! },
                        set: { newValue in data = newValue }
                    ),
                    annotationEditMode: $annotationEditMode
                )
                .id("\(data!.selectionsName?.count ?? 0)-\(data!.selectionsMap?.keys.count ?? 0)") // Force refresh when selections change
                
                // Floating Action Buttons
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        VStack(spacing: 12) {
                            // Condition Labels Settings Button
                            Button(action: {
                                showingConditionLabelsSettings = true
                            }) {
                                Image(systemName: "text.below.photo")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                    .frame(width: 44, height: 44)
                                    .background(Color.purple)
                                    .clipShape(Circle())
                                    .shadow(radius: 4)
                            }
                            .disabled(annotationEditMode)
                            .opacity(annotationEditMode ? 0.5 : 1.0)

                            // Custom Text Column Button
                            Button(action: {
                                showingTextColumnSettings = true
                            }) {
                                Image(systemName: "text.bubble")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                    .frame(width: 44, height: 44)
                                    .background(Color.indigo)
                                    .clipShape(Circle())
                                    .shadow(radius: 4)
                            }
                            .disabled(annotationEditMode)
                            .opacity(annotationEditMode ? 0.5 : 1.0)

                            // Trace Order Button
                            Button(action: {
                                showingTraceOrderSettings = true
                            }) {
                                Image(systemName: "line.3.horizontal.decrease.circle")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                    .frame(width: 44, height: 44)
                                    .background(Color.teal)
                                    .clipShape(Circle())
                                    .shadow(radius: 4)
                            }
                            .disabled(annotationEditMode)
                            .opacity(annotationEditMode ? 0.5 : 1.0)

                            // Y-Axis Position Button
                            Button(action: {
                                showingYAxisPositionSettings = true
                            }) {
                                Image(systemName: "arrow.left.and.right.square")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                    .frame(width: 44, height: 44)
                                    .background(Color.mint)
                                    .clipShape(Circle())
                                    .shadow(radius: 4)
                            }
                            .disabled(annotationEditMode)
                            .opacity(annotationEditMode ? 0.5 : 1.0)

                            // Color Manager Button
                            Button(action: {
                                showingVolcanoColorManager = true
                            }) {
                                Image(systemName: "paintpalette.fill")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                    .frame(width: 44, height: 44)
                                    .background(Color.blue)
                                    .clipShape(Circle())
                                    .shadow(radius: 4)
                            }
                            .disabled(annotationEditMode)
                            .opacity(annotationEditMode ? 0.5 : 1.0)

                            // Search Button
                            Button(action: {
                                showingProteinSearch = true
                            }) {
                                Image(systemName: "magnifyingglass")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                    .frame(width: 44, height: 44)
                                    .background(Color.green)
                                    .clipShape(Circle())
                                    .shadow(radius: 4)
                            }
                            .disabled(annotationEditMode)
                            .opacity(annotationEditMode ? 0.5 : 1.0)
                            
                            // Export Button
                            ExportPlotButton()
                                .disabled(annotationEditMode)
                                .opacity(annotationEditMode ? 0.5 : 1.0)
                            
                            // Annotation Edit Button
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    annotationEditMode.toggle()
                                }
                            }) {
                                Image(systemName: annotationEditMode ? "pencil.circle.fill" : "pencil.circle")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                    .frame(width: 44, height: 44)
                                    .background(annotationEditMode ? Color.orange : Color.gray)
                                    .clipShape(Circle())
                                    .shadow(radius: 4)
                            }
                        }
                        .padding(.trailing, 16)
                        .padding(.bottom, 16)
                    }
                }
            }
            .sheet(isPresented: $showingProteinSearch) {
                ProteinSearchView(curtainData: Binding(
                    get: { data! },
                    set: { newValue in data = newValue }
                ))
            }
            .sheet(isPresented: $showingVolcanoColorManager) {
                VolcanoColorManagerView(curtainData: Binding(
                    get: { data! },
                    set: { newValue in data = newValue }
                ))
            }
            .sheet(isPresented: $showingConditionLabelsSettings) {
                VolcanoConditionLabelsSettingsView(curtainData: Binding(
                    get: { data! },
                    set: { newValue in data = newValue }
                ))
            }
            .sheet(isPresented: $showingTextColumnSettings) {
                VolcanoTextColumnSettingsView(curtainData: Binding(
                    get: { data! },
                    set: { newValue in data = newValue }
                ))
            }
            .sheet(isPresented: $showingTraceOrderSettings) {
                VolcanoTraceOrderSettingsView(
                    curtainData: Binding(
                        get: { data! },
                        set: { newValue in data = newValue }
                    ),
                    traces: PlotlyCoordinator.sharedCoordinator?.chartGenerator.lastGeneratedTraces ?? []
                )
            }
            .sheet(isPresented: $showingYAxisPositionSettings) {
                VolcanoYAxisPositionSettingsView(curtainData: Binding(
                    get: { data! },
                    set: { newValue in data = newValue }
                ))
            }
        } else {
            Text("No data available")
                .foregroundColor(.secondary)
        }
    }
}

struct ProteinDetailsTab: View {
    @Binding var data: CurtainData?
    @State private var selectedSelectionGroup: String = "All"
    @State private var searchText = ""
    @State private var proteinDisplayNameCache: [String: String] = [:]
    
    private var availableSelectionGroups: [String] {
        guard let curtainData = data else { return ["All"] }
        
        var groups = ["All"]
        
        // Try multiple sources for selection names
        // 1. First try selectionsName
        if let selectionsName = curtainData.selectionsName, !selectionsName.isEmpty {
            groups.append(contentsOf: selectionsName)
        }
        // 2. Try selectionsMap keys as fallback
        else if let selectionsMap = curtainData.selectionsMap, !selectionsMap.isEmpty {
            groups.append(contentsOf: selectionsMap.keys.sorted())
        }
        // 3. Try getting unique selection names from selectedMap
        else if let selectedMap = curtainData.selectedMap, !selectedMap.isEmpty {
            let selectionNames = Set(selectedMap.values.flatMap { $0.keys })
            groups.append(contentsOf: selectionNames.sorted())
        }
        
        return groups
    }
    
    
    private var filteredProteins: [String] {
        guard let curtainData = data else { 
            return [] 
        }
        
        
        // Get proteins based on selection group
        var allProteins: [String] = []
        
        if selectedSelectionGroup == "All" {
            // For "All", show only proteins that are in ANY selection (not all proteins from dataframe)
            if let selectedMap = curtainData.selectedMap, !selectedMap.isEmpty {
                allProteins = Array(selectedMap.keys)
            } else {
            }
        } else {
            // For specific selection group, get only proteins from selectedMap
            if let selectedMap = curtainData.selectedMap {
                allProteins = selectedMap.compactMap { (proteinId, selections) in
                    // Check if this protein has the selected group and it's true
                    if selections[selectedSelectionGroup] == true {
                        return proteinId
                    }
                    return nil
                }
            } else {
            }
        }
        
        // Filter by search text - search in display name (gene names + protein ID)
        if !searchText.isEmpty {
            allProteins = allProteins.filter { proteinId in
                // Use read-only display name calculation to avoid state modification during view update
                let displayName = calculateDisplayName(for: proteinId, curtainData: curtainData)
                return displayName.localizedCaseInsensitiveContains(searchText) ||
                       proteinId.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        let finalProteins = allProteins.sorted()
        if finalProteins.count > 0 && finalProteins.count <= 5 {
        }
        return finalProteins
    }
    
    private func populateDisplayNameCache(for curtainData: CurtainData) {
        // Populate cache proactively to avoid state modification during view updates
        guard let selectedMap = curtainData.selectedMap else { return }
        
        Task {
            var newCache: [String: String] = [:]
            for proteinId in selectedMap.keys {
                newCache[proteinId] = calculateDisplayName(for: proteinId, curtainData: curtainData)
            }
            
            // Update the cache in a single operation on the main thread
            await MainActor.run {
                proteinDisplayNameCache = newCache
            }
        }
    }
    
    private func calculateDisplayName(for proteinId: String, curtainData: CurtainData) -> String {
        // Use unified gene name resolution (SQLite first, then extraData fallback)
        if let geneName = curtainData.getPrimaryGeneNameForProtein(proteinId),
           geneName != proteinId {
            return "\(geneName) (\(proteinId))"
        }

        return proteinId
    }
    
    
    var body: some View {
        VStack(spacing: 0) {
                // Filter controls 
                VStack(spacing: 12) {
                    // Selection group filter
                    HStack {
                        Text("Filter by selection:")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        Picker("Selection Group", selection: $selectedSelectionGroup) {
                            ForEach(availableSelectionGroups, id: \.self) { group in
                                Text(group).tag(group)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .frame(maxWidth: 150)
                    }
                    
                    // Search bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        
                        TextField("Search by gene name or protein ID...", text: $searchText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                        
                        if !searchText.isEmpty {
                            Button(action: {
                                searchText = ""
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    // Results count
                    HStack {
                        Text("\(filteredProteins.count) proteins")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if selectedSelectionGroup == "All" {
                            Text("with selections")
                                .font(.caption)
                                .foregroundColor(.blue)
                        } else {
                            Text("in \(selectedSelectionGroup)")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                        
                        Spacer()
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                
                // Protein list
                List {
                    ForEach(Array(filteredProteins.enumerated()), id: \.element) { index, proteinId in
                        ProteinDetailRowView(
                            proteinId: proteinId,
                            curtainData: $data,
                            selectedSelectionGroup: selectedSelectionGroup,
                            proteinList: filteredProteins,
                            proteinIndex: index
                        )
                    }
                }
                .listStyle(PlainListStyle())
            }
            .onAppear {
                // Populate cache when view appears
                if let curtainData = data {
                    populateDisplayNameCache(for: curtainData)
                }
            }
            .onChange(of: data?.linkId) { oldValue, newValue in
                // Clear cache and repopulate when data changes (using linkId as identifier)
                proteinDisplayNameCache.removeAll()
                if let curtainData = data {
                    populateDisplayNameCache(for: curtainData)
                }
            }
            .onChange(of: selectedSelectionGroup) { oldValue, newValue in
                // Clear cache and repopulate when selection group changes
                proteinDisplayNameCache.removeAll()
                if let curtainData = data {
                    populateDisplayNameCache(for: curtainData)
                }
            }
    }
}

enum ProteinChartType: String, CaseIterable {
    case barChart = "Bar Chart"
    case averageBarChart = "Average Bar Chart"
    case violinPlot = "Violin Plot"
    
    var displayName: String {
        return self.rawValue
    }
}

struct SettingsTab: View {
    @Binding var data: CurtainData
    @StateObject private var variantManager = SettingsVariantManager.shared
    @State private var showingSaveVariantSheet = false
    @State private var showingLoadVariantSheet = false
    @State private var showingVariantAlert = false
    @State private var variantToDelete: SettingsVariant?
    @State private var isLoadingVariant = false
    @State private var lastLoadedVariantId: String? = nil
    @State private var loadingProgress: Double = 0.0
    @State private var loadingMessage: String = ""
    @State private var loadingStartTime: Date? = nil
    @State private var suppressDataUpdates = false
    @State private var loadAttempts: [String: Int] = [:] // Track load attempts per variant
    @State private var circuitBreakerTripped = false
    @State private var showingGlobalYAxisLimitsSettings = false
    @State private var showingColumnSizeSettings = false
    @State private var showingMarkerSizeMapSettings = false
    @State private var showingViolinPointPositionSettings = false
    @State private var showingExtraDataStorageSettings = false

    var body: some View {
        Form {
            // Settings Variants Section
            Section("Settings Variants") {
                VStack(spacing: 12) {
                    HStack {
                        Text("Manage analysis parameter presets")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    
                    // Loading Progress Indicator or Circuit Breaker Warning
                    if circuitBreakerTripped {
                        VStack(spacing: 8) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text("Loading temporarily disabled")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Button("Reset") {
                                    resetCircuitBreaker()
                                }
                                .font(.caption)
                                .buttonStyle(.borderedProminent)
                                .controlSize(.mini)
                            }
                        }
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.05))
                        .cornerRadius(8)
                    } else if isLoadingVariant {
                        VStack(spacing: 8) {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text(loadingMessage)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            
                            ProgressView(value: loadingProgress, total: 1.0)
                                .progressViewStyle(LinearProgressViewStyle())
                                .frame(height: 4)
                        }
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.05))
                        .cornerRadius(8)
                    }
                    
                    HStack(spacing: 12) {
                        Button(action: {
                            showingSaveVariantSheet = true
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "square.and.arrow.down")
                                    .font(.caption)
                                Text("Save")
                                    .font(.caption)
                            }
                        }
                        .buttonStyle(.bordered)
                        .foregroundColor(.blue)
                        .disabled(isLoadingVariant || circuitBreakerTripped)
                        
                        Button(action: {
                            showingLoadVariantSheet = true
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.caption)
                                Text("Load")
                                    .font(.caption)
                            }
                        }
                        .buttonStyle(.bordered)
                        .foregroundColor(.green)
                        .disabled(variantManager.savedVariants.isEmpty || isLoadingVariant || circuitBreakerTripped)
                        
                        Spacer()
                        
                        Text("\(variantManager.savedVariants.count) saved")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
            
            Section("Analysis Parameters") {
                HStack {
                    Text("P-value Cutoff")
                    Spacer()
                    Text("\(data.settings.pCutoff, specifier: "%.3f")")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Log2FC Cutoff")
                    Spacer()
                    Text("\(data.settings.log2FCCutoff, specifier: "%.2f")")
                        .foregroundColor(.secondary)
                }
            }
            
            Section("Display Settings") {
                HStack {
                    Text("Plot Font Family")
                    Spacer()
                    Text(data.settings.plotFontFamily)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Scatter Plot Marker Size")
                    Spacer()
                    Text("\(data.settings.scatterPlotMarkerSize, specifier: "%.1f")")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Background Color Grey")
                    Spacer()
                    Image(systemName: data.settings.backGroundColorGrey ? "checkmark" : "xmark")
                        .foregroundColor(data.settings.backGroundColorGrey ? .green : .red)
                }
                
                HStack {
                    Text("Volcano Plot Title")
                    Spacer()
                    Text(data.settings.volcanoPlotTitle.isEmpty ? "Default" : data.settings.volcanoPlotTitle)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Section("Chart Settings") {
                // Global Y-Axis Limits
                Button(action: {
                    showingGlobalYAxisLimitsSettings = true
                }) {
                    HStack {
                        Image(systemName: "chart.bar.xaxis")
                            .foregroundColor(.orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Global Y-Axis Limits")
                            Text("Set consistent Y-axis ranges for all protein charts")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .foregroundColor(.primary)

                // Column Size
                Button(action: {
                    showingColumnSizeSettings = true
                }) {
                    HStack {
                        Image(systemName: "ruler")
                            .foregroundColor(.blue)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Column Size")
                            Text("Control bar/column width for each chart type")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .foregroundColor(.primary)

                // Marker Size Map
                Button(action: {
                    showingMarkerSizeMapSettings = true
                }) {
                    HStack {
                        Image(systemName: "circle.dotted.and.circle")
                            .foregroundColor(.purple)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Marker Size Map")
                            Text("Configure custom marker sizes for selection groups")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .foregroundColor(.primary)

                // Violin Point Position
                Button(action: {
                    showingViolinPointPositionSettings = true
                }) {
                    HStack {
                        Image(systemName: "circle.lefthalf.filled")
                            .foregroundColor(.teal)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Violin Point Position")
                            Text("Control horizontal position of data points in violin plots")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .foregroundColor(.primary)
            }

            Section("Color Management") {
                // Volcano Plot Colors Reference
                HStack {
                    Image(systemName: "chart.xyaxis.line")
                        .foregroundColor(.blue)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Volcano Plot Colors")
                        Text("Available from volcano plot tab (paintpalette button)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Text("↗")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                .foregroundColor(.primary)
                
                // Condition Colors Reference  
                HStack {
                    Image(systemName: "chart.bar.fill")
                        .foregroundColor(.green)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Condition Colors")
                        Text("Available from protein charts (bar chart button)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Text("↗")
                        .font(.caption)
                        .foregroundColor(.green)
                }
                .foregroundColor(.primary)
            }
            
            Section("Data Processing") {
                HStack {
                    Text("UniProt Integration")
                    Spacer()
                    Image(systemName: data.settings.uniprot ? "checkmark" : "xmark")
                        .foregroundColor(data.settings.uniprot ? .green : .red)
                }

                HStack {
                    Text("Imputation Enabled")
                    Spacer()
                    Image(systemName: data.settings.enableImputation ? "checkmark" : "xmark")
                        .foregroundColor(data.settings.enableImputation ? .green : .red)
                }
            }

            Section("Data Management") {
                // Extra Data Storage
                Button(action: {
                    showingExtraDataStorageSettings = true
                }) {
                    HStack {
                        Image(systemName: "externaldrive.badge.plus")
                            .foregroundColor(.orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Extra Data Storage")
                            Text("Manage additional metadata and notes")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()

                        if !data.settings.extraData.isEmpty {
                            Text("\(data.settings.extraData.count)")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.2))
                                .foregroundColor(.orange)
                                .cornerRadius(4)
                        }

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .foregroundColor(.primary)
            }

            // Saved Variants List (if any exist)
            if !variantManager.savedVariants.isEmpty {
                Section("Saved Variants") {
                    ForEach(variantManager.sortedVariants, id: \.id) { variant in
                        VariantRowView(
                            variant: variant,
                            onLoad: {
                                loadVariant(variant)
                            },
                            onDelete: {
                                variantToDelete = variant
                                showingVariantAlert = true
                            },
                            isLoading: isLoadingVariant && lastLoadedVariantId == variant.id,
                            isDisabled: circuitBreakerTripped
                        )
                    }
                }
            }
        }
        .sheet(isPresented: $showingSaveVariantSheet) {
            SaveVariantSheet(
                currentSettings: data.settings,
                selectedMap: data.selectedMap,
                selectionsName: data.selectionsName,
                onSave: { variant in
                    variantManager.saveVariant(variant)
                }
            )
        }
        .sheet(isPresented: $showingLoadVariantSheet) {
            LoadVariantSheet(
                variants: variantManager.savedVariants,
                onLoad: { variant in
                    loadVariant(variant)
                }
            )
        }
        .sheet(isPresented: $showingGlobalYAxisLimitsSettings) {
            GlobalYAxisLimitsSettingsView(curtainData: $data)
        }
        .sheet(isPresented: $showingColumnSizeSettings) {
            ColumnSizeSettingsView(curtainData: $data)
        }
        .sheet(isPresented: $showingMarkerSizeMapSettings) {
            MarkerSizeMapSettingsView(curtainData: $data)
        }
        .sheet(isPresented: $showingViolinPointPositionSettings) {
            ViolinPointPositionSettingsView(curtainData: $data)
        }
        .sheet(isPresented: $showingExtraDataStorageSettings) {
            ExtraDataStorageSettingsView(curtainData: $data)
        }
        .alert("Delete Variant", isPresented: $showingVariantAlert) {
            Button("Delete", role: .destructive) {
                if let variantToDelete = variantToDelete {
                    variantManager.deleteVariant(variantToDelete)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            if let variantToDelete = variantToDelete {
                Text("Are you sure you want to delete '\(variantToDelete.name)'? This action cannot be undone.")
            }
        }
    }
    
    private func loadVariant(_ variant: SettingsVariant) {
        let currentTime = Date()
        
        // Circuit breaker: prevent all loads if tripped
        guard !circuitBreakerTripped else {
            return
        }
        
        // Enhanced loop prevention with multiple checks
        guard !isLoadingVariant else { 
            return 
        }
        
        guard !suppressDataUpdates else {
            return
        }
        
        // Track load attempts and prevent excessive attempts
        let currentAttempts = loadAttempts[variant.id, default: 0]
        if currentAttempts >= 3 {
            circuitBreakerTripped = true
            return
        }
        
        // Prevent rapid successive loads of same variant
        if let lastLoadTime = loadingStartTime, 
           lastLoadedVariantId == variant.id,
           currentTime.timeIntervalSince(lastLoadTime) < 5.0 {
            return
        }
        
        // Increment load attempts
        loadAttempts[variant.id] = currentAttempts + 1
        
        
        // Set loading state with timestamp
        isLoadingVariant = true
        lastLoadedVariantId = variant.id
        loadingStartTime = currentTime
        loadingProgress = 0.0
        loadingMessage = "Preparing to load variant..."
        suppressDataUpdates = true
        
        // Perform the actual variant loading in a single operation without nested async calls
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.loadingProgress = 0.3
            self.loadingMessage = "Processing variant data..."
            
            // Process variant data synchronously to avoid timing issues
            let updatedSettings = variant.appliedTo(self.data.settings)
            let variantSelectedMap = variant.getStoredSelectedMap()
            let variantSelectionsName = variant.getStoredSelectionsName()
            
            self.loadingProgress = 0.7
            self.loadingMessage = "Updating application state..."
            
            // Create the updated data structure
            let updatedCurtainData = CurtainData(
                raw: self.data.raw,
                rawForm: self.data.rawForm,
                differentialForm: self.data.differentialForm,
                processed: self.data.processed,
                password: self.data.password,
                selections: self.data.selections,
                selectionsMap: self.data.selectionsMap,
                selectedMap: variantSelectedMap ?? self.data.selectedMap,
                selectionsName: variantSelectionsName ?? self.data.selectionsName,
                settings: updatedSettings,
                fetchUniprot: self.data.fetchUniprot,
                annotatedData: self.data.annotatedData,
                extraData: self.data.extraData,
                permanent: self.data.permanent
            )
            
            // Apply the changes with a single update after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.loadingProgress = 1.0
                self.loadingMessage = "Complete!"
                
                // Apply the data update with no animation to prevent triggering reactive updates
                withAnimation(.none) {
                    self.data = updatedCurtainData
                }
                
                // Success! Reset load attempts and circuit breaker for this variant
                self.loadAttempts[variant.id] = 0
                self.circuitBreakerTripped = false
                
                
                // Clean up loading state after the update is complete
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.isLoadingVariant = false
                    self.loadingProgress = 0.0
                    self.loadingMessage = ""
                    
                    // Keep data updates suppressed for longer to prevent immediate re-triggers
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        self.suppressDataUpdates = false
                        
                        // Send notification for plot refresh only after everything settles
                        NotificationCenter.default.post(
                            name: NSNotification.Name("VolcanoPlotRefresh"),
                            object: nil,
                            userInfo: ["reason": "settings_variant_loaded"]
                        )
                        
                        
                        // Clear the loaded variant ID after an extended period
                        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                            // Only clear if no new variant has been loaded
                            if self.lastLoadedVariantId == variant.id {
                                self.lastLoadedVariantId = nil
                                self.loadingStartTime = nil
                            }
                        }
                    }
                }
            }
        }
    }
    
    // Reset circuit breaker for debugging/recovery
    private func resetCircuitBreaker() {
        circuitBreakerTripped = false
        loadAttempts.removeAll()
        isLoadingVariant = false
        suppressDataUpdates = false
        lastLoadedVariantId = nil
        loadingStartTime = nil
    }
}

// MARK: - Settings Variant Supporting Views

struct VariantRowView: View {
    let variant: SettingsVariant
    let onLoad: () -> Void
    let onDelete: () -> Void
    let isLoading: Bool
    let isDisabled: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(variant.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    if !variant.description.isEmpty {
                        Text(variant.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("p: \(variant.pCutoff, specifier: "%.3f")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("FC: \(variant.log2FCCutoff, specifier: "%.2f")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            HStack {
                Text("Modified: \(variant.dateModified, style: .date)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button(action: onLoad) {
                    HStack(spacing: 4) {
                        if isLoading {
                            ProgressView()
                                .scaleEffect(0.6)
                        }
                        Text(isLoading ? "Loading..." : "Load")
                    }
                }
                .font(.caption)
                .buttonStyle(.borderedProminent)
                .controlSize(.mini)
                .disabled(isLoading || isDisabled)
            }
        }
        .contextMenu {
            Button("Load Variant", action: onLoad)
                .disabled(isLoading || isDisabled)
            Button("Delete Variant", role: .destructive, action: onDelete)
                .disabled(isLoading || isDisabled)
        }
        .swipeActions(edge: .trailing) {
            Button("Delete", role: .destructive, action: onDelete)
                .disabled(isLoading || isDisabled)
            Button("Load", action: onLoad)
                .tint(.blue)
                .disabled(isLoading || isDisabled)
        }
    }
}

struct SaveVariantSheet: View {
    @Environment(\.dismiss) private var dismiss
    let currentSettings: CurtainSettings
    let selectedMap: [String: [String: Bool]]?
    let selectionsName: [String]?
    let onSave: (SettingsVariant) -> Void
    
    @State private var name = ""
    @State private var description = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section("Variant Information") {
                    TextField("Name", text: $name)
                        .textInputAutocapitalization(.words)
                    
                    TextField("Description (Optional)", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section("Current Settings Preview") {
                    HStack {
                        Text("P-value Cutoff")
                        Spacer()
                        Text("\(currentSettings.pCutoff, specifier: "%.3f")")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Log2FC Cutoff")
                        Spacer()
                        Text("\(currentSettings.log2FCCutoff, specifier: "%.2f")")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Selected Proteins")
                        Spacer()
                        Text("\(selectedMap?.count ?? 0)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Selection Groups")
                        Spacer()
                        Text("\(selectionsName?.count ?? 0)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Annotations")
                        Spacer()
                        Text("\(currentSettings.textAnnotation.count)")
                            .foregroundColor(.secondary)
                    }
                    
                    if let selectionsName = selectionsName, !selectionsName.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Groups: \(selectionsName.joined(separator: ", "))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(3)
                        }
                    }
                }
            }
            .navigationTitle("Save Settings Variant")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveVariant()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
        .alert("Save Variant", isPresented: $showingAlert) {
            Button("OK") { dismiss() }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func saveVariant() {
        let variant = SettingsVariant(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            description: description.trimmingCharacters(in: .whitespacesAndNewlines),
            from: currentSettings,
            selectedMap: selectedMap,
            selectionsName: selectionsName
        )
        
        onSave(variant)
        alertMessage = "Settings variant '\(variant.name)' saved successfully!"
        showingAlert = true
    }
}

struct LoadVariantSheet: View {
    @Environment(\.dismiss) private var dismiss
    let variants: [SettingsVariant]
    let onLoad: (SettingsVariant) -> Void
    
    @State private var selectedVariant: SettingsVariant?
    
    var sortedVariants: [SettingsVariant] {
        variants.sorted { $0.dateModified > $1.dateModified }
    }
    
    var body: some View {
        NavigationView {
            List {
                if variants.isEmpty {
                    ContentUnavailableView(
                        "No Saved Variants",
                        systemImage: "gearshape.2",
                        description: Text("Save your current settings to create your first variant.")
                    )
                } else {
                    Section("Saved Variants") {
                        ForEach(sortedVariants, id: \.id) { variant in
                            VariantLoadRowView(
                                variant: variant,
                                isSelected: selectedVariant?.id == variant.id,
                                onTap: {
                                    selectedVariant = variant
                                }
                            )
                        }
                    }
                }
            }
            .navigationTitle("Load Settings Variant")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Load") {
                        if let variant = selectedVariant {
                            onLoad(variant)
                            dismiss()
                        }
                    }
                    .disabled(selectedVariant == nil)
                }
            }
        }
    }
}

struct VariantLoadRowView: View {
    let variant: SettingsVariant
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        HStack {
            Button(action: onTap) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(variant.name)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        if !variant.description.isEmpty {
                            Text(variant.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                        
                        HStack(spacing: 12) {
                            Text("p: \(variant.pCutoff, specifier: "%.3f")")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text("FC: \(variant.log2FCCutoff, specifier: "%.2f")")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Text("Modified: \(variant.dateModified, style: .date)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.blue)
                    } else {
                        Image(systemName: "circle")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
        }
        .contentShape(Rectangle())
    }
}

// MARK: - Helper Views

struct OverviewSection<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 8) {
                content
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
}

struct OverviewRow: View {
    let label: String
    let value: String
    let isExpandable: Bool
    @State private var isExpanded = false
    
    init(label: String, value: String, isExpandable: Bool = false) {
        self.label = label
        self.value = value
        self.isExpandable = isExpandable
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                if isExpandable {
                    Button(isExpanded ? "Less" : "More") {
                        withAnimation {
                            isExpanded.toggle()
                        }
                    }
                    .font(.caption)
                }
            }
            
            Text(value)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(isExpandable ? (isExpanded ? nil : 3) : nil)
        }
    }
}

struct PlotSettingsView: View {
    let settings: CurtainSettings
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Plot Configuration")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Title: \(settings.volcanoPlotTitle)")
                Text("Marker Size: \(settings.scatterPlotMarkerSize, specifier: "%.1f")")
                
                if let legendX = settings.volcanoPlotLegendX,
                   let legendY = settings.volcanoPlotLegendY {
                    Text("Legend Position: (\(legendX, specifier: "%.2f"), \(legendY, specifier: "%.2f"))")
                }
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct ProteinDetailRowView: View {
    let proteinId: String
    @Binding var curtainData: CurtainData?
    let selectedSelectionGroup: String
    let proteinList: [String]
    let proteinIndex: Int
    
    // Add chart presentation state
    @State private var showingChart = false
    @State private var chartType: ProteinChartType = .barChart
    
    private var proteinData: [String: Any]? {
        guard let curtainData = curtainData else { return nil }
        return curtainData.proteomicsData[proteinId] as? [String: Any]
    }
    
    private var displayName: String {
        guard let curtainData = curtainData else {
            return proteinId
        }

        // Use unified gene name resolution (SQLite first, then extraData fallback)
        if let geneName = curtainData.getPrimaryGeneNameForProtein(proteinId),
           geneName != proteinId {
            return "\(geneName) (\(proteinId))"
        }

        return proteinId
    }
    
    private var selectionGroups: [String] {
        guard let curtainData = curtainData else {
            print("[ProteinDetailRowView] selectionGroups: curtainData is nil for \(proteinId)")
            return []
        }
        guard let selectedMap = curtainData.selectedMap else {
            print("[ProteinDetailRowView] selectionGroups: selectedMap is nil for \(proteinId)")
            return []
        }
        guard let proteinSelections = selectedMap[proteinId] else {
            print("[ProteinDetailRowView] selectionGroups: no entry in selectedMap for '\(proteinId)', selectedMap keys count: \(selectedMap.count)")
            if selectedMap.count <= 5 {
                print("[ProteinDetailRowView] selectedMap keys: \(Array(selectedMap.keys))")
            } else {
                print("[ProteinDetailRowView] first 3 selectedMap keys: \(Array(selectedMap.keys.prefix(3)))")
            }
            return []
        }

        // Get only the selection groups where this protein is selected
        let groups = proteinSelections.compactMap { (selectionName, isSelected) in
            return isSelected ? selectionName : nil
        }
        if !groups.isEmpty {
            print("[ProteinDetailRowView] selectionGroups for \(proteinId): \(groups)")
        }
        return groups
    }
    
    private var selectionColors: [String] {
        guard let curtainData = curtainData else { return [] }

        let defaultColors = ["#FF6B6B", "#4ECDC4", "#45B7D1", "#96CEB4", "#FFEAA7", "#DDA0DD", "#98D8C8", "#F7DC6F"]
        return selectionGroups.enumerated().map { (index, selectionName) in
            return curtainData.settings.colorMap[selectionName] ?? defaultColors[index % defaultColors.count]
        }
    }
    
    private var isSignificantProtein: Bool {
        guard let curtainData = curtainData, let proteinData = proteinData else {
            return false
        }
        
        let fcColumn = curtainData.differentialForm.foldChange
        let sigColumn = curtainData.differentialForm.significant
        
        guard let foldChange = proteinData[fcColumn] as? Double,
              let pValue = proteinData[sigColumn] as? Double else {
            return false
        }
        
        let finalPValue = curtainData.differentialForm.transformSignificant 
            ? pow(10, -pValue)  // Convert back from -log10 transformation
            : pValue
        
        let isFCSignificant = abs(foldChange) >= curtainData.settings.log2FCCutoff
        let isPValueSignificant = finalPValue <= curtainData.settings.pCutoff
        
        return isFCSignificant && isPValueSignificant
    }
    
    // MARK: - Annotation Management
    
    private func generateAnnotationTitle(for proteinId: String) -> String {
        guard let curtainData = curtainData else { return proteinId }

        // Use unified gene name resolution (SQLite first, then extraData fallback)
        if let geneName = curtainData.getPrimaryGeneNameForProtein(proteinId),
           geneName != proteinId {
            return "\(geneName)(\(proteinId))"
        }

        return proteinId
    }
    
    /// Check if annotation exists for this protein
    private func hasAnnotation(for proteinId: String) -> Bool {
        guard let curtainData = curtainData else { return false }
        let title = generateAnnotationTitle(for: proteinId)
        return curtainData.settings.textAnnotation.keys.contains(title)
    }
    
    /// Add annotation for protein (matching PointInteractionModal logic)
    private func addAnnotation(for proteinId: String) {
        guard let curtainData = curtainData, let proteinData = proteinData else { return }
        
        let title = generateAnnotationTitle(for: proteinId)
        
        // Check if annotation already exists
        if hasAnnotation(for: proteinId) {
            return
        }
        
        // Get protein coordinates from data
        let fcColumn = curtainData.differentialForm.foldChange
        let sigColumn = curtainData.differentialForm.significant
        
        guard let foldChange = proteinData[fcColumn] as? Double,
              let pValue = proteinData[sigColumn] as? Double else {
            return
        }
        
        // Calculate plot coordinates
        let plotX = foldChange
        let plotY = curtainData.differentialForm.transformSignificant 
            ? pValue  // Already -log10 transformed
            : -log10(max(pValue, 1e-300))  // Apply transformation
        
        let annotationData: [String: Any] = [
            "primary_id": proteinId,
            "title": title,
            "data": [
                "x": plotX,
                "y": plotY,
                "text": "<b>\(title)</b>",
                "showarrow": true,
                "ax": -20,
                "ay": -20,
                "arrowhead": 1,
                "arrowsize": 1,
                "arrowwidth": 2,
                "arrowcolor": "black",
                "font": [
                    "size": 12,
                    "color": "black"
                ],
                "bgcolor": "rgba(255, 255, 255, 0.8)",
                "bordercolor": "black",
                "borderwidth": 1,
                "showannotation": true,
                "annotationID": title
            ]
        ]
        
        // Update textAnnotation
        var updatedTextAnnotation = curtainData.settings.textAnnotation
        updatedTextAnnotation[title] = AnyCodable(annotationData)
        
        // Update CurtainData with new annotation
        updateCurtainDataWithNewAnnotations(updatedTextAnnotation)
        
    }
    
    /// Remove annotation for protein
    private func removeAnnotation(for proteinId: String) {
        guard let curtainData = curtainData else { return }
        
        let title = generateAnnotationTitle(for: proteinId)
        
        // Check if annotation exists
        if !hasAnnotation(for: proteinId) {
            return
        }
        
        // Remove annotation
        var updatedTextAnnotation = curtainData.settings.textAnnotation
        updatedTextAnnotation.removeValue(forKey: title)
        
        // Update CurtainData
        updateCurtainDataWithNewAnnotations(updatedTextAnnotation)
        
    }
    
    /// Update CurtainData with new textAnnotation (reusable helper)
    private func updateCurtainDataWithNewAnnotations(_ updatedTextAnnotation: [String: AnyCodable]) {
        guard let curtainData = curtainData else { return }
        
        let updatedSettings = CurtainSettings(
            fetchUniprot: curtainData.settings.fetchUniprot,
            inputDataCols: curtainData.settings.inputDataCols,
            probabilityFilterMap: curtainData.settings.probabilityFilterMap,
            barchartColorMap: curtainData.settings.barchartColorMap,
            pCutoff: curtainData.settings.pCutoff,
            log2FCCutoff: curtainData.settings.log2FCCutoff,
            description: curtainData.settings.description,
            uniprot: curtainData.settings.uniprot,
            colorMap: curtainData.settings.colorMap,
            academic: curtainData.settings.academic,
            backGroundColorGrey: curtainData.settings.backGroundColorGrey,
            currentComparison: curtainData.settings.currentComparison,
            version: curtainData.settings.version,
            currentId: curtainData.settings.currentId,
            fdrCurveText: curtainData.settings.fdrCurveText,
            fdrCurveTextEnable: curtainData.settings.fdrCurveTextEnable,
            prideAccession: curtainData.settings.prideAccession,
            project: curtainData.settings.project,
            sampleOrder: curtainData.settings.sampleOrder,
            sampleVisible: curtainData.settings.sampleVisible,
            conditionOrder: curtainData.settings.conditionOrder,
            sampleMap: curtainData.settings.sampleMap,
            volcanoAxis: curtainData.settings.volcanoAxis,
            textAnnotation: updatedTextAnnotation,  // Updated textAnnotation
            volcanoPlotTitle: curtainData.settings.volcanoPlotTitle,
            visible: curtainData.settings.visible,
            volcanoPlotGrid: curtainData.settings.volcanoPlotGrid,
            volcanoPlotDimension: curtainData.settings.volcanoPlotDimension,
            volcanoAdditionalShapes: curtainData.settings.volcanoAdditionalShapes,
            volcanoPlotLegendX: curtainData.settings.volcanoPlotLegendX,
            volcanoPlotLegendY: curtainData.settings.volcanoPlotLegendY,
            defaultColorList: curtainData.settings.defaultColorList,
            scatterPlotMarkerSize: curtainData.settings.scatterPlotMarkerSize,
            plotFontFamily: curtainData.settings.plotFontFamily,
            stringDBColorMap: curtainData.settings.stringDBColorMap,
            interactomeAtlasColorMap: curtainData.settings.interactomeAtlasColorMap,
            proteomicsDBColor: curtainData.settings.proteomicsDBColor,
            networkInteractionSettings: curtainData.settings.networkInteractionSettings,
            rankPlotColorMap: curtainData.settings.rankPlotColorMap,
            rankPlotAnnotation: curtainData.settings.rankPlotAnnotation,
            legendStatus: curtainData.settings.legendStatus,
            selectedComparison: curtainData.settings.selectedComparison,
            imputationMap: curtainData.settings.imputationMap,
            enableImputation: curtainData.settings.enableImputation,
            viewPeptideCount: curtainData.settings.viewPeptideCount,
            peptideCountData: curtainData.settings.peptideCountData,
            volcanoConditionLabels: curtainData.settings.volcanoConditionLabels,
            volcanoTraceOrder: curtainData.settings.volcanoTraceOrder,
            volcanoPlotYaxisPosition: curtainData.settings.volcanoPlotYaxisPosition,
            customVolcanoTextCol: curtainData.settings.customVolcanoTextCol,
            barChartConditionBracket: curtainData.settings.barChartConditionBracket,
            columnSize: curtainData.settings.columnSize,
            chartYAxisLimits: curtainData.settings.chartYAxisLimits,
            individualYAxisLimits: curtainData.settings.individualYAxisLimits,
            violinPointPos: curtainData.settings.violinPointPos,
            networkInteractionData: curtainData.settings.networkInteractionData,
            enrichrGeneRankMap: curtainData.settings.enrichrGeneRankMap,
            enrichrRunList: curtainData.settings.enrichrRunList,
            extraData: curtainData.settings.extraData,
            enableMetabolomics: curtainData.settings.enableMetabolomics,
            metabolomicsColumnMap: curtainData.settings.metabolomicsColumnMap,
            encrypted: curtainData.settings.encrypted,
            dataAnalysisContact: curtainData.settings.dataAnalysisContact,
            markerSizeMap: curtainData.settings.markerSizeMap
        )
        
        // Update CurtainData
        var newCurtainData = CurtainData(
            raw: curtainData.raw,
            rawForm: curtainData.rawForm,
            differentialForm: curtainData.differentialForm,
            processed: curtainData.processed,
            password: curtainData.password,
            selections: curtainData.selections,
            selectionsMap: curtainData.selectionsMap,
            selectedMap: curtainData.selectedMap,
            selectionsName: curtainData.selectionsName,
            settings: updatedSettings,
            fetchUniprot: curtainData.fetchUniprot,
            annotatedData: curtainData.annotatedData,
            extraData: curtainData.extraData,
            permanent: curtainData.permanent,
            bypassUniProt: curtainData.bypassUniProt,
            dbPath: curtainData.dbPath
        )
        // Ensure uniprotDB is preserved
        newCurtainData.uniprotDB = curtainData.uniprotDB
        self.curtainData = newCurtainData
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                // Protein name with selection indicators
                HStack {
                    Text(displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(1)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    // Selection group indicators 
                    HStack(spacing: 4) {
                        ForEach(Array(zip(selectionGroups, selectionColors)), id: \.0) { (groupName, color) in
                            Circle()
                                .fill(Color(hex: color) ?? Color.gray)
                                .frame(width: 8, height: 8)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white, lineWidth: 0.5)
                                )
                        }
                    }
                }
                
                // Selection groups (always show if present, independent of proteinData lookup)
                if !selectionGroups.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(Array(zip(selectionGroups, selectionColors).prefix(3)), id: \.0) { (groupName, color) in
                            Text(groupName)
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(Color(hex: color) ?? .blue)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background((Color(hex: color) ?? .blue).opacity(0.2))
                                .cornerRadius(4)
                        }
                        if selectionGroups.count > 3 {
                            Text("+\(selectionGroups.count - 3)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // Protein statistics (like volcano plot)
                if let proteinData = proteinData, let curtainData = curtainData {
                    let fcColumn = curtainData.differentialForm.foldChange
                    let sigColumn = curtainData.differentialForm.significant

                    HStack {
                        if let foldChange = proteinData[fcColumn] as? Double {
                            Text("FC: \(foldChange, specifier: "%.3f")")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(foldChange > 0 ? .red : .blue)
                        }

                        Spacer()

                        if let pValue = proteinData[sigColumn] as? Double {
                            let displayPValue: Double = curtainData.differentialForm.transformSignificant
                                ? pow(10, -pValue)  // pValue is already -log10 transformed
                                : pValue            // pValue is raw

                            Text("p: \(displayPValue, specifier: "%.2e")")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        // Significance indicator
                        if isSignificantProtein {
                            Image(systemName: "star.fill")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                } else if selectionGroups.isEmpty {
                    Text("Tap to view charts")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Action buttons
            VStack(spacing: 8) {
                // Chart button
                Button(action: {
                    showingChart = true
                }) {
                    Image(systemName: "chart.bar.fill")
                        .font(.caption)
                        .foregroundColor(.blue)
                        .frame(width: 24, height: 24)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())
                
                // Annotation toggle button
                Button(action: {
                    if hasAnnotation(for: proteinId) {
                        removeAnnotation(for: proteinId)
                    } else {
                        addAnnotation(for: proteinId)
                    }
                }) {
                    Image(systemName: hasAnnotation(for: proteinId) ? "text.bubble.fill" : "text.bubble")
                        .font(.caption)
                        .foregroundColor(hasAnnotation(for: proteinId) ? .orange : .gray)
                        .frame(width: 24, height: 24)
                        .background((hasAnnotation(for: proteinId) ? Color.orange : Color.gray).opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .sheet(isPresented: $showingChart) {
            if curtainData != nil {
                ProteinChartView(
                    proteinId: proteinId,
                    curtainData: Binding(
                        get: { curtainData! },
                        set: { newValue in 
                            curtainData = newValue 
                        }
                    ),
                    chartType: $chartType,
                    isPresented: $showingChart,
                    proteinList: proteinList,
                    initialIndex: proteinIndex
                )
            }
        }
    }
}

#Preview {
    let sampleCurtain = CurtainEntity(
        linkId: "sample-id",
        dataDescription: "Sample Proteomics Dataset",
        curtainType: "TP",
        sourceHostname: "example.com"
    )
    
    return CurtainDetailsView(curtain: sampleCurtain)
}
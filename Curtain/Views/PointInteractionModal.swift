//
//  PointInteractionModal.swift
//  Curtain
//
//  Created by Toan Phung on 04/08/2025.
//

import SwiftUI


struct PointInteractionModal: View {
    let clickData: VolcanoPointClickData
    @Binding var curtainData: CurtainData
    @ObservedObject var selectionManager: SelectionManager
    @ObservedObject var annotationManager: AnnotationManager
    @ObservedObject var proteinSearchManager: ProteinSearchManager
    @Binding var isPresented: Bool
    
    @State private var selectedTab = 0
    @State private var newSelectionName = ""
    @State private var selectedProteinIds: Set<String> = []
    @State private var includeClickedProtein = true
    
    var body: some View {
        NavigationStack {
            List {
                // Header
                Section {
                    headerContent
                }

                // Tab picker
                Section {
                    Picker("Action", selection: $selectedTab) {
                        Text("Select").tag(0)
                        Text("Annotate").tag(1)
                        Text("Details").tag(2)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .listRowInsets(EdgeInsets())
                    .padding(.vertical, 4)
                    .accessibilityIdentifier("pointInteractionTabPicker")
                }

                // Content based on selected tab
                switch selectedTab {
                case 0:
                    selectionSections
                case 1:
                    annotationSections
                case 2:
                    detailsSections
                default:
                    selectionSections
                }
            }
            .listStyle(.insetGrouped)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Protein Interaction")
                        .font(.headline)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .fixedSize()
                    .accessibilityIdentifier("pointInteractionCancelButton")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        let pendingAnnotations = buildPendingAnnotations()
                        performAction()
                        isPresented = false
                        // Post annotations via notification so the parent can apply them
                        // to its own @State, avoiding sheet binding write-back issues
                        if !pendingAnnotations.isEmpty {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                NotificationCenter.default.post(
                                    name: NSNotification.Name("VolcanoAnnotationsCreated"),
                                    object: nil,
                                    userInfo: ["annotations": pendingAnnotations]
                                )
                            }
                        }
                    }
                    .fixedSize()
                    .disabled(!canPerformAction)
                    .accessibilityIdentifier("pointInteractionDoneButton")
                }
            }
        }
        .onAppear {
            // Pre-select the clicked protein
            selectedProteinIds.insert(clickData.clickedProtein.id)
        }
    }
    
    // MARK: - Header Content

    private var headerContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(proteinDisplayName(clickData.clickedProtein))
                    .font(.headline)
                    .lineLimit(1)

                Spacer()

                HStack(spacing: 12) {
                    Text("FC: \(clickData.clickedProtein.log2FC, specifier: "%.3f")")
                        .font(.callout)
                        .fontWeight(.medium)

                    Text("p: \(clickData.clickedProtein.pValue, specifier: "%.2e")")
                        .font(.callout)
                        .foregroundColor(.secondary)
                }
            }

            if !clickData.nearbyProteins.isEmpty {
                Text("\(clickData.nearbyProteins.count) nearby proteins found")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
        }
    }
    
    // MARK: - Selection Sections

    @ViewBuilder
    private var selectionSections: some View {
        // Quick Actions
        Section("Quick Actions") {
            Button(action: {
                autoCreateSelectionFromNearbyProteins()
            }) {
                HStack {
                    Image(systemName: "wand.and.stars")
                        .foregroundColor(.blue)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Auto-Create from Nearby Proteins")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("Creates selection with \(clickData.nearbyProteins.count + 1) proteins")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .disabled(clickData.nearbyProteins.isEmpty)

            if !selectedProteinIds.isEmpty {
                Button(action: {
                    autoCreateSelectionFromSelected()
                }) {
                    HStack {
                        Image(systemName: "checkmark.circle")
                            .foregroundColor(.green)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Auto-Create from Selected")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text("Creates selection with \(selectedProteinIds.count) selected proteins")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }

        // Manual Selection
        Section("Manual Selection") {
            Toggle("Include clicked protein", isOn: $includeClickedProtein)

            TextField("Selection name...", text: $newSelectionName)
        }

        // Protein list
        Section("Select Proteins (\(selectedProteinIds.count) selected)") {
            proteinSelectionRow(clickData.clickedProtein, isClickedProtein: true)

            ForEach(clickData.nearbyProteins, id: \.protein.id) { nearbyProtein in
                proteinSelectionRow(nearbyProtein.protein, nearbyProtein: nearbyProtein)
            }
        }
    }

    private func proteinSelectionRow(_ protein: ProteinPoint, nearbyProtein: NearbyProtein? = nil, isClickedProtein: Bool = false) -> some View {
        HStack {
            // Selection checkbox
            Button(action: {
                if selectedProteinIds.contains(protein.id) {
                    selectedProteinIds.remove(protein.id)
                } else {
                    selectedProteinIds.insert(protein.id)
                }
            }) {
                Image(systemName: selectedProteinIds.contains(protein.id) ? "checkmark.square.fill" : "square")
                    .foregroundColor(selectedProteinIds.contains(protein.id) ? .blue : .gray)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(proteinDisplayName(protein))
                        .font(.subheadline)
                        .fontWeight(isClickedProtein ? .semibold : .regular)
                    
                    if isClickedProtein {
                        Text("(Clicked)")
                            .font(.caption)
                            .foregroundColor(.blue)
                            .fontWeight(.medium)
                    }
                    
                    Spacer()
                    
                    // Show protein color
                    Circle()
                        .fill(Color(hex: protein.color) ?? Color.gray)
                        .frame(width: 10, height: 10)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 1)
                        )
                }
                
                HStack(spacing: 12) {
                    Text("FC: \(protein.log2FC, specifier: "%.3f")")
                        .font(.caption)
                        .foregroundColor(protein.log2FC > 0 ? .red : .blue)
                    
                    Text("p: \(protein.pValue, specifier: "%.2e")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let nearby = nearbyProtein {
                        Text("dist: \(nearby.distance, specifier: "%.3f")")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }
            
            Spacer()
            
            if protein.isSignificant {
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)
                    .font(.caption)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(selectedProteinIds.contains(protein.id) ? Color.blue.opacity(0.1) : Color(.systemGray6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(selectedProteinIds.contains(protein.id) ? Color.blue : Color.clear, lineWidth: 1)
        )
    }
    
    // MARK: - Annotation Sections

    @ViewBuilder
    private var annotationSections: some View {
        Section {
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(.blue)
                Text("Annotations will be created for all selected proteins")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Toggle("Include clicked protein", isOn: $includeClickedProtein)
        } header: {
            Text("Bulk Annotation")
        }

        Section("Select Proteins to Annotate (\(selectedProteinIds.count) selected)") {
            proteinAnnotationRow(clickData.clickedProtein, isClickedProtein: true)

            ForEach(clickData.nearbyProteins, id: \.protein.id) { nearbyProtein in
                proteinAnnotationRow(nearbyProtein.protein, nearbyProtein: nearbyProtein)
            }
        }

        Section("Annotation Preview") {
            ForEach(Array(getAnnotationTargetProteins()), id: \.self) { proteinId in
                if let protein = getProteinById(proteinId) {
                    Text(generateAnnotationTitle(for: protein))
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
        }
    }

    // MARK: - Details Sections

    @ViewBuilder
    private var detailsSections: some View {
        Section("Clicked Protein") {
            proteinDetailCard(clickData.clickedProtein)
        }

        // PTM Viewer button - show if data is PTM type
        if curtainData.differentialForm.isPTM {
            Section("PTM Analysis") {
                Button(action: {
                    openPTMViewer()
                }) {
                    HStack {
                        Image(systemName: "atom")
                            .foregroundColor(.purple)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("View PTM Details")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text("Sequence alignment and modification sites")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                    }
                }
            }
        }

        if !clickData.nearbyProteins.isEmpty {
            Section("Nearby Proteins (\(clickData.nearbyProteins.count))") {
                ForEach(clickData.nearbyProteins.prefix(10), id: \.protein.id) { nearbyProtein in
                    nearbyProteinCard(nearbyProtein)
                }

                if clickData.nearbyProteins.count > 10 {
                    Text("... and \(clickData.nearbyProteins.count - 10) more")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    /// Opens PTM viewer for the clicked protein
    private func openPTMViewer() {
        // Get the accession from the protein - for PTM data this is typically stored in the protein ID
        // or can be extracted from the data
        let accession = getAccessionForProtein(clickData.clickedProtein)

        // Close this modal
        isPresented = false

        // Post notification to open PTM viewer
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            NotificationCenter.default.post(
                name: NSNotification.Name("OpenPTMViewer"),
                object: nil,
                userInfo: ["accession": accession]
            )
        }
    }

    /// Gets the accession for a protein point - for PTM data this is stored separately
    private func getAccessionForProtein(_ protein: ProteinPoint) -> String {
        // For PTM data, use the accession field if available, otherwise fall back to primaryID
        return protein.accession ?? protein.primaryID
    }
    
    // MARK: - Helper Views
    
    private func proteinInfoCard(_ protein: ProteinPoint) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(proteinDisplayName(protein))
                .font(.subheadline)
                .fontWeight(.medium)
            
            HStack {
                Label("FC: \(protein.log2FC, specifier: "%.3f")", systemImage: "arrow.up.arrow.down")
                    .font(.caption)
                
                Spacer()
                
                Label("p: \(protein.pValue, specifier: "%.2e")", systemImage: "p.circle")
                    .font(.caption)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    private func proteinDetailCard(_ protein: ProteinPoint) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(proteinDisplayName(protein))
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                // Show protein color indicator
                Circle()
                    .fill(Color(hex: protein.color) ?? Color.gray)
                    .frame(width: 12, height: 12)
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 1)
                    )
            }
            
            if let proteinName = protein.proteinName, proteinName != protein.primaryID {
                Text("Protein: \(proteinName)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Show selection groups if available
            if let selections = getProteinSelections(protein.id), !selections.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Selection Groups:")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                    
                    ForEach(selections, id: \.self) { selection in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color(hex: getSelectionColor(selection)) ?? Color.gray)
                                .frame(width: 8, height: 8)
                            Text(selection)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Log2 FC: \(protein.log2FC, specifier: "%.6f")")
                        .font(.caption)
                    Text("p-value: \(protein.pValue, specifier: "%.6e")")
                        .font(.caption)
                    Text("-log10(p): \(protein.negLog10PValue, specifier: "%.3f")")
                        .font(.caption)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    if protein.isSignificant {
                        Label("Significant", systemImage: "star.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                    
                    Text("(\(clickData.plotCoordinates.x, specifier: "%.3f"), \(clickData.plotCoordinates.y, specifier: "%.3f"))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    private func nearbyProteinCard(_ nearbyProtein: NearbyProtein) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(proteinDisplayName(nearbyProtein.protein))
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text("Distance: \(nearbyProtein.distance, specifier: "%.3f")")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .fontWeight(.medium)
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("FC: \(nearbyProtein.protein.log2FC, specifier: "%.3f")")
                        .font(.caption)
                    Text("p: \(nearbyProtein.protein.pValue, specifier: "%.2e")")
                        .font(.caption)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("ΔX: \(nearbyProtein.deltaX, specifier: "%.3f")")
                        .font(.caption)
                        .foregroundColor(.blue)
                    Text("ΔY: \(nearbyProtein.deltaY, specifier: "%.3f")")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    // MARK: - Helper Methods
    
    private func proteinDisplayName(_ protein: ProteinPoint) -> String {
        if let geneNames = protein.geneNames, !geneNames.isEmpty, geneNames != protein.primaryID {
            return "\(geneNames) (\(protein.primaryID))"
        } else {
            return protein.primaryID
        }
    }
    
    private func getAnnotationTargetProteins() -> Set<String> {
        var targetIds = selectedProteinIds
        if includeClickedProtein {
            targetIds.insert(clickData.clickedProtein.id)
        } else {
            targetIds.remove(clickData.clickedProtein.id)
        }
        return targetIds
    }
    
    private func getProteinById(_ proteinId: String) -> ProteinPoint? {
        // Check clicked protein first
        if clickData.clickedProtein.id == proteinId {
            return clickData.clickedProtein
        }
        
        // Check nearby proteins
        return clickData.nearbyProteins.first { $0.protein.id == proteinId }?.protein
    }
    
    private func proteinAnnotationRow(_ protein: ProteinPoint, nearbyProtein: NearbyProtein? = nil, isClickedProtein: Bool = false) -> some View {
        HStack {
            // Selection checkbox for annotation
            Button(action: {
                if selectedProteinIds.contains(protein.id) {
                    selectedProteinIds.remove(protein.id)
                } else {
                    selectedProteinIds.insert(protein.id)
                }
            }) {
                Image(systemName: selectedProteinIds.contains(protein.id) ? "checkmark.square.fill" : "square")
                    .foregroundColor(selectedProteinIds.contains(protein.id) ? .green : .gray)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(proteinDisplayName(protein))
                        .font(.subheadline)
                        .fontWeight(isClickedProtein ? .semibold : .regular)
                    
                    if isClickedProtein {
                        Text("(Clicked)")
                            .font(.caption)
                            .foregroundColor(.blue)
                            .fontWeight(.medium)
                    }
                    
                    Spacer()
                    
                    // Show protein color
                    Circle()
                        .fill(Color(hex: protein.color) ?? Color.gray)
                        .frame(width: 10, height: 10)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 1)
                        )
                }
                
                HStack(spacing: 12) {
                    Text("FC: \(protein.log2FC, specifier: "%.3f")")
                        .font(.caption)
                        .foregroundColor(protein.log2FC > 0 ? .red : .blue)
                    
                    Text("p: \(protein.pValue, specifier: "%.2e")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let nearby = nearbyProtein {
                        Text("dist: \(nearby.distance, specifier: "%.3f")")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
                
                // Show annotation preview
                Text("→ \(generateAnnotationTitle(for: protein))")
                    .font(.caption2)
                    .foregroundColor(.green)
                    .italic()
            }
            
            Spacer()
            
            if protein.isSignificant {
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)
                    .font(.caption)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(selectedProteinIds.contains(protein.id) ? Color.green.opacity(0.1) : Color(.systemGray6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(selectedProteinIds.contains(protein.id) ? Color.green : Color.clear, lineWidth: 1)
        )
    }
    
    /// - If gene names exist and they're not empty: "geneName(proteinId)"
    /// - Otherwise: just "proteinId"
    private func generateAnnotationTitle(for protein: ProteinPoint) -> String {
        if let geneNames = protein.geneNames, 
           !geneNames.isEmpty, 
           geneNames != protein.primaryID {
            return "\(geneNames)(\(protein.primaryID))"
        } else {
            return protein.primaryID
        }
    }
    
    private var canPerformAction: Bool {
        switch selectedTab {
        case 0: // Selection
            let finalSelectedIds = getFinalSelectedProteinIds()
            return !newSelectionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !finalSelectedIds.isEmpty
        case 1: // Annotation
            return !getAnnotationTargetProteins().isEmpty
        default:
            return true
        }
    }
    
    private func getFinalSelectedProteinIds() -> Set<String> {
        var finalIds = selectedProteinIds
        if includeClickedProtein {
            finalIds.insert(clickData.clickedProtein.id)
        } else {
            finalIds.remove(clickData.clickedProtein.id)
        }
        return finalIds
    }
    
    // MARK: - Auto-Creation Methods
    
    private func autoCreateSelectionFromNearbyProteins() {
        // Create selection with all nearby proteins, optionally including clicked protein
        var allProteinIds = Set<String>()
        
        if includeClickedProtein {
            allProteinIds.insert(clickData.clickedProtein.id)
        }
        
        for nearbyProtein in clickData.nearbyProteins {
            allProteinIds.insert(nearbyProtein.protein.id)
        }
        
        // Generate automatic name based on clicked protein
        let clickedProteinName = proteinDisplayName(clickData.clickedProtein)
        let includeText = includeClickedProtein ? "including" : "near"
        let selectionName = "Proteins \(includeText) \(clickedProteinName) (\(allProteinIds.count) proteins)"
        
        createAutomaticSelection(name: selectionName, proteinIds: allProteinIds)
    }
    
    private func autoCreateSelectionFromSelected() {
        let finalIds = getFinalSelectedProteinIds()
        guard !finalIds.isEmpty else { return }
        
        // Generate automatic name
        let clickedProteinName = proteinDisplayName(clickData.clickedProtein)
        let selectionName = "Selected near \(clickedProteinName) (\(finalIds.count) proteins)"
        
        createAutomaticSelection(name: selectionName, proteinIds: finalIds)
    }
    
    private func createAutomaticSelection(name: String, proteinIds: Set<String>) {
        guard !proteinIds.isEmpty else { return }
        
        // Create search list using protein search manager 
        let _ = proteinSearchManager.createSearchListFromProteinIds(
            name: name,
            proteinIds: proteinIds,
            curtainData: &curtainData,
            description: "Auto-created from volcano plot nearby selection"
        )
        
        // Also update legacy selection manager for backward compatibility
        let colors = ["#FF6B6B", "#4ECDC4", "#45B7D1", "#96CEB4", "#FFEAA7", "#DDA0DD", "#98D8C8", "#F7DC6F"]
        let color = colors[selectionManager.selections.count % colors.count]
        
        selectionManager.createSelection(
            name: name,
            proteinIds: proteinIds,
            color: color
        )
        
        // Close the modal after successful creation
        isPresented = false
    }
    
    private func performAction() {
        switch selectedTab {
        case 0: 
            let finalSelectedIds = getFinalSelectedProteinIds()
            guard !newSelectionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !finalSelectedIds.isEmpty else { return }
            
            // Create search list using protein search manager 
            let _ = proteinSearchManager.createSearchListFromProteinIds(
                name: newSelectionName.trimmingCharacters(in: .whitespacesAndNewlines),
                proteinIds: finalSelectedIds,
                curtainData: &curtainData,
                description: "Created from volcano plot interaction"
            )
            
            // Also update legacy selection manager for backward compatibility
            let colors = ["#FF6B6B", "#4ECDC4", "#45B7D1", "#96CEB4", "#FFEAA7", "#DDA0DD", "#98D8C8", "#F7DC6F"]
            let color = colors[selectionManager.selections.count % colors.count]
            
            selectionManager.createSelection(
                name: newSelectionName.trimmingCharacters(in: .whitespacesAndNewlines),
                proteinIds: finalSelectedIds,
                color: color
            )
            
        case 1: // Create annotation(s) automatically
            let targetProteins = getAnnotationTargetProteins()
            for proteinId in targetProteins {
                if let protein = getProteinById(proteinId) {
                    addAnnotationForProtein(protein)
                }
            }
            
        default:
            break
        }
    }
    
    /// Build annotation data dict for all target proteins (without mutating curtainData)
    /// Returns [title: annotationData] to be applied by the parent view via notification
    private func buildPendingAnnotations() -> [String: [String: Any]] {
        guard selectedTab == 1 else { return [:] }
        var result: [String: [String: Any]] = [:]
        let targetProteins = getAnnotationTargetProteins()
        let existingKeys = Set(curtainData.settings.textAnnotation.keys)

        for proteinId in targetProteins {
            guard let protein = getProteinById(proteinId) else { continue }
            let title = generateAnnotationTitle(for: protein)
            guard !existingKeys.contains(title) else { continue }

            let plotX: Double
            let plotY: Double
            if protein.id == clickData.clickedProtein.id {
                plotX = clickData.plotCoordinates.x
                plotY = clickData.plotCoordinates.y
            } else {
                plotX = protein.log2FC
                plotY = protein.negLog10PValue
            }

            let annotationData: [String: Any] = [
                "primary_id": protein.id,
                "title": title,
                "data": [
                    "xref": "x",
                    "yref": "y",
                    "x": plotX,
                    "y": plotY,
                    "text": "<b>\(title)</b>",
                    "showarrow": true,
                    "arrowhead": 1,
                    "arrowsize": 1,
                    "arrowwidth": 1,
                    "arrowcolor": "#000000",
                    "ax": -20,
                    "ay": -20,
                    "xanchor": "center",
                    "yanchor": "bottom",
                    "font": [
                        "size": 15,
                        "color": "#000000",
                        "family": "Arial, sans-serif"
                    ],
                    "showannotation": true,
                    "annotationID": title
                ]
            ]
            result[title] = annotationData
        }
        return result
    }

    private func addAnnotationForProtein(_ protein: ProteinPoint) {
        let title = generateAnnotationTitle(for: protein)
        
        // Check if annotation already exists to avoid duplicates
        let existingAnnotations = curtainData.settings.textAnnotation
        if existingAnnotations.keys.contains(title) {
            return
        }
        
        // Use clickData coordinates for clicked protein, use protein's own coordinates for nearby proteins
        let plotX: Double
        let plotY: Double
        
        if protein.id == clickData.clickedProtein.id {
            // For clicked protein, use the click coordinates (these are processed and match the plot)
            plotX = clickData.plotCoordinates.x
            plotY = clickData.plotCoordinates.y
        } else {
            // For nearby proteins, use their processed coordinates (log2FC and negLog10PValue are already processed)
            plotX = protein.log2FC
            plotY = protein.negLog10PValue
        }
        
        let annotationData: [String: Any] = [
            "primary_id": protein.id,
            "title": title,
            "data": [
                "xref": "x",
                "yref": "y",
                "x": plotX,  // Use correct plot coordinates that match the actual plotted points
                "y": plotY,  // Use correct plot coordinates that match the actual plotted points
                "text": "<b>\(title)</b>",
                "showarrow": true,
                "arrowhead": 1,
                "arrowsize": 1,
                "arrowwidth": 1,
                "arrowcolor": "#000000",  
                "ax": -20,
                "ay": -20,
                "xanchor": "center",      
                "yanchor": "bottom",      
                "font": [
                    "size": 15,
                    "color": "#000000",
                    "family": "Arial, sans-serif"
                ],
                "showannotation": true,
                "annotationID": title
            ]
        ]
        
        // Update textAnnotation in CurtainData directly 
        var updatedTextAnnotation = curtainData.settings.textAnnotation
        updatedTextAnnotation[title] = AnyCodable(annotationData)
        
        // Create updated settings with new textAnnotation
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
            textAnnotation: updatedTextAnnotation, // Updated textAnnotation
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
        
        // Create new CurtainData with updated settings
        curtainData = CurtainData(
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
            dbPath: curtainData.dbPath,
            linkId: curtainData.linkId
        )

    }
    
    // MARK: - Selection and Color Helper Methods
    
    /// Get selection groups that this protein belongs to
    private func getProteinSelections(_ proteinId: String) -> [String]? {
        guard let selectedMap = curtainData.selectedMap,
              let selectionForId = selectedMap[proteinId] else {
            return nil
        }
        
        let activeSelections = selectionForId.compactMap { (selectionName, isSelected) -> String? in
            return isSelected ? selectionName : nil
        }
        
        return activeSelections.isEmpty ? nil : activeSelections
    }
    
    /// Get the color for a specific selection group
    private func getSelectionColor(_ selectionName: String) -> String {
        return curtainData.settings.colorMap[selectionName] ?? "#808080"
    }
}
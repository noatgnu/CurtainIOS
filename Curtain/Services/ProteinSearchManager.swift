//
//  ProteinSearchManager.swift
//  Curtain
//
//  Created by Toan Phung on 04/08/2025.
//

import Foundation


struct SearchSession {
    var searchLists: [SearchList] = []
    var activeFilters: Set<String> = []
    var activeStoredSelections: Set<String> = []
}


class ProteinSearchManager: ObservableObject {
    @Published var searchSession = SearchSession()
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var searchProgress: String = ""
    @Published var proteinsFound: Int = 0
    
    private let searchService = ProteinSearchService()
    private let defaultColors = ["#FF6B6B", "#4ECDC4", "#45B7D1", "#96CEB4", "#FFEAA7", "#DDA0DD", "#98D8C8", "#F7DC6F", "#AED6F1", "#F8C471"]
    
    // MARK: - Core Search List Management
    
    func createSearchList(
        name: String,
        searchText: String,
        searchType: SearchType,
        curtainData: inout CurtainData,
        color: String? = nil,
        description: String? = nil
    ) async -> SearchList? {
        
        await MainActor.run {
            isLoading = true
            errorMessage = nil
            searchProgress = "Starting search..."
            proteinsFound = 0
        }

        // Perform batch search 
        await MainActor.run {
            searchProgress = "Searching for proteins..."
        }

        let searchResults = await searchService.performBatchSearch(
            inputText: searchText,
            searchType: searchType,
            curtainData: curtainData
        )

        // Collect all matched protein IDs with progress updates
        var allMatchedProteins: Set<String> = []
        var allSearchTerms: [String] = []

        for (index, result) in searchResults.enumerated() {
            allMatchedProteins.formUnion(result.matchedProteins)
            allSearchTerms.append(result.searchTerm)

            // Update progress
            let count = allMatchedProteins.count
            let processed = index + 1
            let total = searchResults.count
            await MainActor.run {
                proteinsFound = count
                searchProgress = "Found \(count) proteins (processed \(processed)/\(total) terms)"
            }
        }

        let proteinCount = allMatchedProteins.count
        guard proteinCount > 0 else {
            await MainActor.run {
                errorMessage = "No proteins found for the search terms"
                searchProgress = ""
                proteinsFound = 0
                isLoading = false
            }
            return nil
        }

        await MainActor.run {
            searchProgress = "Creating search list with \(proteinCount) proteins..."
        }

        let assignedColor = color ?? getNextAvailableColor()

        // Create search list 
        let searchList = SearchList(
            name: name,
            proteinIds: allMatchedProteins,
            searchTerms: allSearchTerms,
            searchType: searchType,
            color: assignedColor,
            description: description
        )

        // Save search list to curtain data before updating UI
        saveSearchListsToCurtainData(curtainData: &curtainData)

        // Add to session and update UI on main actor
        await MainActor.run {
            searchProgress = "Saving search list..."
            searchSession.searchLists.append(searchList)
            searchSession.activeFilters.insert(searchList.id)
            searchProgress = "Search completed!"
            isLoading = false
        }

        // Clear progress after a short delay
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            searchProgress = ""
            proteinsFound = 0
        }

        return searchList
    }
    
    func createSearchListFromProteinIds(
        name: String,
        proteinIds: Set<String>,
        curtainData: inout CurtainData,
        color: String? = nil,
        description: String? = nil
    ) -> SearchList {
        
        // Assign color
        let assignedColor = color ?? getNextAvailableColor()
        
        // Create search list directly from protein IDs (for point click modal selections)
        let searchList = SearchList(
            name: name,
            proteinIds: proteinIds,
            searchTerms: Array(proteinIds), // Use protein IDs as search terms
            searchType: .primaryID,
            color: assignedColor,
            description: description
        )
        
        // Add to session (ensure main thread for UI updates)
        if Thread.isMainThread {
            searchSession.searchLists.append(searchList)
            searchSession.activeFilters.insert(searchList.id)
            saveSearchListsToCurtainData(curtainData: &curtainData)
        } else {
            DispatchQueue.main.sync {
                searchSession.searchLists.append(searchList)
                searchSession.activeFilters.insert(searchList.id)
                saveSearchListsToCurtainData(curtainData: &curtainData)
            }
        }
        
        return searchList
    }
    
    func removeSearchList(id: String, curtainData: inout CurtainData) {
        if Thread.isMainThread {
            searchSession.searchLists.removeAll { $0.id == id }
            searchSession.activeFilters.remove(id)
            saveSearchListsToCurtainData(curtainData: &curtainData)
        } else {
            DispatchQueue.main.sync {
                searchSession.searchLists.removeAll { $0.id == id }
                searchSession.activeFilters.remove(id)
                saveSearchListsToCurtainData(curtainData: &curtainData)
            }
        }
    }
    
    func toggleSearchListFilter(id: String, curtainData: inout CurtainData) {
        if Thread.isMainThread {
            if searchSession.activeFilters.contains(id) {
                searchSession.activeFilters.remove(id)
            } else {
                searchSession.activeFilters.insert(id)
            }
            saveSearchListsToCurtainData(curtainData: &curtainData)
        } else {
            DispatchQueue.main.sync {
                if searchSession.activeFilters.contains(id) {
                    searchSession.activeFilters.remove(id)
                } else {
                    searchSession.activeFilters.insert(id)
                }
                saveSearchListsToCurtainData(curtainData: &curtainData)
            }
        }
    }
    
    func renameSearchList(id: String, newName: String, curtainData: inout CurtainData) {
        if Thread.isMainThread {
            if let index = searchSession.searchLists.firstIndex(where: { $0.id == id }) {
                let currentList = searchSession.searchLists[index]
                searchSession.searchLists[index] = SearchList(
                    id: currentList.id,
                    name: newName,
                    proteinIds: currentList.proteinIds,
                    searchTerms: currentList.searchTerms,
                    searchType: currentList.searchType,
                    color: currentList.color,
                    description: currentList.description,
                    timestamp: currentList.timestamp
                )
                saveSearchListsToCurtainData(curtainData: &curtainData)
            }
        } else {
            DispatchQueue.main.sync {
                if let index = searchSession.searchLists.firstIndex(where: { $0.id == id }) {
                    let currentList = searchSession.searchLists[index]
                    searchSession.searchLists[index] = SearchList(
                        id: currentList.id,
                        name: newName,
                        proteinIds: currentList.proteinIds,
                        searchTerms: currentList.searchTerms,
                        searchType: currentList.searchType,
                        color: currentList.color,
                        description: currentList.description,
                        timestamp: currentList.timestamp
                    )
                    saveSearchListsToCurtainData(curtainData: &curtainData)
                }
            }
        }
    }
    
    
    func restoreSearchListsFromCurtainData(curtainData: CurtainData) {
        
        
        var restoredSearchLists: [SearchList] = []
        var selectionNames: Set<String> = []
        
        // First, collect all selection names from selectionsName 
        if let selectionsName = curtainData.selectionsName {
            selectionNames = Set(selectionsName)
        }
        
        // Use selectedMap for runtime operations 
        if let selectedMap = curtainData.selectedMap {
            
            for (proteinId, selections) in selectedMap {
                for (selectionName, isSelected) in selections {
                    if isSelected {
                        selectionNames.insert(selectionName)
                        
                        // Find or create search list for this selection
                        if let existingIndex = restoredSearchLists.firstIndex(where: { $0.name == selectionName }) {
                            // Add protein to existing search list
                            let existingList = restoredSearchLists[existingIndex]
                            let updatedProteinIds = existingList.proteinIds.union([proteinId])
                            restoredSearchLists[existingIndex] = SearchList(
                                id: existingList.id,
                                name: existingList.name,
                                proteinIds: updatedProteinIds,
                                searchTerms: existingList.searchTerms,
                                searchType: existingList.searchType,
                                color: existingList.color,
                                description: existingList.description,
                                timestamp: existingList.timestamp
                            )
                        } else {
                            // Create new search list - color will be assigned later
                            let searchList = SearchList(
                                name: selectionName,
                                proteinIds: [proteinId],
                                searchTerms: [proteinId],
                                searchType: .primaryID,
                                color: "#808080" // Temporary placeholder color
                            )
                            restoredSearchLists.append(searchList)
                        }
                    }
                }
            }
        }
        
        // Also create empty search lists for selection names that don't have proteins yet
        for selectionName in selectionNames {
            if !restoredSearchLists.contains(where: { $0.name == selectionName }) {
                let emptySearchList = SearchList(
                    name: selectionName,
                    proteinIds: [],
                    searchTerms: [],
                    searchType: .primaryID,
                    color: "#808080", // Temporary placeholder color
                    description: "Empty selection"
                )
                restoredSearchLists.append(emptySearchList)
            }
        }
        
        // Apply correct color assignment using the same logic as volcano plot 
        assignCorrectColorsToSearchLists(&restoredSearchLists, curtainData.settings)
        
        // Update UI on main thread
        if Thread.isMainThread {
            searchSession.searchLists = restoredSearchLists
            searchSession.activeFilters = Set(restoredSearchLists.map { $0.id })
        } else {
            DispatchQueue.main.sync {
                searchSession.searchLists = restoredSearchLists
                searchSession.activeFilters = Set(restoredSearchLists.map { $0.id })
            }
        }
    }
    
    func saveSearchListsToCurtainData(curtainData: inout CurtainData) {
        
        
        // Build new selectOperationNames 
        var newSelectOperationNames: [String] = []
        var newSelectionsMap: [String: [String: Bool]] = [:]
        
        // Preserve existing selections (including significance groups from volcano plot)
        if let existingSelectionsMap = curtainData.selectionsMap {
            for (proteinId, selections) in existingSelectionsMap {
                if let selectionMap = selections as? [String: Bool] {
                    for (selectionName, isSelected) in selectionMap {
                        if isSelected {
                            // Preserve all TRUE selections (including significance groups)
                            if newSelectionsMap[proteinId] == nil {
                                newSelectionsMap[proteinId] = [:]
                            }
                            newSelectionsMap[proteinId]![selectionName] = true
                            
                            // Add to operation names if not already present
                            if !newSelectOperationNames.contains(selectionName) {
                                newSelectOperationNames.append(selectionName)
                            }
                        }
                    }
                }
            }
        }
        
        // Add current SearchList selections (only active ones)
        for searchList in searchSession.searchLists {
            if searchSession.activeFilters.contains(searchList.id) {
                // Add to operation names
                if !newSelectOperationNames.contains(searchList.name) {
                    newSelectOperationNames.append(searchList.name)
                }
                
                // Add protein selections
                for proteinId in searchList.proteinIds {
                    if newSelectionsMap[proteinId] == nil {
                        newSelectionsMap[proteinId] = [:]
                    }
                    newSelectionsMap[proteinId]![searchList.name] = true
                }
            } else {
                // Remove inactive search list selections
                for proteinId in searchList.proteinIds {
                    newSelectionsMap[proteinId]?.removeValue(forKey: searchList.name)
                    if newSelectionsMap[proteinId]?.isEmpty == true {
                        newSelectionsMap.removeValue(forKey: proteinId)
                    }
                }
                // Remove from operation names if no proteins are selected
                newSelectOperationNames.removeAll { $0 == searchList.name }
            }
        }
        
        // Convert to Any type for CurtainData compatibility
        var convertedSelectionsMap: [String: Any] = [:]
        for (proteinId, selections) in newSelectionsMap {
            convertedSelectionsMap[proteinId] = selections
        }
        
        
        updateCurtainDataSelections(
            curtainData: &curtainData,
            selectionsMap: convertedSelectionsMap,
            selectOperationNames: newSelectOperationNames
        )
        
    }
    
    
    private func updateCurtainDataSelections(
        curtainData: inout CurtainData,
        selectionsMap: [String: Any],
        selectOperationNames: [String]
    ) {
        // Update the actual CurtainData object properties 
        // This needs to be done through direct property mutation
        
        curtainData.selectionsMap = selectionsMap
        
        // Update selectedMap  
        curtainData.selectedMap = convertToSelectedMap(selectionsMap)
        
        curtainData.selectionsName = selectOperationNames
        
        
        NotificationCenter.default.post(
            name: NSNotification.Name("VolcanoPlotRefresh"),
            object: nil,
            userInfo: ["reason": "searchUpdate"]
        )
    }
    
    
    func performTypeaheadSearch(
        query: String,
        searchType: SearchType,
        curtainData: CurtainData
    ) async -> [TypeaheadSuggestion] {
        
        guard query.count >= 2 else { return [] }
        
        return await searchService.performTypeaheadSearch(
            query: query,
            searchType: searchType,
            curtainData: curtainData,
            limit: 10
        )
    }
    
    // MARK: - Helper Methods
    
    private func getNextAvailableColor() -> String {
        let usedColors = Set(searchSession.searchLists.map { $0.color })
        
        for color in defaultColors {
            if !usedColors.contains(color) {
                return color
            }
        }
        
        // If all default colors are used, generate a random color
        return String(format: "#%06X", Int.random(in: 0...0xFFFFFF))
    }
    
    
    func exportSearchList(_ searchList: SearchList) -> String {
        // Export as newline-separated protein IDs 
        return searchList.proteinIds.sorted().joined(separator: "\n")
    }
    
    func exportAllSearchLists() -> String {
        // Export all search lists with headers
        var exportContent = ""
        
        for searchList in searchSession.searchLists {
            exportContent += "# \(searchList.name) (\(searchList.proteinIds.count) proteins)\n"
            exportContent += searchList.proteinIds.sorted().joined(separator: "\n")
            exportContent += "\n\n"
        }
        
        return exportContent
    }
    
    
    private func assignCorrectColorsToSearchLists(_ searchLists: inout [SearchList], _ settings: CurtainSettings) {
        // Use the same color assignment logic as VolcanoPlotDataService 
        var colorMap = settings.colorMap
        let selectionNames = Set(searchLists.map { $0.name })
        
        assignColorsToSelections(selectionNames, &colorMap, settings)
        
        // Update search lists with assigned colors
        for i in 0..<searchLists.count {
            let selectionName = searchLists[i].name
            if let assignedColor = colorMap[selectionName] {
                searchLists[i] = SearchList(
                    id: searchLists[i].id,
                    name: searchLists[i].name,
                    proteinIds: searchLists[i].proteinIds,
                    searchTerms: searchLists[i].searchTerms,
                    searchType: searchLists[i].searchType,
                    color: assignedColor,
                    description: searchLists[i].description,
                    timestamp: searchLists[i].timestamp
                )
            }
        }
    }
    
    private func assignColorsToSelections(_ selectOperationNames: Set<String>, _ colorMap: inout [String: String], _ settings: CurtainSettings) {
        // Same logic as VolcanoPlotDataService.assignColorsToSelections 
        let defaultColorList = settings.defaultColorList
        var currentColors: [String] = []
        
        // Collect currently used colors 
        for (_, color) in colorMap {
            if defaultColorList.contains(color) {
                currentColors.append(color)
            }
        }
        
        // Set current position for color assignment 
        var currentPosition = 0
        if currentColors.count < defaultColorList.count {
            currentPosition = currentColors.count
        }
        
        var breakColor = false
        var shouldRepeat = false
        
        for s in selectOperationNames {
            if colorMap[s] == nil {
                while true {
                    if breakColor {
                        colorMap[s] = defaultColorList[currentPosition]
                        break
                    }
                    
                    if currentColors.contains(defaultColorList[currentPosition]) {
                        currentPosition += 1
                        if shouldRepeat {
                            colorMap[s] = defaultColorList[currentPosition]
                            currentPosition = 0
                            breakColor = true
                            break
                        }
                    } else if currentPosition >= defaultColorList.count {
                        currentPosition = 0
                        colorMap[s] = defaultColorList[currentPosition]
                        shouldRepeat = true
                        break
                    } else {
                        colorMap[s] = defaultColorList[currentPosition]
                        break
                    }
                }
                
                currentPosition += 1
                if currentPosition == defaultColorList.count {
                    currentPosition = 0
                }
            }
        }
    }
    
    
    private func convertToSelectedMap(_ selectionsMap: [String: Any]) -> [String: [String: Bool]]? {
        // Convert generic selectionsMap to strongly-typed selectedMap 
        var selectedMap: [String: [String: Bool]] = [:]
        
        for (proteinId, selections) in selectionsMap {
            if let selectionDict = selections as? [String: Bool] {
                // Filter out false values 
                var cleanedSelections: [String: Bool] = [:]
                for (selectionName, isSelected) in selectionDict {
                    if isSelected {
                        cleanedSelections[selectionName] = true
                    }
                }
                
                if !cleanedSelections.isEmpty {
                    selectedMap[proteinId] = cleanedSelections
                }
            }
        }
        
        return selectedMap.isEmpty ? nil : selectedMap
    }
}

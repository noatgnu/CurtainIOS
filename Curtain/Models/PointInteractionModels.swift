//
//  PointInteractionModels.swift
//  Curtain
//
//  Created by Toan Phung on 04/08/2025.
//

import Foundation
import SwiftUI

// MARK: - Point Interaction Models (Like Android)

struct VolcanoPointClickData {
    let clickedProtein: ProteinPoint
    let nearbyProteins: [NearbyProtein]
    let clickPosition: CGPoint
    let plotCoordinates: PlotCoordinates
}

struct NearbyProtein {
    let protein: ProteinPoint
    let distance: Double
    let deltaX: Double
    let deltaY: Double
}

struct PlotCoordinates {
    let x: Double // Log2 fold change
    let y: Double // -log10(p-value)
}

// MARK: - Modal State Management

class PointInteractionViewModel: ObservableObject {
    @Published var selectedPointData: VolcanoPointClickData?
    @Published var isModalPresented = false
    @Published var distanceCutoff: Double = 1.0 // Default cutoff like Android
    
    func handlePointClick(_ clickData: VolcanoPointClickData) {
        selectedPointData = clickData
        isModalPresented = true
    }
    
    func dismissModal() {
        isModalPresented = false
        selectedPointData = nil
    }
}

// MARK: - Distance Calculation (Euclidean Distance)

struct DistanceCalculator {
    static func calculateEuclideanDistance(
        from point1: PlotCoordinates,
        to point2: PlotCoordinates
    ) -> Double {
        let deltaX = point1.x - point2.x
        let deltaY = point1.y - point2.y
        return sqrt(deltaX * deltaX + deltaY * deltaY)
    }
    
    static func findNearbyProteins(
        around centerProtein: ProteinPoint,
        from allProteins: [ProteinPoint],
        distanceCutoff: Double = 1.0
    ) -> [NearbyProtein] {
        let centerCoords = PlotCoordinates(
            x: centerProtein.log2FC,
            y: centerProtein.negLog10PValue
        )
        
        var nearbyProteins: [NearbyProtein] = []
        
        for protein in allProteins {
            // Skip the center protein itself
            if protein.id == centerProtein.id {
                continue
            }
            
            let proteinCoords = PlotCoordinates(
                x: protein.log2FC,
                y: protein.negLog10PValue
            )
            
            let distance = calculateEuclideanDistance(from: centerCoords, to: proteinCoords)
            let deltaX = proteinCoords.x - centerCoords.x
            let deltaY = proteinCoords.y - centerCoords.y
            
            if distance <= distanceCutoff {
                nearbyProteins.append(NearbyProtein(
                    protein: protein,
                    distance: distance,
                    deltaX: deltaX,
                    deltaY: deltaY
                ))
            }
        }
        
        // Sort by distance (closest first, like Android)
        return nearbyProteins.sorted { $0.distance < $1.distance }
    }
}

// MARK: - Selection Management

struct ProteinSelection {
    let id: String
    let name: String
    let proteinIds: Set<String>
    let color: String
    let timestamp: Date
}

class SelectionManager: ObservableObject {
    @Published var selections: [ProteinSelection] = []
    @Published var activeSelectionId: String?
    
    func createSelection(name: String, proteinIds: Set<String>, color: String) {
        let selection = ProteinSelection(
            id: UUID().uuidString,
            name: name,
            proteinIds: proteinIds,
            color: color,
            timestamp: Date()
        )
        selections.append(selection)
        activeSelectionId = selection.id
    }
    
    func addProteinsToSelection(_ proteinIds: Set<String>, selectionId: String) {
        if let index = selections.firstIndex(where: { $0.id == selectionId }) {
            let updatedSelection = ProteinSelection(
                id: selections[index].id,
                name: selections[index].name,
                proteinIds: selections[index].proteinIds.union(proteinIds),
                color: selections[index].color,
                timestamp: Date()
            )
            selections[index] = updatedSelection
        }
    }
    
    func removeSelection(id: String) {
        selections.removeAll { $0.id == id }
        if activeSelectionId == id {
            activeSelectionId = selections.first?.id
        }
    }
}

// MARK: - Annotation Models

struct ProteinAnnotation {
    let id: String
    let proteinId: String
    let text: String
    let position: PlotCoordinates
    let color: String
    let fontSize: Double
    let timestamp: Date
}

class AnnotationManager: ObservableObject {
    @Published var annotations: [ProteinAnnotation] = []
    
    // Callback to update CurtainSettings when annotations change
    var onAnnotationUpdate: ((String, [String: Any]) -> Void)?
    
    func addAnnotation(
        proteinId: String,
        text: String,
        position: PlotCoordinates,
        color: String = "#000000",
        fontSize: Double = 15.0
    ) {
        let annotation = ProteinAnnotation(
            id: UUID().uuidString,
            proteinId: proteinId,
            text: text,
            position: position,
            color: color,
            fontSize: fontSize,
            timestamp: Date()
        )
        annotations.append(annotation)
        
        // Create Android-compatible annotation data structure
        let annotationData: [String: Any] = [
            "primary_id": proteinId,
            "title": text,
            "data": [
                "xref": "x",
                "yref": "y",
                "x": position.x,
                "y": position.y,
                "text": "<b>\(text)</b>",
                "showarrow": true,
                "arrowhead": 1,
                "arrowsize": 1,
                "arrowwidth": 1,
                "ax": -20,
                "ay": -20,
                "font": [
                    "size": fontSize,
                    "color": color,
                    "family": "Arial, sans-serif"
                ],
                "showannotation": true,
                "annotationID": text
            ]
        ]
        
        // Notify about annotation update using the text as the key (matching Android)
        onAnnotationUpdate?(text, annotationData)
    }
    
    func removeAnnotation(id: String) {
        annotations.removeAll { $0.id == id }
    }
    
    func updateAnnotation(id: String, text: String) {
        if let index = annotations.firstIndex(where: { $0.id == id }) {
            let updatedAnnotation = ProteinAnnotation(
                id: annotations[index].id,
                proteinId: annotations[index].proteinId,
                text: text,
                position: annotations[index].position,
                color: annotations[index].color,
                fontSize: annotations[index].fontSize,
                timestamp: Date()
            )
            annotations[index] = updatedAnnotation
        }
    }
}
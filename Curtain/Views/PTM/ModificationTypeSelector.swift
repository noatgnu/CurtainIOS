//
//  ModificationTypeSelector.swift
//  Curtain
//
//  Filter chips for UniProt modification types
//

import SwiftUI

struct ModificationTypeSelector: View {
    let modTypes: [String]
    let selectedModTypes: Set<String>
    let onSelectionChanged: (Set<String>) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Modification Types")
                .font(.headline)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(modTypes, id: \.self) { modType in
                        FilterChip(
                            label: modType,
                            isSelected: selectedModTypes.contains(modType),
                            color: colorForModType(modType)
                        ) {
                            toggleModType(modType)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    private func toggleModType(_ modType: String) {
        var newSelection = selectedModTypes
        if newSelection.contains(modType) {
            newSelection.remove(modType)
        } else {
            newSelection.insert(modType)
        }
        onSelectionChanged(newSelection)
    }

    private func colorForModType(_ modType: String) -> Color {
        let lowercased = modType.lowercased()
        if lowercased.contains("phospho") {
            return .orange
        } else if lowercased.contains("acetyl") {
            return .blue
        } else if lowercased.contains("methyl") {
            return .purple
        } else if lowercased.contains("ubiquit") {
            return .red
        } else if lowercased.contains("glyco") {
            return .green
        }
        return .gray
    }
}

// MARK: - FilterChip

struct FilterChip: View {
    let label: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? color.opacity(0.2) : Color(.systemGray5))
                .foregroundColor(isSelected ? color : .primary)
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isSelected ? color : Color.clear, lineWidth: 1)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    ModificationTypeSelector(
        modTypes: ["Phosphorylation", "Acetylation", "Methylation", "Ubiquitination"],
        selectedModTypes: ["Phosphorylation"],
        onSelectionChanged: { _ in }
    )
    .padding()
}

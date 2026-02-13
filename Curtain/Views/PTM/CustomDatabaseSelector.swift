//
//  CustomDatabaseSelector.swift
//  Curtain
//
//  Filter chips for custom PTM databases
//

import SwiftUI

struct CustomDatabaseSelector: View {
    let databases: [String]
    let selectedDatabases: Set<String>
    let onSelectionChanged: (Set<String>) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Custom PTM Databases")
                .font(.headline)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(databases, id: \.self) { database in
                        FilterChip(
                            label: database,
                            isSelected: selectedDatabases.contains(database),
                            color: .purple
                        ) {
                            toggleDatabase(database)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    private func toggleDatabase(_ database: String) {
        var newSelection = selectedDatabases
        if newSelection.contains(database) {
            newSelection.remove(database)
        } else {
            newSelection.insert(database)
        }
        onSelectionChanged(newSelection)
    }
}

#Preview {
    CustomDatabaseSelector(
        databases: ["PhosphoSitePlus", "UniProt PTM", "Custom DB"],
        selectedDatabases: ["PhosphoSitePlus"],
        onSelectionChanged: { _ in }
    )
    .padding()
}

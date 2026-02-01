//
//  CrossDatasetMatrixView.swift
//  Curtain
//
//  Scrollable heatmap grid for cross-dataset comparison, filtered to a selected protein.
//

import SwiftUI

struct CrossDatasetMatrixView: View {
    @Bindable var viewModel: CrossDatasetSearchViewModel
    let selectedProteinId: String

    @State private var showFilterMenu = false
    @State private var filterSignificantOnly = false
    @State private var hideNotFound = false
    @State private var filterMinFoldChange = ""
    @State private var filterMaxPValue = ""
    @State private var showComparisonInfo: (row: MatrixRow, cell: MatrixCell?)?

    private var matrix: CrossDatasetMatrix? { viewModel.matrixData }

    private var minFcValue: Double? { Double(filterMinFoldChange) }
    private var maxPValueValue: Double? { Double(filterMaxPValue) }
    private var hasActiveFilters: Bool {
        filterSignificantOnly || hideNotFound || minFcValue != nil || maxPValueValue != nil
    }

    private var filteredRows: [MatrixRow] {
        guard let matrix else { return [] }
        return matrix.rows.filter { row in
            let cell = row.cells[selectedProteinId]
            if cell == nil { return !hideNotFound }
            guard let cell else { return true }
            if !cell.found { return !hideNotFound }
            let passesSignificant = !filterSignificantOnly || cell.isSignificant
            let passesFc = minFcValue == nil || (cell.foldChange != nil && abs(cell.foldChange!) >= minFcValue!)
            let passesP = maxPValueValue == nil || (cell.pValue != nil && cell.pValue! <= maxPValueValue!)
            return passesSignificant && passesFc && passesP
        }
    }

    private var uniqueComparisons: [String] {
        filteredRows.map { $0.comparison }.reduce(into: [String]()) { result, comp in
            if !result.contains(comp) { result.append(comp) }
        }.sorted()
    }

    var body: some View {
        VStack(spacing: 0) {
            filterToolbar
            Divider()
            headerRow
            Divider()
            dataRows
            legendBar
        }
        .sheet(item: comparisonInfoBinding) { info in
            ComparisonInfoSheet(
                row: info.row,
                proteinId: selectedProteinId,
                cell: info.cell,
                geneName: matrix?.proteinGeneNames[selectedProteinId] ?? nil
            )
        }
    }

    private var comparisonInfoBinding: Binding<ComparisonInfoItem?> {
        Binding(
            get: {
                guard let info = showComparisonInfo else { return nil }
                return ComparisonInfoItem(row: info.row, cell: info.cell)
            },
            set: { newValue in
                if newValue == nil { showComparisonInfo = nil }
            }
        )
    }

    // MARK: - Filter Toolbar

    private var filterToolbar: some View {
        HStack {
            Text("\(filteredRows.count)/\(matrix?.rows.count ?? 0) datasets")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Menu {
                VStack {
                    Toggle("Significant only", isOn: $filterSignificantOnly)
                    Toggle("Hide not found", isOn: $hideNotFound)
                }

                if hasActiveFilters {
                    Button("Clear Filters") {
                        filterSignificantOnly = false
                        hideNotFound = false
                        filterMinFoldChange = ""
                        filterMaxPValue = ""
                    }
                }
            } label: {
                Image(systemName: "line.3.horizontal.decrease")
                    .foregroundStyle(hasActiveFilters ? Color.accentColor : Color.secondary)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(.secondarySystemGroupedBackground))
    }

    // MARK: - Header Row

    private var headerRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                Text("Dataset")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .frame(width: 160, alignment: .leading)
                    .padding(.horizontal, 12)

                ForEach(uniqueComparisons, id: \.self) { comparison in
                    Text(comparison)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .frame(width: 130)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 8)
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Data Rows

    private var dataRows: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyVStack(spacing: 0) {
                ForEach(Array(filteredRows.enumerated()), id: \.element.id) { index, row in
                    HStack(spacing: 0) {
                        HStack {
                            Text(row.datasetName.isEmpty ? "Untitled" : row.datasetName)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .lineLimit(2)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Image(systemName: "arrow.up.forward.square")
                                .font(.caption2)
                                .foregroundStyle(.tint)
                        }
                        .frame(width: 160)
                        .padding(.horizontal, 12)

                        ForEach(uniqueComparisons, id: \.self) { comparison in
                            let isActiveComparison = row.comparison == comparison
                            let cell = isActiveComparison ? row.cells[selectedProteinId] : nil
                            comparisonCellView(
                                cell: cell,
                                isActiveComparison: isActiveComparison,
                                row: row
                            )
                            .frame(width: 130, height: 48)
                        }
                    }
                    .padding(.vertical, 2)
                    .background(index % 2 == 0 ? Color.clear : Color(.systemGray6).opacity(0.5))

                    if index < filteredRows.count - 1 {
                        Divider().opacity(0.5)
                    }
                }
            }
        }
    }

    // MARK: - Cell View

    private func comparisonCellView(cell: MatrixCell?, isActiveComparison: Bool, row: MatrixRow) -> some View {
        Group {
            if !isActiveComparison {
                // Not this row's comparison — show small dot (matches Android)
                Circle()
                    .fill(Color(.systemGray4).opacity(0.3))
                    .frame(width: 8, height: 8)
            } else if cell == nil || !(cell!.found) {
                // Not found — show N/F (matches Android)
                Text("N/F")
                    .font(.caption2)
                    .foregroundStyle(.secondary.opacity(0.6))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.systemGray5))
                    )
                    .padding(4)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if let cell { showComparisonInfo = (row: row, cell: cell) }
                    }
            } else if let cell, let fc = cell.foldChange {
                // Found with fold change — show colored cell (matches Android)
                let intensity = min(abs(fc) / 3.0, 1.0)
                let bgColor = fc > 0
                    ? Color.green.opacity(0.3 + intensity * 0.5)
                    : Color.red.opacity(0.3 + intensity * 0.5)

                VStack(spacing: 2) {
                    Text(String(format: "%.2f", fc))
                        .font(.system(size: 13, weight: cell.isSignificant ? .bold : .medium))
                        .foregroundStyle(abs(fc) > 1.5 ? .white : .primary)
                    if cell.isSignificant {
                        Text("\u{2605}")
                            .font(.system(size: 10))
                            .foregroundStyle(abs(fc) > 1.5 ? .white : .primary)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(bgColor)
                )
                .padding(4)
                .contentShape(Rectangle())
                .onTapGesture {
                    showComparisonInfo = (row: row, cell: cell)
                }
            } else {
                // Found but no fold change — show "?" (matches Android)
                Text("?")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.systemGray4))
                    )
                    .padding(4)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if let cell { showComparisonInfo = (row: row, cell: cell) }
                    }
            }
        }
    }

    // MARK: - Legend

    private var legendBar: some View {
        HStack(spacing: 16) {
            Text("Legend:")
                .font(.caption2)
                .fontWeight(.semibold)

            HStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 2).fill(.red.opacity(0.5)).frame(width: 14, height: 14)
                Text("Down")
            }
            HStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 2).fill(Color(.systemGray4)).frame(width: 14, height: 14)
                Text("~0")
            }
            HStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 2).fill(.green.opacity(0.5)).frame(width: 14, height: 14)
                Text("Up")
            }
            HStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 2).fill(Color(.systemGray5)).frame(width: 14, height: 14)
                Text("N/F")
            }

            Spacer()

            Text("\u{2605} = significant")
                .foregroundStyle(.secondary)
        }
        .font(.caption2)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemGroupedBackground))
    }
}

// MARK: - Comparison Info Item (for sheet binding)

struct ComparisonInfoItem: Identifiable {
    let id = UUID()
    let row: MatrixRow
    let cell: MatrixCell?
}

// MARK: - Comparison Info Sheet

struct ComparisonInfoSheet: View {
    let row: MatrixRow
    let proteinId: String
    let cell: MatrixCell?
    let geneName: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Dataset") {
                    LabeledContent("Dataset", value: row.datasetName.isEmpty ? "Untitled" : row.datasetName)
                    LabeledContent("Comparison", value: row.comparison)
                }

                if let cell, cell.found {
                    Section("Values") {
                        if let fc = cell.foldChange {
                            LabeledContent("Fold Change") {
                                Text(String(format: "%.3f", fc))
                                    .foregroundStyle(fc > 0 ? .green : fc < 0 ? .red : .primary)
                                    .fontWeight(.bold)
                            }
                        }
                        if let pv = cell.pValue {
                            LabeledContent("P-value") {
                                Text(String(format: "%.2e", pv))
                                    .fontWeight(.bold)
                                    .foregroundStyle(cell.isSignificant ? Color.accentColor : Color.primary)
                            }
                        }
                        if cell.isSignificant {
                            Text("\u{2605} Significant")
                                .foregroundStyle(.tint)
                                .fontWeight(.bold)
                        }
                    }
                }

                if row.conditionLeft != nil || row.conditionRight != nil {
                    Section("Volcano Plot Conditions") {
                        if let left = row.conditionLeft {
                            LabeledContent("Left (\u{2193} FC)") {
                                Text(left).foregroundStyle(.red)
                            }
                        }
                        if let right = row.conditionRight {
                            LabeledContent("Right (\u{2191} FC)") {
                                Text(right).foregroundStyle(.green)
                            }
                        }
                    }
                }
            }
            .navigationTitle(row.datasetName.isEmpty ? "Dataset Info" : row.datasetName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                    .fixedSize()
                }
            }
        }
        .presentationDetents([.medium])
    }
}

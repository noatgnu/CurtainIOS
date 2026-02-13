//
//  PTMSequenceTab.swift
//  Curtain
//
//  Sequence alignment visualization tab
//

import SwiftUI

struct PTMSequenceTab: View {
    let state: PTMViewerState
    @ObservedObject var viewModel: PTMViewerViewModel

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                // Protein info card
                ProteinInfoCard(state: state)

                // Modification type selector
                if !state.availableModTypes.isEmpty {
                    ModificationTypeSelector(
                        modTypes: state.availableModTypes,
                        selectedModTypes: viewModel.selectedModTypes,
                        onSelectionChanged: viewModel.updateSelectedModTypes
                    )
                }

                // Custom database selector
                if !state.availableCustomDatabases.isEmpty {
                    CustomDatabaseSelector(
                        databases: state.availableCustomDatabases,
                        selectedDatabases: viewModel.selectedCustomDatabases,
                        onSelectionChanged: viewModel.updateSelectedCustomDatabases
                    )
                }

                // Alignment legend
                AlignmentLegend()

                // Sequence alignment section
                SequenceAlignmentSection(state: state, viewModel: viewModel)

                // Domain visualization
                if !state.domains.isEmpty {
                    DomainVisualization(domains: state.domains, sequenceLength: state.sequenceLength)
                }

                // PTM Sites list
                PTMSitesList(
                    sites: viewModel.filteredExperimentalSites,
                    onSiteSelected: { site in
                        viewModel.selectedSite = site
                    }
                )
            }
            .padding()
            .padding(.bottom, 32) // Extra bottom padding to prevent clipping
        }
        .sheet(item: $viewModel.selectedSite) { site in
            SiteDetailSheet(site: site)
        }
    }
}

// MARK: - PTMSitesList

struct PTMSitesList: View {
    let sites: [ExperimentalPTMSite]
    let onSiteSelected: (ExperimentalPTMSite) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Experimental PTM Sites (\(sites.count))")
                .font(.headline)

            if sites.isEmpty {
                Text("No PTM sites found")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                ForEach(sites) { site in
                    PTMSiteRow(site: site)
                        .onTapGesture {
                            onSiteSelected(site)
                        }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - PTMSiteRow (matches Android style)

struct PTMSiteRow: View {
    let site: ExperimentalPTMSite

    var body: some View {
        HStack(spacing: 12) {
            // Position and residue
            Text("\(site.residue)\(site.position)")
                .font(.system(.body, design: .monospaced))
                .fontWeight(.bold)
                .frame(width: 60, alignment: .leading)

            // Peptide sequence (truncated)
            if let peptide = site.peptideSequence {
                Text(peptide)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .frame(maxWidth: 100, alignment: .leading)
            }

            Spacer()

            // Fold change and p-value
            VStack(alignment: .trailing, spacing: 2) {
                if let fc = site.foldChange {
                    Text(String(format: "FC: %.2f", fc))
                        .font(.caption)
                        .foregroundColor(fc > 0 ? .red : .blue)
                }

                if let pValue = site.pValue {
                    Text(String(format: "p: %.2e", pValue))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            // Significance indicator
            if site.isSignificant {
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)
                    .font(.caption)
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
}

#Preview {
    PTMSequenceTab(
        state: PTMViewerState(
            accession: "P12345",
            geneName: "TEST",
            canonicalSequence: "MKLPVRGSSTESTSEQUENCE"
        ),
        viewModel: PTMViewerViewModel()
    )
}

//
//  ProteinInfoCard.swift
//  Curtain
//
//  Displays protein metadata in a card format
//

import SwiftUI

struct ProteinInfoCard: View {
    let state: PTMViewerState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text("Protein Information")
                    .font(.headline)
                Spacer()
            }

            Divider()

            // Info grid
            VStack(alignment: .leading, spacing: 8) {
                InfoRow(label: "Accession", value: state.accession)

                if let geneName = state.geneName {
                    InfoRow(label: "Gene Name", value: geneName)
                }

                if let proteinName = state.proteinName {
                    InfoRow(label: "Protein Name", value: proteinName)
                }

                if let organism = state.organism {
                    InfoRow(label: "Organism", value: organism)
                }

                InfoRow(label: "Sequence Length", value: "\(state.sequenceLength) aa")

                InfoRow(label: "Experimental Sites", value: "\(state.experimentalSites.count)")

                if let source = state.experimentalSequenceSource, source != "canonical" {
                    InfoRow(label: "Sequence Source", value: source)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - InfoRow

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(width: 120, alignment: .leading)

            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}

#Preview {
    ProteinInfoCard(
        state: PTMViewerState(
            accession: "P12345",
            geneName: "TP53",
            proteinName: "Cellular tumor antigen p53",
            organism: "Homo sapiens",
            canonicalSequence: "MKLPVRGSSTESTSEQUENCE"
        )
    )
    .padding()
}

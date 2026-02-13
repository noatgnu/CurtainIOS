//
//  SiteDetailSheet.swift
//  Curtain
//
//  Modal showing detailed PTM site information
//  Matches Android's SiteDetailDialog
//

import SwiftUI

struct SiteDetailSheet: View {
    let site: ExperimentalPTMSite
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Title
            Text("\(site.residue)\(site.position)")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.top, 20)
                .padding(.bottom, 16)

            // Content - matches Android's Column with 8dp spacing
            VStack(spacing: 8) {
                DetailRow(label: "Primary ID", value: site.primaryId)
                DetailRow(label: "Position", value: "\(site.position)")
                DetailRow(label: "Residue", value: String(site.residue))

                if let modification = site.modification {
                    DetailRow(label: "Modification", value: modification)
                }

                if let peptide = site.peptideSequence {
                    DetailRow(label: "Peptide", value: peptide)
                }

                if let fc = site.foldChange {
                    DetailRow(label: "Fold Change", value: String(format: "%.4f", fc))
                }

                if let pValue = site.pValue {
                    DetailRow(label: "P-value", value: String(format: "%.4e", pValue))
                }

                if let comparison = site.comparison {
                    DetailRow(label: "Comparison", value: comparison)
                }

                DetailRow(label: "Significant", value: site.isSignificant ? "Yes" : "No")
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)

            Divider()

            // Close button - matches Android's TextButton
            Button("Close") {
                dismiss()
            }
            .font(.body)
            .fontWeight(.medium)
            .foregroundColor(.accentColor)
            .padding(.vertical, 16)
        }
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(radius: 10)
        .padding(24)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - DetailRow (matches Android exactly)

struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.body)
                .foregroundColor(.secondary)

            Spacer()

            Text(value)
                .font(.body)
                .fontWeight(.medium)
                .lineLimit(1)
        }
    }
}

#Preview {
    SiteDetailSheet(
        site: ExperimentalPTMSite(
            primaryId: "P12345_S15",
            position: 15,
            residue: "S",
            modification: "Phosphorylation",
            peptideSequence: "RLSSKMPVR",
            foldChange: 2.5,
            pValue: 0.001,
            isSignificant: true,
            comparison: "Treatment vs Control",
            score: 0.95
        )
    )
}

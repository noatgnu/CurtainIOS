//
//  AlignmentLegend.swift
//  Curtain
//
//  Color legend for alignment visualization
//  Exact copy of Android implementation
//

import SwiftUI

struct AlignmentLegend: View {
    // Exact Android colors
    private let matchColor = Color(red: 0x4C/255, green: 0xAF/255, blue: 0x50/255)        // #4CAF50
    private let mismatchColor = Color(red: 0xF4/255, green: 0x43/255, blue: 0x36/255)     // #F44336
    private let gapColor = Color(red: 0x9E/255, green: 0x9E/255, blue: 0x9E/255)          // #9E9E9E
    private let experimentalColor = Color(red: 0xFF/255, green: 0x57/255, blue: 0x22/255) // #FF5722
    private let uniprotColor = Color(red: 0x21/255, green: 0x96/255, blue: 0xF3/255)      // #2196F3
    private let customColor = Color(red: 0x9C/255, green: 0x27/255, blue: 0xB0/255)       // #9C27B0

    var body: some View {
        // Card with surfaceVariant background (matches Android)
        HStack(spacing: 16) {
            AlignmentLegendItem(color: matchColor, label: "Match")
            AlignmentLegendItem(color: mismatchColor, label: "Mismatch")
            AlignmentLegendItem(color: gapColor, label: "Gap")
            AlignmentLegendItem(color: experimentalColor, label: "Experimental")
            AlignmentLegendItem(color: uniprotColor, label: "UniProt")
            AlignmentLegendItem(color: customColor, label: "Custom")
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground).opacity(0.5))
        .cornerRadius(12)
    }
}

// MARK: - AlignmentLegendItem (matches Android exactly)

struct AlignmentLegendItem: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            // Box with RoundedCornerShape(2.dp) in Android
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 12, height: 12)

            Text(label)
                .font(.caption2)
        }
    }
}

#Preview {
    AlignmentLegend()
        .padding()
}

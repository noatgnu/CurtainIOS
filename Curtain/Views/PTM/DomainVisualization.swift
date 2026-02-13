//
//  DomainVisualization.swift
//  Curtain
//
//  Domain bar chart with positions
//

import SwiftUI

struct DomainVisualization: View {
    let domains: [ProteinDomain]
    let sequenceLength: Int

    private let domainColors: [Color] = [
        .blue, .green, .orange, .purple, .pink, .teal, .indigo, .cyan
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Protein Domains (\(domains.count))")
                .font(.headline)

            // Domain bar visualization
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background bar (full sequence)
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(height: 30)
                        .cornerRadius(4)

                    // Domain bars
                    ForEach(Array(domains.enumerated()), id: \.element.id) { index, domain in
                        let startPercent = CGFloat(domain.startPosition - 1) / CGFloat(sequenceLength)
                        let widthPercent = CGFloat(domain.endPosition - domain.startPosition + 1) / CGFloat(sequenceLength)

                        Rectangle()
                            .fill(domainColors[index % domainColors.count])
                            .frame(width: geometry.size.width * widthPercent, height: 24)
                            .cornerRadius(4)
                            .offset(x: geometry.size.width * startPercent)
                            .overlay(
                                Text(domain.name)
                                    .font(.system(size: 10))
                                    .fontWeight(.medium)
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                    .padding(.horizontal, 4)
                                    .offset(x: geometry.size.width * startPercent)
                            , alignment: .leading)
                    }
                }
            }
            .frame(height: 30)

            // Position ruler
            HStack {
                Text("1")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Spacer()

                Text(String(sequenceLength))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            // Domain list
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(domains.enumerated()), id: \.element.id) { index, domain in
                    HStack {
                        Circle()
                            .fill(domainColors[index % domainColors.count])
                            .frame(width: 8, height: 8)

                        Text(domain.name)
                            .font(.caption)
                            .fontWeight(.medium)

                        Spacer()

                        Text("\(domain.startPosition)-\(domain.endPosition)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

#Preview {
    DomainVisualization(
        domains: [
            ProteinDomain(name: "DNA-binding", startPosition: 100, endPosition: 200),
            ProteinDomain(name: "Transactivation", startPosition: 1, endPosition: 50),
            ProteinDomain(name: "Oligomerization", startPosition: 320, endPosition: 360)
        ],
        sequenceLength: 400
    )
    .padding()
}

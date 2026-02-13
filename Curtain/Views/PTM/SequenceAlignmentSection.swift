//
//  SequenceAlignmentSection.swift
//  Curtain
//
//  Contains alignment header and alignment chunks
//  Matches Android's FullSequenceAlignmentCard
//

import SwiftUI

struct SequenceAlignmentSection: View {
    let state: PTMViewerState
    @ObservedObject var viewModel: PTMViewerViewModel

    private let chunkSize = 50

    // Build position maps for PTM sites
    private var experimentalPositions: [Int: ExperimentalPTMSite] {
        Dictionary(uniqueKeysWithValues: viewModel.filteredExperimentalSites.map { ($0.position, $0) })
    }

    private var modificationPositions: [Int: ParsedModification] {
        let filteredMods = state.parsedModifications.filter { viewModel.selectedModTypes.contains($0.modType) }
        return Dictionary(uniqueKeysWithValues: filteredMods.map { ($0.position, $0) })
    }

    private var customPTMPositions: [Int: CustomPTMSite] {
        let filteredSites = state.customPTMSites
            .filter { viewModel.selectedCustomDatabases.contains($0.key) }
            .values
            .flatMap { $0 }
        return Dictionary(uniqueKeysWithValues: filteredSites.map { ($0.position, $0) })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Sequence Alignment (\(state.sequenceLength) aa)")
                .font(.headline)

            if let alignedPair = state.alignedSequencePair {
                // Show full sequence alignment card like Android
                FullSequenceAlignmentCard(
                    alignedPair: alignedPair,
                    experimentalPositions: experimentalPositions,
                    modificationPositions: modificationPositions,
                    customPTMPositions: customPTMPositions,
                    sourceLabel: state.experimentalSequenceSource ?? "Experimental",
                    chunkSize: chunkSize
                )
            } else {
                // No experimental sequence available
                VStack(spacing: 8) {
                    Text("No experimental sequence available for alignment")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                }
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
            }
        }
    }
}

// MARK: - FullSequenceAlignmentCard (matches Android)

struct FullSequenceAlignmentCard: View {
    let alignedPair: AlignedSequencePair
    let experimentalPositions: [Int: ExperimentalPTMSite]
    let modificationPositions: [Int: ParsedModification]
    let customPTMPositions: [Int: CustomPTMSite]
    let sourceLabel: String
    let chunkSize: Int

    private var numberOfChunks: Int {
        (alignedPair.experimentalAligned.count + chunkSize - 1) / chunkSize
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Source: \(sourceLabel)")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.accentColor)

            ScrollView(.horizontal, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(0..<numberOfChunks, id: \.self) { chunkIdx in
                        let start = chunkIdx * chunkSize
                        let end = min(start + chunkSize, alignedPair.experimentalAligned.count)

                        let expChunk = String(alignedPair.experimentalAligned.dropFirst(start).prefix(end - start))
                        let canChunk = String(alignedPair.canonicalAligned.dropFirst(start).prefix(end - start))

                        AlignmentChunk(
                            experimentalChunk: expChunk,
                            canonicalChunk: canChunk,
                            startIndex: start,
                            experimentalPositions: experimentalPositions,
                            modificationPositions: modificationPositions,
                            customPTMPositions: customPTMPositions,
                            expPositionMap: alignedPair.experimentalPositionMap,
                            canPositionMap: alignedPair.canonicalPositionMap
                        )

                        if chunkIdx < numberOfChunks - 1 {
                            Divider()
                                .padding(.vertical, 4)
                        }
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

#Preview {
    SequenceAlignmentSection(
        state: PTMViewerState(
            accession: "P12345",
            canonicalSequence: "MKLPVRGSSTESTSEQUENCEWITHSOMEMORERESIDUESMKLPVRGSSTESTSEQUENCEWITHSOMEMORERESIDUESMKLPVRGSSTESTSEQUENCE",
            alignedSequencePair: AlignedSequencePair(
                experimentalSequence: "MKLPVRGSSTESTSEQUENCE",
                canonicalSequence: "MKLPVRGSSTESTSEQUENCE",
                experimentalAligned: "MKLPVRGSSTESTSEQUENCE",
                canonicalAligned: "MKLPVRGSSTESTSEQUENCE",
                experimentalPositionMap: [:],
                canonicalPositionMap: [:]
            )
        ),
        viewModel: PTMViewerViewModel()
    )
    .padding()
}

//
//  AlignmentChunk.swift
//  Curtain
//
//  Renders a chunk of sequence alignment with PTM annotations
//  Exact copy of Android implementation
//

import SwiftUI

struct AlignmentChunk: View {
    let experimentalChunk: String
    let canonicalChunk: String
    let startIndex: Int
    let experimentalPositions: [Int: ExperimentalPTMSite]
    let modificationPositions: [Int: ParsedModification]
    let customPTMPositions: [Int: CustomPTMSite]
    let expPositionMap: [Int: Int]
    let canPositionMap: [Int: Int]

    // Colors matching Android exactly
    private let matchColor = Color(red: 0x4C/255, green: 0xAF/255, blue: 0x50/255)        // #4CAF50
    private let mismatchColor = Color(red: 0xF4/255, green: 0x43/255, blue: 0x36/255)     // #F44336
    private let gapColor = Color(red: 0x9E/255, green: 0x9E/255, blue: 0x9E/255)          // #9E9E9E
    private let experimentalPTMColor = Color(red: 0xFF/255, green: 0x57/255, blue: 0x22/255) // #FF5722
    private let uniprotPTMColor = Color(red: 0x21/255, green: 0x96/255, blue: 0xF3/255)   // #2196F3
    private let customPTMColor = Color(red: 0x9C/255, green: 0x27/255, blue: 0xB0/255)    // #9C27B0

    private var expChars: [Character] { Array(experimentalChunk) }
    private var canChars: [Character] { Array(canonicalChunk) }

    private var expPtmAlignedPositions: Set<Int> {
        var result = Set<Int>()
        for pos in experimentalPositions.keys {
            if let alignedIdx = expPositionMap[pos] {
                let localIdx = alignedIdx - startIndex
                if localIdx >= 0 && localIdx < experimentalChunk.count {
                    result.insert(localIdx)
                }
            }
        }
        return result
    }

    private var uniprotModAlignedPositions: Set<Int> {
        var result = Set<Int>()
        for pos in modificationPositions.keys {
            if let alignedIdx = canPositionMap[pos] {
                let localIdx = alignedIdx - startIndex
                if localIdx >= 0 && localIdx < canonicalChunk.count {
                    result.insert(localIdx)
                }
            }
        }
        return result
    }

    private var customPTMAlignedPositions: Set<Int> {
        var result = Set<Int>()
        for pos in customPTMPositions.keys {
            if let alignedIdx = canPositionMap[pos] {
                let localIdx = alignedIdx - startIndex
                if localIdx >= 0 && localIdx < canonicalChunk.count {
                    result.insert(localIdx)
                }
            }
        }
        return result
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            // Position ruler row
            positionRulerRow

            // Reference sequence row ("Ref") - on top
            referenceRow

            // Match/mismatch indicator row
            matchIndicatorRow

            // Experimental sequence row ("Exp") - below
            experimentalRow

            // Custom PTM row ("Cust") - only if there are any
            if !customPTMAlignedPositions.isEmpty {
                customPTMRow
            }

            // Position numbers row
            positionNumbersRow
        }
    }

    // MARK: - Row Views

    private var positionRulerRow: some View {
        HStack(spacing: 0) {
            Text("    ")
                .font(.system(size: 9, design: .monospaced))
                .frame(width: 36, alignment: .trailing)

            ForEach(0..<expChars.count, id: \.self) { idx in
                let globalPos = startIndex + idx + 1
                Text(globalPos % 10 == 0 ? "|" : (globalPos % 5 == 0 ? "." : " "))
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 0.5)
            }
        }
    }

    private var experimentalRow: some View {
        HStack(spacing: 0) {
            Text("Exp")
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.accentColor)
                .frame(width: 36, alignment: .trailing)

            ForEach(0..<expChars.count, id: \.self) { idx in
                let char = expChars[idx]
                let canChar: Character = idx < canChars.count ? canChars[idx] : "-"
                let isExpPTM = expPtmAlignedPositions.contains(idx)

                let bgColor: Color = getExpBackgroundColor(char: char, canChar: canChar, isExpPTM: isExpPTM)

                Text(String(char))
                    .font(.system(size: 11, design: .monospaced))
                    .background(bgColor)
                    .padding(.horizontal, 0.5)
            }
        }
    }

    private var matchIndicatorRow: some View {
        HStack(spacing: 0) {
            Text("    ")
                .font(.system(size: 9, design: .monospaced))
                .frame(width: 36, alignment: .trailing)

            ForEach(0..<expChars.count, id: \.self) { idx in
                let expChar = expChars[idx]
                let canChar: Character = idx < canChars.count ? canChars[idx] : "-"

                let (indicator, indicatorColor) = getMatchIndicator(expChar: expChar, canChar: canChar)

                Text(indicator)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(indicatorColor)
                    .padding(.horizontal, 0.5)
            }
        }
    }

    private var referenceRow: some View {
        HStack(spacing: 0) {
            Text("Ref")
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 36, alignment: .trailing)

            ForEach(0..<canChars.count, id: \.self) { idx in
                let char = canChars[idx]
                let expChar: Character = idx < expChars.count ? expChars[idx] : "-"
                let isUniprotMod = uniprotModAlignedPositions.contains(idx)

                let bgColor: Color = getRefBackgroundColor(char: char, expChar: expChar, isUniprotMod: isUniprotMod)

                Text(String(char))
                    .font(.system(size: 11, design: .monospaced))
                    .background(bgColor)
                    .padding(.horizontal, 0.5)
            }
        }
    }

    private var customPTMRow: some View {
        HStack(spacing: 0) {
            Text("Cust")
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(customPTMColor)
                .frame(width: 36, alignment: .trailing)

            ForEach(0..<canChars.count, id: \.self) { idx in
                let char = canChars[idx]
                let isCustomPTM = customPTMAlignedPositions.contains(idx)

                let bgColor: Color = (char != "-" && isCustomPTM) ? customPTMColor.opacity(0.4) : .clear

                Text(isCustomPTM ? String(char) : " ")
                    .font(.system(size: 11, design: .monospaced))
                    .background(bgColor)
                    .padding(.horizontal, 0.5)
            }
        }
    }

    private var positionNumbersRow: some View {
        HStack(spacing: 0) {
            Text(String(format: "%4d", startIndex + 1))
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 36, alignment: .trailing)

            Spacer()

            Text("\(startIndex + experimentalChunk.count)")
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Helper Methods

    private func getExpBackgroundColor(char: Character, canChar: Character, isExpPTM: Bool) -> Color {
        if char == "-" {
            return gapColor.opacity(0.2)
        } else if isExpPTM {
            return experimentalPTMColor.opacity(0.4)
        } else if char == canChar {
            return .clear
        } else {
            return mismatchColor.opacity(0.3)
        }
    }

    private func getRefBackgroundColor(char: Character, expChar: Character, isUniprotMod: Bool) -> Color {
        if char == "-" {
            return gapColor.opacity(0.2)
        } else if isUniprotMod {
            return uniprotPTMColor.opacity(0.4)
        } else if char == expChar {
            return .clear
        } else {
            return mismatchColor.opacity(0.3)
        }
    }

    private func getMatchIndicator(expChar: Character, canChar: Character) -> (String, Color) {
        if expChar == "-" || canChar == "-" {
            return (" ", .clear)
        } else if expChar == canChar {
            return ("|", matchColor)
        } else {
            return (".", mismatchColor)
        }
    }
}

#Preview {
    AlignmentChunk(
        experimentalChunk: "MKLPVRGSSTESTSEQUENCE",
        canonicalChunk: "MKLPVRGSSTESTSEQUENCE",
        startIndex: 0,
        experimentalPositions: [:],
        modificationPositions: [:],
        customPTMPositions: [:],
        expPositionMap: [:],
        canPositionMap: [:]
    )
    .padding()
}

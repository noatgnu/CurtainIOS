//
//  SequenceAlignmentService.swift
//  Curtain
//
//  Service for sequence alignment and PTM position mapping
//  Implements Smith-Waterman dynamic programming algorithm
//

import Foundation

class SequenceAlignmentService {

    // MARK: - Singleton

    static let shared = SequenceAlignmentService()

    // MARK: - Constants

    private let MATCH_SCORE = 2
    private let MISMATCH_PENALTY = -1
    private let GAP_PENALTY = -2
    private let FUZZY_MATCH_THRESHOLD = 0.8

    private init() {}

    // MARK: - Needleman-Wunsch Global Sequence Alignment (matches Android implementation)

    /// Performs Needleman-Wunsch global sequence alignment
    /// Exact copy of Android implementation
    /// - Parameters:
    ///   - experimentalSequence: The experimental/query sequence
    ///   - canonicalSequence: The reference/canonical sequence
    /// - Returns: AlignedSequencePair with alignment results
    func alignSequences(
        experimentalSequence: String,
        canonicalSequence: String
    ) -> AlignedSequencePair {
        // Clean and uppercase sequences (Android: filter { it.isLetter() })
        let seq1 = experimentalSequence.uppercased().filter { $0.isLetter }
        let seq2 = canonicalSequence.uppercased().filter { $0.isLetter }

        if seq1.isEmpty || seq2.isEmpty {
            return AlignedSequencePair(
                experimentalSequence: seq1,
                canonicalSequence: seq2,
                experimentalAligned: seq1,
                canonicalAligned: seq2,
                experimentalPositionMap: [:],
                canonicalPositionMap: [:]
            )
        }

        let seq1Array = Array(seq1)
        let seq2Array = Array(seq2)
        let m = seq1Array.count
        let n = seq2Array.count

        // Initialize DP matrix with gap penalties (Needleman-Wunsch)
        var dp = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)

        // Initialize first row and column with gap penalties
        for i in 0...m { dp[i][0] = i * GAP_PENALTY }
        for j in 0...n { dp[0][j] = j * GAP_PENALTY }

        // Fill the DP matrix
        for i in 1...m {
            for j in 1...n {
                let matchScore = seq1Array[i - 1] == seq2Array[j - 1] ? MATCH_SCORE : MISMATCH_PENALTY
                dp[i][j] = max(
                    dp[i - 1][j - 1] + matchScore,
                    dp[i - 1][j] + GAP_PENALTY,
                    dp[i][j - 1] + GAP_PENALTY
                )
            }
        }

        // Traceback from bottom-right corner
        var aligned1 = ""
        var aligned2 = ""
        var posMap1: [Int: Int] = [:]
        var posMap2: [Int: Int] = [:]

        var i = m
        var j = n

        while i > 0 || j > 0 {
            if i > 0 && j > 0 {
                let matchScore = seq1Array[i - 1] == seq2Array[j - 1] ? MATCH_SCORE : MISMATCH_PENALTY
                if dp[i][j] == dp[i - 1][j - 1] + matchScore {
                    aligned1 = String(seq1Array[i - 1]) + aligned1
                    aligned2 = String(seq2Array[j - 1]) + aligned2
                    i -= 1
                    j -= 1
                    continue
                }
            }
            if i > 0 && dp[i][j] == dp[i - 1][j] + GAP_PENALTY {
                aligned1 = String(seq1Array[i - 1]) + aligned1
                aligned2 = "-" + aligned2
                i -= 1
            } else {
                aligned1 = "-" + aligned1
                aligned2 = String(seq2Array[j - 1]) + aligned2
                j -= 1
            }
        }

        // Build position maps (1-indexed positions to aligned indices)
        var expPos = 0
        var canPos = 0
        for idx in aligned1.indices.enumerated() {
            let alignedIdx = idx.offset
            if aligned1[aligned1.index(aligned1.startIndex, offsetBy: alignedIdx)] != "-" {
                expPos += 1
                posMap1[expPos] = alignedIdx
            }
            if aligned2[aligned2.index(aligned2.startIndex, offsetBy: alignedIdx)] != "-" {
                canPos += 1
                posMap2[canPos] = alignedIdx
            }
        }

        return AlignedSequencePair(
            experimentalSequence: seq1,
            canonicalSequence: seq2,
            experimentalAligned: aligned1,
            canonicalAligned: aligned2,
            experimentalPositionMap: posMap1,
            canonicalPositionMap: posMap2
        )
    }

    // MARK: - Peptide Alignment

    /// Aligns a peptide sequence to a protein sequence
    /// - Parameters:
    ///   - peptideSequence: The peptide to align (may contain modification notations)
    ///   - canonicalSequence: The protein sequence
    /// - Returns: Tuple of (start, end) positions (1-indexed) or nil if not found
    func alignPeptideToSequence(
        peptideSequence: String,
        canonicalSequence: String
    ) -> (start: Int, end: Int)? {
        // Clean peptide sequence (remove modification notations like [Phospho])
        let cleanedPeptide = cleanPeptideSequence(peptideSequence)
        let cleanedCanonical = canonicalSequence.uppercased()
        let cleanedPeptideUpper = cleanedPeptide.uppercased()

        // Try exact match first
        if let range = cleanedCanonical.range(of: cleanedPeptideUpper) {
            let start = cleanedCanonical.distance(from: cleanedCanonical.startIndex, to: range.lowerBound) + 1
            let end = start + cleanedPeptide.count - 1
            return (start, end)
        }

        // Try fuzzy match with 80% threshold
        return fuzzyAlignPeptide(peptide: cleanedPeptideUpper, sequence: cleanedCanonical)
    }

    /// Performs fuzzy peptide alignment with similarity threshold
    private func fuzzyAlignPeptide(peptide: String, sequence: String) -> (start: Int, end: Int)? {
        let peptideLength = peptide.count
        guard peptideLength > 0 else { return nil }

        var bestMatch: (start: Int, end: Int, score: Double)?

        let sequenceArray = Array(sequence)
        let peptideArray = Array(peptide)

        for i in 0...(sequence.count - peptideLength) {
            var matches = 0
            for j in 0..<peptideLength {
                if sequenceArray[i + j] == peptideArray[j] {
                    matches += 1
                }
            }

            let similarity = Double(matches) / Double(peptideLength)
            if similarity >= FUZZY_MATCH_THRESHOLD {
                if bestMatch == nil || similarity > bestMatch!.score {
                    bestMatch = (i + 1, i + peptideLength, similarity)
                }
            }
        }

        if let match = bestMatch {
            return (match.start, match.end)
        }
        return nil
    }

    /// Cleans peptide sequence by removing modification notations
    func cleanPeptideSequence(_ peptide: String) -> String {
        // Remove common modification notations like [Phospho], (ph), etc.
        var cleaned = peptide

        // Remove bracketed modifications [...]
        let bracketPattern = "\\[[^\\]]*\\]"
        cleaned = cleaned.replacingOccurrences(of: bracketPattern, with: "", options: .regularExpression)

        // Remove parenthesized modifications (...)
        let parenPattern = "\\([^)]*\\)"
        cleaned = cleaned.replacingOccurrences(of: parenPattern, with: "", options: .regularExpression)

        // Remove underscores and dots
        cleaned = cleaned.replacingOccurrences(of: "_", with: "")
        cleaned = cleaned.replacingOccurrences(of: ".", with: "")

        // Keep only amino acid letters
        let allowedChars = CharacterSet(charactersIn: "ACDEFGHIKLMNPQRSTVWYacdefghiklmnpqrstvwy")
        cleaned = String(cleaned.unicodeScalars.filter { allowedChars.contains($0) })

        return cleaned
    }

    // MARK: - PTM Position Extraction

    /// Extracts PTM positions from a peptide with modification notation
    /// - Parameters:
    ///   - peptideSequence: Peptide with modifications like "PEPTs[Phospho]IDE"
    ///   - startPosition: Starting position of peptide in protein (1-indexed)
    /// - Returns: Array of PTMPosition objects
    func extractPTMPositionFromPeptide(
        peptideSequence: String,
        startPosition: Int
    ) -> [PTMPosition] {
        var positions: [PTMPosition] = []
        var cleanPos = 0  // Position in cleaned sequence
        var i = peptideSequence.startIndex

        while i < peptideSequence.endIndex {
            let char = peptideSequence[i]

            if char == "[" || char == "(" {
                // Extract modification name
                let closingChar: Character = char == "[" ? "]" : ")"
                if let endIdx = peptideSequence[i...].firstIndex(of: closingChar) {
                    let modStart = peptideSequence.index(after: i)
                    let modification = String(peptideSequence[modStart..<endIdx])

                    // The modified residue is the previous amino acid
                    if cleanPos > 0 {
                        let proteinPos = startPosition + cleanPos - 1
                        let cleanedPeptide = cleanPeptideSequence(peptideSequence)
                        let residueIdx = cleanedPeptide.index(cleanedPeptide.startIndex, offsetBy: cleanPos - 1)
                        let residue = cleanedPeptide[residueIdx]

                        positions.append(PTMPosition(
                            positionInPeptide: cleanPos,
                            positionInProtein: proteinPos,
                            residue: residue,
                            modification: modification
                        ))
                    }

                    i = peptideSequence.index(after: endIdx)
                    continue
                }
            }

            // Regular amino acid character
            if char.isLetter {
                cleanPos += 1
            }

            i = peptideSequence.index(after: i)
        }

        return positions
    }

    // MARK: - UniProt Feature Parsing

    /// Parses UniProt features from API response data
    /// Handles both Curtain format and standard UniProt API format
    /// - Parameter uniprotData: Dictionary from UniProt API
    /// - Returns: Array of UniProtFeature objects
    func parseUniProtFeatures(uniprotData: [String: Any]) -> [UniProtFeature] {
        var features: [UniProtFeature] = []

        // Try Curtain format: "Modified residue" as string with "MOD_RES" entries
        if let modResString = uniprotData["Modified residue"] as? String, !modResString.isEmpty {
            let parts = modResString.components(separatedBy: "; ")
            var currentPosition = -1

            for part in parts {
                if part.hasPrefix("MOD_RES") {
                    let positionParts = part.components(separatedBy: " ")
                    if positionParts.count >= 2, let pos = Int(positionParts[1]) {
                        currentPosition = pos
                    }
                } else if part.contains("note=") && currentPosition > 0 {
                    // Extract modification type from note="..."
                    if let range = part.range(of: "\"([^\"]+)\"", options: .regularExpression) {
                        let match = String(part[range])
                        let modType = match.trimmingCharacters(in: CharacterSet(charactersIn: "\""))

                        features.append(UniProtFeature(
                            type: .modifiedResidue,
                            startPosition: currentPosition,
                            endPosition: currentPosition,
                            description: modType
                        ))
                    }
                }
            }
        }

        // Try Curtain format: "Modified residue" as array
        if let modResArray = uniprotData["Modified residue"] as? [[String: Any]] {
            for modObj in modResArray {
                let position: Int
                if let posInt = modObj["position"] as? Int {
                    position = posInt
                } else if let posDouble = modObj["position"] as? Double {
                    position = Int(posDouble)
                } else if let posString = modObj["position"] as? String,
                          let posInt = Int(posString) {
                    position = posInt
                } else {
                    continue
                }

                let modType = modObj["modType"] as? String ?? "Modified residue"

                if position > 0 {
                    features.append(UniProtFeature(
                        type: .modifiedResidue,
                        startPosition: position,
                        endPosition: position,
                        description: modType
                    ))
                }
            }
        }

        // Try 'features' array (new UniProt API format)
        if let featuresArray = uniprotData["features"] as? [[String: Any]] {
            for featureDict in featuresArray {
                if let feature = parseFeatureDict(featureDict) {
                    features.append(feature)
                }
            }
        }

        // Try legacy format
        if let comments = uniprotData["comments"] as? [[String: Any]] {
            for comment in comments {
                if let type = comment["type"] as? String,
                   type == "PTM" || type == "FUNCTION" {
                    if let locations = comment["locations"] as? [[String: Any]] {
                        for location in locations {
                            if let feature = parseLocationDict(location, type: type) {
                                features.append(feature)
                            }
                        }
                    }
                }
            }
        }

        return features
    }

    private func parseFeatureDict(_ dict: [String: Any]) -> UniProtFeature? {
        guard let type = dict["type"] as? String else { return nil }

        var startPos = 1
        var endPos = 1

        if let location = dict["location"] as? [String: Any] {
            if let start = location["start"] as? [String: Any],
               let startValue = start["value"] as? Int {
                startPos = startValue
            }
            if let end = location["end"] as? [String: Any],
               let endValue = end["value"] as? Int {
                endPos = endValue
            }
        }

        let description = dict["description"] as? String ?? type
        let evidence = dict["evidences"] as? String

        return UniProtFeature(
            type: FeatureType.fromString(type),
            startPosition: startPos,
            endPosition: endPos,
            description: description,
            evidence: evidence
        )
    }

    private func parseLocationDict(_ dict: [String: Any], type: String) -> UniProtFeature? {
        var startPos = 1
        var endPos = 1

        if let start = dict["start"] as? Int {
            startPos = start
        }
        if let end = dict["end"] as? Int {
            endPos = end
        }

        let description = dict["description"] as? String ?? type

        return UniProtFeature(
            type: FeatureType.fromString(type),
            startPosition: startPos,
            endPosition: endPos,
            description: description,
            evidence: nil
        )
    }

    // MARK: - Domain Extraction

    /// Extracts protein domains from UniProt data
    /// Handles both Curtain format ("Domain [FT]") and standard UniProt API format
    func extractDomains(uniprotData: [String: Any]) -> [ProteinDomain] {
        var domains: [ProteinDomain] = []

        // Try Curtain format: "Domain [FT]" as string
        if let domainString = uniprotData["Domain [FT]"] as? String, !domainString.isEmpty {
            let parts = domainString.components(separatedBy: ";")
            var startPos = -1
            var endPos = -1

            for part in parts {
                let trimmed = part.trimmingCharacters(in: .whitespaces)

                if trimmed.contains("DOMAIN") {
                    // Extract positions: "DOMAIN 10 100" or "DOMAIN 10..100"
                    let regex = try? NSRegularExpression(pattern: "(\\d+)", options: [])
                    let matches = regex?.matches(in: trimmed, options: [], range: NSRange(trimmed.startIndex..., in: trimmed)) ?? []

                    let positions = matches.compactMap { match -> Int? in
                        if let range = Range(match.range, in: trimmed) {
                            return Int(trimmed[range])
                        }
                        return nil
                    }

                    if positions.count >= 2 {
                        startPos = positions[0]
                        endPos = positions[1]
                    }
                } else if trimmed.contains("/note=") && startPos > 0 {
                    // Extract domain name from note="..."
                    if let range = trimmed.range(of: "\"([^\"]+)\"", options: .regularExpression) {
                        let match = String(trimmed[range])
                        let domainName = match.trimmingCharacters(in: CharacterSet(charactersIn: "\""))

                        domains.append(ProteinDomain(
                            name: domainName,
                            startPosition: startPos,
                            endPosition: endPos,
                            description: domainName
                        ))

                        // Reset for next domain
                        startPos = -1
                        endPos = -1
                    }
                }
            }
        }

        // Try standard UniProt API format with "features" array
        if let features = uniprotData["features"] as? [[String: Any]] {
            for feature in features {
                guard let type = feature["type"] as? String,
                      type.lowercased() == "domain" else { continue }

                var startPos = 1
                var endPos = 1
                var name = "Unknown Domain"

                if let location = feature["location"] as? [String: Any] {
                    if let start = location["start"] as? [String: Any],
                       let startValue = start["value"] as? Int {
                        startPos = startValue
                    }
                    if let end = location["end"] as? [String: Any],
                       let endValue = end["value"] as? Int {
                        endPos = endValue
                    }
                }

                if let desc = feature["description"] as? String {
                    name = desc
                }

                domains.append(ProteinDomain(
                    name: name,
                    startPosition: startPos,
                    endPosition: endPos,
                    description: feature["description"] as? String
                ))
            }
        }

        return domains
    }

    // MARK: - Modification Parsing

    /// Parses modifications from UniProt data
    /// Handles both Curtain format (string-based "Modified residue") and standard UniProt API format
    func parseModifications(uniprotData: [String: Any]) -> [ParsedModification] {
        var modifications: [ParsedModification] = []
        let sequence = extractSequence(uniprotData: uniprotData) ?? ""

        print("[SequenceAlignmentService] parseModifications called, sequence length: \(sequence.count)")

        // Check what format Modified residue is in
        if let modRes = uniprotData["Modified residue"] {
            print("[SequenceAlignmentService] 'Modified residue' type: \(type(of: modRes))")
            if let modResString = modRes as? String {
                print("[SequenceAlignmentService] 'Modified residue' length: \(modResString.count)")
                print("[SequenceAlignmentService] 'Modified residue' first 500 chars:")
                print(String(modResString.prefix(500)))
            }
        } else {
            print("[SequenceAlignmentService] No 'Modified residue' key found")
        }

        // Try Curtain format: "Modified residue" as array of objects
        if let modResArray = uniprotData["Modified residue"] as? [[String: Any]] {
            for modObj in modResArray {
                // Handle position that might be Int, String, or Double
                let position: Int
                if let posInt = modObj["position"] as? Int {
                    position = posInt
                } else if let posDouble = modObj["position"] as? Double {
                    position = Int(posDouble)
                } else if let posString = modObj["position"] as? String,
                          let posInt = Int(posString) {
                    position = posInt
                } else {
                    continue
                }

                let residueStr = modObj["residue"] as? String ?? "?"
                let residue = residueStr.first ?? Character("?")
                let modType = modObj["modType"] as? String ?? ""

                if position > 0 && !modType.isEmpty {
                    modifications.append(ParsedModification(
                        position: position,
                        residue: residue,
                        modType: modType
                    ))
                }
            }
            return modifications
        }

        // Try Curtain format: "Modified residue" as string with "MOD_RES" entries
        // Exact copy of Android logic
        if let modResString = uniprotData["Modified residue"] as? String,
           !modResString.isEmpty,
           !sequence.isEmpty {

            let parts = modResString.components(separatedBy: "; ")
            var currentPosition = -1

            for part in parts {
                if part.hasPrefix("MOD_RES") {
                    // Extract position: "MOD_RES 15" -> 15
                    let spaceParts = part.components(separatedBy: " ")
                    if spaceParts.count >= 2, let pos = Int(spaceParts[1]) {
                        currentPosition = pos
                    }
                } else if part.contains("note=") && currentPosition > 0 {
                    // Extract mod type from note="..."
                    // Use regex "(.+?)" to find quoted text
                    if let regex = try? NSRegularExpression(pattern: "\"(.+?)\"", options: []),
                       let match = regex.firstMatch(in: part, options: [], range: NSRange(location: 0, length: part.utf16.count)),
                       match.numberOfRanges >= 2,
                       let typeRange = Range(match.range(at: 1), in: part) {

                        let modType = String(part[typeRange])
                        let residue: Character
                        if currentPosition > 0 && currentPosition <= sequence.count {
                            let idx = sequence.index(sequence.startIndex, offsetBy: currentPosition - 1)
                            residue = sequence[idx]
                        } else {
                            residue = Character("?")
                        }

                        modifications.append(ParsedModification(
                            position: currentPosition,
                            residue: residue,
                            modType: modType
                        ))
                    }
                }
            }

            if !modifications.isEmpty {
                print("[SequenceAlignmentService] Parsed \(modifications.count) modifications from string")
                return modifications
            }
        }

        // Fallback: Standard UniProt API format with "features" array
        if let features = uniprotData["features"] as? [[String: Any]] {
            for feature in features {
                guard let type = feature["type"] as? String,
                      type.lowercased().contains("modified") ||
                      type.lowercased().contains("phospho") ||
                      type.lowercased().contains("glyco") else { continue }

                var position = 1
                if let location = feature["location"] as? [String: Any],
                   let start = location["start"] as? [String: Any],
                   let startValue = start["value"] as? Int {
                    position = startValue
                }

                let description = feature["description"] as? String ?? type
                let modType = extractModificationType(from: description)

                // Get residue from sequence
                let residue: Character
                if position > 0 && position <= sequence.count {
                    let idx = sequence.index(sequence.startIndex, offsetBy: position - 1)
                    residue = sequence[idx]
                } else {
                    residue = Character("X")
                }

                modifications.append(ParsedModification(
                    position: position,
                    residue: residue,
                    modType: modType
                ))
            }
        }

        print("[SequenceAlignmentService] parseModifications returning \(modifications.count) modifications")
        return modifications
    }

    private func extractModificationType(from description: String) -> String {
        let lowercased = description.lowercased()

        if lowercased.contains("phospho") {
            return "Phosphorylation"
        } else if lowercased.contains("acetyl") {
            return "Acetylation"
        } else if lowercased.contains("methyl") {
            return "Methylation"
        } else if lowercased.contains("ubiquit") {
            return "Ubiquitination"
        } else if lowercased.contains("glyco") {
            return "Glycosylation"
        } else if lowercased.contains("sumo") {
            return "SUMOylation"
        }

        return description
    }

    /// Gets unique modification types from parsed modifications
    func getAvailableModTypes(modifications: [ParsedModification]) -> [String] {
        return Array(Set(modifications.map { $0.modType })).sorted()
    }

    // MARK: - PTM Site Comparison

    /// Compares experimental PTM sites with UniProt known sites
    func comparePTMSites(
        experimentalSites: [ExperimentalPTMSite],
        uniprotFeatures: [UniProtFeature],
        canonicalSequence: String
    ) -> [PTMSiteComparison] {
        var comparisons: [PTMSiteComparison] = []

        // Get all modified residue features
        let modifiedResidues = uniprotFeatures.filter { $0.type == .modifiedResidue }

        // Create a set of known positions
        var knownPositions: Set<Int> = Set(modifiedResidues.map { $0.startPosition })

        // Process experimental sites
        for site in experimentalSites {
            let isKnown = knownPositions.contains(site.position)
            let uniprotFeature = modifiedResidues.first { $0.startPosition == site.position }

            comparisons.append(PTMSiteComparison(
                position: site.position,
                residue: site.residue,
                isExperimental: true,
                isKnownUniprot: isKnown,
                experimentalData: site,
                uniprotFeature: uniprotFeature
            ))

            knownPositions.remove(site.position)
        }

        // Add remaining UniProt-only sites
        for feature in modifiedResidues where knownPositions.contains(feature.startPosition) {
            let sequenceArray = Array(canonicalSequence)
            let residue: Character = feature.startPosition <= sequenceArray.count ?
                sequenceArray[feature.startPosition - 1] : "X"

            comparisons.append(PTMSiteComparison(
                position: feature.startPosition,
                residue: residue,
                isExperimental: false,
                isKnownUniprot: true,
                experimentalData: nil,
                uniprotFeature: feature
            ))
        }

        return comparisons.sorted { $0.position < $1.position }
    }

    // MARK: - Aligned Peptide Creation

    /// Creates an AlignedPeptide structure from peptide data
    func createAlignedPeptide(
        primaryId: String,
        peptideSequence: String,
        canonicalSequence: String,
        isSignificant: Bool
    ) -> AlignedPeptide? {
        guard let alignment = alignPeptideToSequence(
            peptideSequence: peptideSequence,
            canonicalSequence: canonicalSequence
        ) else {
            return nil
        }

        let ptmPositions = extractPTMPositionFromPeptide(
            peptideSequence: peptideSequence,
            startPosition: alignment.start
        )

        return AlignedPeptide(
            peptideSequence: cleanPeptideSequence(peptideSequence),
            startPosition: alignment.start,
            endPosition: alignment.end,
            ptmPositions: ptmPositions,
            primaryId: primaryId,
            isSignificant: isSignificant
        )
    }

    // MARK: - UniProt Data Extraction Helpers

    /// Extracts available isoforms from UniProt data
    /// Extracts available isoforms from UniProt data
    /// Handles both Curtain format and standard UniProt API format
    func extractAvailableIsoforms(uniprotData: [String: Any]) -> [String] {
        var isoforms: [String] = []

        // Try Curtain format: "Alternative products (isoforms)" as string
        if let altProducts = uniprotData["Alternative products (isoforms)"] as? String, !altProducts.isEmpty {
            let parts = altProducts.components(separatedBy: CharacterSet(charactersIn: "; "))
            for part in parts {
                if part.hasPrefix("IsoId=") {
                    let isoId = part.replacingOccurrences(of: "IsoId=", with: "").trimmingCharacters(in: .whitespaces)
                    if !isoId.isEmpty {
                        isoforms.append(isoId)
                    }
                }
            }

            if !isoforms.isEmpty {
                return isoforms
            }
        }

        // Fallback: Standard UniProt API format with "comments" array
        if let comments = uniprotData["comments"] as? [[String: Any]] {
            for comment in comments {
                if let type = comment["type"] as? String,
                   type == "ALTERNATIVE PRODUCTS" {
                    if let isoformList = comment["isoforms"] as? [[String: Any]] {
                        for isoform in isoformList {
                            if let ids = isoform["ids"] as? [String] {
                                isoforms.append(contentsOf: ids)
                            } else if let id = isoform["id"] as? String {
                                isoforms.append(id)
                            }
                        }
                    }
                }
            }
        }

        return isoforms
    }

    /// Extracts sequence from UniProt data
    /// Checks both Curtain format ("Sequence") and standard UniProt API format ("sequence")
    func extractSequence(uniprotData: [String: Any]) -> String? {
        print("[SequenceAlignmentService] extractSequence called with keys: \(uniprotData.keys.sorted())")

        // Curtain format: "Sequence" key with string value
        if let sequence = uniprotData["Sequence"] as? String, !sequence.isEmpty {
            print("[SequenceAlignmentService] Found 'Sequence' key, length: \(sequence.count)")
            return sequence
        }

        // Standard UniProt API format: "sequence" object with "value" key
        if let sequence = uniprotData["sequence"] as? [String: Any],
           let value = sequence["value"] as? String {
            print("[SequenceAlignmentService] Found 'sequence.value' key, length: \(value.count)")
            return value
        }

        // Fallback: lowercase "sequence" as direct string
        if let sequence = uniprotData["sequence"] as? String {
            print("[SequenceAlignmentService] Found 'sequence' (string) key, length: \(sequence.count)")
            return sequence
        }

        print("[SequenceAlignmentService] No sequence found in UniProt data")
        return nil
    }

    /// Extracts gene name from UniProt data
    /// Handles both Curtain format ("Gene Names") and standard UniProt API format
    func extractGeneName(uniprotData: [String: Any]) -> String? {
        // Try Curtain format: "Gene Names" as string
        if let geneNames = uniprotData["Gene Names"] as? String, !geneNames.isEmpty {
            // Split by semicolon, space, or backslash and get first non-empty part
            let separators = CharacterSet(charactersIn: "; \\")
            let parts = geneNames.components(separatedBy: separators)
            return parts.first { !$0.trimmingCharacters(in: .whitespaces).isEmpty }?
                .trimmingCharacters(in: .whitespaces)
        }

        // Fallback: Standard UniProt API format with "genes" array
        if let genes = uniprotData["genes"] as? [[String: Any]],
           let firstGene = genes.first {
            if let geneName = firstGene["geneName"] as? [String: Any],
               let value = geneName["value"] as? String {
                return value
            }
            if let primary = firstGene["primary"] as? String {
                return primary
            }
        }

        return nil
    }

    /// Extracts protein name from UniProt data
    func extractProteinName(uniprotData: [String: Any]) -> String? {
        if let protein = uniprotData["proteinDescription"] as? [String: Any] {
            if let recommendedName = protein["recommendedName"] as? [String: Any],
               let fullName = recommendedName["fullName"] as? [String: Any],
               let value = fullName["value"] as? String {
                return value
            }
        }

        if let proteinName = uniprotData["Protein names"] as? String {
            return proteinName
        }

        return nil
    }

    /// Extracts organism from UniProt data
    func extractOrganism(uniprotData: [String: Any]) -> String? {
        if let organism = uniprotData["organism"] as? [String: Any],
           let scientificName = organism["scientificName"] as? String {
            return scientificName
        }

        if let organism = uniprotData["Organism"] as? String {
            return organism
        }

        return nil
    }
}

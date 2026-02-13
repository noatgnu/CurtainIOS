//
//  RealDataTestConstants.swift
//  CurtainTests
//
//  Constants derived from actual TP and PTM example datasets.
//  All values are verified from real server data.
//
//  Generated from:
//  - TP:  https://celsus.muttsu.xyz/curtain/f4b009f3-ac3c-470a-a68b-55fcadf68d0f
//  - PTM: https://celsus.muttsu.xyz/curtain/85970b1d-8052-4d6f-bf67-654396534d76
//

import Foundation

// MARK: - TP Dataset Constants (f4b009f3-ac3c-470a-a68b-55fcadf68d0f)

struct TPDatasetConstants {
    static let linkId = "f4b009f3-ac3c-470a-a68b-55fcadf68d0f"

    // UniProt DB
    static let uniprotEntryCount = 8612
    static let processedRowCount = 8609  // Excluding header (verified from real data)

    // Settings (exact values from real data)
    static let pCutoff = 0.05
    static let log2FCCutoff = 0.6
    static let conditionOrder = ["4Hr-AGB1", "24Hr-AGB1", "4Hr-Cis", "24Hr-Cis"]
    static let fetchUniprot = true

    // DifferentialForm columns
    static let primaryIDsColumn = "Index"
    static let foldChangeColumn = "Difference(Log2): 4HrAGB1/4HrCis"
    static let significantColumn = "pValue(-Log10): 4HrAGB1/4HrCis"
    static let comparisonColumn = "Comparison.1"

    // Sample order (exact from real data)
    static let sampleOrder: [String: [String]] = [
        "4Hr-AGB1": ["4Hr-AGB1.01", "4Hr-AGB1.02", "4Hr-AGB1.03", "4Hr-AGB1.04", "4Hr-AGB1.05"],
        "24Hr-AGB1": ["24Hr-AGB1.01", "24Hr-AGB1.02", "24Hr-AGB1.03", "24Hr-AGB1.04", "24Hr-AGB1.05"],
        "4Hr-Cis": ["4Hr-Cis.01", "4Hr-Cis.02", "4Hr-Cis.03"],
        "24Hr-Cis": ["24Hr-Cis.01", "24Hr-Cis.02", "24Hr-Cis.03"]
    ]

    // Color map (exact colors from real data)
    static let colorMap: [String: String] = [
        "P-value < 0.05;FC <= 0.6 (1)": "#1f77b4",
        "P-value >= 0.05;FC <= 0.6 (1)": "#ff7f0e",
        "P-value >= 0.05;FC > 0.6 (1)": "#2ca02c",
        "P-value < 0.05;FC > 0.6 (1)": "#d62728",
        "PPM1H;ARHCL1;KIAA1157;URCC2[Q9ULR3] (1)": "#9467bd",
        "P-value > 0.05;FC <= 0.6 (1)": "#fd7f6f",
        "P-value <= 0.05;FC <= 0.6 (1)": "#7eb0d5",
        "P-value <= 0.05;FC > 0.6 (1)": "#b2e061",
        "P-value > 0.05;FC > 0.6 (1)": "#bd7ebe",
        "LRRK2 Pathway (1)": "#ffb55a"
    ]

    // Default color list (exact from real data)
    static let defaultColorList = [
        "#fd7f6f", "#7eb0d5", "#b2e061", "#bd7ebe", "#ffb55a",
        "#ffee65", "#beb9db", "#fdcce5", "#8bd3c7"
    ]

    // Known protein -> gene mappings (verified from processed data)
    struct ProteinEntry {
        let id: String
        let gene: String
        let foldChange: Double
        let pValue: Double  // -log10 p-value
        let isSignificant: Bool
    }

    static let knownProteins: [ProteinEntry] = [
        ProteinEntry(id: "Q2M2I8", gene: "AAK1", foldChange: 0.013686244, pValue: 0.173648525, isSignificant: false),
        ProteinEntry(id: "P00519", gene: "ABL1", foldChange: -0.190635935, pValue: 0.672564698, isSignificant: false),
        ProteinEntry(id: "P42684", gene: "ABL2", foldChange: 0.011370341, pValue: 0.118609138, isSignificant: false),
        ProteinEntry(id: "Q04771", gene: "ACVR1", foldChange: -0.016243362, pValue: 0.093948158, isSignificant: false),
        ProteinEntry(id: "P36896", gene: "ACVR1B", foldChange: -0.443786112, pValue: 1.262699463, isSignificant: false),
        ProteinEntry(id: "Q86TW2", gene: "ADCK1", foldChange: -0.020840708, pValue: 0.077586833, isSignificant: false),
        ProteinEntry(id: "Q3MIX3", gene: "ADCK5", foldChange: -0.10810407, pValue: 1.093131358, isSignificant: false),
        ProteinEntry(id: "P31749", gene: "AKT1", foldChange: 0.066013972, pValue: 0.75767337, isSignificant: false),
        ProteinEntry(id: "P31751", gene: "AKT2", foldChange: -0.028311412, pValue: 0.221600445, isSignificant: false),
        ProteinEntry(id: "Q9Y243", gene: "AKT3", foldChange: 0.208109156, pValue: 2.099134728, isSignificant: false)
    ]

    // Significance counts (verified from real data)
    static let significantCount = 1
    static let notSignificantCount = 8608
    static let totalProcessedCount = 8609

    // Q2M2I8 (AAK1) full gene names from UniProt DB
    static let aak1GeneNames = "AAK1;KIAA1048"

    // Volcano plot categories (for visibility and color assignment)
    static let volcanoCategories = [
        "P-value <= 0.05;FC > 0.6",
        "P-value <= 0.05;FC <= 0.6",
        "P-value > 0.05;FC > 0.6",
        "P-value > 0.05;FC <= 0.6"
    ]
}

// MARK: - PTM Dataset Constants (85970b1d-8052-4d6f-bf67-654396534d76)

struct PTMDatasetConstants {
    static let linkId = "85970b1d-8052-4d6f-bf67-654396534d76"

    // UniProt DB
    static let uniprotEntryCount = 2277

    // Settings (exact values from real data)
    static let pCutoff = 0.05
    static let log2FCCutoff = 0.6
    static let fetchUniprot = true

    // DifferentialForm columns (PTM-specific)
    static let primaryIDsColumn = "Index"
    static let accessionColumn = "ProteinID"
    static let positionColumn = "Position"
    static let positionPeptideColumn = "Position.in.peptide"
    static let peptideSequenceColumn = "Peptide"
    static let scoreColumn = "MaxPepProb"
    static let sequenceColumn = "SequenceWindow"
    static let foldChangeColumn = "Welch's T-test Difference AO_UT"
    static let significantColumn = "-Log Welch's T-test p-value AO_UT"
    static let comparisonColumn = "CurtainSetComparison"

    // Sample order (exact from real data)
    static let sampleOrder: [String: [String]] = [
        "UT": ["UT.01", "UT.02", "UT.03", "UT.04", "UT.05"],
        "AO": ["AO.01", "AO.02", "AO.03", "AO.04", "AO.05"]
    ]

    // Sample visibility (exact from real data)
    static let sampleVisible: [String: Bool] = [
        "UT.01": true, "UT.02": true, "UT.03": true, "UT.04": true, "UT.05": true,
        "AO.01": true, "AO.02": true, "AO.03": true, "AO.04": true, "AO.05": true
    ]

    // Color map (exact from real data)
    static let colorMap: [String: String] = [
        "P-value <= 0.05;FC > 0.6": "rgba(232,245,223,0.95)",
        "P-value <= 0.05;FC <= 0.6": "#7eb0d5",
        "P-value > 0.05;FC <= 0.6": "#fd7f6f",
        "P-value > 0.05;FC > 0.6": "#bd7ebe",
        "Old sites": "rgba(11,190,194,0.98)",
        "New sites": "#f14d6c"
    ]

    // Default color list (exact from real data)
    static let defaultColorList = [
        "#fd7f6f", "#7eb0d5", "#b2e061", "#bd7ebe", "#ffb55a",
        "#ffee65", "#beb9db", "#fdcce5", "#8bd3c7"
    ]

    // Visible categories (exact from real data)
    static let visibleCategories: [String: Bool] = [
        "New sites": true,
        "P-value <= 0.05;FC > 0.6": true,
        "P-value > 0.05;FC <= 0.6": true,
        "P-value > 0.05;FC > 0.6": true,
        "P-value <= 0.05;FC <= 0.6": true,
        "Old sites": true
    ]

    // Sample PTM entries (verified from processed data)
    struct PTMEntry {
        let primaryId: String
        let gene: String
        let accession: String
        let position: Int
        let peptide: String
        let foldChange: Double
        let pValue: Double  // -log10 p-value
        let isSignificant: Bool
    }

    static let samplePTMEntries: [PTMEntry] = [
        PTMEntry(
            primaryId: "A0A1W2P872_K427",
            gene: "Nova2",
            accession: "A0A1W2P872",
            position: 427,
            peptide: "GGkTLVEYQELTGAR",  // lowercase k = modified lysine
            foldChange: 1.01620636,
            pValue: 3.787477242,
            isSignificant: true
        ),
        PTMEntry(
            primaryId: "A0A1W2P872_K67",
            gene: "Nova2",
            accession: "A0A1W2P872",
            position: 67,
            peptide: "ETGATIkLSK",
            foldChange: 0.265635872,
            pValue: 2.556779037,
            isSignificant: true
        ),
        PTMEntry(
            primaryId: "A0PJN4_K142",
            gene: "Ube2ql1",
            accession: "A0PJN4",
            position: 142,
            peptide: "EAEATFkSLVK",
            foldChange: 0.085608482,
            pValue: 0.845206977,
            isSignificant: false
        ),
        PTMEntry(
            primaryId: "A1L3P4_K561",
            gene: "Slc9a6",
            accession: "A1L3P4",
            position: 561,
            peptide: "TTkAESAWLFR",
            foldChange: 0.016175079,
            pValue: 0.092990876,
            isSignificant: false
        ),
        PTMEntry(
            primaryId: "A2A432_K665",
            gene: "Cul4b",
            accession: "A2A432",
            position: 665,
            peptide: "DVFEAFYkK",
            foldChange: 0.421013641,
            pValue: 1.90913456,
            isSignificant: true
        )
    ]

    // Significance counts (verified from real data)
    static let significantCount = 3381
    static let notSignificantCount = 2654
    static let totalProcessedCount = 6035

    // Known accessions from UniProt DB
    static let knownAccessions = ["A0A1W2P872", "A0PJN4", "A1L3P4"]
}

// MARK: - Volcano Plot Test Constants

struct VolcanoPlotTestConstants {
    // Volcano plot point categories based on cutoffs
    static func categorizePoint(
        pValue: Double,
        foldChange: Double,
        pCutoff: Double,
        fcCutoff: Double
    ) -> String {
        let isSignificantP = pValue >= -log10(pCutoff)  // -log10 transformed p-value
        let isSignificantFC = abs(foldChange) > fcCutoff

        if isSignificantP && isSignificantFC {
            return foldChange > 0 ? "P-value <= 0.05;FC > 0.6" : "P-value <= 0.05;FC > 0.6"
        } else if isSignificantP {
            return "P-value <= 0.05;FC <= 0.6"
        } else if isSignificantFC {
            return "P-value > 0.05;FC > 0.6"
        } else {
            return "P-value > 0.05;FC <= 0.6"
        }
    }

    // Expected colors for each category (default)
    static let categoryColors: [String: String] = [
        "P-value <= 0.05;FC > 0.6": "#b2e061",
        "P-value <= 0.05;FC <= 0.6": "#7eb0d5",
        "P-value > 0.05;FC > 0.6": "#bd7ebe",
        "P-value > 0.05;FC <= 0.6": "#fd7f6f"
    ]
}

// MARK: - Bar Chart Test Constants

struct BarChartTestConstants {
    // Bar chart displays raw intensity values for selected proteins
    // Conditions are shown on X-axis, intensity on Y-axis

    // For TP dataset: expects 4 condition groups
    static let tpConditionCount = 4

    // For PTM dataset: expects 2 condition groups (UT, AO)
    static let ptmConditionCount = 2

    // Statistical bracket structure
    struct StatisticalBracket {
        let condition1: String
        let condition2: String
        let pValue: Double
        let isSignificant: Bool
    }
}

// MARK: - Annotation Test Constants

struct AnnotationTestConstants {
    // Text annotations on volcano plot
    struct TextAnnotation {
        let primaryId: String
        let text: String
        let x: Double  // fold change position
        let y: Double  // -log10 p-value position
    }

    // Selection group for volcano plot
    struct SelectionGroup {
        let name: String
        let color: String
        let primaryIds: [String]
    }

    // For testing annotation creation/movement
    static let testAnnotationText = "Test Annotation"
    static let testAnnotationOffsetX: Double = 10.0
    static let testAnnotationOffsetY: Double = 10.0
}

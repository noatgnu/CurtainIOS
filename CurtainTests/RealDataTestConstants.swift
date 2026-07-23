//
//  RealDataTestConstants.swift
//  CurtainTests
//
//  Constants derived from actual TP and PTM example datasets.
//  All values verified from fixture JSON files in CurtainTests/Fixtures/.
//
//  Fixture sources (downloaded from API):
//  - TP:  CurtainTests/Fixtures/tp_dataset.json
//  - PTM: CurtainTests/Fixtures/ptm_dataset.json
//

import Foundation

// MARK: - TP Dataset Constants (f4b009f3-ac3c-470a-a68b-55fcadf68d0f)

struct TPDatasetConstants {
    static let linkId = "f4b009f3-ac3c-470a-a68b-55fcadf68d0f"

    // Settings
    static let pCutoff = 0.05
    static let log2FCCutoff = 0.6
    static let fetchUniprot = true
    static let settingsVersion = 2.0

    // DifferentialForm columns
    static let primaryIDsColumn = "Index"
    static let foldChangeColumn = "Difference(Log2): 4HrAGB1/4HrCis"
    static let significantColumn = "pValue(-Log10): 4HrAGB1/4HrCis"
    static let comparisonColumn = "Comparison.1"
    static let comparisonSelect = ["1"]

    // Condition/sample order
    static let conditionOrder = ["4Hr-AGB1", "24Hr-AGB1", "4Hr-Cis", "24Hr-Cis"]
    static let sampleOrder: [String: [String]] = [
        "4Hr-AGB1": ["4Hr-AGB1.01", "4Hr-AGB1.02", "4Hr-AGB1.03", "4Hr-AGB1.04", "4Hr-AGB1.05"],
        "24Hr-AGB1": ["24Hr-AGB1.01", "24Hr-AGB1.02", "24Hr-AGB1.03", "24Hr-AGB1.04", "24Hr-AGB1.05"],
        "4Hr-Cis": ["4Hr-Cis.01", "4Hr-Cis.02", "4Hr-Cis.03"],
        "24Hr-Cis": ["24Hr-Cis.01", "24Hr-Cis.02", "24Hr-Cis.03"]
    ]

    // Color map (exact from fixture JSON settings.colorMap — includes both legacy and current keys)
    static let colorMap: [String: String] = [
        // Legacy keys (stale, from older web app using < / >= operators)
        "P-value < 0.05;FC <= 0.6 (1)": "#1f77b4",
        "P-value < 0.05;FC > 0.6 (1)": "#d62728",
        "P-value >= 0.05;FC <= 0.6 (1)": "#ff7f0e",
        "P-value >= 0.05;FC > 0.6 (1)": "#2ca02c",
        // Current keys (matching web/Android/iOS using <= / > operators)
        "P-value <= 0.05;FC <= 0.6 (1)": "#7eb0d5",
        "P-value <= 0.05;FC > 0.6 (1)": "#b2e061",
        "P-value > 0.05;FC <= 0.6 (1)": "#fd7f6f",
        "P-value > 0.05;FC > 0.6 (1)": "#bd7ebe",
        // User selection keys
        "PPM1H;ARHCL1;KIAA1157;URCC2[Q9ULR3] (1)": "#9467bd",
        "LRRK2 Pathway (1)": "#ffb55a"
    ]

    // Default color list
    static let defaultColorList = [
        "#fd7f6f", "#7eb0d5", "#b2e061", "#bd7ebe", "#ffb55a",
        "#ffee65", "#beb9db", "#fdcce5", "#8bd3c7"
    ]

    // User selections
    static let selectionsName = [
        "PPM1H;ARHCL1;KIAA1157;URCC2[Q9ULR3] (1)",
        "LRRK2 Pathway (1)"
    ]

    // selectionsMap: protein ID -> { selection name -> true }
    // 20 entries total, Q9ULR3 belongs to both selections
    static let selectionsMap: [String: [String: Bool]] = [
        "O14966": ["LRRK2 Pathway (1)": true],
        "O60271": ["LRRK2 Pathway (1)": true],
        "O95716": ["LRRK2 Pathway (1)": true],
        "P20337": ["LRRK2 Pathway (1)": true],
        "P37840": ["LRRK2 Pathway (1)": true],
        "P51149": ["LRRK2 Pathway (1)": true],
        "P61006": ["LRRK2 Pathway (1)": true],
        "P61026": ["LRRK2 Pathway (1)": true],
        "P62820": ["LRRK2 Pathway (1)": true],
        "Q15286": ["LRRK2 Pathway (1)": true],
        "Q5EBL4": ["LRRK2 Pathway (1)": true],
        "Q5S007": ["LRRK2 Pathway (1)": true],
        "Q5VZ89": ["LRRK2 Pathway (1)": true],
        "Q6IQ22": ["LRRK2 Pathway (1)": true],
        "Q86T03": ["LRRK2 Pathway (1)": true],
        "Q86YS6": ["LRRK2 Pathway (1)": true],
        "Q92930": ["LRRK2 Pathway (1)": true],
        "Q96QK1": ["LRRK2 Pathway (1)": true],
        "Q9H0U4": ["LRRK2 Pathway (1)": true],
        "Q9ULR3": ["PPM1H;ARHCL1;KIAA1157;URCC2[Q9ULR3] (1)": true, "LRRK2 Pathway (1)": true]
    ]

    // Processed data counts
    static let processedRowCount = 8609

    // Significance counts (using pCutoff=0.05, log2FCCutoff=0.6)
    static let significantFCCount = 15         // P<=0.05 AND |FC|>0.6
    static let significantNoFCCount = 585      // P<=0.05 AND |FC|<=0.6
    static let notSignificantFCCount = 15      // P>0.05 AND |FC|>0.6
    static let notSignificantNoFCCount = 7994  // P>0.05 AND |FC|<=0.6

    // UniProt DB entry count (Map format with value array)
    static let uniprotDBEntryCount = 8612

    // Known proteins from first rows of processed data
    struct ProteinEntry {
        let id: String
        let gene: String
        let foldChange: Double
        let pValue: Double  // -log10 p-value
    }

    static let knownProteins: [ProteinEntry] = [
        ProteinEntry(id: "Q2M2I8", gene: "AAK1", foldChange: 0.013686244, pValue: 0.173648525),
        ProteinEntry(id: "P00519", gene: "ABL1", foldChange: -0.190635935, pValue: 0.672564698),
        ProteinEntry(id: "P42684", gene: "ABL2", foldChange: 0.011370341, pValue: 0.118609138),
        ProteinEntry(id: "Q04771", gene: "ACVR1", foldChange: -0.016243362, pValue: 0.093948158),
        ProteinEntry(id: "P36896", gene: "ACVR1B", foldChange: -0.443786112, pValue: 1.262699463)
    ]
}

// MARK: - PTM Dataset Constants (85970b1d-8052-4d6f-bf67-654396534d76)

struct PTMDatasetConstants {
    static let linkId = "85970b1d-8052-4d6f-bf67-654396534d76"

    // Settings
    static let pCutoff = 0.05
    static let log2FCCutoff = 0.6
    static let fetchUniprot = true
    static let settingsVersion = 2.0

    // DifferentialForm columns
    static let primaryIDsColumn = "Index"
    static let foldChangeColumn = "Welch's T-test Difference AO_UT"
    static let significantColumn = "-Log Welch's T-test p-value AO_UT"
    static let comparisonColumn = "CurtainSetComparison"
    static let comparisonSelect = "1"  // Note: string, not array (unlike TP)
    static let accessionColumn = "ProteinID"
    static let positionColumn = "Position"
    static let positionPeptideColumn = "Position.in.peptide"
    static let peptideSequenceColumn = "Peptide"
    static let scoreColumn = "MaxPepProb"
    static let sequenceColumn = "SequenceWindow"

    // Sample order
    static let sampleOrder: [String: [String]] = [
        "AO": ["AO.01", "AO.02", "AO.03", "AO.04", "AO.05"],
        "UT": ["UT.01", "UT.02", "UT.03", "UT.04", "UT.05"]
    ]

    // Sample visibility
    static let sampleVisible: [String: Bool] = [
        "AO.01": true, "AO.02": true, "AO.03": true, "AO.04": true, "AO.05": true,
        "UT.01": true, "UT.02": true, "UT.03": true, "UT.04": true, "UT.05": true
    ]

    // Color map (exact from fixture JSON)
    static let colorMap: [String: String] = [
        "P-value <= 0.05;FC > 0.6": "rgba(232,245,223,0.95)",
        "P-value <= 0.05;FC <= 0.6": "#7eb0d5",
        "P-value > 0.05;FC <= 0.6": "#fd7f6f",
        "P-value > 0.05;FC > 0.6": "#bd7ebe",
        "Old sites": "rgba(11,190,194,0.98)",
        "New sites": "#f14d6c"
    ]

    // Default color list
    static let defaultColorList = [
        "#fd7f6f", "#7eb0d5", "#b2e061", "#bd7ebe", "#ffb55a",
        "#ffee65", "#beb9db", "#fdcce5", "#8bd3c7"
    ]

    // Visible categories
    static let visibleCategories: [String: Bool] = [
        "New sites": true,
        "Old sites": true,
        "P-value <= 0.05;FC > 0.6": true,
        "P-value <= 0.05;FC <= 0.6": true,
        "P-value > 0.05;FC <= 0.6": true,
        "P-value > 0.05;FC > 0.6": true
    ]

    // User selections (PTM has "Old sites" and "New sites", not PPM1H/LRRK2)
    static let selectionsName = ["Old sites", "New sites"]
    static let selectionsMapCount = 167  // 167 protein+site entries

    // Processed data counts
    static let processedRowCount = 6035

    // Significance counts (using pCutoff=0.05, log2FCCutoff=0.6)
    static let significantFCCount = 2008       // P<=0.05 AND |FC|>0.6
    static let significantNoFCCount = 1673     // P<=0.05 AND |FC|<=0.6
    static let notSignificantFCCount = 49      // P>0.05 AND |FC|>0.6
    static let notSignificantNoFCCount = 2305  // P>0.05 AND |FC|<=0.6

    // UniProt DB entry count (Map format with value array)
    static let uniprotDBEntryCount = 2277

    // Known PTM entries from first rows of processed data
    struct PTMEntry {
        let primaryId: String
        let gene: String
        let accession: String
        let peptide: String
        let foldChange: Double
        let pValue: Double  // -log10 p-value
    }

    static let samplePTMEntries: [PTMEntry] = [
        PTMEntry(primaryId: "A0A1W2P872_K427", gene: "Nova2", accession: "A0A1W2P872",
                 peptide: "GGkTLVEYQELTGAR", foldChange: 1.01620636, pValue: 3.787477242),
        PTMEntry(primaryId: "A0A1W2P872_K67", gene: "Nova2", accession: "A0A1W2P872",
                 peptide: "ETGATIkLSK", foldChange: 0.265635872, pValue: 2.556779037),
        PTMEntry(primaryId: "A0PJN4_K142", gene: "Ube2ql1", accession: "A0PJN4",
                 peptide: "EAEATFkSLVK", foldChange: 0.085608482, pValue: 0.845206977),
        PTMEntry(primaryId: "A1L3P4_K561", gene: "Slc9a6", accession: "A1L3P4",
                 peptide: "TTkAESAWLFR", foldChange: 0.016175079, pValue: 0.092990876),
        PTMEntry(primaryId: "A2A432_K665", gene: "Cul4b", accession: "A2A432",
                 peptide: "DVFEAFYkK", foldChange: 0.421013641, pValue: 1.90913456)
    ]
}

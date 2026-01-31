//
//  CurtainSettingsModels.swift
//  Curtain
//
//  Created by Toan Phung on 02/08/2025.
//

import Foundation


struct CurtainSettings: Codable {
    // Core Analysis Settings
    let fetchUniprot: Bool
    let inputDataCols: [String: AnyCodable]
    let probabilityFilterMap: [String: AnyCodable]
    let barchartColorMap: [String: AnyCodable]
    let pCutoff: Double
    let log2FCCutoff: Double
    let description: String
    let uniprot: Bool
    let colorMap: [String: String]
    let academic: Bool
    let backGroundColorGrey: Bool
    let currentComparison: String
    let version: Double
    let currentId: String
    let fdrCurveText: String
    let fdrCurveTextEnable: Bool
    let prideAccession: String
    
    // Project and Metadata
    let project: Project
    
    // Sample and Condition Management
    let sampleOrder: [String: [String]]
    let sampleVisible: [String: Bool]
    let conditionOrder: [String]
    let sampleMap: [String: [String: String]]
    
    // Volcano Plot Settings
    let volcanoAxis: VolcanoAxis
    let textAnnotation: [String: AnyCodable]
    let volcanoPlotTitle: String
    let visible: [String: AnyCodable]
    let volcanoPlotGrid: [String: Bool]
    let volcanoPlotDimension: VolcanoPlotDimension
    let volcanoAdditionalShapes: [AnyCodable]
    let volcanoPlotLegendX: Double?
    let volcanoPlotLegendY: Double?
    
    // Visual Settings
    let defaultColorList: [String]
    let scatterPlotMarkerSize: Double
    let plotFontFamily: String
    
    // Network Analysis Colors
    let stringDBColorMap: [String: String]
    let interactomeAtlasColorMap: [String: String]
    let proteomicsDBColor: String
    let networkInteractionSettings: [String: String]
    
    // Plot Settings
    let rankPlotColorMap: [String: AnyCodable]
    let rankPlotAnnotation: [String: AnyCodable]
    let legendStatus: [String: AnyCodable]
    
    // Additional Settings
    let selectedComparison: [String]?
    let imputationMap: [String: AnyCodable]
    let enableImputation: Bool
    let viewPeptideCount: Bool
    let peptideCountData: [String: AnyCodable]

    // Volcano Plot Advanced Settings
    let volcanoConditionLabels: VolcanoConditionLabels
    let volcanoTraceOrder: [String]
    let volcanoPlotYaxisPosition: [String]
    let customVolcanoTextCol: String

    // Bar Chart Advanced Settings
    let barChartConditionBracket: BarChartConditionBracket
    let columnSize: [String: Int]
    let chartYAxisLimits: [String: ChartYAxisLimits]
    let individualYAxisLimits: [String: AnyCodable]

    // Violin Plot Settings
    let violinPointPos: Double

    // Advanced Data Features
    let networkInteractionData: [AnyCodable]
    let enrichrGeneRankMap: [String: AnyCodable]
    let enrichrRunList: [String]
    let extraData: [ExtraDataItem]

    // Metabolomics Support
    let enableMetabolomics: Bool
    let metabolomicsColumnMap: MetabolomicsColumnMap

    // Additional Metadata
    let encrypted: Bool
    let dataAnalysisContact: String
    let markerSizeMap: [String: AnyCodable]

    init() {
        self.fetchUniprot = true
        self.inputDataCols = [:]
        self.probabilityFilterMap = [:]
        self.barchartColorMap = [:]
        self.pCutoff = 0.05
        self.log2FCCutoff = 0.6
        self.description = ""
        self.uniprot = true
        self.colorMap = [:]
        self.academic = true
        self.backGroundColorGrey = false
        self.currentComparison = ""
        self.version = 2.0
        self.currentId = ""
        self.fdrCurveText = ""
        self.fdrCurveTextEnable = false
        self.prideAccession = ""
        self.project = Project()
        self.sampleOrder = [:]
        self.sampleVisible = [:]
        self.conditionOrder = []
        self.sampleMap = [:]
        self.volcanoAxis = VolcanoAxis()
        self.textAnnotation = [:]
        self.volcanoPlotTitle = ""
        self.visible = [:]
        self.volcanoPlotGrid = ["x": true, "y": true]
        self.volcanoPlotDimension = VolcanoPlotDimension()
        self.volcanoAdditionalShapes = []
        self.volcanoPlotLegendX = nil
        self.volcanoPlotLegendY = nil
        self.defaultColorList = Self.defaultColors()
        self.scatterPlotMarkerSize = 10.0
        self.plotFontFamily = "Arial"
        self.stringDBColorMap = Self.defaultStringDBColors()
        self.interactomeAtlasColorMap = Self.defaultInteractomeColors()
        self.proteomicsDBColor = "#ff7f0e"
        self.networkInteractionSettings = Self.defaultNetworkInteractionSettings()
        self.rankPlotColorMap = [:]
        self.rankPlotAnnotation = [:]
        self.legendStatus = [:]
        self.selectedComparison = nil
        self.imputationMap = [:]
        self.enableImputation = false
        self.viewPeptideCount = false
        self.peptideCountData = [:]
        self.volcanoConditionLabels = VolcanoConditionLabels()
        self.volcanoTraceOrder = []
        self.volcanoPlotYaxisPosition = ["middle"]
        self.customVolcanoTextCol = ""
        self.barChartConditionBracket = BarChartConditionBracket()
        self.columnSize = [:]
        self.chartYAxisLimits = [
            "barChart": ChartYAxisLimits(),
            "averageBarChart": ChartYAxisLimits(),
            "violinPlot": ChartYAxisLimits()
        ]
        self.individualYAxisLimits = [:]
        self.violinPointPos = -2.0
        self.networkInteractionData = []
        self.enrichrGeneRankMap = [:]
        self.enrichrRunList = []
        self.extraData = []
        self.enableMetabolomics = false
        self.metabolomicsColumnMap = MetabolomicsColumnMap()
        self.encrypted = false
        self.dataAnalysisContact = ""
        self.markerSizeMap = [:]
    }
    
    init(
        fetchUniprot: Bool = true,
        inputDataCols: [String: AnyCodable] = [:],
        probabilityFilterMap: [String: AnyCodable] = [:],
        barchartColorMap: [String: AnyCodable] = [:],
        pCutoff: Double = 0.05,
        log2FCCutoff: Double = 0.6,
        description: String = "",
        uniprot: Bool = true,
        colorMap: [String: String] = [:],
        academic: Bool = true,
        backGroundColorGrey: Bool = false,
        currentComparison: String = "",
        version: Double = 2.0,
        currentId: String = "",
        fdrCurveText: String = "",
        fdrCurveTextEnable: Bool = false,
        prideAccession: String = "",
        project: Project = Project(),
        sampleOrder: [String: [String]] = [:],
        sampleVisible: [String: Bool] = [:],
        conditionOrder: [String] = [],
        sampleMap: [String: [String: String]] = [:],
        volcanoAxis: VolcanoAxis = VolcanoAxis(),
        textAnnotation: [String: AnyCodable] = [:],
        volcanoPlotTitle: String = "",
        visible: [String: AnyCodable] = [:],
        volcanoPlotGrid: [String: Bool] = ["x": true, "y": true],
        volcanoPlotDimension: VolcanoPlotDimension = VolcanoPlotDimension(),
        volcanoAdditionalShapes: [AnyCodable] = [],
        volcanoPlotLegendX: Double? = nil,
        volcanoPlotLegendY: Double? = nil,
        defaultColorList: [String] = CurtainSettings.defaultColors(),
        scatterPlotMarkerSize: Double = 10.0,
        plotFontFamily: String = "Arial",
        stringDBColorMap: [String: String] = CurtainSettings.defaultStringDBColors(),
        interactomeAtlasColorMap: [String: String] = CurtainSettings.defaultInteractomeColors(),
        proteomicsDBColor: String = "#ff7f0e",
        networkInteractionSettings: [String: String] = CurtainSettings.defaultNetworkInteractionSettings(),
        rankPlotColorMap: [String: AnyCodable] = [:],
        rankPlotAnnotation: [String: AnyCodable] = [:],
        legendStatus: [String: AnyCodable] = [:],
        selectedComparison: [String]? = nil,
        imputationMap: [String: AnyCodable] = [:],
        enableImputation: Bool = false,
        viewPeptideCount: Bool = false,
        peptideCountData: [String: AnyCodable] = [:],
        volcanoConditionLabels: VolcanoConditionLabels = VolcanoConditionLabels(),
        volcanoTraceOrder: [String] = [],
        volcanoPlotYaxisPosition: [String] = ["middle"],
        customVolcanoTextCol: String = "",
        barChartConditionBracket: BarChartConditionBracket = BarChartConditionBracket(),
        columnSize: [String: Int] = [:],
        chartYAxisLimits: [String: ChartYAxisLimits] = [
            "barChart": ChartYAxisLimits(),
            "averageBarChart": ChartYAxisLimits(),
            "violinPlot": ChartYAxisLimits()
        ],
        individualYAxisLimits: [String: AnyCodable] = [:],
        violinPointPos: Double = -2.0,
        networkInteractionData: [AnyCodable] = [],
        enrichrGeneRankMap: [String: AnyCodable] = [:],
        enrichrRunList: [String] = [],
        extraData: [ExtraDataItem] = [],
        enableMetabolomics: Bool = false,
        metabolomicsColumnMap: MetabolomicsColumnMap = MetabolomicsColumnMap(),
        encrypted: Bool = false,
        dataAnalysisContact: String = "",
        markerSizeMap: [String: AnyCodable] = [:]
    ) {
        self.fetchUniprot = fetchUniprot
        self.inputDataCols = inputDataCols
        self.probabilityFilterMap = probabilityFilterMap
        self.barchartColorMap = barchartColorMap
        self.pCutoff = pCutoff
        self.log2FCCutoff = log2FCCutoff
        self.description = description
        self.uniprot = uniprot
        self.colorMap = colorMap
        self.academic = academic
        self.backGroundColorGrey = backGroundColorGrey
        self.currentComparison = currentComparison
        self.version = version
        self.currentId = currentId
        self.fdrCurveText = fdrCurveText
        self.fdrCurveTextEnable = fdrCurveTextEnable
        self.prideAccession = prideAccession
        self.project = project
        self.sampleOrder = sampleOrder
        self.sampleVisible = sampleVisible
        self.conditionOrder = conditionOrder
        self.sampleMap = sampleMap
        self.volcanoAxis = volcanoAxis
        self.textAnnotation = textAnnotation
        self.volcanoPlotTitle = volcanoPlotTitle
        self.visible = visible
        self.volcanoPlotGrid = volcanoPlotGrid
        self.volcanoPlotDimension = volcanoPlotDimension
        self.volcanoAdditionalShapes = volcanoAdditionalShapes
        self.volcanoPlotLegendX = volcanoPlotLegendX
        self.volcanoPlotLegendY = volcanoPlotLegendY
        self.defaultColorList = defaultColorList
        self.scatterPlotMarkerSize = scatterPlotMarkerSize
        self.plotFontFamily = plotFontFamily
        self.stringDBColorMap = stringDBColorMap
        self.interactomeAtlasColorMap = interactomeAtlasColorMap
        self.proteomicsDBColor = proteomicsDBColor
        self.networkInteractionSettings = networkInteractionSettings
        self.rankPlotColorMap = rankPlotColorMap
        self.rankPlotAnnotation = rankPlotAnnotation
        self.legendStatus = legendStatus
        self.selectedComparison = selectedComparison
        self.imputationMap = imputationMap
        self.enableImputation = enableImputation
        self.viewPeptideCount = viewPeptideCount
        self.peptideCountData = peptideCountData
        self.volcanoConditionLabels = volcanoConditionLabels
        self.volcanoTraceOrder = volcanoTraceOrder
        self.volcanoPlotYaxisPosition = volcanoPlotYaxisPosition
        self.customVolcanoTextCol = customVolcanoTextCol
        self.barChartConditionBracket = barChartConditionBracket
        self.columnSize = columnSize
        self.chartYAxisLimits = chartYAxisLimits
        self.individualYAxisLimits = individualYAxisLimits
        self.violinPointPos = violinPointPos
        self.networkInteractionData = networkInteractionData
        self.enrichrGeneRankMap = enrichrGeneRankMap
        self.enrichrRunList = enrichrRunList
        self.extraData = extraData
        self.enableMetabolomics = enableMetabolomics
        self.metabolomicsColumnMap = metabolomicsColumnMap
        self.encrypted = encrypted
        self.dataAnalysisContact = dataAnalysisContact
        self.markerSizeMap = markerSizeMap
    }
    
    
    static func defaultColors() -> [String] {
        return [
            "#fd7f6f", "#7eb0d5", "#b2e061", "#bd7ebe", "#ffb55a",
            "#ffee65", "#beb9db", "#fdcce5", "#8bd3c7"
        ]
    }
    
    static func defaultStringDBColors() -> [String: String] {
        return [
            "Increase": "#8d0606",
            "Decrease": "#4f78a4",
            "In dataset": "#ce8080",
            "Not in dataset": "#676666"
        ]
    }
    
    static func defaultInteractomeColors() -> [String: String] {
        return [
            "Increase": "#a12323",
            "Decrease": "#16458c",
            "HI-Union": "rgba(82,110,194,0.96)",
            "Literature": "rgba(181,151,222,0.96)",
            "HI-Union and Literature": "rgba(222,178,151,0.96)",
            "Not found": "rgba(25,128,128,0.96)",
            "No change": "rgba(47,39,40,0.96)"
        ]
    }
    
    static func defaultNetworkInteractionSettings() -> [String: String] {
        return [
            "Increase": "rgba(220,169,0,0.96)",
            "Decrease": "rgba(220,0,59,0.96)",
            "StringDB": "rgb(206,128,128)",
            "No change": "rgba(47,39,40,0.96)",
            "Not significant": "rgba(255,255,255,0.96)",
            "Significant": "rgba(252,107,220,0.96)",
            "InteractomeAtlas": "rgb(73,73,101)"
        ]
    }
}


struct Project: Codable {
    let title: String
    let projectDescription: String
    let organisms: [NameItem]
    let organismParts: [NameItem]
    let cellTypes: [NameItem]
    let diseases: [NameItem]
    let sampleProcessingProtocol: String
    let dataProcessingProtocol: String
    let accession: String
    let sampleAnnotations: [String: AnyCodable]
    
    init() {
        self.title = ""
        self.projectDescription = ""
        self.organisms = [NameItem()]
        self.organismParts = [NameItem()]
        self.cellTypes = [NameItem()]
        self.diseases = [NameItem()]
        self.sampleProcessingProtocol = ""
        self.dataProcessingProtocol = ""
        self.accession = ""
        self.sampleAnnotations = [:]
    }
    
    init(
        title: String,
        projectDescription: String,
        organisms: [NameItem],
        organismParts: [NameItem],
        cellTypes: [NameItem],
        diseases: [NameItem],
        sampleProcessingProtocol: String,
        dataProcessingProtocol: String,
        accession: String,
        sampleAnnotations: [String: AnyCodable]
    ) {
        self.title = title
        self.projectDescription = projectDescription
        self.organisms = organisms
        self.organismParts = organismParts
        self.cellTypes = cellTypes
        self.diseases = diseases
        self.sampleProcessingProtocol = sampleProcessingProtocol
        self.dataProcessingProtocol = dataProcessingProtocol
        self.accession = accession
        self.sampleAnnotations = sampleAnnotations
    }
}

struct NameItem: Codable {
    let name: String
    let cvLabel: String?
    
    init() {
        self.name = ""
        self.cvLabel = nil
    }
    
    init(name: String, cvLabel: String? = nil) {
        self.name = name
        self.cvLabel = cvLabel
    }
}

struct VolcanoAxis: Codable {
    let minX: Double?
    let maxX: Double?
    let minY: Double?
    let maxY: Double?
    let x: String
    let y: String
    let dtickX: Double?
    let dtickY: Double?
    let ticklenX: Int
    let ticklenY: Int
    
    init() {
        self.minX = nil
        self.maxX = nil
        self.minY = nil
        self.maxY = nil
        self.x = "Log2FC"
        self.y = "-log10(p-value)"
        self.dtickX = nil
        self.dtickY = nil
        self.ticklenX = 5
        self.ticklenY = 5
    }
    
    init(
        minX: Double?,
        maxX: Double?,
        minY: Double?,
        maxY: Double?,
        x: String,
        y: String,
        dtickX: Double?,
        dtickY: Double?,
        ticklenX: Int,
        ticklenY: Int
    ) {
        self.minX = minX
        self.maxX = maxX
        self.minY = minY
        self.maxY = maxY
        self.x = x
        self.y = y
        self.dtickX = dtickX
        self.dtickY = dtickY
        self.ticklenX = ticklenX
        self.ticklenY = ticklenY
    }
}

struct VolcanoPlotDimension: Codable {
    let width: Int
    let height: Int
    let margin: VolcanoPlotMargin
    
    init() {
        self.width = 800
        self.height = 1000
        self.margin = VolcanoPlotMargin()
    }
    
    init(width: Int, height: Int, margin: VolcanoPlotMargin) {
        self.width = width
        self.height = height
        self.margin = margin
    }
}

struct VolcanoPlotMargin: Codable {
    let left: Int?
    let right: Int?
    let bottom: Int?
    let top: Int?

    init() {
        self.left = nil
        self.right = nil
        self.bottom = nil
        self.top = nil
    }

    init(left: Int?, right: Int?, bottom: Int?, top: Int?) {
        self.left = left
        self.right = right
        self.bottom = bottom
        self.top = top
    }
}

struct VolcanoConditionLabels: Codable {
    let enabled: Bool
    let leftCondition: String
    let rightCondition: String
    let leftX: Double
    let rightX: Double
    let yPosition: Double
    let fontSize: Int
    let fontColor: String

    init() {
        self.enabled = false
        self.leftCondition = ""
        self.rightCondition = ""
        self.leftX = 0.25
        self.rightX = 0.75
        self.yPosition = -0.1
        self.fontSize = 14
        self.fontColor = "#000000"
    }

    init(
        enabled: Bool,
        leftCondition: String,
        rightCondition: String,
        leftX: Double,
        rightX: Double,
        yPosition: Double,
        fontSize: Int,
        fontColor: String
    ) {
        self.enabled = enabled
        self.leftCondition = leftCondition
        self.rightCondition = rightCondition
        self.leftX = leftX
        self.rightX = rightX
        self.yPosition = yPosition
        self.fontSize = fontSize
        self.fontColor = fontColor
    }
}

struct BarChartConditionBracket: Codable {
    let showBracket: Bool
    let bracketHeight: Double
    let bracketColor: String
    let bracketWidth: Int

    init() {
        self.showBracket = false
        self.bracketHeight = 0.05
        self.bracketColor = "#000000"
        self.bracketWidth = 2
    }

    init(
        showBracket: Bool,
        bracketHeight: Double,
        bracketColor: String,
        bracketWidth: Int
    ) {
        self.showBracket = showBracket
        self.bracketHeight = bracketHeight
        self.bracketColor = bracketColor
        self.bracketWidth = bracketWidth
    }
}

struct ChartYAxisLimits: Codable {
    let min: Double?
    let max: Double?

    init() {
        self.min = nil
        self.max = nil
    }

    init(min: Double?, max: Double?) {
        self.min = min
        self.max = max
    }
}

struct MetabolomicsColumnMap: Codable {
    let polarity: String?
    let formula: String?
    let abbreviation: String?
    let smiles: String?

    init() {
        self.polarity = nil
        self.formula = nil
        self.abbreviation = nil
        self.smiles = nil
    }

    init(
        polarity: String?,
        formula: String?,
        abbreviation: String?,
        smiles: String?
    ) {
        self.polarity = polarity
        self.formula = formula
        self.abbreviation = abbreviation
        self.smiles = smiles
    }
}

struct ExtraDataItem: Codable {
    let name: String
    let content: String
    let type: String

    init() {
        self.name = ""
        self.content = ""
        self.type = ""
    }

    init(name: String, content: String, type: String) {
        self.name = name
        self.content = content
        self.type = type
    }
}

// MARK: - AnyCodable Helper

public struct AnyCodable: Codable {
    public let value: Any
    
    public init<T>(_ value: T?) {
        self.value = value ?? ()
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if container.decodeNil() {
            self.value = ()
        } else if let bool = try? container.decode(Bool.self) {
            self.value = bool
        } else if let int = try? container.decode(Int.self) {
            self.value = int
        } else if let double = try? container.decode(Double.self) {
            self.value = double
        } else if let string = try? container.decode(String.self) {
            self.value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            self.value = array.map { $0.value }
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            self.value = dictionary.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "AnyCodable value cannot be decoded")
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dictionary as [String: Any]:
            try container.encode(dictionary.mapValues { AnyCodable($0) })
        case is Void:
            try container.encodeNil()
        default:
            throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: container.codingPath, debugDescription: "AnyCodable value cannot be encoded"))
        }
    }
}


extension CurtainSettings {
    
    static func fromDictionary(_ map: [String: Any]) -> CurtainSettings {
        return CurtainSettings(
            fetchUniprot: map["fetchUniprot"] as? Bool ?? true,
            inputDataCols: toAnyCodableMap(map["inputDataCols"] as? [String: Any]),
            probabilityFilterMap: toAnyCodableMap(map["probabilityFilterMap"] as? [String: Any]),
            barchartColorMap: toAnyCodableMap(map["barchartColorMap"] as? [String: Any]),
            pCutoff: map["pCutoff"] as? Double ?? 0.05,
            log2FCCutoff: map["log2FCCutoff"] as? Double ?? 0.6,
            description: map["description"] as? String ?? "",
            uniprot: map["uniprot"] as? Bool ?? true,
            colorMap: map["colorMap"] as? [String: String] ?? [:],
            academic: map["academic"] as? Bool ?? true,
            backGroundColorGrey: map["backGroundColorGrey"] as? Bool ?? false,
            currentComparison: map["currentComparison"] as? String ?? "",
            version: map["version"] as? Double ?? 2.0,
            currentId: map["currentID"] as? String ?? "",
            fdrCurveText: map["fdrCurveText"] as? String ?? "",
            fdrCurveTextEnable: map["fdrCurveTextEnable"] as? Bool ?? false,
            prideAccession: map["prideAccession"] as? String ?? "",
            project: Project.fromDictionary(map["project"] as? [String: Any]),
            sampleOrder: map["sampleOrder"] as? [String: [String]] ?? [:],
            sampleVisible: map["sampleVisible"] as? [String: Bool] ?? [:],
            conditionOrder: map["conditionOrder"] as? [String] ?? [],
            sampleMap: map["sampleMap"] as? [String: [String: String]] ?? [:],
            volcanoAxis: VolcanoAxis.fromDictionary(map["volcanoAxis"] as? [String: Any]),
            textAnnotation: toAnyCodableMap(map["textAnnotation"] as? [String: Any]),
            volcanoPlotTitle: map["volcanoPlotTitle"] as? String ?? "",
            visible: toAnyCodableMap(map["visible"] as? [String: Any]),
            volcanoPlotGrid: map["volcanoPlotGrid"] as? [String: Bool] ?? ["x": true, "y": true],
            volcanoPlotDimension: VolcanoPlotDimension.fromDictionary(map["volcanoPlotDimension"] as? [String: Any]),
            volcanoAdditionalShapes: toAnyCodableList(map["volcanoAdditionalShapes"] as? [Any]),
            volcanoPlotLegendX: map["volcanoPlotLegendX"] as? Double,
            volcanoPlotLegendY: map["volcanoPlotLegendY"] as? Double,
            defaultColorList: map["defaultColorList"] as? [String] ?? CurtainSettings.defaultColors(),
            scatterPlotMarkerSize: map["scatterPlotMarkerSize"] as? Double ?? 10.0,
            plotFontFamily: map["plotFontFamily"] as? String ?? "Arial",
            stringDBColorMap: map["stringDBColorMap"] as? [String: String] ?? CurtainSettings.defaultStringDBColors(),
            interactomeAtlasColorMap: map["interactomeAtlasColorMap"] as? [String: String] ?? CurtainSettings.defaultInteractomeColors(),
            proteomicsDBColor: map["proteomicsDBColor"] as? String ?? "#ff7f0e",
            networkInteractionSettings: map["networkInteractionSettings"] as? [String: String] ?? CurtainSettings.defaultNetworkInteractionSettings(),
            rankPlotColorMap: toAnyCodableMap(map["rankPlotColorMap"] as? [String: Any]),
            rankPlotAnnotation: toAnyCodableMap(map["rankPlotAnnotation"] as? [String: Any]),
            legendStatus: toAnyCodableMap(map["legendStatus"] as? [String: Any]),
            selectedComparison: map["selectedComparison"] as? [String],
            imputationMap: toAnyCodableMap(map["imputationMap"] as? [String: Any]),
            enableImputation: map["enableImputation"] as? Bool ?? false,
            viewPeptideCount: map["viewPeptideCount"] as? Bool ?? false,
            peptideCountData: toAnyCodableMap(map["peptideCountData"] as? [String: Any]),
            volcanoConditionLabels: VolcanoConditionLabels.fromDictionary(map["volcanoConditionLabels"] as? [String: Any]),
            volcanoTraceOrder: map["volcanoTraceOrder"] as? [String] ?? [],
            volcanoPlotYaxisPosition: map["volcanoPlotYaxisPosition"] as? [String] ?? ["middle"],
            customVolcanoTextCol: map["customVolcanoTextCol"] as? String ?? "",
            barChartConditionBracket: BarChartConditionBracket.fromDictionary(map["barChartConditionBracket"] as? [String: Any]),
            columnSize: map["columnSize"] as? [String: Int] ?? [:],
            chartYAxisLimits: ChartYAxisLimits.fromChartDictionary(map["chartYAxisLimits"] as? [String: Any]),
            individualYAxisLimits: toAnyCodableMap(map["individualYAxisLimits"] as? [String: Any]),
            violinPointPos: map["violinPointPos"] as? Double ?? -2.0,
            networkInteractionData: toAnyCodableList(map["networkInteractionData"] as? [Any]),
            enrichrGeneRankMap: toAnyCodableMap(map["enrichrGeneRankMap"] as? [String: Any]),
            enrichrRunList: map["enrichrRunList"] as? [String] ?? [],
            extraData: ExtraDataItem.fromDictionaryArray(map["extraData"] as? [[String: Any]]),
            enableMetabolomics: map["enableMetabolomics"] as? Bool ?? false,
            metabolomicsColumnMap: MetabolomicsColumnMap.fromDictionary(map["metabolomicsColumnMap"] as? [String: Any]),
            encrypted: map["encrypted"] as? Bool ?? false,
            dataAnalysisContact: map["dataAnalysisContact"] as? String ?? "",
            markerSizeMap: toAnyCodableMap(map["markerSizeMap"] as? [String: Any])
        )
    }
    
    static func toAnyCodableMap(_ map: [String: Any]?) -> [String: AnyCodable] {
        guard let map = map else { return [:] }
        var result: [String: AnyCodable] = [:]
        for (key, value) in map {
            result[key] = AnyCodable(value)
        }
        return result
    }
    
    static func toAnyCodableList(_ list: [Any]?) -> [AnyCodable] {
        guard let list = list else { return [] }
        return list.map { AnyCodable($0) }
    }
    
    static func fromJSON(_ jsonString: String) -> CurtainSettings? {
        guard let data = jsonString.data(using: .utf8),
              let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return fromDictionary(jsonObject)
    }
    
    /// Convert to dictionary for serialization
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [:]
        
        dict["fetchUniprot"] = fetchUniprot
        dict["inputDataCols"] = inputDataCols.mapValues { $0.value }
        dict["probabilityFilterMap"] = probabilityFilterMap.mapValues { $0.value }
        dict["barchartColorMap"] = barchartColorMap.mapValues { $0.value }
        dict["pCutoff"] = pCutoff
        dict["log2FCCutoff"] = log2FCCutoff
        dict["description"] = description
        dict["uniprot"] = uniprot
        dict["colorMap"] = colorMap
        dict["academic"] = academic
        dict["backGroundColorGrey"] = backGroundColorGrey
        dict["currentComparison"] = currentComparison
        dict["version"] = version
        dict["currentID"] = currentId
        dict["fdrCurveText"] = fdrCurveText
        dict["fdrCurveTextEnable"] = fdrCurveTextEnable
        dict["prideAccession"] = prideAccession
        dict["project"] = project.toDictionary()
        dict["sampleOrder"] = sampleOrder
        dict["sampleVisible"] = sampleVisible
        dict["conditionOrder"] = conditionOrder
        dict["sampleMap"] = sampleMap
        dict["volcanoAxis"] = volcanoAxis.toDictionary()
        dict["textAnnotation"] = textAnnotation.mapValues { $0.value }
        dict["volcanoPlotTitle"] = volcanoPlotTitle
        dict["visible"] = visible.mapValues { $0.value }
        dict["volcanoPlotGrid"] = volcanoPlotGrid
        dict["volcanoPlotDimension"] = volcanoPlotDimension.toDictionary()
        dict["volcanoAdditionalShapes"] = volcanoAdditionalShapes.map { $0.value }
        dict["volcanoPlotLegendX"] = volcanoPlotLegendX
        dict["volcanoPlotLegendY"] = volcanoPlotLegendY
        dict["defaultColorList"] = defaultColorList
        dict["scatterPlotMarkerSize"] = scatterPlotMarkerSize
        dict["plotFontFamily"] = plotFontFamily
        dict["stringDBColorMap"] = stringDBColorMap
        dict["interactomeAtlasColorMap"] = interactomeAtlasColorMap
        dict["proteomicsDBColor"] = proteomicsDBColor
        dict["networkInteractionSettings"] = networkInteractionSettings
        dict["rankPlotColorMap"] = rankPlotColorMap.mapValues { $0.value }
        dict["rankPlotAnnotation"] = rankPlotAnnotation.mapValues { $0.value }
        dict["legendStatus"] = legendStatus.mapValues { $0.value }
        dict["selectedComparison"] = selectedComparison
        dict["imputationMap"] = imputationMap.mapValues { $0.value }
        dict["enableImputation"] = enableImputation
        dict["viewPeptideCount"] = viewPeptideCount
        dict["peptideCountData"] = peptideCountData.mapValues { $0.value }
        dict["volcanoConditionLabels"] = volcanoConditionLabels.toDictionary()
        dict["volcanoTraceOrder"] = volcanoTraceOrder
        dict["volcanoPlotYaxisPosition"] = volcanoPlotYaxisPosition
        dict["customVolcanoTextCol"] = customVolcanoTextCol
        dict["barChartConditionBracket"] = barChartConditionBracket.toDictionary()
        dict["columnSize"] = columnSize
        dict["chartYAxisLimits"] = chartYAxisLimits.mapValues { $0.toDictionary() }
        dict["individualYAxisLimits"] = individualYAxisLimits.mapValues { $0.value }
        dict["violinPointPos"] = violinPointPos
        dict["networkInteractionData"] = networkInteractionData.map { $0.value }
        dict["enrichrGeneRankMap"] = enrichrGeneRankMap.mapValues { $0.value }
        dict["enrichrRunList"] = enrichrRunList
        dict["extraData"] = extraData.map { $0.toDictionary() }
        dict["enableMetabolomics"] = enableMetabolomics
        dict["metabolomicsColumnMap"] = metabolomicsColumnMap.toDictionary()
        dict["encrypted"] = encrypted
        dict["dataAnalysisContact"] = dataAnalysisContact
        dict["markerSizeMap"] = markerSizeMap.mapValues { $0.value }

        return dict
    }
    
    /// Convert to JSON string
    func toJSON() -> String? {
        let dict = toDictionary()
        guard let data = try? JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }
}

// MARK: - Nested Structure Extensions

extension Project {
    static func fromDictionary(_ map: [String: Any]?) -> Project {
        guard let map = map else { return Project() }
        
        return Project(
            title: map["title"] as? String ?? "",
            projectDescription: map["projectDescription"] as? String ?? "",
            organisms: NameItem.fromDictionaryArray(map["organisms"] as? [[String: Any]]),
            organismParts: NameItem.fromDictionaryArray(map["organismParts"] as? [[String: Any]]),
            cellTypes: NameItem.fromDictionaryArray(map["cellTypes"] as? [[String: Any]]),
            diseases: NameItem.fromDictionaryArray(map["diseases"] as? [[String: Any]]),
            sampleProcessingProtocol: map["sampleProcessingProtocol"] as? String ?? "",
            dataProcessingProtocol: map["dataProcessingProtocol"] as? String ?? "",
            accession: map["accession"] as? String ?? "",
            sampleAnnotations: CurtainSettings.toAnyCodableMap(map["sampleAnnotations"] as? [String: Any])
        )
    }
    
    func toDictionary() -> [String: Any] {
        return [
            "title": title,
            "projectDescription": projectDescription,
            "organisms": organisms.map { $0.toDictionary() },
            "organismParts": organismParts.map { $0.toDictionary() },
            "cellTypes": cellTypes.map { $0.toDictionary() },
            "diseases": diseases.map { $0.toDictionary() },
            "sampleProcessingProtocol": sampleProcessingProtocol,
            "dataProcessingProtocol": dataProcessingProtocol,
            "accession": accession,
            "sampleAnnotations": sampleAnnotations.mapValues { $0.value }
        ]
    }
}

extension NameItem {
    static func fromDictionary(_ map: [String: Any]?) -> NameItem {
        guard let map = map else { return NameItem() }
        
        return NameItem(
            name: map["name"] as? String ?? "",
            cvLabel: map["cvLabel"] as? String
        )
    }
    
    static func fromDictionaryArray(_ array: [[String: Any]]?) -> [NameItem] {
        guard let array = array else { return [NameItem()] }
        
        return array.map { fromDictionary($0) }
    }
    
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = ["name": name]
        if let cvLabel = cvLabel {
            dict["cvLabel"] = cvLabel
        }
        return dict
    }
}

extension VolcanoAxis {
    static func fromDictionary(_ map: [String: Any]?) -> VolcanoAxis {
        guard let map = map else { return VolcanoAxis() }
        
        return VolcanoAxis(
            minX: map["minX"] as? Double,
            maxX: map["maxX"] as? Double,
            minY: map["minY"] as? Double,
            maxY: map["maxY"] as? Double,
            x: map["x"] as? String ?? "Log2FC",
            y: map["y"] as? String ?? "-log10(p-value)",
            dtickX: map["dtickX"] as? Double,
            dtickY: map["dtickY"] as? Double,
            ticklenX: map["ticklenX"] as? Int ?? 5,
            ticklenY: map["ticklenY"] as? Int ?? 5
        )
    }
    
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "x": x,
            "y": y,
            "ticklenX": ticklenX,
            "ticklenY": ticklenY
        ]
        
        if let minX = minX { dict["minX"] = minX }
        if let maxX = maxX { dict["maxX"] = maxX }
        if let minY = minY { dict["minY"] = minY }
        if let maxY = maxY { dict["maxY"] = maxY }
        if let dtickX = dtickX { dict["dtickX"] = dtickX }
        if let dtickY = dtickY { dict["dtickY"] = dtickY }
        
        return dict
    }
}

extension VolcanoPlotDimension {
    static func fromDictionary(_ map: [String: Any]?) -> VolcanoPlotDimension {
        guard let map = map else { return VolcanoPlotDimension() }
        
        return VolcanoPlotDimension(
            width: map["width"] as? Int ?? 800,
            height: map["height"] as? Int ?? 1000,
            margin: VolcanoPlotMargin.fromDictionary(map["margin"] as? [String: Any])
        )
    }
    
    func toDictionary() -> [String: Any] {
        return [
            "width": width,
            "height": height,
            "margin": margin.toDictionary()
        ]
    }
}

extension VolcanoPlotMargin {
    static func fromDictionary(_ map: [String: Any]?) -> VolcanoPlotMargin {
        guard let map = map else { return VolcanoPlotMargin() }

        return VolcanoPlotMargin(
            left: map["l"] as? Int,
            right: map["r"] as? Int,
            bottom: map["b"] as? Int,
            top: map["t"] as? Int
        )
    }

    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [:]

        if let left = left { dict["l"] = left }
        if let right = right { dict["r"] = right }
        if let bottom = bottom { dict["b"] = bottom }
        if let top = top { dict["t"] = top }

        return dict
    }
}

extension VolcanoConditionLabels {
    static func fromDictionary(_ map: [String: Any]?) -> VolcanoConditionLabels {
        guard let map = map else { return VolcanoConditionLabels() }

        return VolcanoConditionLabels(
            enabled: map["enabled"] as? Bool ?? false,
            leftCondition: map["leftCondition"] as? String ?? "",
            rightCondition: map["rightCondition"] as? String ?? "",
            leftX: map["leftX"] as? Double ?? 0.25,
            rightX: map["rightX"] as? Double ?? 0.75,
            yPosition: map["yPosition"] as? Double ?? -0.1,
            fontSize: map["fontSize"] as? Int ?? 14,
            fontColor: map["fontColor"] as? String ?? "#000000"
        )
    }

    func toDictionary() -> [String: Any] {
        return [
            "enabled": enabled,
            "leftCondition": leftCondition,
            "rightCondition": rightCondition,
            "leftX": leftX,
            "rightX": rightX,
            "yPosition": yPosition,
            "fontSize": fontSize,
            "fontColor": fontColor
        ]
    }
}

extension BarChartConditionBracket {
    static func fromDictionary(_ map: [String: Any]?) -> BarChartConditionBracket {
        guard let map = map else { return BarChartConditionBracket() }

        return BarChartConditionBracket(
            showBracket: map["showBracket"] as? Bool ?? false,
            bracketHeight: map["bracketHeight"] as? Double ?? 0.05,
            bracketColor: map["bracketColor"] as? String ?? "#000000",
            bracketWidth: map["bracketWidth"] as? Int ?? 2
        )
    }

    func toDictionary() -> [String: Any] {
        return [
            "showBracket": showBracket,
            "bracketHeight": bracketHeight,
            "bracketColor": bracketColor,
            "bracketWidth": bracketWidth
        ]
    }
}

extension ChartYAxisLimits {
    static func fromDictionary(_ map: [String: Any]?) -> ChartYAxisLimits {
        guard let map = map else { return ChartYAxisLimits() }

        return ChartYAxisLimits(
            min: map["min"] as? Double,
            max: map["max"] as? Double
        )
    }

    static func fromChartDictionary(_ map: [String: Any]?) -> [String: ChartYAxisLimits] {
        guard let map = map else {
            return [
                "barChart": ChartYAxisLimits(),
                "averageBarChart": ChartYAxisLimits(),
                "violinPlot": ChartYAxisLimits()
            ]
        }

        var result: [String: ChartYAxisLimits] = [:]
        for (key, value) in map {
            if let limitDict = value as? [String: Any] {
                result[key] = ChartYAxisLimits.fromDictionary(limitDict)
            }
        }

        // Ensure default keys exist
        if result["barChart"] == nil {
            result["barChart"] = ChartYAxisLimits()
        }
        if result["averageBarChart"] == nil {
            result["averageBarChart"] = ChartYAxisLimits()
        }
        if result["violinPlot"] == nil {
            result["violinPlot"] = ChartYAxisLimits()
        }

        return result
    }

    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [:]

        if let min = min { dict["min"] = min }
        if let max = max { dict["max"] = max }

        return dict
    }
}

extension MetabolomicsColumnMap {
    static func fromDictionary(_ map: [String: Any]?) -> MetabolomicsColumnMap {
        guard let map = map else { return MetabolomicsColumnMap() }

        return MetabolomicsColumnMap(
            polarity: map["polarity"] as? String,
            formula: map["formula"] as? String,
            abbreviation: map["abbreviation"] as? String,
            smiles: map["smiles"] as? String
        )
    }

    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [:]

        if let polarity = polarity { dict["polarity"] = polarity }
        if let formula = formula { dict["formula"] = formula }
        if let abbreviation = abbreviation { dict["abbreviation"] = abbreviation }
        if let smiles = smiles { dict["smiles"] = smiles }

        return dict
    }
}

extension ExtraDataItem {
    static func fromDictionary(_ map: [String: Any]?) -> ExtraDataItem {
        guard let map = map else { return ExtraDataItem() }

        return ExtraDataItem(
            name: map["name"] as? String ?? "",
            content: map["content"] as? String ?? "",
            type: map["type"] as? String ?? ""
        )
    }

    static func fromDictionaryArray(_ array: [[String: Any]]?) -> [ExtraDataItem] {
        guard let array = array else { return [] }

        return array.map { fromDictionary($0) }
    }

    func toDictionary() -> [String: Any] {
        return [
            "name": name,
            "content": content,
            "type": type
        ]
    }
}
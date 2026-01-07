//
//  InputFile.swift
//  Curtain
//
//  Created by Toan Phung on 04/08/2025.
//

import Foundation

// MARK: - InputFile with DataFrame functionality (Like Android)

struct InputFile {
    let filename: String
    let originalFile: String
    let df: DataFrame
    let other: Any?
    
    init(filename: String = "", originalFile: String = "", other: Any? = nil) {
        self.filename = filename
        self.originalFile = originalFile
        self.other = other
        
        // Convert tab-separated data to DataFrame (like Android)
        if originalFile.isEmpty {
            self.df = DataFrame()
        } else {
            self.df = DataFrame.fromTabSeparated(originalFile)
        }
    }
}

// MARK: - DataFrame Implementation (Like Android kotlinx.dataframe)

struct DataFrame {
    private var columns: [String: [String]]
    private var columnOrder: [String]
    
    init() {
        self.columns = [:]
        self.columnOrder = []
    }
    
    init(columns: [String: [String]], columnOrder: [String]) {
        self.columns = columns
        self.columnOrder = columnOrder
    }
    
    // MARK: - Static Factory Methods
    
    static func fromTabSeparated(_ content: String) -> DataFrame {
        
        guard !content.isEmpty else {
            return DataFrame()
        }
        
        let rows = content.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: .newlines)
        guard !rows.isEmpty else {
            return DataFrame()
        }
        
        // Parse header row
        let header = rows[0].components(separatedBy: "\t").map { $0.trimmingCharacters(in: .whitespaces) }
        
        // Handle duplicate column names (like Android)
        let uniqueHeader = handleDuplicateColumnNames(header)
        
        // Parse data rows
        let dataRows = Array(rows.dropFirst())
        
        var columns: [String: [String]] = [:]
        
        // Initialize columns
        for colName in uniqueHeader {
            columns[colName] = []
        }
        
        // Process each row
        for (rowIndex, row) in dataRows.enumerated() {
            let cells = row.components(separatedBy: "\t")
            
            for (colIndex, colName) in uniqueHeader.enumerated() {
                let value = colIndex < cells.count ? cells[colIndex].trimmingCharacters(in: .whitespaces) : ""
                columns[colName]?.append(value)
            }
            
            // Debug first few rows
            if rowIndex < 3 {
            }
        }
        
        return DataFrame(columns: columns, columnOrder: uniqueHeader)
    }
    
    // Handle duplicate column names by appending suffixes (like Android)
    private static func handleDuplicateColumnNames(_ header: [String]) -> [String] {
        var uniqueHeader: [String] = []
        var nameCounts: [String: Int] = [:]
        
        // Count occurrences
        for colName in header {
            nameCounts[colName] = (nameCounts[colName] ?? 0) + 1
        }
        
        var processedCounts: [String: Int] = [:]
        for colName in header {
            if nameCounts[colName] == 1 {
                uniqueHeader.append(colName)
            } else {
                processedCounts[colName] = (processedCounts[colName] ?? 0) + 1
                uniqueHeader.append("\(colName).\(processedCounts[colName]!)")
            }
        }
        
        return uniqueHeader
    }
    
    // MARK: - DataFrame Interface (Like Android)
    
    func rowCount() -> Int {
        return columns.values.first?.count ?? 0
    }
    
    func columnCount() -> Int {
        return columnOrder.count
    }
    
    func getColumn(_ name: String) -> [String] {
        return columns[name] ?? []
    }
    
    func getValue(row: Int, column: String) -> String? {
        guard let columnData = columns[column],
              row >= 0 && row < columnData.count else {
            return nil
        }
        return columnData[row]
    }
    
    func getColumnNames() -> [String] {
        return columnOrder
    }
    
    func isEmpty() -> Bool {
        return columns.isEmpty || rowCount() == 0
    }
    
    // Get row as dictionary
    func getRow(_ index: Int) -> [String: String]? {
        guard index >= 0 && index < rowCount() else { return nil }
        
        var row: [String: String] = [:]
        for colName in columnOrder {
            row[colName] = getValue(row: index, column: colName) ?? ""
        }
        return row
    }
    
    // Filter rows based on condition
    func filter(_ condition: (Int, [String: String]) -> Bool) -> DataFrame {
        var newColumns: [String: [String]] = [:]
        
        // Initialize new columns
        for colName in columnOrder {
            newColumns[colName] = []
        }
        
        // Apply filter
        for rowIndex in 0..<rowCount() {
            if let row = getRow(rowIndex), condition(rowIndex, row) {
                for colName in columnOrder {
                    newColumns[colName]?.append(row[colName] ?? "")
                }
            }
        }
        
        return DataFrame(columns: newColumns, columnOrder: columnOrder)
    }
}
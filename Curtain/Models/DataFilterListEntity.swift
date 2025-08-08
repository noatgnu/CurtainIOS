//
//  DataFilterListEntity.swift
//  Curtain
//
//  Created by Toan Phung on 02/08/2025.
//

import Foundation
import SwiftData

@Model
final class DataFilterListEntity {
    var apiId: Int // ID from the API
    var name: String
    var category: String
    var data: String
    var isDefault: Bool
    var user: Int?
    
    init(apiId: Int, name: String, category: String, data: String, isDefault: Bool = false, user: Int? = nil) {
        self.apiId = apiId
        self.name = name
        self.category = category
        self.data = data
        self.isDefault = isDefault
        self.user = user
    }
}
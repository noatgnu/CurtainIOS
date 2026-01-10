//
//  UniProtService.swift
//  Curtain
//
//  Created by Toan Phung on 02/08/2025.
//

import Foundation


@Observable
class UniProtService {
    private let curtainDataService: CurtainDataService
    
    init(curtainDataService: CurtainDataService) {
        self.curtainDataService = curtainDataService
    }
    
    
    func getUniprotFromPrimary(_ accessionId: String) -> [String: Any]? {
        // Direct lookup in the database
        if let db = curtainDataService.uniprotData.db, db.keys.contains(accessionId) {
            return db[accessionId] as? [String: Any]
        }
        
        // Try to find through accession map
        if let accMap = curtainDataService.uniprotData.accMap, accMap.keys.contains(accessionId) {
            let accessList = accMap[accessionId]
            if let accessList = accessList {
                for acc in accessList {
                    if let dataMap = curtainDataService.uniprotData.dataMap, dataMap.keys.contains(acc) {
                        let mappedAcc = dataMap[acc]
                        if let mappedAcc = mappedAcc, 
                           let db = curtainDataService.uniprotData.db,
                           db.keys.contains(String(describing: mappedAcc)) {
                            return db[String(describing: mappedAcc)] as? [String: Any]
                        }
                    }
                }
            }
        }
        
        return nil
    }
    
    /// Check if UniProt data is loaded
    var isUniProtDataAvailable: Bool {
        return !(curtainDataService.uniprotData.results.isEmpty && 
                (curtainDataService.uniprotData.db?.isEmpty ?? true))
    }
    
}
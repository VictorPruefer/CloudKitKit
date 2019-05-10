//
//  CKKTokenScope.swift
//  CloudKitKit
//
//  Created by Victor Prüfer on 05.05.19.
//  Copyright © 2019 ninelinesdesign. All rights reserved.
//

import Foundation
import CloudKit

internal enum CKKTokenScope {
    case database(scope: CKDatabase.Scope)
    case zone(zoneID: CKRecordZone.ID)
    
    var key: String {
        switch self {
        case let .database(scope: scope):
            switch scope {
            case .private:
                return "CKK private database token"
            case .shared:
                return "CKK shared database token"
            case .public:
                return "CKK public database token"
            @unknown default:
                return "unknow database"
            }
        case let .zone(zoneID: zID):
            return "CKK token zone " + zID.zoneName
        }
    }
}

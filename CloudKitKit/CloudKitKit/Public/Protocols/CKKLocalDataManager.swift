//
//  CKKLocalDataManager.swift
//  CloudKitKit
//
//  Created by Victor Prüfer on 11.05.19.
//  Copyright © 2019 ninelinesdesign. All rights reserved.
//

import Foundation
import CloudKit
import CoreData

protocol CKKLocalDataManager: class {
    /// Takes changed and deleted records and adapt the local database according to these changes
    func handle(changedRecord: CKRecord)
}

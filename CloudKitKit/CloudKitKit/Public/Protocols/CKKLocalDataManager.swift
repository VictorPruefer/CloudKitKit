//
//  CKKLocalDataManager.swift
//  CloudKitKit
//
//  Created by Victor Prüfer on 11.05.19.
//  Copyright © 2019 ninelinesdesign. All rights reserved.
//

import Foundation
import CloudKit

protocol CKKLocalDataManager: class {
    /// Takes changed and deleted records and adapt the local database according to these changes
    func handleCloudChanges(changedRecords: [CKRecord], deletedRecords: [(CKRecord.ID, CKRecord.RecordType)], completionHandler: (() -> Void)?)
    /// Returns all local records that need to be synced
    func getRecordsToSync() -> [CKKRecord]
    /// Save the CoreData context
    func saveContext()
}

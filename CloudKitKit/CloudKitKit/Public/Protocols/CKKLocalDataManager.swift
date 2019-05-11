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
    func handleCloudChanges(changedRecords: [CKRecord], deletedRecords: [(CKRecord.ID, CKRecord.RecordType)], completionHandler: (() -> Void)?)
    func getRecordsToUpload() -> [CKKRecord]
}

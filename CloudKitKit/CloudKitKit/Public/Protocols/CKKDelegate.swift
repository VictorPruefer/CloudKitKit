//
//  CKKDelegate.swift
//  CloudKitKit
//
//  Created by Victor Prüfer on 10.05.19.
//  Copyright © 2019 ninelinesdesign. All rights reserved.
//

import Foundation
import CloudKit

protocol CKKDelegate: class {
    func recordZoneWithIDWasDeleted(zoneID: CKRecordZone.ID)
    func didStartFetchingChanges()
    func didCompleteFetchingChanges()
}

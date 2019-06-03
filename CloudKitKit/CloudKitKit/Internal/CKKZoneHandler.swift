//
//  CKKZoneHandler.swift
//  CloudKitKit
//
//  Created by Victor Prüfer on 05.05.19.
//  Copyright © 2019 ninelinesdesign. All rights reserved.
//

import Foundation
import CloudKit

internal class CKKZoneHandler {
    
    // MARK: - Singleton
    
    /// Singleton instance of ```CKKZoneHandler```
    static let shared = CKKZoneHandler()
    
    // This class is not supposed to be instantiated
    private init() {}
    
}

internal extension CKKZoneHandler {
    
    /// Checks whether the custom zone has already been created. If not, creates a new zone, synchronously. Waits for the zone to be created in order to continue.
    ///
    /// - Parameters:
    ///   - zoneName: The name of the zone that should be created if necessary
    ///   - completionHandler: The completion handler that will be called after success
    func setupCustomZone(zoneName: String, completionHandler: @escaping () -> Void) {
        // Check if creating zone has already been done for this user
        guard NSUbiquitousKeyValueStore.default.bool(forKey: CKKConstants.kCustomZoneCreated.rawValue) == false else {
            completionHandler()
            return
        }
        CKKDebugging.debuggingCrumble(statement: "Setup custom zone \(zoneName)", sender: self)
        // Create a new zone operation and add it to private database
        let zoneID = CKRecordZone.ID(zoneName: zoneName, ownerName: CKCurrentUserDefaultName)
        let newZone = CKRecordZone(zoneID: zoneID)
        let createZoneOp = CKModifyRecordZonesOperation(recordZonesToSave: [newZone], recordZoneIDsToDelete: nil)
        createZoneOp.modifyRecordZonesCompletionBlock = { savedZones, deleted, error in
            if let error = error {
                CKKDebugging.debuggingCrumble(statement: error.localizedDescription, sender: self)
                return
            }
            // Don't create zone again next time
            NSUbiquitousKeyValueStore.default.set(true, forKey: CKKConstants.kCustomZoneCreated.rawValue)
            completionHandler()
        }
        createZoneOp.qualityOfService = .userInitiated
        CKKManager.shared.container.database(with: .private).add(createZoneOp)
    }
    
    /// Fetch all changes in given zones in given database and handle them.
    ///
    /// - Parameters:
    ///   - zoneIDs: The IDs of the affected zones which changes should be handled
    ///   - database: The database of the affected zones
    ///   - completionHandler: The completion handler to be called after handling all changes
    func fetchChangesInZones(zoneIDs: [CKRecordZone.ID], database: CKDatabase.Scope, completionHandler:  (() -> Void)?) {
        CKKDebugging.debuggingCrumble(statement: "✋ Fetch changes in \(zoneIDs.count) zones in \(database)", sender: self)
        
        // Only continue if there is at least one affected zone
        guard !zoneIDs.isEmpty else {
            return
        }
        
        // Modified or added records that need to be handled
        var recordsToSave = [CKRecord]()
        // Deleted records that need to be deleted locally
        var recordsToDelete = [(CKRecord.ID, CKRecord.RecordType)]()
        // Setup options for fetching zone changes
        var optionsForZones = [CKRecordZone.ID: CKFetchRecordZoneChangesOperation.ZoneConfiguration]()
        zoneIDs.forEach({
            // For each zone, set the previous change token to only fetch the new changes
            let options = CKFetchRecordZoneChangesOperation.ZoneConfiguration()
            options.previousServerChangeToken = CKKTokenHandler.shared.getLatestToken(for: .zone(zoneID: $0))
            optionsForZones[$0] = options
        })
        
        // Create an operation to fetch all changes in given zones
        let fetchZoneChangesOperation: CKFetchRecordZoneChangesOperation = {
            let operation = CKFetchRecordZoneChangesOperation(recordZoneIDs: zoneIDs, configurationsByRecordZoneID: optionsForZones)
            operation.fetchAllChanges = true
            operation.qualityOfService = .utility
            operation.recordChangedBlock = { record in
                recordsToSave.append(record)
            }
            operation.recordWithIDWasDeletedBlock = { recordID, recordType in
                recordsToDelete.append((recordID, recordType))
            }
            operation.recordZoneChangeTokensUpdatedBlock = { recordZoneID, newToken, recentClientToken in
                // We now have a new change token locally
                CKKTokenHandler.shared.saveNewToken(newToken: newToken, scope: .zone(zoneID: recordZoneID), commit: true)
            }
            operation.recordZoneFetchCompletionBlock = { recordZoneID, newToken, _, moreComing, error in
                if let error = error {
                    CKKDebugging.debuggingCrumble(statement: error.localizedDescription, sender: self)
                    if let ckerror = error as? CKError {
                        let ckkerror = CKKError(cloudError: ckerror)
                        CKKDebugging.debuggingCrumble(statement: ckkerror.description, sender: self)
                    }
                    return
                }
                // Filter zone changes so that only the ones in this zone and that are not deleted remain
                let zoneChanges = recordsToSave
                    .filter({ $0.recordID.zoneID == recordZoneID })
                    .filter({ record in !recordsToDelete.contains(where: { record.recordID == $0.0 }) })
                let zoneDeletions = recordsToDelete.filter({ $0.0 == recordZoneID })
               
                // TODO: Handle deleted records
                CKKLocalDBManager.shared.handle(changedRecords: zoneChanges, completionHandler: { success in
                    guard success else {
                        // TODO: Handle failure
                        return
                    }
                    CKKTokenHandler.shared.saveNewToken(newToken: newToken, scope: .zone(zoneID: recordZoneID), commit: true)
                    if moreComing {
                        // Not all changes could be retrieved, create a new operation for this zone to fetch the remaining changes
                        CKKDebugging.debuggingCrumble(statement: "⚠️ More coming, create another zone fetch operation", sender: self)
                        self.fetchChangesInZones(zoneIDs: [recordZoneID], database: database, completionHandler: nil)
                    }
                })
            }
            operation.fetchRecordZoneChangesCompletionBlock = { error in
                if let error = error {
                    CKKDebugging.debuggingCrumble(statement: error.localizedDescription, sender: self)
                    return
                }
                completionHandler?()
                CKKDebugging.debuggingCrumble(statement: "✅ Successfully fetched changes in \(zoneIDs.count) zones in \(database)", sender: self)
            }
            
            return operation
        }()
        
        CKKManager.shared.container.database(with: database).add(fetchZoneChangesOperation)
    }
    
}

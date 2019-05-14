//
//  CKKManager.swift
//  CloudKitKit
//
//  Created by Victor Prüfer on 04.05.19.
//  Copyright © 2019 ninelinesdesign. All rights reserved.
//

import UIKit
import CloudKit

// MARK: - Core class
/// The core class of CloudKitKit. Use this class for setup and data management.
public class CKKManager {
    
    // MARK: Singleton
    
    /// Singleton instance of ```CKKManager```
    static let shared = CKKManager()
    
    // This class is not supposed to be instantiated
    private init() {
        container = CKContainer.default()
    }
    
    // MARK: Public properties
    
    weak var delegate: CKKDelegate?
    weak var localDataManager: CKKLocalDataManager?
    
    // MARK: Public and static properties
    
    static var debugMode: Bool = false
    
    // MARK: Internally public members
    
    internal var container: CKContainer
    
    // MARK: Instance members
    
    private var configuration: CKKConfiguration?
    
}

// MARK: - Setup
extension CKKManager {
    
    /// Specify a configuration and start the setup proceedure. This will create subscriptions, zones etc. if required.
    ///
    /// - Parameter configuration: The configuration to use.
    func setup(with configuration: CKKConfiguration, completionHandler: ((CKKError?) -> Void)?) {
        CKKDebugging.debuggingCrumble(statement: "Start setup...", sender: self)
        
        self.configuration = configuration
        
        // First of all, check if the user is logged in
        container.accountStatus { (accountStatus, error) in
            if let error = error {
                CKKDebugging.debuggingCrumble(statement: error.localizedDescription, sender: self)
                if let ckerror = error as? CKError {
                    completionHandler?(CKKError(cloudError: ckerror))
                } else {
                    completionHandler?(.unknown)
                }
                return
            }
            // Only continue if user is signed in
            guard accountStatus == .available else {
                CKKDebugging.debuggingCrumble(statement: "No user logged in", sender: self)
                return
            }
            
            // Setup possible custom container
            if let customContainerID = configuration.customContainerID {
                self.container = CKContainer(identifier: customContainerID)
            }
            
            // Setup required subscriptions
            CKKSubscriptionHandler.shared.setupSubscriptions(databases: [.private, .shared])
            
            // Setup custom zone
            CKKZoneHandler.shared.setupCustomZone(zoneName: configuration.zoneName, completionHandler: {
                completionHandler?(nil)
                // Fetch changes
                self.fetchChanges(database: .private, completionHandler: {
                    CKKDebugging.debuggingCrumble(statement: "Finished fetching changes in private db", sender: self)
                })
                self.fetchChanges(database: .shared, completionHandler: {
                    CKKDebugging.debuggingCrumble(statement: "Finished fetching changes in shared db", sender: self)
                })
                // Upload changes
                self.pushLocalChanges(completionHandler: nil)
            })
        }
    }
    
}

// MARK: - Cloud -> Local (Handle notifications, fetch changes from cloud)
extension CKKManager {
    
    /// Handles incoming push notifications and triggers fetching new data if necessary
    func handleIncomingNotification(userInfo: [AnyHashable : Any], completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        let notification = CKNotification(fromRemoteNotificationDictionary: userInfo)
        if notification?.subscriptionID == CKKConstants.kSubscriptionIDPrivateDB.rawValue {
            CKKDebugging.debuggingCrumble(statement: "Incoming push notification for private DB", sender: self)
            // There are new changes in the private database to fetch
            CKKManager.shared.fetchChanges(database: .private) {
                completionHandler(UIBackgroundFetchResult.newData)
            }
        }
        if notification?.subscriptionID == CKKConstants.kSubscriptionIDSharedDB.rawValue {
            CKKDebugging.debuggingCrumble(statement: "Incoming push notification for shared DB", sender: self)
            // There are new changes in the shared database to fetch
            CKKManager.shared.fetchChanges(database: .shared) {
                completionHandler(UIBackgroundFetchResult.newData)
            }
        }
    }
    
    /// Fetches all changes in a given database.
    ///
    /// - Parameters:
    ///   - database: The database to inspect for changes
    ///   - completionHandler: The completion handler to execute after fetching the changes
    func fetchChanges(database: CKDatabase.Scope, completionHandler: (() -> Void)?) {
        CKKDebugging.debuggingCrumble(statement: "Fetch changes in \(database)...", sender: self)
        // Notify the delegate
        delegate?.didStartFetchingChanges()
        
        // Get currently saved change token of this device
        let currentChangeToken = CKKTokenHandler.shared.getLatestToken(for: .database(scope: database))
        
        // Record zone IDs to fetch updates for; use a set to avoid duplicates
        var affectedZoneIDs = Set<CKRecordZone.ID>()
        
        // Create an operation to fetch all changes that occurred since the previous change token
        let fetchChangesOp: CKFetchDatabaseChangesOperation = {
            let operation = CKFetchDatabaseChangesOperation(previousServerChangeToken: currentChangeToken)
            operation.fetchAllChanges = true
            operation.recordZoneWithIDChangedBlock = { zoneID in
                affectedZoneIDs.insert(zoneID)
            }
            operation.recordZoneWithIDWasDeletedBlock = { zoneID in
                // Notify delegate that zone was deleted
                self.delegate?.recordZoneWithIDWasDeleted(zoneID: zoneID)
                // Recreate zone
                NSUbiquitousKeyValueStore.default.set(false, forKey: CKKConstants.kCustomZoneCreated.rawValue)
                CKKZoneHandler.shared.setupCustomZone(zoneName: zoneID.zoneName, completionHandler: {})
            }
            operation.changeTokenUpdatedBlock = { newToken in
                // We now have a new change token locally, cache it without saving
                CKKTokenHandler.shared.saveNewToken(newToken: newToken, scope: .database(scope: database), commit: true)
            }
            operation.fetchDatabaseChangesCompletionBlock = { newToken, moreComing, error in
                if let error = error {
                    CKKDebugging.debuggingCrumble(statement: error.localizedDescription, sender: self)
                    // Notify the delegate
                    self.delegate?.didCompleteFetchingChanges()
                    
                    // Check the error
                    if let ckerror = error as? CKError {
                        let ckkerror = CKKError(cloudError: ckerror)
                        switch ckkerror {
                        case .changeTokenExpired:
                            // Fetch again from scratch by resetting the token and calling the function again
                            CKKTokenHandler.shared.resetToken(scope: .database(scope: database))
                            self.fetchChanges(database: database, completionHandler: completionHandler)
                        default: break
                        }
                        CKKDebugging.debuggingCrumble(statement: ckkerror.description, sender: self)
                    }
                    
                    return
                }
                
                // Fetch changes in zones that are affected
                CKKZoneHandler.shared.fetchChangesInZones(zoneIDs: Array(affectedZoneIDs), database: database, completionHandler: {
                    // Now that we have successfully fetched the changes, cache the new change token of the database
                    CKKTokenHandler.shared.saveNewToken(newToken: newToken, scope: .database(scope: database), commit: true)
                    if moreComing {
                        self.fetchChanges(database: database, completionHandler: completionHandler)
                    } else {
                        // Notify the delegate
                        self.delegate?.didCompleteFetchingChanges()
                        completionHandler?()
                    }
                })
            }
            
            return operation
        }()
        
        container.database(with: database).add(fetchChangesOp)
    }
    
}

// MARK: - Local -> Cloud (Push local changes to the cloud)
extension CKKManager {
    
    /// Triggers to update all local changes into the cloud
    ///
    /// - Parameter completionHandler: The completion handler to execute after uploading all records
    func pushLocalChanges(completionHandler: (() -> Void)?) {
        guard let recordsToSync = localDataManager?.getRecordsToSync() else {
            completionHandler?()
            return
        }
        pushLocalChanges(hierarchyLevel: 0, records: recordsToSync, completionHandler: completionHandler)
    }
    
    // TODO: Handle deletions
    
    /// Helper function to update all local changes of a given hierarchy level, calls itself recursively with increasing level, to make sure that parent records are uploaded before child records.
    ///
    /// - Parameters:
    ///   - hierarchyLevel: The priority to filter the remain records for and upload them
    ///   - records: The remaining records
    ///   - completionHandler: The completion handler to execute after all records have been synced
    private func pushLocalChanges(hierarchyLevel: Int, records: [CKKRecord], completionHandler: (() -> Void)?) {
        CKKDebugging.debuggingCrumble(statement: "Sync local records with hierarchy level \(hierarchyLevel)", sender: self)
        
        // Specify a limitation on how many records can be transfered in one operation to avoid limit exceed errors
        let maxNumberOfRecords = 260
        // The records that should be proceeded within this round
        var recordsToProceed = records.filter({ $0.hierarchyLevel == hierarchyLevel }).prefix(maxNumberOfRecords)
        // Transform each CKKRecord into a CKRecord and store it in recordsToSave
        var transformedRecords = [CKRecord]()
        
        recordsToProceed.forEach({ record in
            // If there is already a record, use it
            if let storedRecord = record.getRecord() {
                transformedRecords.append(storedRecord)
            } else {
                // Otherwise create a new record
                let zoneID = CKRecordZone.ID(zoneName: configuration?.zoneName ?? "Unknown zone", ownerName: CKCurrentUserDefaultName)
                let recordID = CKRecord.ID(recordName: UUID().uuidString, zoneID: zoneID)
                var newRecord = CKRecord(recordType: record.recordType, recordID: recordID)
                addFieldsToRecord(record: &newRecord, fields: record.getCustomFields())
                transformedRecords.append(newRecord)
            }
        })
        
        // The remaining records that still need to be synced (all records minus recordsToProceed)
        let remainingRecords = records.filter({ record in !recordsToProceed.contains(where: { record.getObjectID() == $0.getObjectID() }) })
        
        // Create an operation to upload the records
        let modifiyRecordsOp = CKModifyRecordsOperation(recordsToSave: transformedRecords, recordIDsToDelete: nil)
        modifiyRecordsOp.modifyRecordsCompletionBlock = { _,_,error in
            if let error = error {
                CKKDebugging.debuggingCrumble(statement: error.localizedDescription, sender: self)
                return
            }
            CKKDebugging.debuggingCrumble(statement: "Successfully uploaded \(recordsToProceed.count) records", sender: self)
            
            // Update local status of uploaded records
            for i in 0..<recordsToProceed.count {
                recordsToProceed[i].syncRequired = false
                recordsToProceed[i].storeRecord(record: transformedRecords[i])
            }
            self.localDataManager?.saveContext()
            
            if remainingRecords.count == 0 || hierarchyLevel > 100 {
                // All records have been uploaded or something went wrong. Abort to avoid infinite loop.
                completionHandler?()
            } else if recordsToProceed.count == maxNumberOfRecords {
                // There are propably more records with this priority to sync, do another round with same hierarchy level
                self.pushLocalChanges(hierarchyLevel: hierarchyLevel, records: remainingRecords, completionHandler: completionHandler)
            } else {
                // Continue with next priority
                self.pushLocalChanges(hierarchyLevel: hierarchyLevel + 1, records: remainingRecords, completionHandler: completionHandler)
            }
        }
        
        container.privateCloudDatabase.add(modifiyRecordsOp)
    }
    
}

// MARK: - Helper functions
extension CKKManager {
    
    func addFieldsToRecord(record: inout CKRecord, fields: [CKKField]) {
        // Add custom field values to the record
        fields.forEach({ field in
            switch field {
            case let .value(key: key, value: value):
                record[key] = value as? CKRecordValue
            case let .reference(key: key, referenceRecord: referenceCKKRecord, parent: parent):
                if let referenceCKKRecord = referenceCKKRecord {
                    if let referenceRecord = referenceCKKRecord.getRecord() {
                        let reference = CKRecord.Reference(record: referenceRecord, action: .deleteSelf)
                        record.setValue(reference, forKey: key)
                        if parent {
                            record.setParent(referenceRecord)
                        }
                    }
                    print("Unexpected error: Parent record not created yet.")
                }
            }
        })
    }
    
}

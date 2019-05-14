//
//  CKKManager.swift
//  CloudKitKit
//
//  Created by Victor Prüfer on 04.05.19.
//  Copyright © 2019 ninelinesdesign. All rights reserved.
//

import UIKit
import CloudKit

/// The core class of CloudKitKit. Use this class for setup and data management.
public class CKKManager {
    
    // MARK: - Singleton
    
    /// Singleton instance of ```CKKManager```
    static let shared = CKKManager()
    
    // This class is not supposed to be instantiated
    private init() {
        container = CKContainer.default()
    }
    
    // MARK: - Public properties
    
    weak var delegate: CKKDelegate?
    weak var localDataManager: CKKLocalDataManager?
    
    // MARK: - Public and static properties
    
    static var debugMode: Bool = false
    
    // MARK: - Internally public members
    
    internal var container: CKContainer
    
    // MARK: - Instance members
    
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
            CKKSubscriptionHandler.shared.setupSubscriptions(databases: configuration.requiredDatabases)
            
            // Setup custom zone
            CKKZoneHandler.shared.setupCustomZone(zoneName: configuration.requiredZone, completionHandler: {
                completionHandler?(nil)
                // Fetch changes
                self.fetchChanges(database: .private, completionHandler: {
                    CKKDebugging.debuggingCrumble(statement: "Finished fetching changes in private db", sender: self)
                })
                self.fetchChanges(database: .shared, completionHandler: {
                    CKKDebugging.debuggingCrumble(statement: "Finished fetching changes in shared db", sender: self)
                })
            })
        }
    }
    
}

// MARK: Handle notification and fetch changes
extension CKKManager {
    
    /// Handles incoming push notifications and triggers fetching new data if necessary
    func handleIncomingNotification(userInfo: [AnyHashable : Any], completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        let notification = CKNotification(fromRemoteNotificationDictionary: userInfo)
        if notification?.subscriptionID == CKKConstants.kSubscriptionIDPrivateDB.rawValue {
            CKKDebugging.debuggingCrumble(statement: "Incoming push notification: Private DB", sender: self)
            // There are new changes in the private database to fetch
            CKKManager.shared.fetchChanges(database: .private) {
                completionHandler(UIBackgroundFetchResult.newData)
            }
        }
        if notification?.subscriptionID == CKKConstants.kSubscriptionIDSharedDB.rawValue {
            CKKDebugging.debuggingCrumble(statement: "Incoming push notification: Shared DB", sender: self)
            // There are new changes in the shared database to fetch
            CKKManager.shared.fetchChanges(database: .shared) {
                completionHandler(UIBackgroundFetchResult.newData)
            }
        }
    }
    
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
                // Notify delegate to handle deleted zone
                self.delegate?.recordZoneWithIDWasDeleted(zoneID: zoneID)
            }
            operation.changeTokenUpdatedBlock = { newToken in
                // We now have a new change token locally, cache it without saving
                CKKTokenHandler.shared.saveNewToken(newToken: newToken, scope: .database(scope: database), commit: false)
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
                    // Now that we have fetched the changes, cache the new change token of the database
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

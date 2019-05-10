//
//  CKKManager.swift
//  CloudKitKit
//
//  Created by Victor Prüfer on 04.05.19.
//  Copyright © 2019 ninelinesdesign. All rights reserved.
//

import Foundation
import CloudKit

/// The core class of CloudKitKit. Use this class for setup and data management.
public class CKKManager {
    
    // MARK: - Singleton
    
    /// Singleton instance of ```CKKManager```
    static var shared = CKKManager()
    
    // This class is not supposed to be instantiated
    private init() {
        container = CKContainer.default()
    }
    
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
    func setup(with configuration: CKKConfiguration) {
        CKKDebugging.debuggingCrumble(statement: "Start setup...", sender: self)
        
        self.configuration = configuration
        
        // First of all, check if the user is logged in
        container.accountStatus { (accountStatus, error) in
            if let error = error {
                CKKDebugging.debuggingCrumble(statement: error.localizedDescription, sender: self)
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

extension CKKManager {
    
    func fetchChanges(database: CKDatabase.Scope, completionHandler: (() -> Void)?) {
        CKKDebugging.debuggingCrumble(statement: "Fetch changes in \(database)...", sender: self)
        
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
                // TODO: Handle deleted zones
            }
            operation.changeTokenUpdatedBlock = { newToken in
                // We now have a new change token locally, cache it without saving
                CKKTokenHandler.shared.saveNewToken(newToken: newToken, scope: .database(scope: database), commit: false)
            }
            operation.fetchDatabaseChangesCompletionBlock = { newToken, more, error in
                // Will be executed when the fetch changes operation completed
                if let error = error {
                    // TODO: Check if error is CKErrorChangeTokenExpired, in this case reset the cached token
                    print(error.localizedDescription)
                    return
                }
                
                // Fetch changes in zones that are affected
                
                CKKZoneHandler.shared.fetchChangesInZones(zoneIDs: Array(affectedZoneIDs), database: database, completionHandler: {
                    // Now that we have fetched the changes, cache the new change token of the database
                    CKKTokenHandler.shared.saveNewToken(newToken: newToken, scope: .database(scope: database), commit: true)
                    completionHandler?()
                })
            }
            
            return operation
        }()
        
        
        container.database(with: database).add(fetchChangesOp)
    }
    
}

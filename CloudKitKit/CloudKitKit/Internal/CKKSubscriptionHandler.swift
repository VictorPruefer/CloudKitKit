//
//  CKKSubscriptionHandler.swift
//  CloudKitKit
//
//  Created by Victor Prüfer on 04.05.19.
//  Copyright © 2019 ninelinesdesign. All rights reserved.
//

import Foundation
import CloudKit

internal class CKKSubscriptionHandler {
    
    // MARK: - Singleton
    
    /// Singleton instance of ```CKKSubscriptionHandler```
    static let shared = CKKSubscriptionHandler()
    
    // This class is not supposed to be instantiated
    private init() {}
    
}

extension CKKSubscriptionHandler {
    
    /// Checks whether subscriptions have been set up before and sets them up if not. Uses silent push notifications that do not require user authentication.
    func setupSubscriptions(databases: [CKDatabase.Scope]) {
        for scope in databases where scope != .public {
            let subscriptionID = scope == .private ? CKKConstants.kSubscriptionIDPrivateDB.rawValue : CKKConstants.kSubscriptionIDSharedDB.rawValue
            CKKDebugging.debuggingCrumble(statement: "Setting up subscription: (\(subscriptionID))...", sender: self)
            // Check if setting up subscription is required
            guard (scope == .private && UserDefaults.standard.bool(forKey: subscriptionID) == false) ||
                (scope == .shared && UserDefaults.standard.bool(forKey: subscriptionID) == false) else {
                continue
            }
            // Subscribe to changes
            let subscriptionOperation = createDatabaseSubscriptionOperation(subscriptionID: subscriptionID)
            subscriptionOperation.modifySubscriptionsCompletionBlock = { subscriptions, deletedIDs, error in
                if let error = error {
                    CKKDebugging.debuggingCrumble(statement: error.localizedDescription, sender: self)
                    return
                }
                // Don't setup subscription next time
                UserDefaults.standard.set(true, forKey: subscriptionID)
                CKKDebugging.debuggingCrumble(statement: "Setup subscription (\(subscriptionID)) successful", sender: self)
            }
            CKKManager.shared.container.database(with: scope).add(subscriptionOperation)
        }
    }
    
    /// Helper function to create a database subscription operation with a given ID. Uses silent notifications.
    private func createDatabaseSubscriptionOperation(subscriptionID: String) -> CKModifySubscriptionsOperation {
        let subscription = CKDatabaseSubscription(subscriptionID: subscriptionID)
        // Silent push notification
        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        subscription.notificationInfo = notificationInfo
        let operation = CKModifySubscriptionsOperation(subscriptionsToSave: [subscription], subscriptionIDsToDelete: nil)
        operation.qualityOfService = .utility
        return operation
    }
    
}

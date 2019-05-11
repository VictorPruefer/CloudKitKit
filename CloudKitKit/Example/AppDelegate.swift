//
//  AppDelegate.swift
//  CloudKitKit
//
//  Created by Vico on 04.05.19.
//  Copyright © 2019 ninelinesdesign. All rights reserved.
//

import UIKit
import CloudKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?


    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        CKKManager.debugMode = true
        CKKManager.shared.delegate = self
        CKKManager.shared.localDataManager = self
        
        let configuration = CKKConfiguration(customContainerID: nil, requiredDatabases: [.private], requiredZone: "Notes")
        CKKManager.shared.setup(with: configuration, completionHandler: { error in
            print(error?.description ?? "Successful setup")
        })

        application.registerForRemoteNotifications()
        
        return true
    }

    // Handling arriving remote notifications
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        let notification = CKNotification(fromRemoteNotificationDictionary: userInfo)
        if notification?.subscriptionID == CKKConstants.kSubscriptionIDPrivateDB.rawValue {
            print("Received push notification from subscription of private database")
            // There are new changes in the private database to fetch
            CKKManager.shared.fetchChanges(database: .private) {
                completionHandler(UIBackgroundFetchResult.newData)
            }
        }
        if notification?.subscriptionID == CKKConstants.kSubscriptionIDSharedDB.rawValue {
            // There are new changes in the shared database to fetch
            CKKManager.shared.fetchChanges(database: .shared, completionHandler: {
                completionHandler(UIBackgroundFetchResult.newData)
            })
        }
    }
    
}

extension AppDelegate: CKKDelegate {
    
    func recordZoneWithIDWasDeleted(zoneID: CKRecordZone.ID) {
        print("record zone with id was deleted")
    }
    
    func didStartFetchingChanges() {
        print("Did start fetching changes")
    }
    
    func didCompleteFetchingChanges() {
        print("Did complete fetching changes")
    }
    
}

extension AppDelegate: CKKLocalDataManager {
    
    func getRecordsToUpload() -> [CKKRecord] {
        // Return all records where needsToBeUploaded == true
        return []
    }
    
    func handleCloudChanges(changedRecords: [CKRecord], deletedRecords: [(CKRecord.ID, CKRecord.RecordType)], completionHandler: (() -> Void)?) {
        print("Handle cloud changes locally")
        // TODO: Handle them and call completion handler
    }
    
}

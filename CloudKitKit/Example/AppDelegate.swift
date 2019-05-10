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
        
        let configuration = CKKConfiguration(customContainerID: nil, requiredDatabases: [.private], requiredZone: "Notes")
        CKKManager.shared.setup(with: configuration)

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


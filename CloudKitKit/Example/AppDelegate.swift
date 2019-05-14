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
        
        let configuration = CKKConfiguration(customContainerID: nil, zoneName: "Notes")
        CKKManager.shared.setup(with: configuration, completionHandler: { error in
            print(error?.description ?? "Successful setup")
        })

        application.registerForRemoteNotifications()
        
        return true
    }

    // Handling arriving remote notifications
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        CKKManager.shared.handleIncomingNotification(userInfo: userInfo, completionHandler: completionHandler)
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

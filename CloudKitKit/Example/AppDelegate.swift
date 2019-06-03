//
//  AppDelegate.swift
//  CloudKitKit
//
//  Created by Vico on 04.05.19.
//  Copyright © 2019 ninelinesdesign. All rights reserved.
//

import UIKit
import CloudKit

// *** Only for demo purpose
import CoreData

@objc(A)
final public class A: NSManagedObject, ABCRecord {
    
    static var recordType: String = "A"
    
    static var hierarchyLevel: Int = 0
    
    @NSManaged var recordName: String?
    // TODO set to false by default?
    @NSManaged var syncRequired: Bool
    
    @NSManaged var encodedSystemFields: Data?
    
    func getCustomFields() -> [CKKField] {
        return []
    }
    
    func setCustomFields(fields: [CKKField]) {
        fields.forEach({ field in
            // Cast field and set the appropriate variable
        })
    }
    
}

@objc(B)
final public class B: NSManagedObject, ABCRecord {

    static var recordType: String = "B"
    
    static var hierarchyLevel: Int = 0
    
    @NSManaged var recordName: String?
    
    @NSManaged var syncRequired: Bool
    
    @NSManaged var encodedSystemFields: Data?
    
    func getCustomFields() -> [CKKField] {
        return []
    }
    
    func setCustomFields(fields: [CKKField]) {
        
    }
}
// *** Only for demo purpose

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?


    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        CKKManager.debugMode = true
        CKKManager.shared.delegate = self
        CKKManager.shared.localDataManager = self
        
        let recordTypes: [ABCRecord.Type] = [A.self, B.self]

        let configuration = CKKConfiguration(customContainerID: nil, zoneName: "Notes", persistentContainerName: "CloudKitKit", recordTypes: recordTypes)
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

extension AppDelegate: CKKLocalDataManager {
    
    // TODO: No delegate required, move to CKKLocalDBManager
    func handle(changedRecord: CKRecord) {
        if let type = Bundle.main.classNamed(changedRecord.recordType) as? ABCRecord.Type {
            type.handle(changedRecord: changedRecord)
        } else {
            print("Fail.. no class for record type found - maybe update required")
        }
    }
    
}

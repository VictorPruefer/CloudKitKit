//
//  CKKConstants.swift
//  CloudKitKit
//
//  Created by Victor Prüfer on 04.05.19.
//  Copyright © 2019 ninelinesdesign. All rights reserved.
//

import Foundation

internal enum CKKConstants: String {
    
    // MARK: - UserDefault Keys

    // Describes whether the subscription for this device has been set up (private database)
    case kSubscriptionSetupCompletedPrivateDB = "CKK private db subscription completed"
    // Describes whether the subscription for this device has been set up (shared database)
    case kSubscriptionSetupCompletedSharedDB = "CKK shared db subscription completed"
    
    // MARK: - Cloud Defaults Keys
    
    case kCustomZoneCreated = "CKK custom zone created"
    
    // MARK: - IDs
    
    // Private database subscription id
    case kSubscriptionIDSharedDB = "CKK subscription shared"
    // Shared database subscription id
    case kSubscriptionIDPrivateDB = "CKK subscription private"
    
}

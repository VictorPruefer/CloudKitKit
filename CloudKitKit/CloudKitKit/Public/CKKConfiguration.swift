//
//  CKKConfiguration.swift
//  CloudKitKit
//
//  Created by Victor Prüfer on 04.05.19.
//  Copyright © 2019 ninelinesdesign. All rights reserved.
//

import Foundation
import CloudKit

/// A ```CKKConfiguration``` describes a set of properties required for setting up the CloudKit connection. Specify required databases, zones and subscriptions. CloudKitKit takes care about not creating duplicate zones / subscriptions.
public struct CKKConfiguration {
    
    /// Specify whether you want to use a default container (```nil```) or a custom one
    var customContainerID: String?
    /// Specify which zones should be accessed and created if necessary
    var zoneName: String
    /// The name of the container CoreData is supposed to use (usually equal to the app name)
    var persistentContainerName: String
    /// A list of all possible record types
    var recordTypes: [ABCRecord.Type]
    
}

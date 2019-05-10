//
//  CKKDebugging.swift
//  CloudKitKit
//
//  Created by Victor Prüfer on 04.05.19.
//  Copyright © 2019 ninelinesdesign. All rights reserved.
//

import Foundation

internal class CKKDebugging {
    
    /// Creates a debugging crumble. If the debugging mode is activated, this will print a debug statement including the sender's type.
    ///
    /// - Parameters:
    ///   - statement: The statement to print out
    ///   - sender: The sender of the statement
    static func debuggingCrumble(statement: String, sender: Any) {
        if CKKManager.debugMode {
            let senderType = String(describing: sender.self)
            print("\(senderType): \(statement)")
        }
    }
    
}

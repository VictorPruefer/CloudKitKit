//
//  CKKTokenHandler.swift
//  CloudKitKit
//
//  Created by Victor Prüfer on 04.05.19.
//  Copyright © 2019 ninelinesdesign. All rights reserved.
//

import Foundation
import CloudKit

/// This class is supposed to be used for token handling. You can access the locally stored token and commit new ones. You can also cache a token and commit it later.
internal class CKKTokenHandler {
    
    // MARK: - Singleton
    
    /// Singleton instance of ```CKKTokenHandler```
    static var shared = CKKTokenHandler()
    
    // This class is not supposed to be instantiated
    private init() {}
    
    // MARK: - Instance members
    
    /// New token that has not been committed yet
    private var uncommittedToken: [(CKKTokenScope, CKServerChangeToken)] = []
    
}

// MARK: - Token Handling Functions
extension CKKTokenHandler {
    
    /// Returns the current locally stored token
    func getLatestToken(for scope: CKKTokenScope) -> CKServerChangeToken? {
        if let changeTokenData = UserDefaults.standard.data(forKey: scope.key) {
            return try? NSKeyedUnarchiver.unarchivedObject(ofClass: CKServerChangeToken.self, from: changeTokenData)
        }
        return nil
    }
    
    /// Saves a new token. You can specify whether you want to persistently store this token or only cache it and commit it later.
    ///
    /// - Parameters:
    ///   - newToken: The new token that wants to be saved
    ///   - commit: ```true```, if the token should immediately be stored persistently. ```false```, if the token should only be cached temporarily.
    func saveNewToken(newToken: CKServerChangeToken, scope: CKKTokenScope, commit: Bool) {
        // Since we want to store a new token, delete the previous one first
        if let existingIndex = uncommittedToken.firstIndex(where: { $0.0.key == scope.key }) {
            uncommittedToken.remove(at: existingIndex)
        }
        // Add the new token to the staging area
        uncommittedToken.append((scope, newToken))
        // Store persistently if wanted
        if commit {
            commitToken(scope: scope)
        }
    }
    
    /// Stores a temporarily cached token persistently, if there is one.
    func commitToken(scope: CKKTokenScope) {
        if let tokenToCommit = uncommittedToken.first(where: { $0.0.key == scope.key }),
            let changeTokenData = try? NSKeyedArchiver.archivedData(withRootObject: tokenToCommit, requiringSecureCoding: true) {
            UserDefaults.standard.set(changeTokenData, forKey: scope.key)
            CKKDebugging.debuggingCrumble(statement: "Commit new token (\(tokenToCommit)) for scope: \(scope.key)", sender: self)
        }
    }
    
    /// Resets the current change token so that the next fetch operation will fetch all existing data
    func resetToken(scope: CKKTokenScope) {
        UserDefaults.standard.set(nil, forKey: scope.key)
        CKKDebugging.debuggingCrumble(statement: "Reset token for scope: \(scope.key)", sender: self)
    }
    
}

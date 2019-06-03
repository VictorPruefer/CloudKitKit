//
//  CKKError.swift
//  CloudKitKit
//
//  Created by Victor Prüfer on 11.05.19.
//  Copyright © 2019 ninelinesdesign. All rights reserved.
//

import Foundation
import CloudKit

enum CKKError {
    
    /// An error that occurs because the previous change token is too old. Set it to ```nil``` and try again.
    case changeTokenExpired
    /// An error that is probably temporary, so fetch the CKErrorRetryAfterKey and retry after a delay
    case temporary
    case requestTooLarge
    /// An error that occurs caused by a bad connection
    case connectionFailure
    /// An error that occurs because the user's iCloud storage limit is exceeded (default: 5gb)
    case userStorageTooSmall
    /// There is a fatal error that shouldn't occur (internal iCloud error, wrong arguments, no permission etc.)
    case fatal
    /// An error that occurs because the authentication was not successful
    case failedAuthentication
    case unknown
    
    init(cloudError: CKError) {
        switch cloudError.code {
        case .changeTokenExpired:
            self = .changeTokenExpired
        case .requestRateLimited, .zoneBusy, .serviceUnavailable:
            self = .temporary
        case .limitExceeded:
            self = .requestTooLarge
        case .networkFailure, .networkUnavailable, .serverResponseLost:
            self = .connectionFailure
        case .internalError, .serverRejectedRequest, .invalidArguments, .permissionFailure:
            self = .fatal
        case .quotaExceeded:
            self = .userStorageTooSmall
        case .notAuthenticated, .managedAccountRestricted:
            self = .failedAuthentication
        default:
            self = .unknown
        }
    }

    var description: String {
        switch self {
        case .changeTokenExpired:
            return "The local cache data is too old and needs to be refetched from the cloud."
        case .temporary:
            return "A temporary error occurred. Please try again later."
        case .requestTooLarge:
            return "The requested data was too large, please split up your request in multiple smaller requests."
        case .connectionFailure:
            return "There was a connection failure, please try again later."
        case .userStorageTooSmall:
            return "Your iCloud storage is too small to save the data in the cloud."
        case .fatal:
            return "A fatal iCloud error occurred, please try again later."
        case .failedAuthentication:
            return "Authentication error. Are you sure you're logged in with a valid iCloud account?"
        case .unknown:
            return "An unknown error occurred, please try again later."
        }
    }
    
}


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
    
    case changeTokenExpired
    case temporary
    case requestTooLarge
    case connectionFailure
    case userStorageTooSmall
    case cloudInternal
    case unknown
    
    init(cloudError: CKError) {
        switch cloudError.code {
        case .changeTokenExpired:
            self = .changeTokenExpired
        case .requestRateLimited, .zoneBusy:
            self = .temporary
        case .limitExceeded:
            self = .requestTooLarge
        case .networkFailure, .networkUnavailable, .serverResponseLost:
            self = .connectionFailure
        case .internalError, .serviceUnavailable:
            self = .cloudInternal
        case .quotaExceeded:
            self = .userStorageTooSmall
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
        case .cloudInternal:
            return "An iCloud internal error occurred, please try again later."
        case .unknown:
            return "An unknown error occurred, please try again later."
        }
    }
    
}


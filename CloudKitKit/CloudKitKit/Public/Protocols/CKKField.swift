//
//  CKKField.swift
//  CKKDemo
//
//  Created by Victor Prüfer on 11.05.19.
//  Copyright © 2019 ninelinesdesign. All rights reserved.
//

import Foundation
import CloudKit

enum CKKField {
    case value(key: String, value: Any?)
    case reference(key: String, referenceRecord: CKKRecord?, parent: Bool)
}

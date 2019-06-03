//
//  CKKField.swift
//  CKKDemo
//
//  Created by Victor Prüfer on 11.05.19.
//  Copyright © 2019 ninelinesdesign. All rights reserved.
//

import Foundation
import CloudKit

/// A representation of a CKRecord key-value pair. It can either contain a simple value, or a reference to another record. A reference can be a parent reference, which means that the record the reference is pointing on is parent.
enum CKKField {
    case value(key: String, value: Any?)
    case reference(key: String, referenceRecord: ABCRecord?, parent: Bool)
}

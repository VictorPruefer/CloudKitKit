//
//  CKKRecord.swift
//  CloudKitKit
//
//  Created by Victor Prüfer on 10.05.19.
//  Copyright © 2019 ninelinesdesign. All rights reserved.
//

import Foundation
import CloudKit

class CKKRecord {
    
    /// Contains the metadata (ID, etc) of the record
    var encodedSystemFields: Data?
    
    /// Takes a record and saves its metadata. This function only saves the metadata, not the custom fields.
    func encodeSystemFields(of record: CKRecord) {
        let coder = NSKeyedArchiver(requiringSecureCoding: true)
        record.encodeSystemFields(with: coder)
        encodedSystemFields = coder.encodedData
    }
    
    /// Creates a record by using the stored metadata. This record only contains the metadata, not the custom fields.
    func getSystemFields() -> CKRecord? {
        guard let encodedSystemFields = encodedSystemFields,
            let coder = try? NSKeyedUnarchiver(forReadingFrom: encodedSystemFields) else {
                return nil
        }
        coder.requiresSecureCoding = true
        return CKRecord(coder: coder)
    }
    
}

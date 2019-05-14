//
//  CKKRecord.swift
//  CloudKitKit
//
//  Created by Victor Prüfer on 10.05.19.
//  Copyright © 2019 ninelinesdesign. All rights reserved.
//

import Foundation
import CloudKit
import CoreData

/**
 CKKRecord is a protocol for NSManagedObjects to store a CKRecord in a CoreData database and to be able to create a CKRecord out of it again.
 
 Make a NSManagedObject conform to CKKRecord. Add three attributes to the CoreData model:
 - ```recordName``` (optional String),
 - ```needsToBeUploaded``` (nonoptional Boolean)
 - ```encodedSystemFields``` (optional Data).
 These attributes need to be stored persistently in addition to your custom fields.
 */
protocol CKKRecord {
    
    // MARK: Persistent properties
    
    /// To make it easier to query, the record name is an additional property of CKKRecord, even though it is already contained in the encoded system fields
    var recordName: String? { get set }
    /// Specify whether there are local changes that have not been updated to the cloud yet
    var syncRequired: Bool { get set }
    /// Contains the metadata (ID, etc) of the record. If you queried a set of CKKRecords using recordName, use encodedSystemFields to make sure that the zoneID is the right one.
    var encodedSystemFields: Data? { get set }
    
    // MARK: Required functions & runtime properties
    
    /// The name of the record type used in the CloudKit scheme, e.g. 'Note'
    var recordType: String { get }
    /// The level in the hierarchy regarding parent references. Records with a lower hierarchy (starting from 0) will be synced first. Records, that are parent for other records, should have a lower level number in order to be synced first.
    var hierarchyLevel: Int { get set }
    /// Returns the object ID from the CoreData object
    func getObjectID() -> NSManagedObjectID
    /// Returns all custom data attributes and references as a set of CKKFields
    func getCustomFields() -> [CKKField]
    /// Set the attributes using a set of CKKFields
    func setCustomFields(fields: [CKKField])
    
    /// Takes a CKRecord and stores all its information in the CKKRecord object
    mutating func storeRecord(record: CKRecord)
    /// Creates a CKRecord out of a CKKRecord and returns it. If are no metadata for a CKRecord, it returns nil.
    func getRecord() -> CKRecord?
    
}

extension CKKRecord {
    
    mutating func storeRecord(record: CKRecord) {
        // Store metadata fields
        encodeSystemFields(of: record)
        recordName = record.recordID.recordName
        // Store custom fields
        var fields = [CKKField]()
        record.allKeys().forEach({ key in
            if let value = record[key] {
                fields.append(CKKField.value(key: key, value: value))
            }
        })
        setCustomFields(fields: fields)
    }
    
    func getRecord() -> CKRecord? {
        // Create record with metadata
        guard var record = getSystemFields() else {
            return nil
        }
        // Add custom field values to the record
        CKKManager.shared.addFieldsToRecord(record: &record, fields: getCustomFields())
        return record
    }
    
}

extension CKKRecord {
    
    /// Takes a record and saves its metadata. This function only saves the metadata, not the custom fields.
    private mutating func encodeSystemFields(of record: CKRecord) {
        let coder = NSKeyedArchiver(requiringSecureCoding: true)
        record.encodeSystemFields(with: coder)
        encodedSystemFields = coder.encodedData
    }
    
    /// Creates a record by using the stored metadata. This record only contains the metadata, not the custom fields.
    private func getSystemFields() -> CKRecord? {
        guard let encodedSystemFields = encodedSystemFields,
            let coder = try? NSKeyedUnarchiver(forReadingFrom: encodedSystemFields) else {
                return nil
        }
        coder.requiresSecureCoding = true
        return CKRecord(coder: coder)
    }
    
}

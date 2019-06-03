//
//  CKKLocalDBManager.swift
//  CloudKitKit
//
//  Created by Victor Prüfer on 14.05.19.
//  Copyright © 2019 ninelinesdesign. All rights reserved.
//

import Foundation
import CoreData
import CloudKit

class CKKLocalDBManager {
    
    // MARK: Singleton
    
    /// Singleton instance of ```CKKLocalDBManager```
    static let shared = CKKLocalDBManager()
    
    // This class is not supposed to be instantiated
    private init() { }
    
    // MARK: Properties
    
    // MARK: CoreData Basics
    
    lazy var persistentContainer: NSPersistentContainer? = {
        guard let configuration = CKKManager.shared.configuration else {
            return nil
        }
        let container = NSPersistentContainer(name: configuration.persistentContainerName)
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                CKKDebugging.debuggingCrumble(statement: error.description, sender: self)
            }
        })
        return container
    }()
    
    /// Saves the context including all changes. Calls completion handler with a success boolean value
    ///
    /// - Parameter completionHandler: true, if the save operation was successful, false otherwise
    func saveContext(completionHandler: ((Bool) -> Void)?) {
        guard let context = persistentContainer?.viewContext else {
            return
        }
        if context.hasChanges {
            do {
                try context.save()
                completionHandler?(true)
            } catch {
                print(error.localizedDescription)
                completionHandler?(false)
            }
        }
    }
    
}

// MARK: - Local Helper Functions
extension CKKLocalDBManager {
    
    /// Helper function to retrieve all locally stored elements of a specific type. Returns a list of that specify type.
    ///
    /// - Parameters:
    ///   - class: The type all elements of should be returned
    ///   - predicate: A predicate to filter the result
    /// - Returns: An array including the query result
    func getAllLocalElements<T: ABCRecord>(class: T.Type , predicate: NSPredicate?) -> [T] {
        let request = NSFetchRequest<T>(entityName: T.recordType)
        request.predicate = predicate
        let result = (try? self.persistentContainer?.viewContext.fetch(request)) ?? []
        return result
    }
    
    func getLocalElementsToSync() -> [ABCRecord] {
        var elementsToBeSynced: [NSManagedObject] = []
        CKKManager.shared.configuration?.recordTypes.forEach({ type in
            let request = NSFetchRequest<NSManagedObject>(entityName: type.recordType)
            request.predicate = NSPredicate(format: "syncRequired == YES")
            let result = (try? self.persistentContainer?.viewContext.fetch(request)) ?? []
            elementsToBeSynced.append(contentsOf: result)
        })
        let castedElements = elementsToBeSynced as? [ABCRecord]
        return castedElements ?? []
    }
    
    // TODO: Instead of true/false, return the records that couldnt be saved/updated.
    
    /// Takes a list of CloudKit records that apparently have changed and stores/updates them locally.
    ///
    /// - Parameters:
    ///   - changedRecords: The array including all changed CloudKit records
    ///   - completionHandler: A completion handler, getting true as parameter if all records could be saved successfully, false otherwise
    func handle(changedRecords: [CKRecord], completionHandler: ((Bool) -> Void)?) {
        guard let dataManager = CKKManager.shared.localDataManager else {
            return
        }
        changedRecords.forEach({ record in
            dataManager.handle(changedRecord: record)
        })
        
        saveContext(completionHandler: completionHandler)
    }
    
    func handle<T: ABCRecord>(changedRecord: CKRecord, type: T.Type) {
        // Check if there is already an entry for the given record name
        let existingEntries = getAllLocalElements(class: type, predicate: NSPredicate(format: "recordName = %@", changedRecord.recordID.recordName))
        // Confirm that there is already a record stored and the record ID is identical
        if let localCopy = existingEntries.first(where: { $0.getRecord()?.recordID == changedRecord.recordID }) {
            // Update the existing record
            // TODO: Handle the case where needsSync == TRUE
            localCopy.storeRecord(record: changedRecord)
        } else if let newElement = CKKLocalDBManager.shared.createNewElement(entityName: type.recordType) as? ABCRecord {
            // Create a new local record for the given cloud-stored record
            newElement.storeRecord(record: changedRecord)
        } else {
            // TODO: Handle fail
        }
        CKKLocalDBManager.shared.saveContext(completionHandler: nil)
    }
    
    /// Creates a new element of a given entity type, inserts it to the context and returns it
    func createNewElement(entityName: String) -> NSManagedObject? {
        guard let context = self.persistentContainer?.viewContext else {
            return nil
        }
        return NSEntityDescription.insertNewObject(forEntityName: entityName, into: context)
    }
    
}

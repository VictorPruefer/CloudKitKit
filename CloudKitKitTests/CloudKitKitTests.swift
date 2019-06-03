//
//  CloudKitKitTests.swift
//  CloudKitKitTests
//
//  Created by Victor Prüfer on 03.06.19.
//  Copyright © 2019 ninelinesdesign. All rights reserved.
//

@testable import CloudKitKit
import XCTest
import CoreData
import CloudKit

// CKKLocalDBManager Tests
class CloudKitKitTests: XCTestCase {

    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        CKKManager.debugMode = true
        CKKManager.shared.localDataManager = self
        
        let recordTypes: [ABCRecord.Type] = [A.self, B.self]
        
        let configuration = CKKConfiguration(customContainerID: nil, zoneName: "Notes", persistentContainerName: "CloudKitKit", recordTypes: recordTypes)
        CKKManager.shared.setup(with: configuration, completionHandler: { error in
            print(error?.description ?? "Successful setup")
        })
    }

    override func tearDown() {
        resetAllRecords(entity: "A")
        resetAllRecords(entity: "B")
    }
    
    override func invokeTest() {
        let numberOfTests = 1
        for time in 0...numberOfTests {
            print("+++++ Test \(time)/\(numberOfTests) +++++")
            super.invokeTest()
        }
    }
    
    // Test if you can get all local elements of a specific type correctly
    // Known issue: without sleep - concurrency problem in CoreData
    func testGetAllLocalElements() {
        let numberOfElements = Int.random(in: 2000...8000)
        createRandomLocalElements(count: numberOfElements, completionHandler: { _ in
            let resultA = CKKLocalDBManager.shared.getAllLocalElements(class: A.self, predicate: nil)
            let resultB = CKKLocalDBManager.shared.getAllLocalElements(class: B.self, predicate: nil)
            XCTAssertEqual(resultA.count + resultB.count, numberOfElements)
        })
        sleep(1)
    }
    
    // Test if elements that need to be synced can be retrieved successfully
    func testGetLocalElementsToSync() {
        let numberOfElements = Int.random(in: 2000...10000)
        createRandomLocalElements(count: numberOfElements, completionHandler: { _ in
            let resultA = CKKLocalDBManager.shared.getAllLocalElements(class: A.self, predicate: nil)
            let resultToBeSynced = CKKLocalDBManager.shared.getLocalElementsToSync()
            XCTAssertEqual(resultA.count, resultToBeSynced.count)
        })
        sleep(1)
    }

}

// Helper functions
extension CloudKitKitTests: CKKLocalDataManager {
    
    // Remove all locally stored objects
    func resetAllRecords(entity: String)
    {
        guard let context = CKKLocalDBManager.shared.persistentContainer?.viewContext else {
            return
        }
        let deleteFetch = NSFetchRequest<NSFetchRequestResult>(entityName: entity)
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: deleteFetch)
        do {
            try context.execute(deleteRequest)
        } catch {
            print ("There was an error")
        }
    }
    
    // Create a bunch of local elements
    func createRandomLocalElements(count: Int, completionHandler: @escaping (Bool) -> ()) {
        for _ in 0..<count {
            let rand = Bool.random()
            let newElement = CKKLocalDBManager.shared.createNewElement(entityName: rand ? "A" : "B") as! ABCRecord
            newElement.syncRequired = rand
        }
        CKKLocalDBManager.shared.saveContext(completionHandler: completionHandler)
    }
    
    // TODO: No delegate required, move to CKKLocalDBManager
    func handle(changedRecord: CKRecord) {
        if let type = Bundle.main.classNamed(changedRecord.recordType) as? ABCRecord.Type {
            type.handle(changedRecord: changedRecord)
        } else {
            print("Fail.. no class for record type found - maybe update required")
        }
    }
    
}

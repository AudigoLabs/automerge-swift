//
//  DocumentTest.swift
//  Automerge
//
//  Created by Lukas Schmidt on 16.05.20.
//

import Foundation
import XCTest
@testable import Automerge

struct DocumentState: Codable, Equatable {
    struct Birds: Codable, Equatable {
        let wrens: Int
        let magpies: Int
    }
    var birds: Birds?
}

struct DocumentT2: Codable, Equatable {
    var bird: String?
}

// Refers to test/frontend_test.js
class DocumentTest: XCTestCase {

    // should allow instantiating from an existing object
    func testInitializing1() {
        let initialState = DocumentState(birds: .init(wrens: 3, magpies: 4))
        let document = try! Document(initialState)
        XCTAssertEqual(document.content, initialState)
    }

    // should return the unmodified document if nothing changed
    func testPerformingChanges1() {
        let initialState = DocumentState(birds: .init(wrens: 3, magpies: 4))
        var document = try! Document(initialState)
        try! document.change { _ in }
        XCTAssertEqual(document.content, initialState)
    }

    // should set root object properties
    func testPerformingChanges2() {
        struct Schema: Codable, Equatable {
            var bird: String?
        }
        let actor = Actor()
        var doc = try! Document(Schema(bird: nil), actor: actor)
        let res = try! doc.change { $0.bird.set("magpie") }

        XCTAssertEqual(doc.content, Schema(bird: "magpie"))
        XCTAssertEqual(res?.request, Request(
                        startOp: 1,
                        deps: [],
                        message: "",
                        time: res!.request.time,
                        actor: actor,
                        seq: 1,
                        ops: [
                            Op(action: .set, obj: .root, key: "bird", insert: false, value: .string("magpie"), pred: [])
                        ]))
    }

    // should create nested maps
    func testPerformingChanges3() {
        struct Schema: Codable, Equatable {
            struct Birds: Codable, Equatable { let wrens: Int }
            var birds: Birds?
        }
        var doc = try! Document(Schema(birds: nil))
        let res = try! doc.change { $0.birds?.set(.init(wrens: 3)) }
        let birds = doc.rootProxy().birds!.objectId
        XCTAssertEqual(doc.content, Schema(birds: .init(wrens: 3)))
        XCTAssertEqual(res?.request, Request(
            startOp: 1,
            deps: [],
            message: "",
            time: res!.request.time,
            actor: doc.actor,
            seq: 1,
            ops: [
                Op(action: .makeMap, obj: .root, key: "birds", insert: false, pred: []),
                Op(action: .set, obj: birds!, key: "wrens", insert: false, value: 3, datatype: .int, pred: [])
            ]
        ))
    }

    // should apply updates inside nested maps
    func testPerformingChanges4() {
        struct Schema: Codable, Equatable {
            struct Birds: Codable, Equatable { let wrens: Int; var sparrows: Double? }
            var birds: Birds?
        }
        var doc1 = try! Document(Schema(birds: nil))
        try! doc1.change { $0.birds?.set(.init(wrens: 3, sparrows: nil)) }
        var doc2 = doc1
        let res = try! doc2.change { $0.birds?.sparrows?.set(15) }
        let birds = doc2.rootProxy().birds?.objectId

        XCTAssertEqual(doc1.content, Schema(birds: .init(wrens: 3, sparrows: nil)))
        XCTAssertEqual(doc2.content, Schema(birds: .init(wrens: 3, sparrows: 15.0)))
        XCTAssertEqual(res?.request, Request(
                        startOp: 3,
                        deps: [],
                        message: "",
                        time: res!.request.time,
                        actor: doc1.actor,
                        seq: 2,
                        ops: [
                            Op(action: .set, obj: birds!, key: "sparrows", insert: false, value: 15.0, datatype: .float64, pred: [])
                        ]))
    }


    // should delete keys in maps
    func testPerformingChanges5() {
        struct Schema: Codable, Equatable {
            var magpies: Int?; let sparrows: Int?
        }
        let actor = Actor()
        let doc1 = try! Document(Schema(magpies: 2, sparrows: 15), actor: actor)
        var doc2 = doc1
        let res = try! doc2.change { $0.magpies.set(nil) }
        XCTAssertEqual(doc1.content, Schema(magpies: 2, sparrows: 15))
        XCTAssertEqual(doc2.content, Schema(magpies: nil, sparrows: 15))
        XCTAssertEqual(res?.request, Request(
                        startOp: 3,
                        deps: [],
                        message: "",
                        time: res!.request.time,
                        actor: actor,
                        seq: 2,
                        ops: [
                            Op(action: .del, obj: .root, key: "magpies", insert: false, value: nil, pred: ["1@\(actor)"])
                        ]))
        XCTAssertEqual(res?.request.ops[0].pred, ["1@\(actor)"])
    }

        // should create lists
        func testPerformingChanges6() {
            struct Schema: Codable, Equatable {
                var birds: [String]?
            }
            let actor = Actor()
            var doc1 = try! Document(Schema(birds: nil), actor: actor)
            let res = try! doc1.change { $0.birds?.set(["chaffinch"])}
            XCTAssertEqual(doc1.content, Schema(birds: ["chaffinch"]))
            XCTAssertEqual(res?.request, Request(
                            startOp: 1,
                            deps: [],
                            message: "",
                            time: res!.request.time,
                            actor: doc1.actor,
                            seq: 1,
                            ops: [
                                Op(action: .makeList, obj: .root, key: "birds", insert: false, pred: []),
                                Op(action: .set, obj: "1@\(actor)", elemId: .head, insert: true, value: "chaffinch", pred: [])
            ]))
        }

        // should apply updates inside lists
        func testPerformingChanges7() {
            struct Schema: Codable, Equatable {
                var birds: [String]?
            }
            let actor = Actor()
            var doc1 = try! Document(Schema(birds: nil), actor: actor)
            try! doc1.change { $0.birds?.set(["chaffinch"]) }
            var doc2 = doc1
            let res = try! doc2.change { $0.birds?[0].set("greenfinch") }
            let birds = doc2.rootProxy().birds?.objectId
            XCTAssertEqual(doc1.content, Schema(birds: ["chaffinch"]))
            XCTAssertEqual(doc2.content, Schema(birds: ["greenfinch"]))
            XCTAssertEqual(res?.request, Request(
                            startOp: 3,
                            deps: [],
                            message: "",
                            time: res!.request.time,
                            actor: doc1.actor,
                            seq: 2,
                            ops: [
                                Op(action: .set, obj: birds!, elemId: "2@\(actor)", value: "greenfinch", pred: ["2@\(actor)"])
                            ]))
        }

        // should delete list elements
        func testPerformingChanges8() {
            struct Schema: Codable, Equatable {
                var birds: [String]
            }
            let actor = Actor()
            let doc1 = try! Document(Schema(birds: ["chaffinch", "goldfinch"]), actor: actor)
            var doc2 = doc1
            let res = try! doc2.change {
                $0.birds.remove(at: 0)
            }
            let birds = doc2.rootProxy().birds.objectId
            XCTAssertEqual(doc1.content, Schema(birds: ["chaffinch", "goldfinch"]))
            XCTAssertEqual(doc2.content, Schema(birds: ["goldfinch"]))
            XCTAssertEqual(res?.request, Request(
                            startOp: 4,
                            deps: [],
                            message: "",
                            time: res!.request.time,
                            actor: doc2.actor,
                            seq: 2,
                            ops: [
                                Op(action: .del, obj: birds!, elemId: "2@\(actor)", pred: ["2@\(actor)"])
                            ]))
        }

        // should store Date objects as timestamps
        func testPerformingChanges9() {
            struct Schema: Codable, Equatable {
                var now: Date?
            }
            let now = Date(timeIntervalSince1970: 126254)
            var doc1 = try! Document(Schema(now: nil))
            let res = try! doc1.change { $0.now?.set(now) }
            XCTAssertEqual(doc1.content, Schema(now: now))
            XCTAssertEqual(res?.request, Request(
                            startOp: 1,
                            deps: [],
                            message: "",
                            time: res!.request.time,
                            actor: doc1.actor,
                            seq: 1,
                            ops: [
                                Op(action: .set, obj: .root, key: "now", insert: false, value: .float64(now.timeIntervalSince1970 * 1000), datatype: .timestamp, pred: [])
            ]))
        }
    
    // should handle counters inside maps
    func testCounters1() {
        struct Schema: Codable, Equatable {
            var wrens: Counter?
        }
        var doc1 = try! Document(Schema())
        let res1 = try! doc1.change { $0.wrens?.set(0) }
        var doc2 = doc1
        let res2 = try! doc2.change { $0.wrens?.increment() }
        let actor = doc2.actor
        XCTAssertEqual(doc1.content, Schema(wrens: 0))
        XCTAssertEqual(doc2.content, Schema(wrens: 1))
        XCTAssertEqual(res1?.request, Request(
                        startOp: 1,
                        deps: [],
                        message: "",
                        time: res1!.request.time,
                        actor: actor,
                        seq: 1,
                        ops: [
                            Op(action: .set, obj: .root, key: "wrens", value: 0, datatype: .counter, pred: [])
                        ]))
        XCTAssertEqual(res2?.request, Request(
                        startOp: 2,
                        deps: [],
                        message: "",
                        time: res2!.request.time,
                        actor: actor,
                        seq: 2,
                        ops: [
                            Op(action: .inc, obj: .root, key: "wrens", value: 1, pred: ["1@\(actor)"])
                        ]))
    }

    // should handle counters inside lists
    func testCounters2() {
        struct Schema: Codable, Equatable {
            var counts: [Counter]?
        }

        var doc1 = try! Document(Schema())
        let res1 = try! doc1.change {
            $0.counts?.set([1])
            XCTAssertEqual($0.counts?.get(), [1])
        }
        var doc2 = doc1
        let res2 = try! doc2.change {
            $0.counts?[0].increment(2)
            XCTAssertEqual($0.counts?.get(), [3])
        }
        let actor = doc2.actor
        let counts = doc2.rootProxy().counts?.objectId
        XCTAssertEqual(doc1.content, Schema(counts: [1]))
        XCTAssertEqual(doc2.content, Schema(counts: [3]))
        XCTAssertEqual(res1?.request, Request(
                        startOp: 1,
                        deps: [],
                        message: "",
                        time: res1!.request.time,
                        actor: actor,
                        seq: 1,
                        ops: [
                            Op(action: .makeList, obj: .root, key: "counts", insert: false, pred: []),
                            Op(action: .set, obj: counts!, elemId: .head, insert: true, value: 1, datatype: .counter, pred: [])
                        ]))
        XCTAssertEqual(res2?.request, Request(
                        startOp: 3,
                        deps: [],
                        message: "",
                        time: res2!.request.time,
                        actor: actor,
                        seq: 2,
                        ops: [
                            Op(action: .inc, obj: counts!, elemId: "2@\(actor)", insert: false, value: 2, pred: ["2@\(actor)"])
                        ]))
    }

    func testSyncWithQueuedChanges() {
        struct Project: Codable {
            let id: String
        }
        enum TransferDirection {
            case from1To2
            case from2To1
        }

        let doc1InitialData =  "hW9KgzGcc5YA3wkBIAacv2+730Z8nxEy3aA5DEMMQ01mt9JOb4ZH0Lye8H0xATnPaWzH+Uxv/q3nUgJv4NvSmtr84S0CaKdxjm0ChFzmCAECAwITDSMSNRJABEMEVgIMAQUCQx2aAyEDI2I0AUI2VmpfsQKAAQ6BAQKDAQUKAAoBfxACB34KCwIDfR0GAX2sppqfBgDTAAIAfgEDAgB/Hn8OSW5pdGlhbGl6YXRpb24JAH8ACQF/AAgBCgcACNUAAAAIfQECAwIEBQYCCQILfg8QBBECEgIXBhgGHwIgAiUDKQUtAi4CNAI3BDp+OzwEQX5CQwVEAkUCSAJLAk4CUQJXAlqNUs1uEzEQlkI229Lm0AMPwAMg7f/PGS45IA6tENexZ5ya2ruLPRvg7XF2KU20lHKwNB598/2MPVyDc9DtyVLH/gZG1P17o4db2k+dq6lz50A++JiUIsl+pTEeXP811DcHjXQ+MHXmgbd5K2RRZ6RSTEuRqHeqLRpMKU8q2eZZg0tEmlIKKBKpgNqM5BKBedXUSVZj0eSC8nKJKIVKZVOhrEWeE/yFQ6lGtQCUBZWsreC1dARMH8IJ6bZ29Fp+JAYEhlXEmg2ZiMkO/Za1pVu974BHR1eiZ+7tZzAjXXA/TMVSTuQiEwpkmaaNyMtmiSiSkiqQTY1IhTgaMlo+TGsMhi5/r3uHa3baxtSBMIRrOzK9og4jz+B4e/KUOzyPFBk6kJkHBuhWb06wdyHRJ6U88bgJssMOw8DGMznqYz5a2OHlMbaXYCg6HDM+Wphv58rXT39monpG7MuT2HMqL91j2XdMP/jRzQnVxoXATsy5/4Fb0beZay3A+1gacJp/XgyOPHWSYn+vrSW3+Q7O8n0AdfgH/9/lSzl+Ad0AAAYBfwkCAXsOeSl5TQIBfQXPAK1/AwF8IHxpAwIBe3wBxgB9QgUBfQIXbAIBegN5AQQBAwIBfQIGfQIBeHwBBQECAQIDAgF8fAEFEgIBf20CAQQDcnUBAgECAQIBAgEFAQIBXQQAfwEIAAIBfwADAX8AAgEDAAIBfwACAQIABgECAAIBfwAIAQIACQF/AAMBfQABAAMBBwAOAQQAf5YECAB5aZYEALYBdiQAAhQDAAKWBH0AAQICAHqWBGmWBIUBAYUBAgAClgR+AJYEAhR+AoUBA5YEAgADlgQCFAQ0fgABApYEfACFAQACApYEBwB2RoUBdoUBhgGFAXaFAWaFAQIUAjSdUT1KQ0EQfkoab+EFAju7b/anyg0kV9jZmSURo+G9SLAQvYC9B7DxDDaCna0HUBALG7FTrAwhr5ANPHCKhQ++/b75vjGBUu20ZGBAUnnIRjt0aKLV2nh0H493b6/K9NEOZLk/bk4OJS3Gp/P5VNrvajAovuVQewYxyqZgtOde3V6F66f77ftZ75R2XHtDYrBaz+eo2gyAsQ7YIaNlYDu0GLQXVuAsZ2QqFAEEIpNKOUrQknotdzZWL6P/1PBXqyDUCsXG5B2z1GRjQYiJa4sUMnhQIZcWZEhTjgkBPBn0vRY71eXX7u3Vxer9uTkvM2WfQ4yiV/3osGWjItN6Hsp2kDIkbzk5MkZif9MU27Y7bDqKzXRx1sF5I60cJ+lwO5nOZtJ0cBmb2WLSoXXC9+e9XxAAfwEVAH8BDAB/ASkAAwB93QBafQ=="
        let doc1InitialSyncState = "QwErd+QjTKnLC3L6xiknJtriHuaOT5RpjYM2GOrDR86Jug=="
        let doc2InitialData = "hW9KgwifsHEAgQUBIAacv2+730Z8nxEy3aA5DEMMQ01mt9JOb4ZH0Lye8H0xASt35CNMqcsLcvrGKScm2uIe5o5PlGmNgzYY6sNHzom6CAECAwITAyMHNRFAA0MCVgIKAQQCDhX0ASECIxc0AUIYVhtXmQGAAQICAAIBfhAHfqymmp8GAH4OSW5pdGlhbGl6YXRpb24AfgABfwACBwAIDwAACH8BBAYCCQILBBECEmkMYXJyYW5nZW1lbnRzEWF1ZGlvQ2xpcFNlZ21lbnRzC2F1ZGlvVHJhY2tzB2VmZmVjdHMCaWQHcHJvamVjdBF2aWRlb0NsaXBTZWdtZW50cwt2aWRlb1RyYWNrcyEzOWJjNDcyZWYxZDE1YjBmLWY5NDhkMWUzMDZjOTMyOGQKY3JlYXRlRGF0ZQJpZA1tdXNpY01ldGFkYXRhBXRpdGxlBXRlbXBvDXRpbWVTaWduYXR1cmULYm90dG9tVmFsdWUIdG9wVmFsdWUKY2xpY2tUcmFjawJpZAlwcm9qZWN0SWQEdHJpbQdlbmFibGVkBG11dGUXAAYBfwkCAX92AgF+BXwDAX4FAwIBfnwBFwQAfwEEAAIBfwACAX8AAgF/AAIBfwACAQQAf5YEBAB6aZYEALYBJAACFH8AApYEfQABAjM5YmM0NzJlZjFkMTViMGYtZDMyNzU3NTNhNjIyMzg1N+7Ku+XjMDM5YmM0NzJlZjFkMTViMGYtZDMyNzU3NTNhNjIyMzg1N05ldyBQcm9qZWN0+AAEBDM5YmM0NzJlZjFkMTViMGYtZjk0OGQxZTMwNmM5MzI4ZDM5YmM0NzJlZjFkMTViMGYtZDMyNzU3NTNhNjIyMzg1NxcAAQ=="
        let doc2InitialSyncState = "QwA="

        var doc1 = try! Document<Project>(data: [UInt8](Data(base64Encoded: doc1InitialData)!))
        var doc2 = try! Document<Project>(data: [UInt8](Data(base64Encoded: doc2InitialData)!))
        let syncState1 = SyncState(data: [UInt8](Data(base64Encoded: doc1InitialSyncState)!))
        let syncState2 = SyncState(data: [UInt8](Data(base64Encoded: doc2InitialSyncState)!))

        func transferSyncMessage(_ dir: TransferDirection) -> SyncMessage {
            let data: [UInt8]
            switch dir {
            case .from1To2:
                data = try! doc1.generateSyncMessage(syncState: syncState1)
            case .from2To1:
                data = try! doc2.generateSyncMessage(syncState: syncState2)
            }
            XCTAssertFalse(data.isEmpty)
            switch dir {
            case .from1To2:
                try! doc2.receiveSyncMessage(syncState: syncState2, data: data)
            case .from2To1:
                try! doc1.receiveSyncMessage(syncState: syncState1, data: data)
            }
            return try! SyncMessage(bytes: data)
        }

        let msg1 = transferSyncMessage(.from1To2)
        XCTAssertEqual(msg1.heads, ["39cf696cc7f94c6ffeade752026fe0dbd29adafce12d0268a7718e6d02845ce6"])
        XCTAssertEqual(msg1.have.count, 1)
        XCTAssertEqual(msg1.have[0].lastSync, ["2b77e4234ca9cb0b72fac6292726dae21ee68e4f94698d833618eac347ce89ba"])
        XCTAssertEqual(msg1.need, [])
        XCTAssertEqual(msg1.changes, [])
        XCTAssertEqual(try! doc2.getQueuedChanges(), [])

        let msg2 = transferSyncMessage(.from2To1)
        XCTAssertEqual(msg2.heads, ["2b77e4234ca9cb0b72fac6292726dae21ee68e4f94698d833618eac347ce89ba"])
        XCTAssertEqual(msg2.have.count, 1)
        XCTAssertEqual(msg2.have[0].lastSync, [])
        XCTAssertEqual(msg2.need, ["39cf696cc7f94c6ffeade752026fe0dbd29adafce12d0268a7718e6d02845ce6"])
        XCTAssertEqual(msg2.changes, [])
        XCTAssertEqual(try! doc1.getQueuedChanges(), [])

        let msg3 = transferSyncMessage(.from1To2)
        XCTAssertEqual(msg3.heads, ["39cf696cc7f94c6ffeade752026fe0dbd29adafce12d0268a7718e6d02845ce6"])
        XCTAssertEqual(msg3.have.count, 1)
        XCTAssertEqual(msg2.have[0].lastSync, [])
        XCTAssertEqual(msg3.need, [])
        XCTAssertEqual(msg3.changes.map { try! Change(change: $0).seq }, [4, 5, 6, 7, 8, 9, 10])
        let queuedChanges = try! doc2.getQueuedChanges()
        XCTAssertEqual(queuedChanges.map { try! Change(change: $0).seq }, [4, 5, 6, 7, 8, 9, 10])

        doc2 = try! Document(data: try! doc2.save())
        try! doc2.setQueuedChanges(queuedChanges)
        let msg4 = transferSyncMessage(.from2To1)
        XCTAssertEqual(msg4.heads, ["2b77e4234ca9cb0b72fac6292726dae21ee68e4f94698d833618eac347ce89ba"])
        XCTAssertEqual(msg4.have.count, 0)
        XCTAssertEqual(msg4.need, ["e0a00f156f64743f0b3aa8cb81c01a16aeb656036fc489c62949abec55a008d9"])
        XCTAssertEqual(msg4.changes, [])
        XCTAssertEqual(try! doc1.getQueuedChanges(), [])

        let msg5 = transferSyncMessage(.from1To2)
        XCTAssertEqual(msg5.heads, ["39cf696cc7f94c6ffeade752026fe0dbd29adafce12d0268a7718e6d02845ce6"])
        XCTAssertEqual(msg5.have.count, 1)
        XCTAssertEqual(msg5.have[0].lastSync, ["2b77e4234ca9cb0b72fac6292726dae21ee68e4f94698d833618eac347ce89ba"])
        XCTAssertEqual(msg5.need, [])
        XCTAssertEqual(msg5.changes.map { try! Change(change: $0).seq }, [3])
        XCTAssertEqual(try! doc2.getQueuedChanges(), [])

        let msg6 = transferSyncMessage(.from2To1)
        XCTAssertEqual(msg6.heads, ["39cf696cc7f94c6ffeade752026fe0dbd29adafce12d0268a7718e6d02845ce6"])
        XCTAssertEqual(msg6.have.count, 1)
        XCTAssertEqual(msg6.have[0].lastSync, ["39cf696cc7f94c6ffeade752026fe0dbd29adafce12d0268a7718e6d02845ce6"])
        XCTAssertEqual(msg6.need, [])
        XCTAssertEqual(msg6.changes, [])
        XCTAssertTrue(try! doc1.getQueuedChanges().isEmpty)

        // Should be in sync now
        XCTAssertTrue(try! doc1.generateSyncMessage(syncState: syncState1).isEmpty)
        XCTAssertTrue(try! doc2.generateSyncMessage(syncState: syncState2).isEmpty)
    }


//        // should use version and sequence number from the backend
//        func testBackendConcurrency1() {
//            struct Schema: Codable, Equatable {
//                var blackbirds: Int?
//                var partridges: Int?
//            }
//            let local = ActorId(), remtote1 = ActorId(), remtote2 = ActorId()
//            let patch1 = Patch(
//                clock: [local.actorId: 4, remtote1.actorId: 11, remtote2.actorId: 41],
//                version: 3,
//                canUndo: false,
//                canRedo: false,
//                diffs: .init(ROOT_ID, type: .map, props: ["blackbirds": [local.actorId: 24]]))
//            var doc1 = try! Document(Schema(blackbirds: nil, partridges: nil), options: .init(actorId: local))
//            doc1.applyPatch(patch: patch1)
//            doc1.change { $0[\.partridges, "partridges"] = 1 }
//            let requests = doc1.state.requests.map { $0.request }
//            XCTAssertEqual(requests, [
//               Request(requestType: .change, message: "", time: requests[0].time, actor: doc1.actor, seq: 5, version: 3, ops: [
//                Op(action: .set, obj: ROOT_ID, key: "partridges", insert: false, value: .int(1))
//                ], undoable: true)
//            ])
//        }
    //
    //    it('should use version and sequence number from the backend', () => {
    //      const local = uuid(), remote1 = uuid(), remote2 = uuid()
    //      const patch1 = {
    //        version: 3, canUndo: false, canRedo: false,
    //        clock: {[local]: 4, [remote1]: 11, [remote2]: 41},
    //        diffs: {objectId: ROOT_ID, type: 'map', props: {blackbirds: {[local]: {value: 24}}}}
    //      }
    //      let doc1 = Frontend.applyPatch(Frontend.init(local), patch1)
    //      let [doc2, req] = Frontend.change(doc1, doc => doc.partridges = 1)
    //      let requests = getRequests(doc2)
    //      assert.deepStrictEqual(requests, [
    //        {requestType: 'change', actor: local, seq: 5, time: requests[0].time, message: '', version: 3, ops: [
    //          {obj: ROOT_ID, action: 'set', key: 'partridges', insert: false, value: 1}
    //        ]}
    //      ])
    //    })
    //
    //
    //    // should remove pending requests once handled
    //    func testBackendConcurrency2() {
    //        struct Schema: Codable, Equatable {
    //            var blackbirds: Int?
    //            var partridges: Int?
    //        }
    //        let actor = ActorId()
    //        var doc =  Document(Schema(blackbirds: nil, partridges: nil), options: .init(actorId: actor))
    //        doc.change({ $0[\.blackbirds, "blackbirds"] = 24 })
    //        doc.change({ $0[\.partridges, "partridges"] = 1 })
    //        let requests = doc.state.requests.map { $0.request }
    //        XCTAssertEqual(requests, [
    //           Request(requestType: .change, message: "", time: requests[0].time, actor: actor, seq: 1, version: 0, ops: [
    //            Op(action: .set, obj: ROOT_ID, key: "blackbirds", insert: false, value: .int(24))
    //            ], undoable: true),
    //           Request(requestType: .change, message: "", time: requests[1].time, actor: actor, seq: 2, version: 0, ops: [
    //           Op(action: .set, obj: ROOT_ID, key: "partridges", insert: false, value: .int(1))
    //           ], undoable: true)
    //        ])
    //        doc.applyPatch(patch: Patch(actor: actor,
    //                                    seq: 1,
    //                                    clock: [actor.actorId: 1],
    //                                    version: 1,
    //                                    canUndo: true,
    //                                    canRedo: false,
    //                                    diffs: ObjectDiff(ROOT_ID, type: .map, props: ["blackbirds": [actor.actorId: 24]])
    //            )
    //        )
    //
    //        let requests2 = doc.state.requests.map { $0.request }
    //        XCTAssertEqual(doc.content, Schema(blackbirds: 24, partridges: 1))
    //        XCTAssertEqual(requests2, [
    //           Request(requestType: .change, message: "", time: requests2[0].time, actor: actor, seq: 2, version: 0, ops: [
    //            Op(action: .set, obj: ROOT_ID, key: "partridges", insert: false, value: .int(1))
    //            ], undoable: true)
    //        ])
    //
    //        doc.applyPatch(patch: Patch(actor: actor,
    //                                    seq: 2,
    //                                    clock: [actor.actorId: 2],
    //                                    version: 2,
    //                                    canUndo: true,
    //                                    canRedo: false,
    //                                    diffs: ObjectDiff(ROOT_ID, type: .map, props: ["partridges": [actor.actorId: 1]])
    //            )
    //        )
    //
    //        XCTAssertEqual(doc.content, Schema(blackbirds: 24, partridges: 1))
    //        XCTAssertEqual(doc.state.requests.map { $0.request }, [])
    //    }
}

//     describe('backend concurrency', () => {
//        function getRequests(doc) {
//          return doc[STATE].requests.map(req => {
//            req = Object.assign({}, req)
//            delete req['before']
//            delete req['diffs']
//            return req
//          })
//        }
//
//        it('should use version and sequence number from the backend', () => {
//          const local = uuid(), remote1 = uuid(), remote2 = uuid()
//          const patch1 = {
//            version: 3, canUndo: false, canRedo: false,
//            clock: {[local]: 4, [remote1]: 11, [remote2]: 41},
//            diffs: {objectId: ROOT_ID, type: 'map', props: {blackbirds: {[local]: {value: 24}}}}
//          }
//          let doc1 = Frontend.applyPatch(Frontend.init(local), patch1)
//          let [doc2, req] = Frontend.change(doc1, doc => doc.partridges = 1)
//          let requests = getRequests(doc2)
//          assert.deepStrictEqual(requests, [
//            {requestType: 'change', actor: local, seq: 5, time: requests[0].time, message: '', version: 3, ops: [
//              {obj: ROOT_ID, action: 'set', key: 'partridges', insert: false, value: 1}
//            ]}
//          ])
//        })
//
//        it('should remove pending requests once handled', () => {
//          const actor = uuid()
//          let [doc1, change1] = Frontend.change(Frontend.init(actor), doc => doc.blackbirds = 24)
//          let [doc2, change2] = Frontend.change(doc1, doc => doc.partridges = 1)
//          let requests = getRequests(doc2)
//          assert.deepStrictEqual(requests, [
//            {requestType: 'change', actor, seq: 1, time: requests[0].time, message: '', version: 0, ops: [
//              {obj: ROOT_ID, action: 'set', key: 'blackbirds', insert: false, value: 24}
//            ]},
//            {requestType: 'change', actor, seq: 2, time: requests[1].time, message: '', version: 0, ops: [
//              {obj: ROOT_ID, action: 'set', key: 'partridges', insert: false, value: 1}
//            ]}
//          ])
//
//          doc2 = Frontend.applyPatch(doc2, {
//            actor, seq: 1, version: 1, clock: {[actor]: 1}, canUndo: true, canRedo: false, diffs: {
//              objectId: ROOT_ID, type: 'map', props: {blackbirds: {[actor]: {value: 24}}}
//            }
//          })
//          requests = getRequests(doc2)
//          assert.deepStrictEqual(doc2, {blackbirds: 24, partridges: 1})
//          assert.deepStrictEqual(requests, [
//            {requestType: 'change', actor, seq: 2, time: requests[0].time, message: '', version: 0, ops: [
//              {obj: ROOT_ID, action: 'set', key: 'partridges', insert: false, value: 1}
//            ]}
//          ])
//
//          doc2 = Frontend.applyPatch(doc2, {
//            actor, seq: 2, version: 2, clock: {[actor]: 2}, canUndo: true, canRedo: false, diffs: {
//              objectId: ROOT_ID, type: 'map', props: {partridges: {[actor]: {value: 1}}}
//            }
//          })
//          assert.deepStrictEqual(doc2, {blackbirds: 24, partridges: 1})
//          assert.deepStrictEqual(getRequests(doc2), [])
//        })
//
//        it('should leave the request queue unchanged on remote patches', () => {
//          const actor = uuid(), other = uuid()
//          let [doc, req] = Frontend.change(Frontend.init(actor), doc => doc.blackbirds = 24)
//          let requests = getRequests(doc)
//          assert.deepStrictEqual(requests, [
//            {requestType: 'change', actor, seq: 1, time: requests[0].time, message: '', version: 0, ops: [
//              {obj: ROOT_ID, action: 'set', key: 'blackbirds', insert: false, value: 24}
//            ]}
//          ])
//
//          doc = Frontend.applyPatch(doc, {
//            version: 1, clock: {[other]: 1}, canUndo: false, canRedo: false, diffs: {
//              objectId: ROOT_ID, type: 'map', props: {pheasants: {[other]: {value: 2}}}
//            }
//          })
//          requests = getRequests(doc)
//          assert.deepStrictEqual(doc, {blackbirds: 24})
//          assert.deepStrictEqual(requests, [
//            {requestType: 'change', actor, seq: 1, time: requests[0].time, message: '', version: 0, ops: [
//              {obj: ROOT_ID, action: 'set', key: 'blackbirds', insert: false, value: 24}
//            ]}
//          ])
//
//          doc = Frontend.applyPatch(doc, {
//            actor, seq: 1, version: 2, clock: {[actor]: 1, [other]: 1}, canUndo: true, canRedo: false, diffs: {
//              objectId: ROOT_ID, type: 'map', props: {blackbirds: {[actor]: {value: 24}}}
//            }
//          })
//          assert.deepStrictEqual(doc, {blackbirds: 24, pheasants: 2})
//          assert.deepStrictEqual(getRequests(doc), [])
//        })
//
//        it('should not allow request patches to be applied out of order', () => {
//          const [doc1, req1] = Frontend.change(Frontend.init(), doc => doc.blackbirds = 24)
//          const [doc2, req2] = Frontend.change(doc1, doc => doc.partridges = 1)
//          const actor = Frontend.getActorId(doc2)
//          const diffs = {objectId: ROOT_ID, type: 'map', props: {partridges: {[actor]: {value: 1}}}}
//          assert.throws(() => {
//            Frontend.applyPatch(doc2, {actor, seq: 2, clock: {[actor]: 2}, diffs})
//          }, /Mismatched sequence number/)
//        })
//
//        it('should handle concurrent insertions into lists', () => {
//          let [doc1, req1] = Frontend.change(Frontend.init(), doc => doc.birds = ['goldfinch'])
//          const birds = Frontend.getObjectId(doc1.birds), actor = Frontend.getActorId(doc1)
//          doc1 = Frontend.applyPatch(doc1, {
//            actor, seq: 1, version: 1, clock: {[actor]: 1}, canUndo: true, canRedo: false,
//            diffs: {objectId: ROOT_ID, type: 'map', props: {
//              birds: {[actor]: {objectId: birds, type: 'list',
//                edits: [{action: 'insert', index: 0}],
//                props: {0: {[actor]: {value: 'goldfinch'}}}
//              }}
//            }}
//          })
//          assert.deepStrictEqual(doc1, {birds: ['goldfinch']})
//          assert.deepStrictEqual(getRequests(doc1), [])
//
//          const [doc2, req2] = Frontend.change(doc1, doc => {
//            doc.birds.insertAt(0, 'chaffinch')
//            doc.birds.insertAt(2, 'greenfinch')
//          })
//          assert.deepStrictEqual(doc2, {birds: ['chaffinch', 'goldfinch', 'greenfinch']})
//
//          const remoteActor = uuid()
//          const doc3 = Frontend.applyPatch(doc2, {
//            version: 2, clock: {[actor]: 1, [remoteActor]: 1}, canUndo: false, canRedo: false,
//            diffs: {objectId: ROOT_ID, type: 'map', props: {
//              birds: {[actor]: {objectId: birds, type: 'list',
//                edits: [{action: 'insert', index: 1}],
//                props: {1: {[remoteActor]: {value: 'bullfinch'}}}
//              }}
//            }}
//          })
//          // The addition of 'bullfinch' does not take effect yet: it is queued up until the pending
//          // request has made its round-trip through the backend.
//          assert.deepStrictEqual(doc3, {birds: ['chaffinch', 'goldfinch', 'greenfinch']})
//
//          const doc4 = Frontend.applyPatch(doc3, {
//            actor, seq: 2, version: 3, clock: {[actor]: 2, [remoteActor]: 1}, canUndo: true, canRedo: false,
//            diffs: {objectId: ROOT_ID, type: 'map', props: {
//              birds: {[actor]: {objectId: birds, type: 'list',
//                edits: [{action: 'insert', index: 0}, {action: 'insert', index: 2}],
//                props: {0: {[actor]: {value: 'chaffinch'}}, 2: {[actor]: {value: 'greenfinch'}}}
//              }}
//            }}
//          })
//          assert.deepStrictEqual(doc4, {birds: ['chaffinch', 'goldfinch', 'greenfinch', 'bullfinch']})
//          assert.deepStrictEqual(getRequests(doc4), [])
//        })
//
//        it('should allow interleaving of patches and changes', () => {
//          const actor = uuid()
//          const [doc1, req1] = Frontend.change(Frontend.init(actor), doc => doc.number = 1)
//          const [doc2, req2] = Frontend.change(doc1, doc => doc.number = 2)
//          assert.deepStrictEqual(req1, {
//            requestType: 'change', actor, seq: 1, time: req1.time, message: '', version: 0, ops: [
//              {obj: ROOT_ID, action: 'set', key: 'number', insert: false, value: 1}
//            ]
//          })
//          assert.deepStrictEqual(req2, {
//            requestType: 'change', actor, seq: 2, time: req2.time, message: '', version: 0, ops: [
//              {obj: ROOT_ID, action: 'set', key: 'number', insert: false, value: 2}
//            ]
//          })
//          const state0 = Backend.init()
//          const [state1, patch1] = Backend.applyLocalChange(state0, req1)
//          const doc2a = Frontend.applyPatch(doc2, patch1)
//          const [doc3, req3] = Frontend.change(doc2a, doc => doc.number = 3)
//          assert.deepStrictEqual(req3, {
//            requestType: 'change', actor, seq: 3, time: req3.time, message: '', version: 1, ops: [
//              {obj: ROOT_ID, action: 'set', key: 'number', insert: false, value: 3}
//            ]
//          })
//        })
//      })
//
//      describe('applying patches', () => {
//        it('should set root object properties', () => {
//          const actor = uuid()
//          const patch = {
//            version: 1, clock: {[actor]: 1}, canUndo: false, canRedo: false,
//            diffs: {objectId: ROOT_ID, type: 'map', props: {bird: {[actor]: {value: 'magpie'}}}}
//          }
//          const doc = Frontend.applyPatch(Frontend.init(), patch)
//          assert.deepStrictEqual(doc, {bird: 'magpie'})
//        })
//
//        it('should reveal conflicts on root object properties', () => {
//          const patch = {
//            version: 1, clock: {actor1: 1, actor2: 1}, canUndo: false, canRedo: false,
//            diffs: {objectId: ROOT_ID, type: 'map', props: {
//              favoriteBird: {actor1: {value: 'robin'}, actor2: {value: 'wagtail'}}
//            }}
//          }
//          const doc = Frontend.applyPatch(Frontend.init(), patch)
//          assert.deepStrictEqual(doc, {favoriteBird: 'wagtail'})
//          assert.deepStrictEqual(Frontend.getConflicts(doc, 'favoriteBird'), {actor1: 'robin', actor2: 'wagtail'})
//        })
//
//        it('should create nested maps', () => {
//          const birds = uuid(), actor = uuid()
//          const patch = {
//            version: 1, clock: {[actor]: 1}, canUndo: false, canRedo: false,
//            diffs: {objectId: ROOT_ID, type: 'map', props: {birds: {[actor]: {
//              objectId: birds, type: 'map', props: {wrens: {[actor]: {value: 3}}}
//            }}}}
//          }
//          const doc = Frontend.applyPatch(Frontend.init(), patch)
//          assert.deepStrictEqual(doc, {birds: {wrens: 3}})
//        })
//
//        it('should apply updates inside nested maps', () => {
//          const birds = uuid(), actor = uuid()
//          const patch1 = {
//            version: 1, clock: {[actor]: 1}, canUndo: false, canRedo: false,
//            diffs: {objectId: ROOT_ID, type: 'map', props: {birds: {[actor]: {
//              objectId: birds, type: 'map', props: {wrens: {[actor]: {value: 3}}}
//            }}}}
//          }
//          const patch2 = {
//            version: 2, clock: {[actor]: 2}, canUndo: false, canRedo: false,
//            diffs: {objectId: ROOT_ID, type: 'map', props: {birds: {[actor]: {
//              objectId: birds, type: 'map', props: {sparrows: {[actor]: {value: 15}}}
//            }}}}
//          }
//          const doc1 = Frontend.applyPatch(Frontend.init(), patch1)
//          const doc2 = Frontend.applyPatch(doc1, patch2)
//          assert.deepStrictEqual(doc1, {birds: {wrens: 3}})
//          assert.deepStrictEqual(doc2, {birds: {wrens: 3, sparrows: 15}})
//        })
//
//        it('should apply updates inside map key conflicts', () => {
//          const birds1 = uuid(), birds2 = uuid()
//          const patch1 = {
//            version: 1, clock: {[birds1]: 1, [birds2]: 1}, canUndo: false, canRedo: false,
//            diffs: {objectId: ROOT_ID, type: 'map', props: {favoriteBirds: {
//              actor1: {objectId: birds1, type: 'map', props: {blackbirds: {actor1: {value: 1}}}},
//              actor2: {objectId: birds2, type: 'map', props: {wrens:      {actor2: {value: 3}}}}
//            }}}
//          }
//          const patch2 = {
//            version: 2, clock: {[birds1]: 2, [birds2]: 1}, canUndo: false, canRedo: false,
//            diffs: {objectId: ROOT_ID, type: 'map', props: {favoriteBirds: {
//              actor1: {objectId: birds1, type: 'map', props: {blackbirds: {actor1: {value: 2}}}},
//              actor2: {objectId: birds2, type: 'map'}
//            }}}
//          }
//          const doc1 = Frontend.applyPatch(Frontend.init(), patch1)
//          const doc2 = Frontend.applyPatch(doc1, patch2)
//          assert.deepStrictEqual(doc1, {favoriteBirds: {wrens: 3}})
//          assert.deepStrictEqual(doc2, {favoriteBirds: {wrens: 3}})
//          assert.deepStrictEqual(Frontend.getConflicts(doc1, 'favoriteBirds'), {actor1: {blackbirds: 1}, actor2: {wrens: 3}})
//          assert.deepStrictEqual(Frontend.getConflicts(doc2, 'favoriteBirds'), {actor1: {blackbirds: 2}, actor2: {wrens: 3}})
//        })
//
//        it('should structure-share unmodified objects', () => {
//          const birds = uuid(), mammals = uuid(), actor = uuid()
//          const patch1 = {
//            version: 1, clock: {[actor]: 1}, canUndo: false, canRedo: false,
//            diffs: {objectId: ROOT_ID, type: 'map', props: {
//              birds:   {[actor]: {objectId: birds,     type: 'map', props: {wrens:   {[actor]: {value: 3}}}}},
//              mammals: {[actor]: {objectId: mammals,   type: 'map', props: {badgers: {[actor]: {value: 1}}}}}
//            }}
//          }
//          const patch2 = {
//            version: 2, clock: {[actor]: 2}, canUndo: false, canRedo: false,
//            diffs: {objectId: ROOT_ID, type: 'map', props: {
//              birds:   {[actor]: {objectId: birds,     type: 'map', props: {sparrows: {[actor]: {value: 15}}}}}
//            }}
//          }
//          const doc1 = Frontend.applyPatch(Frontend.init(), patch1)
//          const doc2 = Frontend.applyPatch(doc1, patch2)
//          assert.deepStrictEqual(doc1, {birds: {wrens: 3}, mammals: {badgers: 1}})
//          assert.deepStrictEqual(doc2, {birds: {wrens: 3, sparrows: 15}, mammals: {badgers: 1}})
//          assert.strictEqual(doc1.mammals, doc2.mammals)
//        })
//
//        it('should delete keys in maps', () => {
//          const actor = uuid()
//          const patch1 = {
//            version: 1, clock: {[actor]: 1}, canUndo: false, canRedo: false,
//            diffs: {objectId: ROOT_ID, type: 'map', props: {
//              magpies: {[actor]: {value: 2}}, sparrows: {[actor]: {value: 15}}
//            }}
//          }
//          const patch2 = {
//            version: 2, clock: {[actor]: 2}, canUndo: false, canRedo: false,
//            diffs: {objectId: ROOT_ID, type: 'map', props: {
//              magpies: {}
//            }}
//          }
//          const doc1 = Frontend.applyPatch(Frontend.init(), patch1)
//          const doc2 = Frontend.applyPatch(doc1, patch2)
//          assert.deepStrictEqual(doc1, {magpies: 2, sparrows: 15})
//          assert.deepStrictEqual(doc2, {sparrows: 15})
//        })
//
//        it('should create lists', () => {
//          const birds = uuid(), actor = uuid()
//          const patch = {
//            version: 1, clock: {[actor]: 1}, canUndo: false, canRedo: false,
//            diffs: {objectId: ROOT_ID, type: 'map', props: {birds: {[actor]: {
//              objectId: birds, type: 'list',
//              edits: [{action: 'insert', index: 0}],
//              props: {0: {[actor]: {value: 'chaffinch'}}}
//            }}}}
//          }
//          const doc = Frontend.applyPatch(Frontend.init(), patch)
//          assert.deepStrictEqual(doc, {birds: ['chaffinch']})
//        })
//
//        it('should apply updates inside lists', () => {
//          const birds = uuid(), actor = uuid()
//          const patch1 = {
//            version: 1, clock: {[actor]: 1}, canUndo: false, canRedo: false,
//            diffs: {objectId: ROOT_ID, type: 'map', props: {birds: {[actor]: {
//              objectId: birds, type: 'list',
//              edits: [{action: 'insert', index: 0}],
//              props: {0: {[actor]: {value: 'chaffinch'}}}
//            }}}}
//          }
//          const patch2 = {
//            version: 2, clock: {[actor]: 2}, canUndo: false, canRedo: false,
//            diffs: {objectId: ROOT_ID, type: 'map', props: {birds: {[actor]: {
//              objectId: birds, type: 'list', edits: [],
//              props: {0: {[actor]: {value: 'greenfinch'}}}
//            }}}}
//          }
//          const doc1 = Frontend.applyPatch(Frontend.init(), patch1)
//          const doc2 = Frontend.applyPatch(doc1, patch2)
//          assert.deepStrictEqual(doc1, {birds: ['chaffinch']})
//          assert.deepStrictEqual(doc2, {birds: ['greenfinch']})
//        })
//
//        it('should apply updates inside list element conflicts', () => {
//          const birds = uuid(), item1 = uuid(), item2 = uuid(), actor = uuid()
//          const patch1 = {
//            version: 1, clock: {[actor]: 1}, canUndo: false, canRedo: false,
//            diffs: {objectId: ROOT_ID, type: 'map', props: {birds: {[actor]: {
//              objectId: birds, type: 'list',
//              edits: [{action: 'insert', index: 0}],
//              props: {0: {
//                actor1: {objectId: item1, type: 'map', props: {species: {actor1: {value: 'woodpecker'}}, numSeen: {actor1: {value: 1}}}},
//                actor2: {objectId: item2, type: 'map', props: {species: {actor2: {value: 'lapwing'   }}, numSeen: {actor2: {value: 2}}}}
//              }}
//            }}}}
//          }
//          const patch2 = {
//            version: 2, clock: {[actor]: 2}, canUndo: false, canRedo: false,
//            diffs: {objectId: ROOT_ID, type: 'map', props: {birds: {[actor]: {
//              objectId: birds, type: 'list', edits: [],
//              props: {0: {
//                actor1: {objectId: item1, type: 'map', props: {numSeen: {actor1: {value: 2}}}},
//                actor2: {objectId: item2, type: 'map'}
//              }}
//            }}}}
//          }
//          const doc1 = Frontend.applyPatch(Frontend.init(), patch1)
//          const doc2 = Frontend.applyPatch(doc1, patch2)
//          assert.deepStrictEqual(doc1, {birds: [{species: 'lapwing', numSeen: 2}]})
//          assert.deepStrictEqual(doc2, {birds: [{species: 'lapwing', numSeen: 2}]})
//          assert.strictEqual(doc1.birds[0], doc2.birds[0])
//          assert.deepStrictEqual(Frontend.getConflicts(doc1.birds, 0), {
//            actor1: {species: 'woodpecker', numSeen: 1},
//            actor2: {species: 'lapwing',    numSeen: 2}
//          })
//          assert.deepStrictEqual(Frontend.getConflicts(doc2.birds, 0), {
//            actor1: {species: 'woodpecker', numSeen: 2},
//            actor2: {species: 'lapwing',    numSeen: 2}
//          })
//        })
//
//        it('should delete list elements', () => {
//          const birds = uuid(), actor = uuid()
//          const patch1 = {
//            version: 1, clock: {[actor]: 1}, canUndo: false, canRedo: false,
//            diffs: {objectId: ROOT_ID, type: 'map', props: {birds: {[actor]: {
//              objectId: birds, type: 'list',
//              edits: [{action: 'insert', index: 0}, {action: 'insert', index: 1}],
//              props: {
//                0: {[actor]: {value: 'chaffinch'}},
//                1: {[actor]: {value: 'goldfinch'}}
//              }
//            }}}}
//          }
//          const patch2 = {
//            version: 2, clock: {[actor]: 2}, canUndo: false, canRedo: false,
//            diffs: {objectId: ROOT_ID, type: 'map', props: {birds: {[actor]: {
//              objectId: birds, type: 'list', props: {},
//              edits: [{action: 'remove', index: 0}]
//            }}}}
//          }
//          const doc1 = Frontend.applyPatch(Frontend.init(), patch1)
//          const doc2 = Frontend.applyPatch(doc1, patch2)
//          assert.deepStrictEqual(doc1, {birds: ['chaffinch', 'goldfinch']})
//          assert.deepStrictEqual(doc2, {birds: ['goldfinch']})
//        })
//
//        it('should apply updates at different levels of the object tree', () => {
//          const counts = uuid(), details = uuid(), detail1 = uuid(), actor = uuid()
//          const patch1 = {
//            version: 1, clock: {[actor]: 1}, canUndo: false, canRedo: false,
//            diffs: {objectId: ROOT_ID, type: 'map', props: {
//              counts: {[actor]: {objectId: counts, type: 'map', props: {
//                magpies: {[actor]: {value: 2}}
//              }}},
//              details: {[actor]: {objectId: details, type: 'list',
//                edits: [{action: 'insert', index: 0}],
//                props: {0: {[actor]: {objectId: detail1, type: 'map', props: {
//                  species: {[actor]: {value: 'magpie'}},
//                  family:  {[actor]: {value: 'corvidae'}}
//                }}}}
//              }}
//            }}
//          }
//          const patch2 = {
//            version: 2, clock: {[actor]: 2}, canUndo: false, canRedo: false,
//            diffs: {objectId: ROOT_ID, type: 'map', props: {
//              counts: {[actor]: {objectId: counts, type: 'map', props: {
//                magpies: {[actor]: {value: 3}}
//              }}},
//              details: {[actor]: {objectId: details, type: 'list', edits: [],
//                props: {0: {[actor]: {objectId: detail1, type: 'map', props: {
//                  species: {[actor]: {value: 'Eurasian magpie'}}
//                }}}}
//              }}
//            }}
//          }
//          const doc1 = Frontend.applyPatch(Frontend.init(), patch1)
//          const doc2 = Frontend.applyPatch(doc1, patch2)
//          assert.deepStrictEqual(doc1, {counts: {magpies: 2}, details: [{species: 'magpie', family: 'corvidae'}]})
//          assert.deepStrictEqual(doc2, {counts: {magpies: 3}, details: [{species: 'Eurasian magpie', family: 'corvidae'}]})
//        })
//      })
//
//      describe('undo and redo', () => {
//        it('should allow undo in the frontend', () => {
//          const doc0 = Frontend.init(), b0 = Backend.init(), actor = Frontend.getActorId(doc0)
//          assert.strictEqual(Frontend.canUndo(doc0), false)
//          const [doc1, req1] = Frontend.change(doc0, doc => doc.number = 1)
//          const [b1, patch1] = Backend.applyLocalChange(b0, req1)
//          const doc1a = Frontend.applyPatch(doc1, patch1)
//          assert.strictEqual(Frontend.canUndo(doc1a), true)
//          const [doc2, req2] = Frontend.undo(doc1a)
//          assert.deepStrictEqual(req2, {actor, requestType: 'undo', seq: 2, time: req2.time, message: '', version: 1})
//          const [b2, patch2] = Backend.applyLocalChange(b1, req2)
//          const doc2a = Frontend.applyPatch(doc2, patch2)
//          assert.deepStrictEqual(doc2a, {})
//        })
//
//        function apply(backend, change) {
//          const [doc, req] = change
//          const [newBackend, patch] = Backend.applyLocalChange(backend, req)
//          return [newBackend, Frontend.applyPatch(doc, patch)]
//        }
//
//        it('should perform multiple undos and redos', () => {
//          const doc0 = Frontend.init(), b0 = Backend.init()
//          const [b1, doc1] = apply(b0, Frontend.change(doc0, doc => doc.number = 1))
//          const [b2, doc2] = apply(b1, Frontend.change(doc1, doc => doc.number = 2))
//          const [b3, doc3] = apply(b2, Frontend.change(doc2, doc => doc.number = 3))
//          const [b4, doc4] = apply(b3, Frontend.undo(doc3))
//          const [b5, doc5] = apply(b4, Frontend.undo(doc4))
//          const [b6, doc6] = apply(b5, Frontend.redo(doc5))
//          const [b7, doc7] = apply(b6, Frontend.redo(doc6))
//          assert.deepStrictEqual(doc1, {number: 1})
//          assert.deepStrictEqual(doc2, {number: 2})
//          assert.deepStrictEqual(doc3, {number: 3})
//          assert.deepStrictEqual(doc4, {number: 2})
//          assert.deepStrictEqual(doc5, {number: 1})
//          assert.deepStrictEqual(doc6, {number: 2})
//          assert.deepStrictEqual(doc7, {number: 3})
//        })
//      })
//    })
//}

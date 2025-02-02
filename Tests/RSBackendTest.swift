//
//  RSBackendTest.swift
//  Automerge
//
//  Created by Lukas Schmidt on 10.05.20.
//

import Foundation
@testable import Automerge
import XCTest

final class RSBackendTest: XCTestCase {

//    func testInit() {
//        let backend = RSBackend()
//         XCTAssertEqual(backend.save(), [])
//    }

//    func testloadDocument() {
//        let initialDocumentState: [UInt8] = [133,111,74,131,67,87,31,164,0,162,1,1,16,216,174,219,98,163,198,72,226,186,232,37,141,162,111,106,34,1,66,129,104,19,111,146,163,48,114,216,197,112,88,253,81,69,231,3,107,17,68,57,99,190,132,215,172,44,149,155,164,1,6,1,2,127,0,3,2,127,1,11,2,127,2,19,7,127,155,170,164,139,163,46,29,16,127,14,73,110,105,116,105,97,108,105,122,97,116,105,111,110,32,2,127,0,1,4,0,1,127,0,2,4,0,1,127,1,9,4,0,1,127,0,11,4,0,1,127,0,13,9,127,5,98,105,114,100,115,0,1,17,2,2,0,19,2,2,1,28,2,1,1,34,3,126,5,0,46,3,126,0,70,47,4,84,101,115,116,64,2,2,0]
//        let backend = RSBackend(data: initialDocumentState)
//
//        let abc = backend.save()
//        XCTAssertEqual(backend.save(), initialDocumentState)
//    }

    func testApplyLocal() {
        let backend = RSBackend()
        let request = Request(
            startOp: 1,
            deps: [],
            message: "Test",
            time: Date(),
            actor: "111111",
            seq: 1,
            ops: [
                Op(action: .set, obj: .root, key: "bird", value: .string("magpie"), pred: [])
            ])
        _ = try! backend.applyLocalChange(request: request)
    }

}

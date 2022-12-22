//
//  TableTests.swift
//  Automerge
//
//  Created by Lukas Schmidt on 12.06.20.
//

import Foundation
@testable import Automerge
import XCTest

class TableTest: XCTestCase {

    // should generate ops to create a table
    func testTableFronted1() {
        struct Scheme: Equatable, Codable {
            struct Book: Equatable, Codable { }
            var books: Table<Book>?
        }
        let actor = Actor()
        var doc = try! Document(Scheme(books: nil), actor: actor)

        let req = try! doc.change {
            $0.books?.set(Table())
        }

        XCTAssertEqual(req, Request(
                        startOp: 1,
                        deps: [],
                        message: "",
                        time: req!.time,
                        actor: actor,
                        seq: 1,
                        ops: [
            Op(action: .makeTable, obj: .root, key: "books", pred: [])
        ]))
    }

    // should generate ops to insert a row
    func testTableFronted2() {
        struct Scheme: Equatable, Codable {
            struct Book: Equatable, Codable {
                let authors: String
                let title: String
            }
            var books: Table<Book>
        }
        let actor = Actor()
        var doc = try! Document(Scheme(books: Table()), actor: actor)

        var rowId: ObjectId!
        let req = try! doc.change {
            rowId = $0.books.add(.init(authors: "Kleppmann, Martin", title: "Designing Data-Intensive Applications"))
        }

        let books = doc.rootProxy().books.objectId
        let rowObjID = doc.rootProxy().books.row(by: rowId)?.objectId
        XCTAssertEqual(req, Request(
                        startOp: 2,
                        deps: [],
                        message: "",
                        time: req!.time,
                        actor: actor,
                        seq: 2,
                        ops: [
                            Op(action: .makeMap, obj: books!, key: .string(rowId.objectId), pred: []),
                            Op(action: .set, obj: rowObjID!, key: "authors", value: "Kleppmann, Martin", pred: []),
                            Op(action: .set, obj: rowObjID!, key: "title", value: "Designing Data-Intensive Applications", pred: []),
                        ]))
    }

    // should generate ops to insert a row with a specified ID
    func testTableFronted3() {
        struct Scheme: Equatable, Codable {
            struct Book: Equatable, Codable {
                let authors: String
                let title: String
            }
            var books: Table<Book>
        }
        let actor = Actor()
        var doc = try! Document(Scheme(books: Table()), actor: actor)

        let rowIdStr = "b9b916c1-3da7-4427-bd16-a918927c60ec"
        let rowId = ObjectId(stringLiteral: rowIdStr)
        let req = try! doc.change {
            $0.books.add(.init(authors: "Kleppmann, Martin", title: "Designing Data-Intensive Applications"), id: rowId)
        }

        let books = doc.rootProxy().books.objectId
        let rowObjID = doc.rootProxy().books.row(by: rowId)?.objectId
        XCTAssertEqual(req, Request(
                        startOp: 2,
                        deps: [],
                        message: "",
                        time: req!.time,
                        actor: actor,
                        seq: 2,
                        ops: [
                            Op(action: .makeMap, obj: books!, key: .string(rowIdStr), pred: []),
                            Op(action: .set, obj: rowObjID!, key: "authors", value: "Kleppmann, Martin", pred: []),
                            Op(action: .set, obj: rowObjID!, key: "title", value: "Designing Data-Intensive Applications", pred: []),
                        ]))
    }

    // should look up a row by ID
    func testTableWithOneRow1() {
        struct Scheme: Equatable, Codable {
            struct Book: Equatable, Codable {
                let authors: String
                let title: String
                static let ddia = Book(authors: "Kleppmann, Martin", title: "Designing Data-Intensive Applications")
            }
            var books: Table<Book>
        }
        let actor = Actor()
        var s1 = try! Document(Scheme(books: Table()), actor: actor)

        var rowId: ObjectId?
        try! s1.change {
            rowId = $0.books.add(.ddia)
        }
        XCTAssertEqual(s1.content.books.row(by: rowId!)?.value, .ddia)
    }

    // should return the row count
    func testTableWithOneRow2() {
        struct Scheme: Equatable, Codable {
            struct Book: Equatable, Codable {
                let authors: String
                let title: String
                static let ddia = Book(authors: "Kleppmann, Martin", title: "Designing Data-Intensive Applications")
            }
            var books: Table<Book>
        }
        let actor = Actor()
        var s1 = try! Document(Scheme(books: Table()), actor: actor)

        try! s1.change {
            $0.books.add(.ddia)
        }
        XCTAssertEqual(s1.content.books.count, 1)
        XCTAssertEqual(Array(s1.content.books).map{ $0.value}, [.ddia])
    }

    // should return a list of row IDs
    func testTableWithOneRow3() {
        struct Scheme: Equatable, Codable {
            struct Book: Equatable, Codable {
                let authors: String
                let title: String
                static let ddia = Book(authors: "Kleppmann, Martin", title: "Designing Data-Intensive Applications")
            }
            var books: Table<Book>
        }
        let actor = Actor()
        var s1 = try! Document(Scheme(books: Table()), actor: actor)

        var rowId: ObjectId?
        try! s1.change {
            rowId = $0.books.add(.ddia)
        }
        XCTAssertEqual(s1.content.books.ids, [rowId!])
    }

    // should save and reload
    func testTableWithOneRow4() {
        struct Scheme: Equatable, Codable {
            struct Book: Equatable, Codable {
                let authors: String
                let title: String
                static let ddia = Book(authors: "Kleppmann, Martin", title: "Designing Data-Intensive Applications")
            }
            var books: Table<Book>
        }
        let actor = Actor()
        var s1 = try! Document(Scheme(books: Table()), actor: actor)

        var rowId: ObjectId?
        try! s1.change {
            rowId = $0.books.add(.ddia)
        }
        XCTAssertEqual(try! Document<Scheme>(changes: s1.allChanges()).content.books.row(by: rowId!)?.value, .ddia)
    }

    // should allow a row to be updated
    func testTableWithOneRow5() {
        struct Scheme: Equatable, Codable {
            struct Book: Equatable, Codable {
                let authors: String
                let title: String
                var isbn: String?
                static let ddia = Book(authors: "Kleppmann, Martin", title: "Designing Data-Intensive Applications", isbn: nil)
            }
            var books: Table<Book>
        }
        let actor = Actor()
        var s1 = try! Document(Scheme(books: Table()), actor: actor)

        var rowId: ObjectId!
        try! s1.change {
            rowId = $0.books.add(.ddia)
        }
        try! s1.change {
            $0.books.row(by: rowId)?.isbn.set("9781449373320")
        }
        XCTAssertEqual(s1.content.books.row(by: rowId!)?.value, Scheme.Book(authors: "Kleppmann, Martin", title: "Designing Data-Intensive Applications", isbn: "9781449373320"))
    }

    // should allow a row to be removed
    func testTableWithOneRow6() {
        struct Scheme: Equatable, Codable {
            struct Book: Equatable, Codable {
                let authors: String
                let title: String
                static let ddia = Book(authors: "Kleppmann, Martin", title: "Designing Data-Intensive Applications")
            }
            var books: Table<Book>
        }
        let actor = Actor()
        var s1 = try! Document(Scheme(books: Table()), actor: actor)

        var rowId: ObjectId!
        try! s1.change {
            rowId = $0.books.add(.ddia)
        }
        try! s1.change {
            $0.books.removeRow(by: rowId)
        }
        XCTAssertEqual(s1.content.books.count, 0)
    }

    // should allow concurrent row insertion
    func testTableWithOneRow7() {
        struct Scheme: Equatable, Codable {
            struct Book: Equatable, Codable {
                let authors: [String]
                let title: String
                static let ddia = Book(authors: ["Kleppmann, Martin"], title: "Designing Data-Intensive Applications")
                static let rsdp = Book(authors: ["Cachin, Christian", "Guerraoui, Rachid", "Rodrigues, Luís"], title: "Introduction to Reliable and Secure Distributed Programming")
            }
            var books: Table<Book>
        }
        let actor = Actor()
        var s1 = try! Document(Scheme(books: Table()), actor: actor)
        var s2 = try! Document<Scheme>(changes: s1.allChanges())

        var ddia: ObjectId!
        var rsdp: ObjectId!
        try! s1.change {
            ddia = $0.books.add(.ddia)
        }
        try! s2.change {
            rsdp = $0.books.add(.rsdp)
        }
        try! s1.merge(s2)
        XCTAssertEqual(s1.content.books.row(by: ddia)?.value, .ddia)
        XCTAssertEqual(s1.content.books.row(by: ddia)?.id, ddia)
        XCTAssertEqual(s1.content.books.row(by: rsdp)?.value, .rsdp)
        XCTAssertEqual(s1.content.books.row(by: rsdp)?.id, rsdp)
        XCTAssertEqual(s1.content.books.count, 2)
        XCTAssertEqualOneOf(s1.content.books.ids, [ddia, rsdp], [rsdp, ddia])
    }

}

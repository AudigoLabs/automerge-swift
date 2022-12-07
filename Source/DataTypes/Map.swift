//
//  Map.swift
//  Automerge
//
//  Created by Lukas Schmidt on 22.04.21.
//

import Foundation

/// A representation of a Map object within Automerge.
struct Map: Equatable, Codable {

    init(objectId: ObjectId = "", mapValues: [String: Object] = [:], conflicts: [String: [ObjectId: Object]] = [:]) {
        self.objectId = objectId
        self.mapValues = mapValues
        self.conflicts = conflicts
    }

    let objectId: ObjectId
    var mapValues: [String: Object]
    var conflicts: [String: [ObjectId: Object]]

    subscript(_ key: String) -> Object? {
        get {
            return mapValues[key]
        }
        set {
            mapValues[key] = newValue
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(mapValues)
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.mapValues = try container.decode([String: Object].self)
        self.objectId = ObjectId("")
        self.conflicts = [:]
    }

    static func == (lhs: Map, rhs: Map) -> Bool {
        return (lhs.objectId == "" || rhs.objectId == "" || lhs.objectId == rhs.objectId) && lhs.mapValues == rhs.mapValues
    }
}

extension Map: Sequence {
    public func makeIterator() -> AnyIterator<(key: String, value: Object)> {
        return AnyIterator(mapValues.sorted(by: { $0.key < $1.key }).makeIterator())
    }
}

extension Map: ExpressibleByDictionaryLiteral {

    init(dictionaryLiteral elements: (String, Object)...) {
        self = Map(mapValues: Dictionary(uniqueKeysWithValues: elements))
    }

}

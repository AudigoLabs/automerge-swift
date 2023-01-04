//
//  File.swift
//  
//
//  Created by Lukas Schmidt on 07.04.20.
//

import Foundation


/// A class that represents the collection of changes and current change state of a document.
public final class Patch: Codable {

    init(
        actor: Actor? = nil,
        seq: Int? = nil,
        clock: Clock,
        deps: [ObjectId],
        maxOp: Int,
        diffs: MapDiff
    ) {
        self.actor = actor
        self.seq = seq
        self.clock = clock
        self.deps = deps
        self.maxOp = maxOp
        self.diffs = diffs
    }

    let actor: Actor?
    let seq: Int?
    let clock: Clock
    let deps: [ObjectId]
    let maxOp: Int
    let diffs: MapDiff
    
    /// Creates a new Patch by decoding from the provided decoder.
    /// - Parameter decoder: The decoder to read data from.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.actor = try container.decodeIfPresent(Actor.self, forKey: .actor)
        self.seq = try container.decodeIfPresent(Int.self, forKey: .seq)
        self.clock = try container.decode(Clock.self, forKey: .clock)
        self.deps = try container.decode([ObjectId].self, forKey: .deps)
        self.maxOp = try container.decode(Int.self, forKey: .maxOp)

        self.diffs = (try? container.decode(MapDiff.self, forKey: .diffs)) ?? .empty
    }

}

public extension Patch {

    func debugGetChangedProperties() -> [String: String] {
        var result = [String: String]()
        getChangedPropertiesHelper(diffs.props, &result)
        return result
    }

    private func getChangedPropertiesHelper(_ props: Props, _ result: inout [String: String], _ path: [String] = []) {
        for (key, values) in props {
            var newPath = path
            newPath.append("\(key)")
            for diff in values.values {
                switch diff {
                case .map(let mapDiff):
                    getChangedPropertiesHelper(mapDiff.props, &result, newPath)
                case .list(_):
                    // TODO
                    break
                case .value(let valueDiff):
                    result[newPath.joined(separator: ".")] = "\(valueDiff.value)"
                }
            }
        }
    }

}

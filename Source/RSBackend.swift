//
//  RSBackend.swift
//  
//
//  Created by Lukas Schmidt on 07.04.20.
//

import Foundation
import AutomergeBackend
import ZippyJSON

/// A class that wraps the Automerge-rs core library.
public final class RSBackend {

    private var automerge: OpaquePointer
    private let encoder: JSONEncoder
    private let decoder: ZippyJSONDecoder

    public convenience init() {
        self.init(automerge: automerge_init())
    }

    public convenience init(data: [UInt8]) throws {
        guard let automerge = automerge_load(UInt(data.count), data) else {
            throw AutomergeError.loadFailed
        }
        self.init(automerge: automerge)
    }

    deinit {
        automerge_free(automerge)
    }

    public func clone() -> RSBackend {
        return RSBackend(automerge: automerge_clone(automerge))
    }

    public convenience init(changes: [[UInt8]]) throws {
        self.init()
        _ = try apply(changes: changes)
    }

    private init(automerge: OpaquePointer) {
        self.automerge = automerge
        self.encoder = JSONEncoder()
        self.decoder = .init()
        encoder.dateEncodingStrategy = .custom({ (date, encoder) throws in
            var container = encoder.singleValueContainer()
            let seconds: UInt = UInt(date.timeIntervalSince1970)
            try container.encode(seconds)
        })
        decoder.dateDecodingStrategy = .custom({ (decoder) throws in
            var container = try decoder.unkeyedContainer()
            return try Date(timeIntervalSince1970: container.decode(TimeInterval.self))
        })
    }

    public func save() throws -> [UInt8] {
        let length = automerge_save(automerge)
        guard length >= 0 else {
            throw backendError
        }
        return try readBinary(length: length)
    }

    public func applyLocalChange(request: Request) throws -> Patch {
        let data = try encoder.encode(request)
        let string = String(data: data, encoding: .utf8)
        return try callJSONFunction(resultType: Patch.self) {
            automerge_apply_local_change(automerge, string)
        }
    }

    public func apply(changes: [[UInt8]]) throws -> Patch {
        for change in changes {
            automerge_write_change(automerge, UInt(change.count), change)
        }
        return try callJSONFunction(resultType: Patch.self) {
            automerge_apply_changes(automerge)
        }
    }

    public func getPatch() throws -> Patch {
        try callJSONFunction(resultType: Patch.self) {
            automerge_get_patch(automerge)
        }
    }

    public func getChanges(heads: [String] = []) throws -> [[UInt8]] {
        var changes = [[UInt8]]()
        var headsBuffer = Array<UInt8>(hex: heads.joined())
        var length = automerge_get_changes(automerge, UInt(heads.count), &headsBuffer)
        guard length >= 0 else {
            throw backendError
        }
        while length > 0 {
            try changes.append(readBinary(mutableLength: &length))
        }
        return changes
    }

    public func getMissingDeps() throws -> [String] {
        var buffer = [UInt8]()
        return try callJSONFunction(resultType: [String].self) {
            automerge_get_missing_deps(automerge, 0, &buffer)
        }
    }

    public func getHeads() throws -> [String] {
        var length = automerge_get_heads(automerge)
        var heads = [[UInt8]]()
        while length > 0 {
            var readLength = 32
            heads.append(try readBinary(mutableLength: &readLength))
            length = readLength
        }

        return heads.map { $0.toHexString() }
    }

    public func generateSyncMessage(syncStatePointer: OpaquePointer) throws -> [UInt8] {
        try callBinaryFunction({ automerge_generate_sync_message(automerge, syncStatePointer) }).data
    }

    public func receiveSyncMessage(syncStatePointer: OpaquePointer, data: [UInt8]) throws -> Patch? {
        try callOptionalJSONFunction(resultType: Patch.self) {
            automerge_receive_sync_message(automerge, syncStatePointer, data, UInt(data.count))
        }
    }

    public func encodeSyncState(syncStatePointer: OpaquePointer) throws -> [UInt8] {
        try callBinaryFunction({ automerge_encode_sync_state(automerge, syncStatePointer) }).data
    }

    func decodeSyncMessage(bytes: [UInt8]) throws -> SyncMessage {
        try callJSONFunction(resultType: SyncMessage.self) {
            automerge_decode_sync_message(automerge, bytes, UInt(bytes.count))
        }
    }

    func decodeChange(bytes: [UInt8]) throws -> Change {
        try callJSONFunction(resultType: Change.self) {
            automerge_decode_change(automerge, UInt(bytes.count), bytes)
        }
    }

}

extension RSBackend {

    private func callJSONFunction<T: Decodable>(resultType: T.Type, _ api: () -> Int) throws -> T {
        let length = api()
        guard length >= 0 else {
            throw backendError
        }
        return try readJSON(resultType, length: length)
    }

    private func callOptionalJSONFunction<T: Decodable>(resultType: T.Type, _ api: () -> Int) throws -> T? {
        let length = api()
        guard length >= 0 else {
            throw backendError
        }
        guard length > 0 else {
            return nil
        }
        return try readJSON(resultType, length: length)
    }

    private func readJSON<T: Decodable>(_ type: T.Type, length: Int) throws -> T {
        var buffer = Array<Int8>(repeating: 0, count: length)
        guard automerge_read_json(automerge, &buffer) == 0 else {
            throw backendError
        }
        guard let data = String(cString: buffer).data(using: .utf8) else {
            throw AutomergeError.dataConversion
        }
        return try decoder.decode(type, from: data)
    }

}

extension RSBackend {

    private func callBinaryFunction(_ api: () -> Int) throws -> (data: [UInt8], length: Int) {
        var length = api()
        guard length >= 0 else {
            throw backendError
        }
        if length == 0 {
            return (data: [], length: 0)
        }
        let data = try readBinary(mutableLength: &length)
        return (data: data, length: length)
    }

    private func readBinary(mutableLength: inout Int) throws -> [UInt8] {
        var data = Array<UInt8>(repeating: 0, count: mutableLength)
        mutableLength = automerge_read_binary(automerge, &data)
        guard mutableLength >= 0 else {
            throw backendError
        }
        return data
    }

    private func readBinary(length: Int) throws -> [UInt8] {
        var length = length
        return try readBinary(mutableLength: &length)
    }

}

extension RSBackend {

    private var backendError: AutomergeError {
        let errStr = automerge_error(automerge)
        if let errStr = errStr {
            let error = String(cString: errStr)
            return .backend(error.trimmingCharacters(in: CharacterSet(charactersIn: "\"")))
        } else {
            return .backend(nil)
        }
    }
}

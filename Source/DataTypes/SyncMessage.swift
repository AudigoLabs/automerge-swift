//
//  SyncMessage.swift
//  
//
//  Created by Brian Gomberg on 12/21/22.
//

import Foundation

public struct SyncMessage: Codable {
    public let heads: [String]
    public let need: [String]
    public let have: [SyncHave]
    public let changes: [[UInt8]]

    public struct SyncHave: Codable {
        public let lastSync: [String]
        public let bloom: [UInt8]
    }

    public init(bytes: [UInt8]) throws {
        self = try RSBackend().decodeSyncMessage(bytes: bytes)
    }
}

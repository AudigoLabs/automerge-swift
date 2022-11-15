//
//  SyncState.swift
//  
//
//  Created by Brian Gomberg on 9/27/22.
//

import AutomergeBackend
import Foundation

public class SyncState {
    private(set) var pointer: OpaquePointer

    public init() {
        pointer = automerge_sync_state_init()
    }

    public init(data: [UInt8]) {
        pointer = automerge_decode_sync_state(data, UInt(data.count))
    }

    deinit {
        automerge_sync_state_free(pointer)
    }
}

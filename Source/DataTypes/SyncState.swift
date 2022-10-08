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

    deinit {
        automerge_sync_state_free(pointer)
    }
}

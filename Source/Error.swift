//
//  File.swift
//  
//
//  Created by Brian Gomberg on 12/21/22.
//

import Foundation
import AutomergeBackend

public enum AutomergeError: Error {
    case dataConversion
    case loadFailed
    case backend(String?)
}

//
//  Request.swift
//  
//
//  Created by Lukas Schmidt on 07.04.20.
//

import Foundation

public struct Request: Equatable, Codable {

    public let startOp: Int
    public let deps: [ObjectId]
    public let message: String
    public let time: Date
    public let actor: Actor
    public let seq: Int
    public let ops: [Op]

}

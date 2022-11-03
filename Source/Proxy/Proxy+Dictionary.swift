//
//  Proxy+Dictionary.swift
//  
//
//  Created by Brian Gomberg on 11/2/22.
//

import Foundation

extension Proxy where Wrapped: ExpressibleByDictionaryLiteral, Wrapped.Value: Codable, Wrapped.Key == String {

    private var map: Map {
        guard case .map(let map)? = objectId.map({ context.getObject(objectId: $0) }) else {
           fatalError("Must be map")
        }

        return map
    }

    public subscript(key: String) -> Proxy<Wrapped.Value> {
        get {
            let objectId = map[key]?.objectId
            return Proxy<Wrapped.Value>(
                context: context,
                objectId: objectId,
                path: path + [.init(key: .string(key), objectId: objectId)],
                value: (self.get() as! Dictionary)[key]
            )
        }
    }

    public func removeValue(forKey key: String) {
        context.setMapKey(path: path, key: key, value: .primitive(.null))
    }

}

extension MutableProxy where Wrapped: ExpressibleByDictionaryLiteral, Wrapped.Value: Codable, Wrapped.Key == String {

    private var map: Map {
        guard case .map(let map)? = objectId.map({ context.getObject(objectId: $0) }) else {
           fatalError("Must be map")
        }

        return map
    }

    public subscript(key: String) -> MutableProxy<Wrapped.Value> {
        get {
            let objectId = map[key]?.objectId
            return MutableProxy<Wrapped.Value>(
                context: context,
                objectId: objectId,
                path: path + [.init(key: .string(key), objectId: objectId)],
                value: (self.get() as! Dictionary)[key]
            )
        }
    }

    public func removeValue(forKey key: String) {
        context.setMapKey(path: path, key: key, value: .primitive(.null))
    }

}

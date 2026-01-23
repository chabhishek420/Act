//
//  AnyCodable.swift
//  Rube-ios
//

import Foundation

@frozen public struct AnyCodable: Codable, @unchecked Sendable {
    public let value: Any

    public init(_ value: Any) {
        self.value = value
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let x = try? container.decode(Bool.self) {
            value = x
        } else if let x = try? container.decode(Int.self) {
            value = x
        } else if let x = try? container.decode(Double.self) {
            value = x
        } else if let x = try? container.decode(String.self) {
            value = x
        } else if let x = try? container.decode([String: AnyCodable].self) {
            value = x.mapValues { $0.value }
        } else if let x = try? container.decode([AnyCodable].self) {
            value = x.map { $0.value }
        } else if container.decodeNil() {
            value = NSNull()
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Wrong type for AnyCodable")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let x as Bool:
            try container.encode(x)
        case let x as Int:
            try container.encode(x)
        case let x as Double:
            try container.encode(x)
        case let x as String:
            try container.encode(x)
        case let x as [String: Any]:
            try container.encode(x.mapValues { AnyCodable($0) })
        case let x as [Any]:
            try container.encode(x.map { AnyCodable($0) })
        case is NSNull:
            try container.encodeNil()
        default:
            throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: encoder.codingPath, debugDescription: "Wrong type for AnyCodable"))
        }
    }
}

extension AnyCodable: Equatable {
    public static func == (lhs: AnyCodable, rhs: AnyCodable) -> Bool {
        switch (lhs.value, rhs.value) {
        case let (l as Bool, r as Bool): return l == r
        case let (l as Int, r as Int): return l == r
        case let (l as Double, r as Double): return l == r
        case let (l as String, r as String): return l == r
        case let (l as [String: Any], r as [String: Any]): return NSDictionary(dictionary: l).isEqual(r)
        case let (l as [Any], r as [Any]): return NSArray(array: l).isEqual(r)
        case (is NSNull, is NSNull): return true
        default: return false
        }
    }
}

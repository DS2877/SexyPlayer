import Foundation

/// Xtream Codes panels are notoriously loose with JSON types: an id might be
/// `12`, `"12"`, or `12.0`; a missing value might be `null`, `""`, `false`, or
/// absent. These decode defensively.

@propertyWrapper
public struct LenientInt: Codable, Hashable, Sendable {
    public var wrappedValue: Int?

    public init(wrappedValue: Int?) { self.wrappedValue = wrappedValue }

    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { wrappedValue = nil; return }
        if let i = try? c.decode(Int.self) { wrappedValue = i; return }
        if let d = try? c.decode(Double.self) { wrappedValue = Int(d); return }
        if let s = try? c.decode(String.self) {
            let trimmed = s.trimmingCharacters(in: .whitespaces)
            wrappedValue = Int(trimmed) ?? Double(trimmed).map(Int.init)
            return
        }
        if let b = try? c.decode(Bool.self) { wrappedValue = b ? 1 : 0; return }
        wrappedValue = nil
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(wrappedValue)
    }
}

@propertyWrapper
public struct LenientString: Codable, Hashable, Sendable {
    public var wrappedValue: String?

    public init(wrappedValue: String?) { self.wrappedValue = wrappedValue }

    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { wrappedValue = nil; return }
        if let s = try? c.decode(String.self) {
            let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
            wrappedValue = trimmed.isEmpty ? nil : trimmed
            return
        }
        if let i = try? c.decode(Int.self) { wrappedValue = String(i); return }
        if let d = try? c.decode(Double.self) { wrappedValue = String(d); return }
        if let b = try? c.decode(Bool.self) { wrappedValue = b ? "1" : nil; return }
        wrappedValue = nil
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(wrappedValue)
    }
}

extension KeyedDecodingContainer {
    /// Missing keys decode to a nil-wrapped value instead of throwing.
    public func decode(_ type: LenientInt.Type, forKey key: Key) throws -> LenientInt {
        try decodeIfPresent(type, forKey: key) ?? LenientInt(wrappedValue: nil)
    }
    public func decode(_ type: LenientString.Type, forKey key: Key) throws -> LenientString {
        try decodeIfPresent(type, forKey: key) ?? LenientString(wrappedValue: nil)
    }
}

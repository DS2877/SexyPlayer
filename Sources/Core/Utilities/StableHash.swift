import Foundation

/// A deterministic, process-independent hash. Unlike `Hasher`, the result is the
/// same across launches, which is what stable identifiers and cache keys need.
///
/// FNV-1a (64-bit). Not cryptographic — collision resistance is "good enough for
/// identifiers", not security.
public enum StableHash {
    public static func hash(_ string: String) -> UInt64 {
        var result: UInt64 = 0xcbf29ce484222325
        for byte in string.utf8 {
            result ^= UInt64(byte)
            result = result &* 0x100000001b3
        }
        return result
    }

    public static func hash(_ parts: [String]) -> UInt64 {
        hash(parts.joined(separator: "\u{1f}"))
    }
}

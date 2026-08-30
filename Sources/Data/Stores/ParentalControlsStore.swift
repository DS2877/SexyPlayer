import Foundation
import Observation
import CryptoKit

/// A 4-digit PIN that gates revealing adult-flagged content.
///
/// This is a parental control, not a security boundary: a 4-digit code is
/// inherently low-entropy and the PIN only guards the *toggle* in Settings, not
/// the data itself. It's stored as a salted SHA-256 hash in `UserDefaults` so
/// the digits are never written in the clear.
@MainActor
@Observable
public final class ParentalControlsStore {

    /// True when a PIN has been set.
    public private(set) var isEnabled: Bool

    private var storedHash: String?
    private let salt: String
    private let defaults: UserDefaults
    private let hashKey = "parental.pinHash.v1"
    private let saltKey = "parental.salt.v1"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let existing = defaults.string(forKey: saltKey) {
            self.salt = existing
        } else {
            let fresh = UUID().uuidString
            defaults.set(fresh, forKey: saltKey)
            self.salt = fresh
        }
        let hash = defaults.string(forKey: hashKey)
        self.storedHash = hash
        self.isEnabled = hash != nil
    }

    public static func isValidPIN(_ pin: String) -> Bool {
        pin.count == 4 && pin.allSatisfy(\.isNumber)
    }

    /// Set or replace the PIN. Returns false if `pin` isn't 4 digits.
    @discardableResult
    public func setPIN(_ pin: String) -> Bool {
        guard Self.isValidPIN(pin) else { return false }
        let hash = Self.digest(pin, salt: salt)
        storedHash = hash
        defaults.set(hash, forKey: hashKey)
        isEnabled = true
        return true
    }

    /// True if `pin` matches, or if no PIN is set (nothing to check).
    public func verify(_ pin: String) -> Bool {
        guard let storedHash else { return true }
        return Self.digest(pin, salt: salt) == storedHash
    }

    /// Remove the PIN. Requires the current PIN.
    @discardableResult
    public func disable(currentPIN: String) -> Bool {
        guard verify(currentPIN) else { return false }
        storedHash = nil
        defaults.removeObject(forKey: hashKey)
        isEnabled = false
        return true
    }

    private static func digest(_ pin: String, salt: String) -> String {
        let data = Data((salt + ":" + pin).utf8)
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

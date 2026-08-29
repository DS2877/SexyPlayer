import Foundation
import Observation

/// Holds `UserPreferences`, persisted as JSON in `UserDefaults`.
@MainActor
@Observable
public final class PreferencesStore {

    public private(set) var preferences: UserPreferences

    private let defaults: UserDefaults
    private let key = "userPreferences.v1"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: key),
           let decoded = try? JSONDecoder().decode(UserPreferences.self, from: data) {
            self.preferences = decoded
        } else {
            self.preferences = UserPreferences()
        }
    }

    public var hasOnboarded: Bool { preferences.hasOnboarded }

    /// Apply an edit and persist.
    public func update(_ mutate: (inout UserPreferences) -> Void) {
        var copy = preferences
        mutate(&copy)
        preferences = copy
        persist()
    }

    public func completeOnboarding() {
        update { $0.hasOnboarded = true }
    }

    public func reset() {
        preferences = UserPreferences()
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(preferences) else { return }
        defaults.set(data, forKey: key)
    }
}

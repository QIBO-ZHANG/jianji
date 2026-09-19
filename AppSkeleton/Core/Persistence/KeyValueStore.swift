import Foundation

/// Typed wrapper over `UserDefaults`. Keys live with the feature that owns them, so a
/// renamed setting fails at compile time instead of silently reading stale data.
struct KeyValueStore: @unchecked Sendable {
    // UserDefaults is documented as safe for concurrent use, which is what lets the
    // wrapper stay a value type over a reference to the shared suite.
    struct Key<T: Codable & Sendable>: Sendable {
        let name: String
        let defaultValue: T

        init(_ name: String, default: T) {
            self.name = name
            self.defaultValue = `default`
        }
    }

    enum BoolKey {
        static let hasCompletedOnboarding = Key<Bool>("onboarding.completed", default: false)
    }

    enum StringKey {
        static let lastSyncedAt = Key<String>("sync.lastDate", default: "")
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    subscript<T: Codable & Sendable>(key: Key<T>) -> T {
        get { read(key) }
        // Writes land in the backing suite, not in the value itself.
        nonmutating set { write(newValue, key: key) }
    }

    func read<T: Codable & Sendable>(_ key: Key<T>) -> T {
        guard let raw = defaults.data(forKey: key.name) else { return key.defaultValue }
        return (try? JSONDecoder().decode(T.self, from: raw)) ?? key.defaultValue
    }

    func write<T: Codable & Sendable>(_ value: T, key: Key<T>) {
        guard let raw = try? JSONEncoder().encode(value) else { return }
        defaults.set(raw, forKey: key.name)
    }

    func clear<T: Codable & Sendable>(_ key: Key<T>) {
        defaults.removeObject(forKey: key.name)
    }
}

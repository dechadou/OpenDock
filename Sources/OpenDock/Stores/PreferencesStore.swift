import Combine
import Foundation

@MainActor
public final class PreferencesStore: ObservableObject {
    public nonisolated static let defaultKey = AppIdentity.preferencesKey

    @Published public var preferences: SidebarPreferences {
        didSet {
            save()
        }
    }

    private let defaults: UserDefaults
    private let key: String
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(defaults: UserDefaults = .standard, key: String = PreferencesStore.defaultKey) {
        self.defaults = defaults
        self.key = key

        if let data = defaults.data(forKey: key),
            let decoded = try? decoder.decode(SidebarPreferences.self, from: data)
        {
            self.preferences = decoded
        } else {
            self.preferences = .defaults
        }
    }

    public func update(_ transform: (inout SidebarPreferences) -> Void) {
        var copy = preferences
        transform(&copy)
        preferences = copy
    }

    public func reset() {
        preferences = .defaults
    }

    private func save() {
        guard let data = try? encoder.encode(preferences) else {
            return
        }

        defaults.set(data, forKey: key)
    }
}

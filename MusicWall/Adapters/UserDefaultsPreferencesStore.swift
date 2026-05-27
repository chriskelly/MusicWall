import Foundation

struct UserDefaultsPreferencesStore: PreferencesStore, @unchecked Sendable {
    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults) {
        self.userDefaults = userDefaults
    }

    func save<T: Encodable>(_ value: T, for key: PreferencesKey) {
        guard let encoded = try? JSONEncoder().encode(value) else { return }
        userDefaults.set(encoded, forKey: key.rawValue)
    }

    func load<T: Decodable>(_ type: T.Type, for key: PreferencesKey) -> T? {
        guard let data = userDefaults.data(forKey: key.rawValue) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}

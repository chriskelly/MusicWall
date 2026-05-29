import Foundation
@testable import MusicWall

final class InMemoryPreferencesStore: PreferencesStore, @unchecked Sendable {
    private var storage: [PreferencesKey: Data] = [:]

    func save<T: Encodable>(_ value: T, for key: PreferencesKey) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        storage[key] = data
    }

    func load<T: Decodable>(_ type: T.Type, for key: PreferencesKey) -> T? {
        guard let data = storage[key] else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    func setRaw(_ data: Data, for key: PreferencesKey) {
        storage[key] = data
    }
}

import Foundation

protocol PreferencesStore: Sendable {
    func save<T: Encodable>(_ value: T, for key: PreferencesKey)
    func load<T: Decodable>(_ type: T.Type, for key: PreferencesKey) -> T?
}

import Foundation

struct AppDependencies {
    let preferencesStore: PreferencesStore

    static let live = AppDependencies(
        preferencesStore: UserDefaultsPreferencesStore(userDefaults: .standard)
    )

    static func preview() -> AppDependencies {
        let suiteName = "com.musicwall.preview.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        return AppDependencies(
            preferencesStore: UserDefaultsPreferencesStore(userDefaults: defaults)
        )
    }
}

import Foundation

struct AppDependencies {
    let preferencesStore: PreferencesStore
    let albumRepository: any AlbumRepository
    let artworkProvider: any ArtworkProvider
    let playbackController: any PlaybackController
    let albumBackupService: any AlbumBackupService
    let musicAuthorization: any MusicAuthorizationProviding

    static let live: AppDependencies = {
        let repository = MusicKitAlbumRepository()
        return AppDependencies(
            preferencesStore: UserDefaultsPreferencesStore(userDefaults: .standard),
            albumRepository: repository,
            artworkProvider: MusicKitArtworkProvider(repository: repository),
            playbackController: SystemMusicPlayerAdapter(repository: repository),
            albumBackupService: LiveAlbumBackupService(),
            musicAuthorization: LiveMusicAuthorizationProvider()
        )
    }()

    static func preview() -> AppDependencies {
        let suiteName = "com.musicwall.preview.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        return AppDependencies(
            preferencesStore: UserDefaultsPreferencesStore(userDefaults: defaults),
            albumRepository: PreviewAlbumRepository(),
            artworkProvider: PreviewArtworkProvider(),
            playbackController: PreviewPlaybackController(),
            albumBackupService: LiveAlbumBackupService(),
            musicAuthorization: PreviewMusicAuthorizationProvider(status: .authorized)
        )
    }

    static func uiTest(scenario: UITestLoadScenario) -> AppDependencies {
        let suiteName = "com.musicwall.uitest.\(scenario.rawValue).\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let preferences = UserDefaultsPreferencesStore(userDefaults: defaults)
        let playback = UITestPlaybackController()
        let repository = UITestAlbumRepository()

        switch scenario {
        case .savedLibrary:
            preferences.save(UITestFixtures.baseTrio, for: .albumRecordsItems)
        case .restoreFromBackup:
            preferences.save(UITestFixtures.backupIDs, for: .backupAlbumIDs)
        }

        return AppDependencies(
            preferencesStore: preferences,
            albumRepository: repository,
            artworkProvider: PreviewArtworkProvider(),
            playbackController: playback,
            albumBackupService: LiveAlbumBackupService(),
            musicAuthorization: PreviewMusicAuthorizationProvider(status: .authorized)
        )
    }
}

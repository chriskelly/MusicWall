import Foundation

struct AppDependencies {
    let preferencesStore: PreferencesStore
    let albumRepository: any AlbumRepository
    let playbackController: any PlaybackController
    let albumBackupService: any AlbumBackupService

    static let live: AppDependencies = {
        let repository = MusicKitAlbumRepository()
        return AppDependencies(
            preferencesStore: UserDefaultsPreferencesStore(userDefaults: .standard),
            albumRepository: repository,
            playbackController: SystemMusicPlayerAdapter(repository: repository),
            albumBackupService: LiveAlbumBackupService()
        )
    }()

    static func preview() -> AppDependencies {
        let suiteName = "com.musicwall.preview.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        return AppDependencies(
            preferencesStore: UserDefaultsPreferencesStore(userDefaults: defaults),
            albumRepository: PreviewAlbumRepository(),
            playbackController: PreviewPlaybackController(),
            albumBackupService: LiveAlbumBackupService()
        )
    }
}

import Testing
@testable import MusicWall

struct SmokeTests {
    @Test
    func appDependenciesLiveConstructs() {
        let dependencies = AppDependencies.live
        _ = dependencies.preferencesStore
        _ = dependencies.albumRepository
        _ = dependencies.playbackController
        _ = dependencies.albumBackupService
        _ = dependencies.musicAuthorization
        #expect(true)
    }

    @Test
    func appDependenciesPreviewConstructs() {
        let dependencies = AppDependencies.preview()
        _ = dependencies.musicAuthorization
        #expect(true)
    }
}

import Testing
@testable import MusicWall

struct SmokeTests {
    @Test
    func appDependenciesLiveConstructs() {
        let dependencies = AppDependencies.live
        _ = dependencies.preferencesStore
        _ = dependencies.albumRepository
        _ = dependencies.playbackController
        #expect(true)
    }
}

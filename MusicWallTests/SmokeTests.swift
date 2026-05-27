import Testing
@testable import MusicWall

struct SmokeTests {
    @Test
    func appDependenciesLiveConstructs() {
        let dependencies = AppDependencies.live
        _ = dependencies.preferencesStore
        #expect(true)
    }
}

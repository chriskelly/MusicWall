import Foundation
import Testing
@testable import MusicWall

struct CarPlayConnectPlannerTests {
    @Test
    func unauthorized_returnsSetupRequired() {
        let screen = CarPlayConnectPlanner.rootScreen(
            authorizationStatus: .denied,
            albums: AlbumFixtures.baseTrio
        )
        #expect(screen == .setupRequired)
    }

    @Test
    func authorizedEmptyLibrary_returnsSetupRequired() {
        let screen = CarPlayConnectPlanner.rootScreen(
            authorizationStatus: .authorized,
            albums: []
        )
        #expect(screen == .setupRequired)
    }

    @Test
    func authorizedWithAlbums_returnsAlbumLibrary() {
        let albums = AlbumFixtures.baseTrio
        let screen = CarPlayConnectPlanner.rootScreen(
            authorizationStatus: .authorized,
            albums: albums
        )
        #expect(screen == .albumLibrary(albums: albums))
    }
}

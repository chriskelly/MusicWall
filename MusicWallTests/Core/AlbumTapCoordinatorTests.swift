import Foundation
import Testing
@testable import MusicWall

@Suite struct AlbumTapCoordinatorTests {
    @Test func deselectPausesAndClearsSelection() async {
        let playback = MockPlaybackController()
        let albumID = AlbumID(rawValue: "album-1")

        let selected = await AlbumTapCoordinator.handleTap(
            albumID: albumID,
            rawSelectedID: "album-1",
            playback: playback
        )

        #expect(playback.pauseCallCount == 1)
        #expect(playback.playCalls.isEmpty)
        #expect(selected == nil)
    }

    @Test func newSelectionPlaysAlbum() async {
        let playback = MockPlaybackController()
        let albumID = AlbumID(rawValue: "album-2")

        let selected = await AlbumTapCoordinator.handleTap(
            albumID: albumID,
            rawSelectedID: nil,
            playback: playback
        )

        #expect(playback.playCalls == [albumID])
        #expect(selected == "album-2")
    }
}

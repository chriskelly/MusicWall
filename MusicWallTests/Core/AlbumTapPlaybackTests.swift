import Foundation
import Testing
@testable import MusicWall

@Suite struct AlbumTapPlaybackTests {
    @Test func deselectPausesAndClearsSelection() async {
        let playback = MockPlaybackController()
        let albumID = AlbumID(rawValue: "album-1")
        var selected: String? = "album-1"

        await AlbumTapPlayback.handleTap(
            albumID: albumID,
            rawSelectedID: selected,
            setSelected: { selected = $0 },
            playback: playback
        )

        #expect(playback.pauseCallCount == 1)
        #expect(playback.playCalls.isEmpty)
        #expect(selected == nil)
    }

    @Test func newSelectionPlaysAlbum() async {
        let playback = MockPlaybackController()
        let albumID = AlbumID(rawValue: "album-2")
        var selected: String? = nil

        await AlbumTapPlayback.handleTap(
            albumID: albumID,
            rawSelectedID: selected,
            setSelected: { selected = $0 },
            playback: playback
        )

        #expect(playback.playCalls == [albumID])
        #expect(selected == "album-2")
    }
}

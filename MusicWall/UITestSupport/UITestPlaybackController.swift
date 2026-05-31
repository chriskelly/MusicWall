import Foundation
import Observation

@Observable
final class UITestPlaybackController: PlaybackController, @unchecked Sendable {
    private(set) var lastPlayedAlbumID: String = ""

    func play(albumId: AlbumID) async throws {
        lastPlayedAlbumID = albumId.rawValue
    }

    func pause() {}
}

import Foundation

final class UITestPlaybackController: PlaybackController, @unchecked Sendable {
    func play(albumId: AlbumID) async throws {}

    func pause() {}
}

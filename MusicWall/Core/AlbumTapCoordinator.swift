import Foundation

enum AlbumTapCoordinator {
    static func handleTap(
        albumID: AlbumID,
        rawSelectedID: String?,
        playback: any PlaybackController
    ) async -> String? {
        let rawAlbumID = albumID.rawValue
        if rawSelectedID == rawAlbumID {
            playback.pause()
            return nil
        } else {
            _ = try? await playback.play(albumId: albumID)
            return rawAlbumID
        }
    }
}

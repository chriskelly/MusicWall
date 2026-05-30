import Foundation

enum AlbumTapCoordinator {
    static func handleTap(
        albumID: AlbumID,
        rawSelectedID: String?,
        setSelected: @MainActor (String?) -> Void,
        playback: any PlaybackController
    ) async {
        let rawAlbumID = albumID.rawValue
        if rawSelectedID == rawAlbumID {
            playback.pause()
            await setSelected(nil)
        } else {
            await setSelected(rawAlbumID)
            _ = try? await playback.play(albumId: albumID)
        }
    }
}

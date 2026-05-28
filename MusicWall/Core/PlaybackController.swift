import Foundation

enum PlaybackError: Error, LocalizedError, Equatable {
    case albumNotFound
    case playbackFailed(String)

    var errorDescription: String? {
        switch self {
        case .albumNotFound:
            return "Album not found"
        case .playbackFailed(let message):
            return "Playback failed: \(message)"
        }
    }
}

protocol PlaybackController: Sendable {
    func play(albumId: AlbumID) async throws
    func pause()
}

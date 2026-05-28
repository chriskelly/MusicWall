import Foundation
import MusicKit

struct SystemMusicPlayerAdapter: PlaybackController, Sendable {
    let repository: MusicKitAlbumRepository

    func play(albumId: AlbumID) async throws {
        do {
            let album = try await repository.musicKitAlbum(for: albumId)
            let player = SystemMusicPlayer.shared
            player.queue = [album]
            try await player.play()
        } catch let error as AlbumRepositoryError {
            if case .albumNotFound = error {
                throw PlaybackError.albumNotFound
            }
            throw PlaybackError.playbackFailed(error.localizedDescription)
        } catch let error as PlaybackError {
            throw error
        } catch {
            throw PlaybackError.playbackFailed(error.localizedDescription)
        }
    }

    func pause() {
        SystemMusicPlayer.shared.pause()
    }
}

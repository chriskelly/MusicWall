import SwiftUI

private struct UnimplementedAlbumRepository: AlbumRepository {
    func search(query: String, source: AlbumSearchSource) async throws -> [AlbumRecord] {
        preconditionFailure("albumRepository not installed — set .environment(\\.albumRepository, ...)")
    }

    func fetch(ids: [AlbumID]) async throws -> [AlbumRecord] {
        preconditionFailure("albumRepository not installed")
    }
}

private struct UnimplementedPlaybackController: PlaybackController {
    func play(albumId: AlbumID) async throws {
        preconditionFailure("playback not installed")
    }

    func pause() {
        preconditionFailure("playback not installed")
    }
}

private struct UnimplementedArtworkProvider: ArtworkProvider {
    func artworkURL(for id: AlbumID, width: Int, height: Int) async -> URL? {
        preconditionFailure("artworkProvider not installed — set .environment(\\.artworkProvider, ...)")
    }
}

extension EnvironmentValues {
    @Entry var albumRepository: any AlbumRepository = UnimplementedAlbumRepository()
    @Entry var playback: any PlaybackController = UnimplementedPlaybackController()
    @Entry var artworkProvider: any ArtworkProvider = UnimplementedArtworkProvider()
}

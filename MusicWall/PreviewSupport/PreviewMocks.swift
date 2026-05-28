import Foundation

struct PreviewAlbumRepository: AlbumRepository {
    func search(query: String, source: AlbumSearchSource) async throws -> [AlbumRecord] { [] }
    func fetch(ids: [AlbumID]) async throws -> [AlbumRecord] { [] }
    func artworkURL(for id: AlbumID, width: Int, height: Int) async -> URL? { nil }
}

struct PreviewPlaybackController: PlaybackController {
    func play(albumId: AlbumID) async throws {}
    func pause() {}
}

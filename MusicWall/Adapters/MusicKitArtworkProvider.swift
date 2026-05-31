import Foundation
import MusicKit

struct MusicKitArtworkProvider: ArtworkProvider, Sendable {
    let repository: MusicKitAlbumRepository

    func artworkURL(for id: AlbumID, width: Int, height: Int) async -> URL? {
        guard let album = try? await repository.musicKitAlbum(for: id) else { return nil }
        return album.artwork?.url(width: width, height: height)
    }
}

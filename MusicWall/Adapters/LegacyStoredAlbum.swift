import Foundation
import MusicKit

/// Decodes pre-PR-6 `StoredAlbum` JSON from `savedAlbumsItemsKey`. Not used in UI.
struct LegacyStoredAlbum: Codable {
    let id: MusicItemID
    let title: String
    let artistName: String
    let releaseDate: Date?

    func asAlbumRecord() -> AlbumRecord {
        AlbumRecord(
            id: AlbumID(rawValue: id.rawValue),
            title: title,
            artistName: artistName,
            releaseDate: releaseDate,
            isExplicit: false
        )
    }
}

import Foundation
import MusicKit

enum AlbumMapper {
    static func record(from album: MusicKit.Album) -> AlbumRecord {
        AlbumRecord(
            id: AlbumID(rawValue: album.id.rawValue),
            title: album.title,
            artistName: album.artistName,
            releaseDate: album.releaseDate,
            isExplicit: album.contentRating == .explicit
        )
    }
}

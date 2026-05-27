import Foundation
import MusicKit

extension StoredAlbum {
    var asAlbumRecord: AlbumRecord {
        AlbumRecord(
            id: AlbumID(rawValue: id.rawValue),
            title: title,
            artistName: artistName,
            releaseDate: releaseDate
        )
    }
}

extension StoredAlbums.SortOptions {
    var albumSortKey: AlbumSortKey {
        switch self {
        case .artist: .artist
        case .title: .title
        case .date: .year
        }
    }
}

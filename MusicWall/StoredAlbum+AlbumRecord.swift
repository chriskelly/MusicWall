import Foundation
import MusicKit

extension StoredAlbum {
    init(from record: AlbumRecord) {
        self.id = MusicItemID(record.id.rawValue)
        self.title = record.title
        self.artistName = record.artistName
        self.releaseDate = record.releaseDate
    }

    var asAlbumRecord: AlbumRecord {
        AlbumRecord(
            id: AlbumID(rawValue: id.rawValue),
            title: title,
            artistName: artistName,
            releaseDate: releaseDate,
            isExplicit: false
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

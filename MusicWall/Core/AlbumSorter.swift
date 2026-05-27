import Foundation

enum AlbumSorter {
    static func sorted(
        _ albums: [AlbumRecord],
        key: AlbumSortKey,
        ascending: Bool
    ) -> [AlbumRecord] {
        var copy = albums
        switch key {
        case .artist:
            if ascending {
                copy.sort { $0.artistName.lowercased() < $1.artistName.lowercased() }
            } else {
                copy.sort { $0.artistName.lowercased() > $1.artistName.lowercased() }
            }
        case .title:
            if ascending {
                copy.sort { $0.title.lowercased() < $1.title.lowercased() }
            } else {
                copy.sort { $0.title.lowercased() > $1.title.lowercased() }
            }
        case .year:
            if ascending {
                copy.sort { ($0.releaseDate ?? Date.distantFuture) < ($1.releaseDate ?? Date.distantFuture) }
            } else {
                copy.sort { ($0.releaseDate ?? Date.distantPast) > ($1.releaseDate ?? Date.distantPast) }
            }
        }
        return copy
    }
}

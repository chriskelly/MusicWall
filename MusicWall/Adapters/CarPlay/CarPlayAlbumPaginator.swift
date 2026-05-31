import Foundation

enum CarPlayAlbumPaginator {
    static let defaultPageSize = 8

    static func pages(from albums: [AlbumRecord], pageSize: Int = defaultPageSize) -> [[AlbumRecord]] {
        guard pageSize > 0, !albums.isEmpty else { return [] }
        return stride(from: 0, to: albums.count, by: pageSize).map { start in
            Array(albums[start..<min(start + pageSize, albums.count)])
        }
    }
}

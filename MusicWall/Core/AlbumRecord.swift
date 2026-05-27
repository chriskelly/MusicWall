import Foundation

struct AlbumRecord: Equatable, Sendable {
    let id: AlbumID
    let title: String
    let artistName: String
    let releaseDate: Date?
}

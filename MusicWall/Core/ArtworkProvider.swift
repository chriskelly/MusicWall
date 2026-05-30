import Foundation

protocol ArtworkProvider: Sendable {
    func artworkURL(for id: AlbumID, width: Int, height: Int) async -> URL?
}

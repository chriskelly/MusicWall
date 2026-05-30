import Foundation
@testable import MusicWall

final class MockArtworkProvider: ArtworkProvider, @unchecked Sendable {
    var artworkURLHandler: ((AlbumID, Int, Int) async -> URL?)?
    private(set) var artworkURLCalls: [(AlbumID, Int, Int)] = []

    func artworkURL(for id: AlbumID, width: Int, height: Int) async -> URL? {
        artworkURLCalls.append((id, width, height))
        if let artworkURLHandler { return await artworkURLHandler(id, width, height) }
        return nil
    }
}

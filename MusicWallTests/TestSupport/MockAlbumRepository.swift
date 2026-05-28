import Foundation
@testable import MusicWall

final class MockAlbumRepository: AlbumRepository, @unchecked Sendable {
    var searchHandler: ((String, AlbumSearchSource) async throws -> [AlbumRecord])?
    var fetchHandler: (([AlbumID]) async throws -> [AlbumRecord])?
    var artworkURLHandler: ((AlbumID, Int, Int) async -> URL?)?

    private(set) var searchCalls: [(String, AlbumSearchSource)] = []
    private(set) var fetchCalls: [[AlbumID]] = []

    func search(query: String, source: AlbumSearchSource) async throws -> [AlbumRecord] {
        searchCalls.append((query, source))
        if let searchHandler { return try await searchHandler(query, source) }
        return []
    }

    func fetch(ids: [AlbumID]) async throws -> [AlbumRecord] {
        fetchCalls.append(ids)
        if let fetchHandler { return try await fetchHandler(ids) }
        return []
    }

    func artworkURL(for id: AlbumID, width: Int, height: Int) async -> URL? {
        if let artworkURLHandler { return await artworkURLHandler(id, width, height) }
        return nil
    }
}

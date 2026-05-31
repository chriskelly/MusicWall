import Foundation
@testable import MusicWall

final class MockAlbumRepository: AlbumRepository, @unchecked Sendable {
    var searchHandler: ((String, AlbumSearchSource) async throws -> [AlbumRecord])?
    var fetchHandler: (([AlbumID]) async throws -> [AlbumRecord])?

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
}

import Foundation
@testable import MusicWall

final class MockAlbumRepository: AlbumRepository, @unchecked Sendable {
    var searchHandler: ((String, AlbumSearchSource) async throws -> [AlbumRecord])?
    var fetchHandler: (([AlbumID]) async throws -> [AlbumRecord])?

    private let lock = NSLock()
    private var recordedSearchCalls: [(String, AlbumSearchSource)] = []
    private var recordedFetchCalls: [[AlbumID]] = []

    /// `catalog` and `library` searches run concurrently, so recording is lock-protected
    /// to keep these call lists complete and readable from the test actor. The handlers are
    /// set by the test before any search starts and are not mutated while requests run.
    var searchCalls: [(String, AlbumSearchSource)] {
        lock.withLock { recordedSearchCalls }
    }

    var fetchCalls: [[AlbumID]] {
        lock.withLock { recordedFetchCalls }
    }

    func search(query: String, source: AlbumSearchSource) async throws -> [AlbumRecord] {
        lock.withLock { recordedSearchCalls.append((query, source)) }

        if let searchHandler { return try await searchHandler(query, source) }
        return []
    }

    func fetch(ids: [AlbumID]) async throws -> [AlbumRecord] {
        lock.withLock { recordedFetchCalls.append(ids) }

        if let fetchHandler { return try await fetchHandler(ids) }
        return []
    }
}

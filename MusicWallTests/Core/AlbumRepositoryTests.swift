import Foundation
import Testing
@testable import MusicWall

@Suite struct AlbumRepositoryTests {
    @Test func searchEmptyQueryThrowsInvalidQuery() async {
        let repo = MockAlbumRepository()
        repo.searchHandler = { _, _ in throw AlbumRepositoryError.invalidQuery }

        await #expect(throws: AlbumRepositoryError.invalidQuery) {
            _ = try await repo.search(query: "", source: .catalog)
        }
    }

    @Test func fetchEmptyIDsReturnsEmpty() async throws {
        let repo = MockAlbumRepository()
        let result = try await repo.fetch(ids: [])
        #expect(result.isEmpty)
        #expect(repo.fetchCalls == [[]])
    }

    @Test func searchRecordsSource() async throws {
        let repo = MockAlbumRepository()
        repo.searchHandler = { _, _ in
            [AlbumFixtures.record(id: "a", title: "T", artistName: "A")]
        }

        _ = try await repo.search(query: "drake", source: .library)
        #expect(repo.searchCalls.count == 1)
        #expect(repo.searchCalls[0].0 == "drake")
        #expect(repo.searchCalls[0].1 == .library)
    }
}

import Foundation
import Testing
@testable import MusicWall

struct AlbumStoreImportTests {
    @Test @MainActor
    func reimportExistingIDsDoesNotFetchOrDuplicate() async throws {
        let preferences = InMemoryPreferencesStore()
        let repository = MockAlbumRepository()
        repository.fetchHandler = { ids in
            ids.map { id in
                AlbumFixtures.record(
                    id: "normalized-\(id.rawValue)",
                    title: "Fetched",
                    artistName: "Artist"
                )
            }
        }

        let store = AlbumStore(preferences: preferences, repository: repository)
        store.addAlbum(AlbumFixtures.record(id: "foo", title: "Album", artistName: "Artist"))

        try await store.importAlbums(from: ["foo"])

        #expect(store.items.count == 1)
        #expect(store.items[0].id.rawValue == "foo")
        #expect(repository.fetchCalls.isEmpty)
    }

    @Test @MainActor
    func importOnlyFetchesMissingIDs() async throws {
        let preferences = InMemoryPreferencesStore()
        let repository = MockAlbumRepository()
        repository.fetchHandler = { ids in
            ids.map { id in
                AlbumFixtures.record(id: id.rawValue, title: "Fetched", artistName: "Artist")
            }
        }

        let store = AlbumStore(preferences: preferences, repository: repository)
        store.addAlbum(AlbumFixtures.record(id: "foo", title: "Album", artistName: "Artist"))

        try await store.importAlbums(from: ["foo", "bar"])

        #expect(repository.fetchCalls == [[AlbumID(rawValue: "bar")]])
        #expect(store.items.count == 2)
        #expect(store.items.map(\.id.rawValue).sorted() == ["bar", "foo"])
    }
}

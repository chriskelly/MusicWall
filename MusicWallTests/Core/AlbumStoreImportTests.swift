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

    @Test @MainActor
    func importBackupRecordsAddsWithoutFetch() async throws {
        let preferences = InMemoryPreferencesStore()
        let repository = MockAlbumRepository()
        repository.fetchHandler = { _ in
            Issue.record("fetch should not be called for v2 record import")
            return []
        }

        let store = AlbumStore(preferences: preferences, repository: repository)
        let edited = AlbumFixtures.record(
            id: "edited-1",
            title: "Local Title",
            artistName: "Local Artist",
            releaseDate: AlbumFixtures.utcDate(year: 1999, month: 1, day: 1)
        )

        try await store.importBackup(.records([edited]))

        #expect(repository.fetchCalls.isEmpty)
        #expect(store.items.count == 1)
        #expect(store.items[0] == edited)
    }

    @Test @MainActor
    func importBackupRecordsSkipsExistingAlbums() async throws {
        let preferences = InMemoryPreferencesStore()
        let repository = MockAlbumRepository()
        let store = AlbumStore(preferences: preferences, repository: repository)
        let existing = AlbumFixtures.record(id: "dup", title: "Keep Me", artistName: "Local")
        store.addAlbum(existing)

        let fromBackup = AlbumFixtures.record(id: "dup", title: "Overwrite?", artistName: "Backup")
        let newAlbum = AlbumFixtures.record(id: "new", title: "New", artistName: "Artist")

        try await store.importBackup(.records([fromBackup, newAlbum]))

        #expect(repository.fetchCalls.isEmpty)
        #expect(store.items.count == 2)
        #expect(store.items.first { $0.id.rawValue == "dup" } == existing)
        #expect(store.items.first { $0.id.rawValue == "new" } == newAlbum)
    }

    @Test @MainActor
    func importBackupIdsDelegatesToFetchPath() async throws {
        let preferences = InMemoryPreferencesStore()
        let repository = MockAlbumRepository()
        repository.fetchHandler = { ids in
            ids.map { AlbumFixtures.record(id: $0.rawValue, title: "Fetched", artistName: "Artist") }
        }

        let store = AlbumStore(preferences: preferences, repository: repository)
        try await store.importBackup(.ids(["fetched-1"]))

        #expect(repository.fetchCalls == [[AlbumID(rawValue: "fetched-1")]])
        #expect(store.items.count == 1)
        #expect(store.items[0].title == "Fetched")
    }
}

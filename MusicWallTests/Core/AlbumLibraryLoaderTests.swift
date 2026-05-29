import Foundation
import Testing
@testable import MusicWall

struct AlbumLibraryLoaderTests {
    @Test
    func loadsFromNewKeyWhenPresent() async {
        let prefs = InMemoryPreferencesStore()
        let expected = [AlbumFixtures.record(id: "a", title: "A", artistName: "X")]
        prefs.save(expected, for: .albumRecordsItems)

        let result = await AlbumLibraryLoader.load(
            preferences: prefs,
            repository: MockAlbumRepository()
        )

        #expect(result.records == expected)
        #expect(result.shouldPersistCanonical == false)
    }

    @Test
    func migratesLegacyFixtureAndFlagsPersist() async throws {
        let prefs = InMemoryPreferencesStore()
        prefs.setRaw(try legacyFixtureData(), for: .storedAlbumsItems)

        let result = await AlbumLibraryLoader.load(
            preferences: prefs,
            repository: MockAlbumRepository()
        )

        #expect(result.records.count == 2)
        #expect(result.records[1].title == "Edited Title")
        #expect(result.records.allSatisfy { !$0.isExplicit })
        #expect(result.shouldPersistCanonical == true)
    }

    @Test
    func legacyMigrateWritesNewKey() async throws {
        let prefs = InMemoryPreferencesStore()
        prefs.setRaw(try legacyFixtureData(), for: .storedAlbumsItems)

        let collection = AlbumCollection(
            persistItems: { prefs.save($0, for: .albumRecordsItems) },
            persistBackupIDs: { prefs.save($0, for: .backupAlbumIDs) }
        )

        let result = await AlbumLibraryLoader.load(
            preferences: prefs,
            repository: MockAlbumRepository()
        )
        collection.performWithoutPersist {
            collection.replaceAll(result.records, persist: false)
        }
        if result.shouldPersistCanonical {
            collection.replaceAll(collection.items, persist: true)
        }

        let saved = prefs.load([AlbumRecord].self, for: .albumRecordsItems)
        #expect(saved?.count == 2)
        #expect(prefs.load([LegacyStoredAlbum].self, for: .storedAlbumsItems)?.count == 2)
    }

    @Test
    func hydratesFromBackupWhenCanonicalAndLegacyEmpty() async {
        let prefs = InMemoryPreferencesStore()
        prefs.save(["id-1", "id-2"], for: .backupAlbumIDs)

        let repo = MockAlbumRepository()
        repo.fetchHandler = { ids in
            ids.map { AlbumFixtures.record(id: $0.rawValue, title: "T", artistName: "A") }
        }

        let result = await AlbumLibraryLoader.load(preferences: prefs, repository: repo)

        #expect(result.records.count == 2)
        #expect(result.shouldPersistCanonical == true)
        #expect(repo.fetchCalls.count == 1)
    }

    @Test
    func fetchThrowsLeavesEmpty() async {
        let prefs = InMemoryPreferencesStore()
        prefs.save(["id-1"], for: .backupAlbumIDs)

        let repo = MockAlbumRepository()
        repo.fetchHandler = { _ in throw AlbumRepositoryError.networkError("offline") }

        let result = await AlbumLibraryLoader.load(preferences: prefs, repository: repo)

        #expect(result.records.isEmpty)
        #expect(result.shouldPersistCanonical == false)
    }

    @Test
    func partialFetchReturnsSubset() async {
        let prefs = InMemoryPreferencesStore()
        prefs.save(["id-1", "id-missing"], for: .backupAlbumIDs)

        let repo = MockAlbumRepository()
        repo.fetchHandler = { ids in
            ids
                .filter { $0.rawValue == "id-1" }
                .map { AlbumFixtures.record(id: $0.rawValue, title: "T", artistName: "A") }
        }

        let result = await AlbumLibraryLoader.load(preferences: prefs, repository: repo)

        #expect(result.records.count == 1)
        #expect(result.records[0].id.rawValue == "id-1")
    }
}

private func legacyFixtureData() throws -> Data {
    if let url = Bundle(for: BundleToken.self).url(
        forResource: "legacy_stored_albums_v1",
        withExtension: "json"
    ),
        let bundled = try? Data(contentsOf: url),
        !bundled.isEmpty,
        bundled != Data("[]".utf8) {
        return bundled
    }
    return try LegacyFixtureTests.sampleLegacyFixtureData()
}

private final class BundleToken {}

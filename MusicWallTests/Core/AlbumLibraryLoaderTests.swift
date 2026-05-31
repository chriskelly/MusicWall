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
    func hydratesFromBackupWhenCanonicalEmpty() async {
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

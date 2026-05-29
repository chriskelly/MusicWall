import Foundation
import MusicKit
import Testing
@testable import MusicWall

struct UserDefaultsPreferencesStoreTests {
    private func makeStore() -> (UserDefaultsPreferencesStore, String) {
        let suiteName = "test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        return (UserDefaultsPreferencesStore(userDefaults: defaults), suiteName)
    }

    @Test
    func roundTripAlbumRecordsItems() {
        let (store, suiteName) = makeStore()
        defer { UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName) }

        let albums = [
            AlbumFixtures.record(
                id: "fixture-round-trip",
                title: "Take Care",
                artistName: "Drake",
                isExplicit: true
            ),
        ]
        store.save(albums, for: .albumRecordsItems)
        let loaded = store.load([AlbumRecord].self, for: .albumRecordsItems)
        #expect(loaded == albums)
    }

    @Test
    func roundTripLegacyStoredAlbumsItems() {
        let (store, suiteName) = makeStore()
        defer { UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName) }

        let legacy = [
            LegacyStoredAlbum(
                id: MusicItemID("legacy-round-trip"),
                title: "Take Care",
                artistName: "Drake",
                releaseDate: nil
            ),
        ]
        store.save(legacy, for: .storedAlbumsItems)
        let loaded = store.load([LegacyStoredAlbum].self, for: .storedAlbumsItems)
        #expect(loaded?.count == 1)
        #expect(loaded?.first?.id.rawValue == "legacy-round-trip")
    }

    @Test
    func roundTripBackupAlbumIDs() {
        let (store, suiteName) = makeStore()
        defer { UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName) }

        let ids = ["id-a", "id-b"]
        store.save(ids, for: .backupAlbumIDs)
        #expect(store.load([String].self, for: .backupAlbumIDs) == ids)
    }

    @Test
    func roundTripSortDirection() {
        let (store, suiteName) = makeStore()
        defer { UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName) }

        let value: [AlbumStore.SortOption: Bool] = [.artist: true, .title: false]
        store.save(value, for: .sortDirection)
        #expect(store.load([AlbumStore.SortOption: Bool].self, for: .sortDirection) == value)
    }

    @Test
    func roundTripCurrentSort() {
        let (store, suiteName) = makeStore()
        defer { UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName) }

        store.save(AlbumStore.SortOption.artist, for: .currentSort)
        #expect(store.load(AlbumStore.SortOption.self, for: .currentSort) == .artist)
    }

    @Test
    func roundTripHomePageLayout() {
        let (store, suiteName) = makeStore()
        defer { UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName) }

        store.save(LayoutMenu.Option.grid, for: .homePageLayout)
        #expect(store.load(LayoutMenu.Option.self, for: .homePageLayout) == .grid)
    }

    @Test(arguments: PreferencesKey.allCases)
    func corruptDataReturnsNil(key: PreferencesKey) {
        let (store, suiteName) = makeStore()
        defer { UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName) }

        UserDefaults(suiteName: suiteName)!.set(Data([0x00, 0x01, 0x02]), forKey: key.rawValue)
        #expect(store.load(String.self, for: key) == nil)
    }
}

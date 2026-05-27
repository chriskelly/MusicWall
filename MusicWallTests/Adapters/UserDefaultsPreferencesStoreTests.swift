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
    func roundTripStoredAlbumsItems() {
        let (store, suiteName) = makeStore()
        defer { UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName) }

        let albums = [
            StoredAlbum(
                id: MusicItemID("fixture-round-trip"),
                title: "Take Care",
                artistName: "Drake",
                releaseDate: nil
            ),
        ]
        store.save(albums, for: .storedAlbumsItems)
        let loaded = store.load([StoredAlbum].self, for: .storedAlbumsItems)
        #expect(loaded?.count == 1)
        #expect(loaded?.first?.id.rawValue == "fixture-round-trip")
        #expect(loaded?.first?.title == "Take Care")
        #expect(loaded?.first?.artistName == "Drake")
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

        let value: [StoredAlbums.SortOptions: Bool] = [.artist: true, .title: false]
        store.save(value, for: .sortDirection)
        #expect(store.load([StoredAlbums.SortOptions: Bool].self, for: .sortDirection) == value)
    }

    @Test
    func roundTripCurrentSort() {
        let (store, suiteName) = makeStore()
        defer { UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName) }

        store.save(StoredAlbums.SortOptions.artist, for: .currentSort)
        #expect(store.load(StoredAlbums.SortOptions.self, for: .currentSort) == .artist)
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

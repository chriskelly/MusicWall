import Foundation
import Testing
@testable import MusicWall

/// CarPlay spec: shuffle must not persist saved album order (session-only).
@MainActor
struct CarPlayShuffleDoesNotPersistTests {
    @Test
    func shuffleDoesNotPersistSavedOrder() async {
        let preferences = UserDefaultsPreferencesStore(
            userDefaults: UserDefaults(suiteName: UUID().uuidString)!
        )
        preferences.save(AlbumFixtures.baseTrio, for: .albumRecordsItems)

        let repository = PreviewAlbumRepository()
        let store = AlbumStore(preferences: preferences, repository: repository)
        await store.load()

        let savedOrder = store.items.map(\.id)
        store.temporarilyShuffle()

        let reloadedStore = AlbumStore(preferences: preferences, repository: repository)
        await reloadedStore.load()

        #expect(reloadedStore.items.map(\.id) == savedOrder)
    }
}

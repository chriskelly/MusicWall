import Foundation
import Observation

@Observable
final class AlbumStore {
    enum SortOption: String, CaseIterable, Identifiable, Codable {
        case artist = "Artist"
        case title = "Title"
        case date = "Year"

        var id: String { rawValue }
    }

    private let preferences: PreferencesStore
    private let repository: any AlbumRepository
    private let collection: AlbumCollection

    private(set) var items: [AlbumRecord] = []

    var currentSort: SortOption = .artist {
        didSet { preferences.save(currentSort, for: .currentSort) }
    }

    var sortDirection: [SortOption: Bool] = [:] {
        didSet { preferences.save(sortDirection, for: .sortDirection) }
    }

    init(preferences: PreferencesStore, repository: any AlbumRepository) {
        self.preferences = preferences
        self.repository = repository
        self.collection = Self.makeCollection(preferences: preferences)
    }

    private static func makeCollection(preferences: PreferencesStore) -> AlbumCollection {
        AlbumCollection(
            persistItems: { records in
                preferences.save(records, for: .albumRecordsItems)
            },
            persistBackupIDs: { ids in
                preferences.save(ids, for: .backupAlbumIDs)
            }
        )
    }

    private func syncItemsFromCollection() {
        items = collection.items
    }

    @MainActor
    func load() async {
        let result = await AlbumLibraryLoader.load(
            preferences: preferences,
            repository: repository
        )
        collection.performWithoutPersist {
            collection.replaceAll(result.records, persist: false)
        }
        if result.shouldPersistCanonical {
            collection.replaceAll(collection.items, persist: true)
        }
        loadSort()
        syncItemsFromCollection()
    }

    private func loadSort() {
        sortDirection = preferences.load([SortOption: Bool].self, for: .sortDirection) ?? [:]
        currentSort = preferences.load(SortOption.self, for: .currentSort) ?? .artist
    }

    func applySort() {
        let ascending = sortDirection[currentSort] ?? true
        collection.applySort(key: currentSort.albumSortKey, ascending: ascending)
        syncItemsFromCollection()
    }

    func toggleSortDirection(for option: SortOption) {
        sortDirection[option] = !(sortDirection[option] ?? true)
    }

    func isAscending(for option: SortOption) -> Bool {
        sortDirection[option] ?? true
    }

    func addAlbum(_ record: AlbumRecord) {
        if collection.add(record) {
            applySort()
        }
    }

    func updateAlbum(_ record: AlbumRecord) {
        let existed = collection.contains(id: record.id)
        collection.update(record)
        if existed {
            applySort()
        } else {
            syncItemsFromCollection()
        }
    }

    func remove(album: AlbumRecord) {
        collection.remove(id: album.id)
        syncItemsFromCollection()
    }

    func remove(atOffsets offsets: IndexSet) {
        let ids = offsets.map { items[$0].id }
        for id in ids {
            collection.remove(id: id)
        }
        syncItemsFromCollection()
    }

    func temporarilyShuffle() {
        collection.temporarilyShuffle()
        syncItemsFromCollection()
    }

    @MainActor
    func importAlbums(from ids: [String]) async throws {
        guard !ids.isEmpty else { return }

        let albumIDs = ids.map { AlbumID(rawValue: $0) }
        let missingIDs = albumIDs.filter { !collection.contains(id: $0) }
        guard !missingIDs.isEmpty else {
            applySort()
            return
        }

        let fetched = try await repository.fetch(ids: missingIDs)
        collection.performWithoutPersist {
            for record in fetched where !collection.contains(id: record.id) {
                _ = collection.add(record)
            }
        }
        applySort()
    }

    @MainActor
    func importBackup(_ contents: BackupContents) async throws {
        switch contents {
        case .records(let records):
            collection.performWithoutPersist {
                for record in records where !collection.contains(id: record.id) {
                    _ = collection.add(record)
                }
            }
            applySort()
        case .ids(let ids):
            try await importAlbums(from: ids)
        }
    }

    static func dummyData(
        preferences: PreferencesStore,
        repository: any AlbumRepository
    ) -> AlbumStore {
        let store = AlbumStore(preferences: preferences, repository: repository)
        let samples = [
            AlbumRecord(
                id: AlbumID(rawValue: "preview-1"),
                title: "Take Care",
                artistName: "Drake",
                releaseDate: Date(),
                isExplicit: false
            ),
            AlbumRecord(
                id: AlbumID(rawValue: "preview-2"),
                title: "Born Sinners",
                artistName: "J. Cole",
                releaseDate: nil,
                isExplicit: false
            ),
            AlbumRecord(
                id: AlbumID(rawValue: "preview-3"),
                title: "Good Kid, m.A.A.d City",
                artistName: "Kendrick Lamar",
                releaseDate: Date(timeIntervalSinceNow: 500),
                isExplicit: false
            ),
        ]
        store.collection.performWithoutPersist {
            store.collection.replaceAll(samples, persist: false)
        }
        store.syncItemsFromCollection()
        return store
    }
}

extension AlbumStore.SortOption {
    var albumSortKey: AlbumSortKey {
        switch self {
        case .artist: .artist
        case .title: .title
        case .date: .year
        }
    }
}

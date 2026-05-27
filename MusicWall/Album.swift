//
//  Album.swift
//  MusicWall
//
//  Created by Chris Kelly on 10/7/25.
//

import Foundation
import MusicKit


struct StoredAlbum: Identifiable, Codable {
    let id: MusicItemID
    let title: String
    let artistName: String
    let releaseDate: Date?
    
    func play() async throws { try await MusicService.playAlbum(id: id) }
    func pause() { MusicService.pauseAlbum() }
}

extension StoredAlbum {
    init(from album:MusicKitAlbum) {
        self.id = album.id
        self.title = album.title
        self.artistName = album.artistName
        self.releaseDate = album.releaseDate
    }
}

@Observable
class StoredAlbums {
    private let preferences: PreferencesStore
    fileprivate let collection: AlbumCollection

    init(preferences: PreferencesStore) {
        self.preferences = preferences
        self.collection = Self.makeCollection(preferences: preferences)
    }

    var items = [StoredAlbum]()

    private func refreshItems() {
        items = collection.items.map { StoredAlbum(from: $0) }
    }

    private static func makeCollection(preferences: PreferencesStore) -> AlbumCollection {
        AlbumCollection(
            persistItems: { records in
                let stored = records.map { StoredAlbum(from: $0) }
                preferences.save(stored, for: .storedAlbumsItems)
            },
            persistBackupIDs: { ids in
                preferences.save(ids, for: .backupAlbumIDs)
            }
        )
    }
    
    @MainActor
    func load() async {
        await loadItems()
        loadSort()
    }
    
    private func loadItems() async {
        collection.performWithoutPersist {
            let stored = preferences.load([StoredAlbum].self, for: .storedAlbumsItems) ?? []
            collection.replaceAll(stored.map(\.asAlbumRecord), persist: false)
        }
        refreshItems()

        guard collection.items.isEmpty else { return }

        let backupIDs = preferences.load([String].self, for: .backupAlbumIDs) ?? []
        guard let albums = try? await MusicService.fetchAlbums(ids: backupIDs) else { return }

        let records = albums.map { StoredAlbum(from: $0).asAlbumRecord }
        collection.replaceAll(records, persist: true)
        refreshItems()
    }
    
    private func loadSort() {
        sortDirection = preferences.load([SortOptions: Bool].self, for: .sortDirection) ?? [:]
        currentSort = preferences.load(SortOptions.self, for: .currentSort) ?? .artist
    }
    
    enum SortOptions: String, CaseIterable, Identifiable, Codable {
        var id: String { rawValue }
        
        case artist = "Artist"
        case title = "Title"
        case date = "Year"
    }
    
    var currentSort: SortOptions = .artist {
        didSet {
            preferences.save(currentSort, for: .currentSort)
        }
    }
    var sortDirection: [SortOptions: Bool] = [:] {// true = ascending, false = descending
        didSet {
            preferences.save(sortDirection, for: .sortDirection)
        }
    }
    
    func applySort() {
        let ascending = sortDirection[currentSort] ?? true
        collection.applySort(key: currentSort.albumSortKey, ascending: ascending)
        refreshItems()
    }
    
    func toggleSortDirection(for option: SortOptions) {
        sortDirection[option] = !(sortDirection[option] ?? true)
    }
    
    func isAscending(for option: SortOptions) -> Bool {
        return sortDirection[option] ?? true
    }
    
    /// Adds album and resorts items list
    func addAlbum(_ album: StoredAlbum) {
        if collection.add(album.asAlbumRecord) {
            applySort()
        }
    }
    
    /// Updates an existing album and resorts items list
    func updateAlbum(_ album: StoredAlbum) {
        let existed = collection.contains(id: album.asAlbumRecord.id)
        collection.update(album.asAlbumRecord)
        if existed {
            applySort()
        }
    }

    func remove(album: StoredAlbum) {
        collection.remove(id: album.asAlbumRecord.id)
        refreshItems()
    }

    func remove(atOffsets offsets: IndexSet) {
        let idsToRemove = offsets.map { items[$0].asAlbumRecord.id }
        for id in idsToRemove {
            collection.remove(id: id)
        }
        refreshItems()
    }
    
    func temporarilyShuffle() {
        collection.temporarilyShuffle()
        refreshItems()
    }
    
    func exportAlbumIDs() -> [String] {
        collection.exportIDs()
    }
    
    @MainActor
    func importAlbums(from ids: [String]) async throws {
        guard !ids.isEmpty else { return }
        
        let fetchedAlbums = try await MusicService.fetchAlbums(ids: ids)
        collection.performWithoutPersist {
            for album in fetchedAlbums {
                let record = StoredAlbum(from: album).asAlbumRecord
                if !collection.contains(id: record.id) {
                    _ = collection.add(record)
                }
            }
        }
        applySort()
    }
    
    static func dummyData(preferences: PreferencesStore) -> StoredAlbums {
        let storedAlbums = StoredAlbums(preferences: preferences)
        let samples = [
            StoredAlbum(id: MusicItemID("\(UUID())"), title: "Take Care", artistName: "Drake", releaseDate: Date()),
            StoredAlbum(id: MusicItemID("\(UUID())"), title: "Born Sinners", artistName: "J. Cole", releaseDate: nil),
            StoredAlbum(id: MusicItemID("\(UUID())"), title: "Good Kid, m.A.A.d City", artistName: "Kendrick Lamar", releaseDate: Date(timeIntervalSinceNow: 500)),
        ]
        storedAlbums.collection.performWithoutPersist {
            storedAlbums.collection.replaceAll(samples.map(\.asAlbumRecord), persist: false)
        }
        storedAlbums.refreshItems()
        return storedAlbums
    }
}

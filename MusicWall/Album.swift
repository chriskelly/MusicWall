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
    private var itemsSavingLocked = false

    init(preferences: PreferencesStore) {
        self.preferences = preferences
    }
    
    var items = [StoredAlbum]() {
        didSet {
            if !itemsSavingLocked {
                preferences.save(items, for: .storedAlbumsItems)
                preferences.save(items.map { $0.id.rawValue }, for: .backupAlbumIDs)
            }
        }
    }
    
    @MainActor
    func load() async {
        await loadItems()
        loadSort()
    }
    
    private func loadItems() async {
        itemsSavingLocked = true
        items = preferences.load([StoredAlbum].self, for: .storedAlbumsItems) ?? []
        if items.isEmpty {
            let backupIDs = preferences.load([String].self, for: .backupAlbumIDs) ?? []
            if let albums = try? await MusicService.fetchAlbums(ids: backupIDs) {
                itemsSavingLocked = false
                items = albums.map { StoredAlbum(from: $0) }
            }
        }
        itemsSavingLocked = false
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
        let records = items.map(\.asAlbumRecord)
        let sortedRecords = AlbumSorter.sorted(
            records,
            key: currentSort.albumSortKey,
            ascending: ascending
        )
        let byID = Dictionary(uniqueKeysWithValues: items.map { ($0.id.rawValue, $0) })
        items = sortedRecords.compactMap { byID[$0.id.rawValue] }
    }
    
    func toggleSortDirection(for option: SortOptions) {
        sortDirection[option] = !(sortDirection[option] ?? true)
    }
    
    func isAscending(for option: SortOptions) -> Bool {
        return sortDirection[option] ?? true
    }
    
    /// Adds album and resorts items list
    func addAlbum(_ album: StoredAlbum) {
        if !items.contains(where: { $0.id == album.id }) {
            items.append(album)
            applySort()
        }
    }
    
    /// Updates an existing album and resorts items list
    func updateAlbum(_ album: StoredAlbum) {
        if let index = items.firstIndex(where: { $0.id == album.id }) {
            items[index] = album
            applySort()
        }
    }
    
    func temporarilyShuffle() {
        itemsSavingLocked = true
        items.shuffle()
        itemsSavingLocked = false
    }
    
    func exportAlbumIDs() -> [String] {
        return items.map { $0.id.rawValue }
    }
    
    @MainActor
    func importAlbums(from ids: [String]) async throws {
        guard !ids.isEmpty else { return }
        
        let fetchedAlbums = try await MusicService.fetchAlbums(ids: ids)
        let storedAlbums = fetchedAlbums.map { StoredAlbum(from: $0) }
        
        itemsSavingLocked = true
        for album in storedAlbums {
            if !items.contains(where: { $0.id == album.id }) {
                items.append(album)
            }
        }
        itemsSavingLocked = false
        applySort()
    }
    
    static func dummyData(preferences: PreferencesStore) -> StoredAlbums {
        let storedAlbums = StoredAlbums(preferences: preferences)
        storedAlbums.items = [
            StoredAlbum(id: MusicItemID("\(UUID())"), title: "Take Care", artistName: "Drake", releaseDate: Date()),
            StoredAlbum(id: MusicItemID("\(UUID())"), title: "Born Sinners", artistName: "J. Cole", releaseDate: nil),
            StoredAlbum(id: MusicItemID("\(UUID())"), title: "Good Kid, m.A.A.d City", artistName: "Kendrick Lamar", releaseDate: Date(timeIntervalSinceNow: 500)),
        ]
        return storedAlbums
    }
}


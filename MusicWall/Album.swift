//
//  Album.swift
//  MusicWall
//
//  Created by Chris Kelly on 10/7/25.
//

import Foundation
import MusicKit


struct SavedAlbum: Identifiable, Codable {
    let id: MusicItemID
    let title: String
    let artistName: String
    let releaseDate: Date?
    
    func play() async {await playAlbum(id: id)}
}

extension SavedAlbum {
    init(from album:Album) {
        self.id = album.id
        self.title = album.title
        self.artistName = album.artistName
        self.releaseDate = album.releaseDate
    }
}

@Observable
class SavedAlbums {
    private var itemsSavingLocked = false
    
    var items = [SavedAlbum]() {
        didSet {
            if !itemsSavingLocked {
                UserDefaultsManager.setData(key: .savedAlbumsItemsKey, data: items)
                UserDefaultsManager.setData(key: .backupAlbumIDsKey, data: items.map { $0.id.rawValue })
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
        items = UserDefaultsManager.loadData(
            key: .savedAlbumsItemsKey,
            type: [SavedAlbum].self
        ) ?? []
        if items.isEmpty {
            let backupIDs = UserDefaultsManager.loadData(
                key: .backupAlbumIDsKey,
                type: [String].self
            ) ?? []
            if let albums = try? await fetchAlbums(ids: backupIDs) {
                itemsSavingLocked = false
                items = albums.map { SavedAlbum(from: $0) }
            }
        }
        itemsSavingLocked = false
    }
    
    private func loadSort() {
        sortDirection = UserDefaultsManager.loadData(
            key: .sortDirectionKey,
            type: [SortOptions: Bool].self
        ) ?? [:]
        currentSort = UserDefaultsManager.loadData(
            key: .currentSortKey,
            type: SortOptions.self
        ) ?? .artist
    }
    
    enum SortOptions: String, CaseIterable, Identifiable, Codable {
        var id: String { rawValue }
        
        case artist = "Artist"
        case title = "Title"
        case date = "Year"
    }
    
    var currentSort: SortOptions = .artist {
        didSet {
            UserDefaultsManager.setData(key: .currentSortKey, data: currentSort)
        }
    }
    var sortDirection: [SortOptions: Bool] = [:] {// true = ascending, false = descending
        didSet {
            UserDefaultsManager.setData(key: .sortDirectionKey, data: sortDirection)
        }
    }
    
    func applySort() {
        let isAscending = sortDirection[currentSort] ?? true
        
        switch currentSort {
        case .artist:
            if isAscending {
                items.sort { $0.artistName.lowercased() < $1.artistName.lowercased() }
            } else {
                items.sort { $0.artistName.lowercased() > $1.artistName.lowercased() }
            }
        case .title:
            if isAscending {
                items.sort { $0.title.lowercased() < $1.title.lowercased() }
            } else {
                items.sort { $0.title.lowercased() > $1.title.lowercased() }
            }
        case .date:
            if isAscending {
                items.sort { ($0.releaseDate ?? Date.distantFuture) < ($1.releaseDate ?? Date.distantFuture) }
            } else {
                items.sort { ($0.releaseDate ?? Date.distantPast) > ($1.releaseDate ?? Date.distantPast) }
            }
        }
    }
    
    func toggleSortDirection(for option: SortOptions) {
        sortDirection[option] = !(sortDirection[option] ?? true)
    }
    
    func isAscending(for option: SortOptions) -> Bool {
        return sortDirection[option] ?? true
    }
    
    static func dummyData() -> SavedAlbums {
        let savedAlbums = SavedAlbums()
        savedAlbums.items = [
            SavedAlbum(id: MusicItemID("\(UUID())"), title: "Take Care", artistName: "Drake", releaseDate: Date()),
            SavedAlbum(id: MusicItemID("\(UUID())"), title: "Born Sinners", artistName: "J. Cole", releaseDate: nil),
            SavedAlbum(id: MusicItemID("\(UUID())"), title: "Good Kid, m.A.A.d City", artistName: "Kendrick Lamar", releaseDate: Date(timeIntervalSinceNow: 500)),
        ]
        return savedAlbums
    }
}

func fetchAlbums(ids: [String]) async throws -> [Album]? {
    guard !ids.isEmpty else { return nil }
    let ids = ids.map { MusicItemID($0) }
    let request = MusicCatalogResourceRequest<Album>(matching: \.id, memberOf: ids)
    if let response = try? await request.response() {
        return Array(response.items)
    } else {
        return nil
    }
}

func playAlbum(id: MusicItemID) async {
    do {
        let request = MusicCatalogResourceRequest<Album>(matching: \.id, equalTo: id)
        let response = try await request.response()
        if let album = response.items.first {
            let player = SystemMusicPlayer.shared
            player.queue = [album]
            try await player.play()
        }
    } catch {
        print("Playback error: \(error)")
    }
}

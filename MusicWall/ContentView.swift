//
//  ContentView.swift
//  MusicWall
//
//  Created by Chris Kelly on 8/27/25.
//

import SwiftUI
import MusicKit

struct ContentView: View {
    @State private var isAuthorized = false
    @State private var authorizationDenied = false
    
    var body: some View {
        Group {
            if isAuthorized {
                FavAlbumView(albums: SavedAlbums())
            } else if authorizationDenied {
                VStack {
                    Text("Apple Music access is required to use this app.")
                        .multilineTextAlignment(.center)
                        .padding()
                    Button("Try Again") {
                        Task {
                            await requestAuthorization()
                        }
                    }
                }
            } else {
                ProgressView("Requesting Music Access…")
            }
        }
        .task {
            await requestAuthorization()
        }
    }
    
    func requestAuthorization() async {
        let status = await MusicAuthorization.request()
        switch status {
        case .authorized:
            isAuthorized = true
        case .denied, .restricted, .notDetermined:
            isAuthorized = false
            authorizationDenied = true
        @unknown default:
            isAuthorized = false
            authorizationDenied = true
        }
    }
}

struct ArtworkURLs: Codable {
    let xSmall: URL?
    let small: URL?
    let medium: URL?
    let large: URL?
    let xLarge: URL?
}

struct SavedAlbum: Identifiable, Codable {
    let id: MusicItemID
    let title: String
    let artistName: String
    var artworkURL: ArtworkURLs
}

extension SavedAlbum {
    init(from album:Album) {
        self.id = album.id
        self.title = album.title
        self.artistName = album.artistName
        self.artworkURL = ArtworkURLs(
            xSmall: album.artwork?.url(width: 60, height: 60),
            small: album.artwork?.url(width: 120, height: 120),
            medium: album.artwork?.url(width: 240, height: 240),
            large: album.artwork?.url(width: 480, height: 480),
            xLarge: album.artwork?.url(width: 960, height: 960)
        )
    }
    init(dummyTitle: String, dummyArtist: String) {
        self.id = MusicItemID("\(UUID())")
        self.title = dummyTitle
        self.artistName = dummyArtist
        self.artworkURL = ArtworkURLs(xSmall: nil, small: nil, medium: nil, large: nil, xLarge: nil)
    }
}

@Observable
class SavedAlbums {
    let itemsKey = "savedAlbumsItemsKey"
    let backupIDsKey = "backupIDsKey"
    
    var items = [SavedAlbum]() {
        didSet {
            if let fullDataFormat = try? JSONEncoder().encode(items) {
                UserDefaults.standard.set(fullDataFormat, forKey: itemsKey)
            }
            let backupIDs = items.map { $0.id.rawValue }
            UserDefaults.standard.set(backupIDs, forKey: backupIDsKey)
        }
    }

    @MainActor
    func load() async {
        if let savedItems = UserDefaults.standard.data(forKey: itemsKey) {
            if let decoded = try? JSONDecoder().decode([SavedAlbum].self, from: savedItems) {
                items = decoded
                return
            }
        }
        if let backupIDs = UserDefaults.standard.array(forKey: backupIDsKey) as? [String] {
            if let albums = try? await fetchAlbums(ids: backupIDs) {
                items = albums.map {SavedAlbum(from: $0)}
                return
            }
        }
        items = []
    }
}

func fetchAlbums(ids: [String]) async throws -> [Album]? {
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

#Preview {
    ContentView()
}

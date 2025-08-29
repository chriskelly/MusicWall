//
//  ContentView.swift
//  Vinyl Wall
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
                FavAlbumView()
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
}

@Observable
class SavedAlbums {
    static let itemsKey = "savedAlbumsItemsKey"
    
    var items = [SavedAlbum]() {
        didSet {
            if let encoded = try? JSONEncoder().encode(items) {
                UserDefaults.standard.set(encoded, forKey: SavedAlbums.itemsKey)
            }
        }
    }
    
    init() {
        if let savedItems = UserDefaults.standard.data(forKey: SavedAlbums.itemsKey) {
            if let decoded = try? JSONDecoder().decode([SavedAlbum].self, from: savedItems) {
                items = decoded
                return
            }
        }
        items = []
    }
}

#Preview {
    ContentView()
}

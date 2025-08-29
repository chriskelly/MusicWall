//
//  ContentView.swift
//  Vinyl Wall
//
//  Created by Chris Kelly on 8/27/25.
//

import SwiftUI
import MusicKit

struct ContentView: View {
    @State private var albums = SavedAlbums()
    
    @State private var showingAddView = false
    
    @State private var isAuthorized = false
    @State private var authorizationDenied = false

        var body: some View {
            Group {
                if isAuthorized {
                    NavigationStack {
                        List {
                            ForEach(albums.items) {
                                AlbumTile(album: $0)
                            }
                            .onDelete { indexSet in
                                albums.items.remove(atOffsets: indexSet)
                            }
                        }
                        .navigationTitle("Fav Albums")
                        .toolbar {
                            Button("Add album", systemImage: "plus") {
                                showingAddView = true
                            }
                        }
                    }
                    .sheet(isPresented: $showingAddView) {
                        AlbumSearchView(onSelect: { album in
                            print(album)
                        })
                    }
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

struct AlbumTile: View {
    let album: SavedAlbum
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(album.title)
                    .font(.headline)
                Text(album.artistName)
                    .font(.footnote)
            }
            Spacer()
            if let url = album.artworkURL {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFit()
                        .frame(width: 60, height: 60)
                } placeholder: {
                    ProgressView()
                }
            } else {
                Image(systemName: "music.note")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 60, height: 60)
                    .foregroundColor(.gray)
            }
        }
    }
}

struct SavedAlbum: Identifiable, Codable {
    let id: MusicItemID
    let title: String
    let artistName: String
    var artworkURL: URL?
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

//
//  ContentView.swift
//  Vinyl Wall
//
//  Created by Chris Kelly on 8/27/25.
//

import SwiftUI

struct ContentView: View {
    @State private var albums = AlbumsPlaceholder()

        var body: some View {
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
                        albums.items.append(AlbumPlaceholder(title: "New Album", artistName: "Unknown"))
                    }
                }
            }
        }
    }

struct AlbumTile: View {
    let album: AlbumPlaceholder
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(album.title)
                    .font(.headline)
                Text(album.artistName)
                    .font(.footnote)
            }
            Spacer()
            Text(album.artworkURL)
        }
    }
}

struct AlbumPlaceholder: Identifiable, Codable {
    var id = UUID()
    let title: String
    let artistName: String
    var artworkURL = "O"
}

@Observable
class AlbumsPlaceholder {
    static let itemsKey = "itemsKey"
    
    var items = [AlbumPlaceholder]() {
        didSet {
            if let encoded = try? JSONEncoder().encode(items) {
                UserDefaults.standard.set(encoded, forKey: AlbumsPlaceholder.itemsKey)
            }
        }
    }
    
    init() {
        if let savedItems = UserDefaults.standard.data(forKey: AlbumsPlaceholder.itemsKey) {
            if let decoded = try? JSONDecoder().decode([AlbumPlaceholder].self, from: savedItems) {
                items = decoded
                return
            }
        }
        items = [
            AlbumPlaceholder(title: "Take Care", artistName: "Drake"),
            AlbumPlaceholder(title: "Born Sinner", artistName: "J. Cole")
        ]
    }
}

#Preview {
    ContentView()
}

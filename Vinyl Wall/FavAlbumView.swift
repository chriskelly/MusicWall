//
//  FavAlbumView.swift
//  Vinyl Wall
//
//  Created by Chris Kelly on 8/29/25.
//

import SwiftUI

struct FavAlbumView: View {
    @State private var albums = SavedAlbums()
    
    @State private var showingAddView = false
    
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
                    showingAddView = true
                }
            }
        }
        .sheet(isPresented: $showingAddView) {
            AlbumSearchView(onSelect: { album in
                print(album)
            })
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

#Preview {
    FavAlbumView()
}

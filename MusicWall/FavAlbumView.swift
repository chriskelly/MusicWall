//
//  FavAlbumView.swift
//  MusicWall
//
//  Created by Chris Kelly on 8/29/25.
//

import SwiftUI

struct FavAlbumView: View {
    @State var albums: SavedAlbums
    
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
                albums.items.append(SavedAlbum(from: album))
            })
        }
        .task {
            await albums.load()
        }
    }
}

struct AlbumTile: View {
    let album: SavedAlbum
    let imageSize = CGFloat(60)
    
    var body: some View {
        Button {
            Task {
                await playAlbum(id: album.id)
            }
        } label: {
            HStack {
                VStack(alignment: .leading) {
                    Text(album.title)
                        .font(.headline)
                    Text(album.artistName)
                        .font(.footnote)
                }
                Spacer()
                if let url = album.artworkURL.small {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(width: imageSize, height: imageSize)
                    } placeholder: {
                        ProgressView()
                    }
                } else {
                    Image(systemName: "music.note")
                        .resizable()
                        .scaledToFit()
                        .frame(width: imageSize, height: imageSize)
                        .foregroundColor(.gray)
                }
            }
        }
    }
}



#Preview {
    FavAlbumView(albums: SavedAlbums())
}

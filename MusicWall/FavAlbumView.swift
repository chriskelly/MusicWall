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
                Menu {
                    SortMenu(albums: albums)
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                }
                Button("Add album", systemImage: "plus") {
                    showingAddView = true
                }
            }
        }
        .sheet(isPresented: $showingAddView) {
            AlbumSearchView(onSelect: { album in
                albums.items.append(SavedAlbum(from: album))
                albums.applySort()
            })
        }
        .task {
            await albums.load()
        }
    }
}

struct SortMenu: View {
    var albums: SavedAlbums
    
    var body: some View {
        Section {
            ForEach(SavedAlbums.SortOptions.allCases) {option in
                Button {
                    if albums.currentSort == option {
                        albums.toggleSortDirection(for: option)
                    } else {
                        albums.currentSort = option
                    }
                    albums.applySort()
                } label: {
                    HStack {
                        Text(option.rawValue)
                        Spacer()
                        if albums.currentSort == option {
                            Image(systemName: albums.isAscending(for: option) ? "arrow.down" : "arrow.up")
                                .foregroundColor(.accentColor)
                        }
                    }
                }
            }
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
                AlbumArtwork(album: album, imageSize: imageSize)
            }
        }
    }
    
}

struct AlbumArtwork: View {
    let album: SavedAlbum
    let imageSize: CGFloat
    
    @State private var imageURL: URL?
    
    var body: some View {
        AsyncImage(url: imageURL) { image in
            image
                .resizable()
                .scaledToFit()
                .frame(width: imageSize, height: imageSize)
        } placeholder: {
            ProgressView()
        }
        .task {
            imageURL = await ImageCache().getArtwork(
                albumID: album.id.rawValue,
                size: Int(imageSize)
            )
        }
    }
}



#Preview {
    let savedAlbums = SavedAlbums()
    savedAlbums.items = [
        SavedAlbum(dummyTitle: "Take Care", dummyArtist: "Drake", dummyReleaseDate: Date()),
        SavedAlbum(dummyTitle: "Born Sinners", dummyArtist: "J. Cole"),
        SavedAlbum(dummyTitle: "Good Kid, m.A.A.d City", dummyArtist: "Kendrick Lamar", dummyReleaseDate: Date(timeIntervalSinceNow: 500)),
    ]
    return FavAlbumView(albums: savedAlbums)
}

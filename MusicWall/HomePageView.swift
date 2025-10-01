//
//  HomePageView.swift
//  MusicWall
//
//  Created by Chris Kelly on 8/29/25.
//

import SwiftUI

struct HomePageView: View {
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
                    withAnimation {
                        albums.applySort()
                    }
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
                AlbumArtwork(album: album, viewSize: imageSize)
            }
        }
    }
    
}

struct AlbumArtwork: View {
    let album: SavedAlbum
    let viewSize: CGFloat
    
    @State private var imageURL: URL?
    
    var body: some View {
        AsyncImage(url: imageURL) { image in
            image
                .resizable()
                .scaledToFit()
                .frame(width: viewSize, height: viewSize)
        } placeholder: {
            ProgressView()
        }
        .task {
            let scale = UIScreen.main.scale   // @2x for most iPhones, @3x on latest pro/max models
            let pixelSize = Int((viewSize * scale).rounded())
            imageURL = await ImageCache().getArtwork(
                albumID: album.id.rawValue,
                size: pixelSize
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
    return HomePageView(albums: savedAlbums)
}

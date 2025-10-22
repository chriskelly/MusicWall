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
    @State private var currentLayout = LayoutMenu.loadLayout() ?? .grid
    
    var body: some View {
        NavigationStack {
            Group {
                switch currentLayout {
                case .grid:
                    GridLayout()
                case .list:
                    ListLayout()
                }
            }
            .navigationTitle("Fav Albums")
            .toolbar {
                HomePageMenu(currentLayout: $currentLayout)
                Button("Shuffle albums temporarily", systemImage: "shuffle.circle") {
                    withAnimation {
                        albums.temporarilyShuffle()
                    }
                }
                Button("Add album", systemImage: "plus") {
                    showingAddView = true
                }
            }
        }
        .environment(albums)
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

struct HomePageMenu: View {
    @Binding var currentLayout: LayoutMenu.Option
    
    var body: some View {
        Menu {
            LayoutMenu(currentLayout: $currentLayout)
            SortMenu()
        } label: {
            Label("Options", systemImage: "line.3.horizontal.decrease.circle")
        }
    }
}

struct SortMenu: View {
    @Environment(SavedAlbums.self) private var albums
    
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
                        if albums.currentSort == option {
                            Image(systemName: albums.isAscending(for: option) ? "arrow.down" : "arrow.up")
                                .foregroundColor(.accentColor)
                        }
                        Text(option.rawValue)
                    }
                }
            }
        }
    }
}


#Preview {
    HomePageView(albums: SavedAlbums.dummyData())
}

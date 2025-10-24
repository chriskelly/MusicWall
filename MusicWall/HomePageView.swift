//
//  HomePageView.swift
//  MusicWall
//
//  Created by Chris Kelly on 8/29/25.
//

import SwiftUI
import MusicKit

struct HomePageView: View {
    @State var albums: StoredAlbums
    @State private var showingAddView = false
    @State private var currentLayout = LayoutMenu.loadLayout() ?? .grid
    @State private var showingAlbumAddSnackbar = false
    
    var body: some View {
        NavigationStack {
            layoutView()
            .navigationTitle("My Albums")
            .toolbar {toolbarView()}
            .background(Color(.systemGray6))
        }
        .environment(albums)
        .sheet(isPresented: $showingAddView) {
            AlbumSearchView(onSelect: onSearchSelect)
        }
        .snackbar(isPresented: $showingAlbumAddSnackbar, message: "Album successfully added!")
        .task {await albums.load()}
    }
    
    private func layoutView() -> some View {
        return Group {
            switch currentLayout {
            case .grid:
                GridLayout()
            case .list:
                ListLayout()
            }
        }
    }
    
    private func toolbarView() -> some View {
        return Group {
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
    
    private func onSearchSelect(_ album: MusicKitAlbum) {
        albums.addAlbum(StoredAlbum(from: album))
        showingAlbumAddSnackbar = true
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
    @Environment(StoredAlbums.self) private var albums
    
    var body: some View {
        Section {
            ForEach(StoredAlbums.SortOptions.allCases) {option in
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
    HomePageView(albums: StoredAlbums.dummyData())
}

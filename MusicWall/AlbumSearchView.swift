//
//  AlbumSearchView.swift
//  MusicWall
//
//  Created by Chris Kelly on 8/28/25.
//

import SwiftUI
import MusicKit

struct AlbumSearchView: View {
    @State private var query = ""
    @State private var catalogSearchResults: [Album] = []
    @State private var librarySearchResults: [Album] = []
    @FocusState private var isSearchFieldFocused: Bool
    
    var onSelect: (Album) -> Void
    
    var body: some View {
        NavigationStack {
            VStack {
                TextField("Search for an album", text: $query)
                    .textFieldStyle(.roundedBorder)
                    .padding()
                    .focused($isSearchFieldFocused)
                Button("Search") {
                    isSearchFieldFocused = false
                    Task {await searchAlbums()}
                }
                List {
                    Section(header: Text("Library")){
                        ForEach(librarySearchResults, id: \.id) { album in
                            SearchResultButton(onSelect: onSelect, album: album)
                        }
                    }
                    Section(header: Text("Apple Music")){
                        ForEach(catalogSearchResults, id: \.id) { album in
                            SearchResultButton(onSelect: onSelect, album: album)
                        }
                    }
                    
                }
            }
            .navigationTitle("Find Album")
        }
    }
    
    struct SearchResultButton:View {
        @Environment(\.dismiss) var dismiss
        
        var onSelect: (Album) -> Void
        var album: Album
        
        var body: some View {
            Button {
                onSelect(album)
                dismiss()
            } label: {
                HStack {
                    if album.contentRating == .explicit {
                        Image(systemName: "e.square.fill")
                    }
                    Text("\(album.title) — \(album.artistName)")
                }
            }
        }
    }
    
    func searchAlbums() async {
        guard !query.isEmpty else { return }
        do {
            catalogSearchResults = try await MusicService.searchAlbums(query: query, location: .catalog)
            librarySearchResults = try await MusicService.searchAlbums(query: query, location: .library)
        } catch {
            print(error.localizedDescription)
        }
    }
}

#Preview {
    AlbumSearchView(onSelect: { album in
        print(album)
    })
}

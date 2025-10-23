//
//  AlbumSearchView.swift
//  MusicWall
//
//  Created by Chris Kelly on 8/28/25.
//

import SwiftUI
import MusicKit

struct AlbumSearchView: View {
    @Environment(\.dismiss) var dismiss
    @State private var query = ""
    @State private var searchResults: [Album] = []
    
    var onSelect: (Album) -> Void
    
    var body: some View {
        NavigationStack {
            VStack {
                TextField("Search for an album", text: $query)
                    .textFieldStyle(.roundedBorder)
                    .padding()
                
                Button("Search") {
                    Task {
                        await searchAlbums()
                    }
                }
                
                List(searchResults, id: \.id) { album in
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
            .navigationTitle("Find Album")
        }
    }
    
    func searchAlbums() async {
        guard !query.isEmpty else { return }
        do {
            searchResults = try await MusicService.searchAlbums(query: query)
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

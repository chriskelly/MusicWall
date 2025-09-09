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
                        Text("\(album.title) — \(album.artistName)")
                    }
                }
            }
            .navigationTitle("Find Album")
        }
    }
    
    func searchAlbums() async {
        guard !query.isEmpty else { return }
        let request = MusicCatalogSearchRequest(term: query, types: [Album.self])
        do {
            let response = try await request.response()
            searchResults = Array(response.albums)
        } catch {
            print("Search failed: \(error)")
        }
    }
}

#Preview {
    AlbumSearchView(onSelect: { album in
        print(album)
    })
}

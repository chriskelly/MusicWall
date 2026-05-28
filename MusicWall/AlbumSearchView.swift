//
//  AlbumSearchView.swift
//  MusicWall
//
//  Created by Chris Kelly on 8/28/25.
//

import SwiftUI

struct AlbumSearchView: View {
    let repository: any AlbumRepository
    var onSelect: (AlbumRecord) -> Void

    @State private var query = ""
    @State private var catalogSearchResults: [AlbumRecord] = []
    @State private var librarySearchResults: [AlbumRecord] = []
    @State private var isSearching = false
    @FocusState private var isSearchFieldFocused: Bool

    var body: some View {
        NavigationStack {
            VStack {
                TextField("Search for an album", text: $query)
                    .textFieldStyle(.roundedBorder)
                    .padding()
                    .focused($isSearchFieldFocused)
                Button("Search") {
                    isSearchFieldFocused = false
                    Task { await searchAlbums() }
                }
                .disabled(isSearching)
                if isSearching {
                    ProgressView("Searching…")
                        .padding(.vertical, 4)
                }
                resultsView()
            }
            .navigationTitle("Find Album")
        }
    }

    private func resultsView() -> some View {
        List {
            Section(header: Text("Library")) {
                ForEach(librarySearchResults, id: \.id) { record in
                    SearchResultButton(onSelect: onSelect, record: record)
                }
            }
            Section(header: Text("Apple Music")) {
                ForEach(catalogSearchResults, id: \.id) { record in
                    SearchResultButton(onSelect: onSelect, record: record)
                }
            }
        }
    }

    struct SearchResultButton: View {
        @Environment(\.dismiss) var dismiss

        var onSelect: (AlbumRecord) -> Void
        var record: AlbumRecord

        var body: some View {
            Button {
                onSelect(record)
                dismiss()
            } label: {
                HStack {
                    if record.isExplicit {
                        Image(systemName: "e.square.fill")
                    }
                    Text("\(record.title) — \(record.artistName)")
                }
            }
        }
    }

    func searchAlbums() async {
        guard !query.isEmpty else { return }
        isSearching = true
        defer { isSearching = false }
        do {
            catalogSearchResults = try await repository.search(query: query, source: .catalog)
            librarySearchResults = try await repository.search(query: query, source: .library)
        } catch {
            print(error.localizedDescription)
        }
    }
}

#Preview {
    let deps = AppDependencies.preview()
    AlbumSearchView(repository: deps.albumRepository, onSelect: { _ in })
}

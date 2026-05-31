//
//  AlbumSearchView.swift
//  MusicWall
//
//  Created by Chris Kelly on 8/28/25.
//

import SwiftUI

struct AlbumSearchView: View {
    let onSelect: (AlbumRecord) -> Void

    @State private var viewModel: SearchViewModel
    @FocusState private var isSearchFieldFocused: Bool

    init(repository: any AlbumRepository, onSelect: @escaping (AlbumRecord) -> Void) {
        self.onSelect = onSelect
        _viewModel = State(initialValue: SearchViewModel(repository: repository))
    }

    var body: some View {
        AlbumSearchContent(
            viewModel: viewModel,
            onSelect: onSelect,
            isSearchFieldFocused: $isSearchFieldFocused
        )
    }
}

private struct AlbumSearchContent: View {
    @Bindable var viewModel: SearchViewModel
    var onSelect: (AlbumRecord) -> Void
    @FocusState.Binding var isSearchFieldFocused: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack {
                TextField("Search for an album", text: $viewModel.query)
                    .textFieldStyle(.roundedBorder)
                    .padding()
                    .focused($isSearchFieldFocused)
                Button("Search") {
                    isSearchFieldFocused = false
                    Task { await viewModel.search() }
                }
                .disabled(viewModel.isSearching)
                if viewModel.isSearching {
                    ProgressView("Searching…")
                        .padding(.vertical, 4)
                }
                if let message = viewModel.errorMessage {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                resultsView()
            }
            .navigationTitle("Find Album")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .accessibilityIdentifier("search.cancel")
                }
            }
        }
    }

    private func resultsView() -> some View {
        List {
            Section(header: Text("Library")) {
                ForEach(viewModel.libraryResults, id: \.id) { record in
                    AlbumSearchView.SearchResultButton(onSelect: onSelect, record: record)
                }
            }
            Section(header: Text("Apple Music")) {
                ForEach(viewModel.catalogResults, id: \.id) { record in
                    AlbumSearchView.SearchResultButton(onSelect: onSelect, record: record)
                }
            }
        }
    }
}

extension AlbumSearchView {
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
}

#Preview {
    let deps = AppDependencies.preview()
    AlbumSearchView(repository: deps.albumRepository, onSelect: { _ in })
}

//
//  AlbumEditView.swift
//  MusicWall
//
//  Created by Chris Kelly on 11/17/25.
//

import SwiftUI

struct AlbumEditView: View {
    let onSave: (AlbumRecord) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: AlbumEditViewModel

    init(album: AlbumRecord, onSave: @escaping (AlbumRecord) -> Void) {
        self.onSave = onSave
        _viewModel = State(initialValue: AlbumEditViewModel(album: album))
    }

    var body: some View {
        AlbumEditContent(viewModel: viewModel, onSave: onSave, dismiss: dismiss)
    }
}

private struct AlbumEditContent: View {
    @Bindable var viewModel: AlbumEditViewModel
    let onSave: (AlbumRecord) -> Void
    let dismiss: DismissAction

    var body: some View {
        NavigationStack {
            Form {
                Section("Changes made here are local and may be overridden by Apple Music") {
                    TextField("Title", text: $viewModel.title)
                    TextField("Artist Name", text: $viewModel.artistName)
                }

                Section {
                    Toggle("Set Release Date", isOn: Binding(
                        get: { viewModel.releaseDate != nil },
                        set: { viewModel.setReleaseDateEnabled($0) }
                    ))

                    if viewModel.releaseDate != nil {
                        DatePicker(
                            "Release Date",
                            selection: Binding(
                                get: { viewModel.releaseDate ?? Date() },
                                set: { viewModel.releaseDate = $0 }
                            ),
                            displayedComponents: .date
                        )
                    }
                }
            }
            .navigationTitle("Edit Album")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(viewModel.makeSavedRecord())
                        dismiss()
                    }
                    .disabled(!viewModel.canSave)
                }
            }
        }
    }
}

#Preview {
    let deps = AppDependencies.preview()
    AlbumEditView(
        album: AlbumStore.dummyData(
            preferences: deps.preferencesStore,
            repository: deps.albumRepository
        ).items.first!,
        onSave: { _ in }
    )
}

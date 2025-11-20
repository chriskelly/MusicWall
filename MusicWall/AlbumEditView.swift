//
//  AlbumEditView.swift
//  MusicWall
//
//  Created by Chris Kelly on 11/17/25.
//

import SwiftUI

struct AlbumEditView: View {
    let album: StoredAlbum
    let onSave: (StoredAlbum) -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var title: String
    @State private var artistName: String
    @State private var releaseDate: Date?
    
    init(album: StoredAlbum, onSave: @escaping (StoredAlbum) -> Void) {
        self.album = album
        self.onSave = onSave
        _title = State(initialValue: album.title)
        _artistName = State(initialValue: album.artistName)
        _releaseDate = State(initialValue: album.releaseDate)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Changes made here are local and may be overridden by Apple Music") {
                    TextField("Title", text: $title)
                    TextField("Artist Name", text: $artistName)
                }
                
                Section {
                    Toggle("Set Release Date", isOn: Binding(
                        get: { releaseDate != nil },
                        set: { hasDate in
                            if hasDate {
                                releaseDate = album.releaseDate ?? Date()
                            } else {
                                releaseDate = nil
                            }
                        }
                    ))
                    
                    if releaseDate != nil {
                        DatePicker(
                            "Release Date",
                            selection: Binding(
                                get: { releaseDate ?? Date() },
                                set: { releaseDate = $0 }
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
                        saveAlbum()
                    }
                    .disabled(title.isEmpty || artistName.isEmpty)
                }
            }
        }
    }
    
    private func saveAlbum() {
        let updatedAlbum = StoredAlbum(
            id: album.id,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            artistName: artistName.trimmingCharacters(in: .whitespacesAndNewlines),
            releaseDate: releaseDate
        )
        onSave(updatedAlbum)
        dismiss()
    }
}

#Preview {
    AlbumEditView(
        album: StoredAlbums.dummyData().items.first!,
        onSave: { _ in }
    )
}


import Foundation
import Observation

@MainActor
@Observable
final class AlbumEditViewModel {
    var title: String
    var artistName: String
    var releaseDate: Date?

    private let album: AlbumRecord

    init(album: AlbumRecord) {
        self.album = album
        self.title = album.title
        self.artistName = album.artistName
        self.releaseDate = album.releaseDate
    }

    var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !artistName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func setReleaseDateEnabled(_ enabled: Bool) {
        if enabled {
            releaseDate = album.releaseDate ?? Date()
        } else {
            releaseDate = nil
        }
    }

    func makeSavedRecord() -> AlbumRecord {
        AlbumRecord(
            id: album.id,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            artistName: artistName.trimmingCharacters(in: .whitespacesAndNewlines),
            releaseDate: releaseDate,
            isExplicit: album.isExplicit
        )
    }
}

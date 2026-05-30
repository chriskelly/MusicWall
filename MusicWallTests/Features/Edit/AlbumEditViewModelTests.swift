import Foundation
import Testing
@testable import MusicWall

struct AlbumEditViewModelTests {
    @Test @MainActor
    func canSave_whitespaceOnlyTitle_isFalse() {
        let album = AlbumFixtures.record(id: "a", title: "T", artistName: "A")
        let viewModel = AlbumEditViewModel(album: album)
        viewModel.title = "   "

        #expect(viewModel.canSave == false)
    }

    @Test @MainActor
    func canSave_whitespaceOnlyArtist_isFalse() {
        let album = AlbumFixtures.record(id: "a", title: "T", artistName: "A")
        let viewModel = AlbumEditViewModel(album: album)
        viewModel.artistName = "\t\n"

        #expect(viewModel.canSave == false)
    }

    @Test @MainActor
    func canSave_validFields_isTrue() {
        let album = AlbumFixtures.record(id: "a", title: "T", artistName: "A")
        let viewModel = AlbumEditViewModel(album: album)

        #expect(viewModel.canSave == true)
    }

    @Test @MainActor
    func makeSavedRecord_trimsWhitespace() {
        let album = AlbumFixtures.record(id: "a", title: "T", artistName: "A")
        let viewModel = AlbumEditViewModel(album: album)
        viewModel.title = "  Abbey Road  "
        viewModel.artistName = "  The Beatles  "

        let saved = viewModel.makeSavedRecord()

        #expect(saved.title == "Abbey Road")
        #expect(saved.artistName == "The Beatles")
    }

    @Test @MainActor
    func makeSavedRecord_preservesIdAndExplicit() {
        let releaseDate = AlbumFixtures.utcDate(year: 1969, month: 9, day: 26)
        let album = AlbumFixtures.record(
            id: "abbey-road",
            title: "Abbey Road",
            artistName: "The Beatles",
            releaseDate: releaseDate,
            isExplicit: true
        )
        let viewModel = AlbumEditViewModel(album: album)
        viewModel.title = "New Title"

        let saved = viewModel.makeSavedRecord()

        #expect(saved.id == album.id)
        #expect(saved.isExplicit == true)
        #expect(saved.title == "New Title")
        #expect(saved.releaseDate == releaseDate)
    }

    @Test @MainActor
    func setReleaseDateEnabled_true_usesExistingDate() {
        let releaseDate = AlbumFixtures.utcDate(year: 2011, month: 11, day: 15)
        let album = AlbumFixtures.record(id: "a", title: "T", artistName: "A", releaseDate: releaseDate)
        let viewModel = AlbumEditViewModel(album: album)
        viewModel.releaseDate = nil

        viewModel.setReleaseDateEnabled(true)

        #expect(viewModel.releaseDate == releaseDate)
    }

    @Test @MainActor
    func setReleaseDateEnabled_true_usesNowWhenMissing() {
        let album = AlbumFixtures.record(id: "a", title: "T", artistName: "A", releaseDate: nil)
        let viewModel = AlbumEditViewModel(album: album)

        viewModel.setReleaseDateEnabled(true)

        #expect(viewModel.releaseDate != nil)
    }

    @Test @MainActor
    func setReleaseDateEnabled_false_clearsDate() {
        let album = AlbumFixtures.record(
            id: "a",
            title: "T",
            artistName: "A",
            releaseDate: AlbumFixtures.utcDate(year: 2011, month: 11, day: 15)
        )
        let viewModel = AlbumEditViewModel(album: album)
        viewModel.setReleaseDateEnabled(true)

        viewModel.setReleaseDateEnabled(false)

        #expect(viewModel.releaseDate == nil)
    }
}

import SwiftUI
import Testing
import ViewInspector
@testable import MusicWall

struct EmptyAlbumsViewTests {
    @Test @MainActor
    func rendersTitleAndDescription() throws {
        let sut = EmptyAlbumsView(onAddAlbum: {}, onImport: {})

        _ = try sut.inspect().find(text: "Get started on your Music Wall!")
        _ = try sut.inspect().find(
            text: "Every great collection starts with one great album. "
                + "Search Apple Music, or restore your albums if you're returning."
        )
    }

    @Test @MainActor
    func addAlbumButton_invokesCallback() throws {
        var didAdd = false
        let sut = EmptyAlbumsView(onAddAlbum: { didAdd = true }, onImport: {})

        try sut.inspect().find(button: "Add an album").tap()

        #expect(didAdd)
    }

    @Test @MainActor
    func importButton_invokesCallback() throws {
        var didImport = false
        let sut = EmptyAlbumsView(onAddAlbum: {}, onImport: { didImport = true })

        try sut.inspect().find(button: "Import a backup").tap()

        #expect(didImport)
    }
}

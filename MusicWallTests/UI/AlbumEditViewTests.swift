import SwiftUI
import Testing
import ViewInspector
@testable import MusicWall

struct AlbumEditViewTests {
    @Test @MainActor
    func saveDisabled_whenTitleWhitespaceOnly() async throws {
        let album = AlbumFixtures.record(id: "a", title: "   ", artistName: "A")
        let view = AlbumEditView(album: album, onSave: { _ in })

        try await ViewHosting.host(view) {
            try await view.inspection.inspect { inspected in
                let save = try inspected.find(button: "Save")
                #expect(try save.isDisabled())
            }
        }
    }

    @Test @MainActor
    func saveEnabled_whenTitleValid() async throws {
        let album = AlbumFixtures.record(id: "a", title: "Abbey Road", artistName: "The Beatles")
        let view = AlbumEditView(album: album, onSave: { _ in })

        try await ViewHosting.host(view) {
            try await view.inspection.inspect { inspected in
                let save = try inspected.find(button: "Save")
                #expect(try save.isDisabled() == false)
            }
        }
    }
}

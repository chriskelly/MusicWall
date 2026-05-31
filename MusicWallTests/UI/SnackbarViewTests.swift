import SwiftUI
import Testing
import ViewInspector
@testable import MusicWall

struct SnackbarViewTests {
    @Test @MainActor
    func displaysMessage() throws {
        let sut = SnackbarView(message: "Added 3 albums")

        _ = try sut.inspect().find(text: "Added 3 albums")
    }

    @Test @MainActor
    func showsActionButton_whenLabelProvided() throws {
        let sut = SnackbarView(
            message: "Item added",
            actionLabel: "Undo",
            action: {}
        )

        _ = try sut.inspect().find(button: "Undo")
    }

    @Test @MainActor
    func actionButton_invokesCallback() throws {
        var didUndo = false
        let sut = SnackbarView(
            message: "Item added",
            actionLabel: "Undo",
            action: { didUndo = true }
        )

        try sut.inspect().find(button: "Undo").tap()

        #expect(didUndo)
    }

    @Test @MainActor
    func hidesActionButton_whenLabelNil() throws {
        let sut = SnackbarView(message: "Done")

        #expect(throws: (any Error).self) {
            try sut.inspect().find(button: "Undo")
        }
    }
}

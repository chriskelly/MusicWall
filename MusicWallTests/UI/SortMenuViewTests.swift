import SwiftUI
import Testing
import ViewInspector
@testable import MusicWall

struct SortMenuViewTests {
    @MainActor
    private func makeViewModel(
        sort: AlbumStore.SortOption = .artist,
        ascending: Bool = true
    ) -> HomeViewModel {
        let preferences = InMemoryPreferencesStore()
        let viewModel = HomeViewModel(
            preferences: preferences,
            repository: MockAlbumRepository(),
            backup: MockAlbumBackupService()
        )
        viewModel.store.currentSort = sort
        if !ascending {
            viewModel.store.toggleSortDirection(for: sort)
        }
        return viewModel
    }

    @MainActor
    private func directionArrowName(in button: InspectableView<ViewType.Button>) throws -> String? {
        let label = try button.labelView()
        let images = try label.findAll(ViewType.Image.self)
        guard let image = images.first else { return nil }
        return try image.actualImage().name()
    }

    @Test @MainActor
    func currentSort_showsDirectionArrow_ascending() throws {
        let viewModel = makeViewModel(sort: .artist, ascending: true)
        let sut = SortMenu(viewModel: viewModel)

        let artistButton = try sut.inspect().find(button: "Artist")
        #expect(try directionArrowName(in: artistButton) == "arrow.down")

        let titleButton = try sut.inspect().find(button: "Title")
        #expect(try directionArrowName(in: titleButton) == nil)
    }

    @Test @MainActor
    func currentSort_showsDirectionArrow_descending() throws {
        let viewModel = makeViewModel(sort: .artist, ascending: false)
        let sut = SortMenu(viewModel: viewModel)

        let artistButton = try sut.inspect().find(button: "Artist")
        #expect(try directionArrowName(in: artistButton) == "arrow.up")
    }

    @Test @MainActor
    func tapSortOption_updatesCurrentSort() throws {
        let viewModel = makeViewModel(sort: .artist, ascending: true)
        let sut = SortMenu(viewModel: viewModel)

        try sut.inspect().find(button: "Title").tap()

        #expect(viewModel.currentSort == .title)
    }
}

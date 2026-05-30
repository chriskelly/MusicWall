import Foundation
import Testing
@testable import MusicWall

struct SearchViewModelTests {
    @MainActor
    private func makeViewModel(
        repository: MockAlbumRepository = MockAlbumRepository()
    ) -> (SearchViewModel, MockAlbumRepository) {
        (SearchViewModel(repository: repository), repository)
    }

    @Test @MainActor
    func search_emptyQuery_doesNotCallRepository() async {
        let (viewModel, repository) = makeViewModel()
        viewModel.query = ""

        await viewModel.search()

        #expect(repository.searchCalls.isEmpty)
        #expect(viewModel.isSearching == false)
    }

    @Test @MainActor
    func search_success_populatesBothResultLists() async {
        let repository = MockAlbumRepository()
        let catalogRecord = AlbumFixtures.record(id: "cat-1", title: "Catalog", artistName: "Artist A")
        let libraryRecord = AlbumFixtures.record(id: "lib-1", title: "Library", artistName: "Artist B")
        repository.searchHandler = { _, source in
            switch source {
            case .catalog: return [catalogRecord]
            case .library: return [libraryRecord]
            }
        }
        let viewModel = SearchViewModel(repository: repository)
        viewModel.query = "test"

        await viewModel.search()

        #expect(viewModel.catalogResults == [catalogRecord])
        #expect(viewModel.libraryResults == [libraryRecord])
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.isSearching == false)
        #expect(repository.searchCalls.count == 2)
        #expect(repository.searchCalls.contains(where: { $0.1 == .catalog }))
        #expect(repository.searchCalls.contains(where: { $0.1 == .library }))
    }

    @Test @MainActor
    func search_bothFail_clearsResultsAndSetsErrorMessage() async {
        let repository = MockAlbumRepository()
        repository.searchHandler = { _, _ in
            throw AlbumRepositoryError.searchFailed("boom")
        }
        let viewModel = SearchViewModel(repository: repository)
        viewModel.query = "test"

        await viewModel.search()

        #expect(viewModel.catalogResults.isEmpty)
        #expect(viewModel.libraryResults.isEmpty)
        #expect(viewModel.errorMessage?.contains("Apple Music:") == true)
        #expect(viewModel.errorMessage?.contains("Library:") == true)
        #expect(viewModel.isSearching == false)
    }

    @Test @MainActor
    func search_catalogFails_showsPartialResults() async {
        let repository = MockAlbumRepository()
        let libraryRecord = AlbumFixtures.record(id: "lib-1", title: "Library", artistName: "Artist B")
        repository.searchHandler = { _, source in
            switch source {
            case .catalog:
                throw AlbumRepositoryError.networkError("offline")
            case .library:
                return [libraryRecord]
            }
        }
        let viewModel = SearchViewModel(repository: repository)
        viewModel.query = "test"

        await viewModel.search()

        #expect(viewModel.catalogResults.isEmpty)
        #expect(viewModel.libraryResults == [libraryRecord])
        #expect(viewModel.errorMessage?.contains("Apple Music:") == true)
        #expect(viewModel.errorMessage?.contains("Library:") == false)
    }

    @Test @MainActor
    func search_libraryFails_showsPartialResults() async {
        let repository = MockAlbumRepository()
        let catalogRecord = AlbumFixtures.record(id: "cat-1", title: "Catalog", artistName: "Artist A")
        repository.searchHandler = { _, source in
            switch source {
            case .catalog:
                return [catalogRecord]
            case .library:
                throw AlbumRepositoryError.networkError("offline")
            }
        }
        let viewModel = SearchViewModel(repository: repository)
        viewModel.query = "test"

        await viewModel.search()

        #expect(viewModel.catalogResults == [catalogRecord])
        #expect(viewModel.libraryResults.isEmpty)
        #expect(viewModel.errorMessage?.contains("Library:") == true)
        #expect(viewModel.errorMessage?.contains("Apple Music:") == false)
    }

    @Test @MainActor
    func search_repositoryError_usesLocalizedDescription() async {
        let repository = MockAlbumRepository()
        repository.searchHandler = { _, _ in
            throw AlbumRepositoryError.networkError("offline")
        }
        let viewModel = SearchViewModel(repository: repository)
        viewModel.query = "test"

        await viewModel.search()

        #expect(viewModel.errorMessage?.contains("offline") == true)
    }
}

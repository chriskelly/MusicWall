import Foundation
import Testing
@testable import MusicWall

@Suite(.timeLimit(.minutes(1)))
struct SearchViewModelTests {
    @MainActor
    private func makeViewModel(
        repository: MockAlbumRepository = MockAlbumRepository(),
        debounce: Duration = .zero
    ) -> (SearchViewModel, MockAlbumRepository) {
        (SearchViewModel(repository: repository, debounce: debounce), repository)
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

    // MARK: - As-you-type path

    @Test @MainActor
    func queryDidChange_searchesTrimmedQueryOncePerSource() async {
        let catalogRecord = AlbumFixtures.record(id: "cat-1", title: "Catalog", artistName: "Artist A")
        let libraryRecord = AlbumFixtures.record(id: "lib-1", title: "Library", artistName: "Artist B")
        let repository = MockAlbumRepository()
        repository.searchHandler = { _, source in
            source == .catalog ? [catalogRecord] : [libraryRecord]
        }
        let (viewModel, _) = makeViewModel(repository: repository)
        viewModel.query = "  daft punk  "

        await viewModel.queryDidChange()

        #expect(repository.searchCalls.map { $0.0 } == ["daft punk", "daft punk"])
        #expect(Set(repository.searchCalls.map { $0.1 }) == [.catalog, .library])
        #expect(viewModel.catalogResults == [catalogRecord])
        #expect(viewModel.libraryResults == [libraryRecord])
        #expect(viewModel.isSearching == false)
    }

    @Test @MainActor
    func queryDidChange_clearsPreviousErrorBeforeSearchCompletes() async {
        let repository = MockAlbumRepository()
        let searchStarted = AsyncGate()
        let releaseSearch = AsyncGate()
        repository.searchHandler = { _, _ in
            searchStarted.open()
            await releaseSearch.wait()
            return []
        }
        let (viewModel, _) = makeViewModel(repository: repository)
        viewModel.errorMessage = "Apple Music: offline"
        viewModel.query = "daft"

        let searchTask = Task { await viewModel.queryDidChange() }
        await searchStarted.wait()

        #expect(viewModel.errorMessage == nil)

        releaseSearch.open()
        await searchTask.value
    }

    @Test(arguments: ["", "d", "   "]) @MainActor
    func queryDidChange_queryBelowMinimum_clearsResultsAndErrorWithoutSearching(query: String) async {
        let record = AlbumFixtures.record(id: "cat-1", title: "Catalog", artistName: "Artist A")
        let repository = MockAlbumRepository()
        repository.searchHandler = { _, _ in [record] }
        let (viewModel, _) = makeViewModel(repository: repository)
        viewModel.query = "daft"
        await viewModel.search()
        #expect(viewModel.catalogResults == [record])
        #expect(viewModel.libraryResults == [record])

        viewModel.errorMessage = "Library: offline"
        let callsBefore = repository.searchCalls.count
        viewModel.query = query
        await viewModel.queryDidChange()

        #expect(repository.searchCalls.count == callsBefore)
        #expect(viewModel.catalogResults.isEmpty)
        #expect(viewModel.libraryResults.isEmpty)
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.isSearching == false)
    }

    @Test @MainActor
    func queryDidChange_catalogFails_keepsLibraryPartialResults() async {
        let libraryRecord = AlbumFixtures.record(id: "lib-1", title: "Library", artistName: "Artist B")
        let repository = MockAlbumRepository()
        repository.searchHandler = { _, source in
            switch source {
            case .catalog:
                throw AlbumRepositoryError.networkError("offline")
            case .library:
                return [libraryRecord]
            }
        }
        let (viewModel, _) = makeViewModel(repository: repository)
        viewModel.query = "daft"

        await viewModel.queryDidChange()

        #expect(viewModel.catalogResults.isEmpty)
        #expect(viewModel.libraryResults == [libraryRecord])
        #expect(viewModel.errorMessage?.contains("Apple Music:") == true)
        #expect(viewModel.errorMessage?.contains("Library:") == false)
        #expect(viewModel.isSearching == false)
    }

    @Test @MainActor
    func queryDidChange_cancelledDuringDebounce_doesNotSearch() async {
        let (viewModel, repository) = makeViewModel(debounce: .milliseconds(100))
        viewModel.query = "daft"

        let task = Task { await viewModel.queryDidChange() }
        task.cancel()
        await task.value

        #expect(repository.searchCalls.isEmpty)
        #expect(viewModel.isSearching == false)
    }

    @Test @MainActor
    func queryDidChange_olderResponseArrivesLast_keepsNewestResults() async {
        let oldRecord = AlbumFixtures.record(id: "old-1", title: "Old", artistName: "Artist A")
        let newRecord = AlbumFixtures.record(id: "new-1", title: "New", artistName: "Artist B")
        let repository = MockAlbumRepository()
        let oldSearchStarted = AsyncGate()
        let releaseOldSearch = AsyncGate()
        repository.searchHandler = { query, _ in
            guard query == "older" else { return [newRecord] }
            oldSearchStarted.open()
            await releaseOldSearch.wait()
            return [oldRecord]
        }
        let (viewModel, _) = makeViewModel(repository: repository)

        viewModel.query = "older"
        let oldTask = Task { await viewModel.queryDidChange() }
        await oldSearchStarted.wait()

        viewModel.query = "newer"
        await viewModel.queryDidChange()

        releaseOldSearch.open()
        await oldTask.value

        #expect(viewModel.catalogResults == [newRecord])
        #expect(viewModel.libraryResults == [newRecord])
        #expect(viewModel.isSearching == false)
    }

    @Test @MainActor
    func queryDidChange_clearedWhileSearchInFlight_stopsSpinner() async {
        let record = AlbumFixtures.record(id: "cat-1", title: "Catalog", artistName: "Artist A")
        let repository = MockAlbumRepository()
        let searchStarted = AsyncGate()
        let releaseSearch = AsyncGate()
        repository.searchHandler = { _, _ in
            searchStarted.open()
            await releaseSearch.wait()
            return [record]
        }
        let (viewModel, _) = makeViewModel(repository: repository)

        viewModel.query = "daft"
        let searchTask = Task { await viewModel.search() }
        await searchStarted.wait()

        viewModel.query = ""
        await viewModel.queryDidChange()

        #expect(viewModel.isSearching == false)

        releaseSearch.open()
        await searchTask.value

        #expect(viewModel.catalogResults.isEmpty)
        #expect(viewModel.libraryResults.isEmpty)
        #expect(viewModel.isSearching == false)
    }

    @Test @MainActor
    func queryDidChange_supersedesInFlightSearch_andStopsItsSpinner() async {
        let record = AlbumFixtures.record(id: "cat-1", title: "Catalog", artistName: "Artist A")
        let repository = MockAlbumRepository()
        let searchStarted = AsyncGate()
        let releaseSearch = AsyncGate()
        repository.searchHandler = { _, _ in
            searchStarted.open()
            await releaseSearch.wait()
            return [record]
        }
        let (viewModel, _) = makeViewModel(repository: repository, debounce: .seconds(60))

        viewModel.query = "daft"
        let oldSearch = Task { await viewModel.search() }
        await searchStarted.wait()

        viewModel.query = "dafts"
        let typing = Task { await viewModel.queryDidChange() }
        await Task.yield()
        #expect(viewModel.isSearching == false)

        releaseSearch.open()
        await oldSearch.value

        #expect(viewModel.catalogResults.isEmpty)
        #expect(viewModel.isSearching == false)

        typing.cancel()
        await typing.value
    }

    @Test @MainActor
    func search_whileSameQueryInFlight_doesNotStartAnother() async {
        let record = AlbumFixtures.record(id: "cat-1", title: "Catalog", artistName: "Artist A")
        let repository = MockAlbumRepository()
        let catalogStarted = AsyncGate()
        let libraryStarted = AsyncGate()
        let releaseSearch = AsyncGate()
        repository.searchHandler = { _, source in
            switch source {
            case .catalog: catalogStarted.open()
            case .library: libraryStarted.open()
            }
            await releaseSearch.wait()
            return [record]
        }
        let (viewModel, _) = makeViewModel(repository: repository)
        viewModel.query = "daft"
        let firstSearch = Task { await viewModel.search() }
        await catalogStarted.wait()
        await libraryStarted.wait()

        let duplicateSearch = Task { await viewModel.search() }
        await Task.yield()

        releaseSearch.open()
        await duplicateSearch.value
        await firstSearch.value

        #expect(repository.searchCalls.count == 2)
        #expect(viewModel.catalogResults == [record])
    }

    @Test @MainActor
    func queryDidChange_cancelledWhileRequestInFlight_keepsPreviousResults() async {
        let previousRecord = AlbumFixtures.record(id: "first-1", title: "First", artistName: "Artist A")
        let record = AlbumFixtures.record(id: "cat-1", title: "Catalog", artistName: "Artist B")
        let repository = MockAlbumRepository()
        let searchStarted = AsyncGate()
        let releaseSearch = AsyncGate()
        repository.searchHandler = { query, _ in
            guard query == "daft" else { return [previousRecord] }
            searchStarted.open()
            await releaseSearch.wait()
            return [record]
        }
        let (viewModel, _) = makeViewModel(repository: repository)
        viewModel.query = "first"
        await viewModel.search()
        #expect(viewModel.catalogResults == [previousRecord])

        viewModel.query = "daft"
        let searchTask = Task { await viewModel.queryDidChange() }
        await searchStarted.wait()
        searchTask.cancel()
        releaseSearch.open()
        await searchTask.value

        #expect(viewModel.catalogResults == [previousRecord])
        #expect(viewModel.libraryResults == [previousRecord])
        #expect(viewModel.isSearching == false)
        #expect(viewModel.errorMessage == nil)
    }

    @Test @MainActor
    func search_afterSupersededQuery_stillSearchesNewText() async {
        let oldRecord = AlbumFixtures.record(id: "old-1", title: "Old", artistName: "Artist A")
        let newRecord = AlbumFixtures.record(id: "new-1", title: "New", artistName: "Artist B")
        let repository = MockAlbumRepository()
        let searchStarted = AsyncGate()
        let releaseSearch = AsyncGate()
        repository.searchHandler = { query, _ in
            guard query == "daft" else { return [newRecord] }
            searchStarted.open()
            await releaseSearch.wait()
            return [oldRecord]
        }
        let (viewModel, _) = makeViewModel(repository: repository)
        viewModel.query = "daft"
        let oldSearch = Task { await viewModel.search() }
        await searchStarted.wait()

        viewModel.query = "nirvana"
        await viewModel.search()

        releaseSearch.open()
        await oldSearch.value

        #expect(repository.searchCalls.count == 4)
        #expect(viewModel.catalogResults == [newRecord])
        #expect(viewModel.libraryResults == [newRecord])
    }

    @Test @MainActor
    func queryDidChange_sameTextAsInFlightSubmit_startsItsOwnSearch() async {
        let record = AlbumFixtures.record(id: "cat-1", title: "Catalog", artistName: "Artist A")
        let repository = MockAlbumRepository()
        let searchStarted = AsyncGate()
        let releaseSearch = AsyncGate()
        repository.searchHandler = { _, _ in
            searchStarted.open()
            await releaseSearch.wait()
            return [record]
        }
        let (viewModel, _) = makeViewModel(repository: repository)
        viewModel.query = "daft"

        let submit = Task { await viewModel.search() }
        await searchStarted.wait()

        let typed = Task { await viewModel.queryDidChange() }
        await Task.yield()

        releaseSearch.open()
        await typed.value
        await submit.value

        #expect(repository.searchCalls.count == 4)
        #expect(viewModel.catalogResults == [record])
        #expect(viewModel.isSearching == false)
    }

    @Test @MainActor
    func search_singleCharacterQuery_isNotSubjectToTypingMinimum() async {
        let record = AlbumFixtures.record(id: "cat-1", title: "Catalog", artistName: "Artist A")
        let repository = MockAlbumRepository()
        repository.searchHandler = { _, _ in [record] }
        let (viewModel, _) = makeViewModel(repository: repository)
        viewModel.query = "u"

        await viewModel.search()

        #expect(repository.searchCalls.count == 2)
        #expect(viewModel.catalogResults == [record])
    }
}

/// Lets a test hold an async search open and release it on demand, so the ordering
/// between concurrent searches is explicit instead of timing-based. It lives here rather
/// than in `TestSupport/` because the MusicWallTests target lists its files explicitly, so a
/// new file would need an Xcode project change.
private final class AsyncGate: @unchecked Sendable {
    private let lock = NSLock()
    private var isOpen = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func open() {
        lock.lock()
        guard !isOpen else {
            lock.unlock()
            return
        }
        isOpen = true
        let pending = waiters
        waiters = []
        lock.unlock()

        for continuation in pending {
            continuation.resume()
        }
    }

    func wait() async {
        await withCheckedContinuation { continuation in
            lock.lock()
            if isOpen {
                lock.unlock()
                continuation.resume()
                return
            }
            waiters.append(continuation)
            lock.unlock()
        }
    }
}

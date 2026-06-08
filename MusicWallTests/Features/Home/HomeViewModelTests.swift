import Foundation
import Testing
@testable import MusicWall

struct HomeViewModelTests {
    @MainActor
    private func makeViewModel(
        preferences: InMemoryPreferencesStore = InMemoryPreferencesStore(),
        repository: MockAlbumRepository = MockAlbumRepository(),
        backup: MockAlbumBackupService = MockAlbumBackupService()
    ) -> (HomeViewModel, InMemoryPreferencesStore, MockAlbumRepository, MockAlbumBackupService) {
        let viewModel = HomeViewModel(
            preferences: preferences,
            repository: repository,
            backup: backup
        )
        return (viewModel, preferences, repository, backup)
    }

    @Test @MainActor
    func init_loadsLayoutFromPreferences() {
        let preferences = InMemoryPreferencesStore()
        preferences.save(LayoutMenu.Option.list, for: .homePageLayout)
        let viewModel = HomeViewModel(
            preferences: preferences,
            repository: MockAlbumRepository(),
            backup: MockAlbumBackupService()
        )
        #expect(viewModel.currentLayout == .list)
    }

    @Test @MainActor
    func exportEmptyCollection_showsNoAlbumsMessage() {
        let backup = MockAlbumBackupService()
        backup.exportHandler = { albums in
            if albums.isEmpty { throw BackupError.emptyExport }
            return URL(fileURLWithPath: "/tmp/export.json")
        }
        let viewModel = HomeViewModel(
            preferences: InMemoryPreferencesStore(),
            repository: MockAlbumRepository(),
            backup: backup
        )

        let result = viewModel.exportAlbums()

        if case .snackbar(let state) = result {
            #expect(state.message == "No albums to export")
        } else {
            Issue.record("Expected snackbar result")
        }
        #expect(backup.exportCalls == [[]])
    }

    @Test @MainActor
    func exportSuccess_returnsURL() {
        let backup = MockAlbumBackupService()
        let expectedURL = URL(fileURLWithPath: "/tmp/test-export.json")
        backup.exportHandler = { _ in expectedURL }
        let (viewModel, _, _, _) = makeViewModel(backup: backup)
        viewModel.store.addAlbum(AlbumFixtures.record(id: "a", title: "A", artistName: "Artist"))

        let result = viewModel.exportAlbums()

        if case .success(let url) = result {
            #expect(url == expectedURL)
        } else {
            Issue.record("Expected success")
        }
    }

    @Test @MainActor
    func exportOtherError_showsExportFailedPrefix() {
        let backup = MockAlbumBackupService()
        backup.exportHandler = { _ in throw BackupError.invalidFormat }
        let (viewModel, _, _, _) = makeViewModel(backup: backup)
        viewModel.store.addAlbum(AlbumFixtures.record(id: "a", title: "A", artistName: "Artist"))

        let result = viewModel.exportAlbums()

        if case .snackbar(let state) = result {
            #expect(state.message.hasPrefix("Export failed:"))
        } else {
            Issue.record("Expected snackbar")
        }
    }

    @Test @MainActor
    func importSuccess_showsCountMessage() async {
        let backup = MockAlbumBackupService()
        backup.importHandler = { _ in .ids(["a", "b"]) }
        let repository = MockAlbumRepository()
        repository.fetchHandler = { ids in
            ids.map { AlbumFixtures.record(id: $0.rawValue, title: "T", artistName: "Artist") }
        }
        let viewModel = HomeViewModel(
            preferences: InMemoryPreferencesStore(),
            repository: repository,
            backup: backup
        )
        let fileURL = URL(fileURLWithPath: "/tmp/import.json")

        await viewModel.importAlbums(from: fileURL)

        #expect(viewModel.snackbar?.message == "Successfully imported 2 album(s)!")
        #expect(viewModel.store.items.count == 2)
    }

    @Test @MainActor
    func importV2Records_showsCountWithoutFetch() async {
        let backup = MockAlbumBackupService()
        let records = [
            AlbumFixtures.record(id: "v2-a", title: "Local", artistName: "Artist"),
            AlbumFixtures.record(id: "v2-b", title: "Local 2", artistName: "Artist 2"),
        ]
        backup.importHandler = { _ in .records(records) }
        let repository = MockAlbumRepository()
        repository.fetchHandler = { _ in
            Issue.record("fetch should not be called")
            return []
        }
        let viewModel = HomeViewModel(
            preferences: InMemoryPreferencesStore(),
            repository: repository,
            backup: backup
        )
        let fileURL = URL(fileURLWithPath: "/tmp/import-v2.json")

        await viewModel.importAlbums(from: fileURL)

        #expect(viewModel.snackbar?.message == "Successfully imported 2 album(s)!")
        #expect(viewModel.store.items == records)
        #expect(repository.fetchCalls.isEmpty)
    }

    @Test @MainActor
    func importBackupFailure_showsImportFailed() async {
        let backup = MockAlbumBackupService()
        backup.importHandler = { _ in throw BackupError.invalidFormat }
        let viewModel = HomeViewModel(
            preferences: InMemoryPreferencesStore(),
            repository: MockAlbumRepository(),
            backup: backup
        )

        await viewModel.importAlbums(from: URL(fileURLWithPath: "/tmp/bad.json"))

        #expect(viewModel.snackbar?.message.hasPrefix("Import failed:") == true)
    }

    @Test @MainActor
    func importStoreFailure_showsImportFailed() async {
        struct TestError: Error {}
        let backup = MockAlbumBackupService()
        backup.importHandler = { _ in .ids(["missing"]) }
        let repository = MockAlbumRepository()
        repository.fetchHandler = { _ in throw TestError() }
        let viewModel = HomeViewModel(
            preferences: InMemoryPreferencesStore(),
            repository: repository,
            backup: backup
        )

        await viewModel.importAlbums(from: URL(fileURLWithPath: "/tmp/import.json"))

        #expect(viewModel.snackbar?.message.hasPrefix("Import failed:") == true)
    }

    @Test @MainActor
    func importFailed_fromFileImporter() {
        struct TestError: Error, LocalizedError {
            var errorDescription: String? { "picker failed" }
        }
        let (viewModel, _, _, _) = makeViewModel()

        viewModel.importFailed(TestError())

        #expect(viewModel.snackbar?.message == "Import failed: picker failed")
    }

    @Test @MainActor
    func selectSort_sameOption_togglesDirection() {
        let (viewModel, preferences, _, _) = makeViewModel()
        preferences.save([AlbumStore.SortOption: Bool](), for: .sortDirection)
        viewModel.store.currentSort = .artist
        viewModel.store.sortDirection[.artist] = true
        viewModel.selectSort(.artist)
        let firstAscending = viewModel.isAscending(for: .artist)
        viewModel.selectSort(.artist)
        #expect(viewModel.isAscending(for: .artist) != firstAscending)
    }

    @Test @MainActor
    func selectSort_differentOption_switchesSort() {
        let (viewModel, _, _, _) = makeViewModel()
        viewModel.store.currentSort = .artist
        viewModel.selectSort(.title)
        #expect(viewModel.currentSort == .title)
    }

    @Test @MainActor
    func setLayout_persistsToPreferences() {
        let (viewModel, preferences, _, _) = makeViewModel()
        viewModel.setLayout(.list)
        #expect(preferences.load(LayoutMenu.Option.self, for: .homePageLayout) == .list)
    }

    @Test @MainActor
    func albumAdded_setsSnackbar() {
        let (viewModel, _, _, _) = makeViewModel()
        viewModel.albumAdded()
        #expect(viewModel.snackbar?.message == "Album successfully added!")
    }

    @Test @MainActor
    func load_hydratesFromSavedPreferences() async {
        let preferences = InMemoryPreferencesStore()
        let records = [AlbumFixtures.record(id: "loaded", title: "Loaded", artistName: "Artist")]
        preferences.save(records, for: .albumRecordsItems)
        let viewModel = HomeViewModel(
            preferences: preferences,
            repository: MockAlbumRepository(),
            backup: MockAlbumBackupService()
        )

        await viewModel.load()

        #expect(viewModel.store.items == records)
    }

    @Test @MainActor
    func previewEmpty_isLoadedWithNoAlbums() {
        let viewModel = HomeViewModel.previewEmpty(dependencies: AppDependencies.preview())
        #expect(viewModel.hasLoaded)
        #expect(viewModel.isEmpty)
    }

    @Test @MainActor
    func isEmpty_trueWhenStoreEmpty() {
        let (viewModel, _, _, _) = makeViewModel()
        #expect(viewModel.isEmpty)
    }

    @Test @MainActor
    func load_emptyStore_staysEmptyAfterLoad() async {
        let (viewModel, _, _, _) = makeViewModel()
        await viewModel.load()
        #expect(viewModel.hasLoaded)
        #expect(viewModel.isEmpty)
    }

    @Test @MainActor
    func load_withSavedAlbums_isNotEmpty() async {
        let preferences = InMemoryPreferencesStore()
        preferences.save(
            [AlbumFixtures.record(id: "saved", title: "Saved", artistName: "Artist")],
            for: .albumRecordsItems
        )
        let viewModel = HomeViewModel(
            preferences: preferences,
            repository: MockAlbumRepository(),
            backup: MockAlbumBackupService()
        )

        await viewModel.load()

        #expect(viewModel.hasLoaded)
        #expect(!viewModel.isEmpty)
    }

    @Test @MainActor
    func currentSort_and_isAscending_reflectStore() {
        let (viewModel, _, _, _) = makeViewModel()
        viewModel.store.currentSort = .title
        viewModel.store.sortDirection[.title] = false
        #expect(viewModel.currentSort == .title)
        #expect(!viewModel.isAscending(for: .title))
    }

    @Test @MainActor
    func isEmpty_falseAfterAddAlbum() {
        let (viewModel, _, _, _) = makeViewModel()
        viewModel.store.addAlbum(AlbumFixtures.record(id: "a", title: "A", artistName: "Artist"))
        #expect(!viewModel.isEmpty)
    }

    @Test @MainActor
    func load_setsHasLoaded() async {
        let (viewModel, _, _, _) = makeViewModel()
        #expect(!viewModel.hasLoaded)
        await viewModel.load()
        #expect(viewModel.hasLoaded)
    }

    @Test @MainActor
    func isEmpty_falseAfterImport() async {
        let backup = MockAlbumBackupService()
        backup.importHandler = { _ in .ids(["a"]) }
        let repository = MockAlbumRepository()
        repository.fetchHandler = { ids in
            ids.map { AlbumFixtures.record(id: $0.rawValue, title: "T", artistName: "Artist") }
        }
        let viewModel = HomeViewModel(
            preferences: InMemoryPreferencesStore(),
            repository: repository,
            backup: backup
        )
        #expect(viewModel.isEmpty)

        await viewModel.importAlbums(from: URL(fileURLWithPath: "/tmp/import.json"))

        #expect(!viewModel.isEmpty)
    }

    @Test @MainActor
    func shuffleAlbums_preservesItemCount() {
        let (viewModel, _, _, _) = makeViewModel()
        for fixture in AlbumFixtures.baseTrio {
            viewModel.store.addAlbum(fixture)
        }
        let count = viewModel.store.items.count

        viewModel.shuffleAlbums()

        #expect(viewModel.store.items.count == count)
    }
}

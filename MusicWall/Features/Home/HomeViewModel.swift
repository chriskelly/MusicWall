import Foundation
import Observation

struct SnackbarState: Equatable {
    let message: String
}

enum HomeExportResult: Equatable {
    case success(URL)
    case snackbar(SnackbarState)
}

@MainActor
@Observable
final class HomeViewModel {
    let store: AlbumStore
    var currentLayout: LayoutMenu.Option
    var snackbar: SnackbarState?

    private let preferences: PreferencesStore
    private let backup: any AlbumBackupService

    init(
        preferences: PreferencesStore,
        repository: any AlbumRepository,
        backup: any AlbumBackupService
    ) {
        self.preferences = preferences
        self.backup = backup
        self.store = AlbumStore(preferences: preferences, repository: repository)
        self.currentLayout = preferences.load(LayoutMenu.Option.self, for: .homePageLayout) ?? .grid
    }

    func load() async {
        await store.load()
    }

    var currentSort: AlbumStore.SortOption {
        store.currentSort
    }

    func isAscending(for option: AlbumStore.SortOption) -> Bool {
        store.isAscending(for: option)
    }

    func selectSort(_ option: AlbumStore.SortOption) {
        if store.currentSort == option {
            store.toggleSortDirection(for: option)
        } else {
            store.currentSort = option
        }
        store.applySort()
    }

    func setLayout(_ option: LayoutMenu.Option) {
        currentLayout = option
        preferences.save(currentLayout, for: .homePageLayout)
    }

    func shuffleAlbums() {
        store.temporarilyShuffle()
    }

    func albumAdded() {
        snackbar = SnackbarState(message: "Album successfully added!")
    }

    func exportAlbums() -> HomeExportResult {
        let albums = store.items
        do {
            let url = try backup.exportAlbums(albums)
            return .success(url)
        } catch let error as BackupError where error == .emptyExport {
            return .snackbar(SnackbarState(message: "No albums to export"))
        } catch {
            return .snackbar(
                SnackbarState(message: "Export failed: \(error.localizedDescription)")
            )
        }
    }

    func importAlbums(from url: URL) async {
        do {
            let contents = try backup.importBackup(from: url)
            try await store.importBackup(contents)
            snackbar = SnackbarState(message: "Successfully imported \(contents.count) album(s)!")
        } catch {
            snackbar = SnackbarState(message: "Import failed: \(error.localizedDescription)")
        }
    }

    func importFailed(_ error: Error) {
        snackbar = SnackbarState(message: "Import failed: \(error.localizedDescription)")
    }
}

extension HomeViewModel {
    static func preview(dependencies: AppDependencies) -> HomeViewModel {
        let viewModel = HomeViewModel(
            preferences: dependencies.preferencesStore,
            repository: dependencies.albumRepository,
            backup: dependencies.albumBackupService
        )
        for record in AlbumStore.dummyData(
            preferences: dependencies.preferencesStore,
            repository: dependencies.albumRepository
        ).items {
            viewModel.store.addAlbum(record)
        }
        return viewModel
    }
}

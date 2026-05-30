# PR 9 — Home ViewModel

**Status:** Approved (2026-05-29)  
**Program:** MusicWall testability refactor  
**Requires:** PR 6 merged; PR 7 merged (export/import via `AlbumBackupService`)  
**Blocks:** PR 12 (view tests), PR 13 (UI tests)  
**Approach:** Monolithic `HomeViewModel` (Option 1) + VM owns `AlbumStore` (Option A) + hybrid presentation (Option C) + menus via VM (Option A) + dedicated empty-export copy (Option C)

## Summary

Move home-screen orchestration from `HomePageView` into an `@MainActor` `@Observable` **`HomeViewModel`** that owns **`AlbumStore`**, layout preference load/save, sort menu actions, export/import flows (via injected **`AlbumBackupService`**), and snackbar message state. `HomePageView` becomes a thin SwiftUI shell: bindings, `.environment(viewModel.store)`, repository/playback environment, and system UI (`fileImporter`, `ShareSheet`). `SortMenu`, `LayoutMenu`, and `BackupMenu` call the ViewModel instead of `AppDependencies` or `@Environment(AlbumStore)` directly.

## Goals

- `HomePageView` contains no direct `albumBackupService` calls.
- Unit-testable home orchestration: export empty/success/failure, import success/failure, sort toggle, layout persistence, add-album snackbar.
- `HomeViewModelTests` run without SwiftUI hosting.
- `ContentView` creates `HomeViewModel` when authorized (not bare `AlbumStore`).
- Preserve existing user-visible strings except empty export (dedicated copy per Option C).
- Move `HomePageView` to `MusicWall/Features/Home/`.

## Non-goals

- `SearchViewModel` (PR 10) — search sheet stays in view with repository injection.
- `LayoutViews` tap/play (PR 11).
- Moving sort preference persistence out of `AlbumStore` (store still owns `currentSort` / `sortDirection` keys).
- ViewInspector / snapshot tests (PR 12).
- Changing `AlbumStore.importAlbums` fetch semantics (covered by `AlbumStoreImportTests`).
- `AppDependencies` factory for `AlbumStore` (VM creates store in `init`).

## Approaches considered

### ViewModel shape

| Option | Description | Why not chosen |
|--------|-------------|----------------|
| **1 (chosen)** | Single `HomeViewModel` owns store, layout, snackbar, sort/backup methods | Matches PR 8; one test surface; ~80–120 lines is acceptable |
| 2 | VM + `HomeBackupCoordinator` | Extra type for two methods; `AlbumBackupService` is already the boundary |
| 3 | VM for backup only; menus unchanged | Conflicts with menu-via-VM decision; weak sort/layout test coverage |

### `AlbumStore` ownership

| Option | Description | Why not chosen |
|--------|-------------|----------------|
| **A (chosen)** | `HomeViewModel` creates and exposes `store` | Single home boundary; `ContentView` stays auth-only |
| B | `ContentView` creates store, passes to VM + view | Duplicated ownership from PR 8 |
| C | `AppDependencies.makeAlbumStore()` | Extra factory for no benefit |

### Presentation state

| Option | Description | Why not chosen |
|--------|-------------|----------------|
| **C (chosen)** | VM owns `snackbar` message; view owns `fileImporter` / `ShareSheet` bindings | Testable messages; system APIs stay in view layer |
| A | View owns all `@State`; VM returns result enums only | More glue in view |
| B | VM owns all presentation flags | SwiftUI-adjacent state in VM |

### Menu wiring

| Option | Description | Why not chosen |
|--------|-------------|----------------|
| **A (chosen)** | Menus call `HomeViewModel`; VM delegates to store/prefs | Matches skill; sort/layout covered by VM tests |
| B | Menus use `@Environment(AlbumStore)` for sort | Bypasses orchestration boundary |
| C | Hybrid: layout on VM, sort on environment | Split ownership |

### Empty export messaging

| Option | Description | Why not chosen |
|--------|-------------|----------------|
| **C (chosen)** | `BackupError.emptyExport` → `"No albums to export"`; other export errors → `"Export failed: …"` | Empty collection is expected state, not a failure |
| A | Always standalone `"No albums to export"` only for empty | Same as chosen for empty branch |
| B | Always `"Export failed: \(localizedDescription)"` | Awkward double wording for empty export |

## Architecture

### Layer placement

```
MusicWall/
  Features/Home/
    HomeViewModel.swift
    HomePageView.swift              # moved from MusicWall/
  Features/Auth/
    ContentView.swift               # creates HomeViewModel when authorized
  LayoutViews.swift                 # LayoutMenu.Option type; LayoutMenu updated
  AppDependencies.swift             # unchanged fields

MusicWallTests/
  Features/Home/
    HomeViewModelTests.swift
    AlbumStoreImportTests.swift     # unchanged
  TestSupport/
    MockAlbumBackupService.swift
```

Delete `MusicWall/HomePageView.swift` after move (filesystem-synced group picks up new path).

### Data flow

```
ContentView (.authorized)
  └─ HomePageView(viewModel: HomeViewModel)
       ├─ .task { await viewModel.load() }  → store.load()
       ├─ .environment(viewModel.store)
       ├─ .environment(\.albumRepository, dependencies.albumRepository)
       └─ .environment(\.playback, dependencies.playbackController)

Sort menu:
  SortMenu(viewModel) → viewModel.selectSort(option)
    → store.currentSort / toggleSortDirection / applySort

Layout menu:
  LayoutMenu(viewModel) → viewModel.setLayout(option)
    → currentLayout + preferences.save(..., .homePageLayout)

Export:
  BackupMenu → viewModel.exportAlbums()
    → .success(url) → view: ShareSheet
    → .snackbar(msg) → view: snackbar binding

Import:
  view: fileImporter → url
    → viewModel.importAlbums(from: url)
    → backup.importAlbumIDs → store.importAlbums → snackbar

Add album:
  AlbumSearchView.onSelect → store.addAlbum + viewModel.albumAdded() → snackbar
```

### Dependency rules

| Unit | May import |
|------|------------|
| `HomeViewModel` | Foundation, Observation |
| `HomePageView`, menus, `ShareSheet` | SwiftUI, UIKit (`ShareSheet` only) |
| `MockAlbumBackupService` | Foundation, `@testable import MusicWall` |
| Tests | `@testable import MusicWall` |

## Domain types

### `SnackbarState`

```swift
struct SnackbarState: Equatable {
    let message: String
}
```

Single snackbar channel for import/export/add-album messages (replaces separate add vs import snackbar state in view).

### `HomeExportResult`

```swift
enum HomeExportResult: Equatable {
    case success(URL)
    case snackbar(SnackbarState)
}
```

View presents `ShareSheet` only on `.success`. `.snackbar` covers empty export and other export failures.

## HomeViewModel

```swift
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
    )

    func load() async
    func selectSort(_ option: AlbumStore.SortOption)
    func isAscending(for option: AlbumStore.SortOption) -> Bool
    var currentSort: AlbumStore.SortOption { get }
    func setLayout(_ option: LayoutMenu.Option)
    func shuffleAlbums()
    func albumAdded()
    func exportAlbums() -> HomeExportResult
    func importAlbums(from url: URL) async
    func importFailed(_ error: Error)
}
```

### Init

- `store = AlbumStore(preferences:repository:)`
- `currentLayout = preferences.load(LayoutMenu.Option.self, for: .homePageLayout) ?? .grid`
- Store `preferences` and `backup` for layout save and backup I/O

### Sort — `selectSort`

| Condition | Action |
|-----------|--------|
| `option == store.currentSort` | `store.toggleSortDirection(for: option)` |
| else | `store.currentSort = option` |
| always | `store.applySort()` |

View may wrap calls in `withAnimation { }` as today.

### Layout — `setLayout`

Sets `currentLayout` and `preferences.save(currentLayout, for: .homePageLayout)`.

Remove direct `preferences.save` from `LayoutMenu`; menu reads/writes through VM binding.

### Export — `exportAlbums`

1. `let ids = store.exportAlbumIDs()`
2. `try backup.exportAlbumIDs(ids)`
3. On success: `.success(url)`
4. On error:
   - `BackupError.emptyExport` → `.snackbar(SnackbarState(message: "No albums to export"))`
   - else → `.snackbar(SnackbarState(message: "Export failed: \(error.localizedDescription)"))`

`LiveAlbumBackupService` still throws `emptyExport` when `ids.isEmpty`; VM maps copy (does not change PR 7 service).

### Import — `importAlbums(from:)`

1. `let ids = try backup.importAlbumIDs(from: url)`
2. `try await store.importAlbums(from: ids)`
3. Success: `snackbar = SnackbarState(message: "Successfully imported \(ids.count) album(s)!")`
4. Failure: `snackbar = SnackbarState(message: "Import failed: \(error.localizedDescription)")`

Note: `store.importAlbums` no-ops on empty `ids` without error; backup layer may throw `emptyImport` for empty JSON files (PR 7).

### Import — `importFailed`

Called when `fileImporter` returns `Result.failure`: same `"Import failed: …"` pattern.

### Add album — `albumAdded`

`snackbar = SnackbarState(message: "Album successfully added!")`

### Shuffle — `shuffleAlbums`

`store.temporarilyShuffle()` — view applies animation.

## HomePageView

Move to `MusicWall/Features/Home/HomePageView.swift`.

### Init

```swift
init(viewModel: HomeViewModel, dependencies: AppDependencies)
```

`ContentView` creates VM once when showing home:

```swift
HomePageView(
    viewModel: HomeViewModel(
        preferences: dependencies.preferencesStore,
        repository: dependencies.albumRepository,
        backup: dependencies.albumBackupService
    ),
    dependencies: dependencies
)
```

`ContentView` holds `@State private var homeViewModel` initialized in `init(dependencies:)` alongside `authViewModel` (same pattern as PR 8). The home VM is only shown when `authViewModel.state == .authorized`; `store.load()` runs from `HomePageView.task`, not at VM creation. Initializing `HomeViewModel` before authorization is acceptable.

### Removed from view

- `importAlbums` / `exportAlbums` private methods
- `dependencies.albumBackupService` usage
- Direct layout load in view `init` (VM init handles it)
- Duplicate snackbar strings (VM owns copy)
- `@State currentLayout` (VM property)
- `@Environment(AlbumStore)` in menus (menus use VM)

### Retained in view

- `@State showingAddView`
- `@State showingFileImporter`
- `@State exportedFileURL`, `showingExportShareSheet`
- `fileImporter`, `sheet`, `ShareSheet`
- `AlbumSearchView` with `dependencies.albumRepository`
- `.task { await viewModel.load() }`
- Toolbar shuffle/add buttons calling VM / showing sheet

### Snackbar binding

Single `.snackbar` driven by `viewModel.snackbar`:

```swift
.snackbar(
    isPresented: Binding(
        get: { viewModel.snackbar != nil },
        set: { if !$0 { viewModel.snackbar = nil } }
    ),
    message: viewModel.snackbar?.message ?? ""
)
```

Remove separate `showingAlbumAddSnackbar` / `showingImportSnackbar` / `importSnackbarMessage`.

### Menus

```swift
struct HomePageMenu: View {
    @Bindable var viewModel: HomeViewModel
    @Binding var showingFileImporter: Bool
    let onExport: () -> Void
}

struct SortMenu: View {
    @Bindable var viewModel: HomeViewModel
}

struct BackupMenu: View {
    @Binding var showingFileImporter: Bool
    let onExport: () -> Void
}
```

`HomePageView` passes `onExport` that calls `viewModel.exportAlbums()` and presents `ShareSheet` on `.success`.

Change `LayoutMenu` in `LayoutViews.swift` to take `@Bindable var viewModel: HomeViewModel`. Previews construct `HomeViewModel(preferences:repository:backup:)` with `AppDependencies.preview()`. Remove `LayoutMenu.loadLayout(using:)` — layout load lives in VM `init` only.

### Environment

```swift
.environment(viewModel.store)
.environment(\.albumRepository, dependencies.albumRepository)
.environment(\.playback, dependencies.playbackController)
```

`LayoutViews` (`GridLayout`, `ListLayout`) unchanged — still `@Environment(AlbumStore.self)`.

## Mocks

### `MockAlbumBackupService` (`MusicWallTests/TestSupport/`)

Handler style matching `MockAlbumRepository`:

```swift
final class MockAlbumBackupService: AlbumBackupService, @unchecked Sendable {
    var exportHandler: ([String]) throws -> URL = { _ in URL(fileURLWithPath: "/tmp/export.json") }
    var importHandler: (URL) throws -> [String] = { _ in [] }
    private(set) var exportCalls: [[String]] = []
    private(set) var importCalls: [URL] = []

    func exportAlbumIDs(_ ids: [String]) throws -> URL { … }
    func importAlbumIDs(from url: URL) throws -> [String] { … }
}
```

## Testing

### Framework

Swift Testing (consistent with PR 1–8). All `HomeViewModelTests` on `@MainActor`.

### `HomeViewModelTests`

| Test | Setup | Assert |
|------|-------|--------|
| `exportEmptyCollection_showsNoAlbumsMessage` | Empty store | `exportAlbums()` → `.snackbar("No albums to export")`; `exportCalls` empty |
| `exportSuccess_returnsURL` | Store with albums; mock returns URL | `.success(url)` |
| `exportOtherError_showsExportFailedPrefix` | Mock throws `BackupError.invalidFormat` | `.snackbar` message has `"Export failed:"` prefix |
| `importSuccess_showsCountMessage` | Mock returns `["a","b"]`; repository returns records | `snackbar` success with count 2 |
| `importBackupFailure_showsImportFailed` | Mock import throws | `"Import failed:"` |
| `importStoreFailure_showsImportFailed` | Backup OK; `repository.fetch` throws | `"Import failed:"` |
| `importFailed_fromFileImporter` | Call `importFailed(underlying)` | `"Import failed:"` |
| `selectSort_sameOption_togglesDirection` | Pre-seed artist ascending; `selectSort(.artist)` twice | `isAscending` flips |
| `selectSort_differentOption_switchesSort` | `selectSort(.title)` | `currentSort == .title` |
| `setLayout_persistsToPreferences` | `setLayout(.list)` | prefs load `.list` |
| `init_loadsLayoutFromPreferences` | Pre-save `.list` in prefs | `currentLayout == .list` |
| `albumAdded_setsSnackbar` | `albumAdded()` | `"Album successfully added!"` |

Use `InMemoryPreferencesStore`, `MockAlbumRepository`, `MockAlbumBackupService`. Seed albums via `viewModel.store.addAlbum(AlbumFixtures.record(...))`.

Target: high line/branch coverage on `HomeViewModel` (message mapping branches).

### Unchanged tests

- `AlbumStoreImportTests` — store-level import/fetch behavior
- `BackupCodecTests`, `LiveAlbumBackupServiceTests` — PR 7 boundaries

### Smoke

- `#Preview` on `HomePageView` compiles with `HomeViewModel` + `AppDependencies.preview()`
- `ContentView` preview shows home with mock auth + home VM

### Human verification (PR description)

| Scenario | Expected |
|----------|----------|
| Export with albums | Share sheet with JSON file |
| Export empty library | Snackbar: "No albums to export" |
| Import valid backup | Success count snackbar; albums appear |
| Import invalid file | Import failed snackbar |
| Sort artist/title/year + toggle direction | List reorders; persists relaunch |
| Grid/list toggle | Layout persists relaunch |
| Add from search | Success snackbar |

## Acceptance criteria

- [ ] `HomeViewModel` in `MusicWall/Features/Home/`; owns `AlbumStore`; injects `AlbumBackupService`.
- [ ] `HomePageView` in `Features/Home/`; no `albumBackupService` calls.
- [ ] `ContentView` creates `HomeViewModel` (not bare `AlbumStore`) for authorized state.
- [ ] `SortMenu`, `LayoutMenu` (home path), backup export/import orchestration go through VM.
- [ ] Empty export shows `"No albums to export"` without `"Export failed:"` prefix.
- [ ] `HomeViewModelTests` cover export/import/sort/layout/snackbar cases without SwiftUI hosting.
- [ ] `MockAlbumBackupService` in test support.
- [ ] App compiles; `ci-tests` green.

## PR delivery

- Branch from `main`: `cursor/test-refactor-pr-09-home-vm` (or team convention).
- Move `HomePageView.swift` to `Features/Home/`; add `HomeViewModel.swift`.
- Register `HomeViewModelTests.swift` and `MockAlbumBackupService.swift` in `project.pbxproj` (mirror `AuthViewModelTests.swift`).
- PR description: link “PR 9 of 14”; note human export/import on simulator.

## Follow-on PRs

| PR | Relationship |
|----|----------------|
| PR 10 | `SearchViewModel`; search sheet may move orchestration out of `HomePageView` |
| PR 11 | Layout tap/play; `AlbumStore` environment unchanged |
| PR 12 | ViewInspector tests against thin `HomePageView` |
| PR 13 | UI tests; home launch with mock backup optional |
| PR 14 | Coverage gates on `HomeViewModel` |

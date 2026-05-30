# PR 9 — Home ViewModel Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move home-screen orchestration from `HomePageView` into a testable `HomeViewModel` that owns `AlbumStore`, layout/sort/backup flows, and snackbar messages; thin the view to bindings and system UI only.

**Architecture:** `@MainActor @Observable HomeViewModel` in `Features/Home/` creates `AlbumStore`, injects `AlbumBackupService` for export/import, maps errors to `SnackbarState` / `HomeExportResult`. Menus call VM methods. View keeps `fileImporter`, `ShareSheet`, and sheet state.

**Tech Stack:** Swift 5, Swift Testing, Observation, Xcode 16+, scheme `MusicWall`, simulator `iPhone 17`, `bundle exec fastlane ci_tests`.

**Spec:** `docs/specs/2026-05-29-pr-09-home-viewmodel-design.md`

**Branch:** `cursor/test-refactor-pr-09-home-vm`

---

## File map

| Action | Path | Notes |
|--------|------|-------|
| Create | `MusicWall/Features/Home/HomeViewModel.swift` | VM + `SnackbarState` + `HomeExportResult` |
| Move | `MusicWall/HomePageView.swift` → `MusicWall/Features/Home/HomePageView.swift` | Thin view + menus + `ShareSheet` |
| Modify | `MusicWall/LayoutViews.swift` | `LayoutMenu` takes `@Bindable HomeViewModel` |
| Modify | `MusicWall/Features/Auth/ContentView.swift` | Create `HomeViewModel`, pass to home |
| Create | `MusicWallTests/TestSupport/MockAlbumBackupService.swift` | Test double |
| Create | `MusicWallTests/Features/Home/HomeViewModelTests.swift` | VM unit tests |
| Modify | `MusicWall.xcodeproj/project.pbxproj` | Register test files |
| Modify | `Agent.md` | HomeViewModel note |

**Xcode note:** `MusicWall/` uses `PBXFileSystemSynchronizedRootGroup` — new app files under `MusicWall/Features/` auto-join the target. Delete old `MusicWall/HomePageView.swift` after move so Xcode does not compile two copies. Test files must be registered in `project.pbxproj` (mirror `AuthViewModelTests.swift`).

---

### Task 1: Test mock — `MockAlbumBackupService`

**Files:**
- Create: `MusicWallTests/TestSupport/MockAlbumBackupService.swift`
- Modify: `MusicWall.xcodeproj/project.pbxproj`

- [ ] **Step 1: Register file in Xcode project**

Add `MockAlbumBackupService.swift` to `MusicWallTests` target (PBXFileReference, PBXBuildFile, `TestSupport` group, Sources build phase). Mirror `MockMusicAuthorizationProvider.swift` registration.

- [ ] **Step 2: Create `MockAlbumBackupService.swift`**

```swift
import Foundation
@testable import MusicWall

final class MockAlbumBackupService: AlbumBackupService, @unchecked Sendable {
    var exportHandler: ([String]) throws -> URL = { _ in
        URL(fileURLWithPath: "/tmp/export.json")
    }
    var importHandler: (URL) throws -> [String] = { _ in [] }

    private(set) var exportCalls: [[String]] = []
    private(set) var importCalls: [URL] = []

    func exportAlbumIDs(_ ids: [String]) throws -> URL {
        exportCalls.append(ids)
        return try exportHandler(ids)
    }

    func importAlbumIDs(from url: URL) throws -> [String] {
        importCalls.append(url)
        return try importHandler(url)
    }
}
```

- [ ] **Step 3: Build tests target**

Run:

```bash
xcodebuild build-for-testing -project MusicWall.xcodeproj -scheme MusicWall \
  -destination 'platform=iOS Simulator,name=iPhone 17' -quiet
```

Expected: `BUILD SUCCEEDED`

- [ ] **Step 4: Commit**

```bash
git add MusicWallTests/TestSupport/MockAlbumBackupService.swift MusicWall.xcodeproj/project.pbxproj
git commit -m "test: Add MockAlbumBackupService"
```

---

### Task 2: `HomeViewModel` types + failing tests (TDD)

**Files:**
- Create: `MusicWallTests/Features/Home/HomeViewModelTests.swift`
- Create: `MusicWall/Features/Home/HomeViewModel.swift` (stub)
- Modify: `MusicWall.xcodeproj/project.pbxproj`

- [ ] **Step 1: Register `HomeViewModelTests.swift` in Xcode project**

Mirror `AuthViewModelTests.swift` under `MusicWallTests/Features/Home/`.

- [ ] **Step 2: Create stub `HomeViewModel.swift`**

```swift
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

    init(
        preferences: PreferencesStore,
        repository: any AlbumRepository,
        backup: any AlbumBackupService
    ) {
        fatalError("unimplemented")
    }
}
```

- [ ] **Step 3: Create `HomeViewModelTests.swift`**

```swift
import Foundation
import Testing
@testable import MusicWall

struct HomeViewModelTests {
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
    backup.exportHandler = { ids in
      if ids.isEmpty { throw BackupError.emptyExport }
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
    backup.importHandler = { _ in ["a", "b"] }
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
    backup.importHandler = { _ in ["missing"] }
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
}
```

- [ ] **Step 4: Run tests — expect FAIL**

Run:

```bash
xcodebuild test -project MusicWall.xcodeproj -scheme MusicWall \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:MusicWallTests/HomeViewModelTests -quiet
```

Expected: FAIL (`fatalError` or missing methods)

- [ ] **Step 5: Commit failing tests**

```bash
git add MusicWall/Features/Home/HomeViewModel.swift \
  MusicWallTests/Features/Home/HomeViewModelTests.swift \
  MusicWall.xcodeproj/project.pbxproj
git commit -m "test: Add failing HomeViewModel tests"
```

---

### Task 3: Implement `HomeViewModel`

**Files:**
- Modify: `MusicWall/Features/Home/HomeViewModel.swift`

- [ ] **Step 1: Replace stub with full implementation**

```swift
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
        let ids = store.exportAlbumIDs()
        do {
            let url = try backup.exportAlbumIDs(ids)
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
            let ids = try backup.importAlbumIDs(from: url)
            try await store.importAlbums(from: ids)
            snackbar = SnackbarState(message: "Successfully imported \(ids.count) album(s)!")
        } catch {
            snackbar = SnackbarState(message: "Import failed: \(error.localizedDescription)")
        }
    }

    func importFailed(_ error: Error) {
        snackbar = SnackbarState(message: "Import failed: \(error.localizedDescription)")
    }
}
```

- [ ] **Step 2: Run `HomeViewModelTests`**

Run:

```bash
xcodebuild test -project MusicWall.xcodeproj -scheme MusicWall \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:MusicWallTests/HomeViewModelTests -quiet
```

Expected: all tests PASS

- [ ] **Step 3: Commit**

```bash
git add MusicWall/Features/Home/HomeViewModel.swift
git commit -m "feat(home): Implement HomeViewModel"
```

---

### Task 4: Thin `HomePageView` + move to `Features/Home`

**Files:**
- Create: `MusicWall/Features/Home/HomePageView.swift`
- Delete: `MusicWall/HomePageView.swift`

- [ ] **Step 1: Create `Features/Home/HomePageView.swift`**

Replace `HomePageView` with VM-driven version. Key points:

```swift
struct HomePageView: View {
    @Bindable var viewModel: HomeViewModel
    let dependencies: AppDependencies
    @State private var showingAddView = false
    @State private var showingFileImporter = false
    @State private var exportedFileURL: URL?
    @State private var showingExportShareSheet = false

    var body: some View {
        NavigationStack {
            layoutView()
                .navigationTitle("My Albums")
                .toolbar { toolbarView() }
                .background(Color(.systemGray6))
        }
        .environment(viewModel.store)
        .environment(\.albumRepository, dependencies.albumRepository)
        .environment(\.playback, dependencies.playbackController)
        .sheet(isPresented: $showingAddView) {
            AlbumSearchView(
                repository: dependencies.albumRepository,
                onSelect: onSearchSelect
            )
        }
        .snackbar(
            isPresented: Binding(
                get: { viewModel.snackbar != nil },
                set: { if !$0 { viewModel.snackbar = nil } }
            ),
            message: viewModel.snackbar?.message ?? ""
        )
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: [.json, .text],
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result: result)
        }
        .sheet(isPresented: $showingExportShareSheet) {
            if let url = exportedFileURL {
                ShareSheet(activityItems: [url])
            }
        }
        .task { await viewModel.load() }
    }

    private func layoutView() -> some View {
        Group {
            switch viewModel.currentLayout {
            case .grid: GridLayout()
            case .list: ListLayout()
            }
        }
    }

    private func toolbarView() -> some ToolbarContent {
        Group {
            HomePageMenu(
                viewModel: viewModel,
                showingFileImporter: $showingFileImporter,
                onExport: handleExport
            )
            Button("Shuffle albums temporarily", systemImage: "shuffle.circle") {
                withAnimation { viewModel.shuffleAlbums() }
            }
            Button("Add album", systemImage: "plus") {
                showingAddView = true
            }
        }
    }

    private func onSearchSelect(_ record: AlbumRecord) {
        viewModel.store.addAlbum(record)
        viewModel.albumAdded()
    }

    private func handleFileImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            Task { await viewModel.importAlbums(from: url) }
        case .failure(let error):
            viewModel.importFailed(error)
        }
    }

    private func handleExport() {
        switch viewModel.exportAlbums() {
        case .success(let url):
            exportedFileURL = url
            showingExportShareSheet = true
        case .snackbar(let state):
            viewModel.snackbar = state
        }
    }
}

struct HomePageMenu: View {
    @Bindable var viewModel: HomeViewModel
    @Binding var showingFileImporter: Bool
    let onExport: () -> Void

    var body: some View {
        Menu {
            LayoutMenu(viewModel: viewModel)
            SortMenu(viewModel: viewModel)
            BackupMenu(showingFileImporter: $showingFileImporter, onExport: onExport)
        } label: {
            Label("Options", systemImage: "line.3.horizontal.decrease.circle")
        }
    }
}

struct SortMenu: View {
    @Bindable var viewModel: HomeViewModel

    var body: some View {
        Section {
            ForEach(AlbumStore.SortOption.allCases) { option in
                Button {
                    withAnimation { viewModel.selectSort(option) }
                } label: {
                    HStack {
                        if viewModel.currentSort == option {
                            Image(systemName: viewModel.isAscending(for: option) ? "arrow.down" : "arrow.up")
                                .foregroundColor(.accentColor)
                        }
                        Text(option.rawValue)
                    }
                }
            }
        }
    }
}
```

Keep `BackupMenu` and `ShareSheet` unchanged except signatures already shown.

Update `#Preview`:

```swift
#Preview {
    let deps = AppDependencies.preview()
    let viewModel = HomeViewModel(
        preferences: deps.preferencesStore,
        repository: deps.albumRepository,
        backup: deps.albumBackupService
    )
    HomePageView(viewModel: viewModel, dependencies: deps)
}
```

For preview data, after creating VM call `viewModel.store.addAlbum(...)` in preview or add `HomeViewModel.preview(dependencies:)` helper that seeds dummy albums via internal store — **simplest:** in preview, use live backup + `AlbumStore.dummyData` pattern replaced by seeding:

```swift
let viewModel = HomeViewModel(...)
viewModel.store.addAlbum(AlbumFixtures.record(...)) // repeat 3 samples from old dummyData
```

Or extract `AlbumStore.dummyData` and copy records into `viewModel.store` in preview only.

- [ ] **Step 2: Delete `MusicWall/HomePageView.swift`**

```bash
git rm MusicWall/HomePageView.swift
```

- [ ] **Step 3: Build app**

Run:

```bash
xcodebuild build -project MusicWall.xcodeproj -scheme MusicWall \
  -destination 'platform=iOS Simulator,name=iPhone 17' -quiet
```

Expected: may FAIL until `LayoutMenu` updated (Task 5) — complete Task 5 before expecting green build, or do Tasks 4+5 together.

- [ ] **Step 4: Commit**

```bash
git add MusicWall/Features/Home/HomePageView.swift
git commit -m "refactor(home): Thin HomePageView with HomeViewModel"
```

---

### Task 5: Update `LayoutMenu` + `ContentView`

**Files:**
- Modify: `MusicWall/LayoutViews.swift`
- Modify: `MusicWall/Features/Auth/ContentView.swift`

- [ ] **Step 1: Update `LayoutMenu` in `LayoutViews.swift`**

```swift
struct LayoutMenu: View {
    @Bindable var viewModel: HomeViewModel

    enum Option: String, CaseIterable, Identifiable, Codable {
        var id: String { rawValue }
        case grid = "Grid"
        case list = "List"
    }

    var body: some View {
        Section {
            ForEach(LayoutMenu.Option.allCases) { option in
                Button {
                    viewModel.setLayout(option)
                } label: {
                    HStack {
                        if viewModel.currentLayout == option {
                            Image(systemName: "checkmark")
                        }
                        Text(option.rawValue)
                    }
                }
            }
        }
    }
}
```

Remove `static func loadLayout(using:)` — no remaining call sites after VM init owns load.

- [ ] **Step 2: Update `LayoutMenu` preview**

```swift
#Preview {
    let deps = AppDependencies.preview()
    let viewModel = HomeViewModel(
        preferences: deps.preferencesStore,
        repository: deps.albumRepository,
        backup: deps.albumBackupService
    )
    LayoutMenu(viewModel: viewModel)
    // ... environment on ListLayout/GridLayout using viewModel.store
}
```

- [ ] **Step 3: Update `ContentView.swift`**

```swift
struct ContentView: View {
    let dependencies: AppDependencies
    @State private var viewModel: AuthViewModel
    @State private var homeViewModel: HomeViewModel
    @Environment(\.openURL) private var openURL

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        _viewModel = State(
            initialValue: AuthViewModel(authorization: dependencies.musicAuthorization)
        )
        _homeViewModel = State(
            initialValue: HomeViewModel(
                preferences: dependencies.preferencesStore,
                repository: dependencies.albumRepository,
                backup: dependencies.albumBackupService
            )
        )
    }

    var body: some View {
        Group {
            switch viewModel.state {
            case .authorized:
                HomePageView(viewModel: homeViewModel, dependencies: dependencies)
            // ... denied, loading unchanged
            }
        }
        .task { await viewModel.checkAuthorization() }
    }
}
```

Remove inline `AlbumStore(...)` construction in authorized branch.

- [ ] **Step 4: Run full test suite**

Run:

```bash
bundle exec fastlane ci_tests
```

Expected: PASS (all unit tests + build)

- [ ] **Step 5: Commit**

```bash
git add MusicWall/LayoutViews.swift MusicWall/Features/Auth/ContentView.swift
git commit -m "refactor(home): Wire ContentView and LayoutMenu to HomeViewModel"
```

---

### Task 6: Docs + PR hygiene

**Files:**
- Modify: `Agent.md`

- [ ] **Step 1: Update `Agent.md`**

Add under architecture / MVVM notes:

- Home screen orchestration: `HomeViewModel` in `Features/Home/`
- `HomePageView` is thin; no direct `albumBackupService` calls

- [ ] **Step 2: Verify acceptance criteria**

Manual checklist from spec:

- [ ] `HomePageView` has no `albumBackupService` usage (grep)
- [ ] `HomeViewModelTests` pass without SwiftUI hosting
- [ ] Previews compile

Run:

```bash
rg 'albumBackupService' MusicWall/Features/Home MusicWall/HomePageView.swift 2>/dev/null || true
```

Expected: no matches in `HomePageView`

- [ ] **Step 3: Commit**

```bash
git add Agent.md
git commit -m "docs: Note HomeViewModel in Agent.md"
```

---

## Spec coverage checklist

| Spec requirement | Task |
|------------------|------|
| `HomeViewModel` owns `AlbumStore` | Task 3 |
| Layout load/save via VM | Task 3, 5 |
| Sort via VM | Task 3, 4 |
| Export/import via `AlbumBackupService` | Task 3 |
| Snackbar messages / empty export copy | Task 3 |
| Thin `HomePageView`, no backup calls | Task 4 |
| `ContentView` creates VM | Task 5 |
| `HomeViewModelTests` matrix | Task 2–3 |
| `MockAlbumBackupService` | Task 1 |
| Move to `Features/Home/` | Task 4 |

## Human verification (PR description)

| Scenario | Expected |
|----------|----------|
| Export with albums | Share sheet |
| Export empty library | "No albums to export" |
| Import valid backup | Success count snackbar |
| Import invalid file | Import failed snackbar |
| Sort + layout | Persists across relaunch |
| Add from search | Success snackbar |

## PR delivery

- Branch: `cursor/test-refactor-pr-09-home-vm`
- PR title: `test refactor PR 9: HomeViewModel`
- Link spec + plan; note simulator export/import QA

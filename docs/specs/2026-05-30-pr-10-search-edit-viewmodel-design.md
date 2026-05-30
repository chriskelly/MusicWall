# PR 10 — Search + Edit ViewModels

**Status:** Approved (2026-05-30)  
**Program:** MusicWall testability refactor  
**Requires:** PR 5 merged  
**Blocks:** PR 12  
**Approach:** View-owned VMs (Option 1) + `async let` parallel search (Option 1) + inline `errorMessage` (Option A) + trim-aware `canSave` (Option A) + partial results on parallel failure (Option A) + `makeSavedRecord()` save API (Option 1)

## Summary

Extract **`SearchViewModel`** and **`AlbumEditViewModel`** from `AlbumSearchView` and `AlbumEditView`. Replace `print(error)` in the search path with an inline **`errorMessage`** in the search sheet. Run catalog and library searches in parallel via `AlbumRepository`, reporting partial results when one source fails. Move trim/validation logic for album edits into **`AlbumEditViewModel`** with trim-aware save disabling. Views become thin SwiftUI shells with bindings; unit tests cover search orchestration and edit save output without SwiftUI hosting.

## Goals

- No `print(error)` in search path; user-visible errors via `errorMessage`.
- Parallel catalog + library search with independent per-source error handling.
- `SearchViewModelTests`: empty query, mock returns, mock errors, dual search, partial failure.
- `AlbumEditViewModelTests`: trim rules, whitespace-only validation, release-date toggle, saved `AlbumRecord` output.
- `AlbumSearchView` keeps `onSelect: (AlbumRecord) -> Void` at sheet boundary; no `MusicKit.Album` in search view layer.
- Move search/edit files under `Features/Search/` and `Features/Edit/`.
- Follow PR 8–9 VM conventions: `@MainActor`, `@Observable`, constructor injection.

## Non-goals

- Grid/list layout refactor (PR 11).
- Introducing `AlbumRepository` or migrating off `AlbumRecord` (PR 5 done).
- Search errors via snackbar or propagation to `HomeViewModel`.
- `AlbumTapCoordinator` or playback changes (PR 11).
- ViewInspector / snapshot tests (PR 12).
- Changing add-album flow beyond thin search sheet wiring.

## Decisions (brainstorming)

| Topic | Choice |
|-------|--------|
| Search error UX | Inline `errorMessage` text in search sheet (not snackbar) |
| Edit save validation | Trim-aware: disable Save when trimmed title or artist is empty |
| Parallel search failure | Partial results: show successful source; `errorMessage` names failed source(s) |
| VM ownership | View-owned `@State` VM created in view `init` from injected dependencies |
| Parallel implementation | Two `async let` calls with per-source `do/catch` |
| Edit save API | `canSave` + `makeSavedRecord()`; view calls `onSave` + `dismiss` |

## Approaches considered

### ViewModel ownership

| Option | Description | Why not chosen |
|--------|-------------|----------------|
| **1 (chosen)** | Sheet view owns VM via `@State` in `init` | Matches PR 8 `AuthViewModel`; parent stays unaware of sheet VM lifecycle |
| 2 | Parent creates and passes VM | Extra wiring in `HomePageView` / `LayoutContainer` |
| 3 | VMs on `AppDependencies` | Wrong lifetime for sheet-scoped state |

### Parallel search implementation

| Option | Description | Why not chosen |
|--------|-------------|----------------|
| **1 (chosen)** | `async let` + per-source `do/catch` | Simple; maps cleanly to partial-failure UX |
| 2 | `withThrowingTaskGroup` | More boilerplate for two fixed sources |
| 3 | Sequential (current) | Slower; skill requires parallel |

### Search error presentation

| Option | Description | Why not chosen |
|--------|-------------|----------------|
| **A (chosen)** | Inline `errorMessage` in search sheet | Self-contained sheet; matches PR 10 skill |
| B | Snackbar inside search sheet | Overlays results; inconsistent with home snackbar channel |
| C | Dismiss sheet; snackbar on home | Couples search errors to `HomeViewModel` |

### Edit save validation

| Option | Description | Why not chosen |
|--------|-------------|----------------|
| **A (chosen)** | Trim-aware `canSave` | Prevents whitespace-only saves; matches skill intent |
| B | Literal empty check only | Allows `"   "` to save after silent trim |

### Edit save API

| Option | Description | Why not chosen |
|--------|-------------|----------------|
| **1 (chosen)** | `makeSavedRecord() -> AlbumRecord` | Testable; VM has no SwiftUI dismiss dependency |
| 2 | VM owns `onSave` closure | Side effects in VM; harder to unit test |
| 3 | `save() -> AlbumRecord?` | Awkward for validation that is already gated by `canSave` |

## Architecture

### Layer placement

```
MusicWall/
  Features/Search/
    SearchViewModel.swift
    AlbumSearchView.swift              # moved from MusicWall/
  Features/Edit/
    AlbumEditViewModel.swift
    AlbumEditView.swift                # moved from MusicWall/
  Features/Home/
    HomePageView.swift                 # sheet wiring only
  LayoutViews.swift                    # edit sheet wiring only

MusicWallTests/
  Features/Search/
    SearchViewModelTests.swift
  Features/Edit/
    AlbumEditViewModelTests.swift
  TestSupport/
    MockAlbumRepository.swift          # unchanged
```

Delete `MusicWall/AlbumSearchView.swift` and `MusicWall/AlbumEditView.swift` after move (filesystem-synced group picks up new paths).

### Data flow — search

```
HomePageView.sheet(showingAddView)
  └─ AlbumSearchView(repository:onSelect:)
       ├─ @State viewModel = SearchViewModel(repository:)
       ├─ TextField ↔ viewModel.query
       ├─ Button("Search") → viewModel.search()
       ├─ ProgressView when viewModel.isSearching
       ├─ Text(errorMessage) when non-nil (inline, below search controls)
       └─ List ← viewModel.libraryResults / catalogResults
            └─ SearchResultButton → onSelect(record) → dismiss
                 └─ HomePageView.onSearchSelect → store.addAlbum + albumAdded snackbar
```

Search errors stay in the sheet. Add-album success snackbar remains on `HomeViewModel.albumAdded()`.

### Data flow — edit

```
LayoutContainer.sheet(editingAlbum)
  └─ AlbumEditView(album:onSave:)
       ├─ @State viewModel = AlbumEditViewModel(album:)
       ├─ TextField title/artist ↔ viewModel
       ├─ release-date toggle ↔ viewModel.setReleaseDateEnabled(_:)
       ├─ DatePicker when releaseDate != nil
       ├─ Save disabled when !viewModel.canSave
       └─ Save → onSave(viewModel.makeSavedRecord()) → dismiss
            └─ store.updateAlbum(updatedAlbum)
```

### Dependency rules

| Unit | May import |
|------|------------|
| `SearchViewModel`, `AlbumEditViewModel` | Foundation, Observation |
| `AlbumSearchView`, `AlbumEditView` | SwiftUI |
| Tests | `@testable import MusicWall` |

No MusicKit imports in Features/Search or Features/Edit.

## SearchViewModel

```swift
@MainActor
@Observable
final class SearchViewModel {
    var query = ""
    private(set) var catalogResults: [AlbumRecord] = []
    private(set) var libraryResults: [AlbumRecord] = []
    private(set) var isSearching = false
    var errorMessage: String?

    private let repository: any AlbumRepository

    init(repository: any AlbumRepository)

    func search() async
}
```

### `search()` behavior

| Step | Behavior |
|------|----------|
| Empty query | No-op: do not set `isSearching`; do not call repository; leave prior results/errors unchanged |
| Start | `isSearching = true`; `errorMessage = nil` |
| Parallel fetch | `async let catalogTask = repository.search(query:query, source:.catalog)` and `async let libraryTask = repository.search(query:query, source:.library)` |
| Catalog catch | On failure: `catalogResults = []`; append `"Apple Music: \(error.localizedDescription)"` to error parts |
| Catalog success | Assign `catalogResults` |
| Library catch | On failure: `libraryResults = []`; append `"Library: \(error.localizedDescription)"` to error parts |
| Library success | Assign `libraryResults` |
| Finish | `isSearching = false`; `errorMessage = errorParts.joined(separator: "\n")` if any failures, else `nil` |

Errors map via `LocalizedError` / `error.localizedDescription`. Repository throws `AlbumRepositoryError` — no `MusicServiceError` mapping in VM.

### Preview helper

```swift
extension SearchViewModel {
    static func preview(dependencies: AppDependencies) -> SearchViewModel {
        SearchViewModel(repository: dependencies.albumRepository)
    }
}
```

Optional: pre-seed `catalogResults` / `libraryResults` in preview via mock repository handlers.

## AlbumSearchView

Move to `MusicWall/Features/Search/AlbumSearchView.swift`.

### Init

```swift
init(repository: any AlbumRepository, onSelect: @escaping (AlbumRecord) -> Void) {
    self.onSelect = onSelect
    _viewModel = State(initialValue: SearchViewModel(repository: repository))
}
```

Keep `onSelect: (AlbumRecord) -> Void` at view boundary (unchanged contract for `HomePageView`).

### Removed from view

- `@State catalogSearchResults`, `librarySearchResults`, `isSearching`
- `searchAlbums()` async function
- `print(error.localizedDescription)`

### Retained in view

- `@FocusState isSearchFieldFocused` — keyboard dismiss on Search tap
- `SearchResultButton` nested struct with `@Environment(\.dismiss)`, explicit badge via `record.isExplicit`
- Navigation title `"Find Album"`, section headers `"Library"` / `"Apple Music"`

### Error presentation

When `viewModel.errorMessage != nil`, show below search button / progress indicator:

```swift
if let message = viewModel.errorMessage {
    Text(message)
        .font(.footnote)
        .foregroundStyle(.red)
        .multilineTextAlignment(.center)
        .padding(.horizontal)
}
```

### HomePageView wiring

```swift
.sheet(isPresented: $showingAddView) {
    AlbumSearchView(
        repository: dependencies.albumRepository,
        onSelect: onSearchSelect
    )
}
```

Signature unchanged; VM created inside `AlbumSearchView`.

## AlbumEditViewModel

```swift
@MainActor
@Observable
final class AlbumEditViewModel {
    var title: String
    var artistName: String
    var releaseDate: Date?

    private let album: AlbumRecord

    init(album: AlbumRecord) {
        self.album = album
        self.title = album.title
        self.artistName = album.artistName
        self.releaseDate = album.releaseDate
    }

    var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !artistName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func setReleaseDateEnabled(_ enabled: Bool)
    func makeSavedRecord() -> AlbumRecord
}
```

### `setReleaseDateEnabled`

| Input | Action |
|-------|--------|
| `true` | `releaseDate = album.releaseDate ?? Date()` |
| `false` | `releaseDate = nil` |

Matches current toggle behavior in `AlbumEditView`.

### `makeSavedRecord`

```swift
AlbumRecord(
    id: album.id,
    title: title.trimmingCharacters(in: .whitespacesAndNewlines),
    artistName: artistName.trimmingCharacters(in: .whitespacesAndNewlines),
    releaseDate: releaseDate,
    isExplicit: album.isExplicit
)
```

Precondition: caller only invokes when `canSave` is true (Save button gated in view).

## AlbumEditView

Move to `MusicWall/Features/Edit/AlbumEditView.swift`.

### Init

```swift
init(album: AlbumRecord, onSave: @escaping (AlbumRecord) -> Void) {
    self.onSave = onSave
    _viewModel = State(initialValue: AlbumEditViewModel(album: album))
}
```

### Removed from view

- `@State title`, `artistName`, `releaseDate` (owned by VM)
- `saveAlbum()` private method
- Inline trim logic and literal empty checks on Save disabled

### Retained in view

- `@Environment(\.dismiss)` for Cancel / Save dismiss
- Form sections, navigation title, toolbar Cancel/Save
- Save: `onSave(viewModel.makeSavedRecord()); dismiss()`
- Save disabled: `.disabled(!viewModel.canSave)`

### LayoutViews wiring

```swift
.sheet(item: $editingAlbum) { album in
    AlbumEditView(album: album) { updatedAlbum in
        store.updateAlbum(updatedAlbum)
    }
}
```

Signature unchanged; VM created inside `AlbumEditView`.

## Testing

### Framework

Swift Testing (consistent with PR 1–9). All VM tests on `@MainActor`.

### `SearchViewModelTests`

Use `MockAlbumRepository`. Set `searchHandler` per source or inspect `searchCalls`.

| Test | Setup | Assert |
|------|-------|--------|
| `search_emptyQuery_doesNotCallRepository` | `query = ""` | `await search()` → `searchCalls.isEmpty`; `isSearching == false` |
| `search_success_populatesBothResultLists` | Handlers return distinct `[AlbumRecord]` per source | Both lists populated; `errorMessage == nil`; `isSearching == false` after |
| `search_bothFail_clearsResultsAndSetsErrorMessage` | Both handlers throw | Both lists empty; `errorMessage` contains `"Apple Music:"` and `"Library:"` |
| `search_catalogFails_showsPartialResults` | Catalog throws; library returns records | `catalogResults == []`; library populated; `errorMessage` contains `"Apple Music:"` only |
| `search_libraryFails_showsPartialResults` | Library throws; catalog returns records | `libraryResults == []`; catalog populated; `errorMessage` contains `"Library:"` only |
| `search_repositoryError_usesLocalizedDescription` | Throw `AlbumRepositoryError.networkError("offline")` | Message includes localized description |
| `search_setsIsSearchingDuringFetch` | Slow handler or inspection mid-flight | `isSearching == true` before completion (optional timing test) |

Verify parallel calls: both `.catalog` and `.library` appear in `searchCalls` for a single `search()` invocation.

### `AlbumEditViewModelTests`

Use `AlbumFixtures.record(...)` or test fixture album.

| Test | Setup | Assert |
|------|-------|--------|
| `canSave_whitespaceOnlyTitle_isFalse` | `title = "   "` | `canSave == false` |
| `canSave_whitespaceOnlyArtist_isFalse` | `artistName = "\t\n"` | `canSave == false` |
| `canSave_validFields_isTrue` | Non-empty trimmed fields | `canSave == true` |
| `makeSavedRecord_trimsWhitespace` | `title = "  Abbey Road  "` | Saved title `"Abbey Road"` |
| `makeSavedRecord_preservesIdAndExplicit` | Edit title only | `id`, `isExplicit` unchanged |
| `setReleaseDateEnabled_true_usesExistingOrNow` | Album with/without `releaseDate` | Correct date assignment |
| `setReleaseDateEnabled_false_clearsDate` | Enable then disable | `releaseDate == nil` |

### Unchanged tests

- `AlbumRepositoryTests`, `MockAlbumRepository` consumers in other features
- `HomeViewModelTests` — add-album path unchanged at home boundary

### Smoke

- `#Preview` on `AlbumSearchView` and `AlbumEditView` compile with `AppDependencies.preview()`
- App builds; `ci-tests` green

### Human verification (PR description)

| Scenario | Expected |
|----------|----------|
| Search with results | Library + Apple Music sections populate |
| Search network failure (one source) | Other section shows results; red inline error names failed source |
| Search empty query + tap Search | No spinner; no repository call |
| Edit album, whitespace title | Save disabled |
| Edit album, trim fields, Save | Store shows trimmed values |
| Add from search | Home snackbar unchanged |

## Acceptance criteria

- [ ] `SearchViewModel` in `MusicWall/Features/Search/`; parallel catalog + library search.
- [ ] No `print(error)` in search path; inline `errorMessage` in search sheet.
- [ ] Partial results on parallel failure with per-source error labels.
- [ ] `AlbumEditViewModel` in `MusicWall/Features/Edit/`; trim-aware `canSave`.
- [ ] `makeSavedRecord()` produces expected `AlbumRecord` in tests.
- [ ] `AlbumSearchView` / `AlbumEditView` are thin bindings; `onSelect` / `onSave` boundaries unchanged.
- [ ] No `MusicKit.Album` in search view layer.
- [ ] `SearchViewModelTests` and `AlbumEditViewModelTests` pass without SwiftUI hosting.
- [ ] App compiles; `ci-tests` green.

## PR delivery

- Branch from `main`: `cursor/test-refactor-pr-10-search-edit-vm` (or team convention).
- Move `AlbumSearchView.swift` → `Features/Search/`; add `SearchViewModel.swift`.
- Move `AlbumEditView.swift` → `Features/Edit/`; add `AlbumEditViewModel.swift`.
- Register new test files in `project.pbxproj` (mirror `HomeViewModelTests.swift`).
- PR description: link “PR 10 of 14”; note device/simulator search QA.

## Follow-on PRs

| PR | Relationship |
|----|--------------|
| PR 11 | Grid/list layout; search/edit VMs unchanged |
| PR 12 | ViewInspector tests against thin search/edit views |
| PR 13 | UI tests; add-album flow via search sheet |
| PR 14 | Coverage gates on search/edit VMs |

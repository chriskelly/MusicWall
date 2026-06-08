# Empty albums welcome screen

**Status:** Approved (2026-06-07)  
**Program:** MusicWall UX — first-run / empty-collection guidance  
**Requires:** PR 9 merged (`HomeViewModel`, `HomePageView` in `Features/Home/`)  
**Blocks:** None  
**Approach:** Inline empty state (Option A) + welcome CTAs for add/import + warmer copy + toolbar unchanged

## Summary

When the user is authorized and `AlbumStore.items` is empty, replace the blank grid/list with an inline **welcome view** that explains MusicWall in warm, playful language and offers two actions: **add an album** (opens the existing search sheet) and **import a backup** (opens the existing file importer). When the first album is added (or import succeeds), the welcome view disappears and the normal grid/list layout appears.

No first-launch-only flag, no auto-presented search sheet, and no toolbar changes for v1 — shuffle, sort, layout, and backup export remain available exactly as today.

## Goals

- First-time and zero-album users see intentional guidance instead of a blank gray home screen.
- Primary path to value: **Add an album** → existing `AlbumSearchView` sheet.
- Secondary path: **Import a backup** → existing `fileImporter` flow and `HomeViewModel.importAlbums`.
- Copy tone is **warmer and playful**, aligned with the “album wall” / vinyl metaphor used elsewhere (e.g. CarPlay setup copy).
- Welcome disappears automatically when `store.items` becomes non-empty.
- Avoid a flash of welcome content before async `store.load()` completes.
- Accessibility identifiers for UI tests on welcome CTAs and container.

## Non-goals

- Full-screen onboarding or `hasSeenWelcome` persistence (Option B/C from brainstorm).
- Auto-opening the search sheet on first empty load (Option D).
- Hiding or disabling toolbar controls when empty (shuffle, sort, layout, export stay as-is).
- New assets or custom illustrations (SF Symbols only for v1).
- CarPlay template changes.
- Core / adapter changes (`AlbumStore`, `AlbumLibraryLoader`, backup codec unchanged).
- Localization strings file — inline English copy in the view (consistent with existing app strings).

## Decisions (brainstorming)


| Topic        | Choice                                                                                                    |
| ------------ | --------------------------------------------------------------------------------------------------------- |
| Presentation | **Option A** — inline empty state inside `HomePageView`, not a separate navigation destination            |
| CTAs         | **Add album** + **Import backup** buttons on the welcome view                                             |
| Toolbar      | **Leave as-is** — no conditional hide/disable for shuffle, sort, layout, or export                        |
| Copy tone    | **Warmer / playful** — vinyl wall metaphor, friendly encouragement                                        |
| Load gate    | `**hasLoaded`** on `HomeViewModel` — show progress until first `load()` completes                         |
| Visual       | `**ContentUnavailableView**` (iOS 17+) with SF Symbol; custom layout acceptable if needed for two buttons |


## Approaches considered

### Empty-state placement


| Option         | Description                                           | Why not chosen                                                                             |
| -------------- | ----------------------------------------------------- | ------------------------------------------------------------------------------------------ |
| **A (chosen)** | Branch in `HomePageView.layoutView()` when empty      | Minimal scope; reuses existing sheets/importer; no new navigation stack                    |
| B              | Dedicated `WelcomeView` with first-launch persistence | Extra preference key; wrong experience when user deletes last album unless combined with A |
| C              | Auto-present search sheet                             | Pushy; skips explaining the home screen                                                    |
| D              | Empty state inside `GridLayout` / `ListLayout`        | Duplicated logic across layouts; harder to test as one surface                             |


### Toolbar when empty


| Option                   | Description          | Why not chosen                                                     |
| ------------------------ | -------------------- | ------------------------------------------------------------------ |
| **Leave as-is (chosen)** | Full toolbar visible | Reduces complexity; shuffle/sort are harmless no-ops on empty data |
| Hide shuffle/sort        | Conditional toolbar  | More branching; deferred to a follow-up if users report confusion  |


## Architecture

### Layer placement

```
MusicWall/
  Features/Home/
    HomeViewModel.swift          # + isEmpty, hasLoaded
    HomePageView.swift           # branch layoutView(); pass callbacks to welcome
    EmptyAlbumsView.swift        # new — welcome UI only

MusicWallTests/
  Features/Home/
    HomeViewModelTests.swift     # + hasLoaded / isEmpty cases
    EmptyAlbumsViewTests.swift   # ViewInspector — optional but recommended

MusicWallUITests/
  MusicWallUITests.swift         # + empty collection smoke test

MusicWall/UITestSupport/
  UITestLoadScenario.swift       # + emptyCollection case
  AppDependencies.swift          # seed empty prefs for emptyCollection
```

### Data flow

```
HomePageView.task
  └─ await viewModel.load()
       └─ store.load() → sync items
       └─ hasLoaded = true

HomePageView.layoutView()
  ├─ !viewModel.hasLoaded → ProgressView (centered)
  ├─ viewModel.isEmpty     → EmptyAlbumsView(onAddAlbum:, onImport:)
  └─ else                  → GridLayout | ListLayout (unchanged)

EmptyAlbumsView — Add album
  └─ onAddAlbum() → showingAddView = true → AlbumSearchView sheet (existing)

EmptyAlbumsView — Import backup
  └─ onImport() → showingFileImporter = true → fileImporter → viewModel.importAlbums (existing)

First album added / import success
  └─ store.items non-empty → isEmpty false → layout switches with animation (view wraps branch in withAnimation if needed)
```

### Dependency rules


| Unit              | May import                                                 |
| ----------------- | ---------------------------------------------------------- |
| `EmptyAlbumsView` | SwiftUI only                                               |
| `HomeViewModel`   | Foundation, Observation (no SwiftUI)                       |
| `HomePageView`    | SwiftUI, UIKit (`ShareSheet` only)                         |
| Tests             | `@testable import MusicWall`, ViewInspector for view tests |


## Domain / ViewModel

### `HomeViewModel` additions

```swift
private(set) var hasLoaded = false

var isEmpty: Bool {
    store.items.isEmpty
}
```

`**load()**` — after existing `await store.load()` body completes successfully, set `hasLoaded = true`. If `store.load()` throws or fails internally, still set `hasLoaded = true` so the user sees the welcome (empty) rather than an infinite spinner; today `load()` does not surface errors to the VM.

No new persistence keys. `isEmpty` is derived from `store.items` only.

## EmptyAlbumsView

New file: `MusicWall/Features/Home/EmptyAlbumsView.swift`.

### Layout

- Centered content in the existing `NavigationStack` body (same gray background as grid/list via parent `.background(Color(.systemGray6))`).
- Use `ContentUnavailableView` as the base, or a `VStack` with equivalent spacing if two prominent buttons do not fit the default `ContentUnavailableView` action slot cleanly.
- **Icon:** SF Symbol `opticaldisc` or `square.grid.3x3.fill` (prefer `opticaldisc` for vinyl/playful tone).
- **Two buttons**, visually distinct:
  - Primary: filled / prominent style — add album
  - Secondary: bordered or plain — import backup
- Support Dynamic Type: multiline text alignment, avoid fixed heights that clip large content sizes.

### Copy (approved strings)


| Element          | Text                                                                                                                    |
| ---------------- | ----------------------------------------------------------------------------------------------------------------------- |
| Title            | **Get started on your Music Wall!**                                                                                     |
| Description      | **Every great collection starts with one great album. Search Apple Music, or restore your albums if you're returning.** |
| Primary button   | **Add an album**                                                                                                        |
| Secondary button | **Import a backup**                                                                                                     |


Voice notes for implementers: conversational, lightly playful, no exclamation overload.

### Callbacks

```swift
struct EmptyAlbumsView: View {
    let onAddAlbum: () -> Void
    let onImport: () -> Void
    // ...
}
```

No `@Environment` repository access — parent owns sheet/importer state (matches `HomePageView` pattern).

### Accessibility identifiers


| Identifier                   | Element                                                                  |
| ---------------------------- | ------------------------------------------------------------------------ |
| `home.emptyWelcome`          | Root container (e.g. outer `VStack` or `ContentUnavailableView` wrapper) |
| `home.emptyWelcome.addAlbum` | Primary button                                                           |
| `home.emptyWelcome.import`   | Secondary button                                                         |


Existing toolbar add button keeps `home.addAlbum` — welcome button is a separate, easier tap target for empty state tests.

## HomePageView changes

### `layoutView()`

```swift
private func layoutView() -> some View {
    Group {
        if !viewModel.hasLoaded {
            ProgressView()
        } else if viewModel.isEmpty {
            EmptyAlbumsView(
                onAddAlbum: { showingAddView = true },
                onImport: { showingFileImporter = true }
            )
        } else {
            switch viewModel.currentLayout {
            case .grid: GridLayout()
            case .list: ListLayout()
            }
        }
    }
}
```

Wrap the empty ↔ non-empty transition in animation: `loadedContentView()` uses `.animation(.default, value: viewModel.isEmpty)`; `onSearchSelect` wraps `addAlbum` in `withAnimation`.

### Unchanged

- Navigation title **"My Albums"**
- Toolbar: options menu, shuffle, add (`home.addAlbum`)
- `.task { await viewModel.load() }`
- Search sheet, file importer, export share sheet, snackbar binding
- `.environment(viewModel.store)` and repository/playback/artwork environment

## Previews

Add to `EmptyAlbumsView.swift`:

```swift
#Preview {
    EmptyAlbumsView(onAddAlbum: {}, onImport: {})
}
```

Add to `HomePageView.swift`:

```swift
#Preview("Empty") {
    let deps = AppDependencies.preview()
    let viewModel = HomeViewModel(
        preferences: deps.preferencesStore,
        repository: deps.albumRepository,
        backup: deps.albumBackupService
    )
    // Do not seed albums; mark loaded for preview
    viewModel.markLoadedForPreview() // test-only or package-visible helper, OR
    // run load in preview task with empty prefs
    HomePageView(viewModel: viewModel, dependencies: deps)
}
```

Prefer a package-visible `static func previewEmpty(dependencies:)` on `HomeViewModel` that constructs VM with empty store and `hasLoaded = true`, mirroring `HomeViewModel.preview(dependencies:)` which seeds dummy data.

## UI test support

### New load scenario: `emptyCollection`

Extend `UITestLoadScenario`:

```swift
case emptyCollection
```

**Seeding:** Isolated UserDefaults with no `.albumRecordsItems` and no `.backupAlbumIDs` (or explicit empty arrays). Mock auth remains authorized. `store.load()` yields empty `items`.

**Launch arguments:** `-UITestMockMusic` + `-UITestLoadScenario emptyCollection`

### New smoke test


| Test                                                | Steps                         | Assert                                                                                                                |
| --------------------------------------------------- | ----------------------------- | --------------------------------------------------------------------------------------------------------------------- |
| `testLaunch_emptyCollection_showsWelcomeAndAddFlow` | Launch with `emptyCollection` | `home.emptyWelcome` exists; tap `home.emptyWelcome.addAlbum`; search field or `search.cancel` visible; dismiss search |


Import flow UI test is optional for v1 (file importer is hard to automate in XCUITest); manual verification covers import from welcome.

Document `emptyCollection` in `MusicWallTests/Agent.md` launch-argument table.

## Testing

### `HomeViewModelTests`


| Test                         | Setup                                               | Assert                                   |
| ---------------------------- | --------------------------------------------------- | ---------------------------------------- |
| `isEmpty_trueWhenStoreEmpty` | Fresh VM, empty store                               | `isEmpty == true`                        |
| `isEmpty_falseAfterAddAlbum` | Add one record                                      | `isEmpty == false`                       |
| `load_setsHasLoaded`         | Call `await load()`                                 | `hasLoaded == true`                      |
| `isEmpty_falseAfterImport`   | Mock backup returns IDs; repository returns records | After `importAlbums`, `isEmpty == false` |


Use existing `InMemoryPreferencesStore`, `MockAlbumRepository`, `MockAlbumBackupService`.

### `EmptyAlbumsViewTests` (ViewInspector)


| Test                             | Assert                             |
| -------------------------------- | ---------------------------------- |
| `rendersTitleAndDescription`     | Title and description text present |
| `addAlbumButton_invokesCallback` | Tap triggers `onAddAlbum`          |
| `importButton_invokesCallback`   | Tap triggers `onImport`            |


Follow patterns from existing ViewInspector tests (e.g. `SortMenu`, `SnackbarView`).

### Unchanged

- Grid/list layout tests, tap coordinator, backup codec, `AlbumLibraryLoaderTests`
- Existing UI tests for `savedLibrary` and `restoreFromBackup` scenarios

## Human verification (PR description)


| Scenario                             | Expected                                                                       |
| ------------------------------------ | ------------------------------------------------------------------------------ |
| Fresh install, authorized, no albums | After brief load, welcome with copy and two buttons; toolbar unchanged         |
| Tap **Add an album** on welcome      | Search sheet opens; same as toolbar +                                          |
| Tap **Import a backup** on welcome   | System file picker opens; successful import shows count snackbar and grid/list |
| Add first album from search          | Welcome animates away; album appears in grid/list                              |
| Delete last album                    | Welcome returns                                                                |
| Relaunch with saved albums           | No welcome; normal home                                                        |
| Dynamic Type (large)                 | Welcome text and buttons remain readable                                       |
| VoiceOver                            | Title, description, and both buttons are focusable with sensible labels        |


## Acceptance criteria

- `EmptyAlbumsView` in `MusicWall/Features/Home/` with approved copy and SF Symbol.
- `HomeViewModel` exposes `isEmpty` and `hasLoaded`; `load()` sets `hasLoaded` after completion.
- `HomePageView` shows progress until loaded, welcome when empty, grid/list otherwise.
- Welcome **Add an album** opens existing search sheet; **Import a backup** opens existing file importer.
- Toolbar behavior unchanged when empty.
- Accessibility identifiers: `home.emptyWelcome`, `home.emptyWelcome.addAlbum`, `home.emptyWelcome.import`.
- `#Preview` for empty home compiles.
- `HomeViewModelTests` cover `isEmpty` and `hasLoaded`.
- ViewInspector tests for `EmptyAlbumsView` (or documented skip with rationale).
- UI test: `emptyCollection` scenario shows welcome and add flow.
- `MusicWallTests/Agent.md` updated with `emptyCollection` scenario.
- App compiles; `ci-tests` green.

## PR delivery

- Branch from `main`: e.g. `feature/empty-albums-welcome`.
- Single focused PR; link this spec in the description.
- No changes to `DEVELOPMENT_TEAM`, bundle ID, or entitlements.
- Human verification on simulator or TestFlight: empty welcome, add flow, import flow, delete-last-album regression.

## Follow-on (out of scope)

- Hide shuffle/sort when empty if user feedback warrants it.
- Richer hero animation (vinyl spin) on welcome.
- Localized strings (`Localizable.strings`).
- UI test for import via welcome (document picker automation).


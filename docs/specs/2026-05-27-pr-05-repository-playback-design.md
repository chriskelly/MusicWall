# PR 5 — AlbumRepository + PlaybackController

**Status:** Approved (2026-05-27)  
**Program:** MusicWall testability refactor  
**Requires:** PR 4 merged  
**Blocks:** PR 6, PR 10, PR 11  
**Approach:** Hybrid injection (Option 3) + full search domain migration (Option A) + `artworkURL` on repository until PR 11

## Summary

Replace the static `MusicService` enum with Core protocols (`AlbumRepository`, `PlaybackController`), MusicKit adapters (`MusicKitAlbumRepository`, `SystemMusicPlayerAdapter`, `AlbumMapper`), and hybrid dependency injection via `AppDependencies` plus SwiftUI environment keys for deep views. Migrate all call sites—including `AlbumSearchView` and `ImageCache`—so no `MusicService.` references remain outside adapters. Extend `AlbumRecord` with `isExplicit`. Remove `StoredAlbum.play()` / `pause()`; wire tap-to-play through `PlaybackController`.

## Goals

- Core protocols and domain errors are Foundation-only and unit-testable with mocks.
- `MusicKitAlbumRepository` owns all MusicKit request types; `AlbumMapper` is the only `MusicKit.Album` → `AlbumRecord` mapping.
- `AppDependencies.live` / `.preview()` register live adapters and test doubles.
- Zero `MusicService.` call sites outside `MusicWall/Adapters/` (then delete `MusicService.swift`).
- Fix `playAlbum` force-unwrap: `SystemMusicPlayerAdapter` uses `guard` + `AlbumRepositoryError.albumNotFound`.
- Tests: `MockAlbumRepository`, `MockPlaybackController`; repository error mapping; empty query/IDs; tap play/pause call order.

## Non-goals

- `AlbumCollection.load()` persistence redesign or `StoredAlbum` JSON migration (PR 6).
- `SearchViewModel` / snackbar error UX (PR 10)—search may still `print` errors in PR 5.
- `AlbumTapCoordinator` extraction (PR 11)—inline `onAlbumTapped` uses `PlaybackController` only.
- Full `ArtworkProvider` + injected `URLSession` / `FileManager` (PR 11).
- ViewModels for home/auth (PR 8–9).
- SPM module split (PR 15).

## Approaches considered

| Option | Description | Why not chosen |
|--------|-------------|----------------|
| **A (chosen)** | Hybrid: `AppDependencies` + environment for leaf views; constructor injection for facades/sheets | Matches PR 3 composition root; avoids `StoredAlbums` ↔ SwiftUI coupling |
| B | Explicit parameters only, no environment keys | Parameter creep on every layout; fights deep `AlbumArtwork` / tap handler |
| C | Environment only | Hides dependencies; harder to test `StoredAlbums` without SwiftUI |
| Search defer (B) | Leave `AlbumSearchView` on `MusicService` until PR 10 | Violates no-static-`MusicService` acceptance |
| Search hybrid (C) | Repository returns MusicKit to views | Breaks Core boundary; non-testable UI |

## Architecture

### Layer placement

```
MusicWall/
  Core/
    AlbumRecord.swift              # + isExplicit
    AlbumRepository.swift          # protocol + AlbumSearchSource + AlbumRepositoryError
    PlaybackController.swift       # protocol + PlaybackError
  Adapters/
    AlbumMapper.swift              # MusicKit.Album → AlbumRecord
    MusicKitAlbumRepository.swift
    SystemMusicPlayerAdapter.swift
  App/
    Environment+Services.swift     # @Entry albumRepository, playback (SwiftUI)
  AppDependencies.swift
  Album.swift                      # StoredAlbums(repository:); remove play/pause
  AlbumSearchView.swift            # [AlbumRecord], injected repository
  LayoutViews.swift                # onAlbumTapped + @Environment playback
  ImageCache.swift                 # repository.artworkURL(...)
  ContentView.swift / HomePageView.swift

MusicWallTests/
  Core/
    AlbumRepositoryTests.swift     # via mocks / error cases
  Adapters/
    AlbumMapperTests.swift         # optional; explicit mapping
  TestSupport/
    MockAlbumRepository.swift
    MockPlaybackController.swift
  Features/
    AlbumTapPlaybackTests.swift    # call order on tap helper
```

Delete `MusicWall/MusicService.swift` after logic moves to adapters.

### Dependency rules

| Module / folder | May import |
|-----------------|------------|
| `MusicWall/Core/` | Foundation |
| `MusicWall/Adapters/` | Foundation, MusicKit |
| `Environment+Services.swift` | SwiftUI, Core protocols |
| Views, `StoredAlbums` | SwiftUI, MusicKit only where legacy `StoredAlbum` / `MusicItemID` remain until PR 6 |

### Injection (hybrid)

| Consumer | Mechanism |
|----------|-----------|
| `AppDependencies` | Holds `albumRepository`, `playbackController` (live + preview mocks) |
| `ContentView` | Passes `dependencies` or fields into `HomePageView` |
| `StoredAlbums` | `init(preferences:repository:)` — **not** `@Environment` |
| `AlbumSearchView` | `init(repository:onSelect:)` from sheet |
| `GridLayout` / `ListLayout` / `AlbumArtwork` | `@Environment(\.albumRepository)`, `@Environment(\.playback)` |
| `HomePageView` | Installs environment on authorized subtree after creating `StoredAlbums` |

```swift
// AppDependencies.live
let albumRepository = MusicKitAlbumRepository()
let playbackController = SystemMusicPlayerAdapter(repository: albumRepository)
```

Previews: `AppDependencies.preview()` returns `MockAlbumRepository()` and `MockPlaybackController()`.

## Domain model

### `AlbumRecord` (extend PR 2)

```swift
struct AlbumRecord: Equatable, Sendable {
    let id: AlbumID
    let title: String
    let artistName: String
    let releaseDate: Date?
    let isExplicit: Bool
}
```

- Mapper sets `isExplicit` from `album.contentRating == .explicit` (else `false`).
- Fixtures in `AlbumFixtures` default `isExplicit: false` unless testing badge.

### `AlbumRepository`

```swift
enum AlbumSearchSource: Sendable {
    case catalog
    case library
}

protocol AlbumRepository: Sendable {
    func search(query: String, source: AlbumSearchSource) async throws -> [AlbumRecord]
    func fetch(ids: [AlbumID]) async throws -> [AlbumRecord]
    /// Size-specific artwork URL from MusicKit; nil if album/artwork missing.
    func artworkURL(for id: AlbumID, width: Int, height: Int) async -> URL?
}
```

`artworkURL` exists in PR 5 so `ImageCache` never calls `MusicService`; PR 11 replaces this with `ArtworkProvider` and may remove the method from `AlbumRepository`.

### `PlaybackController`

```swift
protocol PlaybackController: Sendable {
    func play(albumId: AlbumID) async throws
    func pause()
}
```

### Errors (replace `MusicServiceError`)

**`AlbumRepositoryError`** (Core, `LocalizedError`):

| Case | When |
|------|------|
| `invalidQuery` | Empty search query |
| `albumNotFound` | Catalog fetch returned no items |
| `searchFailed(String)` | MusicKit search wrapped |
| `networkError(String)` | Other fetch/search failures |

**`PlaybackError`** (Core):

| Case | When |
|------|------|
| `albumNotFound` | Fetch before play returned empty |
| `playbackFailed(String)` | `SystemMusicPlayer.play()` failure |

Adapters map MusicKit errors to these cases only—views/tests never see MusicKit error types.

## Adapters

### `AlbumMapper`

`static func record(from: MusicKit.Album) -> AlbumRecord` — single mapping for search, fetch, and persistence hydration paths in adapters.

### `MusicKitAlbumRepository`

Move logic from `MusicService.searchAlbums`, `fetchAlbums` (library-first, then catalog). Return `[AlbumRecord]` via mapper.

`artworkURL(for:width:height:)`:

1. `fetch(ids: [id])` internally (or shared private fetch MusicKit album helper).
2. Return `album.artwork?.url(width:height:)` from MusicKit instance before/after map as needed.

Preserve behavior: empty `ids` → `[]`; empty query → `invalidQuery`.

### `SystemMusicPlayerAdapter`

```swift
struct SystemMusicPlayerAdapter: PlaybackController {
    let repository: any AlbumRepository
    // optional player factory for tests
}
```

`play(albumId:)`:

1. `let albums = try await repository.fetch(ids: [albumId])`
2. `guard let record = albums.first else { throw PlaybackError.albumNotFound }`
3. Re-fetch MusicKit album for queue entry **or** add package-internal `fetchMusicKitAlbums` on repository implementation used only by adapter (prefer: repository exposes fetch returning records; adapter uses package-private `MusicKitAlbumRepository.musicKitAlbum(for:)` to avoid double catalog round-trip if needed—implementation may fetch once in adapter via internal helper on `MusicKitAlbumRepository`).

**Implementation note:** Playback requires a `MusicKit.Album` for `SystemMusicPlayer` queue. Acceptable PR 5 approach: `MusicKitAlbumRepository` adds `fileprivate func musicKitAlbum(for id: AlbumID) async throws -> MusicKit.Album` used by `SystemMusicPlayerAdapter` in the same Adapters folder (not on the Core protocol). Keeps protocol Core-clean.

`pause()` → `SystemMusicPlayer.shared.pause()`.

## App changes

### Remove from `StoredAlbum`

- Delete `play()` and `pause()`.
- Keep `init(from: MusicKitAlbum)` until PR 6 removes remaining MusicKit construction at UI boundary.

### `StoredAlbums`

- Add `private let repository: any AlbumRepository`.
- `loadItems()` backup hydration: `try? await repository.fetch(ids: backupIDs.map(AlbumID.init))` then map to records (already `AlbumRecord` from repository—use directly, not `StoredAlbum(from: MusicKit)`).
- `importAlbums(from:)`: `repository.fetch(ids:)` → add records.

### `AlbumSearchView`

- State: `[AlbumRecord]` for catalog and library sections.
- `let repository: any AlbumRepository`
- `onSelect: (AlbumRecord) -> Void`
- Search: `repository.search(query, .catalog)` / `.library`
- UI: show explicit badge when `record.isExplicit`

### `HomePageView`

- `onSearchSelect(_ record: AlbumRecord)` → `StoredAlbum(from: record)` → `addAlbum`
- Pass `dependencies.albumRepository` into sheet.
- Install `.environment(\.albumRepository, …)` and `.environment(\.playback, …)` on navigation content.

### `LayoutViews` — `onAlbumTapped`

Replace model playback with:

```swift
private func onAlbumTapped(
    album: StoredAlbum,
    selectedAlbumIdBinding: Binding<String?>,
    playback: any PlaybackController
) {
    let albumID = AlbumID(rawValue: album.id.rawValue)
    if selectedAlbumIdBinding.wrappedValue == album.id.rawValue {
        playback.pause()
        selectedAlbumIdBinding.wrappedValue = nil
    } else {
        selectedAlbumIdBinding.wrappedValue = album.id.rawValue
        Task {
            do { try await playback.play(albumId: albumID) }
            catch { print(error.localizedDescription) } // PR 10: VM error surface
        }
    }
}
```

Call sites pass `playback` from `@Environment(\.playback)`.

### `ImageCache`

- `init(repository: any AlbumRepository)` (default live from environment at call site).
- Replace `MusicService.fetchAlbums` with `repository.artworkURL(for:width:height:)`.
- Keep disk cache + `URLSession.shared` behavior unchanged.

### `Agent.md`

Optional one-line pointer: album fetch/search/playback via `AlbumRepository` / `PlaybackController` (replace `MusicService` bullet).

## Data flow

```
Search:
  AlbumSearchView → AlbumRepository.search → [AlbumRecord] → onSelect → StoredAlbum(from:) → StoredAlbums.addAlbum

Load backup IDs:
  StoredAlbums.loadItems → AlbumRepository.fetch → [AlbumRecord] → AlbumCollection.replaceAll

Tap play:
  LayoutViews → PlaybackController.play → SystemMusicPlayerAdapter
              → MusicKitAlbumRepository (MusicKit album) → SystemMusicPlayer

Artwork:
  AlbumArtwork → ImageCache(repository:) → AlbumRepository.artworkURL → download/cache
```

## Testing

| Test | Asserts |
|------|---------|
| `MockAlbumRepository` + search | Empty query throws `invalidQuery`; catalog vs library source recorded |
| `MockAlbumRepository` + fetch | Empty ids → `[]`; not found mapping |
| `MockPlaybackController` | `play`/`pause` call counts and order |
| Tap helper / lightweight test | Deselect calls `pause` then clears selection; new tap calls `play` with `AlbumID` |
| `AlbumMapper` (optional) | Explicit flag, field mapping from fixture MusicKit album if testable without device |

Adapter integration with real MusicKit: human QA only (existing program policy).

## Acceptance criteria

- [ ] `AlbumRepository` + `PlaybackController` protocols in `MusicWall/Core/`; Foundation only.
- [ ] `AlbumRecord.isExplicit` mapped in `AlbumMapper`.
- [ ] `MusicKitAlbumRepository`, `SystemMusicPlayerAdapter`, `AlbumMapper` in `MusicWall/Adapters/`.
- [ ] `AppDependencies` exposes repository + playback; preview uses mocks.
- [ ] Environment keys installed from `HomePageView`; facades use constructor injection.
- [ ] No `MusicService.` references; `MusicService.swift` deleted.
- [ ] `StoredAlbum.play` / `pause` removed; tap uses `PlaybackController`.
- [ ] `AlbumSearchView` uses `[AlbumRecord]` and injected repository.
- [ ] `ImageCache` uses `repository.artworkURL` (no `MusicService`).
- [ ] `play` path has no force-unwrap on fetch result.
- [ ] Unit tests for mocks, errors, empty query/IDs, tap call order.
- [ ] `ci-tests` green.

## Human verification (PR description)

- Search catalog + library; explicit badge on explicit albums.
- Tap album to play; tap again to pause.
- Artwork loads on grid/list.
- Restore from backup IDs when items key empty (existing behavior).

## PR delivery

- Branch: `cursor/test-refactor-pr-05-repository-playback` (or team convention).
- Add new files to Xcode targets.
- PR title: `test refactor PR 5: AlbumRepository + PlaybackController`
- Link PR 5 of 14; note MusicKit playback/search require device/simulator QA.

## Follow-on PRs

| PR | Relationship |
|----|----------------|
| PR 6 | `StoredAlbums` already has `repository`; migrate persistence to `[AlbumRecord]`, drop facade |
| PR 10 | Extract `SearchViewModel` from `AlbumSearchView` (repository + `AlbumRecord` already in place); replace `print` errors |
| PR 11 | `AlbumTapCoordinator` replaces inline `onAlbumTapped`; `ArtworkProvider` supersedes `artworkURL` on repository |
| PR 14 | Delete any remaining `MusicKit` init paths on `StoredAlbum` |

# PR 6 — Load, migration, AlbumStore

**Status:** Approved (2026-05-28)  
**Program:** MusicWall testability refactor  
**Requires:** PR 5 merged  
**Blocks:** PR 8, PR 9  
**Approach:** Persistence Option B (new canonical key + one-time legacy read) + app state Option C (`AlbumStore` in Features)

## Summary

Replace `StoredAlbums` with an `@Observable` **`AlbumStore`** under `MusicWall/Features/Home/`, persisting `[AlbumRecord]` to a new UserDefaults key while migrating once from legacy `[StoredAlbum]` JSON on `savedAlbumsItemsKey`. Keep backup-ID hydration as a tertiary fallback. Views switch to `@Environment(AlbumStore.self)` and `AlbumRecord` throughout. `AlbumCollection` stays Foundation-only; hydration uses injected `AlbumRepository` only.

## Goals

- Canonical on-disk format: `[AlbumRecord]` on new key `albumRecordsItems` (see Preferences keys).
- One-time legacy import from `storedAlbumsItems` (`[LegacyStoredAlbum]`) preserving local title/artist/date; map `isExplicit` to `false` unless already on record.
- Load order: new key → legacy items key → backup IDs + `repository.fetch`.
- Stop writing legacy items key; continue updating `backupAlbumIDs` on every persist.
- Delete `StoredAlbums` facade; remove `StoredAlbum` from UI types.
- Unit tests: migration golden fixtures, new-key round-trip, empty legacy + backup, fetch throws, partial fetch.
- Human QA: upgrade over existing TestFlight/local data without library loss.

## Non-goals

- `HomeViewModel` / `AuthViewModel` (PR 8–9).
- Versioned persistence envelope (future; evolve via tolerant `AlbumRecord` Codable on new key).
- Deleting legacy `savedAlbumsItemsKey` blob from UserDefaults.
- Re-fetching entire library to backfill `isExplicit`.
- Coverage gates (PR 14).
- `AlbumRepository` / `PlaybackController` design changes (PR 5).

## Approaches considered

| Option | Description | Why not chosen |
|--------|-------------|----------------|
| **Persistence B (chosen)** | New key for `[AlbumRecord]`; read legacy key once; backup fallback | Clear evolution path; avoids decode ambiguity on same key |
| Persistence A | Same key, try `[AlbumRecord]` then `[StoredAlbum]` | Decode failure modes conflate corrupt / legacy / older schema |
| Persistence C | `{ version, items }` envelope | Heavier than needed for PR 6; can add later on new key |
| **App state C (chosen)** | `@Observable AlbumStore` in Features; pure `AlbumCollection` | Matches PR 4 Core boundary; PR 9 can adopt store in ViewModel |
| App state A | `@Observable AlbumCollection` | Couples Observation to Core |
| App state B | `AlbumLibrary` name only | Same as C; **AlbumStore** chosen for PR 9 alignment |

## Architecture

### Layer placement

```
MusicWall/
  Core/
    AlbumRecord.swift              # + Codable (backward-compatible)
    AlbumCollection.swift          # unchanged responsibility
    LegacyStoredAlbum.swift        # migration-only Codable (MusicItemID id)
    AlbumLibraryLoader.swift       # optional: pure load/migrate logic, testable
    PreferencesKey.swift           # + albumRecordsItems
  Features/
    Home/
      AlbumStore.swift             # @Observable facade: collection + sort + load/import
  ContentView.swift                # AlbumStore(preferences:repository:)
  HomePageView.swift               # @State store, .environment(store)
  LayoutViews.swift                # @Environment(AlbumStore.self), AlbumRecord UI
  AlbumEditView.swift              # AlbumRecord in/out

MusicWallTests/
  Core/
    AlbumLibraryLoaderTests.swift  # migration + backup paths (or AlbumStoreTests)
  Fixtures/
    legacy_stored_albums_v1.json   # golden encode from JSONEncoder + StoredAlbum shape
    album_records_v1.json
```

Physical paths follow the program target layout (`MusicWall/Features/…`) until SPM split (PR 15). New Swift files under `MusicWall/` are picked up by the filesystem-synchronized Xcode group.

### Dependency rules

| Unit | May import |
|------|------------|
| `AlbumCollection`, `AlbumLibraryLoader`, `LegacyStoredAlbum` | Foundation |
| `LegacyStoredAlbum` | MusicKit (for `MusicItemID` Codable only) — or isolate in `MusicWall/Adapters/Legacy/` if Core must stay MusicKit-free |
| `AlbumStore` | Foundation, Observation, Core protocols/types, `AlbumCollection` |
| Views | SwiftUI, `AlbumRecord`, `AlbumStore` |
| Tests | `@testable import MusicWall`, `MockAlbumRepository` |

**MusicKit in Core:** Prefer `LegacyStoredAlbum` in `MusicWall/Adapters/` (or `Features/Home/Migration/`) so `MusicWall/Core/` stays MusicKit-free. Loader returns `[AlbumRecord]`; only the legacy decoder touches `MusicItemID`.

### Component responsibilities

| Unit | Responsibility |
|------|----------------|
| `AlbumCollection` | In-memory `[AlbumRecord]` CRUD, sort, shuffle, export; persist via closures |
| `AlbumLibraryLoader` | Deterministic load/migrate: new key → legacy → backup fetch; no `@Observable` |
| `AlbumStore` | Owns `AlbumCollection`, sort prefs, `load()` / `importAlbums`; exposes `items` for SwiftUI |
| `AlbumStore` persist closures | `save([AlbumRecord], for: .albumRecordsItems)` + `save(backup IDs)` |
| Views | `@Environment(AlbumStore.self)`; never `StoredAlbum` / `StoredAlbums` |

## Persistence & migration

### Preferences keys

| Key | Enum case | Content |
|-----|-----------|---------|
| `albumRecordsItemsKey` (new) | `albumRecordsItems` | `[AlbumRecord]` — canonical |
| `savedAlbumsItemsKey` (legacy) | `storedAlbumsItems` | `[LegacyStoredAlbum]` — read once, never written after PR 6 |
| `backupIDsKey` | `backupAlbumIDs` | `[String]` — unchanged; still written on persist |

### `AlbumRecord` Codable

```swift
struct AlbumRecord: Equatable, Sendable, Codable {
    let id: AlbumID
    let title: String
    let artistName: String
    let releaseDate: Date?
    let isExplicit: Bool
}
```

- Use `decodeIfPresent` for `isExplicit` defaulting to `false` when absent on new-key blobs.
- Additive fields in future PRs: same pattern on `albumRecordsItems` only.

### `LegacyStoredAlbum`

Mirror pre-PR-6 `StoredAlbum` fields for decoding only:

```swift
struct LegacyStoredAlbum: Codable {
    let id: MusicItemID
    let title: String
    let artistName: String
    let releaseDate: Date?
}

func asAlbumRecord() -> AlbumRecord {
    AlbumRecord(
        id: AlbumID(rawValue: id.rawValue),
        title: title,
        artistName: artistName,
        releaseDate: releaseDate,
        isExplicit: false
    )
}
```

Golden fixture: commit JSON from a real `JSONEncoder().encode([LegacyStoredAlbum])` in tests — do not hand-author `MusicItemID` wire format.

### Load pipeline

`AlbumLibraryLoader.load(into:preferences:repository:)` (or equivalent on `AlbumStore` calling loader):

1. **New key:** `preferences.load([AlbumRecord].self, for: .albumRecordsItems)` → if non-empty, `collection.replaceAll(..., persist: false)` → done (items step).
2. **Legacy key:** `preferences.load([LegacyStoredAlbum].self, for: .storedAlbumsItems)` → map to `[AlbumRecord]` → `replaceAll(..., persist: true)` (writes new key + backup IDs).
3. **Backup:** If `collection.items.isEmpty`, read `backupAlbumIDs` → `repository.fetch(ids:)` → on success `replaceAll(..., persist: true)`; on failure leave empty (`try?` semantics match PR 5 unless PR 6 explicitly documents stricter behavior).
4. **Sort prefs:** Load `sortDirection` / `currentSort` into `AlbumStore` (same keys and `Codable` enum raw values as `StoredAlbums.SortOptions`).

After step 2 or 3 succeeds, subsequent launches hit step 1 only (offline-safe).

### Write path

On `AlbumCollection` mutation (not suppressed):

- Encode `[AlbumRecord]` to `.albumRecordsItems`.
- Encode `items.map(\.id.rawValue)` to `.backupAlbumIDs`.
- Do **not** write `.storedAlbumsItems`.

## `AlbumStore` (Features/Home)

```swift
@Observable
final class AlbumStore {
    private let preferences: PreferencesStore
    private let repository: any AlbumRepository
    private let collection: AlbumCollection

    private(set) var items: [AlbumRecord] = []  // sync from collection after mutations

    var currentSort: SortOption = .artist { didSet { preferences.save(...) } }
    var sortDirection: [SortOption: Bool] = [:] { didSet { preferences.save(...) } }

    enum SortOption: String, CaseIterable, Identifiable, Codable { ... }  // same cases as today

    @MainActor func load() async
    func addAlbum(_ record: AlbumRecord)
    func updateAlbum(_ record: AlbumRecord)
    func remove(album: AlbumRecord) / remove(atOffsets:)
    func applySort() / toggleSortDirection / isAscending / temporarilyShuffle
    func exportAlbumIDs() -> [String]
    @MainActor func importAlbums(from ids: [String]) async throws

    static func dummyData(preferences:repository:) -> AlbumStore
}
```

- Factory `make(preferences:repository:)` wires `AlbumCollection` persist closures.
- After every collection mutation, update `items` so `@Observable` notifies (same pattern as PR 4 `refreshItems()`).
- `importAlbums`: `performWithoutPersist` bulk add + `applySort()` (unchanged semantics).
- `load()`: call loader, then `loadSort()`, sync `items`.

### Composition root & environment

```swift
// ContentView (authorized)
HomePageView(
    store: AlbumStore(preferences: store, repository: dependencies.albumRepository),
    preferences: store,
    dependencies: dependencies
)

// HomePageView
.environment(store)
.task { await store.load() }
```

Replace `@Environment(StoredAlbums.self)` with `@Environment(AlbumStore.self)` in `LayoutViews`, `LayoutMenu`, etc.

## View wiring

| File | Change |
|------|--------|
| `ContentView.swift` | `AlbumStore` instead of `StoredAlbums` |
| `HomePageView.swift` | `@State var store`, `onSearchSelect` → `store.addAlbum(record)` |
| `LayoutViews.swift` | `AlbumRecord` in grid/list; `store.remove` / tap `record.id` |
| `AlbumEditView.swift` | `AlbumRecord` + `onSave: (AlbumRecord) -> Void` |
| `Album.swift` | **Delete** `StoredAlbum` / `StoredAlbums` (or remove file) |
| `StoredAlbum+AlbumRecord.swift` | **Delete** (replaced by `LegacyStoredAlbum` + `AlbumRecord` UI) |

Playback and repository environment keys unchanged (PR 5).

## Data flow

```
Launch:
  AlbumStore.load()
    → AlbumLibraryLoader
        → new key [AlbumRecord]?
        → else legacy [LegacyStoredAlbum] → persist new key
        → else backup IDs → AlbumRepository.fetch → persist
    → load sort prefs

Add from search:
  AlbumSearchView → onSelect(AlbumRecord) → store.addAlbum → collection → persist new key + backup

Tap play:
  LayoutViews → AlbumID(record.id) → PlaybackController (unchanged)
```

## Error handling

- Encode/decode failures: unchanged silent behavior from PR 3 (`try?` in store).
- Backup fetch failure: empty library until retry; no crash.
- No new user-facing errors in PR 6 (PR 10+).

## Testing

| Test | Asserts |
|------|---------|
| `legacy_stored_albums_v1.json` → loader | Correct `[AlbumRecord]` count/fields; `isExplicit == false` |
| Loader writes new key | Spy/in-memory `PreferencesStore` receives `[AlbumRecord]` after legacy migrate |
| New key round-trip | `isExplicit` and all fields survive encode/decode |
| Empty new + empty legacy + backup IDs | `MockAlbumRepository` fetch populates collection |
| Fetch throws | Collection stays empty |
| Partial fetch | Subset of IDs returned → subset in collection |
| `AlbumCollectionTests` | No changes to scenarios |
| Optional `AlbumStoreTests` | Sort/add/remove call through to collection |

Framework: Swift Testing; no `UserDefaults.standard` in unit tests.

## Acceptance criteria

- [ ] `PreferencesKey.albumRecordsItems` added; canonical persist is `[AlbumRecord]`.
- [ ] One-time legacy migration from `storedAlbumsItems` with golden fixture tests.
- [ ] Backup ID key still updated on item changes.
- [ ] Hydration uses `AlbumRepository.fetch` only (no `MusicService` / `StoredAlbum.play`).
- [ ] `AlbumStore` in `MusicWall/Features/Home/`; `StoredAlbums` removed.
- [ ] `ContentView` / `HomePageView` / layouts use `AlbumStore` + `AlbumRecord`.
- [ ] `MusicWall/Core/` has no new MusicKit imports (legacy type outside Core if needed).
- [ ] `ci-tests` green.
- [ ] Human QA documented: install over existing data; library + sort prefs + local edits survive.

## Human verification (PR description)

- Install build over existing TestFlight/local library; albums and sort order survive relaunch.
- Add album from search; relaunch persists.
- Edit album title locally; relaunch keeps edit (legacy migrate path).
- Clear new key only (dev): legacy + backup still recover library.
- Airplane mode after migration: library visible from new key without network.

## PR delivery

- Branch: `cursor/test-refactor-pr-06-load-migration` (or team convention).
- PR title: `test refactor PR 6: load, migration, AlbumStore`
- Link PR 6 of 14; reference this spec.

## Follow-on PRs

| PR | Relationship |
|----|----------------|
| PR 7 | Backup codec may share loader patterns; avoid conflicting migration |
| PR 8–9 | `HomeViewModel` / `AuthViewModel` adopt `AlbumStore` |
| PR 10 | Search error UX |
| PR 11 | `AlbumTapCoordinator`, `ArtworkProvider` |
| PR 14 | Remove `LegacyStoredAlbum` if legacy key no longer needed in wild |

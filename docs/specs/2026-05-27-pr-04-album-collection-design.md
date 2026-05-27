# PR 4 — AlbumCollection + StoredAlbums facade

**Status:** Approved (2026-05-27)  
**Program:** MusicWall testability refactor  
**Requires:** PR 2, PR 3 merged  
**Blocks:** PR 5  
**Approach:** Core `AlbumCollection` + delegate persist (Option A) + `StoredAlbums` facade (Option A) + `performWithoutPersist` (Option A)

## Summary

Extract in-memory album list logic (add, update, remove, dedup, sort, shuffle, export IDs) from `StoredAlbums` into a Foundation-only `AlbumCollection` in `MusicWall/Core/`. `StoredAlbums` remains the `@Observable` app facade: maps `StoredAlbum` ↔ `AlbumRecord`, implements persist closures that encode `[StoredAlbum]` and backup ID strings via `PreferencesStore`, and keeps sort preferences plus MusicKit `load()` / `importAlbums()` until later PRs. Views keep `@Environment(StoredAlbums.self)`; delete paths stop mutating `items` directly.

## Goals

- Single testable unit for collection behavior without MusicKit, SwiftUI, or `UserDefaults.standard`.
- Sort order delegated to `AlbumSorter` (behavior locked by PR 2 tests).
- Replace `itemsSavingLocked` with scoped `performWithoutPersist { }`.
- Persist on mutation via injected closures; on-disk JSON shape unchanged (`[StoredAlbum]`).
- Unit tests: dedup on add, update/remove no-ops, export IDs, shuffle without persist, sort after add, `performWithoutPersist`.

## Non-goals

- MusicKit `load()` / `importAlbums(from:)` implementation changes beyond using `performWithoutPersist` (PR 5–6).
- Deleting `StoredAlbums` or switching environment to `AlbumCollection` (PR 6).
- `AlbumRecord` Codable or migration from `StoredAlbum` JSON (PR 6).
- Moving sort preference keys off `StoredAlbums` (optional later).
- `AlbumRepository` / removing `MusicService` (PR 5).
- SPM module extraction (optional PR 15).

## Architecture

### Layer placement

```
MusicWall/
  Core/
    AlbumCollection.swift
  Album.swift                    # StoredAlbums facade
  StoredAlbum+AlbumRecord.swift
  LayoutViews.swift              # delete → facade remove APIs
  HomePageView.swift             # unchanged environment type
  ContentView.swift

MusicWallTests/
  Core/
    AlbumCollectionTests.swift
  Fixtures/
    AlbumFixtures.swift          # reuse existing
```

### Dependency rules

| Module / folder | May import |
|-----------------|------------|
| `MusicWall/Core/` (`AlbumCollection`) | Foundation |
| `StoredAlbums`, views | SwiftUI, MusicKit as today |
| `MusicWallTests` | `@testable import MusicWall` |

### Component responsibilities

| Unit | Responsibility |
|------|----------------|
| `AlbumCollection` | `[AlbumRecord]` CRUD, dedup, sort, shuffle, export IDs, persist suppression |
| `StoredAlbums` | Facade, `StoredAlbum` mapping, persist encoding, sort prefs, `load()` / `importAlbums()` |
| Views | `@Environment(StoredAlbums.self)` until PR 6 |

## Approaches considered

| Option | Description | Why not chosen |
|--------|-------------|----------------|
| **A (chosen)** | Core collection + facade + delegate persist | Matches program architecture; testable Core |
| B | App-target `AlbumCollection` with direct `PreferencesStore` | Couples Core goal to MusicKit encoding in collection |
| C | Memory-only Core; facade-only persist | Easy to miss persist on a code path |

## `AlbumCollection`

Foundation-only `final class` (not `@Observable`).

```swift
final class AlbumCollection {
    private(set) var items: [AlbumRecord] = []
    private var persistSuppressed = false

    init(
        persistItems: @escaping ([AlbumRecord]) -> Void,
        persistBackupIDs: @escaping ([String]) -> Void
    )

    @discardableResult
    func add(_ record: AlbumRecord) -> Bool

    func update(_ record: AlbumRecord)
    func remove(id: AlbumID)
    func contains(id: AlbumID) -> Bool
    func exportIDs() -> [String]

    func applySort(key: AlbumSortKey, ascending: Bool)
    func temporarilyShuffle()

    func performWithoutPersist(_ block: () -> Void)
    func replaceAll(_ items: [AlbumRecord], persist: Bool)
}
```

### Behavior

| Method | Behavior |
|--------|----------|
| `add` | If `contains(id:)`, return `false` and do not persist. Else append, `applySort` is **not** automatic — caller (`StoredAlbums.addAlbum`) calls `applySort` after add. |
| `update` | Replace by `AlbumID` if present; no-op if missing. Does not auto-sort — facade calls `applySort` after update. |
| `remove` | Remove by `AlbumID` if present; no-op if missing. |
| `exportIDs` | `items.map(\.id.rawValue)` in current order. |
| `applySort` | `items = AlbumSorter.sorted(items, key:, ascending:)` |
| `temporarilyShuffle` | Shuffle in place inside `performWithoutPersist` (no persist). |
| `performWithoutPersist` | Sets `persistSuppressed`; runs `block`; clears flag in `defer`. |
| `replaceAll` | Sets `items`; if `persist` and not suppressed, calls persist closures. |

**Persist:** After any mutating operation when `persistSuppressed == false`, invoke both `persistItems(items)` and `persistBackupIDs(items.map(\.id.rawValue))`.

**Sort:** `AlbumCollection` does not read or write `currentSort` / `sortDirection` keys. `StoredAlbums.applySort()` reads prefs and calls `collection.applySort(key:ascending:)`.

### `add` + sort sequencing

`StoredAlbums.addAlbum` / `updateAlbum` preserve today’s behavior:

1. `collection.add` / `update` (persist once per operation if mutation occurred).
2. `collection.applySort(key: currentSort.albumSortKey, ascending: sortDirection[currentSort] ?? true)` (second persist if order changed).

This matches current double-write pattern (append + resort). Tests on `AlbumCollection` cover sort in isolation; facade integration is covered by existing app behavior / manual QA.

## `StoredAlbums` facade

### Ownership

```swift
@Observable
class StoredAlbums {
    private let preferences: PreferencesStore
    private let collection: AlbumCollection
    // sort prefs unchanged
}
```

Initialize `AlbumCollection` with closures that map records to `StoredAlbum` and call:

```swift
preferences.save(stored, for: .storedAlbumsItems)
preferences.save(ids, for: .backupAlbumIDs)
```

Mapping uses `MusicItemID(record.id.rawValue)` and field copy (mirror `StoredAlbum.asAlbumRecord` inverse).

### Public API changes

| Before | After |
|--------|-------|
| `var items` with `didSet` persist | Read-only `var items: [StoredAlbum]` from `collection.items` mapping, **or** private setter only used inside facade — **no** public `items` mutation from views |
| Direct `albums.items.remove` in views | `albums.remove(album:)` / `albums.remove(atOffsets:)` forwarding to `collection.remove` |
| `itemsSavingLocked` | `collection.performWithoutPersist` in `loadItems`, `importAlbums` bulk append |
| `addAlbum` / `updateAlbum` / `applySort` / `temporarilyShuffle` / `exportAlbumIDs` | Forward to `collection` as above |

New facade methods (names may match call sites):

```swift
func remove(album: StoredAlbum)
func remove(atOffsets offsets: IndexSet)
```

### Unchanged on facade

- `load()`, `loadItems()`, `loadSort()`, `importAlbums(from:)`
- `currentSort`, `sortDirection`, `toggleSortDirection`, `isAscending`
- `SortOptions` enum and `dummyData(preferences:)`
- `StoredAlbum.play()` / `pause()` (PR 5+)

### Hydration

`loadItems()`:

```swift
collection.performWithoutPersist {
    let stored = preferences.load([StoredAlbum].self, for: .storedAlbumsItems) ?? []
    collection.replaceAll(stored.map(\.asAlbumRecord), persist: false)
    // MusicKit recovery branch: append fetched albums inside same block,
    // then exit block and persist once if items non-empty (match current semantics)
}
```

`importAlbums` bulk append stays inside `performWithoutPersist`; single `applySort` after block (as today).

## View wiring

| File | Change |
|------|--------|
| `LayoutViews.swift` | Grid context menu delete → `albums.remove(album:)` |
| `LayoutViews.swift` | List `.onDelete` → `albums.remove(atOffsets:)` |
| Other views | No environment type change |

## Data flow

```
View → StoredAlbums.addAlbum(StoredAlbum)
     → collection.add(AlbumRecord)
     → persist closures → PreferencesStore ([StoredAlbum] + [String])
     → StoredAlbums.applySort() → collection.applySort(...)
```

Shuffle: `StoredAlbums.temporarilyShuffle()` → `collection.temporarilyShuffle()` (no persist).

## Error handling

- Missing ID on `update` / `remove`: no-op, no persist for no-op updates.
- Encode/decode failures: unchanged silent behavior from PR 3.
- No new user-facing errors in PR 4.

## Testing

### Framework

Swift Testing (PR 1 / 2 / 3).

### `AlbumCollectionTests`

Use `AlbumFixtures` and persist spies (e.g. capture arrays in closure locals). Never `UserDefaults.standard` or MusicKit.

| Test | Asserts |
|------|---------|
| Dedup on add | Second `add` with same `AlbumID` returns `false`; count 1; persist spy called once |
| Update missing ID | Count unchanged; persist not called |
| Update existing | Fields updated; persist called |
| Remove existing / missing | Count / persist |
| `exportIDs` | Equals `items.map(\.id.rawValue)` in order |
| Shuffle without persist | Order may change; persist spy count 0 |
| Sort after add | Order matches `AlbumSorter.sorted` for fixture trio (same keys/directions as `AlbumSorterTests`) |
| `performWithoutPersist` | Multiple mutations inside block → persist spy 0; after block, optional explicit persist via `replaceAll(..., persist: true)` |

### Optional

Thin facade test with `UserDefaults(suiteName:)` or in-memory store verifying `[StoredAlbum]` round-trip after `addAlbum` — not required if collection tests are thorough.

### CI

No workflow changes. PR must pass `ci-tests` (`fastlane ci_tests`).

### Human verification (PR description)

- Add album from search; list resorts and survives relaunch.
- Sort menu changes order; persists across relaunch.
- Shuffle reorders visually; relaunch restores saved order (not shuffled).
- Delete from grid and list; persists.
- Export still produces correct ID list.

## Acceptance criteria

- [ ] `AlbumCollection` in `MusicWall/Core/`; Foundation only; no `PreferencesStore` import.
- [ ] Delegate persist closures; on-disk `[StoredAlbum]` and backup ID keys unchanged.
- [ ] `itemsSavingLocked` removed; `performWithoutPersist` used for hydrate/import/shuffle.
- [ ] Views do not mutate `albums.items` directly; use `remove` APIs.
- [ ] `AlbumCollectionTests` cover dedup, no-op update, export, shuffle-without-persist, sort, `performWithoutPersist`.
- [ ] Unit tests do not use MusicKit or `UserDefaults.standard` without isolation.
- [ ] Sort order matches PR 2 `AlbumSorter` behavior.
- [ ] App compiles; `ci-tests` green.

## PR delivery

- Branch from `main`: `cursor/test-refactor-pr-04-album-collection` (or team convention).
- Add `AlbumCollection.swift` and `AlbumCollectionTests.swift` to Xcode targets.
- PR description: link "PR 4 of 14"; list human verification steps above.
- Monitor `ci-tests` until green before merge.

## Follow-on PRs

| PR | Relationship |
|----|----------------|
| PR 5 | `AlbumRepository`; remove static `MusicService` from fetch paths |
| PR 6 | `AlbumCollection.load()`, `AlbumRecord` migration, environment → `AlbumCollection`, delete `StoredAlbums` |
| PR 9 | `HomeViewModel` owns sort actions against collection |
| PR 14 | Coverage gates; delete legacy patterns |

# PR 2 — Core domain + AlbumSorter

**Status:** Approved (2026-05-27)  
**Program:** MusicWall testability refactor  
**Requires:** PR 1 merged  
**Blocks:** PR 4  
**Approach:** Option B — extract Core, delegate `StoredAlbums.applySort()` immediately

## Summary

Introduce app-owned domain types and pure sorting in `MusicWall/Core/`, with `StoredAlbums.applySort()` delegating to `AlbumSorter` via a thin adapter. Unit tests lock sort behavior with fixed golden fixtures. No persistence or UI contract changes.

## Goals

- Single source of truth for album sort comparators (verbatim copy from pre-refactor `applySort()`).
- Core layer free of MusicKit, SwiftUI, and UIKit.
- Deterministic Swift Testing coverage for all sort keys and directions.
- App continues to use `StoredAlbum` and `SortOptions` everywhere except inside `applySort()`.

## Non-goals

- `AlbumCollection`, `PreferencesStore`, repositories, ViewModels.
- Removing `StoredAlbum` / `MusicItemID` from persistence (PR 6).
- Changing UserDefaults keys or on-disk JSON shape.
- SPM module extraction (optional PR 15).
- Fixing `dummyData()` to use fixed dates (preview-only; out of scope).

## Architecture

### Layer placement

```
MusicWall/
  Core/                    # Foundation only
    AlbumID.swift
    AlbumRecord.swift
    AlbumSortKey.swift
    AlbumSorter.swift
  StoredAlbum+AlbumRecord.swift   # App target; may import MusicKit
  Album.swift                     # applySort delegates; inline comparators removed

MusicWallTests/
  Core/
    AlbumSorterTests.swift
```

### Dependency rules

| Module / folder | May import |
|-----------------|------------|
| `MusicWall/Core/` | Foundation |
| `StoredAlbum+AlbumRecord.swift` | Foundation, MusicKit (for `StoredAlbum`) |
| `MusicWallTests` | `@testable import MusicWall` |

## Domain types

### `AlbumID`

```swift
struct AlbumID: RawRepresentable, Codable, Hashable, Sendable {
    let rawValue: String
}
```

Maps to `MusicItemID.rawValue` at the adapter boundary.

### `AlbumRecord`

```swift
struct AlbumRecord: Equatable, Sendable {
    let id: AlbumID
    let title: String
    let artistName: String
    let releaseDate: Date?
}
```

### `AlbumSortKey`

```swift
enum AlbumSortKey: String, CaseIterable, Sendable {
    case artist
    case title
    case year
}
```

Maps from `StoredAlbums.SortOptions`:

| `SortOptions` | `AlbumSortKey` | UI label (unchanged) |
|---------------|----------------|----------------------|
| `.artist` | `.artist` | Artist |
| `.title` | `.title` | Title |
| `.date` | `.year` | Year |

`SortOptions` remains the app and persistence-facing enum until PR 3–4.

## `AlbumSorter`

### API

```swift
enum AlbumSorter {
    static func sorted(
        _ albums: [AlbumRecord],
        key: AlbumSortKey,
        ascending: Bool
    ) -> [AlbumRecord]
}
```

Non-mutating return value for straightforward golden assertions in tests.

### Comparators (verbatim from legacy `applySort()`)

| Key | Ascending | Descending |
|-----|-----------|------------|
| `.artist` | `artistName.lowercased() <` | `>` |
| `.title` | `title.lowercased() <` | `>` |
| `.year` | `(releaseDate ?? .distantFuture) <` | `(releaseDate ?? .distantPast) >` |

Nil `releaseDate` sorts as earliest when ascending (treated as distant future) and latest when descending (treated as distant past). Case-insensitive for artist and title.

No explicit stable-sort requirement beyond Swift `sort` behavior (same as legacy).

## Adapter and delegation

### `StoredAlbum` → `AlbumRecord`

```swift
extension StoredAlbum {
    var asAlbumRecord: AlbumRecord {
        AlbumRecord(
            id: AlbumID(rawValue: id.rawValue),
            title: title,
            artistName: artistName,
            releaseDate: releaseDate
        )
    }
}
```

### `SortOptions` → `AlbumSortKey`

```swift
extension StoredAlbums.SortOptions {
    var albumSortKey: AlbumSortKey { ... }
}
```

### `StoredAlbums.applySort()`

1. Read `ascending` from `sortDirection[currentSort] ?? true`.
2. Map `items` to `[AlbumRecord]` via `asAlbumRecord`.
3. Call `AlbumSorter.sorted(_:key:ascending:)`.
4. Rebuild `[StoredAlbum]` by looking up original rows by `id.rawValue` (preserves `MusicItemID` and all fields).

```swift
let byID = Dictionary(uniqueKeysWithValues: items.map { ($0.id.rawValue, $0) })
items = sortedRecords.compactMap { byID[$0.id.rawValue] }
```

Remove inline comparator closures from `applySort()`.

## Testing

### Framework

Swift Testing (consistent with PR 1 / `MusicWallTests/Agent.md`).

### Golden fixtures

Shared helpers live in `MusicWallTests/Fixtures/AlbumFixtures.swift` (`utcDate`, `record`, `baseTrio`). Golden sort-order expectations remain in `AlbumSorterTests`.

Fixed dates and stable string IDs (no `UUID()` or `Date()` in tests):

| `AlbumID.rawValue` | Title | Artist | `releaseDate` |
|--------------------|-------|--------|---------------|
| `fixture-drake` | Take Care | Drake | 2011-11-15 |
| `fixture-cole` | Born Sinners | J. Cole | `nil` |
| `fixture-kendrick` | Good Kid, m.A.A.d City | Kendrick Lamar | 2012-10-22 |

Additional rows as needed for case-insensitivity cases (e.g. artist/title differing only by case).

Use `Calendar` / fixed `TimeZone` (UTC) when constructing fixture dates so golden order is stable across locales.

### Test matrix (`AlbumSorterTests`)

Parameterized coverage:

- Every `AlbumSortKey` × `ascending: true/false`
- Assert full ordered `[String]` of `AlbumID.rawValue` (golden arrays)

Dedicated cases:

- Nil `releaseDate` ordering for `.year` asc/desc
- Case-insensitive artist/title ordering

Optional belt-and-suspenders: one test file-local copy of legacy comparators asserting parity with `AlbumSorter` on fixtures before deleting inline production code (may be removed after PR merges).

### CI

No workflow changes. PR must pass existing `ci-tests` (`fastlane ci_test`).

## Acceptance criteria

- [ ] `AlbumSorter` tests match golden order fixtures derived from legacy `applySort()` behavior.
- [ ] `StoredAlbums.applySort()` delegates to `AlbumSorter`; no duplicated comparators in `Album.swift`.
- [ ] `MusicWall/Core/` has no MusicKit, SwiftUI, or UIKit imports.
- [ ] UserDefaults keys and on-disk format unchanged.
- [ ] App compiles; `ci-tests` green.

## PR delivery

- Branch from `main`: `cursor/test-refactor-pr-02-core-album-sorter-c3d5` (or team convention).
- Add new files to `MusicWall.xcodeproj` / test target membership.
- Do **not** use `no-deploy` — run TestFlight on the PR and verify sort on a physical device.
- Monitor `ci-tests` and `testflight-release` until green before merge.

## Follow-on PRs

| PR | Relationship |
|----|----------------|
| PR 3 | `PreferencesStore`; may later persist `AlbumSortKey` |
| PR 4 | `AlbumCollection.applySort(using: AlbumSorter, ...)` replaces collection + sort in `StoredAlbums` |
| PR 6 | Migrate persistence to `AlbumRecord` / `AlbumID` |

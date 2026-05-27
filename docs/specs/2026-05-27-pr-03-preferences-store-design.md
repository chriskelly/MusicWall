# PR 3 — PreferencesStore + UserDefaults adapter

**Status:** Approved (2026-05-27)  
**Program:** MusicWall testability refactor  
**Requires:** PR 1 merged  
**Blocks:** PR 4, PR 7  
**Approach:** Full call-site migration (Option A) + generic `PreferencesStore` API (Option A)

## Summary

Replace static `UserDefaultsManager` with an injectable `PreferencesStore` protocol and `UserDefaultsPreferencesStore` adapter. Migrate all persistence call sites to use `AppDependencies.preferencesStore`. Preserve exact UserDefaults key strings and JSON encoding behavior. Add isolated unit tests for every key.

## Goals

- Persistence is injectable and unit-testable via `UserDefaults(suiteName:)` or in-memory fakes.
- `PreferencesStore` and `PreferencesKey` live in `MusicWall/Core/` (Foundation only).
- `UserDefaultsPreferencesStore` lives in `MusicWall/Adapters/` with no MusicKit or SwiftUI imports.
- All eight legacy call sites migrated; `UserDefaultsManager.swift` deleted.
- Existing simulator/user data continues to load (keys and JSON shapes unchanged).

## Non-goals

- `AlbumCollection` (PR 4).
- Backup file I/O (PR 7).
- Changing UserDefaults keys or on-disk JSON shape.
- Typed per-key protocol methods (generic API only; no app-target convenience extensions in this PR unless needed for compile).
- Logging or `throws` on encode/decode failures (preserve silent behavior).
- SPM `MusicWallPersistence` module (optional PR 15).
- `AppDependencies` fields beyond `preferencesStore`.

## Architecture

### Layer placement

```
MusicWall/
  Core/
    PreferencesKey.swift
    PreferencesStore.swift
  Adapters/
    UserDefaultsPreferencesStore.swift
  AppDependencies.swift
  Album.swift              # StoredAlbums uses injected store
  LayoutViews.swift        # LayoutMenu uses injected store
  ContentView.swift
  HomePageView.swift

MusicWallTests/
  Adapters/
    UserDefaultsPreferencesStoreTests.swift
  TestSupport/
    InMemoryPreferencesStore.swift   # if useful for tests/previews
```

Delete `MusicWall/UserDefaultsManager.swift`.

### Dependency rules

| Module / folder | May import |
|-----------------|------------|
| `MusicWall/Core/` (`PreferencesKey`, `PreferencesStore`) | Foundation |
| `MusicWall/Adapters/` (`UserDefaultsPreferencesStore`) | Foundation |
| `StoredAlbums`, `LayoutMenu`, views | SwiftUI, MusicKit as today |
| `MusicWallTests` | `@testable import MusicWall` |

## `PreferencesKey`

Enum with `String` raw values **identical** to legacy `UserDefaultsManager.Key`:

| Case | `rawValue` (UserDefaults key) |
|------|-------------------------------|
| `storedAlbumsItems` | `savedAlbumsItemsKey` |
| `backupAlbumIDs` | `backupIDsKey` |
| `sortDirection` | `sortDirectionKey` |
| `currentSort` | `currentSortKey` |
| `homePageLayout` | `homePageLayoutKey` |

## `PreferencesStore`

```swift
protocol PreferencesStore: Sendable {
    func save<T: Encodable>(_ value: T, for key: PreferencesKey)
    func load<T: Decodable>(_ type: T.Type, for key: PreferencesKey) -> T?
}
```

Call sites pass app-owned `Codable` types at the boundary (`[StoredAlbum]`, `[String]`, `[SortOptions: Bool]`, `SortOptions`, `LayoutMenu.Option`). The protocol does not reference those types.

## `UserDefaultsPreferencesStore`

```swift
struct UserDefaultsPreferencesStore: PreferencesStore {
    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults)
}
```

### Behavior (matches legacy `UserDefaultsManager`)

| Operation | Behavior |
|-----------|----------|
| `save` | `JSONEncoder().encode(value)`; on success `userDefaults.set(data, forKey: key.rawValue)`; on encode failure, no write |
| `load` | `userDefaults.data(forKey:)`; on success `JSONDecoder().decode(type, from:)`; missing key or decode failure → `nil` |

Production: `UserDefaultsPreferencesStore(userDefaults: .standard)`.

Tests: unique `UserDefaults(suiteName:)` per test; clear suite in teardown.

## Composition root and injection

### `AppDependencies`

```swift
struct AppDependencies {
    let preferencesStore: PreferencesStore

    static let live = AppDependencies(
        preferencesStore: UserDefaultsPreferencesStore(userDefaults: .standard)
    )
}
```

`MusicWallApp` already holds `AppDependencies.live` and passes it to `ContentView`.

### `StoredAlbums`

- Add `private let preferences: PreferencesStore`.
- `init(preferences: PreferencesStore)` — **required**; no implicit `.standard`.
- Replace all `UserDefaultsManager.setData` / `loadData` with `preferences.save` / `preferences.load`.
- Update `dummyData(preferences:)` (or equivalent) for previews/tests.

Persisted types unchanged:

| Key | Type |
|-----|------|
| `storedAlbumsItems` | `[StoredAlbum]` |
| `backupAlbumIDs` | `[String]` |
| `sortDirection` | `[StoredAlbums.SortOptions: Bool]` |
| `currentSort` | `StoredAlbums.SortOptions` |

### `ContentView` → `HomePageView`

```swift
let store = dependencies.preferencesStore
HomePageView(
    albums: StoredAlbums(preferences: store),
    preferences: store
)
```

### `HomePageView`

- Add `let preferences: PreferencesStore` (stored property).
- Initialize `@State private var currentLayout` in `init` from `LayoutMenu.loadLayout(using: preferences) ?? .grid`.

### `LayoutMenu`

- Add `let preferences: PreferencesStore`.
- On layout selection: `preferences.save(currentLayout, for: .homePageLayout)`.
- Replace `static func loadLayout()` with:

```swift
static func loadLayout(using preferences: PreferencesStore) -> Option?
```

Load: `preferences.load(Option.self, for: .homePageLayout)`.

### Previews

Pass a fresh `InMemoryPreferencesStore()` or ephemeral `UserDefaults(suiteName:)` into `StoredAlbums`, `LayoutMenu`, and `HomePageView` — do not rely on `.standard` in previews.

## Testing

### Framework

Swift Testing (consistent with PR 1 / PR 2).

### `UserDefaultsPreferencesStoreTests`

For **each** `PreferencesKey`:

1. **Round-trip** — save a representative value, load, assert equality.
2. **Corrupt data** — write invalid/truncated `Data` under `key.rawValue`; assert `load` returns `nil`.
3. **Isolation** — unique suite name per test; remove persistent domain in teardown.

Representative payloads (use `@testable import MusicWall` where app types are needed):

| Key | Test payload |
|-----|----------------|
| `storedAlbumsItems` | `[StoredAlbum]` (minimal fixture or empty array) |
| `backupAlbumIDs` | `["id-a", "id-b"]` |
| `sortDirection` | `[.artist: true, .title: false]` |
| `currentSort` | `.artist` |
| `homePageLayout` | `.grid` |

Optional: `InMemoryPreferencesStore` in `MusicWallTests/TestSupport/` implementing `PreferencesStore` via `[PreferencesKey: Data]` for fast tests and previews.

### Smoke

`AppDependencies.live` constructs successfully.

### Human verification (PR description)

On simulator with existing user data: albums, sort preferences, and home layout still load correctly.

### CI

No workflow changes. PR must pass existing `ci-tests` (`fastlane ci_tests`).

## Acceptance criteria

- [ ] `PreferencesStore` + `PreferencesKey` in `MusicWall/Core/`; Foundation only.
- [ ] `UserDefaultsPreferencesStore` in `MusicWall/Adapters/`; no MusicKit or SwiftUI imports.
- [ ] All five keys covered by round-trip and corrupt-data tests with isolated suites.
- [ ] All `UserDefaultsManager` call sites migrated; file deleted; no remaining references.
- [ ] `AppDependencies.live` provides `UserDefaultsPreferencesStore(userDefaults: .standard)`.
- [ ] UserDefaults key strings and JSON shapes unchanged.
- [ ] App compiles; `ci-tests` green.

## PR delivery

- Branch from `main`: `cursor/test-refactor-pr-03-preferences-store` (or team convention).
- Add new files to `MusicWall.xcodeproj` / test target membership.
- Remove `UserDefaultsManager.swift` from target.
- PR description: link "PR 3 of 14"; note human verification on simulator with existing data.
- Monitor `ci-tests` until green before merge.

## Follow-on PRs

| PR | Relationship |
|----|----------------|
| PR 4 | `AlbumCollection` injects `PreferencesStore`; may add app-target typed convenience extensions |
| PR 6 | Persistence payloads migrate from `StoredAlbum` to `AlbumRecord` |
| PR 7 | Backup file I/O (separate from UserDefaults) |
| PR 14 | Delete any remaining legacy persistence patterns; coverage gates |

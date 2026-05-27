# PR 3 — PreferencesStore + UserDefaults adapter Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace static `UserDefaultsManager` with injectable `PreferencesStore` + `UserDefaultsPreferencesStore`, migrate all call sites through `AppDependencies`, and cover every key with isolated Swift Testing.

**Architecture:** Foundation-only `PreferencesKey` and `PreferencesStore` in `MusicWall/Core/`. JSON encode/decode adapter in `MusicWall/Adapters/`. App types (`StoredAlbum`, `SortOptions`, `LayoutMenu.Option`) stay at call sites via generic `save`/`load`. Production uses `UserDefaults.standard` via `AppDependencies.live`.

**Tech Stack:** Swift 5, Swift Testing, Xcode 16+, scheme `MusicWall`, simulator `iPhone 17`, `bundle exec fastlane ci_tests`.

**Spec:** `docs/specs/2026-05-27-pr-03-preferences-store-design.md`

**Branch:** `cursor/test-refactor-pr-03-preferences-store`

---

## File map

| Action | Path | Notes |
|--------|------|-------|
| Create | `MusicWall/Core/PreferencesKey.swift` | Exact legacy raw strings |
| Create | `MusicWall/Core/PreferencesStore.swift` | Generic protocol |
| Create | `MusicWall/Adapters/UserDefaultsPreferencesStore.swift` | Foundation only |
| Modify | `MusicWall/AppDependencies.swift` | Add `preferencesStore` |
| Modify | `MusicWall/Album.swift` | `StoredAlbums(preferences:)` |
| Modify | `MusicWall/ContentView.swift` | Wire store into `HomePageView` |
| Modify | `MusicWall/HomePageView.swift` | `preferences` + custom `init` |
| Modify | `MusicWall/HomePageView.swift` | `HomePageMenu` passes `preferences` to `LayoutMenu` |
| Modify | `MusicWall/LayoutViews.swift` | `LayoutMenu` uses store |
| Modify | `MusicWall/AlbumEditView.swift` | Preview uses `dummyData(preferences:)` |
| Delete | `MusicWall/UserDefaultsManager.swift` | After migration |
| Create | `MusicWallTests/Adapters/UserDefaultsPreferencesStoreTests.swift` | Round-trip + corrupt per key |
| Modify | `MusicWallTests/SmokeTests.swift` | Assert `preferencesStore` exists |
| Modify | `MusicWall.xcodeproj/project.pbxproj` | Register test file |
| Modify | `README.md` | Replace `UserDefaultsManager` mention |

**Xcode note:** `MusicWall/` uses `PBXFileSystemSynchronizedRootGroup` — new app files auto-join the target. Test files under `MusicWallTests/` must be registered in `project.pbxproj` (mirror `AlbumSorterTests.swift`).

**Preview helper:** Add `AppDependencies.preview()` using an ephemeral `UserDefaults(suiteName:)` so previews never touch `.standard`.

---

## Key string reference (do not change)

| `PreferencesKey` case | `rawValue` |
|-----------------------|------------|
| `storedAlbumsItems` | `savedAlbumsItemsKey` |
| `backupAlbumIDs` | `backupIDsKey` |
| `sortDirection` | `sortDirectionKey` |
| `currentSort` | `currentSortKey` |
| `homePageLayout` | `homePageLayoutKey` |

---

### Task 1: Core protocol types

**Files:**
- Create: `MusicWall/Core/PreferencesKey.swift`
- Create: `MusicWall/Core/PreferencesStore.swift`

- [ ] **Step 1: Create `PreferencesKey.swift`**

```swift
import Foundation

enum PreferencesKey: String, CaseIterable, Sendable {
    case storedAlbumsItems = "savedAlbumsItemsKey"
    case backupAlbumIDs = "backupIDsKey"
    case sortDirection = "sortDirectionKey"
    case currentSort = "currentSortKey"
    case homePageLayout = "homePageLayoutKey"
}
```

- [ ] **Step 2: Create `PreferencesStore.swift`**

```swift
import Foundation

protocol PreferencesStore: Sendable {
    func save<T: Encodable>(_ value: T, for key: PreferencesKey)
    func load<T: Decodable>(_ type: T.Type, for key: PreferencesKey) -> T?
}
```

- [ ] **Step 3: Build app target**

Run:

```bash
xcodebuild build -project MusicWall.xcodeproj -scheme MusicWall \
  -destination 'platform=iOS Simulator,name=iPhone 17' -quiet
```

Expected: `BUILD SUCCEEDED`

- [ ] **Step 4: Commit**

```bash
git add MusicWall/Core/PreferencesKey.swift MusicWall/Core/PreferencesStore.swift
git commit -m "feat(core): Add PreferencesKey and PreferencesStore"
```

---

### Task 2: Failing adapter tests

**Files:**
- Create: `MusicWallTests/Adapters/UserDefaultsPreferencesStoreTests.swift`
- Modify: `MusicWall.xcodeproj/project.pbxproj`

- [ ] **Step 1: Add `CaseIterable` to `PreferencesKey`**

In `MusicWall/Core/PreferencesKey.swift`:

```swift
enum PreferencesKey: String, CaseIterable, Sendable {
```

- [ ] **Step 2: Register test file in Xcode project**

Add `MusicWallTests/Adapters/UserDefaultsPreferencesStoreTests.swift` to `MusicWallTests` target (Sources build phase + `Adapters` subgroup under `MusicWallTests`), mirroring `AlbumSorterTests.swift` registration.

- [ ] **Step 3: Write `UserDefaultsPreferencesStoreTests.swift`**

```swift
import Foundation
import MusicKit
import Testing
@testable import MusicWall

struct UserDefaultsPreferencesStoreTests {
    private func makeStore() -> (UserDefaultsPreferencesStore, String) {
        let suiteName = "test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        return (UserDefaultsPreferencesStore(userDefaults: defaults), suiteName)
    }

    @Test
    func roundTripStoredAlbumsItems() {
        let (store, suiteName) = makeStore()
        defer { UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName) }

        let albums: [StoredAlbum] = []
        store.save(albums, for: .storedAlbumsItems)
        #expect(store.load([StoredAlbum].self, for: .storedAlbumsItems) == albums)
    }

    @Test
    func roundTripBackupAlbumIDs() {
        let (store, suiteName) = makeStore()
        defer { UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName) }

        let ids = ["id-a", "id-b"]
        store.save(ids, for: .backupAlbumIDs)
        #expect(store.load([String].self, for: .backupAlbumIDs) == ids)
    }

    @Test
    func roundTripSortDirection() {
        let (store, suiteName) = makeStore()
        defer { UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName) }

        let value: [StoredAlbums.SortOptions: Bool] = [.artist: true, .title: false]
        store.save(value, for: .sortDirection)
        #expect(store.load([StoredAlbums.SortOptions: Bool].self, for: .sortDirection) == value)
    }

    @Test
    func roundTripCurrentSort() {
        let (store, suiteName) = makeStore()
        defer { UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName) }

        store.save(StoredAlbums.SortOptions.artist, for: .currentSort)
        #expect(store.load(StoredAlbums.SortOptions.self, for: .currentSort) == .artist)
    }

    @Test
    func roundTripHomePageLayout() {
        let (store, suiteName) = makeStore()
        defer { UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName) }

        store.save(LayoutMenu.Option.grid, for: .homePageLayout)
        #expect(store.load(LayoutMenu.Option.self, for: .homePageLayout) == .grid)
    }

    @Test(arguments: PreferencesKey.allCases)
    func corruptDataReturnsNil(key: PreferencesKey) {
        let (store, suiteName) = makeStore()
        defer { UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName) }

        UserDefaults(suiteName: suiteName)!.set(Data([0x00, 0x01, 0x02]), forKey: key.rawValue)
        #expect(store.load(String.self, for: key) == nil)
    }
}
```

- [ ] **Step 4: Run tests to verify they fail**

Run:

```bash
xcodebuild test -project MusicWall.xcodeproj -scheme MusicWall \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:MusicWallTests/UserDefaultsPreferencesStoreTests 2>&1 | tail -20
```

Expected: FAIL — `UserDefaultsPreferencesStore` not found

- [ ] **Step 5: Commit failing tests**

```bash
git add MusicWallTests/Adapters/UserDefaultsPreferencesStoreTests.swift MusicWall.xcodeproj/project.pbxproj
git commit -m "test: Add UserDefaultsPreferencesStore tests (red)"
```

---

### Task 3: `UserDefaultsPreferencesStore` implementation

**Files:**
- Create: `MusicWall/Adapters/UserDefaultsPreferencesStore.swift`

- [ ] **Step 1: Implement adapter**

```swift
import Foundation

struct UserDefaultsPreferencesStore: PreferencesStore, @unchecked Sendable {
    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults) {
        self.userDefaults = userDefaults
    }

    func save<T: Encodable>(_ value: T, for key: PreferencesKey) {
        guard let encoded = try? JSONEncoder().encode(value) else { return }
        userDefaults.set(encoded, forKey: key.rawValue)
    }

    func load<T: Decodable>(_ type: T.Type, for key: PreferencesKey) -> T? {
        guard let data = userDefaults.data(forKey: key.rawValue) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
```

`@unchecked Sendable` matches storing `UserDefaults` (reference type) behind a value-type facade; safe for this single-threaded app usage.

- [ ] **Step 2: Run adapter tests**

Run:

```bash
xcodebuild test -project MusicWall.xcodeproj -scheme MusicWall \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:MusicWallTests/UserDefaultsPreferencesStoreTests 2>&1 | tail -20
```

Expected: all `UserDefaultsPreferencesStoreTests` PASS

- [ ] **Step 3: Commit**

```bash
git add MusicWall/Adapters/UserDefaultsPreferencesStore.swift
git commit -m "feat: Add UserDefaultsPreferencesStore adapter"
```

---

### Task 4: Composition root

**Files:**
- Modify: `MusicWall/AppDependencies.swift`

- [ ] **Step 1: Update `AppDependencies`**

```swift
struct AppDependencies {
    let preferencesStore: PreferencesStore

    static let live = AppDependencies(
        preferencesStore: UserDefaultsPreferencesStore(userDefaults: .standard)
    )

    static func preview() -> AppDependencies {
        let suiteName = "com.musicwall.preview.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        return AppDependencies(
            preferencesStore: UserDefaultsPreferencesStore(userDefaults: defaults)
        )
    }
}
```

- [ ] **Step 2: Update `SmokeTests.swift`**

```swift
@Test
func appDependenciesLiveConstructs() {
    let dependencies = AppDependencies.live
    _ = dependencies.preferencesStore
    #expect(true)
}
```

- [ ] **Step 3: Build and run smoke test**

Run:

```bash
bundle exec fastlane ci_tests
```

Expected: PASS (smoke + existing tests)

- [ ] **Step 4: Commit**

```bash
git add MusicWall/AppDependencies.swift MusicWallTests/SmokeTests.swift
git commit -m "feat: Wire preferencesStore into AppDependencies"
```

---

### Task 5: Migrate `StoredAlbums`

**Files:**
- Modify: `MusicWall/Album.swift`

- [ ] **Step 1: Add stored `preferences` and required initializer**

```swift
@Observable
class StoredAlbums {
    private let preferences: PreferencesStore
    private var itemsSavingLocked = false

    init(preferences: PreferencesStore) {
        self.preferences = preferences
    }
```

- [ ] **Step 2: Replace persistence calls**

| Legacy | Replacement |
|--------|-------------|
| `UserDefaultsManager.setData(key: .storedAlbumsItemsKey, data: items)` | `preferences.save(items, for: .storedAlbumsItems)` |
| `UserDefaultsManager.setData(key: .backupAlbumIDsKey, data: ...)` | `preferences.save(..., for: .backupAlbumIDs)` |
| `UserDefaultsManager.loadData(key: .storedAlbumsItemsKey, type: [StoredAlbum].self)` | `preferences.load([StoredAlbum].self, for: .storedAlbumsItems)` |
| `UserDefaultsManager.loadData(key: .backupAlbumIDsKey, type: [String].self)` | `preferences.load([String].self, for: .backupAlbumIDs)` |
| `UserDefaultsManager.loadData(key: .sortDirectionKey, type: ...)` | `preferences.load(..., for: .sortDirection)` |
| `UserDefaultsManager.loadData(key: .currentSortKey, type: ...)` | `preferences.load(..., for: .currentSort)` |
| `UserDefaultsManager.setData(key: .currentSortKey, data: currentSort)` | `preferences.save(currentSort, for: .currentSort)` |
| `UserDefaultsManager.setData(key: .sortDirectionKey, data: sortDirection)` | `preferences.save(sortDirection, for: .sortDirection)` |

- [ ] **Step 3: Update `dummyData`**

```swift
static func dummyData(preferences: PreferencesStore) -> StoredAlbums {
    let storedAlbums = StoredAlbums(preferences: preferences)
    storedAlbums.items = [
        StoredAlbum(id: MusicItemID("\(UUID())"), title: "Take Care", artistName: "Drake", releaseDate: Date()),
        StoredAlbum(id: MusicItemID("\(UUID())"), title: "Born Sinners", artistName: "J. Cole", releaseDate: nil),
        StoredAlbum(id: MusicItemID("\(UUID())"), title: "Good Kid, m.A.A.d City", artistName: "Kendrick Lamar", releaseDate: Date(timeIntervalSinceNow: 500)),
    ]
    return storedAlbums
}
```

- [ ] **Step 4: Build (expect compile errors in callers — fixed in Task 6)**

Run:

```bash
xcodebuild build -project MusicWall.xcodeproj -scheme MusicWall \
  -destination 'platform=iOS Simulator,name=iPhone 17' -quiet 2>&1 | tail -30
```

Expected: errors in `ContentView`, previews, `AlbumEditView` until Task 6

- [ ] **Step 5: Commit**

```bash
git add MusicWall/Album.swift
git commit -m "refactor: Inject PreferencesStore into StoredAlbums"
```

---

### Task 6: Wire views and delete legacy manager

**Files:**
- Modify: `MusicWall/ContentView.swift`
- Modify: `MusicWall/HomePageView.swift`
- Modify: `MusicWall/LayoutViews.swift`
- Modify: `MusicWall/AlbumEditView.swift`
- Delete: `MusicWall/UserDefaultsManager.swift`
- Modify: `README.md`

- [ ] **Step 1: Update `ContentView`**

```swift
if isAuthorized {
    let store = dependencies.preferencesStore
    HomePageView(
        albums: StoredAlbums(preferences: store),
        preferences: store
    )
}
```

- [ ] **Step 2: Update `HomePageView`**

Add property and custom initializer; pass `preferences` into `HomePageMenu`:

```swift
struct HomePageView: View {
    @State var albums: StoredAlbums
    let preferences: PreferencesStore
    @State private var showingAddView = false
    @State private var currentLayout: LayoutMenu.Option
    // ... other @State unchanged ...

    init(albums: StoredAlbums, preferences: PreferencesStore) {
        self._albums = State(initialValue: albums)
        self.preferences = preferences
        self._currentLayout = State(
            initialValue: LayoutMenu.loadLayout(using: preferences) ?? .grid
        )
    }

    // In toolbarView():
    HomePageMenu(
        currentLayout: $currentLayout,
        showingFileImporter: $showingFileImporter,
        preferences: preferences,
        onExport: exportAlbums
    )
}
```

- [ ] **Step 3: Update `HomePageMenu`**

```swift
struct HomePageMenu: View {
    @Binding var currentLayout: LayoutMenu.Option
    @Binding var showingFileImporter: Bool
    let preferences: PreferencesStore
    let onExport: () -> Void

    var body: some View {
        Menu {
            LayoutMenu(currentLayout: $currentLayout, preferences: preferences)
            // ...
        }
    }
}
```

- [ ] **Step 4: Update `LayoutMenu`**

```swift
struct LayoutMenu: View {
    @Binding var currentLayout: Option
    let preferences: PreferencesStore

    // Button action:
    preferences.save(currentLayout, for: .homePageLayout)

    static func loadLayout(using preferences: PreferencesStore) -> Option? {
        preferences.load(Option.self, for: .homePageLayout)
    }
}
```

Update `#Preview` in `LayoutViews.swift`:

```swift
#Preview {
    @Previewable @State var layout: LayoutMenu.Option = .grid
    let deps = AppDependencies.preview()
    LayoutMenu(currentLayout: $layout, preferences: deps.preferencesStore)
}
```

- [ ] **Step 5: Update previews and `AlbumEditView`**

`HomePageView` previews:

```swift
#Preview {
    let deps = AppDependencies.preview()
    HomePageView(
        albums: StoredAlbums.dummyData(preferences: deps.preferencesStore),
        preferences: deps.preferencesStore
    )
}
```

`LayoutViews.swift` list/grid previews:

```swift
let deps = AppDependencies.preview()
let albums = StoredAlbums.dummyData(preferences: deps.preferencesStore)
ListLayout().environment(albums)
```

`AlbumEditView` preview:

```swift
let deps = AppDependencies.preview()
AlbumEditView(
    album: StoredAlbums.dummyData(preferences: deps.preferencesStore).items.first!,
    onSave: { _ in }
)
```

- [ ] **Step 6: Delete `UserDefaultsManager.swift`**

```bash
git rm MusicWall/UserDefaultsManager.swift
```

- [ ] **Step 7: Update `README.md`**

Replace `UserDefaultsManager.swift` with `PreferencesStore` / `UserDefaultsPreferencesStore` in the file tree description.

- [ ] **Step 8: Verify no remaining references**

Run:

```bash
rg UserDefaultsManager
```

Expected: no matches (or only historical docs outside this PR scope)

- [ ] **Step 9: Full test suite**

Run:

```bash
bundle exec fastlane ci_tests
```

Expected: PASS

- [ ] **Step 10: Commit**

```bash
git add MusicWall/ContentView.swift MusicWall/HomePageView.swift MusicWall/LayoutViews.swift \
  MusicWall/AlbumEditView.swift README.md
git commit -m "refactor: Migrate persistence call sites; remove UserDefaultsManager"
```

---

### Task 7: PR delivery

- [ ] **Step 1: Verify Core/Adapters imports**

Run:

```bash
rg '^import (MusicKit|SwiftUI|UIKit)' MusicWall/Core MusicWall/Adapters
```

Expected: no matches

- [ ] **Step 2: Push branch and open PR**

```bash
git push -u origin cursor/test-refactor-pr-03-preferences-store
gh pr create --title "test refactor PR 3: PreferencesStore + UserDefaults adapter" --body "$(cat <<'EOF'
## Summary
- Add `PreferencesStore` protocol and `UserDefaultsPreferencesStore` adapter
- Migrate all persistence call sites through `AppDependencies.preferencesStore`
- Delete `UserDefaultsManager`; preserve exact UserDefaults keys and JSON shapes

## Test plan
- [ ] `ci-tests` passes (`bundle exec fastlane ci_tests`)
- [ ] Simulator with **existing** user data: albums, sort prefs, and home layout still load
- [ ] Change layout → kill app → relaunch → layout persisted

## Spec
docs/specs/2026-05-27-pr-03-preferences-store-design.md
EOF
)"
```

- [ ] **Step 3: Monitor PR checks**

```bash
gh pr checks <PR_NUMBER> --watch
```

Expected: `ci-tests` green

---

## Spec coverage self-review

| Spec requirement | Task |
|------------------|------|
| `PreferencesKey` exact raw strings | Task 1 |
| `PreferencesStore` generic API in Core | Task 1 |
| `UserDefaultsPreferencesStore` in Adapters, Foundation only | Task 3 |
| Silent encode/decode failure behavior | Task 3 |
| `AppDependencies.preferencesStore` + `.live` | Task 4 |
| `StoredAlbums(preferences:)` migration | Task 5 |
| `ContentView` / `HomePageView` / `LayoutMenu` wiring | Task 6 |
| `HomePageMenu` passes preferences | Task 6 |
| Previews use isolated store | Task 6 |
| Five keys round-trip + corrupt tests | Task 2–3 |
| Delete `UserDefaultsManager` | Task 6 |
| `ci-tests` green | Task 7 |
| Human verification note in PR body | Task 7 |

No placeholders. Type names consistent across tasks.

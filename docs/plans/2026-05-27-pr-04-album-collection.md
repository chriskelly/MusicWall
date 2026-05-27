# PR 4 — AlbumCollection + StoredAlbums facade Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extract testable in-memory album collection logic into `AlbumCollection` (Core), keep `StoredAlbums` as the `@Observable` facade with delegate persist, and route view deletes through facade `remove` APIs.

**Architecture:** Foundation-only `AlbumCollection` holds `[AlbumRecord]` and calls injected persist closures. `StoredAlbums` maps to `StoredAlbum`, owns sort prefs and MusicKit load/import, and calls `refreshItems()` after collection mutations so `@Observable` notifies SwiftUI. On-disk `[StoredAlbum]` JSON unchanged.

**Tech Stack:** Swift 5, Swift Testing, Observation (`@Observable`), Xcode 16+, scheme `MusicWall`, simulator `iPhone 17`, `bundle exec fastlane ci_tests`.

**Spec:** `docs/specs/2026-05-27-pr-04-album-collection-design.md`

**Branch:** `cursor/test-refactor-pr-04-album-collection` (spec commit already on this branch; `main` must not include PR 4 work until merge)

---

## File map

| Action | Path | Notes |
|--------|------|-------|
| Create | `MusicWall/Core/AlbumCollection.swift` | Foundation only |
| Create | `MusicWallTests/Core/AlbumCollectionTests.swift` | Persist spies; no MusicKit / `.standard` |
| Modify | `MusicWall/StoredAlbum+AlbumRecord.swift` | `StoredAlbum.init(from: AlbumRecord)` |
| Modify | `MusicWall/Album.swift` | Facade; remove `itemsSavingLocked` |
| Modify | `MusicWall/LayoutViews.swift` | Delete → `remove(album:)` / `remove(atOffsets:)` |
| Modify | `MusicWall.xcodeproj/project.pbxproj` | Register `AlbumCollectionTests.swift` |

**Xcode note:** `MusicWall/` uses `PBXFileSystemSynchronizedRootGroup` — new Core files auto-join the app target. Test files must be registered in `project.pbxproj` (mirror `AlbumSorterTests.swift`).

**Observation note:** `StoredAlbums.items` must remain a **stored** property updated via `refreshItems()` after every collection mutation. A computed `items` getter alone will not trigger `@Observable` updates when `AlbumCollection` mutates internally.

---

## Persist spy pattern (tests)

```swift
private struct PersistSpy {
    var itemsCalls: [[AlbumRecord]] = []
    var backupCalls: [[String]] = []

    func makeCollection() -> AlbumCollection {
        AlbumCollection(
            persistItems: { self.itemsCalls.append($0) },
            persistBackupIDs: { self.backupCalls.append($0) }
        )
    }
}
```

Use a class or `@MainActor` box if mutating from escaping closures in tests; simplest approach:

```swift
final class PersistSpy {
    var itemsCalls: [[AlbumRecord]] = []
    var backupCalls: [[String]] = []

    func makeCollection() -> AlbumCollection {
        AlbumCollection(
            persistItems: { [weak self] in self?.itemsCalls.append($0) },
            persistBackupIDs: { [weak self] in self?.backupCalls.append($0.map(\.id.rawValue)) }
        )
    }
}
```

Wait — backup closure receives `[String]` per spec, not records. Correct:

```swift
persistBackupIDs: { [weak self] ids in self?.backupCalls.append(ids) }
```

And `persistItems` receives `[AlbumRecord]`.

---

### Task 1: `StoredAlbum` mapping from `AlbumRecord`

**Files:**
- Modify: `MusicWall/StoredAlbum+AlbumRecord.swift`

- [ ] **Step 1: Add initializer**

```swift
extension StoredAlbum {
    init(from record: AlbumRecord) {
        self.id = MusicItemID(record.id.rawValue)
        self.title = record.title
        self.artistName = record.artistName
        self.releaseDate = record.releaseDate
    }

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

(Keep existing `asAlbumRecord`; add `init(from:)` only if not already present.)

- [ ] **Step 2: Build**

```bash
xcodebuild build -project MusicWall.xcodeproj -scheme MusicWall \
  -destination 'platform=iOS Simulator,name=iPhone 17' -quiet
```

Expected: `BUILD SUCCEEDED`

- [ ] **Step 3: Commit**

```bash
git add MusicWall/StoredAlbum+AlbumRecord.swift
git commit -m "feat: Add StoredAlbum initializer from AlbumRecord"
```

---

### Task 2: Failing `AlbumCollection` tests

**Files:**
- Create: `MusicWallTests/Core/AlbumCollectionTests.swift`
- Modify: `MusicWall.xcodeproj/project.pbxproj`

- [ ] **Step 1: Register test file in Xcode project**

Add `AlbumCollectionTests.swift` to `MusicWallTests` target (PBXBuildFile, PBXFileReference, `Core` group child, Sources build phase) mirroring `AlbumSorterTests.swift`. Use new unique 24-char hex IDs in `project.pbxproj`.

- [ ] **Step 2: Create `AlbumCollectionTests.swift`**

```swift
import Foundation
import Testing
@testable import MusicWall

struct AlbumCollectionTests {
    private final class PersistSpy {
        var itemsCalls: [[AlbumRecord]] = []
        var backupCalls: [[String]] = []

        func makeCollection() -> AlbumCollection {
            AlbumCollection(
                persistItems: { [weak self] records in
                    self?.itemsCalls.append(records)
                },
                persistBackupIDs: { [weak self] ids in
                    self?.backupCalls.append(ids)
                }
            )
        }
    }

    @Test
    func addDedupesByID() {
        let spy = PersistSpy()
        let collection = spy.makeCollection()
        let record = AlbumFixtures.record(id: "a", title: "T", artistName: "A")

        let first = collection.add(record)
        let second = collection.add(record)

        #expect(first == true)
        #expect(second == false)
        #expect(collection.items.count == 1)
        #expect(spy.itemsCalls.count == 1)
        #expect(spy.backupCalls.count == 1)
    }

    @Test
    func updateMissingIDIsNoOp() {
        let spy = PersistSpy()
        let collection = spy.makeCollection()
        collection.replaceAll(AlbumFixtures.baseTrio, persist: true)
        spy.itemsCalls.removeAll()
        spy.backupCalls.removeAll()

        collection.update(
            AlbumFixtures.record(id: "missing", title: "X", artistName: "Y")
        )

        #expect(collection.items == AlbumFixtures.baseTrio)
        #expect(spy.itemsCalls.isEmpty)
        #expect(spy.backupCalls.isEmpty)
    }

    @Test
    func updateExistingReplacesAndPersists() {
        let spy = PersistSpy()
        let collection = spy.makeCollection()
        collection.replaceAll([AlbumFixtures.record(id: "a", title: "Old", artistName: "A")], persist: true)
        spy.itemsCalls.removeAll()

        collection.update(AlbumFixtures.record(id: "a", title: "New", artistName: "A"))

        #expect(collection.items.first?.title == "New")
        #expect(spy.itemsCalls.count == 1)
    }

    @Test
    func removeExistingAndMissing() {
        let spy = PersistSpy()
        let collection = spy.makeCollection()
        collection.replaceAll([AlbumFixtures.record(id: "a", title: "T", artistName: "A")], persist: true)
        spy.itemsCalls.removeAll()

        collection.remove(id: AlbumID(rawValue: "missing"))
        #expect(collection.items.count == 1)
        #expect(spy.itemsCalls.isEmpty)

        collection.remove(id: AlbumID(rawValue: "a"))
        #expect(collection.items.isEmpty)
        #expect(spy.itemsCalls.count == 1)
    }

    @Test
    func exportIDsMatchesItemOrder() {
        let spy = PersistSpy()
        let collection = spy.makeCollection()
        collection.replaceAll(AlbumFixtures.baseTrio, persist: false)

        #expect(collection.exportIDs() == ["fixture-drake", "fixture-cole", "fixture-kendrick"])
    }

    @Test
    func temporarilyShuffleDoesNotPersist() {
        let spy = PersistSpy()
        let collection = spy.makeCollection()
        collection.replaceAll(AlbumFixtures.baseTrio, persist: true)
        let before = collection.items
        spy.itemsCalls.removeAll()
        spy.backupCalls.removeAll()

        collection.temporarilyShuffle()

        #expect(collection.items != before || before.count <= 1)
        #expect(spy.itemsCalls.isEmpty)
        #expect(spy.backupCalls.isEmpty)
    }

    @Test
    func applySortMatchesAlbumSorter() {
        let spy = PersistSpy()
        let collection = spy.makeCollection()
        collection.replaceAll(AlbumFixtures.baseTrio, persist: false)

        collection.applySort(key: .artist, ascending: true)

        #expect(collection.exportIDs() == ["fixture-drake", "fixture-cole", "fixture-kendrick"])
    }

    @Test
    func performWithoutPersistSkipsSaves() {
        let spy = PersistSpy()
        let collection = spy.makeCollection()

        collection.performWithoutPersist {
            collection.add(AlbumFixtures.record(id: "a", title: "T", artistName: "A"))
            collection.add(AlbumFixtures.record(id: "b", title: "U", artistName: "B"))
        }

        #expect(spy.itemsCalls.isEmpty)
        #expect(collection.items.count == 2)

        collection.replaceAll(collection.items, persist: true)
        #expect(spy.itemsCalls.count == 1)
    }
}
```

- [ ] **Step 3: Run tests — expect compile failure**

```bash
xcodebuild test -project MusicWall.xcodeproj -scheme MusicWall \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:MusicWallTests/AlbumCollectionTests -quiet
```

Expected: compile error — `AlbumCollection` not found

- [ ] **Step 4: Commit**

```bash
git add MusicWallTests/Core/AlbumCollectionTests.swift MusicWall.xcodeproj/project.pbxproj
git commit -m "test: Add failing AlbumCollection tests"
```

---

### Task 3: Implement `AlbumCollection`

**Files:**
- Create: `MusicWall/Core/AlbumCollection.swift`

- [ ] **Step 1: Create `AlbumCollection.swift`**

```swift
import Foundation

final class AlbumCollection {
    private(set) var items: [AlbumRecord] = []
    private var persistSuppressed = false
    private let persistItems: ([AlbumRecord]) -> Void
    private let persistBackupIDs: ([String]) -> Void

    init(
        persistItems: @escaping ([AlbumRecord]) -> Void,
        persistBackupIDs: @escaping ([String]) -> Void
    ) {
        self.persistItems = persistItems
        self.persistBackupIDs = persistBackupIDs
    }

    @discardableResult
    func add(_ record: AlbumRecord) -> Bool {
        guard !contains(id: record.id) else { return false }
        items.append(record)
        persistIfNeeded()
        return true
    }

    func update(_ record: AlbumRecord) {
        guard let index = items.firstIndex(where: { $0.id == record.id }) else { return }
        items[index] = record
        persistIfNeeded()
    }

    func remove(id: AlbumID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items.remove(at: index)
        persistIfNeeded()
    }

    func contains(id: AlbumID) -> Bool {
        items.contains { $0.id == id }
    }

    func exportIDs() -> [String] {
        items.map(\.id.rawValue)
    }

    func applySort(key: AlbumSortKey, ascending: Bool) {
        items = AlbumSorter.sorted(items, key: key, ascending: ascending)
        persistIfNeeded()
    }

    func temporarilyShuffle() {
        performWithoutPersist {
            items.shuffle()
        }
    }

    func performWithoutPersist(_ block: () -> Void) {
        persistSuppressed = true
        defer { persistSuppressed = false }
        block()
    }

    func replaceAll(_ newItems: [AlbumRecord], persist: Bool) {
        items = newItems
        if persist {
            persistIfNeeded()
        }
    }

    private func persistIfNeeded() {
        guard !persistSuppressed else { return }
        persistItems(items)
        persistBackupIDs(items.map(\.id.rawValue))
    }
}
```

- [ ] **Step 2: Run collection tests**

```bash
xcodebuild test -project MusicWall.xcodeproj -scheme MusicWall \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:MusicWallTests/AlbumCollectionTests -quiet
```

Expected: all `AlbumCollectionTests` pass

- [ ] **Step 3: Commit**

```bash
git add MusicWall/Core/AlbumCollection.swift
git commit -m "feat(core): Add AlbumCollection with delegate persist"
```

---

### Task 4: Refactor `StoredAlbums` facade

**Files:**
- Modify: `MusicWall/Album.swift`

- [ ] **Step 1: Replace `itemsSavingLocked` with `AlbumCollection`**

Remove `itemsSavingLocked` and `items` `didSet` persistence. Add:

```swift
fileprivate let collection: AlbumCollection

private func refreshItems() {
    items = collection.items.map { StoredAlbum(from: $0) }
}

private func makeCollection(preferences: PreferencesStore) -> AlbumCollection {
    AlbumCollection(
        persistItems: { records in
            let stored = records.map { StoredAlbum(from: $0) }
            preferences.save(stored, for: .storedAlbumsItems)
        },
        persistBackupIDs: { ids in
            preferences.save(ids, for: .backupAlbumIDs)
        }
    )
}
```

In `init(preferences:)`:

```swift
self.preferences = preferences
self.collection = Self.makeCollection(preferences: preferences)
```

Keep `var items = [StoredAlbum]()` as stored property (no `didSet`).

- [ ] **Step 2: Forward collection + sort methods**

```swift
func applySort() {
    let ascending = sortDirection[currentSort] ?? true
    collection.applySort(key: currentSort.albumSortKey, ascending: ascending)
    refreshItems()
}

func addAlbum(_ album: StoredAlbum) {
    if collection.add(album.asAlbumRecord) {
        applySort()
    }
}

func updateAlbum(_ album: StoredAlbum) {
    let existed = collection.contains(id: album.asAlbumRecord.id)
    collection.update(album.asAlbumRecord)
    if existed {
        applySort()
    }
}
```

```swift
func temporarilyShuffle() {
    collection.temporarilyShuffle()
    refreshItems()
}

func exportAlbumIDs() -> [String] {
    collection.exportIDs()
}

func remove(album: StoredAlbum) {
    collection.remove(id: album.asAlbumRecord.id)
    refreshItems()
}

func remove(atOffsets offsets: IndexSet) {
    let idsToRemove = offsets.map { items[$0].asAlbumRecord.id }
    for id in idsToRemove {
        collection.remove(id: id)
    }
    refreshItems()
}
```

- [ ] **Step 3: Rewrite `loadItems()` with `performWithoutPersist`**

Legacy behavior: load from prefs without persist; if still empty, fetch backup IDs and assign once **with** persist. Use:

```swift
private func loadItems() async {
    collection.performWithoutPersist {
        let stored = preferences.load([StoredAlbum].self, for: .storedAlbumsItems) ?? []
        collection.replaceAll(stored.map(\.asAlbumRecord), persist: false)
    }
    refreshItems()

    guard collection.items.isEmpty else { return }

    let backupIDs = preferences.load([String].self, for: .backupAlbumIDs) ?? []
    guard let albums = try? await MusicService.fetchAlbums(ids: backupIDs) else { return }

    let records = albums.map { StoredAlbum(from: $0).asAlbumRecord }
    collection.replaceAll(records, persist: true)
    refreshItems()
}
```

- [ ] **Step 4: Rewrite `importAlbums`**

```swift
@MainActor
func importAlbums(from ids: [String]) async throws {
    guard !ids.isEmpty else { return }

    let fetchedAlbums = try await MusicService.fetchAlbums(ids: ids)
    collection.performWithoutPersist {
        for album in fetchedAlbums {
            let record = StoredAlbum(from: album).asAlbumRecord
            if !collection.contains(id: record.id) {
                _ = collection.add(record)
            }
        }
    }
    applySort()
}
```

(`add` inside `performWithoutPersist` does not persist; `applySort` persists sorted result.)

- [ ] **Step 5: Update `dummyData`**

Declare `collection` as `fileprivate` (same file as `dummyData`) so previews can hydrate without persisting:

```swift
static func dummyData(preferences: PreferencesStore) -> StoredAlbums {
    let storedAlbums = StoredAlbums(preferences: preferences)
    let samples = [
        StoredAlbum(id: MusicItemID("\(UUID())"), title: "Take Care", artistName: "Drake", releaseDate: Date()),
        StoredAlbum(id: MusicItemID("\(UUID())"), title: "Born Sinners", artistName: "J. Cole", releaseDate: nil),
        StoredAlbum(id: MusicItemID("\(UUID())"), title: "Good Kid, m.A.A.d City", artistName: "Kendrick Lamar", releaseDate: Date(timeIntervalSinceNow: 500)),
    ]
    storedAlbums.collection.performWithoutPersist {
        storedAlbums.collection.replaceAll(samples.map(\.asAlbumRecord), persist: false)
    }
    storedAlbums.refreshItems()
    return storedAlbums
}
```

- [ ] **Step 6: Build and run full unit tests**

```bash
bundle exec fastlane ci_tests
```

Expected: green (or `xcodebuild test` equivalent)

- [ ] **Step 7: Commit**

```bash
git add MusicWall/Album.swift
git commit -m "refactor: Delegate StoredAlbums collection logic to AlbumCollection"
```

---

### Task 5: View delete wiring

**Files:**
- Modify: `MusicWall/LayoutViews.swift`

- [ ] **Step 1: Grid delete (context menu)**

Replace:

```swift
if let index = albums.items.firstIndex(where: { $0.id == album.id }) {
    albums.items.remove(at: index)
```

With:

```swift
albums.remove(album: album)
```

- [ ] **Step 2: List `.onDelete`**

Replace:

```swift
let deletedAlbums = indexSet.map { albums.items[$0] }
albums.items.remove(atOffsets: indexSet)
```

With:

```swift
let deletedAlbum = indexSet.first.map { albums.items[$0] }
albums.remove(atOffsets: indexSet)
```

And snackbar:

```swift
if let deletedAlbum {
    onDeleteSnackbar(deletedAlbum)
}
```

- [ ] **Step 3: Build + test**

```bash
xcodebuild build -project MusicWall.xcodeproj -scheme MusicWall \
  -destination 'platform=iOS Simulator,name=iPhone 17' -quiet
bundle exec fastlane ci_tests
```

- [ ] **Step 4: Commit**

```bash
git add MusicWall/LayoutViews.swift
git commit -m "refactor: Route album deletes through StoredAlbums facade"
```

---

### Task 6: PR hygiene

- [ ] **Step 1: Confirm branch contents**

```bash
git log --oneline origin/main..HEAD
```

Expected: spec commit + implementation commits (no extra docs on `main`)

- [ ] **Step 2: Push feature branch**

```bash
git push -u origin cursor/test-refactor-pr-04-album-collection
```

- [ ] **Step 3: Open PR**

Title: `test refactor PR 4: AlbumCollection + StoredAlbums facade`

Body: link spec, "PR 4 of 14", human verification checklist from spec (add/search/sort/shuffle/delete/export/relaunch).

---

## Spec coverage checklist (self-review)

| Spec requirement | Task |
|------------------|------|
| Core `AlbumCollection`, Foundation only | Task 3 |
| Delegate persist closures | Task 3, 4 |
| `performWithoutPersist` replaces `itemsSavingLocked` | Task 3, 4 |
| View delete via `remove` APIs | Task 5 |
| Tests: dedup, update no-op, export, shuffle, sort, suppress | Task 2–3 |
| Sort matches `AlbumSorter` | Task 2 `applySortMatchesAlbumSorter` |
| Facade keeps sort prefs + load/import | Task 4 |
| `@Observable` refresh | Task 4 `refreshItems()` |
| On-disk shape unchanged | Task 4 persist closures |

## Human verification (PR description)

- Add album from search; list resorts; survives relaunch.
- Sort menu; order persists across relaunch.
- Shuffle visual only; relaunch restores saved order.
- Delete from grid and list; persists.
- Export album IDs file contents correct.

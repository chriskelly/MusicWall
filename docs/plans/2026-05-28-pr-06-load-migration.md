# PR 6 — Load, migration, AlbumStore Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace `StoredAlbums` with `AlbumStore` in `MusicWall/Features/Home/`, persist `[AlbumRecord]` on a new preferences key, migrate once from legacy `[StoredAlbum]` JSON, and wire all views to `AlbumRecord` + `@Environment(AlbumStore.self)`.

**Architecture:** `AlbumLibraryLoader` in `Adapters/` performs new-key → legacy → backup hydration (depends on `LegacyStoredAlbum` + Core protocols). `AlbumCollection` stays Foundation-only. `LegacyStoredAlbum` lives in `MusicWall/Adapters/` (MusicKit for `MusicItemID` only). `@Observable AlbumStore` owns `AlbumCollection`, sort prefs, and persist closures that write `.albumRecordsItems` + `.backupAlbumIDs` only.

**Tech Stack:** Swift 5, Swift Testing, Observation (`@Observable`), SwiftUI, MusicKit (legacy decode only), scheme `MusicWall`, simulator `iPhone 17`, `bundle exec fastlane ci_tests`.

**Spec:** `docs/specs/2026-05-28-pr-06-load-migration-design.md`

**Branch:** `cursor/test-refactor-pr-06-load-migration` (from `main`; spec commit may already be on this branch)

---

## File map

| Action | Path | Notes |
|--------|------|-------|
| Modify | `MusicWall/Core/AlbumRecord.swift` | `Codable`, `Identifiable` |
| Modify | `MusicWall/Core/PreferencesKey.swift` | `albumRecordsItems` |
| Create | `MusicWall/Adapters/LegacyStoredAlbum.swift` | Migration-only; `asAlbumRecord()` |
| Create | `MusicWall/Adapters/AlbumLibraryLoader.swift` | Load/migrate/hydrate (imports `LegacyStoredAlbum`; not Core) |
| Create | `MusicWall/Features/Home/AlbumStore.swift` | `@Observable` facade |
| Create | `MusicWall/Features/Home/AlbumStore+SortOption.swift` | `albumSortKey` mapping (optional: inline in AlbumStore) |
| Delete | `MusicWall/Album.swift` | `StoredAlbum` / `StoredAlbums` |
| Delete | `MusicWall/StoredAlbum+AlbumRecord.swift` | Replaced by above |
| Modify | `MusicWall/ContentView.swift` | `AlbumStore` |
| Modify | `MusicWall/HomePageView.swift` | `@State store`, environment |
| Modify | `MusicWall/LayoutViews.swift` | `AlbumStore`, `AlbumRecord` |
| Modify | `MusicWall/AlbumEditView.swift` | `AlbumRecord` |
| Create | `MusicWallTests/TestSupport/InMemoryPreferencesStore.swift` | Fast loader tests |
| Create | `MusicWallTests/Core/AlbumLibraryLoaderTests.swift` | Migration + backup |
| Create | `MusicWallTests/Fixtures/legacy_stored_albums_v1.json` | Golden bytes (generated) |
| Modify | `MusicWallTests/Adapters/UserDefaultsPreferencesStoreTests.swift` | `LegacyStoredAlbum` + `albumRecordsItems` |
| Modify | `MusicWall.xcodeproj/project.pbxproj` | Register new test files + JSON in Copy Bundle Resources |

**Xcode note:** `MusicWall/` uses filesystem-synchronized root — new app files under `MusicWall/Features/` auto-join target. Register each new **test** file and `legacy_stored_albums_v1.json` in `project.pbxproj` (mirror `AlbumCollectionTests.swift`).

**Verify no stray references after delete:**

```bash
rg 'StoredAlbums|StoredAlbum' --glob '*.swift'
```

Expected: no matches under `MusicWall/` or `MusicWallTests/` (skills/docs may still mention them).

---

### Task 1: `AlbumRecord` Codable + `albumRecordsItems` key

**Files:**
- Modify: `MusicWall/Core/AlbumRecord.swift`
- Modify: `MusicWall/Core/PreferencesKey.swift`
- Create: `MusicWallTests/Core/AlbumRecordCodableTests.swift`

- [ ] **Step 1: Add `PreferencesKey.albumRecordsItems`**

```swift
enum PreferencesKey: String, CaseIterable, Sendable {
    case albumRecordsItems = "albumRecordsItemsKey"
    case storedAlbumsItems = "savedAlbumsItemsKey"
  // ... existing cases unchanged
}
```

- [ ] **Step 2: Add `Identifiable` + `Codable` to `AlbumRecord`**

`AlbumID` is already `Codable`. Use explicit decode so `isExplicit` defaults when absent:

```swift
struct AlbumRecord: Equatable, Sendable, Identifiable, Codable {
    let id: AlbumID
    let title: String
    let artistName: String
    let releaseDate: Date?
    let isExplicit: Bool

    enum CodingKeys: String, CodingKey {
        case id, title, artistName, releaseDate, isExplicit
    }

    init(
        id: AlbumID,
        title: String,
        artistName: String,
        releaseDate: Date?,
        isExplicit: Bool
    ) {
        self.id = id
        self.title = title
        self.artistName = artistName
        self.releaseDate = releaseDate
        self.isExplicit = isExplicit
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(AlbumID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        artistName = try container.decode(String.self, forKey: .artistName)
        releaseDate = try container.decodeIfPresent(Date.self, forKey: .releaseDate)
        isExplicit = try container.decodeIfPresent(Bool.self, forKey: .isExplicit) ?? false
    }
}
```

(Synthesized `encode(to:)` is fine.)

- [ ] **Step 3: Write `AlbumRecordCodableTests`**

```swift
import Foundation
import Testing
@testable import MusicWall

struct AlbumRecordCodableTests {
    @Test
    func roundTripIncludesIsExplicit() throws {
        let record = AlbumFixtures.record(
            id: "id-1",
            title: "Take Care",
            artistName: "Drake",
            isExplicit: true
        )
        let data = try JSONEncoder().encode([record])
        let decoded = try JSONDecoder().decode([AlbumRecord].self, from: data)
        #expect(decoded == [record])
    }

    @Test
    func missingIsExplicitDefaultsFalse() throws {
        let json = """
        [{"id":"id-1","title":"T","artistName":"A"}]
        """
        let data = Data(json.utf8)
        let decoded = try JSONDecoder().decode([AlbumRecord].self, from: data)
        #expect(decoded.count == 1)
        #expect(decoded[0].isExplicit == false)
    }
}
```

- [ ] **Step 4: Register test file in `project.pbxproj`**

- [ ] **Step 5: Run tests**

```bash
xcodebuild test -project MusicWall.xcodeproj -scheme MusicWall \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:MusicWallTests/AlbumRecordCodableTests -quiet
```

Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add MusicWall/Core/AlbumRecord.swift MusicWall/Core/PreferencesKey.swift \
  MusicWallTests/Core/AlbumRecordCodableTests.swift MusicWall.xcodeproj/project.pbxproj
git commit -m "feat: add AlbumRecord Codable and albumRecordsItems key"
```

---

### Task 2: `LegacyStoredAlbum` adapter

**Files:**
- Create: `MusicWall/Adapters/LegacyStoredAlbum.swift`

- [ ] **Step 1: Add legacy type (MusicKit only here)**

```swift
import Foundation
import MusicKit

/// Decodes pre-PR-6 `StoredAlbum` JSON from `savedAlbumsItemsKey`. Do not use in UI.
struct LegacyStoredAlbum: Codable {
    let id: MusicItemID
    let title: String
    let artistName: String
    let releaseDate: Date?

    func asAlbumRecord() -> AlbumRecord {
        AlbumRecord(
            id: AlbumID(rawValue: id.rawValue),
            title: title,
            artistName: artistName,
            releaseDate: releaseDate,
            isExplicit: false
        )
    }
}
```

- [ ] **Step 2: Build**

```bash
xcodebuild build -project MusicWall.xcodeproj -scheme MusicWall \
  -destination 'platform=iOS Simulator,name=iPhone 17' -quiet
```

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add MusicWall/Adapters/LegacyStoredAlbum.swift
git commit -m "feat: add LegacyStoredAlbum for migration decode"
```

---

### Task 3: Golden legacy JSON fixture

**Files:**
- Create: `MusicWallTests/Fixtures/legacy_stored_albums_v1.json`
- Create: `MusicWallTests/Fixtures/LegacyFixtureGeneratorTests.swift` (temporary; can delete after fixture committed)

- [ ] **Step 1: Add generator test to produce fixture bytes**

```swift
import Foundation
import MusicKit
import Testing
@testable import MusicWall

struct LegacyFixtureGeneratorTests {
    @Test
    func encodeSampleLegacyLibrary() throws {
        let legacy = [
            LegacyStoredAlbum(
                id: MusicItemID("golden-album-1"),
                title: "Take Care",
                artistName: "Drake",
                releaseDate: nil
            ),
            LegacyStoredAlbum(
                id: MusicItemID("golden-album-2"),
                title: "Edited Title",
                artistName: "Local Artist",
                releaseDate: Date(timeIntervalSince1970: 1_300_000_000)
            ),
        ]
        let data = try JSONEncoder().encode(legacy)
        let json = String(decoding: data, as: UTF8.self)
        print("LEGACY_FIXTURE_JSON:\n\(json)")
        #expect(!data.isEmpty)
    }
}
```

- [ ] **Step 2: Run test and capture JSON**

```bash
xcodebuild test -project MusicWall.xcodeproj -scheme MusicWall \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:MusicWallTests/LegacyFixtureGeneratorTests/encodeSampleLegacyLibrary 2>&1 \
  | tee /tmp/legacy-fixture.log
grep -A999 'LEGACY_FIXTURE_JSON:' /tmp/legacy-fixture.log | tail -n +2 > MusicWallTests/Fixtures/legacy_stored_albums_v1.json
```

Verify file decodes:

```bash
# Manual: open JSON and confirm it is valid; loader tests will assert decode.
```

- [ ] **Step 3: Add `legacy_stored_albums_v1.json` to test target Copy Bundle Resources in `project.pbxproj`**

- [ ] **Step 4: Delete `LegacyFixtureGeneratorTests.swift` OR keep with `#expect` against bundle file only**

Preferred: replace generator test with:

```swift
@Test
func legacyFixtureDecodes() throws {
    let url = try #require(Bundle(for: BundleToken.self).url(
        forResource: "legacy_stored_albums_v1",
        withExtension: "json"
    ))
    let data = try Data(contentsOf: url)
    let legacy = try JSONDecoder().decode([LegacyStoredAlbum].self, from: data)
    #expect(legacy.count == 2)
}
private enum BundleToken {}
```

- [ ] **Step 5: Commit fixture + bundle wiring**

```bash
git add MusicWallTests/Fixtures/legacy_stored_albums_v1.json \
  MusicWallTests/Fixtures/LegacyFixtureGeneratorTests.swift \
  MusicWall.xcodeproj/project.pbxproj
git commit -m "test: add golden legacy StoredAlbum JSON fixture"
```

---

### Task 4: `InMemoryPreferencesStore` test helper

**Files:**
- Create: `MusicWallTests/TestSupport/InMemoryPreferencesStore.swift`

- [ ] **Step 1: Implement**

```swift
import Foundation
@testable import MusicWall

final class InMemoryPreferencesStore: PreferencesStore, @unchecked Sendable {
    private var storage: [PreferencesKey: Data] = [:]

    func save<T: Encodable>(_ value: T, for key: PreferencesKey) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        storage[key] = data
    }

    func load<T: Decodable>(_ type: T.Type, for key: PreferencesKey) -> T? {
        guard let data = storage[key] else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    func data(for key: PreferencesKey) -> Data? {
        storage[key]
    }
}
```

- [ ] **Step 2: Register in `project.pbxproj`**

- [ ] **Step 3: Commit**

```bash
git add MusicWallTests/TestSupport/InMemoryPreferencesStore.swift MusicWall.xcodeproj/project.pbxproj
git commit -m "test: add InMemoryPreferencesStore"
```

---

### Task 5: `AlbumLibraryLoader` + unit tests

**Files:**
- Create: `MusicWall/Adapters/AlbumLibraryLoader.swift`
- Create: `MusicWallTests/Core/AlbumLibraryLoaderTests.swift`

- [ ] **Step 1: Add loader result type + API** (`Adapters/` — may import `LegacyStoredAlbum` and Core types only)

```swift
import Foundation

enum AlbumLibraryLoader {
    struct LoadResult: Equatable {
        let records: [AlbumRecord]
        /// When true, caller must persist via `collection.replaceAll(..., persist: true)`.
        let shouldPersistCanonical: Bool
    }

  @MainActor
  static func load(
    preferences: PreferencesStore,
    repository: any AlbumRepository
  ) async -> LoadResult {
    if let records = preferences.load([AlbumRecord].self, for: .albumRecordsItems),
       !records.isEmpty {
      return LoadResult(records: records, shouldPersistCanonical: false)
    }

    if let legacy = preferences.load([LegacyStoredAlbum].self, for: .storedAlbumsItems),
       !legacy.isEmpty {
      return LoadResult(
        records: legacy.map { $0.asAlbumRecord() },
        shouldPersistCanonical: true
      )
    }

    let backupIDs = preferences.load([String].self, for: .backupAlbumIDs) ?? []
    guard !backupIDs.isEmpty else {
      return LoadResult(records: [], shouldPersistCanonical: false)
    }

    let ids = backupIDs.map { AlbumID(rawValue: $0) }
    let fetched = (try? await repository.fetch(ids: ids)) ?? []
    return LoadResult(records: fetched, shouldPersistCanonical: !fetched.isEmpty)
  }
}
```

- [ ] **Step 2: Write loader tests**

```swift
import Foundation
import Testing
@testable import MusicWall

struct AlbumLibraryLoaderTests {
    @Test
    func loadsFromNewKeyWhenPresent() async {
        let prefs = InMemoryPreferencesStore()
        let expected = [AlbumFixtures.record(id: "a", title: "A", artistName: "X")]
        prefs.save(expected, for: .albumRecordsItems)

        let result = await AlbumLibraryLoader.load(
            preferences: prefs,
            repository: MockAlbumRepository()
        )

        #expect(result.records == expected)
        #expect(result.shouldPersistCanonical == false)
    }

    @Test
    func migratesLegacyFixtureAndFlagsPersist() async throws {
        let prefs = InMemoryPreferencesStore()
        let url = try #require(Bundle(for: BundleToken.self).url(
            forResource: "legacy_stored_albums_v1",
            withExtension: "json"
        ))
        prefs.setRaw(Data(contentsOf: url), for: .storedAlbumsItems)

        let result = await AlbumLibraryLoader.load(
            preferences: prefs,
            repository: MockAlbumRepository()
        )

        #expect(result.records.count == 2)
        #expect(result.records[1].title == "Edited Title")
        #expect(result.records.allSatisfy { !$0.isExplicit })
        #expect(result.shouldPersistCanonical == true)
    }

    @Test
    func hydratesFromBackupWhenCanonicalAndLegacyEmpty() async {
        let prefs = InMemoryPreferencesStore()
        prefs.save(["id-1", "id-2"], for: .backupAlbumIDs)

        let repo = MockAlbumRepository()
        repo.fetchHandler = { ids in
            ids.map { AlbumFixtures.record(id: $0.rawValue, title: "T", artistName: "A") }
        }

        let result = await AlbumLibraryLoader.load(preferences: prefs, repository: repo)

        #expect(result.records.count == 2)
        #expect(result.shouldPersistCanonical == true)
        #expect(repo.fetchCalls.count == 1)
    }

    @Test
    func fetchThrowsLeavesEmpty() async {
        let prefs = InMemoryPreferencesStore()
        prefs.save(["id-1"], for: .backupAlbumIDs)

        let repo = MockAlbumRepository()
        repo.fetchHandler = { _ in throw AlbumRepositoryError.networkError("offline") }

        let result = await AlbumLibraryLoader.load(preferences: prefs, repository: repo)

        #expect(result.records.isEmpty)
        #expect(result.shouldPersistCanonical == false)
    }

    @Test
    func partialFetchReturnsSubset() async {
        let prefs = InMemoryPreferencesStore()
        prefs.save(["id-1", "id-missing"], for: .backupAlbumIDs)

        let repo = MockAlbumRepository()
        repo.fetchHandler = { ids in
            ids.filter { $0.rawValue == "id-1" }.map {
                AlbumFixtures.record(id: $0.rawValue, title: "T", artistName: "A")
            }
        }

        let result = await AlbumLibraryLoader.load(preferences: prefs, repository: repo)

        #expect(result.records.count == 1)
        #expect(result.records[0].id.rawValue == "id-1")
    }
}

private enum BundleToken {}

```

Add to `InMemoryPreferencesStore` (Task 4):

```swift
func setRaw(_ data: Data, for key: PreferencesKey) {
    storage[key] = data
}
```

- [ ] **Step 3: Add migration persist integration test**

After `AlbumStore` exists (Task 6), or test collection directly:

```swift
@Test
func legacyMigrateWritesNewKey() async {
    let prefs = InMemoryPreferencesStore()
    // ... seed legacy fixture ...
    let collection = AlbumCollection(
        persistItems: { prefs.save($0, for: .albumRecordsItems) },
        persistBackupIDs: { prefs.save($0, for: .backupAlbumIDs) }
    )
    let result = await AlbumLibraryLoader.load(preferences: prefs, repository: MockAlbumRepository())
    collection.performWithoutPersist {
        collection.replaceAll(result.records, persist: false)
    }
    if result.shouldPersistCanonical {
        collection.replaceAll(collection.items, persist: true)
    }
    let saved = prefs.load([AlbumRecord].self, for: .albumRecordsItems)
    #expect(saved?.count == 2)
    #expect(prefs.load([LegacyStoredAlbum].self, for: .storedAlbumsItems) != nil) // legacy blob untouched
}
```

- [ ] **Step 4: Register test file; run**

```bash
xcodebuild test -project MusicWall.xcodeproj -scheme MusicWall \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:MusicWallTests/AlbumLibraryLoaderTests -quiet
```

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add MusicWall/Adapters/AlbumLibraryLoader.swift \
  MusicWallTests/Core/AlbumLibraryLoaderTests.swift \
  MusicWallTests/TestSupport/InMemoryPreferencesStore.swift \
  MusicWall.xcodeproj/project.pbxproj
git commit -m "feat: add AlbumLibraryLoader with migration and backup tests"
```

---

### Task 6: `AlbumStore` in Features/Home

**Files:**
- Create: `MusicWall/Features/Home/AlbumStore.swift`
- Modify: `MusicWall/Album.swift` (temporary — keep until Task 8, or delete after store compiles)

Port logic from `StoredAlbums` in `Album.swift` (lines 31–187). Key differences: persist `[AlbumRecord]` to `.albumRecordsItems`; use `AlbumLibraryLoader`; expose `[AlbumRecord]` items.

- [ ] **Step 1: Create `AlbumStore`**

```swift
import Foundation
import Observation

@Observable
final class AlbumStore {
    enum SortOption: String, CaseIterable, Identifiable, Codable {
        case artist = "Artist"
        case title = "Title"
        case date = "Year"
        var id: String { rawValue }
    }

    private let preferences: PreferencesStore
    private let repository: any AlbumRepository
    private let collection: AlbumCollection

    private(set) var items: [AlbumRecord] = []

    var currentSort: SortOption = .artist {
        didSet { preferences.save(currentSort, for: .currentSort) }
    }
    var sortDirection: [SortOption: Bool] = [:] {
        didSet { preferences.save(sortDirection, for: .sortDirection) }
    }

    init(preferences: PreferencesStore, repository: any AlbumRepository) {
        self.preferences = preferences
        self.repository = repository
        self.collection = Self.makeCollection(preferences: preferences)
    }

    private static func makeCollection(preferences: PreferencesStore) -> AlbumCollection {
        AlbumCollection(
            persistItems: { records in
                preferences.save(records, for: .albumRecordsItems)
            },
            persistBackupIDs: { ids in
                preferences.save(ids, for: .backupAlbumIDs)
            }
        )
    }

    private func syncItemsFromCollection() {
        items = collection.items
    }

    @MainActor
    func load() async {
        let result = await AlbumLibraryLoader.load(
            preferences: preferences,
            repository: repository
        )
        collection.performWithoutPersist {
            collection.replaceAll(result.records, persist: false)
        }
        if result.shouldPersistCanonical {
            collection.replaceAll(collection.items, persist: true)
        }
        loadSort()
        syncItemsFromCollection()
    }

    private func loadSort() {
        sortDirection = preferences.load([SortOption: Bool].self, for: .sortDirection) ?? [:]
        currentSort = preferences.load(SortOption.self, for: .currentSort) ?? .artist
    }

    func applySort() {
        let ascending = sortDirection[currentSort] ?? true
        collection.applySort(key: currentSort.albumSortKey, ascending: ascending)
        syncItemsFromCollection()
    }

    func addAlbum(_ record: AlbumRecord) {
        if collection.add(record) {
            applySort()
        }
    }

    func updateAlbum(_ record: AlbumRecord) {
        let existed = collection.contains(id: record.id)
        collection.update(record)
        if existed {
            applySort()
        } else {
            syncItemsFromCollection()
        }
    }

    func remove(album: AlbumRecord) {
        collection.remove(id: album.id)
        syncItemsFromCollection()
    }

    func remove(atOffsets offsets: IndexSet) {
        let ids = offsets.map { items[$0].id }
        for id in ids {
            collection.remove(id: id)
        }
        syncItemsFromCollection()
    }

    func temporarilyShuffle() {
        collection.temporarilyShuffle()
        syncItemsFromCollection()
    }

    func exportAlbumIDs() -> [String] {
        collection.exportIDs()
    }

    @MainActor
    func importAlbums(from ids: [String]) async throws {
        guard !ids.isEmpty else { return }
        let albumIDs = ids.map { AlbumID(rawValue: $0) }
        let fetched = try await repository.fetch(ids: albumIDs)
        collection.performWithoutPersist {
            for record in fetched where !collection.contains(id: record.id) {
                _ = collection.add(record)
            }
        }
        applySort()
    }

    func toggleSortDirection(for option: SortOption) {
        sortDirection[option] = !(sortDirection[option] ?? true)
    }

    func isAscending(for option: SortOption) -> Bool {
        sortDirection[option] ?? true
    }

    static func dummyData(
        preferences: PreferencesStore,
        repository: any AlbumRepository
    ) -> AlbumStore {
        let store = AlbumStore(preferences: preferences, repository: repository)
        let samples = [
            AlbumFixtures.record(id: "preview-1", title: "Take Care", artistName: "Drake", releaseDate: Date()),
            AlbumFixtures.record(id: "preview-2", title: "Born Sinners", artistName: "J. Cole"),
            AlbumFixtures.record(id: "preview-3", title: "GKMC", artistName: "Kendrick Lamar", releaseDate: Date()),
        ]
        store.collection.performWithoutPersist {
            store.collection.replaceAll(samples, persist: false)
        }
        store.syncItemsFromCollection()
        return store
    }
}
```

Add `extension AlbumStore.SortOption` with `var albumSortKey: AlbumSortKey` (copy switch from `StoredAlbum+AlbumRecord.swift`).

**Note:** `dummyData` needs `performWithoutPersist` on the collection — either expose `fileprivate let collection` within the module or duplicate seeding via public `addAlbum` calls after init.

- [ ] **Step 2: Build (both `AlbumStore` and old `StoredAlbums` may coexist briefly)**

```bash
xcodebuild build -project MusicWall.xcodeproj -scheme MusicWall \
  -destination 'platform=iOS Simulator,name=iPhone 17' -quiet
```

- [ ] **Step 3: Commit**

```bash
git add MusicWall/Features/Home/AlbumStore.swift
git commit -m "feat: add AlbumStore in Features/Home"
```

---

### Task 7: Composition root — `ContentView` + `HomePageView`

**Files:**
- Modify: `MusicWall/ContentView.swift`
- Modify: `MusicWall/HomePageView.swift`

- [ ] **Step 1: `ContentView`**

```swift
HomePageView(
    store: AlbumStore(
        preferences: store,
        repository: dependencies.albumRepository
    ),
    preferences: store,
    dependencies: dependencies
)
```

- [ ] **Step 2: `HomePageView`**

Replace `albums: StoredAlbums` with `store: AlbumStore`:

```swift
@State var store: AlbumStore

init(store: AlbumStore, preferences: PreferencesStore, dependencies: AppDependencies) {
    self._store = State(initialValue: store)
    // ...
}

// body:
.environment(store)
.task { await store.load() }

// onSearchSelect:
store.addAlbum(record)

// import/export/shuffle:
store.importAlbums(from: ids)
store.exportAlbumIDs()
store.temporarilyShuffle()
```

- [ ] **Step 3: `SortMenu`**

```swift
@Environment(AlbumStore.self) private var store
ForEach(AlbumStore.SortOption.allCases) { option in
    // store.currentSort, store.applySort(), etc.
}
```

- [ ] **Step 4: Update previews at bottom of `HomePageView.swift`**

```swift
store: AlbumStore.dummyData(
    preferences: deps.preferencesStore,
    repository: deps.albumRepository
)
```

- [ ] **Step 5: Build**

```bash
xcodebuild build -project MusicWall.xcodeproj -scheme MusicWall \
  -destination 'platform=iOS Simulator,name=iPhone 17' -quiet
```

- [ ] **Step 6: Commit**

```bash
git add MusicWall/ContentView.swift MusicWall/HomePageView.swift
git commit -m "refactor: wire ContentView and HomePageView to AlbumStore"
```

---

### Task 8: Views — `LayoutViews`, `AlbumEditView`, `AlbumArtwork`

**Files:**
- Modify: `MusicWall/LayoutViews.swift`
- Modify: `MusicWall/AlbumEditView.swift`

- [ ] **Step 1: Replace environment and types**

| Was | Becomes |
|-----|---------|
| `@Environment(StoredAlbums.self) var albums` | `@Environment(AlbumStore.self) var store` |
| `StoredAlbum` | `AlbumRecord` |
| `albums.items` | `store.items` |
| `albums.addAlbum` / `remove` / `updateAlbum` | `store.*` |
| `album.id.rawValue` | `album.id.rawValue` (unchanged — `AlbumID`) |
| `ForEach(albums.items)` | `ForEach(store.items)` (`AlbumRecord` is `Identifiable`) |

- [ ] **Step 2: `AlbumEditView` save**

```swift
struct AlbumEditView: View {
    let album: AlbumRecord
    let onSave: (AlbumRecord) -> Void
    // ...
    private func saveAlbum() {
        let updated = AlbumRecord(
            id: album.id,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            artistName: artistName.trimmingCharacters(in: .whitespacesAndNewlines),
            releaseDate: releaseDate,
            isExplicit: album.isExplicit
        )
        onSave(updated)
        dismiss()
    }
}
```

- [ ] **Step 3: `AlbumArtwork`**

```swift
struct AlbumArtwork: View {
    let album: AlbumRecord
    // ...
    imageURL = await ImageCache(repository: albumRepository).getArtwork(
        albumID: album.id.rawValue,
        size: pixelSize
    )
}
```

- [ ] **Step 4: Update `#Preview` in `LayoutViews.swift`**

Use `AlbumStore.dummyData` + `.environment(store)`.

- [ ] **Step 5: Build + smoke**

```bash
xcodebuild build -project MusicWall.xcodeproj -scheme MusicWall \
  -destination 'platform=iOS Simulator,name=iPhone 17' -quiet
```

- [ ] **Step 6: Commit**

```bash
git add MusicWall/LayoutViews.swift MusicWall/AlbumEditView.swift
git commit -m "refactor: migrate layouts and edit view to AlbumRecord and AlbumStore"
```

---

### Task 9: Remove `StoredAlbum` / `StoredAlbums`

**Files:**
- Delete: `MusicWall/Album.swift`
- Delete: `MusicWall/StoredAlbum+AlbumRecord.swift`

- [ ] **Step 1: Delete files**

```bash
git rm MusicWall/Album.swift MusicWall/StoredAlbum+AlbumRecord.swift
```

- [ ] **Step 2: Verify no references**

```bash
rg 'StoredAlbums|StoredAlbum' --glob '*.swift'
```

Expected: no matches in `MusicWall/` or `MusicWallTests/`.

- [ ] **Step 3: Build + full CI tests**

```bash
bundle exec fastlane ci_tests
```

Expected: green

- [ ] **Step 4: Commit**

```bash
git commit -m "refactor: remove StoredAlbums facade and StoredAlbum UI type"
```

---

### Task 10: Update preferences adapter tests

**Files:**
- Modify: `MusicWallTests/Adapters/UserDefaultsPreferencesStoreTests.swift`

- [ ] **Step 1: Replace `roundTripStoredAlbumsItems`**

```swift
@Test
func roundTripAlbumRecordsItems() {
    let (store, suiteName) = makeStore()
    defer { UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName) }

    let albums = [
        AlbumFixtures.record(id: "fixture-round-trip", title: "Take Care", artistName: "Drake", isExplicit: true),
    ]
    store.save(albums, for: .albumRecordsItems)
    let loaded = store.load([AlbumRecord].self, for: .albumRecordsItems)
    #expect(loaded == albums)
}

@Test
func roundTripLegacyStoredAlbumsItems() {
    let (store, suiteName) = makeStore()
    defer { UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName) }

    let legacy = [
        LegacyStoredAlbum(
            id: MusicItemID("legacy-round-trip"),
            title: "Take Care",
            artistName: "Drake",
            releaseDate: nil
        ),
    ]
    store.save(legacy, for: .storedAlbumsItems)
    let loaded = store.load([LegacyStoredAlbum].self, for: .storedAlbumsItems)
    #expect(loaded?.first?.id.rawValue == "legacy-round-trip")
}
```

- [ ] **Step 2: Update sort round-trip tests**

```swift
let value: [AlbumStore.SortOption: Bool] = [.artist: true, .title: false]
store.save(AlbumStore.SortOption.artist, for: .currentSort)
```

- [ ] **Step 3: Run adapter tests**

```bash
xcodebuild test -project MusicWall.xcodeproj -scheme MusicWall \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:MusicWallTests/UserDefaultsPreferencesStoreTests -quiet
```

- [ ] **Step 4: Commit**

```bash
git add MusicWallTests/Adapters/UserDefaultsPreferencesStoreTests.swift
git commit -m "test: update preferences store tests for AlbumRecord and legacy decode"
```

---

### Task 11: Final verification + PR metadata

- [ ] **Step 1: Full test suite**

```bash
bundle exec fastlane ci_tests
```

- [ ] **Step 2: Reference grep**

```bash
rg 'MusicService|StoredAlbums|StoredAlbum' --glob '*.swift'
```

Expected: no app/test Swift matches.

- [ ] **Step 3: PR description checklist** (from spec Human verification)

- Install over existing local/TestFlight library
- Add album + relaunch
- Local edit survives relaunch (legacy path)
- Airplane mode after migrate shows library

- [ ] **Step 4: Commit plan doc if not already on branch**

```bash
git add docs/plans/2026-05-28-pr-06-load-migration.md
git commit -m "docs: add PR 6 load migration implementation plan"
```

---

## Spec coverage checklist

| Spec requirement | Task |
|------------------|------|
| New `albumRecordsItems` key | Task 1 |
| `AlbumRecord` Codable + `isExplicit` default | Task 1 |
| `LegacyStoredAlbum` outside Core | Task 2 |
| Golden legacy fixture | Task 3 |
| Load order new → legacy → backup | Task 5 |
| Stop writing legacy key | Task 6 persist closures |
| Backup IDs on persist | Task 6 |
| `AlbumStore` in Features/Home | Task 6 |
| Views use `AlbumStore` + `AlbumRecord` | Tasks 7–8 |
| Remove `StoredAlbums` | Task 9 |
| Migration / backup / partial / throw tests | Tasks 3, 5 |
| `ci-tests` green | Task 11 |

## PR delivery

- **Title:** `test refactor PR 6: load, migration, AlbumStore`
- **Link:** PR 6 of 14; spec `docs/specs/2026-05-28-pr-06-load-migration-design.md`
- **Human QA:** paste checklist from Task 11 Step 3

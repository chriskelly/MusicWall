# Backup Full Album Data Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Upgrade file backup export/import to persist full `AlbumRecord` data (preserving local edits) while remaining backward-compatible with legacy ID-only backup files.

**Architecture:** Introduce a versioned v2 JSON envelope (`{"version": 2, "albums": [...]}`) encoded/decoded by `BackupCodec`, surfaced as a `BackupContents` enum (`.records` vs `.ids`). `AlbumStore.importBackup` adds v2 records directly without MusicKit fetch; legacy `.ids` delegates to the existing fetch path.

**Tech Stack:** Swift, SwiftUI, Swift Testing, MusicKit (legacy import only), Xcode scheme `MusicWall`, iPhone 17 simulator

**Design spec:** `docs/specs/2026-06-06-backup-full-album-data-design.md`

---

## File map

| File | Responsibility |
|------|----------------|
| `MusicWall/Core/BackupContents.swift` | Decode result type (new) |
| `MusicWall/Core/BackupCodec.swift` | v2 encode + dual-format decode |
| `MusicWall/Core/AlbumBackupService.swift` | Protocol: `exportAlbums` / `importBackup` |
| `MusicWall/Adapters/LiveAlbumBackupService.swift` | Live backup I/O |
| `MusicWall/Adapters/FileExportService.swift` | Temp file write + filename |
| `MusicWall/Features/Home/AlbumStore.swift` | `importBackup`; remove `exportAlbumIDs` |
| `MusicWall/Core/AlbumCollection.swift` | Remove `exportIDs` |
| `MusicWall/Features/Home/HomeViewModel.swift` | Export records; route `BackupContents` |
| `MusicWall/Features/Home/HomePageView.swift` | Menu label copy |
| `MusicWallTests/TestSupport/MockAlbumBackupService.swift` | Updated mock |
| `MusicWallTests/Core/BackupCodecTests.swift` | v2 + legacy codec tests |
| `MusicWallTests/Adapters/LiveAlbumBackupServiceTests.swift` | Service round-trip tests |
| `MusicWallTests/Adapters/FileExportServiceTests.swift` | Filename prefix test |
| `MusicWallTests/Core/AlbumStoreImportTests.swift` | `.records` import tests |
| `MusicWallTests/Core/AlbumCollectionTests.swift` | Remove `exportIDs` assertions |
| `MusicWallTests/Features/Home/HomeViewModelTests.swift` | Updated mock expectations |

`MusicWall/` uses `PBXFileSystemSynchronizedRootGroup` — new files under `MusicWall/Core/` are picked up automatically; no `project.pbxproj` edit needed.

---

### Task 1: `BackupContents` type

**Files:**
- Create: `MusicWall/Core/BackupContents.swift`

- [ ] **Step 1: Create the type**

```swift
import Foundation

enum BackupContents: Equatable, Sendable {
    case records([AlbumRecord])
    case ids([String])

    var count: Int {
        switch self {
        case .records(let records): records.count
        case .ids(let ids): ids.count
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add MusicWall/Core/BackupContents.swift
git commit -m "feat: add BackupContents decode result type"
```

---

### Task 2: `BackupCodec` v2 encode + dual decode

**Files:**
- Modify: `MusicWall/Core/BackupCodec.swift`
- Test: `MusicWallTests/Core/BackupCodecTests.swift`

- [ ] **Step 1: Replace codec tests with v2 + legacy coverage**

Replace the entire contents of `MusicWallTests/Core/BackupCodecTests.swift`:

```swift
import Foundation
import Testing
@testable import MusicWall

struct BackupCodecTests {
    private let codec = BackupCodec()

    private var sampleRecords: [AlbumRecord] {
        [
            AlbumFixtures.record(
                id: "fixture-a",
                title: "Take Care",
                artistName: "Drake",
                releaseDate: AlbumFixtures.utcDate(year: 2011, month: 11, day: 15),
                isExplicit: true
            ),
            AlbumFixtures.record(id: "fixture-b", title: "Born Sinners", artistName: "J. Cole"),
        ]
    }

    @Test
    func roundTripEncodesAndDecodesV2Records() throws {
        let records = sampleRecords
        let data = try codec.encode(records)
        let decoded = try codec.decode(data)
        #expect(decoded == .records(records))
    }

    @Test
    func decodeLegacyIDArrayReturnsIds() throws {
        let data = Data(#"["legacy-a","legacy-b"]"#.utf8)
        let decoded = try codec.decode(data)
        #expect(decoded == .ids(["legacy-a", "legacy-b"]))
    }

    @Test
    func decodeEmptyV2AlbumsThrowsEmptyImport() {
        let data = Data(#"{"version":2,"albums":[]}"#.utf8)
        #expect(throws: BackupError.emptyImport) {
            _ = try codec.decode(data)
        }
    }

    @Test
    func decodeEmptyLegacyArrayThrowsEmptyImport() {
        #expect(throws: BackupError.emptyImport) {
            _ = try codec.decode(Data("[]".utf8))
        }
    }

    @Test
    func decodeInvalidJSONThrowsInvalidFormat() {
        #expect(throws: BackupError.invalidFormat) {
            _ = try codec.decode(Data("{".utf8))
        }
    }

    @Test
    func decodeNonArrayLegacyJSONThrowsInvalidFormat() {
        #expect(throws: BackupError.invalidFormat) {
            _ = try codec.decode(Data("\"not-an-array\"".utf8))
        }
    }

    @Test
    func decodeWrongLegacyElementTypeThrowsInvalidFormat() {
        #expect(throws: BackupError.invalidFormat) {
            _ = try codec.decode(Data("[1, 2]".utf8))
        }
    }

    @Test
    func decodeUnsupportedVersionThrowsInvalidFormat() {
        let data = Data(#"{"version":99,"albums":[{"id":"x","title":"T","artistName":"A"}]}"#.utf8)
        #expect(throws: BackupError.invalidFormat) {
            _ = try codec.decode(data)
        }
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run:
```bash
xcodebuild test -project MusicWall.xcodeproj -scheme MusicWall \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:MusicWallTests/BackupCodecTests 2>&1 | tail -20
```
Expected: FAIL — `encode`/`decode` signatures and `BackupContents` mismatch.

- [ ] **Step 3: Implement `BackupCodec`**

Replace the entire contents of `MusicWall/Core/BackupCodec.swift`:

```swift
import Foundation

struct BackupCodec {
    private struct BackupEnvelope: Codable {
        let version: Int
        let albums: [AlbumRecord]
    }

    private static let currentVersion = 2

    func encode(_ albums: [AlbumRecord]) throws -> Data {
        let envelope = BackupEnvelope(version: Self.currentVersion, albums: albums)
        do {
            return try JSONEncoder().encode(envelope)
        } catch {
            throw BackupError.invalidFormat
        }
    }

    func decode(_ data: Data) throws -> BackupContents {
        if let envelope = try? JSONDecoder().decode(BackupEnvelope.self, from: data) {
            guard envelope.version == Self.currentVersion else {
                throw BackupError.invalidFormat
            }
            guard !envelope.albums.isEmpty else {
                throw BackupError.emptyImport
            }
            return .records(envelope.albums)
        }

        let ids: [String]
        do {
            ids = try JSONDecoder().decode([String].self, from: data)
        } catch {
            throw BackupError.invalidFormat
        }
        guard !ids.isEmpty else {
            throw BackupError.emptyImport
        }
        return .ids(ids)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run the same `xcodebuild` command from Step 2.
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add MusicWall/Core/BackupCodec.swift MusicWallTests/Core/BackupCodecTests.swift
git commit -m "feat: encode full album records in v2 backup format"
```

---

### Task 3: `AlbumBackupService` protocol + live service

**Files:**
- Modify: `MusicWall/Core/AlbumBackupService.swift`
- Modify: `MusicWall/Adapters/LiveAlbumBackupService.swift`
- Test: `MusicWallTests/Adapters/LiveAlbumBackupServiceTests.swift`

- [ ] **Step 1: Update live service tests**

Replace the entire contents of `MusicWallTests/Adapters/LiveAlbumBackupServiceTests.swift`:

```swift
import Foundation
import Testing
@testable import MusicWall

struct LiveAlbumBackupServiceTests {
    private struct DenyingReader: SecurityScopedReader {
        func readData(from url: URL) throws -> Data {
            throw BackupError.fileAccessDenied
        }
    }

    private var sampleRecords: [AlbumRecord] {
        [
            AlbumFixtures.record(id: "id-a", title: "Album A", artistName: "Artist A"),
            AlbumFixtures.record(id: "id-b", title: "Album B", artistName: "Artist B"),
        ]
    }

    @Test
    func exportEmptyAlbumsThrowsEmptyExport() {
        let service = LiveAlbumBackupService(reader: DirectFileReader())
        #expect(throws: BackupError.emptyExport) {
            _ = try service.exportAlbums([])
        }
    }

    @Test
    func exportImportV2RoundTrip() throws {
        let service = LiveAlbumBackupService(reader: DirectFileReader())
        let records = sampleRecords
        let url = try service.exportAlbums(records)
        defer { try? FileManager.default.removeItem(at: url) }

        let imported = try service.importBackup(from: url)
        #expect(imported == .records(records))
    }

    @Test
    func importLegacyIDsRoundTrip() throws {
        let legacyData = Data(#"["legacy-a","legacy-b"]"#.utf8)
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("legacy-\(UUID().uuidString).json")
        try legacyData.write(to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let service = LiveAlbumBackupService(reader: DirectFileReader())
        let imported = try service.importBackup(from: tempURL)
        #expect(imported == .ids(["legacy-a", "legacy-b"]))
    }

    @Test
    func importPropagatesFileAccessDenied() {
        let service = LiveAlbumBackupService(reader: DenyingReader())
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("unused-\(UUID().uuidString).json")

        #expect(throws: BackupError.fileAccessDenied) {
            _ = try service.importBackup(from: url)
        }
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run:
```bash
xcodebuild test -project MusicWall.xcodeproj -scheme MusicWall \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:MusicWallTests/LiveAlbumBackupServiceTests 2>&1 | tail -20
```
Expected: FAIL — protocol methods renamed.

- [ ] **Step 3: Update protocol and live service**

`MusicWall/Core/AlbumBackupService.swift`:

```swift
import Foundation

protocol AlbumBackupService: Sendable {
    func exportAlbums(_ albums: [AlbumRecord]) throws -> URL
    func importBackup(from url: URL) throws -> BackupContents
}
```

`MusicWall/Adapters/LiveAlbumBackupService.swift`:

```swift
import Foundation

struct LiveAlbumBackupService: AlbumBackupService {
    private let codec: BackupCodec
    private let exportService: FileExportService
    private let reader: any SecurityScopedReader

    init(
        codec: BackupCodec = BackupCodec(),
        exportService: FileExportService = FileExportService(),
        reader: any SecurityScopedReader = SecurityScopedResourceReader()
    ) {
        self.codec = codec
        self.exportService = exportService
        self.reader = reader
    }

    func exportAlbums(_ albums: [AlbumRecord]) throws -> URL {
        guard !albums.isEmpty else {
            throw BackupError.emptyExport
        }
        let data = try codec.encode(albums)
        return try exportService.write(data)
    }

    func importBackup(from url: URL) throws -> BackupContents {
        let data = try reader.readData(from: url)
        return try codec.decode(data)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run the same `xcodebuild` command from Step 2.
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add MusicWall/Core/AlbumBackupService.swift MusicWall/Adapters/LiveAlbumBackupService.swift MusicWallTests/Adapters/LiveAlbumBackupServiceTests.swift
git commit -m "feat: update backup service for full album export/import"
```

---

### Task 4: Export filename prefix

**Files:**
- Modify: `MusicWall/Adapters/FileExportService.swift`
- Test: `MusicWallTests/Adapters/FileExportServiceTests.swift`

- [ ] **Step 1: Update the failing test**

In `MusicWallTests/Adapters/FileExportServiceTests.swift`, change line 14:

```swift
#expect(url.lastPathComponent.hasPrefix("MusicWall_Backup_"))
```

- [ ] **Step 2: Run test to verify it fails**

Run:
```bash
xcodebuild test -project MusicWall.xcodeproj -scheme MusicWall \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:MusicWallTests/FileExportServiceTests 2>&1 | tail -15
```
Expected: FAIL — prefix still `MusicWall_AlbumIDs_`.

- [ ] **Step 3: Update filename in `FileExportService`**

```swift
.appendingPathComponent("MusicWall_Backup_\(Date().timeIntervalSince1970).json")
```

- [ ] **Step 4: Run test to verify it passes**

Run the same command.
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add MusicWall/Adapters/FileExportService.swift MusicWallTests/Adapters/FileExportServiceTests.swift
git commit -m "feat: rename backup export filename prefix"
```

---

### Task 5: `AlbumStore.importBackup`

**Files:**
- Modify: `MusicWall/Features/Home/AlbumStore.swift`
- Test: `MusicWallTests/Core/AlbumStoreImportTests.swift`

- [ ] **Step 1: Add failing tests for v2 record import**

Append to `MusicWallTests/Core/AlbumStoreImportTests.swift`:

```swift
    @Test @MainActor
    func importBackupRecordsAddsWithoutFetch() async throws {
        let preferences = InMemoryPreferencesStore()
        let repository = MockAlbumRepository()
        repository.fetchHandler = { _ in
            Issue.record("fetch should not be called for v2 record import")
            return []
        }

        let store = AlbumStore(preferences: preferences, repository: repository)
        let edited = AlbumFixtures.record(
            id: "edited-1",
            title: "Local Title",
            artistName: "Local Artist",
            releaseDate: AlbumFixtures.utcDate(year: 1999, month: 1, day: 1)
        )

        try await store.importBackup(.records([edited]))

        #expect(repository.fetchCalls.isEmpty)
        #expect(store.items.count == 1)
        #expect(store.items[0] == edited)
    }

    @Test @MainActor
    func importBackupRecordsSkipsExistingAlbums() async throws {
        let preferences = InMemoryPreferencesStore()
        let repository = MockAlbumRepository()
        let store = AlbumStore(preferences: preferences, repository: repository)
        let existing = AlbumFixtures.record(id: "dup", title: "Keep Me", artistName: "Local")
        store.addAlbum(existing)

        let fromBackup = AlbumFixtures.record(id: "dup", title: "Overwrite?", artistName: "Backup")
        let newAlbum = AlbumFixtures.record(id: "new", title: "New", artistName: "Artist")

        try await store.importBackup(.records([fromBackup, newAlbum]))

        #expect(repository.fetchCalls.isEmpty)
        #expect(store.items.count == 2)
        #expect(store.items.first { $0.id.rawValue == "dup" } == existing)
        #expect(store.items.first { $0.id.rawValue == "new" } == newAlbum)
    }

    @Test @MainActor
    func importBackupIdsDelegatesToFetchPath() async throws {
        let preferences = InMemoryPreferencesStore()
        let repository = MockAlbumRepository()
        repository.fetchHandler = { ids in
            ids.map { AlbumFixtures.record(id: $0.rawValue, title: "Fetched", artistName: "Artist") }
        }

        let store = AlbumStore(preferences: preferences, repository: repository)
        try await store.importBackup(.ids(["fetched-1"]))

        #expect(repository.fetchCalls == [[AlbumID(rawValue: "fetched-1")]])
        #expect(store.items.count == 1)
        #expect(store.items[0].title == "Fetched")
    }
```

- [ ] **Step 2: Run tests to verify they fail**

Run:
```bash
xcodebuild test -project MusicWall.xcodeproj -scheme MusicWall \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:MusicWallTests/AlbumStoreImportTests 2>&1 | tail -20
```
Expected: FAIL — `importBackup` not defined.

- [ ] **Step 3: Add `importBackup` to `AlbumStore`**

Add after `importAlbums(from ids:)` in `MusicWall/Features/Home/AlbumStore.swift`:

```swift
    @MainActor
    func importBackup(_ contents: BackupContents) async throws {
        switch contents {
        case .records(let records):
            collection.performWithoutPersist {
                for record in records where !collection.contains(id: record.id) {
                    _ = collection.add(record)
                }
            }
            applySort()
        case .ids(let ids):
            try await importAlbums(from: ids)
        }
    }
```

- [ ] **Step 4: Run tests to verify they pass**

Run the same command.
Expected: PASS (all 5 tests in `AlbumStoreImportTests`).

- [ ] **Step 5: Commit**

```bash
git add MusicWall/Features/Home/AlbumStore.swift MusicWallTests/Core/AlbumStoreImportTests.swift
git commit -m "feat: import v2 backup records without MusicKit fetch"
```

---

### Task 6: Remove dead ID export helpers

**Files:**
- Modify: `MusicWall/Core/AlbumCollection.swift`
- Modify: `MusicWall/Features/Home/AlbumStore.swift`
- Test: `MusicWallTests/Core/AlbumCollectionTests.swift`

- [ ] **Step 1: Update collection tests that used `exportIDs`**

In `MusicWallTests/Core/AlbumCollectionTests.swift`:

Rename `exportIDsMatchesItemOrder` → `itemsPreserveOrderAfterReplaceAll` and replace the assertion:

```swift
    @Test
    func itemsPreserveOrderAfterReplaceAll() {
        let spy = PersistSpy()
        let collection = spy.makeCollection()
        collection.replaceAll(AlbumFixtures.baseTrio, persist: false)

        #expect(collection.items.map(\.id.rawValue) == ["fixture-drake", "fixture-cole", "fixture-kendrick"])
    }
```

In `applySortMatchesAlbumSorter`, replace line 117:

```swift
        #expect(collection.items.map(\.id.rawValue) == ["fixture-drake", "fixture-cole", "fixture-kendrick"])
```

- [ ] **Step 2: Remove `exportIDs` from `AlbumCollection`**

Delete the `exportIDs()` method (lines 41–43) from `MusicWall/Core/AlbumCollection.swift`.

- [ ] **Step 3: Remove `exportAlbumIDs` from `AlbumStore`**

Delete the `exportAlbumIDs()` method (lines 118–120) from `MusicWall/Features/Home/AlbumStore.swift`.

- [ ] **Step 4: Run collection + store tests**

Run:
```bash
xcodebuild test -project MusicWall.xcodeproj -scheme MusicWall \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:MusicWallTests/AlbumCollectionTests \
  -only-testing:MusicWallTests/AlbumStoreImportTests 2>&1 | tail -20
```
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add MusicWall/Core/AlbumCollection.swift MusicWall/Features/Home/AlbumStore.swift MusicWallTests/Core/AlbumCollectionTests.swift
git commit -m "refactor: remove unused album ID export helpers"
```

---

### Task 7: `HomeViewModel` + mock + tests

**Files:**
- Modify: `MusicWall/Features/Home/HomeViewModel.swift`
- Modify: `MusicWallTests/TestSupport/MockAlbumBackupService.swift`
- Test: `MusicWallTests/Features/Home/HomeViewModelTests.swift`

- [ ] **Step 1: Update `MockAlbumBackupService`**

Replace entire file:

```swift
import Foundation
@testable import MusicWall

final class MockAlbumBackupService: AlbumBackupService, @unchecked Sendable {
    var exportHandler: ([AlbumRecord]) throws -> URL = { _ in
        URL(fileURLWithPath: "/tmp/export.json")
    }
    var importHandler: (URL) throws -> BackupContents = { _ in .ids([]) }

    private(set) var exportCalls: [[AlbumRecord]] = []
    private(set) var importCalls: [URL] = []

    func exportAlbums(_ albums: [AlbumRecord]) throws -> URL {
        exportCalls.append(albums)
        return try exportHandler(albums)
    }

    func importBackup(from url: URL) throws -> BackupContents {
        importCalls.append(url)
        return try importHandler(url)
    }
}
```

- [ ] **Step 2: Update `HomeViewModel`**

In `MusicWall/Features/Home/HomeViewModel.swift`, replace `exportAlbums()`:

```swift
    func exportAlbums() -> HomeExportResult {
        let albums = store.items
        do {
            let url = try backup.exportAlbums(albums)
            return .success(url)
        } catch let error as BackupError where error == .emptyExport {
            return .snackbar(SnackbarState(message: "No albums to export"))
        } catch {
            return .snackbar(
                SnackbarState(message: "Export failed: \(error.localizedDescription)")
            )
        }
    }
```

Replace `importAlbums(from:)`:

```swift
    func importAlbums(from url: URL) async {
        do {
            let contents = try backup.importBackup(from: url)
            try await store.importBackup(contents)
            snackbar = SnackbarState(message: "Successfully imported \(contents.count) album(s)!")
        } catch {
            snackbar = SnackbarState(message: "Import failed: \(error.localizedDescription)")
        }
    }
```

- [ ] **Step 3: Update `HomeViewModelTests`**

In `exportEmptyCollection_showsNoAlbumsMessage`, update handler and expectation:

```swift
        backup.exportHandler = { albums in
            if albums.isEmpty { throw BackupError.emptyExport }
            return URL(fileURLWithPath: "/tmp/export.json")
        }
        // ...
        #expect(backup.exportCalls == [[]])
```

In `importSuccess_showsCountMessage`:

```swift
        backup.importHandler = { _ in .ids(["a", "b"]) }
```

Add a new test after `importSuccess_showsCountMessage`:

```swift
    @Test @MainActor
    func importV2Records_showsCountWithoutFetch() async {
        let backup = MockAlbumBackupService()
        let records = [
            AlbumFixtures.record(id: "v2-a", title: "Local", artistName: "Artist"),
            AlbumFixtures.record(id: "v2-b", title: "Local 2", artistName: "Artist 2"),
        ]
        backup.importHandler = { _ in .records(records) }
        let repository = MockAlbumRepository()
        repository.fetchHandler = { _ in
            Issue.record("fetch should not be called")
            return []
        }
        let viewModel = HomeViewModel(
            preferences: InMemoryPreferencesStore(),
            repository: repository,
            backup: backup
        )
        let fileURL = URL(fileURLWithPath: "/tmp/import-v2.json")

        await viewModel.importAlbums(from: fileURL)

        #expect(viewModel.snackbar?.message == "Successfully imported 2 album(s)!")
        #expect(viewModel.store.items == records)
        #expect(repository.fetchCalls.isEmpty)
    }
```

In `importStoreFailure_showsImportFailed`:

```swift
        backup.importHandler = { _ in .ids(["missing"]) }
```

- [ ] **Step 4: Run HomeViewModel tests**

Run:
```bash
xcodebuild test -project MusicWall.xcodeproj -scheme MusicWall \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:MusicWallTests/HomeViewModelTests 2>&1 | tail -20
```
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add MusicWall/Features/Home/HomeViewModel.swift MusicWallTests/TestSupport/MockAlbumBackupService.swift MusicWallTests/Features/Home/HomeViewModelTests.swift
git commit -m "feat: wire HomeViewModel to full album backup export/import"
```

---

### Task 8: UI menu labels

**Files:**
- Modify: `MusicWall/Features/Home/HomePageView.swift`

- [ ] **Step 1: Update menu button labels**

In `HomePageView.swift` `BackupMenu`, change:

```swift
            Button("Export Albums", systemImage: "square.and.arrow.up") {
                onExport()
            }
            Button("Import Albums", systemImage: "square.and.arrow.down") {
                showingFileImporter = true
            }
```

- [ ] **Step 2: Commit**

```bash
git add MusicWall/Features/Home/HomePageView.swift
git commit -m "ui: rename backup menu labels to Export/Import Albums"
```

---

### Task 9: Full verification

- [ ] **Step 1: Run all unit tests**

```bash
xcodebuild test -project MusicWall.xcodeproj -scheme MusicWall \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:MusicWallTests 2>&1 | tail -30
```
Expected: All `MusicWallTests` pass.

- [ ] **Step 2: Run Core import guard**

```bash
Scripts/check_core_imports.sh
```
Expected: exit 0 (no MusicKit/SwiftUI imports in `Core/`).

- [ ] **Step 3: Manual smoke check (optional, on device/simulator)**

1. Add albums, edit one album's artist/title locally.
2. Export Albums → share/save JSON.
3. Delete app data or use a second install.
4. Import Albums → verify local edits restored without network fetch.

---

## Spec coverage checklist

| Spec requirement | Task |
|------------------|------|
| v2 envelope export with full `AlbumRecord` | Task 2, 3 |
| Legacy v1 ID import with MusicKit fetch | Task 2, 5 |
| `BackupContents` enum | Task 1 |
| Protocol rename | Task 3 |
| Export filename `MusicWall_Backup_` | Task 4 |
| `AlbumStore.importBackup` | Task 5 |
| Remove dead ID export helpers | Task 6 |
| `HomeViewModel` wiring | Task 7 |
| UI label updates | Task 8 |
| Skip existing albums on import | Task 5 tests |
| Preserve local edits | Task 5 `importBackupRecordsAddsWithoutFetch` |
| UserDefaults persistence unchanged | No code changes (existing `AlbumCollection.persistIfNeeded`) |
| `AlbumLibraryLoader` unchanged | No task (verified by full test run) |

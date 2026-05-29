# PR 7 — Backup codec + file services Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace `BackupService` with testable `BackupCodec`, file I/O adapters, and `LiveAlbumBackupService` exposed on `AppDependencies.albumBackupService`.

**Architecture:** Foundation-only Core types (`BackupCodec`, `BackupError`, protocols) plus Adapters for temp-file write and security-scoped read. `LiveAlbumBackupService` composes the three pieces behind `AlbumBackupService`. `HomePageView` calls `dependencies.albumBackupService`; delete legacy monolith.

**Tech Stack:** Swift 5, Swift Testing, Xcode 16+, scheme `MusicWall`, simulator `iPhone 17`, `bundle exec fastlane ci_tests`.

**Spec:** `docs/specs/2026-05-29-pr-07-backup-codec-design.md`

**Branch:** `cursor/test-refactor-pr-07-backup-codec`

---

## File map

| Action | Path | Notes |
|--------|------|-------|
| Create | `MusicWall/Core/BackupError.swift` | Replaces `BackupServiceError` strings |
| Create | `MusicWall/Core/AlbumBackupService.swift` | Protocol |
| Create | `MusicWall/Core/SecurityScopedReader.swift` | Protocol |
| Create | `MusicWall/Core/BackupCodec.swift` | Pure JSON encode/decode |
| Create | `MusicWall/Adapters/FileExportService.swift` | Temp `.json` write |
| Create | `MusicWall/Adapters/SecurityScopedResourceReader.swift` | Production reader |
| Create | `MusicWall/Adapters/LiveAlbumBackupService.swift` | Coordinator |
| Modify | `MusicWall/AppDependencies.swift` | Add `albumBackupService` |
| Modify | `MusicWall/HomePageView.swift` | Use injected service |
| Modify | `MusicWallTests/SmokeTests.swift` | Touch `albumBackupService` |
| Delete | `MusicWall/BackupService.swift` | After migration |
| Create | `MusicWallTests/Core/BackupCodecTests.swift` | Codec coverage |
| Create | `MusicWallTests/Adapters/FileExportServiceTests.swift` | Write path |
| Create | `MusicWallTests/Adapters/LiveAlbumBackupServiceTests.swift` | Coordinator |
| Create | `MusicWallTests/TestSupport/DirectFileReader.swift` | Test reader |
| Modify | `MusicWall.xcodeproj/project.pbxproj` | Register test files |
| Modify | `Agent.md` | Legacy mapping |

**Xcode note:** `MusicWall/` uses `PBXFileSystemSynchronizedRootGroup` — new app files auto-join the target. Test files under `MusicWallTests/` must be registered in `project.pbxproj` (mirror `AlbumCollectionTests.swift` / `UserDefaultsPreferencesStoreTests.swift`).

**Legacy error strings (must match exactly):**

| Case | `errorDescription` |
|------|-------------------|
| `emptyExport` | `No albums to export` |
| `emptyImport` | `Import file contains no album IDs` |
| `fileAccessDenied` | `Could not access file` |
| `fileReadFailed(message)` | `Failed to read file: \(message)` |
| `invalidFormat` | `Invalid file format` |

---

### Task 1: Core error and protocols

**Files:**
- Create: `MusicWall/Core/BackupError.swift`
- Create: `MusicWall/Core/AlbumBackupService.swift`
- Create: `MusicWall/Core/SecurityScopedReader.swift`

- [ ] **Step 1: Create `BackupError.swift`**

```swift
import Foundation

enum BackupError: Error, LocalizedError, Equatable {
    case emptyExport
    case emptyImport
    case fileAccessDenied
    case fileReadFailed(String)
    case invalidFormat

    var errorDescription: String? {
        switch self {
        case .emptyExport:
            return "No albums to export"
        case .emptyImport:
            return "Import file contains no album IDs"
        case .fileAccessDenied:
            return "Could not access file"
        case .fileReadFailed(let message):
            return "Failed to read file: \(message)"
        case .invalidFormat:
            return "Invalid file format"
        }
    }
}
```

- [ ] **Step 2: Create `AlbumBackupService.swift`**

```swift
import Foundation

protocol AlbumBackupService: Sendable {
    func exportAlbumIDs(_ ids: [String]) throws -> URL
    func importAlbumIDs(from url: URL) throws -> [String]
}
```

- [ ] **Step 3: Create `SecurityScopedReader.swift`**

```swift
import Foundation

protocol SecurityScopedReader: Sendable {
    func readData(from url: URL) throws -> Data
}
```

- [ ] **Step 4: Build app target**

Run:

```bash
xcodebuild build -project MusicWall.xcodeproj -scheme MusicWall \
  -destination 'platform=iOS Simulator,name=iPhone 17' -quiet
```

Expected: `BUILD SUCCEEDED`

- [ ] **Step 5: Commit**

```bash
git add MusicWall/Core/BackupError.swift \
  MusicWall/Core/AlbumBackupService.swift \
  MusicWall/Core/SecurityScopedReader.swift
git commit -m "feat(core): Add BackupError and backup file protocols"
```

---

### Task 2: BackupCodec (TDD)

**Files:**
- Create: `MusicWallTests/Core/BackupCodecTests.swift`
- Create: `MusicWall/Core/BackupCodec.swift`
- Modify: `MusicWall.xcodeproj/project.pbxproj`

- [ ] **Step 1: Register `BackupCodecTests.swift` in Xcode project**

Add `MusicWallTests/Core/BackupCodecTests.swift` to `MusicWallTests` target (Sources build phase + `Core` subgroup), mirroring `AlbumCollectionTests.swift`.

- [ ] **Step 2: Write failing `BackupCodecTests.swift`**

```swift
import Foundation
import Testing
@testable import MusicWall

struct BackupCodecTests {
    private let codec = BackupCodec()

    @Test
    func roundTripEncodesAndDecodesIDs() throws {
        let ids = ["fixture-a", "fixture-b"]
        let data = try codec.encode(ids)
        let decoded = try codec.decode(data)
        #expect(decoded == ids)
    }

    @Test
    func decodeEmptyArrayThrowsEmptyImport() {
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
    func decodeNonArrayJSONThrowsInvalidFormat() {
        #expect(throws: BackupError.invalidFormat) {
            _ = try codec.decode(Data("\"not-an-array\"".utf8))
        }
    }

    @Test
    func decodeWrongElementTypeThrowsInvalidFormat() {
        #expect(throws: BackupError.invalidFormat) {
            _ = try codec.decode(Data("[1, 2]".utf8))
        }
    }
}
```

- [ ] **Step 3: Run tests to verify they fail**

Run:

```bash
xcodebuild test -project MusicWall.xcodeproj -scheme MusicWall \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:MusicWallTests/BackupCodecTests -quiet
```

Expected: FAIL — `BackupCodec` not found

- [ ] **Step 4: Implement `BackupCodec.swift`**

```swift
import Foundation

struct BackupCodec {
    func encode(_ ids: [String]) throws -> Data {
        do {
            return try JSONEncoder().encode(ids)
        } catch {
            throw BackupError.invalidFormat
        }
    }

    func decode(_ data: Data) throws -> [String] {
        let ids: [String]
        do {
            ids = try JSONDecoder().decode([String].self, from: data)
        } catch {
            throw BackupError.invalidFormat
        }
        guard !ids.isEmpty else {
            throw BackupError.emptyImport
        }
        return ids
    }
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run:

```bash
xcodebuild test -project MusicWall.xcodeproj -scheme MusicWall \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:MusicWallTests/BackupCodecTests -quiet
```

Expected: all `BackupCodecTests` PASS

- [ ] **Step 6: Commit**

```bash
git add MusicWall/Core/BackupCodec.swift \
  MusicWallTests/Core/BackupCodecTests.swift \
  MusicWall.xcodeproj/project.pbxproj
git commit -m "feat(core): Add BackupCodec with unit tests"
```

---

### Task 3: FileExportService (TDD)

**Files:**
- Create: `MusicWallTests/Adapters/FileExportServiceTests.swift`
- Create: `MusicWall/Adapters/FileExportService.swift`
- Modify: `MusicWall.xcodeproj/project.pbxproj`

- [ ] **Step 1: Register `FileExportServiceTests.swift` in Xcode project**

Add under `MusicWallTests/Adapters/` (mirror `UserDefaultsPreferencesStoreTests.swift`).

- [ ] **Step 2: Write failing `FileExportServiceTests.swift`**

```swift
import Foundation
import Testing
@testable import MusicWall

struct FileExportServiceTests {
    @Test
    func writeCreatesFileWithPayload() throws {
        let service = FileExportService()
        let payload = Data("[\"a\"]".utf8)
        let url = try service.write(payload)
        defer { try? FileManager.default.removeItem(at: url) }

        #expect(url.pathExtension == "json")
        #expect(url.lastPathComponent.hasPrefix("MusicWall_AlbumIDs_"))
        #expect(try Data(contentsOf: url) == payload)
    }
}
```

- [ ] **Step 3: Run test to verify it fails**

Run:

```bash
xcodebuild test -project MusicWall.xcodeproj -scheme MusicWall \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:MusicWallTests/FileExportServiceTests -quiet
```

Expected: FAIL — `FileExportService` not found

- [ ] **Step 4: Implement `FileExportService.swift`**

```swift
import Foundation

struct FileExportService {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func write(_ data: Data) throws -> URL {
        let tempURL = fileManager.temporaryDirectory
            .appendingPathComponent("MusicWall_AlbumIDs_\(Date().timeIntervalSince1970).json")
        try data.write(to: tempURL)
        return tempURL
    }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run:

```bash
xcodebuild test -project MusicWall.xcodeproj -scheme MusicWall \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:MusicWallTests/FileExportServiceTests -quiet
```

Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add MusicWall/Adapters/FileExportService.swift \
  MusicWallTests/Adapters/FileExportServiceTests.swift \
  MusicWall.xcodeproj/project.pbxproj
git commit -m "feat(adapters): Add FileExportService with unit tests"
```

---

### Task 4: Security-scoped reader + test support

**Files:**
- Create: `MusicWall/Adapters/SecurityScopedResourceReader.swift`
- Create: `MusicWallTests/TestSupport/DirectFileReader.swift`

- [ ] **Step 1: Create `SecurityScopedResourceReader.swift`**

```swift
import Foundation

struct SecurityScopedResourceReader: SecurityScopedReader {
    func readData(from url: URL) throws -> Data {
        guard url.startAccessingSecurityScopedResource() else {
            throw BackupError.fileAccessDenied
        }
        defer { url.stopAccessingSecurityScopedResource() }

        do {
            return try Data(contentsOf: url)
        } catch {
            throw BackupError.fileReadFailed(error.localizedDescription)
        }
    }
}
```

- [ ] **Step 2: Create `DirectFileReader.swift`**

```swift
import Foundation
@testable import MusicWall

struct DirectFileReader: SecurityScopedReader {
    func readData(from url: URL) throws -> Data {
        do {
            return try Data(contentsOf: url)
        } catch {
            throw BackupError.fileReadFailed(error.localizedDescription)
        }
    }
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
git add MusicWall/Adapters/SecurityScopedResourceReader.swift \
  MusicWallTests/TestSupport/DirectFileReader.swift
git commit -m "feat(adapters): Add security-scoped and direct file readers"
```

---

### Task 5: LiveAlbumBackupService (TDD)

**Files:**
- Create: `MusicWallTests/Adapters/LiveAlbumBackupServiceTests.swift`
- Create: `MusicWall/Adapters/LiveAlbumBackupService.swift`
- Modify: `MusicWall.xcodeproj/project.pbxproj`

- [ ] **Step 1: Register `LiveAlbumBackupServiceTests.swift` in Xcode project**

Add under `MusicWallTests/Adapters/`.

- [ ] **Step 2: Write failing `LiveAlbumBackupServiceTests.swift`**

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

    @Test
    func exportEmptyIDsThrowsEmptyExport() {
        let service = LiveAlbumBackupService(reader: DirectFileReader())
        #expect(throws: BackupError.emptyExport) {
            _ = try service.exportAlbumIDs([])
        }
    }

    @Test
    func exportImportRoundTrip() throws {
        let service = LiveAlbumBackupService(reader: DirectFileReader())
        let ids = ["id-a", "id-b"]
        let url = try service.exportAlbumIDs(ids)
        defer { try? FileManager.default.removeItem(at: url) }

        let imported = try service.importAlbumIDs(from: url)
        #expect(imported == ids)
    }

    @Test
    func importPropagatesFileAccessDenied() throws {
        let service = LiveAlbumBackupService(reader: DenyingReader())
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("unused-\(UUID().uuidString).json")

        #expect(throws: BackupError.fileAccessDenied) {
            _ = try service.importAlbumIDs(from: url)
        }
    }
}
```

- [ ] **Step 3: Run tests to verify they fail**

Run:

```bash
xcodebuild test -project MusicWall.xcodeproj -scheme MusicWall \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:MusicWallTests/LiveAlbumBackupServiceTests -quiet
```

Expected: FAIL — `LiveAlbumBackupService` not found

- [ ] **Step 4: Implement `LiveAlbumBackupService.swift`**

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

    func exportAlbumIDs(_ ids: [String]) throws -> URL {
        guard !ids.isEmpty else {
            throw BackupError.emptyExport
        }
        let data = try codec.encode(ids)
        return try exportService.write(data)
    }

    func importAlbumIDs(from url: URL) throws -> [String] {
        let data = try reader.readData(from: url)
        return try codec.decode(data)
    }
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run:

```bash
xcodebuild test -project MusicWall.xcodeproj -scheme MusicWall \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:MusicWallTests/LiveAlbumBackupServiceTests -quiet
```

Expected: all PASS

- [ ] **Step 6: Commit**

```bash
git add MusicWall/Adapters/LiveAlbumBackupService.swift \
  MusicWallTests/Adapters/LiveAlbumBackupServiceTests.swift \
  MusicWall.xcodeproj/project.pbxproj
git commit -m "feat(adapters): Add LiveAlbumBackupService with unit tests"
```

---

### Task 6: Wire AppDependencies and HomePageView

**Files:**
- Modify: `MusicWall/AppDependencies.swift`
- Modify: `MusicWall/HomePageView.swift`

- [ ] **Step 1: Add `albumBackupService` to `AppDependencies.swift`**

```swift
struct AppDependencies {
    let preferencesStore: PreferencesStore
    let albumRepository: any AlbumRepository
    let playbackController: any PlaybackController
    let albumBackupService: any AlbumBackupService

    static let live: AppDependencies = {
        let repository = MusicKitAlbumRepository()
        return AppDependencies(
            preferencesStore: UserDefaultsPreferencesStore(userDefaults: .standard),
            albumRepository: repository,
            playbackController: SystemMusicPlayerAdapter(repository: repository),
            albumBackupService: LiveAlbumBackupService()
        )
    }()

    static func preview() -> AppDependencies {
        let suiteName = "com.musicwall.preview.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        return AppDependencies(
            preferencesStore: UserDefaultsPreferencesStore(userDefaults: defaults),
            albumRepository: PreviewAlbumRepository(),
            playbackController: PreviewPlaybackController(),
            albumBackupService: LiveAlbumBackupService()
        )
    }
}
```

- [ ] **Step 2: Update `HomePageView.swift` call sites**

In `importAlbums(from:)` replace:

```swift
let ids = try BackupService.importAlbumIDs(from: url)
```

with:

```swift
let ids = try dependencies.albumBackupService.importAlbumIDs(from: url)
```

In `exportAlbums()` replace:

```swift
let url = try BackupService.exportAlbumIDs(ids)
```

with:

```swift
let url = try dependencies.albumBackupService.exportAlbumIDs(ids)
```

- [ ] **Step 3: Build**

Run:

```bash
xcodebuild build -project MusicWall.xcodeproj -scheme MusicWall \
  -destination 'platform=iOS Simulator,name=iPhone 17' -quiet
```

Expected: `BUILD SUCCEEDED`

- [ ] **Step 4: Commit**

```bash
git add MusicWall/AppDependencies.swift MusicWall/HomePageView.swift
git commit -m "feat(app): Wire AlbumBackupService through AppDependencies"
```

---

### Task 7: Remove legacy BackupService and update docs

**Files:**
- Delete: `MusicWall/BackupService.swift`
- Modify: `MusicWallTests/SmokeTests.swift`
- Modify: `Agent.md`

- [ ] **Step 1: Delete `MusicWall/BackupService.swift`**

- [ ] **Step 2: Update `SmokeTests.swift`**

```swift
import Testing
@testable import MusicWall

struct SmokeTests {
    @Test
    func appDependenciesLiveConstructs() {
        let dependencies = AppDependencies.live
        _ = dependencies.preferencesStore
        _ = dependencies.albumRepository
        _ = dependencies.playbackController
        _ = dependencies.albumBackupService
        #expect(true)
    }
}
```

- [ ] **Step 3: Update `Agent.md`**

Replace persistence line:

```markdown
- **MVVM-style separation:** views in `*View.swift`, Apple Music access via `AlbumRepository` / `PlaybackController` (`AppDependencies.live`), persistence via `PreferencesStore` / `AlbumBackupService`.
```

Replace backup test note:

```markdown
- Version export/import via `AlbumBackupService` (`LiveAlbumBackupService` + `BackupCodec`) — test round-trip when changing `Album` model.
```

- [ ] **Step 4: Verify no legacy references**

Run:

```bash
rg 'BackupService' --glob '*.swift' --glob '*.md'
```

Expected: no matches (or only historical docs outside scope)

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "refactor: Remove BackupService; update smoke tests and Agent.md"
```

---

### Task 8: Full CI verification

- [ ] **Step 1: Run full test suite**

Run:

```bash
bundle exec fastlane ci_tests
```

Expected: all tests green

- [ ] **Step 2: Human verification checklist (PR description)**

- Export with albums → share sheet opens with `.json` file
- Import that file → albums appear
- Export with empty library → snackbar “No albums to export”
- Import corrupt JSON → snackbar “Invalid file format”

- [ ] **Step 3: Final commit if any fixups needed**

Only if Task 8 step 1 required changes.

---

## Spec coverage checklist

| Spec requirement | Task |
|------------------|------|
| `BackupCodec` encode/decode | Task 2 |
| `BackupError` all cases + strings | Task 1 |
| `FileExportService` temp write | Task 3 |
| `SecurityScopedResourceReader` | Task 4 |
| `DirectFileReader` test support | Task 4 |
| `AlbumBackupService` protocol | Task 1 |
| `LiveAlbumBackupService` coordinator | Task 5 |
| `AppDependencies.albumBackupService` | Task 6 |
| `HomePageView` migration | Task 6 |
| Delete `BackupService` | Task 7 |
| Codec tests (round-trip, empty, invalid) | Task 2 |
| File export tests | Task 3 |
| Coordinator tests | Task 5 |
| Smoke test | Task 7 |
| `Agent.md` update | Task 7 |
| CI green | Task 8 |

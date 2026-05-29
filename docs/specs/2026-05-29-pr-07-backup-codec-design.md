# PR 7 — Backup codec + file services

**Status:** Approved (2026-05-29)  
**Program:** MusicWall testability refactor  
**Requires:** PR 3 merged  
**Blocks:** none critical (PR 9 `HomeViewModel` uses export/import)  
**Approach:** Internal decomposition (codec + file I/O) + single `AlbumBackupService` on `AppDependencies` (Option B1)

## Summary

Replace static `BackupService` with testable Core/Adapter pieces composed by `LiveAlbumBackupService`, exposed as `AppDependencies.albumBackupService`. Delete `BackupService.swift`. `HomePageView` calls the injected service; `AlbumStore` still owns MusicKit import after IDs are read. On-disk backup format unchanged: JSON array of `String` album IDs in a timestamped temp `.json` file.

## Goals

- 100% unit-testable JSON encode/decode (`BackupCodec`) and file I/O boundaries (`FileExportService`, `SecurityScopedReader`).
- Map every legacy `BackupServiceError` case to thrown `BackupError` (including `fileReadFailed` and `invalidFormat`, which are defined today but never thrown).
- One injectable dependency for the backup feature; codec and file helpers are not on `AppDependencies`.
- Delete `BackupService` with no deprecated shim.
- Target ≥95% line coverage on `BackupCodec` in CI (informational until PR 14).

## Non-goals

- `HomeViewModel` (PR 9) — orchestration stays in `HomePageView` private methods until then.
- Changing backup JSON shape, filename pattern, or temp directory location.
- `AlbumStore.importAlbums(from:)` / MusicKit fetch behavior.
- Snackbar or error UI redesign.
- SPM `MusicWallPersistence` module (optional PR 15).
- Moving export/import into `AlbumCollection`.

## Approaches considered

| Option | Description | Why not chosen |
|--------|-------------|----------------|
| **A** | Three separate dependencies on `AppDependencies` | Orchestration leaks into the view; three fields used only together |
| **B1 (chosen)** | `AlbumBackupService` protocol + `LiveAlbumBackupService` composing codec + file types | One call-site seam; internal pieces still fully unit-tested |
| **B2** | Concrete `LiveAlbumBackupService` only, no protocol | Harder to mock at view boundary |
| **C** | Construct adapters inline in `HomePageView` | Breaks composition-root pattern from PR 3/5 |

## Architecture

### Layer placement

```
MusicWall/
  Core/
    BackupCodec.swift
    BackupError.swift
    AlbumBackupService.swift
    SecurityScopedReader.swift
  Adapters/
    FileExportService.swift
    SecurityScopedResourceReader.swift
    LiveAlbumBackupService.swift
  AppDependencies.swift
  HomePageView.swift

MusicWallTests/
  Core/
    BackupCodecTests.swift
  Adapters/
    FileExportServiceTests.swift
    LiveAlbumBackupServiceTests.swift
  TestSupport/
    DirectFileReader.swift
```

Delete `MusicWall/BackupService.swift`.

### Data flow

```
Export:
  AlbumStore.exportAlbumIDs()
    → albumBackupService.exportAlbumIDs(ids)
      → guard non-empty → BackupCodec.encode → FileExportService.write → URL
    → share sheet

Import:
  fileImporter URL
    → albumBackupService.importAlbumIDs(from: url)
      → SecurityScopedReader.readData → BackupCodec.decode → [String]
    → AlbumStore.importAlbums(from: ids)
    → snackbar
```

### Dependency rules

| Module / folder | May import |
|-----------------|------------|
| `MusicWall/Core/` (`BackupCodec`, `BackupError`, protocols) | Foundation |
| `MusicWall/Adapters/` (file services, live backup service) | Foundation |
| Views | SwiftUI; backup only via `AppDependencies.albumBackupService` |
| `MusicWallTests` | `@testable import MusicWall` |

## `BackupError`

Replaces `BackupServiceError`. Conforms to `Error, LocalizedError`. **Keep `errorDescription` strings identical** to legacy copy (snackbar text unchanged).

| Case | Thrown by |
|------|-----------|
| `emptyExport` | `LiveAlbumBackupService.exportAlbumIDs` |
| `emptyImport` | `BackupCodec.decode` |
| `fileAccessDenied` | `SecurityScopedResourceReader` |
| `fileReadFailed(String)` | `SecurityScopedResourceReader` |
| `invalidFormat` | `BackupCodec` (`encode` or `decode` JSON failure) |

## `BackupCodec`

Foundation-only struct with no dependencies.

```swift
struct BackupCodec {
    func encode(_ ids: [String]) throws -> Data
    func decode(_ data: Data) throws -> [String]
}
```

| Method | Behavior |
|--------|----------|
| `encode` | `JSONEncoder().encode(ids)`; failure → `BackupError.invalidFormat` |
| `decode` | `JSONDecoder().decode([String].self, from: data)`; failure → `invalidFormat`; success with `ids.isEmpty` → `emptyImport` |

Does **not** enforce `emptyExport` (export policy belongs in `LiveAlbumBackupService`).

## `FileExportService`

```swift
struct FileExportService {
    init(fileManager: FileManager = .default)
    func write(_ data: Data) throws -> URL
}
```

Writes to:

`fileManager.temporaryDirectory.appendingPathComponent("MusicWall_AlbumIDs_\(Date().timeIntervalSince1970).json")`

Propagates `Data.write(to:)` failures. Does not validate empty `Data`.

## `SecurityScopedReader`

```swift
protocol SecurityScopedReader: Sendable {
    func readData(from url: URL) throws -> Data
}
```

### `SecurityScopedResourceReader` (production)

1. `guard url.startAccessingSecurityScopedResource()` else → `fileAccessDenied`
2. `defer { url.stopAccessingSecurityScopedResource() }`
3. `try Data(contentsOf: url)` — failure → `fileReadFailed(error.localizedDescription)`

### `DirectFileReader` (tests only, `MusicWallTests/TestSupport/`)

`try Data(contentsOf: url)` with no security-scoped access (for round-trip tests with files created in temp).

## `AlbumBackupService`

```swift
protocol AlbumBackupService: Sendable {
    func exportAlbumIDs(_ ids: [String]) throws -> URL
    func importAlbumIDs(from url: URL) throws -> [String]
}
```

Signatures match legacy `BackupService` so `HomePageView` changes are minimal.

## `LiveAlbumBackupService`

```swift
struct LiveAlbumBackupService: AlbumBackupService {
    init(
        codec: BackupCodec = BackupCodec(),
        exportService: FileExportService = FileExportService(),
        reader: any SecurityScopedReader = SecurityScopedResourceReader()
    )
}
```

| Method | Steps |
|--------|--------|
| `exportAlbumIDs` | `guard !ids.isEmpty` → `emptyExport`; `try exportService.write(codec.encode(ids))` |
| `importAlbumIDs` | `try codec.decode(reader.readData(from: url))` |

## Composition root and injection

### `AppDependencies`

```swift
struct AppDependencies {
    // existing fields…
    let albumBackupService: any AlbumBackupService

    static let live = AppDependencies(
        // …
        albumBackupService: LiveAlbumBackupService()
    )
}
```

`preview()` uses `LiveAlbumBackupService()` (same as live). Previews do not exercise file import/export today.

### `HomePageView`

Replace:

- `BackupService.importAlbumIDs(from: url)` → `dependencies.albumBackupService.importAlbumIDs(from: url)`
- `BackupService.exportAlbumIDs(ids)` → `dependencies.albumBackupService.exportAlbumIDs(ids)`

Keep existing snackbar handling via `error.localizedDescription`.

No new parameters on `HomePageView` — it already holds `dependencies: AppDependencies`.

## Testing

### Framework

Swift Testing (consistent with PR 1–6).

### `BackupCodecTests`

| Case | Expectation |
|------|-------------|
| Round-trip | Encode `["a","b"]`, decode, equal |
| Empty array JSON | `[]` → `emptyImport` |
| Invalid JSON | `{}`, `"not-array"`, truncated bytes → `invalidFormat` |
| Wrong element type | `[1, 2]` (if encodable as array of numbers in fixture) → `invalidFormat` |

### `FileExportServiceTests`

| Case | Expectation |
|------|-------------|
| Write | Returns URL under injected/temp directory; file contents match input `Data` |
| Read back | `Data(contentsOf: url)` equals written payload |

Use injected `FileManager` or system temp with teardown delete.

### `LiveAlbumBackupServiceTests`

| Case | Expectation |
|------|-------------|
| `emptyExport` | `exportAlbumIDs([])` throws `emptyExport` |
| Round-trip | Export IDs to temp via service; import with `DirectFileReader` → same IDs |
| Access denied | Inject reader stub throwing `fileAccessDenied` → propagates |

### Smoke

`AppDependencies.live` constructs successfully.

### Human verification (PR description)

On simulator: export album list → share sheet file; import same file → albums restored; empty library export shows “No albums to export”; corrupt file shows invalid-format message.

### CI

No workflow changes. PR must pass existing `ci-tests` (`fastlane ci_tests`).

## Acceptance criteria

- [ ] `BackupCodec`, `BackupError`, `AlbumBackupService`, `SecurityScopedReader` in `MusicWall/Core/`; Foundation only.
- [ ] `FileExportService`, `SecurityScopedResourceReader`, `LiveAlbumBackupService` in `MusicWall/Adapters/`; Foundation only.
- [ ] `BackupCodecTests` cover round-trip, empty import, invalid JSON.
- [ ] `FileExportServiceTests` and `LiveAlbumBackupServiceTests` cover export path and coordinator errors.
- [ ] `BackupService.swift` deleted; no remaining `BackupService` / `BackupServiceError` references.
- [ ] `AppDependencies.live` and `preview()` provide `LiveAlbumBackupService()`.
- [ ] `HomePageView` uses `dependencies.albumBackupService` only.
- [ ] Backup file format and `LocalizedError` strings unchanged from legacy behavior.
- [ ] App compiles; `ci-tests` green.

## PR delivery

- Branch from `main`: `cursor/test-refactor-pr-07-backup-codec` (or team convention).
- Add new Swift files to `MusicWall` / `MusicWallTests` targets in `MusicWall.xcodeproj`.
- Remove `BackupService.swift` from target.
- Update `Agent.md` legacy mapping (`BackupService` → `AlbumBackupService` + internals).
- PR description: link “PR 7 of 14”; note human export/import on simulator.

## Follow-on PRs

| PR | Relationship |
|----|----------------|
| PR 9 | `HomeViewModel` owns export/import; inject `AlbumBackupService` into VM |
| PR 14 | Coverage gates; confirm codec ≥95% in CI report |

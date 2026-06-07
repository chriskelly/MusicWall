# Backup — Full Album Data Export/Import

**Status:** Approved (2026-06-06)  
**Program:** MusicWall backup upgrade  
**Requires:** Existing `AlbumBackupService` / `BackupCodec` infrastructure (PR 7)  
**Approach:** Versioned envelope + `BackupContents` result type (Approach A)

## Summary

Upgrade the file backup format from a bare JSON array of album IDs to a versioned envelope containing full `AlbumRecord` data. This preserves locally edited title, artist, and release date across backup restoration. Legacy ID-only backup files continue to import via the existing Apple Music fetch path.

## Goals

- Export full `AlbumRecord` data (`id`, `title`, `artistName`, `releaseDate`, `isExplicit`) in backup files.
- Restore v2 backups directly from file data — no Apple Music re-fetch — so local edits survive.
- Maintain backward compatibility: legacy bare `[String]` ID arrays still import and fetch from MusicKit.
- Keep existing UserDefaults persistence (`albumRecordsItems`, `backupAlbumIDs`) unchanged.
- Preserve merge semantics: albums already in the collection are skipped on import (local copy wins).

## Non-goals

- Backing up app preferences (sort order, sort direction, layout).
- Changing `AlbumLibraryLoader` launch hydration behavior.
- Changing `AlbumRecord` model fields or edit UI.
- Artwork or playback state in backups.
- Overwriting existing albums on import.

## Decisions

| Question | Decision |
|----------|----------|
| Restore behavior | Backup data is source of truth for v2; Apple Music fetch only for legacy v1 ID imports |
| Format | Versioned envelope `{"version": 2, "albums": [...]}` |
| Scope | Album records only (no preferences) |
| Merge on import | Keep existing — skip albums already in collection |

## Approaches considered

| Option | Description | Why not chosen |
|--------|-------------|----------------|
| **A (chosen)** | Versioned envelope + `BackupContents` enum; protocol renamed to `exportAlbums` / `importBackup` | Explicit format versioning; single import path; clean layer separation |
| **B** | Add parallel `exportAlbums` / `importBackup` alongside existing ID methods | Leaves dead ID export code; two parallel paths invite drift |
| **C** | Service normalizes everything to `[AlbumRecord]` including async MusicKit fetch | Breaks layer separation — file adapter would depend on async repository |

## On-disk format

### v2 (new exports)

```json
{
  "version": 2,
  "albums": [
    {
      "id": "1440857781",
      "title": "Take Care",
      "artistName": "Drake",
      "releaseDate": "2011-11-15T00:00:00Z",
      "isExplicit": true
    }
  ]
}
```

- `version`: `Int`, currently `2`.
- `albums`: array of existing `AlbumRecord` Codable objects (no model changes).
- Export filename: `MusicWall_Backup_<timestamp>.json` (was `MusicWall_AlbumIDs_<timestamp>.json`).

### v1 (legacy, still supported on import)

```json
["1440857781", "1441164738"]
```

Bare JSON array of album ID strings. Detected when v2 envelope decode fails.

## Architecture

### New type: `BackupContents`

```swift
enum BackupContents: Equatable, Sendable {
    case records([AlbumRecord])   // v2
    case ids([String])            // legacy v1
}
```

### Layer changes

```
MusicWall/
  Core/
    BackupCodec.swift          — encode/decode v2 envelope; fallback to v1
    BackupContents.swift       — new result type
    AlbumBackupService.swift   — protocol: exportAlbums / importBackup
  Adapters/
    LiveAlbumBackupService.swift — rewire to new codec/protocol
    FileExportService.swift    — update filename prefix only
  Features/Home/
    AlbumStore.swift           — importBackup(_ contents: BackupContents)
    HomeViewModel.swift        — pass full records on export; route import
    HomePageView.swift         — menu labels: "Export Albums" / "Import Albums"
```

### Protocol change

```swift
protocol AlbumBackupService: Sendable {
    func exportAlbums(_ albums: [AlbumRecord]) throws -> URL
    func importBackup(from url: URL) throws -> BackupContents
}
```

Removes `exportAlbumIDs` / `importAlbumIDs`. `AlbumStore.exportAlbumIDs()` and `AlbumCollection.exportIDs()` are removed as dead code.

### Data flow

```
Export:
  store.items (full [AlbumRecord])
    → backup.exportAlbums(albums)
      → guard non-empty → BackupCodec.encode → FileExportService.write → URL
    → share sheet

Import:
  fileImporter URL
    → backup.importBackup(from: url)
      → SecurityScopedResourceReader.readData
      → BackupCodec.decode → BackupContents
    → store.importBackup(contents)
      → .records: add new albums directly (no fetch)
      → .ids: importAlbums(from:) → MusicKit fetch for missing IDs
    → snackbar
```

### `BackupCodec` behavior

**Encode** (`encode(_ albums: [AlbumRecord]) -> Data`):
- Writes `{ "version": 2, "albums": albums }` using `JSONEncoder`.

**Decode** (`decode(_ data: Data) -> BackupContents`):
1. Try decoding v2 envelope → `.records(albums)`.
2. On failure, try decoding bare `[String]` → `.ids(ids)`.
3. On both failures → `BackupError.invalidFormat`.
4. Empty `albums` (v2) or empty `[]` (v1) → `BackupError.emptyImport`.

`BackupError` cases unchanged.

### `AlbumStore.importBackup`

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

- **v2 records:** added directly; local edits preserved; works offline.
- **Already present:** skipped (`collection.add` returns false for duplicates).
- **v1 IDs:** existing async fetch path unchanged.
- Persistence: `applySort()` triggers `persistIfNeeded()` which writes both `albumRecordsItems` and `backupAlbumIDs`.

### UI changes

`HomePageView` `BackupMenu` labels:
- "Export Album IDs" → "Export Albums"
- "Import Album IDs" → "Import Albums"

Snackbar copy updated to say "album(s)" instead of referencing IDs.

## Testing

| Test file | Coverage |
|-----------|----------|
| `BackupCodecTests` | v2 round-trip; legacy `[String]` → `.ids`; empty v2/v1 → `emptyImport`; malformed → `invalidFormat` |
| `LiveAlbumBackupServiceTests` | `exportAlbums` file round-trip; `importBackup` reads v2 and legacy; empty export → `emptyExport` |
| `AlbumStoreImportTests` | `.records` adds without repository fetch; edits preserved; skips existing; `.ids` still fetches |
| `AlbumLibraryLoaderTests` | Unchanged — launch hydration unaffected |

Mock/stub `AlbumRepository` in store import tests to verify fetch is **not** called for `.records` imports.

## Backward compatibility

- Old ID-only `.json` files import successfully (decoded as `.ids`, fetched from Apple Music).
- UserDefaults keys (`albumRecordsItems`, `backupAlbumIDs`) and `AlbumLibraryLoader` launch path unchanged.
- No migration needed for existing installs — only file export/import format changes.

## Files to touch

| File | Change |
|------|--------|
| `Core/BackupContents.swift` | New |
| `Core/BackupCodec.swift` | v2 encode; dual-format decode |
| `Core/AlbumBackupService.swift` | Protocol rename |
| `Adapters/LiveAlbumBackupService.swift` | Rewire |
| `Adapters/FileExportService.swift` | Filename prefix |
| `Features/Home/AlbumStore.swift` | `importBackup`; remove `exportAlbumIDs` |
| `Core/AlbumCollection.swift` | Remove `exportIDs` |
| `Features/Home/HomeViewModel.swift` | Export records; route `BackupContents` |
| `Features/Home/HomePageView.swift` | Menu labels |
| `MusicWallTests/Core/BackupCodecTests.swift` | v2 + legacy tests |
| `MusicWallTests/Adapters/LiveAlbumBackupServiceTests.swift` | Updated API |
| `MusicWallTests/Core/AlbumStoreImportTests.swift` | `.records` import path |

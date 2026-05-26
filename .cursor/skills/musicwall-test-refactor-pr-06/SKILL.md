---
name: musicwall-test-refactor-pr-06
description: >-
  MusicWall test refactor PR 6 only — persistence load, backup ID recovery, legacy
  StoredAlbum JSON migration wired to AlbumCollection and repository. Invoke explicitly.
disable-model-invocation: true
paths:
  - MusicWall/**
  - MusicWallTests/**
---

# PR 6 — Load, migration, repository wiring

**Requires:** PR 5 merged  
**Blocks:** PR 8, PR 9

## Goal

Safe on-disk migration and async hydration via `AlbumRepository` with comprehensive tests.

## In scope

- **`AlbumCollection.load()`** (or `AlbumLibraryService`):
  1. Decode `[AlbumRecord]` from preferences (new key or same key with version byte)
  2. If empty, read legacy backup ID list → `repository.fetch` → map → persist
  3. Load sort preferences into collection or separate `SortPreferences` type
- **Migration** from legacy `StoredAlbum` JSON (`MusicItemID` encoding) — one-time, tested with fixture files committed under `MusicWallTests/Fixtures/`
- Remove or gut **`StoredAlbums`** class; views use **`AlbumCollection`** via environment
- **Tests:** migration golden files; empty backup; fetch throws → items stay empty; fetch partial results

## Out of scope

- Home/Auth ViewModels (PR 8–9).
- Coverage gates (PR 14).

## Acceptance criteria

- [ ] Existing simulator UserDefaults data migrates without data loss (document manual QA).
- [ ] `ContentView` / `HomePageView` use `AlbumCollection` not `StoredAlbums()`.
- [ ] Backup ID keys still updated on item changes (compat with pre-refactor backups).

## Human QA

- Install build over existing TestFlight/local data if possible; verify album list survives.

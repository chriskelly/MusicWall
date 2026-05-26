---
name: musicwall-test-refactor-pr-04
description: >-
  MusicWall test refactor PR 4 only — AlbumCollection replaces StoredAlbums collection
  logic (add/update/sort/export) with testable persist boundaries. Invoke explicitly.
disable-model-invocation: true
paths:
  - MusicWall/**
  - MusicWallTests/**
---

# PR 4 — AlbumCollection

**Requires:** PR 2, PR 3 merged  
**Blocks:** PR 5

## Goal

Replace in-memory collection + sort + dedup logic in `StoredAlbums` with `AlbumCollection` and explicit persist control.

## In scope

- **`AlbumCollection`** (`@Observable` acceptable in app target or Core if no SwiftUI):
  - `items: [AlbumRecord]`
  - `add`, `update`, `remove`, `exportIDs`, `contains`
  - `applySort(using: AlbumSorter, key:, ascending:)`
  - Replace `itemsSavingLocked` with `performWithoutPersist { }` or `isHydrating` flag
- Inject **`PreferencesStore`**; persist on mutation (or explicit `save()` — document choice).
- **Tests:** dedup on add, update missing ID no-op, export IDs, shuffle without persist, sort after add.
- Wire app to use `AlbumCollection` **or** bridge from `StoredAlbums` if dual-write needed one release (minimize dual-write duration).

## Out of scope

- MusicKit `load()` / `importAlbums` network (PR 5–6).
- Deleting `StoredAlbums` entirely (PR 6/14).

## Acceptance criteria

- [ ] Unit tests do not call MusicKit or real UserDefaults.standard without isolation.
- [ ] Sort behavior matches PR 2 `AlbumSorter` tests.

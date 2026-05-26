---
name: musicwall-test-refactor-pr-02
description: >-
  MusicWall test refactor PR 2 only — Core domain types (AlbumID, AlbumRecord),
  AlbumSorter extracted from StoredAlbums.applySort. Invoke explicitly.
disable-model-invocation: true
paths:
  - MusicWall/**
  - MusicWallTests/**
  - Packages/**
---

# PR 2 — Core domain + AlbumSorter

**Requires:** PR 1 merged  
**Blocks:** PR 4

## Goal

Extract pure sorting logic and introduce app-owned domain types without breaking the running app.

## In scope

- Add **`MusicWall/Core/`** (or `Packages/MusicWallCore`) with:
  - `AlbumID` (`String` rawValue, `Codable`, `Hashable`, `Sendable`)
  - `AlbumRecord` (`id`, `title`, `artistName`, `releaseDate`)
  - `AlbumSortKey` (artist / title / year) — mirror `StoredAlbums.SortOptions`
  - **`AlbumSorter`**: logic copied **verbatim** from `StoredAlbums.applySort()` comparators
- **Tests:** table-driven matrix — all sort keys × asc/desc × nil `releaseDate` × case insensitivity.
- Optional thin adapter: `StoredAlbum` ↔ `AlbumRecord` for later PRs; app can still use `StoredAlbum` in UI.

## Out of scope

- Removing `StoredAlbum` / `MusicItemID` from persistence (PR 6).
- `PreferencesStore`, repositories, ViewModels.

## Acceptance criteria

- [ ] `AlbumSorter` tests match golden order fixtures derived from current app behavior.
- [ ] No change to UserDefaults keys or on-disk format.
- [ ] Existing app compiles; CI tests green.

## Agent notes

- Compare sort output against **copied** sample arrays from `StoredAlbums.dummyData()` before/after refactor.
- Keep Core free of `import MusicKit`.

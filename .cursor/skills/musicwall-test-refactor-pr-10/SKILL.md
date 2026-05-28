---
name: musicwall-test-refactor-pr-10
description: >-
  MusicWall test refactor PR 10 only — SearchViewModel and AlbumEditViewModel;
  surface errors in UI. Invoke explicitly.
disable-model-invocation: true
paths:
  - MusicWall/**
  - MusicWallTests/**
---

# PR 10 — Search + edit ViewModels

**Requires:** PR 5 merged  
**Blocks:** PR 12  
**Design (PR 5):** [docs/specs/2026-05-27-pr-05-repository-playback-design.md](../../../docs/specs/2026-05-27-pr-05-repository-playback-design.md)

## Goal

Testable search and edit flows; replace `print` error handling with user-visible state.

## Prerequisites from PR 5

- `AlbumSearchView` already uses `any AlbumRepository` and `[AlbumRecord]` / `onSelect: (AlbumRecord) -> Void`.
- `AlbumRecord.isExplicit` drives search row UI — VM does not re-map from MusicKit.
- Repository errors are `AlbumRepositoryError` — VM maps to `errorMessage`, not `MusicServiceError`.

## In scope

- **`SearchViewModel`**:
  - Parallel catalog + library search via `AlbumRepository` (same API as PR 5 view)
  - `isSearching`, `catalogResults` / `libraryResults` as `[AlbumRecord]`, `errorMessage`
- **`AlbumSearchView`**: thin bindings to VM; keep `onSelect(AlbumRecord)` at boundary
- **`AlbumEditViewModel`**:
  - Trim whitespace rules from `AlbumEditView.saveAlbum()`
  - Validation: empty title/artist disables save
- **`AlbumEditView`**: thin form bindings
- **Tests:** empty query; mock repo returns/errors; dual search; edit save output `AlbumRecord`

## Out of scope

- Grid/list layout (PR 11).
- Introducing `AlbumRepository` or migrating off `AlbumRecord` (PR 5).

## Acceptance criteria

- [ ] No `print(error)` left in search path.
- [ ] Edit save produces expected `AlbumRecord` in tests.
- [ ] No `MusicKit.Album` in search view layer.

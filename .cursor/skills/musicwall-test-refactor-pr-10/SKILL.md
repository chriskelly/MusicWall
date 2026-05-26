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

## Goal

Testable search and edit flows; replace `print` error handling with user-visible state.

## In scope

- **`SearchViewModel`**:
  - Parallel catalog + library search via `AlbumRepository`
  - `isSearching`, results arrays, `errorMessage`
- **`AlbumSearchView`**: binds to VM; `onSelect` passes `AlbumRecord` or maps at boundary
- **`AlbumEditViewModel`**:
  - Trim whitespace rules from `AlbumEditView.saveAlbum()`
  - Validation: empty title/artist disables save
- **`AlbumEditView`**: thin form bindings
- **Tests:** empty query; mock repo returns/errors; dual search; edit save output record

## Out of scope

- Grid/list layout (PR 11).

## Acceptance criteria

- [ ] No `print(error)` left in search path.
- [ ] Edit save produces expected `AlbumRecord` in tests.

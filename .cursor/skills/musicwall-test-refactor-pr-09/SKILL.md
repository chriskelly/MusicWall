---
name: musicwall-test-refactor-pr-09
description: >-
  MusicWall test refactor PR 9 only — HomeViewModel (sort, layout, import/export,
  snackbars); thin HomePageView. Invoke explicitly.
disable-model-invocation: true
paths:
  - MusicWall/**
  - MusicWallTests/**
---

# PR 9 — Home ViewModel

**Requires:** PR 6 merged; PR 7 if export/import uses new backup types  
**Blocks:** PR 12, PR 13

## Goal

Move home-screen orchestration out of `HomePageView` into testable `HomeViewModel`.

## In scope

- **`HomeViewModel`**:
  - Layout preference load/save (from `LayoutMenu`)
  - Sort menu actions → `AlbumCollection` + `AlbumSorter`
  - Export/import flows → `BackupCodec` / file services / `AlbumCollection.import`
  - Snackbar message strings (success/failure)
- Thin **`HomePageView`**: bindings + `environment(albumCollection)`
- Move **`SortMenu`**, **`BackupMenu`** logic into VM or small helpers
- **Tests:** export empty collection; import success/failure messages; sort toggle; layout persistence

## Out of scope

- `LayoutViews` tap/play (PR 11).
- `SearchViewModel` (PR 10).

## Acceptance criteria

- [ ] `HomePageView` contains no direct `BackupService` / `MusicService` calls.
- [ ] ViewModel tests run without SwiftUI hosting where possible.

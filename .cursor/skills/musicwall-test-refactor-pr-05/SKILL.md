---
name: musicwall-test-refactor-pr-05
description: >-
  MusicWall test refactor PR 5 only — AlbumRepository and PlaybackController protocols,
  MusicKit adapters, remove static MusicService and model play/pause. Invoke explicitly.
disable-model-invocation: true
paths:
  - MusicWall/**
  - MusicWallTests/**
---

# PR 5 — Repository + playback protocols

**Requires:** PR 4 merged  
**Blocks:** PR 6, PR 10, PR 11  
**Design:** [docs/specs/2026-05-27-pr-05-repository-playback-design.md](../../../docs/specs/2026-05-27-pr-05-repository-playback-design.md)

## Goal

Eliminate static `MusicService` and playback methods on `StoredAlbum`; all MusicKit/SystemMusicPlayer behind protocols.

## Decisions (locked)

- **Search:** `AlbumSearchView` uses `[AlbumRecord]` + injected `AlbumRepository` (no `MusicKit.Album` in view).
- **`AlbumRecord`:** add `isExplicit: Bool` (mapper from `contentRating == .explicit`).
- **Injection:** Hybrid — `AppDependencies` owns instances; `StoredAlbums` / `AlbumSearchView` use constructor injection; leaf views use `@Environment(\.albumRepository)` / `@Environment(\.playback)` installed in `HomePageView`.
- **Artwork (until PR 11):** `AlbumRepository.artworkURL(for:width:height:)` — `ImageCache` uses this; no `MusicService` in `ImageCache`.
- **Errors:** `AlbumRepositoryError` + `PlaybackError` in Core (replace `MusicServiceError`).
- **Tap:** Inline `onAlbumTapped` + `PlaybackController` in PR 5; `AlbumTapCoordinator` is PR 11.

## In scope

- Protocols (`MusicWall/Core/`):
  - **`AlbumRepository`**: `search(query, source:)`, `fetch(ids:)`, `artworkURL(for:width:height:)`
  - **`AlbumSearchSource`**: `.catalog` | `.library`
  - **`PlaybackController`**: `play(albumId:)`, `pause()`
- Implementations (`MusicWall/Adapters/`):
  - **`MusicKitAlbumRepository`** (logic from `MusicService.swift`)
  - **`SystemMusicPlayerAdapter`** (depends on repository; no force-unwrap on play)
  - **`AlbumMapper`**: `MusicKit.Album` → `AlbumRecord`
- **`Environment+Services.swift`**: `@Entry` keys for repository + playback
- Register in **`AppDependencies.live`** / **`preview()`** with mocks
- **`StoredAlbums(preferences:repository:)`** — `load` / `importAlbums` use repository
- Remove **`StoredAlbum.play()` / `pause()`**; **`onAlbumTapped`** uses `PlaybackController`
- **Tests:** `MockAlbumRepository`, `MockPlaybackController` — errors, empty query, empty IDs, tap call order

## Out of scope

- Full `load()` / persistence migration (PR 6).
- `SearchViewModel` / snackbar errors (PR 10).
- `AlbumTapCoordinator`, `ArtworkProvider` (PR 11).

## Acceptance criteria

- [ ] No remaining `MusicService.` call sites; `MusicService.swift` deleted.
- [ ] `AlbumRecord.isExplicit` + mapper tests or mock coverage.
- [ ] Mock tests cover `AlbumRepositoryError` / `PlaybackError` equivalents.
- [ ] Hybrid injection per design spec.
- [ ] Optional one-line `Agent.md` pointer to protocols.

## Risk

- Playback needs `MusicKit.Album` for queue — use package-private helper on `MusicKitAlbumRepository` from `SystemMusicPlayerAdapter` (not on Core protocol).

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

## Goal

Eliminate static `MusicService` and playback methods on `StoredAlbum`; all MusicKit/SystemMusicPlayer behind protocols.

## In scope

- Protocols:
  - **`AlbumRepository`**: `search(query, source: .catalog | .library)`, `fetch(ids: [AlbumID])`
  - **`PlaybackController`**: `play(albumId:)`, `pause()`
- Implementations:
  - **`MusicKitAlbumRepository`** (move logic from `MusicService.swift`)
  - **`SystemMusicPlayerAdapter`**
  - **`AlbumMapper`**: `MusicKit.Album` → `AlbumRecord`
- Register in **`AppDependencies.live`**
- Environment keys or injection for `playback` + `repository`
- Remove **`StoredAlbum.play()` / `pause()`**; update **`onAlbumTapped`** to use `PlaybackController`
- **Tests:** `MockAlbumRepository`, `MockPlaybackController` — error mapping, empty query, empty IDs, call order on tap

## Out of scope

- Full `load()` migration (PR 6).
- ViewModels (PR 8–10).

## Acceptance criteria

- [ ] No remaining `MusicService.` call sites in app (except adapter impl).
- [ ] Mock tests cover `MusicServiceError` equivalent domain errors.
- [ ] `Agent.md` architecture note can stay; optional one-line pointer to new protocols.

## Risk

- `fetchAlbums` force-unwrap in current `playAlbum` — fix while moving to adapter (use guard + typed error).

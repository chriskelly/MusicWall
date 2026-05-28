---
name: musicwall-test-refactor-pr-11
description: >-
  MusicWall test refactor PR 11 only — AlbumTapCoordinator, ArtworkProvider with
  injected URLSession/FileManager, displayScale from VM. Invoke explicitly.
disable-model-invocation: true
paths:
  - MusicWall/**
  - MusicWallTests/**
---

# PR 11 — Tap coordinator + artwork pipeline

**Requires:** PR 5 merged  
**Blocks:** PR 12  
**Design (PR 5):** [docs/specs/2026-05-27-pr-05-repository-playback-design.md](../../../docs/specs/2026-05-27-pr-05-repository-playback-design.md)

## Goal

Extract tap-to-play logic and make artwork loading fully mockable.

## Prerequisites from PR 5

- `PlaybackController` + `@Environment(\.playback)` already wired; `onAlbumTapped` calls `play` / `pause` with `AlbumID` (no `StoredAlbum.play()`).
- `ImageCache` uses `AlbumRepository.artworkURL(for:width:height:)` — **remove that method from `AlbumRepository` when `ArtworkProvider` lands** (avoid duplicate APIs).
- `AlbumRecord` / repository boundaries unchanged — coordinator does not touch MusicKit.

## In scope

- **`AlbumTapCoordinator`** (or pure functions):
  - Same behavior as PR 5 `onAlbumTapped` in `LayoutViews.swift` (select/deselect, play, pause)
  - Uses `PlaybackController` protocol
- **`ArtworkProvider`** protocol; refactor **`ImageCache`** → inject:
  - Artwork resolution (replaces `AlbumRepository.artworkURL`)
  - `URLSession` protocol
  - `FileManager`
- Remove **`UIScreen.main.scale`** from view — pass `displayScale` from environment/VM
- **Tests:** tap state machine; cache hit; cache miss + download; download fail returns remote URL

## Out of scope

- ViewInspector (PR 12).
- `AlbumRepository` search/fetch design (PR 5).

## Acceptance criteria

- [ ] `onAlbumTapped` private function removed; coordinator tested.
- [ ] `ImageCache` / `ArtworkProvider` tests use mocks only (no network).
- [ ] `AlbumRepository` no longer requires `artworkURL` (moved to `ArtworkProvider`).

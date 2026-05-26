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

## Goal

Extract tap-to-play logic and make `ImageCache` fully mockable.

## In scope

- **`AlbumTapCoordinator`** (or pure functions):
  - Same behavior as `onAlbumTapped` in `LayoutViews.swift` (select/deselect, play, pause)
  - Uses `PlaybackController` protocol
- **`ArtworkProvider`** protocol; refactor **`ImageCache`** → inject:
  - `AlbumRepository` (or artwork URL provider)
  - `URLSession` protocol
  - `FileManager`
- Remove **`UIScreen.main.scale`** from view — pass `displayScale` from environment/VM
- **Tests:** tap state machine; cache hit; cache miss + download; download fail returns remote URL

## Out of scope

- ViewInspector (PR 12).

## Acceptance criteria

- [ ] `onAlbumTapped` private function removed; coordinator tested.
- [ ] `ImageCache`/`ArtworkProvider` tests use mocks only (no network).

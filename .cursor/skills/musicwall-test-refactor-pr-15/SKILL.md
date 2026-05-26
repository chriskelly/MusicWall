---
name: musicwall-test-refactor-pr-15
description: >-
  MusicWall test refactor PR 15 (optional) — extract MusicWallCore, MusicWallPersistence,
  MusicWallMusicKit as local Swift packages. Invoke explicitly.
disable-model-invocation: true
paths:
  - MusicWall/**
  - Packages/**
  - MusicWall.xcodeproj/**
  - MusicWallTests/**
---

# PR 15 (optional) — SPM module extraction

**Requires:** PR 14 merged  
**Blocks:** nothing

## Goal

Physical module boundaries matching logical layers; Core tests link without MusicKit.

## In scope

- Create local packages:
  - `Packages/MusicWallCore`
  - `Packages/MusicWallPersistence`
  - `Packages/MusicWallMusicKit` (depends on Core + MusicKit)
- App target depends on all three
- Move files from `MusicWall/Core/`, `MusicWall/Adapters/` into packages
- **Tests:** `MusicWallCoreTests` can run with package-only scheme (optional CI job)

## Out of scope

- New features or behavior changes.
- Coverage threshold changes (unless package split breaks reporting — fix in same PR).

## Acceptance criteria

- [ ] App builds and all existing tests pass.
- [ ] `MusicWallCore` target has zero MusicKit dependency in `Package.swift`.
- [ ] README or `docs/testing.md` notes package layout.

## When to skip

Skip if team prefers folder-based modules and PR 14 coverage is sufficient.

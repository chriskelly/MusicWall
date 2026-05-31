---
name: musicwall-test-refactor-pr-14
description: >-
  MusicWall test refactor PR 14 only — coverage thresholds in CI, delete legacy types,
  update Agent.md and testing docs. Invoke explicitly.
disable-model-invocation: true
paths:
  - MusicWall/**
  - MusicWallTests/**
  - MusicWallUITests/**
  - fastlane/**
  - .github/workflows/**
  - Agent.md
  - MusicWallTests/Agent.md
---

# PR 14 — Coverage gates + legacy cleanup

**Requires:** PR 12, PR 13 merged  
**Blocks:** optional PR 15

## Goal

Enforce coverage policy; remove dead code from pre-refactor architecture.

## In scope

- CI fails if coverage below thresholds:
  - Core/Persistence: **≥ 95%**
  - ViewModels: **≥ 90%**
  - Adapters: **≥ 80%**
- Implement via `xccov` / custom script — upload summary to PR (optional)
- **Delete** (if fully replaced):
  - `StoredAlbum` / `StoredAlbums` (if not already)
  - Static `MusicService` enum
  - `UserDefaultsManager` class
  - Legacy `BackupService` monolith
- Update **`Agent.md`**: architecture section points to layered model + `MusicWallTests/Agent.md`
- Update **`MusicWallTests/Agent.md`**: exclusions, commands, threshold table
- PR template checkbox: unit tests + coverage (optional)

## Out of scope

- SPM extraction (PR 15).

## Acceptance criteria

- [ ] CI enforces thresholds on `main` and PRs.
- [ ] No orphaned references to deleted types.
- [ ] Documented exclusions for live MusicKit success paths.

## Ratchet note

If full thresholds fail mid-program, land informational reporting first, then flip `fail_ci` in same PR.

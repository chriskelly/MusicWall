---
name: musicwall-test-refactor-pr-13
description: >-
  MusicWall test refactor PR 13 only — MusicWallUITests target, launch arguments,
  mock AppDependencies, smoke flows. Invoke explicitly.
disable-model-invocation: true
paths:
  - MusicWall/**
  - MusicWallUITests/**
  - MusicWall.xcodeproj/**
---

# PR 13 — UI tests + launch configuration

**Requires:** PR 8, PR 9 merged  
**Blocks:** PR 14

## Goal

End-to-end smoke tests on simulator without real MusicKit or Apple ID.

## In scope

- Add **`MusicWallUITests`** target to Xcode project + scheme
- **`AppDependencies.uiTest`**: mock auth (authorized), mock repository (fixture albums), mock playback
- Launch argument e.g. `-UITestMockMusic 1` read in `MusicWallApp`
- Tests (minimum):
  1. Launch → album list visible (fixture titles)
  2. Tap album → mock playback invoked (if assertable via launch env)
  3. Open search sheet → dismiss
- CI: run UI tests on `no-deploy` job (accept +2–3 min runtime)

## Out of scope

- Real catalog search in UI tests.
- Coverage gates (PR 14).

## Acceptance criteria

- [ ] UI tests pass on GitHub Actions simulator.
- [ ] Production launch path unchanged when argument absent.
- [ ] Document UI test command in `docs/testing.md`

## Flake control

- Use accessibility identifiers on key buttons/lists.
- Avoid fixed `sleep` — prefer `waitForExistence`.

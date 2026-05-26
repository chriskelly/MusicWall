---
name: musicwall-test-refactor-pr-12
description: >-
  MusicWall test refactor PR 12 only — ViewInspector or snapshot tests for SnackbarView,
  sort menu, edit validation UI. Invoke explicitly.
disable-model-invocation: true
paths:
  - MusicWall/**
  - MusicWallTests/**
---

# PR 12 — SwiftUI unit-level UI tests

**Requires:** PR 9, PR 10, PR 11 merged (or rebased onto their changes)  
**Blocks:** PR 14

## Goal

Automated tests for high-value SwiftUI without full XCUITest cost.

## In scope

- Add **ViewInspector** (or snapshot testing) to test target — document in `docs/testing.md`
- Tests:
  - `SnackbarView` — message, action button, undo callback
  - Sort menu — checkmark on current sort
  - `AlbumEditView` — Save disabled when title empty
- Keep tests **stable** (no animation timing assertions)

## Out of scope

- Full app XCUITest (PR 13).
- Vinyl animation / `glassEffect()` branches unless trivial snapshot.

## Acceptance criteria

- [ ] CI runs new tests on macOS job.
- [ ] Dependency license acceptable (note in PR description).

## Decision

Pick **one** of ViewInspector vs snapshot in PR description; don't add both unless justified.

---
name: musicwall-test-refactor-pr-08
description: >-
  MusicWall test refactor PR 8 only — AuthViewModel and MusicAuthorizationProviding
  protocol; thin ContentView. Invoke explicitly.
disable-model-invocation: true
paths:
  - MusicWall/**
  - MusicWallTests/**
---

# PR 8 — Auth ViewModel

**Requires:** PR 6 merged  
**Blocks:** PR 13 (UI tests)

## Goal

Test authorization state machine without calling real `MusicAuthorization.request()` in unit tests.

## In scope

- **`MusicAuthorizationProviding`** protocol wrapping authorization status + request
- **`AuthViewModel`** (`@MainActor`, `@Observable`): states `.loading`, `.authorized`, `.denied`
- **`ContentView`**: binds to VM only; remove inline `requestAuthorization` logic
- **`AppDependencies`**: inject live vs mock provider
- **Tests:** all `MusicAuthorization.Status` branches including `@unknown default`

## Out of scope

- Home/search features.
- UI tests (PR 13).

## Acceptance criteria

- [ ] Unit tests cover 100% of AuthViewModel state transitions.
- [ ] Preview uses mock authorized state.

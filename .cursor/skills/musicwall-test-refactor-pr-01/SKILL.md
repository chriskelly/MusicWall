---
name: musicwall-test-refactor-pr-01
description: >-
  MusicWall test refactor PR 1 only — MusicWallTests target, scheme TestAction,
  CI xcodebuild test, AppDependencies skeleton. Invoke explicitly for this PR.
disable-model-invocation: true
paths:
  - MusicWall/**
  - MusicWall.xcodeproj/**
  - fastlane/**
  - .github/workflows/**
  - docs/testing.md
---

# PR 1 — Test harness + composition root skeleton

**Program:** [musicwall-test-refactor](../musicwall-test-refactor/SKILL.md)  
**Requires:** nothing (first PR)  
**Blocks:** PR 2, PR 3

## Goal

Enable automated tests in CI and introduce dependency injection entry point without changing user-visible behavior.

## In scope

- Add **`MusicWallTests`** target (XCTest or Swift Testing — document choice in `docs/testing.md`).
- Wire **`MusicWall.xcscheme`** `TestAction` → `MusicWallTests`; enable **Gather code coverage**.
- Extend **`fastlane`** (`ci_test` lane or extend `ci_build`) to run:
  `xcodebuild test -scheme MusicWall -destination 'platform=iOS Simulator,name=iPhone 16'` (match CI simulator).
- Update **`.github/workflows/ios-preview.yml`**: run tests on `no-deploy` PRs (or all PRs once stable).
- Add **`AppDependencies`** struct with static `.live` factory (empty/minimal protocols OK).
- Pass `AppDependencies` from `MusicWallApp` → `ContentView` (no behavior change yet).
- Create **`docs/testing.md`**: framework choice, local test command, exclusions list (MusicKit live).

## Out of scope

- Domain model changes, `MusicService` refactor, ViewModels.
- Coverage thresholds (PR 14).
- UI tests.

## Tests required

- At least one **smoke test** (e.g. `@testable import MusicWall` + `XCTAssertTrue(true)` or `AppDependencies.live` constructs).
- Verify test target builds on CI.

## Acceptance criteria

- [ ] `bundle exec fastlane ci_test` (or documented equivalent) passes locally on Mac.
- [ ] GitHub Actions `no-deploy` job runs tests and reports pass/fail.
- [ ] App behavior unchanged; TestFlight path still works when label absent.
- [ ] `docs/testing.md` exists.

## Agent checklist

1. Branch `cursor/test-refactor-pr-01-test-harness-c3d5` from `main`.
2. Do **not** implement PR 2+ items.
3. PR description: link "PR 1 of 14" and list CI command for humans.
4. Use label **`no-deploy`** on this PR until test lane is proven stable (optional).

## Key files (starting point)

- `MusicWall/MusicWallApp.swift`, `MusicWall/ContentView.swift`
- `MusicWall.xcodeproj/project.pbxproj`, `xcshareddata/xcschemes/MusicWall.xcscheme`
- `fastlane/Fastfile`, `.github/workflows/ios-preview.yml`

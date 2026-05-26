---
name: musicwall-test-refactor
description: >-
  MusicWall iOS testability refactor program — layered architecture, 14 PR roadmap,
  coverage policy. Use when planning or scoping any PR in this program, or when the user
  asks about full test coverage, MusicWallCore, ViewModels, or test-friendly refactors.
paths:
  - MusicWall/**
  - MusicWall.xcodeproj/**
  - MusicWallTests/**
  - MusicWallUITests/**
  - Packages/**
  - fastlane/**
  - .github/workflows/**
  - docs/testing.md
metadata:
  project: MusicWall
  program-version: "1"
---

# MusicWall testability refactor (program overview)

This skill describes a **multi-PR refactor** of the MusicWall SwiftUI + MusicKit app into testable layers, with tests added **in the same PR** as each refactor step.

## How to run one PR with a dedicated agent

1. Confirm prerequisites (see [references/pr-index.md](references/pr-index.md)) are merged on `main`.
2. Invoke **only** the PR skill, e.g. `/musicwall-test-refactor-pr-05` — do not implement other PRs in the same session.
3. Branch from `main`: `cursor/test-refactor-pr-05-<short-topic>-c3d5` (or team convention).
4. Read [references/architecture.md](references/architecture.md) for north-star rules.
5. Ship one PR; CI must pass `ios-preview` (`no-deploy` until tests are stable, then drop label if appropriate).
6. Update `docs/testing.md` when behavior or coverage policy changes.

## North star (summary)

- **Core** has no `MusicKit`, `SwiftUI`, or `UIKit`.
- **Domain types** are app-owned (`AlbumID`, `AlbumRecord`) — not `MusicKit.Album` in persistence.
- **Protocols** at boundaries: `AlbumRepository`, `PlaybackController`, `PreferencesStore`, `ArtworkProvider`.
- **ViewModels** own async work and state; **views** bind only.
- **Composition root**: `AppDependencies` / environment keys — previews and tests inject fakes.
- **Playback** is not on model types; use `PlaybackController`.

Full detail: [references/architecture.md](references/architecture.md).

## PR index

| PR | Skill to invoke | Focus |
|----|-----------------|--------|
| 1 | `/musicwall-test-refactor-pr-01` | Test target, CI `xcodebuild test`, `AppDependencies` skeleton |
| 2 | `/musicwall-test-refactor-pr-02` | Core types + `AlbumSorter` |
| 3 | `/musicwall-test-refactor-pr-03` | `PreferencesStore` + UserDefaults adapter |
| 4 | `/musicwall-test-refactor-pr-04` | `AlbumCollection` replaces collection logic |
| 5 | `/musicwall-test-refactor-pr-05` | Repository + playback protocols; remove static `MusicService` |
| 6 | `/musicwall-test-refactor-pr-06` | Load/migrate persistence + repository wiring |
| 7 | `/musicwall-test-refactor-pr-07` | `BackupCodec` + file export/import |
| 8 | `/musicwall-test-refactor-pr-08` | `AuthViewModel` + authorization protocol |
| 9 | `/musicwall-test-refactor-pr-09` | `HomeViewModel` + thin `HomePageView` |
| 10 | `/musicwall-test-refactor-pr-10` | `SearchViewModel` + `AlbumEditViewModel` |
| 11 | `/musicwall-test-refactor-pr-11` | `AlbumTapCoordinator` + `ArtworkCache` injection |
| 12 | `/musicwall-test-refactor-pr-12` | ViewInspector or snapshot tests for key UI |
| 13 | `/musicwall-test-refactor-pr-13` | `MusicWallUITests` + launch mocks |
| 14 | `/musicwall-test-refactor-pr-14` | Coverage gates, delete legacy, docs |
| 15 (optional) | `/musicwall-test-refactor-pr-15` | Extract `Packages/*` SPM modules |

Dependency graph: [references/pr-dependencies.md](references/pr-dependencies.md).

## Program-wide rules

- **One PR = one skill** — no scope creep into later PRs.
- **Tests in every PR** for code moved or added in that PR.
- **Preserve UserDefaults compatibility** until PR 6 migration is explicit and tested.
- **Do not** change `DEVELOPMENT_TEAM`, bundle ID, or commit secrets (see root `Agent.md`).
- **Linux cloud agents** cannot compile iOS — rely on GitHub Actions; note device-only checks for humans.
- **MusicKit playback/auth** remain human-verified on TestFlight; unit tests use mocks.

## Coverage policy (final state, PR 14)

| Layer | Enforced target |
|-------|-----------------|
| Core / Persistence | ≥ 95% |
| ViewModels | ≥ 90% |
| MusicKit adapters | ≥ 80% (live API success paths documented as excluded) |
| SwiftUI | Coordinator + UI tests, not 100% line coverage on animations |

Exclusions: real catalog search success, `SystemMusicPlayer` integration, vinyl animations, `glassEffect()` branches unless snapshotted.

## Decisions (lock in PR 1, document in `docs/testing.md`)

| Decision | Options | Default if unset |
|----------|---------|------------------|
| Test framework | Swift Testing vs XCTest | XCTest (CI familiarity) |
| Module split | SPM in PR 2 vs folders first | Folders under `MusicWall/Core/` until optional PR 15 |
| Coverage ratchet | Only PR 14 vs 70% → 85% → 95% | Ratchet at PR 7, 11, 14 |

## Related repo docs

- `Agent.md` — CI/CD, MusicKit, branch conventions
- `docs/specs/2026-05-24-ios-cicd-design.md` — planned `MusicWallTests` in CI

# Agent guide — MusicWallTests

`MusicWallTests` is the deterministic test target. UI smoke tests live in `MusicWallUITests`. Both run through the shared `MusicWall` scheme on the iPhone 17 simulator.

## Test pyramid

| Layer | Target | Framework |
|-------|--------|-----------|
| Core / Adapters / ViewModels | `MusicWallTests` | Swift Testing |
| SwiftUI views (Snackbar, SortMenu, AlbumEdit) | `MusicWallTests` | Swift Testing + ViewInspector |
| End-to-end smoke | `MusicWallUITests` | XCTest / XCUITest |

Layer, design, and TDD rules live in `../AGENTS.md`; this guide adds only test-specific conventions.

## Commands

```bash
bundle exec fastlane ci_tests
```

Unit-only, single-test, UI-only, coverage-only, and warnings-only commands: `docs/commands.md`.

## Conventions

- UI tweaks do not need a test. Use Swift Testing by default and XCTest/XCUITest for UI only.
- Fixtures: `Fixtures/AlbumFixtures.swift` holds canonical `AlbumRecord` samples (`baseTrio`, UTC date helpers); `MusicWall/UITestSupport/UITestFixtures.swift` must match their IDs and titles.
- Test doubles live in `TestSupport/`.
- **Stability:** no animation-timing or auto-dismiss assertions, no snapshot reference images, no `glassEffect()` branch coverage unless trivial, and do not inspect content inside `Menu` or `contextMenu`.
- **Warnings:** both test targets compile with warnings as errors; `Scripts/check_warnings.sh` prints a bucket summary only.

## Docs index

- Full test and coverage commands → `docs/commands.md`
- UI launch arguments and accessibility identifiers → `docs/ui-tests.md`
- ViewInspector patterns and inventory → `docs/viewinspector.md`
- Coverage thresholds and adapter exclusions → `docs/coverage.md`

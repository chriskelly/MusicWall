# Swift warnings strategy — Phase 4 (Swift 6 language mode, all targets)

**Status:** Approved (2026-06-08)  
**Program:** MusicWall quality gates  
**Requires:** Phase 3 merged (PR #35 — strict concurrency on app target)  
**Parent spec:** `docs/specs/2026-06-08-swift-warnings-strategy-design.md`  
**Approach:** Set `SWIFT_VERSION = 6.0` on all three targets; single `@MainActor` annotation on the UI-test class clears the only blocker

## Summary

Enable **Swift 6 language mode** (`SWIFT_VERSION = 6.0`) on **all three targets** — `MusicWall`, `MusicWallTests`, `MusicWallUITests` — completing the warnings-strategy program. The app target is already strict-concurrency clean from Phase 3 and the unit-test target compiles cleanly under Swift 6. The only blocker is `MusicWallUITests`, where `XCUIApplication` / `XCUIElement` APIs are `@MainActor` while `XCTestCase` methods are nonisolated. A single class-level `@MainActor` annotation resolves all of those diagnostics.

Existing `SWIFT_TREAT_WARNINGS_AS_ERRORS` / `GCC_TREAT_WARNINGS_AS_ERRORS` on all targets is unchanged; it makes any future Swift 6 diagnostic CI-blocking once the baseline is clean. `SWIFT_STRICT_CONCURRENCY = complete` on the app target (Phase 3) stays in place.

## Goals

- CI **fails** when a PR introduces a Swift 6 language-mode diagnostic in **any** target.
- Achieve a **zero-diagnostic baseline** across all three targets before enabling the gate.
- Fix the UI-test blocker with proper isolation (`@MainActor`), not suppression.
- Complete and document the warnings-strategy program (Phases 1–4).

## Non-goals

- Actor refactors or architectural changes.
- `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` or other project-wide isolation defaults.
- ViewInspector changes (version bump, fork, vendoring, or replacement).
- `@unchecked Sendable` / `@preconcurrency` additions.
- Changes to `Scripts/check_warnings.sh`, `fastlane/Fastfile`, or `.github/workflows/`.

## Decisions (brainstorming)

| Topic | Choice |
|-------|--------|
| Phase 4 outcome | **Fix + enable** — clear baseline, then set `SWIFT_VERSION = 6.0` |
| Scope | **All three targets** — app, unit tests, UI tests |
| UI-test fix | **`@MainActor` on `MusicWallUITests` class** — one line, clears all diagnostics |
| ViewInspector | **No change** — SPM compiles it in its own Swift 5 mode |
| Enforcement | **Compiler** — existing `TREAT_WARNINGS_AS_ERRORS`; no new scripts |

## Approaches considered

### Phase 4 outcome

| Option | Description | Why not chosen |
|--------|-------------|----------------|
| **Fix + enable (chosen)** | Annotate UI-test class; set `SWIFT_VERSION = 6.0` on all targets | — |
| Assessment only | Document inventory; defer build setting | Program already at the finish line; only one trivial fix remains |
| App target only | Swift 6 on `MusicWall`, defer test targets | Leaves the program incomplete for no benefit; test targets are clean or one-line away |

### UI-test isolation fix

| Option | Description | Why not chosen |
|--------|-------------|----------------|
| **Class `@MainActor` (chosen)** | Annotate `final class MusicWallUITests` | One line; idiomatic for XCTest UI tests; verified green |
| Per-method `@MainActor` | Annotate each test method + helpers | More edits, identical result, higher churn |
| Project default isolation | `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` | Broad project-wide behavior change; out of scope for a warnings phase |

### ViewInspector (investigated, no action)

A probe using a command-line `SWIFT_VERSION=6` override forced ViewInspector into Swift 6 mode and surfaced a `callWithIndex` data-race error in `ViewSearchIndex.swift`. This is a **probe artifact**: SwiftPM compiles each package in its own declared language version. ViewInspector's `Package.swift` is `swift-tools-version:5.9` with no `swiftLanguageVersions`, so it always builds in **Swift 5 mode** regardless of our targets' `SWIFT_VERSION`. A per-target Swift 6 build confirmed ViewInspector compiles with zero errors. Version `0.10.4` is byte-identical at the failing line, so a bump would change nothing. No fork, vendoring, or replacement is needed.

## Baseline inventory (verified 2026-06-08)

Probe methodology: set `SWIFT_VERSION = 6.0` on all six target build configs in `project.pbxproj` (no command-line override), then `xcodebuild test` with warnings-as-errors enabled (true CI config).

| Target | Swift 6 diagnostics | Action |
|--------|---------------------|--------|
| `MusicWall` app | **0** | None — strict-concurrency clean from Phase 3 |
| `MusicWallTests` (incl. ViewInspector dependency) | **0** | None |
| `MusicWallUITests` | **104** | `@MainActor` on the test class |

All 104 UI-test diagnostics are the same class of main-actor isolation issue:

| Count | Diagnostic |
|-------|-----------|
| 15 | call to main actor-isolated `waitForExistence(timeout:)` in synchronous nonisolated context |
| 14 | main actor-isolated subscript can not be referenced from nonisolated autoclosure |
| 10 | main actor-isolated property `navigationBars` from nonisolated autoclosure |
| 7 | main actor-isolated subscript from nonisolated context |
| 6 | call to main actor-isolated `tap()` |
| 4 | main actor-isolated `staticTexts` from nonisolated autoclosure |
| 4 | main actor-isolated `buttons` from nonisolated context |
| ... | remaining: `value`, `otherElements`, `exists`, `firstMatch`, `launchArguments`, `launch()`, `init()` — all main-actor isolation |

`XCUIApplication` and `XCUIElement` are `@MainActor`-isolated in the SDK; UI tests already run on the main thread, so isolating the test class is correct, not a workaround.

## Code changes

### `MusicWallUITests` — main-actor isolation

```swift
import XCTest

@MainActor
final class MusicWallUITests: XCTestCase {
    // unchanged body
}
```

No other test edits. Private helpers (`launchApp`, `assertFixtureAlbumsVisible`, `waitUntilHittable`, `waitForLastPlayedAlbumID`) become main-actor isolated via the class annotation; this is consistent with their existing use of `XCUIElement` APIs.

## Xcode changes

Change in **all six target build configurations** (app, `MusicWallTests`, `MusicWallUITests` × Debug + Release) in `MusicWall.xcodeproj/project.pbxproj`:

```
SWIFT_VERSION = 6.0;
```

(previously `5.0`). The project-level (`XCConfigurationList` for the project) configurations set no `SWIFT_VERSION`, so no project-level change is required. Strict-concurrency and warnings-as-errors settings are untouched.

**Fastlane / workflow:** no changes to `fastlane/Fastfile` or `.github/workflows/ci-tests.yml`.

## Script — `check_warnings.sh`

No behavior change. Swift 6 diagnostics appear in the xcodebuild log as ordinary `warning:` / `error:` lines; the compiler gate catches them before the script runs.

## Documentation

| Path | Change |
|------|--------|
| `Agent.md` | Warnings policy: Swift 6 language mode (`SWIFT_VERSION = 6.0`) on all targets; link Phase 4 spec |
| `docs/specs/2026-06-08-swift-warnings-strategy-design.md` | Phase 4 row → **Done**; link to this document |

No `MusicWallTests/Agent.md` change required (no test-command or policy change beyond the language mode noted in `Agent.md`).

## Error handling

- New Swift 6 diagnostic on any target after the gate: xcodebuild fails at compile time (same as ordinary warnings).
- ViewInspector behavior under future Swift 6 adoption upstream: out of scope; the dependency builds in its own language mode.

## Implementation task order

1. **Baseline capture** — re-run per-target Swift 6 probe; confirm only `MusicWallUITests` errors (104, all main-actor isolation).
2. **UI-test fix** — add `@MainActor` to `MusicWallUITests` class.
3. **Enable build setting** — `SWIFT_VERSION = 6.0` on all six target configs.
4. **Verify positive** — `bundle exec fastlane ci_tests` (or `xcodebuild test`) passes with zero diagnostics; 5/5 UI tests pass.
5. **Verify negative** — introduce a deliberate Swift 6 isolation/data-race violation in app source → compile failure → revert.
6. **Update documentation** — `Agent.md`, parent spec Phase 4 row.

## Acceptance criteria

- [ ] `SWIFT_VERSION = 6.0` set on all six target configurations (app + both test targets, Debug + Release).
- [ ] `bundle exec fastlane ci_tests` passes with zero warnings in all `check_warnings.sh` buckets and zero compiler diagnostics.
- [ ] `MusicWallUITests` class is `@MainActor`; no other test changes.
- [ ] ViewInspector unchanged (no version bump, fork, or replacement).
- [ ] Deliberate app Swift 6 diagnostic causes compile failure (verified locally, then reverted).
- [ ] Docs updated; parent spec Phase 4 row marked Done and links to this document.

## Human verification (PR description)

- Confirm per-target probe inventory was zero outside `MusicWallUITests` before the fix.
- Paste `check_warnings.sh` summary showing zero warnings in all buckets.
- Spot-check `project.pbxproj`: `SWIFT_VERSION = 6.0` on all six target configs.
- Note the single `@MainActor` annotation on `MusicWallUITests`.

## PR delivery

- Branch: `cursor/swift-warnings-phase4` (or team convention).
- PR title: `ci: Swift 6 language mode on all targets (phase 4)`
- Link specs: this document + parent `docs/specs/2026-06-08-swift-warnings-strategy-design.md`

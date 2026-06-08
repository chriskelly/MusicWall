# Swift warnings strategy — Phase 3 (strict concurrency on app target)

**Status:** Approved (2026-06-08)  
**Program:** MusicWall quality gates  
**Requires:** Phase 2 merged (PR #34 — warnings-as-errors on test targets)  
**Parent spec:** `docs/specs/2026-06-08-swift-warnings-strategy-design.md`  
**Approach:** Isolation alignment fixes; clean six-warning baseline; `SWIFT_STRICT_CONCURRENCY = complete` on `MusicWall` target only

## Summary

Enable **`SWIFT_STRICT_CONCURRENCY = complete`** on the **`MusicWall` app target** after clearing six strict-concurrency diagnostics surfaced by a probe build. Fixes use **isolation alignment** — no actor refactors, no `@preconcurrency` imports, no project-wide setting.

Test targets keep default (minimal) strict-concurrency checking. A project-wide probe showed 60+ main-actor warnings in `MusicWallUITests` alone; those remain out of scope until a future phase.

Existing **`SWIFT_TREAT_WARNINGS_AS_ERRORS`** on all targets is unchanged. Strict-concurrency diagnostics are compiler warnings (or errors under complete checking); warnings-as-errors makes them CI-blocking once the baseline is clean.

## Goals

- CI **fails** when a PR introduces a strict-concurrency diagnostic in **`MusicWall/`** app source.
- Achieve a **zero-diagnostic baseline** on the app target before enabling the build setting.
- Fix warnings with proper isolation (`@MainActor`, `Sendable`, API shape changes) — not broad suppressions.
- Document the app-target strict-concurrency gate and link from the parent warnings strategy.

## Non-goals

- Swift 6 language mode (Phase 4 in parent spec).
- `SWIFT_STRICT_CONCURRENCY = complete` on **`MusicWallTests`** or **`MusicWallUITests`**.
- Changes to `Scripts/check_warnings.sh`, Fastlane, or GitHub workflow wiring.
- `FAIL_ON_TEST_WARNINGS=true` or other script gates.
- Actor refactors (`ImageCache` stays a struct).
- CarPlay or tap-handling architectural rewrites beyond what the six warnings require.

## Decisions (brainstorming)

| Topic | Choice |
|-------|--------|
| Phase 3 outcome | **Fix + enable** — clear baseline, then set build setting on app target |
| Fix strategy | **Isolation alignment (A)** — `@MainActor`, `Sendable`, return-value API |
| Scope | **`MusicWall` target only** — test targets unchanged |
| Enforcement | **Compiler** — existing `TREAT_WARNINGS_AS_ERRORS`; no new scripts |
| `ImageCache` Sendable | Synthesized conformance first; **`@unchecked Sendable`** fallback if `FileManager` blocks it |
| `AlbumTapCoordinator` | **Return `String?`** instead of `@MainActor` setter closure |

## Approaches considered

### Phase 3 outcome

| Option | Description | Why not chosen |
|--------|-------------|----------------|
| **Fix + enable (chosen)** | Clear six app warnings; enable `SWIFT_STRICT_CONCURRENCY = complete` on app target | — |
| Assessment only | Document inventory; defer build setting | Delays Swift 6 readiness path |
| Enable first, fix incrementally | Turn on setting with red CI | Blocks merges unnecessarily |

### Fix strategy

| Option | Description | Why not chosen |
|--------|-------------|----------------|
| **Isolation alignment (chosen)** | `@MainActor` on CarPlay factories; `Sendable` on `ImageCache`; return-value tap API | — |
| Shim-first | `@unchecked Sendable` and closure workarounds without API change | More suppression; weaker Phase 4 posture |
| Actor refactor | `actor ImageCache`; view-model migration | Scope too large for six warnings |

## Architecture

### CI flow (unchanged wiring, stricter app compile)

```
fastlane ci_tests
  │
  ├─ Scripts/check_core_imports.sh                    (existing)
  │
  ├─ xcodebuild test … 2>&1 | tee build/xcodebuild.log
  │     ├─ MusicWall:        TREAT_WARNINGS_AS_ERRORS = YES  (Phase 1)
  │     │                    SWIFT_STRICT_CONCURRENCY = complete  (Phase 3)
  │     ├─ MusicWallTests:   TREAT_WARNINGS_AS_ERRORS = YES  (Phase 2)
  │     └─ MusicWallUITests: TREAT_WARNINGS_AS_ERRORS = YES  (Phase 2)
  │        → compile fails if any target introduces a warning;
  │          app target also checks strict concurrency
  │
  ├─ Scripts/check_coverage.sh <xcresult>              (existing)
  │
  └─ Scripts/check_warnings.sh build/xcodebuild.log
        └─ report-only (FAIL_ON_TEST_WARNINGS=false, default)
```

### Enforcement matrix (after Phase 3)

| Source | Mechanism | CI behavior |
|--------|-----------|-------------|
| `MusicWall/` ordinary warnings | Compiler (`TREAT_WARNINGS_AS_ERRORS`) | **Fail build** |
| `MusicWall/` strict-concurrency diagnostics | Compiler (`SWIFT_STRICT_CONCURRENCY = complete` + warnings-as-errors) | **Fail build** |
| `MusicWallTests/` warnings | Compiler (`TREAT_WARNINGS_AS_ERRORS`) | **Fail build** |
| `MusicWallUITests/` warnings | Compiler (`TREAT_WARNINGS_AS_ERRORS`) | **Fail build** |
| `appintentsmetadataprocessor` noise | Script allowlist | **Ignored** |

## Baseline inventory (verified 2026-06-08)

Probe: `xcodebuild build -scheme MusicWall SWIFT_STRICT_CONCURRENCY=complete` with warnings-as-errors temporarily disabled to collect full inventory.

| # | File | Warning | Fix |
|---|------|---------|-----|
| 1 | `MusicWall/Adapters/CarPlay/CarPlaySetupTemplate.swift:9` | Main-actor-isolated `CPInformationTemplate` init from nonisolated static factory | Mark `CarPlaySetupTemplate` **`@MainActor`** |
| 2–3 | `MusicWall/Adapters/CarPlay/CarPlayBarButtons.swift:19` | Sending `CPBarButton` / `@MainActor` handler into `Task` | Mark enum **`@MainActor`**; use **`MainActor.assumeIsolated { handler(button) }`** instead of `Task { @MainActor in … }` |
| 4 | `MusicWall/Adapters/CarPlay/CarPlayCoordinator.swift:140` | Sending `imageCache` across `await` in `@MainActor` type | Make **`ImageCache`** conform to **`Sendable`** (`@unchecked` if `FileManager` blocks synthesis) |
| 5–6 | `MusicWall/LayoutViews.swift:80, :183` | Sending non-`Sendable` `@MainActor (String?) -> Void` into async `handleTap` | Refactor **`AlbumTapCoordinator.handleTap`** to return **`String?`** |

With warnings-as-errors enabled (current project default), item 1 is already a **compile error**; items 2–6 are warnings that also fail CI.

### Out-of-scope probe note (test targets)

Applying `SWIFT_STRICT_CONCURRENCY=complete` project-wide (command-line override) surfaced 60+ main-actor warnings in `MusicWallUITests/MusicWallUITests.swift`. Phase 3 does **not** enable the setting on test targets; that backlog is documented for a future phase.

## Code changes

### `AlbumTapCoordinator` — return selection instead of setter closure

```swift
// Before
static func handleTap(
    albumID: AlbumID,
    rawSelectedID: String?,
    setSelected: @MainActor (String?) -> Void,
    playback: any PlaybackController
) async

// After
static func handleTap(
    albumID: AlbumID,
    rawSelectedID: String?,
    playback: any PlaybackController
) async -> String?
```

Behavior unchanged:

- Same album tapped again → `playback.pause()`; return `nil`.
- Different album → `playback.play(albumId:)`; return `rawAlbumID`.

**Call sites** (`LayoutViews.swift` grid + list tap handlers):

```swift
Task {
    selectedAlbumID = await AlbumTapCoordinator.handleTap(
        albumID: AlbumID(rawValue: album.id.rawValue),
        rawSelectedID: selectedAlbumID,
        playback: playback
    )
}
```

**Tests** — `MusicWallTests/Core/AlbumTapCoordinatorTests.swift` (2 tests): assign return value instead of `setSelected` closure.

### `ImageCache` — `Sendable` conformance

```swift
struct ImageCache: Sendable { … }
```

If the compiler rejects synthesized `Sendable` because `FileManager` is not `Sendable`:

```swift
struct ImageCache: @unchecked Sendable { … }
```

Add a brief comment: cache operations are read/write on a dedicated cache directory; `FileManager` is used synchronously (same precedent as `UserDefaultsPreferencesStore`).

### CarPlay — `@MainActor` + synchronous main-thread dispatch

**`CarPlaySetupTemplate`:**

```swift
@MainActor
enum CarPlaySetupTemplate {
    static func make() -> CPInformationTemplate { … }
}
```

**`CarPlayBarButtons`:**

```swift
@MainActor
enum CarPlayBarButtons {
    …
    CPBarButton(image: symbolImage(systemName)) { button in
        MainActor.assumeIsolated {
            handler(button)
        }
    }
}
```

CarPlay bar-button callbacks are delivered on the main thread; `assumeIsolated` avoids sending non-`Sendable` `CPBarButton` across an async `Task` boundary.

## Xcode changes

Add to **`MusicWall` app target** build configurations (Debug + Release) in **`MusicWall.xcodeproj/project.pbxproj`**:

```
SWIFT_STRICT_CONCURRENCY = complete;
```

Place alongside existing `SWIFT_TREAT_WARNINGS_AS_ERRORS` / `GCC_TREAT_WARNINGS_AS_ERRORS`.

Do **not** set on **`MusicWallTests`**, **`MusicWallUITests`**, or project-wide.

**Fastlane / workflow:** no changes to `fastlane/Fastfile` or `.github/workflows/ci-tests.yml`.

## Script — `check_warnings.sh`

No behavior change in Phase 3. Strict-concurrency diagnostics appear in the xcodebuild log as ordinary `warning:` / `error:` lines; the app compiler gate catches them before the script runs.

## Documentation

| Path | Change |
|------|--------|
| `Agent.md` | Warnings policy: `SWIFT_STRICT_CONCURRENCY = complete` on app target; link Phase 3 spec |
| `docs/specs/2026-06-08-swift-warnings-strategy-design.md` | Phase 3 row links to this document |
| `.github/pull_request_template.md` | Optional note that app target uses strict concurrency (existing checkbox already covers warnings) |

No `MusicWallTests/Agent.md` changes — test targets unchanged.

## Error handling

- New strict-concurrency diagnostic on app target after gate enabled: xcodebuild fails at compile time (same as ordinary warnings).
- `ImageCache` synthesized `Sendable` rejected: fall back to `@unchecked Sendable` with comment; do not defer the gate.
- Test-target strict-concurrency backlog: dormant until a future phase explicitly enables the setting on those targets.

## Implementation task order

1. **Baseline capture** — re-run probe; confirm six-warning inventory.
2. **Refactor `AlbumTapCoordinator`** — return `String?`; update unit tests.
3. **Update `LayoutViews.swift`** — two tap call sites.
4. **`ImageCache` `Sendable`** — synthesized or `@unchecked` fallback.
5. **CarPlay isolation** — `@MainActor` on `CarPlaySetupTemplate`; `@MainActor` + `assumeIsolated` on `CarPlayBarButtons`.
6. **Enable build setting** — `SWIFT_STRICT_CONCURRENCY = complete` on `MusicWall` Debug + Release.
7. **Verify locally** — `bundle exec fastlane ci_tests` (positive); temporary app concurrency warning → compile failure → revert (negative).
8. **Update documentation** — `Agent.md`, parent spec Phase 3 row.

## Acceptance criteria

- [ ] `bundle exec fastlane ci_tests` passes with zero warnings in all `check_warnings.sh` buckets.
- [ ] `SWIFT_STRICT_CONCURRENCY = complete` set on `MusicWall` only (Debug + Release).
- [ ] `MusicWallTests` and `MusicWallUITests` do **not** have strict concurrency enabled.
- [ ] All six baseline diagnostics resolved without `@preconcurrency` imports or project-wide suppressions.
- [ ] Deliberate app strict-concurrency diagnostic causes compile failure (verified locally, then reverted).
- [ ] Docs updated; parent spec Phase 3 row links to this document.

## Human verification (PR description)

- Confirm probe inventory was zero before enabling build setting.
- Paste `check_warnings.sh` summary showing zero warnings in all buckets.
- Spot-check `project.pbxproj`: `SWIFT_STRICT_CONCURRENCY = complete` on `MusicWall` target only.
- Note any `@unchecked Sendable` on `ImageCache` and why.

## PR delivery

- Branch: `cursor/swift-warnings-phase3` (or team convention).
- PR title: `ci: strict concurrency on app target (phase 3)`
- Link specs: this document + parent `docs/specs/2026-06-08-swift-warnings-strategy-design.md`

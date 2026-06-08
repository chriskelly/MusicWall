# Swift warnings strategy — Phase 2 (test-target compiler gate)

**Status:** Approved (2026-06-08)  
**Program:** MusicWall quality gates  
**Requires:** Phase 1 merged (PR #33 — hybrid app gate + test report)  
**Parent spec:** `docs/specs/2026-06-08-swift-warnings-strategy-design.md`  
**Approach:** Compiler warnings-as-errors on test targets; ViewInspector bump-then-shim; clean baseline before enabling gate

## Summary

Extend Phase 1 by enabling **`SWIFT_TREAT_WARNINGS_AS_ERRORS`** and **`GCC_TREAT_WARNINGS_AS_ERRORS`** on **`MusicWallTests`** and **`MusicWallUITests`**, matching the app target. Clear the current seven-warning backlog first, then enable the gate in the same PR.

ViewInspector Sendable warnings are addressed with strategy **C**: resolve to the latest **`0.10.x`** pin, rebuild, and apply a test-only shim (`@retroactive InspectionEmissary`, plus `@unchecked Sendable` if needed) only if the bump alone does not clear warnings.

`check_warnings.sh` remains **report-only** — enforcement moves to the compiler. Do **not** set **`FAIL_ON_TEST_WARNINGS=true`**.

## Goals

- CI **fails** when a PR introduces a compiler warning in **any** project target (`MusicWall`, `MusicWallTests`, `MusicWallUITests`).
- Achieve a **zero-warning baseline** across all three targets before enabling the gate.
- Resolve ViewInspector Sendable warnings without upstream package changes (shim fallback is acceptable).
- Update documentation to reflect test-target compiler enforcement.

## Non-goals

- Swift 6 language mode (Phase 4 in parent spec).
- `SWIFT_STRICT_CONCURRENCY = complete` on any target (Phase 3).
- Enabling **`FAIL_ON_TEST_WARNINGS=true`** script gate (redundant with compiler enforcement).
- Rewriting ViewInspector-based view tests to use a different framework.
- Upstream ViewInspector contributions (issue [#404](https://github.com/nalexn/ViewInspector/issues/404) remains open).

## Decisions (brainstorming)

| Topic | Choice |
|-------|--------|
| Test enforcement | **Compiler gate** — `TREAT_WARNINGS_AS_ERRORS` on both test targets |
| ViewInspector Sendable | **Bump then shim (C)** — latest `0.10.x`, then `@retroactive` / `@unchecked Sendable` if needed |
| Script gate | **Keep report-only** — do not flip `FAIL_ON_TEST_WARNINGS` |
| Scope | All three targets warning-free; same hybrid CI flow as Phase 1 |

## Approaches considered

### Test-target enforcement

| Option | Description | Why not chosen |
|--------|-------------|----------------|
| **Compiler gate (chosen)** | `TREAT_WARNINGS_AS_ERRORS` on `MusicWallTests` + `MusicWallUITests` | — |
| Script gate | Set `FAIL_ON_TEST_WARNINGS=true` in `ci_tests` | Misses `other`-bucket warnings (macro expansions, module-qualified `MusicWall.Inspection.*` paths) |
| Both | Compiler + script gate | Redundant; added complexity with no benefit |

### ViewInspector Sendable

| Option | Description | Why not chosen |
|--------|-------------|----------------|
| **Bump then shim (chosen)** | Resolve latest `0.10.x`; shim only if warnings remain | — |
| Shim only | `@retroactive` / `@unchecked Sendable` without version check | Skips low-cost verification that upstream fixed the issue |
| Bump only | Pin newer ViewInspector and hope warnings disappear | [#404](https://github.com/nalexn/ViewInspector/issues/404) still open; Approach #2 warnings persist in Swift 5 |

## Architecture

### CI flow (unchanged wiring, stricter compile)

```
fastlane ci_tests
  │
  ├─ Scripts/check_core_imports.sh                    (existing)
  │
  ├─ xcodebuild test … 2>&1 | tee build/xcodebuild.log
  │     ├─ MusicWall:        TREAT_WARNINGS_AS_ERRORS = YES  (Phase 1)
  │     ├─ MusicWallTests:   TREAT_WARNINGS_AS_ERRORS = YES  (Phase 2)
  │     └─ MusicWallUITests: TREAT_WARNINGS_AS_ERRORS = YES  (Phase 2)
  │        → compile fails if any target introduces a warning
  │
  ├─ Scripts/check_coverage.sh <xcresult>              (existing)
  │
  └─ Scripts/check_warnings.sh build/xcodebuild.log
        └─ report-only (FAIL_ON_TEST_WARNINGS=false, default)
```

### Enforcement matrix (after Phase 2)

| Source | Mechanism | CI behavior |
|--------|-----------|-------------|
| `MusicWall/` warnings | Compiler (`TREAT_WARNINGS_AS_ERRORS`) | **Fail build** |
| `MusicWallTests/` warnings | Compiler (`TREAT_WARNINGS_AS_ERRORS`) | **Fail build** |
| `MusicWallUITests/` warnings | Compiler (`TREAT_WARNINGS_AS_ERRORS`) | **Fail build** |
| `appintentsmetadataprocessor` noise | Script allowlist | **Ignored** |
| Macro / module-qualified warnings | Compiler (not script buckets) | **Fail build** |

## Baseline inventory (verified 2026-06-08)

Seven unique warnings from `xcodebuild test -only-testing:MusicWallTests`:

| # | Origin | Warning | Fix |
|---|--------|---------|-----|
| 1–2 | `MusicWallTests/TestSupport/ViewInspector+MusicWall.swift` | Retroactive `Sendable` via `InspectionEmissary` | Bump ViewInspector; then shim (below) |
| 3–4 | `MusicWall.Inspection.*` (generated) | `Sendable` property violations on `Inspection` | Resolved by shim fix |
| 5 | `MusicWallTests/UI/SortMenuViewTests.swift:28` | Unnecessary `try` on `findAll` | Remove `try` |
| 6–7 | `AlbumEditViewTests` macro expansion | Unnecessary `try` inside `#expect(try …)` | Restructure assert to avoid `try` on non-throwing expression |

**Script classification gap (why compiler gate was chosen):** four warnings land in the `other` bucket because they lack a `/MusicWallTests/` path prefix. `FAIL_ON_TEST_WARNINGS=true` would only count the three `tests`-bucket warnings.

## Xcode changes

Add to **`MusicWallTests`** and **`MusicWallUITests`** build configurations (Debug + Release) in **`MusicWall.xcodeproj/project.pbxproj`**:

```
GCC_TREAT_WARNINGS_AS_ERRORS = YES;
SWIFT_TREAT_WARNINGS_AS_ERRORS = YES;
```

Do **not** set project-wide. App target settings from Phase 1 remain unchanged.

**Fastlane / workflow:** no changes to `fastlane/Fastfile` or `.github/workflows/ci-tests.yml`.

## ViewInspector strategy (C — bump then shim)

### Step 1 — Bump

- Current pin: **ViewInspector 0.10.3** (`Package.resolved`).
- Requirement: `upToNextMajorVersion` from `0.10.0`.
- Run `xcodebuild -resolvePackageDependencies` and rebuild to confirm no newer `0.10.x` resolves.
- Re-check warning count via `bundle exec fastlane ci_tests` or targeted `xcodebuild test -only-testing:MusicWallTests`.

### Step 2 — Shim fallback (expected)

Update `MusicWallTests/TestSupport/ViewInspector+MusicWall.swift`:

```swift
import ViewInspector
@testable import MusicWall

extension Inspection: @retroactive InspectionEmissary {}
```

If `MusicWall.Inspection.notice` / `callbacks` warnings persist:

```swift
extension Inspection: @unchecked Sendable {}
```

Add a brief comment: test-only retroactive conformance for ViewInspector's `PassthroughSubject`-backed `Inspection` helper ([ViewInspector #404](https://github.com/nalexn/ViewInspector/issues/404)).

### Step 3 — Unnecessary `try` fixes

| File | Change |
|------|--------|
| `SortMenuViewTests.swift:28` | `let images = label.findAll(ViewType.Image.self)` — remove `try` |
| `AlbumEditViewTests.swift` | Replace `#expect(try save.isDisabled())` with a non-throwing assert pattern (e.g. `let disabled = try save.isDisabled()` then `#expect(disabled)`) |

## Script — `check_warnings.sh`

No behavior change in Phase 2:

- **`FAIL_ON_TEST_WARNINGS`** remains default **`false`**.
- Script continues to print bucket summary for CI visibility.
- Compiler is the enforcement layer; script is supplementary.

## Documentation

| Path | Change |
|------|--------|
| `Agent.md` | Warnings policy: all targets compiler-enforced |
| `MusicWallTests/Agent.md` | Remove v1 report-only language; document ViewInspector shim; update local verification commands |
| `docs/specs/2026-06-08-swift-warnings-strategy-design.md` | Note Phase 2 spec link in future-phases table |
| `.github/pull_request_template.md` | Extend warnings checkbox to all targets |

## Error handling

- Test warning introduced after gate enabled: xcodebuild fails at compile time (same as app).
- ViewInspector shim insufficient: PR blocked until `@unchecked Sendable` added or alternative fix found.
- Missing build log: `check_warnings.sh` still exits **`2`** (unchanged).

## Implementation task order

1. Fix unnecessary-`try` warnings (`SortMenuViewTests`, `AlbumEditViewTests`).
2. Resolve/bump ViewInspector; rebuild and re-check warnings.
3. Apply ViewInspector shim if Sendable warnings remain.
4. Enable `TREAT_WARNINGS_AS_ERRORS` on `MusicWallTests` and `MusicWallUITests`.
5. Run `bundle exec fastlane ci_tests` (positive case).
6. Verify negative case — temporary test warning causes compile failure; revert.
7. Update documentation.

## Acceptance criteria

- [ ] `bundle exec fastlane ci_tests` passes with zero warnings in all `check_warnings.sh` buckets.
- [ ] `SWIFT_TREAT_WARNINGS_AS_ERRORS` set on `MusicWall`, `MusicWallTests`, and `MusicWallUITests` — not project-wide.
- [ ] ViewInspector at latest resolved `0.10.x`; shim applied only if bump alone does not clear Sendable warnings.
- [ ] Deliberate test-target warning causes compile failure (verified locally, then reverted).
- [ ] Docs updated; parent spec Phase 2 row links to this document.

## Human verification (PR description)

- Paste `check_warnings.sh` summary showing zero warnings in all buckets.
- Confirm `TREAT_WARNINGS_AS_ERRORS` on all three targets (spot-check `project.pbxproj`).
- Note ViewInspector version and whether shim was required.

## PR delivery

- Branch: `cursor/swift-warnings-phase2` (or team convention).
- PR title: `ci: warnings-as-errors on test targets (phase 2)`
- Link specs: this document + parent `docs/specs/2026-06-08-swift-warnings-strategy-design.md`

# Swift warnings strategy — hybrid CI gate

**Status:** Approved (2026-06-08)  
**Program:** MusicWall quality gates  
**Requires:** PR 14 coverage gate merged (pattern reference)  
**Approach:** Compiler warnings-as-errors on app target + `check_warnings.sh` report phase for test targets; clean app baseline; documented Swift 6 path

## Summary

Keep **`MusicWall`** app code warning-free via **`SWIFT_TREAT_WARNINGS_AS_ERRORS`** / **`GCC_TREAT_WARNINGS_AS_ERRORS`** on the app target only. Add **`Scripts/check_warnings.sh`** wired into **`fastlane ci_tests`** to classify build-log warnings, allowlist tooling noise, and **report** (not fail on) test-target warnings. Fix the existing ~2 app warnings before enabling the gate. Document a phased path toward test-target enforcement and Swift 6 concurrency.

## Goals

- CI **fails** when a PR introduces a compiler warning in **`MusicWall/`** app source.
- Fix existing app warnings (unused `try?`, Sendable conformance) as part of the same work.
- **Report** test-target warning counts in CI logs without blocking merges in v1.
- Establish documented follow-on phases for test warnings and Swift 6 readiness.

## Non-goals

- Flipping Swift 6 language mode.
- Fixing all ViewInspector / test-target Sendable warnings in v1.
- Upstream ViewInspector changes.
- Enforcing warnings on **`testflight-release`** or **`app-store-release`** lanes (they inherit app-target settings naturally when building `MusicWall`).

## Decisions (brainstorming)

| Topic | Choice |
|-------|--------|
| Primary driver | **Clean baseline + CI gate + Swift 6 path** |
| App enforcement | **`SWIFT_TREAT_WARNINGS_AS_ERRORS`** on **`MusicWall` target only** |
| Test enforcement (v1) | **Report only** via **`check_warnings.sh`** |
| Tooling noise | **Allowlist** `appintentsmetadataprocessor` in script |
| Log capture | **`tee`** xcodebuild output to **`build/xcodebuild.log`** |
| Baseline | **Fix app warnings before enabling gate** |

## Approaches considered

### Enforcement mechanism

| Option | Description | Why not chosen |
|--------|-------------|----------------|
| **Hybrid (chosen)** | Warnings-as-errors on app target + script reports test warnings | — |
| Script only, app paths | Parse log; fail on `MusicWall/` warnings | No local Xcode enforcement; fragile without compiler backup |
| Warnings-as-errors, all targets | Project-wide `TREAT_WARNINGS_AS_ERRORS` | Blocks immediately on ~5–8 ViewInspector test warnings |
| Phased report-only | Script fails nothing for one cycle | Delays app enforcement; doesn't match zero-tolerance goal |

### Test-target policy (v1)

| Option | Description | Why not chosen |
|--------|-------------|----------------|
| **Report only (chosen)** | Script prints test warning summary; `exit 0` | — |
| Fail on test warnings day one | Same gate as app | ViewInspector Sendable fixes are non-trivial / may need upstream |
| Ignore tests entirely | No script classification | Loses visibility into test backlog |

## Architecture

### CI flow

```
fastlane ci_tests
  │
  ├─ Scripts/check_core_imports.sh                    (existing)
  │
  ├─ xcodebuild test … 2>&1 | tee build/xcodebuild.log
  │     └─ MusicWall target: SWIFT_TREAT_WARNINGS_AS_ERRORS = YES
  │        GCC_TREAT_WARNINGS_AS_ERRORS = YES
  │        → compile fails if app introduces a warning
  │
  ├─ Scripts/check_coverage.sh <xcresult>              (existing)
  │
  └─ Scripts/check_warnings.sh build/xcodebuild.log
        ├─ Strip allowlisted appintentsmetadataprocessor lines
        ├─ Classify remaining warnings by path prefix
        ├─ Print summary table (app / tests / filtered)
        └─ exit 0 in v1 (FAIL_ON_TEST_WARNINGS=false, default)
```

### Enforcement matrix

| Source | Mechanism | CI behavior (v1) |
|--------|-----------|------------------|
| `MusicWall/` Swift/Clang warnings | Compiler (`TREAT_WARNINGS_AS_ERRORS`) | **Fail build** |
| `MusicWallTests/`, `MusicWallUITests/` warnings | `check_warnings.sh` | **Report only** |
| `appintentsmetadataprocessor` noise | Script allowlist | **Ignored** |

## Xcode changes

Add to **`MusicWall` app target** build configurations (Debug + Release) in **`MusicWall.xcodeproj/project.pbxproj`**:

```
SWIFT_TREAT_WARNINGS_AS_ERRORS = YES;
GCC_TREAT_WARNINGS_AS_ERRORS = YES;
```

Do **not** set on **`MusicWallTests`** or **`MusicWallUITests`**.

## Script — `Scripts/check_warnings.sh`

- **Args:** path to tee'd xcodebuild log (e.g. `build/xcodebuild.log`).
- **Env:**
  - **`FAIL_ON_TEST_WARNINGS`** — default **`false`**; set **`true`** in phase 2 to exit non-zero when test-bucket count > 0.
  - **`FAIL_CI`** — default **`true`** when `CI=true`; only consulted when **`FAIL_ON_TEST_WARNINGS=true`**.
- **Parsing:**
  - Match lines containing `warning:`.
  - Classify by path prefix: `MusicWall/`, `MusicWallTests/`, `MusicWallUITests/`.
  - Warnings without a repo path (tooling) go to **filtered** bucket unless allowlisted.
- **Allowlist regex:** `appintentsmetadataprocessor.*Metadata extraction skipped`
- **Output:** deduplicated lines per bucket + summary table.
- **Exit:** **`0`** in v1 after reporting. App warnings are already caught by the compiler; script is for visibility and future test gate.

### Fastlane — extend `ci_tests`

```ruby
lane :ci_tests do
  sh("../Scripts/check_core_imports.sh")
  result_bundle = "../build/MusicWallTestResults.xcresult"
  build_log = "../build/xcodebuild.log"
  sh("rm -rf #{result_bundle}")
  sh("mkdir -p ../build")
  sh(
    "set -o pipefail && xcodebuild test -project ../#{XCODEPROJ} -scheme #{SCHEME} " \
    "-destination 'platform=iOS Simulator,name=iPhone 17' " \
    "-enableCodeCoverage YES " \
    "-resultBundlePath #{result_bundle} 2>&1 | tee #{build_log}"
  )
  sh("../Scripts/check_coverage.sh #{result_bundle}")
  sh("../Scripts/check_warnings.sh #{build_log}")
end
```

Use **`set -o pipefail`** so xcodebuild failure propagates through the tee pipe.

### Workflow

No change to **`.github/workflows/ci-tests.yml`** — existing **`bundle exec fastlane ci_tests`** picks up the gate.

## Baseline fixes (app target)

Fix before or in the same PR as enabling **`TREAT_WARNINGS_AS_ERRORS`**:

| File | Warning | Fix direction |
|------|---------|---------------|
| `MusicWall/Adapters/CarPlay/CarPlayCoordinator.swift:109` | Result of `try?` is unused | Assign to `_` or handle error explicitly |
| `MusicWall/Adapters/LiveAlbumBackupService.swift:5` | `Sendable` struct with non-Sendable `FileExportService` | Prefer making `FileExportService` `Sendable` if safe; otherwise `@unchecked Sendable` with brief comment |

## Test backlog (report only in v1)

Known warnings to appear in CI report output (~5–8):

| Area | Examples |
|------|----------|
| ViewInspector shim | `MusicWallTests/TestSupport/ViewInspector+MusicWall.swift` — retroactive `Sendable` on `Inspection` |
| ViewInspector tests | `SortMenuViewTests.swift`, `AlbumEditViewTests.swift` — unnecessary `try` |
| ViewInspector package | Generated `Inspection` Sendable / mutable-property warnings |

## Future phases (documented, out of v1 scope)

| Phase | Action |
|-------|--------|
| 2 | **Done** — test-target warnings fixed; `TREAT_WARNINGS_AS_ERRORS` on test targets. See `docs/specs/2026-06-08-swift-warnings-phase2-design.md` |
| 3 | **Done** — strict concurrency on app target. See `docs/specs/2026-06-08-swift-warnings-phase3-design.md` |
| 4 | **Done** — Swift 6 language mode on all targets. See `docs/specs/2026-06-08-swift-warnings-phase4-design.md` |

## Documentation

| Path | Change |
|------|--------|
| `Agent.md` | Add **Warnings policy** section: app zero-tolerance (compiler), tests reported |
| `MusicWallTests/Agent.md` | Commands for local `check_warnings.sh`; note test backlog policy |
| `.github/pull_request_template.md` | Checkbox: no new app warnings (CI enforces via compiler) |

## Error handling

- Missing log file: script prints clear stderr message; exit **`2`**.
- App warning introduced: xcodebuild fails at compile time before coverage/warnings scripts run.
- Test warnings: printed in summary; CI passes in v1.

## Implementation task order

1. **Fix app baseline** — `CarPlayCoordinator.swift`, `LiveAlbumBackupService.swift` / `FileExportService.swift`.
2. **Enable warnings-as-errors** — `MusicWall` target only in `project.pbxproj`.
3. **Add `check_warnings.sh`** — parsing, allowlist, summary output.
4. **Wire Fastlane** — `tee` log + script invocation with `pipefail`.
5. **Update docs** — `Agent.md`, `MusicWallTests/Agent.md`, PR template.
6. **Verify locally** — `bundle exec fastlane ci_tests` passes; test warnings appear in report.
7. **Verify negative case** — temporary app warning causes compile failure (revert before merge).

## Acceptance criteria

- [ ] `bundle exec fastlane ci_tests` passes with zero app warnings.
- [ ] Deliberate app warning causes compile failure (verified, then reverted).
- [ ] `check_warnings.sh` reports test-target warning count; exits 0 in v1.
- [ ] `appintentsmetadataprocessor` lines excluded from actionable counts.
- [ ] `SWIFT_TREAT_WARNINGS_AS_ERRORS` set on `MusicWall` only, not test targets.
- [ ] Docs updated in `Agent.md` and `MusicWallTests/Agent.md`.

## Human verification (PR description)

- Paste `check_warnings.sh` summary from CI log (test bucket count).
- Confirm no app-bucket warnings in report (compiler already enforces).
- Spot-check Release configuration builds clean for app target.

## PR delivery

- Branch: `cursor/swift-warnings-strategy` (or team convention).
- PR title: `ci: hybrid Swift warnings gate (app zero-tolerance + test report)`
- Link spec: `docs/specs/2026-06-08-swift-warnings-strategy-design.md`

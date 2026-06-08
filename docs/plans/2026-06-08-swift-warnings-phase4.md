# Swift Warnings Phase 4 — Swift 6 Language Mode Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enable Swift 6 language mode (`SWIFT_VERSION = 6.0`) on all three targets, with a single `@MainActor` annotation on the UI-test class to clear the only blocker.

**Architecture:** The app target (Phase 3 strict-concurrency clean) and the unit-test target already compile under Swift 6. The only diagnostics are 104 main-actor isolation errors in `MusicWallUITests`, all resolved by isolating the test class to `@MainActor`. ViewInspector is unaffected — SwiftPM compiles it in its own Swift 5 language mode. Enforcement reuses the existing `SWIFT_TREAT_WARNINGS_AS_ERRORS` gate; no CI/script changes.

**Tech Stack:** Xcode 26, Swift 6, XCTest UI testing, Fastlane (`ci_tests`), `xcodebuild`.

**Spec:** `docs/specs/2026-06-08-swift-warnings-phase4-design.md`
**Parent spec:** `docs/specs/2026-06-08-swift-warnings-strategy-design.md`

---

## File Structure

| File | Responsibility | Change |
|------|----------------|--------|
| `MusicWallUITests/MusicWallUITests.swift` | UI test suite | Add `@MainActor` to the class declaration |
| `MusicWall.xcodeproj/project.pbxproj` | Build settings | `SWIFT_VERSION = 5.0` → `6.0` on all 6 target configs |
| `Agent.md` | Repo agent guide | Warnings policy: Swift 6 language mode on all targets |
| `docs/specs/2026-06-08-swift-warnings-strategy-design.md` | Parent program spec | Phase 4 row → Done + link |

**Notes for the engineer (zero-context assumptions):**
- This repo only builds on macOS with Xcode; CI is the source of truth. Use the iPhone 17 simulator destination (matches `fastlane/Fastfile`).
- "Warnings-as-errors" is already on for every target, so any Swift 6 diagnostic fails the build. Do **not** add new build flags.
- Do **not** touch ViewInspector, `Scripts/check_warnings.sh`, `fastlane/Fastfile`, or `.github/workflows/`.
- The `MusicWall/` group is filesystem-synchronized; no `project.pbxproj` membership edits are needed for source changes.

---

## Task 1: Capture and confirm the Swift 6 baseline

**Files:**
- Read-only: `MusicWall.xcodeproj/project.pbxproj`, `MusicWallUITests/MusicWallUITests.swift`

- [ ] **Step 1: Confirm the six target-level `SWIFT_VERSION` entries**

Run:
```bash
cd /Users/chris/.cursor/worktrees/MusicWall/3gg4
grep -n "SWIFT_VERSION = 5.0;" MusicWall.xcodeproj/project.pbxproj
```
Expected: exactly 6 lines (app Debug/Release, MusicWallTests Debug/Release, MusicWallUITests Debug/Release). The project-level configuration sets no `SWIFT_VERSION`.

- [ ] **Step 2: Probe the Swift 6 baseline (warnings-as-errors ON, the real CI gate)**

This temporarily flips all six configs to 6.0, builds, and captures diagnostics. It will fail (expected) — Task 2 adds the fix.

Run:
```bash
cd /Users/chris/.cursor/worktrees/MusicWall/3gg4
mkdir -p build
sed -i '' 's/SWIFT_VERSION = 5.0;/SWIFT_VERSION = 6.0;/g' MusicWall.xcodeproj/project.pbxproj
set -o pipefail
xcodebuild test -project MusicWall.xcodeproj -scheme MusicWall \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  2>&1 | tee build/phase4-baseline.log | tail -5 || true
```

- [ ] **Step 3: Confirm only `MusicWallUITests` errors, all main-actor isolation**

Run:
```bash
cd /Users/chris/.cursor/worktrees/MusicWall/3gg4
echo "UITest errors:"; grep "error:" build/phase4-baseline.log | grep -c "MusicWallUITests/" || true
echo "App errors:"; grep "error:" build/phase4-baseline.log | grep -E "/MusicWall/[A-Z]" | grep -vc Tests || true
echo "Unit-test errors:"; grep "error:" build/phase4-baseline.log | grep -c "MusicWallTests/" || true
echo "ViewInspector errors:"; grep "error:" build/phase4-baseline.log | grep -ci ViewInspector || true
```
Expected: UITest errors > 0 (≈104, all "main actor-isolated"); app, unit-test, and ViewInspector errors all `0`.

- [ ] **Step 4: Revert the probe (Task 2 reapplies the setting properly, after the fix)**

Run:
```bash
cd /Users/chris/.cursor/worktrees/MusicWall/3gg4
git checkout MusicWall.xcodeproj/project.pbxproj
grep -c "SWIFT_VERSION = 5.0;" MusicWall.xcodeproj/project.pbxproj
```
Expected: `6` (clean working tree for `project.pbxproj`).

---

## Task 2: Isolate the UI-test class to `@MainActor`

**Files:**
- Modify: `MusicWallUITests/MusicWallUITests.swift:1-3`

- [ ] **Step 1: Add `@MainActor` to the test class**

Change the top of `MusicWallUITests/MusicWallUITests.swift` from:
```swift
import XCTest

final class MusicWallUITests: XCTestCase {
```
to:
```swift
import XCTest

@MainActor
final class MusicWallUITests: XCTestCase {
```
No other edits in this file. All private helpers (`launchApp`, `assertFixtureAlbumsVisible`, `waitUntilHittable`, `waitForLastPlayedAlbumID`) inherit main-actor isolation from the class, matching their existing `XCUIElement` usage.

- [ ] **Step 2: Verify the UI-test target compiles under Swift 6 in isolation**

Temporarily enable Swift 6 just to compile-check the fix (reverted in this step).

Run:
```bash
cd /Users/chris/.cursor/worktrees/MusicWall/3gg4
sed -i '' 's/SWIFT_VERSION = 5.0;/SWIFT_VERSION = 6.0;/g' MusicWall.xcodeproj/project.pbxproj
set -o pipefail
xcodebuild build-for-testing -project MusicWall.xcodeproj -scheme MusicWall \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  2>&1 | tee build/phase4-fix-check.log | tail -5
echo "remaining UITest errors:"; grep "error:" build/phase4-fix-check.log | grep -c "MusicWallUITests/" || true
git checkout MusicWall.xcodeproj/project.pbxproj
```
Expected: `** BUILD SUCCEEDED **`; remaining UITest errors `0`. (`project.pbxproj` reverted; only the `.swift` change remains.)

- [ ] **Step 3: Commit the UI-test fix**

```bash
cd /Users/chris/.cursor/worktrees/MusicWall/3gg4
git add MusicWallUITests/MusicWallUITests.swift
git commit -m "test(ui): isolate MusicWallUITests to @MainActor for Swift 6"
```

---

## Task 3: Enable Swift 6 language mode on all targets

**Files:**
- Modify: `MusicWall.xcodeproj/project.pbxproj` (6 occurrences)

- [ ] **Step 1: Flip all six target configs to Swift 6**

Run:
```bash
cd /Users/chris/.cursor/worktrees/MusicWall/3gg4
sed -i '' 's/SWIFT_VERSION = 5.0;/SWIFT_VERSION = 6.0;/g' MusicWall.xcodeproj/project.pbxproj
grep -c "SWIFT_VERSION = 6.0;" MusicWall.xcodeproj/project.pbxproj
grep -c "SWIFT_VERSION = 5.0;" MusicWall.xcodeproj/project.pbxproj
```
Expected: `6` then `0`.

- [ ] **Step 2: Commit the build-setting change**

```bash
cd /Users/chris/.cursor/worktrees/MusicWall/3gg4
git add MusicWall.xcodeproj/project.pbxproj
git commit -m "ci: enable Swift 6 language mode on all targets (phase 4)"
```

---

## Task 4: Verify positive and negative gates

**Files:**
- Read-only build verification; one temporary edit reverted within the task.

- [ ] **Step 1: Positive — full test run is green under Swift 6**

Run:
```bash
cd /Users/chris/.cursor/worktrees/MusicWall/3gg4
set -o pipefail
xcodebuild test -project MusicWall.xcodeproj -scheme MusicWall \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  2>&1 | tee build/phase4-positive.log | tail -8
echo "our-target diagnostics:"; grep -E "warning:|error:" build/phase4-positive.log | grep -v appintents | grep -E "MusicWall/|MusicWallTests/|MusicWallUITests/|ViewInspector" | sort -u || echo "NONE"
```
Expected: `** TEST SUCCEEDED **`, 5 UI tests + unit tests pass, `NONE` for our-target diagnostics.

- [ ] **Step 2: Optional — run the full Fastlane gate**

Run:
```bash
cd /Users/chris/.cursor/worktrees/MusicWall/3gg4
bundle exec fastlane ci_tests
```
Expected: lane passes; `check_warnings.sh` summary shows zero warnings in all buckets.

- [ ] **Step 3: Negative — a deliberate Swift 6 violation fails the build**

Add a data-race violation to app source. Append to the end of `MusicWall/ImageCache.swift`:
```swift
@MainActor final class _Phase4NegativeProbe {
    var counter = 0
    nonisolated func bump() {
        counter += 1
    }
}
```

- [ ] **Step 4: Confirm the build fails**

Run:
```bash
cd /Users/chris/.cursor/worktrees/MusicWall/3gg4
set -o pipefail
xcodebuild build -project MusicWall.xcodeproj -scheme MusicWall \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  2>&1 | tee build/phase4-negative.log | tail -5 || true
grep -E "error:" build/phase4-negative.log | grep -i "ImageCache.swift" | head -3
```
Expected: build fails (non-zero) with a main-actor isolation error referencing `ImageCache.swift` (e.g. "main actor-isolated property 'counter' can not be referenced from a nonisolated context").

- [ ] **Step 5: Revert the negative probe**

Run:
```bash
cd /Users/chris/.cursor/worktrees/MusicWall/3gg4
git checkout MusicWall/ImageCache.swift
git status -s MusicWall/ImageCache.swift
```
Expected: no output (clean). Do **not** commit the probe.

---

## Task 5: Update documentation

**Files:**
- Modify: `Agent.md` (Warnings policy section)
- Modify: `docs/specs/2026-06-08-swift-warnings-strategy-design.md` (Phase 4 row)

- [ ] **Step 1: Update the `Agent.md` warnings policy**

In `Agent.md`, find the Warnings policy bullet list. Replace the future/phase lines:
```markdown
- **Future:** phase 4 assesses Swift 6 language mode.
- **Specs:** Phase 1 — `docs/specs/2026-06-08-swift-warnings-strategy-design.md`; Phase 2 — `docs/specs/2026-06-08-swift-warnings-phase2-design.md`; Phase 3 — `docs/specs/2026-06-08-swift-warnings-phase3-design.md`.
```
with:
```markdown
- **Swift 6 language mode:** `SWIFT_VERSION = 6.0` on all targets (app + both test targets) — Phase 4. UI tests run main-actor isolated (`@MainActor` on the `MusicWallUITests` class).
- **Specs:** Phase 1 — `docs/specs/2026-06-08-swift-warnings-strategy-design.md`; Phase 2 — `docs/specs/2026-06-08-swift-warnings-phase2-design.md`; Phase 3 — `docs/specs/2026-06-08-swift-warnings-phase3-design.md`; Phase 4 — `docs/specs/2026-06-08-swift-warnings-phase4-design.md`.
```

- [ ] **Step 2: Mark the parent spec Phase 4 row Done**

In `docs/specs/2026-06-08-swift-warnings-strategy-design.md`, in the "Future phases" table, change:
```markdown
| 4 | Swift 6 language mode assessment |
```
to:
```markdown
| 4 | **Done** — Swift 6 language mode on all targets. See `docs/specs/2026-06-08-swift-warnings-phase4-design.md` |
```

- [ ] **Step 3: Commit the documentation updates**

```bash
cd /Users/chris/.cursor/worktrees/MusicWall/3gg4
git add Agent.md docs/specs/2026-06-08-swift-warnings-strategy-design.md
git commit -m "docs: record Swift 6 language mode gate (phase 4)"
```

---

## Task 6: Push and open the PR

**Files:** none (git/gh operations)

- [ ] **Step 1: Push the branch**

```bash
cd /Users/chris/.cursor/worktrees/MusicWall/3gg4
git push -u origin cursor/swift-warnings-phase4
```

- [ ] **Step 2: Open the PR**

```bash
cd /Users/chris/.cursor/worktrees/MusicWall/3gg4
gh pr create --title "ci: Swift 6 language mode on all targets (phase 4)" --body "$(cat <<'EOF'
## Summary
- Enables Swift 6 language mode (`SWIFT_VERSION = 6.0`) on all three targets, completing the Swift warnings strategy program (Phases 1–4).
- Isolates `MusicWallUITests` to `@MainActor` (the only blocker: 104 main-actor isolation diagnostics on `XCUIElement` APIs). App and unit-test targets were already clean.
- ViewInspector unchanged — SwiftPM compiles it in its own Swift 5 language mode, so it is unaffected.

## Verification
- Positive: `xcodebuild test` under per-target Swift 6 with warnings-as-errors ON → TEST SUCCEEDED, zero diagnostics in all buckets, all tests pass.
- Negative: deliberate main-actor violation in app source → compile failure → reverted.

Specs: `docs/specs/2026-06-08-swift-warnings-phase4-design.md`, `docs/specs/2026-06-08-swift-warnings-strategy-design.md`

## Test plan
- [ ] CI `ci-tests` passes
- [ ] Confirm `SWIFT_VERSION = 6.0` on all six target configs in `project.pbxproj`
- [ ] Confirm `@MainActor` on `MusicWallUITests` class
EOF
)"
```
Expected: PR URL returned.

---

## Self-Review (completed during plan authoring)

- **Spec coverage:** UI-test fix (Task 2), all-target enable (Task 3), positive+negative verify (Task 4), docs incl. parent row (Task 5) — every spec acceptance criterion maps to a task. ViewInspector "no change" is honored by omission (no task touches it).
- **Placeholder scan:** No TBDs; every code/command step is concrete.
- **Type consistency:** Single symbol introduced is the temporary `_Phase4NegativeProbe` (Task 4), created and reverted within the same task; not referenced elsewhere.

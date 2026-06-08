# Swift Warnings Phase 2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enforce zero compiler warnings on `MusicWallTests` and `MusicWallUITests` via warnings-as-errors, after clearing the seven-warning baseline (ViewInspector Sendable + unnecessary `try`).

**Architecture:** Fix baseline warnings first, then add `SWIFT_TREAT_WARNINGS_AS_ERRORS` / `GCC_TREAT_WARNINGS_AS_ERRORS` to both test targets in `project.pbxproj`. ViewInspector strategy C: resolve latest `0.10.x`, then apply `@retroactive InspectionEmissary` shim (and `@unchecked Sendable` if needed). `check_warnings.sh` stays report-only.

**Tech Stack:** Swift 5, Xcode 26+, ViewInspector 0.10.x (SPM), Bash + Python 3, Fastlane, iPhone 17 simulator.

**Spec:** `docs/specs/2026-06-08-swift-warnings-phase2-design.md`

**Branch:** `cursor/swift-warnings-phase2` (from `main`; design spec already committed)

---

## File map

| Action | Path | Notes |
|--------|------|-------|
| Modify | `MusicWallTests/UI/SortMenuViewTests.swift` | Remove unnecessary `try` |
| Modify | `MusicWallTests/UI/AlbumEditViewTests.swift` | Fix `#expect(try …)` macro warnings |
| Modify | `MusicWall.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved` | May update after package resolve |
| Modify | `MusicWallTests/TestSupport/ViewInspector+MusicWall.swift` | `@retroactive` / `@unchecked Sendable` shim |
| Modify | `MusicWall.xcodeproj/project.pbxproj` | Warnings-as-errors on test targets |
| Modify | `Agent.md` | Warnings policy — all targets |
| Modify | `MusicWallTests/Agent.md` | Warnings policy + ViewInspector shim note |
| Modify | `docs/specs/2026-06-08-swift-warnings-strategy-design.md` | Link Phase 2 spec in future-phases table |
| Modify | `.github/pull_request_template.md` | Warnings checkbox covers all targets |

No changes: `Scripts/check_warnings.sh`, `fastlane/Fastfile`, `.github/workflows/ci-tests.yml`.

---

### Task 0: Branch setup

**Files:** (none)

- [ ] **Step 1: Confirm branch and base**

```bash
git checkout cursor/swift-warnings-phase2
git log --oneline -1
```

Expected: latest commit is `docs: add Swift warnings phase 2 design spec` (or later). Branch is based on `main` with Phase 1 merged.

- [ ] **Step 2: Capture baseline warning count**

```bash
mkdir -p build
xcodebuild test -project MusicWall.xcodeproj -scheme MusicWall \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:MusicWallTests 2>&1 | tee build/xcodebuild-baseline.log
Scripts/check_warnings.sh build/xcodebuild-baseline.log
```

Expected: `tests: 3`, `other: 4`, `app: 0` (seven unique warnings total).

---

### Task 1: Fix unnecessary `try` warnings

**Files:**
- Modify: `MusicWallTests/UI/SortMenuViewTests.swift:26-30`
- Modify: `MusicWallTests/UI/AlbumEditViewTests.swift:12-30`

- [ ] **Step 1: Fix SortMenuViewTests**

Replace `directionArrowName` — `findAll` is non-throwing:

```swift
    @MainActor
    private func directionArrowName(in button: InspectableView<ViewType.Button>) throws -> String? {
        let label = try button.labelView()
        let images = label.findAll(ViewType.Image.self)
        guard let image = images.first else { return nil }
        return try image.actualImage().name()
    }
```

- [ ] **Step 2: Fix AlbumEditViewTests**

Extract `isDisabled()` before `#expect` so the macro does not wrap a non-throwing `try`:

```swift
    @Test @MainActor
    func saveDisabled_whenTitleWhitespaceOnly() async throws {
        let album = AlbumFixtures.record(id: "a", title: "   ", artistName: "A")
        let view = AlbumEditView(album: album, onSave: { _ in })

        try await ViewHosting.host(view) {
            try await view.inspection.inspect { inspected in
                let save = try inspected.find(button: "Save")
                let disabled = save.isDisabled()
                #expect(disabled)
            }
        }
    }

    @Test @MainActor
    func saveEnabled_whenTitleValid() async throws {
        let album = AlbumFixtures.record(id: "a", title: "Abbey Road", artistName: "The Beatles")
        let view = AlbumEditView(album: album, onSave: { _ in })

        try await ViewHosting.host(view) {
            try await view.inspection.inspect { inspected in
                let save = try inspected.find(button: "Save")
                let disabled = save.isDisabled()
                #expect(disabled == false)
            }
        }
    }
```

- [ ] **Step 3: Rebuild and verify `try` warnings gone**

```bash
xcodebuild test -project MusicWall.xcodeproj -scheme MusicWall \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:MusicWallTests 2>&1 | tee build/xcodebuild-after-try.log
Scripts/check_warnings.sh build/xcodebuild-after-try.log
```

Expected: `tests` bucket drops from 3 to 2 (Sendable warnings only); `other` drops from 4 to 2 (macro `try` warnings gone).

- [ ] **Step 4: Commit**

```bash
git add MusicWallTests/UI/SortMenuViewTests.swift MusicWallTests/UI/AlbumEditViewTests.swift
git commit -m "fix(tests): remove unnecessary try in ViewInspector view tests"
```

---

### Task 2: Resolve ViewInspector package

**Files:**
- May modify: `MusicWall.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`

- [ ] **Step 1: Resolve latest 0.10.x**

```bash
xcodebuild -resolvePackageDependencies \
  -project MusicWall.xcodeproj \
  -scheme MusicWall
cat MusicWall.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved
```

Expected: ViewInspector version `0.10.3` or newer within `0.10.x`. Record the resolved version for the PR description.

- [ ] **Step 2: Rebuild and check Sendable warnings**

```bash
xcodebuild test -project MusicWall.xcodeproj -scheme MusicWall \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:MusicWallTests 2>&1 | tee build/xcodebuild-after-bump.log
Scripts/check_warnings.sh build/xcodebuild-after-bump.log
```

Expected: Sendable warnings likely still present (ViewInspector #404). If all warnings are zero, skip Task 3 and go to Task 4.

- [ ] **Step 3: Commit if Package.resolved changed**

```bash
git add MusicWall.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved
git commit -m "chore: resolve ViewInspector to latest 0.10.x"
```

Skip this commit if `Package.resolved` is unchanged.

---

### Task 3: ViewInspector Sendable shim

**Files:**
- Modify: `MusicWallTests/TestSupport/ViewInspector+MusicWall.swift`

- [ ] **Step 1: Apply `@retroactive` shim**

```swift
import ViewInspector
@testable import MusicWall

extension Inspection: @retroactive InspectionEmissary {}
```

- [ ] **Step 2: Rebuild and check remaining warnings**

```bash
xcodebuild test -project MusicWall.xcodeproj -scheme MusicWall \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:MusicWallTests 2>&1 | tee build/xcodebuild-after-retroactive.log
Scripts/check_warnings.sh build/xcodebuild-after-retroactive.log
```

Expected: retroactive-conformance warnings silenced. If `MusicWall.Inspection.notice` / `callbacks` warnings remain in `other` bucket, proceed to Step 3. If all buckets are zero, skip Step 3.

- [ ] **Step 3: Add `@unchecked Sendable` if needed**

```swift
import ViewInspector
@testable import MusicWall

// Test-only shim for ViewInspector Approach #2 (https://github.com/nalexn/ViewInspector/issues/404).
extension Inspection: @retroactive InspectionEmissary {}
extension Inspection: @unchecked Sendable {}
```

- [ ] **Step 4: Rebuild and confirm zero warnings**

```bash
xcodebuild test -project MusicWall.xcodeproj -scheme MusicWall \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:MusicWallTests 2>&1 | tee build/xcodebuild-after-shim.log
Scripts/check_warnings.sh build/xcodebuild-after-shim.log
```

Expected: all buckets `0` except `filtered` (appintentsmetadataprocessor allowlisted).

- [ ] **Step 5: Commit**

```bash
git add MusicWallTests/TestSupport/ViewInspector+MusicWall.swift
git commit -m "fix(tests): ViewInspector Sendable shim for InspectionEmissary"
```

---

### Task 4: Enable warnings-as-errors on test targets

**Files:**
- Modify: `MusicWall.xcodeproj/project.pbxproj`

Add to **four** build configurations (`MusicWallTests` Debug/Release, `MusicWallUITests` Debug/Release), immediately before `SWIFT_VERSION = 5.0;`:

```
GCC_TREAT_WARNINGS_AS_ERRORS = YES;
SWIFT_TREAT_WARNINGS_AS_ERRORS = YES;
```

Target build configuration IDs:

| Target | Config | ID (search key) |
|--------|--------|-------------------|
| MusicWallTests | Debug | `F0ADCAC359BEAA58B300DC90` |
| MusicWallTests | Release | `944A84916DE51D0580A90ADF` |
| MusicWallUITests | Debug | `C0DE00112233445566779902` |
| MusicWallUITests | Release | `C0DE00112233445566779903` |

Example for MusicWallTests Debug:

```text
				PRODUCT_BUNDLE_IDENTIFIER = chris.MusicWallTests;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SDKROOT = iphoneos;
				GCC_TREAT_WARNINGS_AS_ERRORS = YES;
				SWIFT_TREAT_WARNINGS_AS_ERRORS = YES;
				SWIFT_VERSION = 5.0;
```

- [ ] **Step 1: Add settings to all four configurations**

- [ ] **Step 2: Verify settings present**

```bash
grep -A2 'SWIFT_TREAT_WARNINGS_AS_ERRORS' MusicWall.xcodeproj/project.pbxproj
```

Expected: six occurrences total — two for `MusicWall` app (Phase 1), four for test targets (Phase 2). No project-level entry.

- [ ] **Step 3: Commit**

```bash
git add MusicWall.xcodeproj/project.pbxproj
git commit -m "ci: enable warnings-as-errors on MusicWallTests and MusicWallUITests"
```

---

### Task 5: Verify locally (positive + negative)

**Files:**
- Temporarily modify: `MusicWallTests/SmokeTests.swift` (negative case only — revert before commit)

- [ ] **Step 1: Full CI lane — positive case**

```bash
bundle exec fastlane ci_tests
```

Expected: PASS. At end of log, `check_warnings.sh` summary shows `app: 0`, `tests: 0`, `ui_tests: 0`, `other: 0`.

- [ ] **Step 2: Negative case — deliberate test warning**

Add a temporary unused variable to `MusicWallTests/SmokeTests.swift`:

```swift
@Test func smoke_unusedWarningProbe() {
    let _unusedProbe = 0
}
```

Run:

```bash
xcodebuild test -project MusicWall.xcodeproj -scheme MusicWall \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:MusicWallTests/SmokeTests 2>&1 | tail -15
```

Expected: `** TEST FAILED **` or `** BUILD FAILED **` with "warnings being treated as errors" or unused variable error.

- [ ] **Step 3: Revert the deliberate warning**

Remove the temporary test. Do not commit the smoke-test change.

- [ ] **Step 4: Final full CI run**

```bash
bundle exec fastlane ci_tests
```

Expected: PASS with all warning buckets at zero.

---

### Task 6: Update documentation

**Files:**
- Modify: `Agent.md:139-144`
- Modify: `MusicWallTests/Agent.md:73-77` and `200-207`
- Modify: `docs/specs/2026-06-08-swift-warnings-strategy-design.md:159-163`
- Modify: `.github/pull_request_template.md:17`

- [ ] **Step 1: Update `Agent.md` warnings policy**

Replace the Warnings policy subsection with:

```markdown
### Warnings policy

- **All targets (`MusicWall/`, `MusicWallTests/`, `MusicWallUITests/`):** zero compiler warnings — `SWIFT_TREAT_WARNINGS_AS_ERRORS` and `GCC_TREAT_WARNINGS_AS_ERRORS` are enabled on the app and both test targets. CI fails at compile time if a PR introduces a warning in any target.
- **Tooling noise:** `appintentsmetadataprocessor` "Metadata extraction skipped" lines are allowlisted in `Scripts/check_warnings.sh` (report-only).
- **Future:** phase 3 evaluates `SWIFT_STRICT_CONCURRENCY` on the app target; phase 4 assesses Swift 6 language mode.
- **Specs:** Phase 1 — `docs/specs/2026-06-08-swift-warnings-strategy-design.md`; Phase 2 — `docs/specs/2026-06-08-swift-warnings-phase2-design.md`.
```

- [ ] **Step 2: Update `MusicWallTests/Agent.md`**

Remove the `FAIL_ON_TEST_WARNINGS` simulation block (lines 73–77). Replace the Warnings policy table (lines 200–207) with:

```markdown
## Warnings policy

| Target | CI behavior |
|--------|-------------|
| `MusicWall/` app source | Compile fails on any warning |
| `MusicWallTests/`, `MusicWallUITests/` | Compile fails on any warning |

ViewInspector `InspectionEmissary` shim lives in `TestSupport/ViewInspector+MusicWall.swift` (`@retroactive`, `@unchecked Sendable` if needed). `Scripts/check_warnings.sh` still prints a bucket summary in CI logs but enforcement is compiler-first.
```

- [ ] **Step 3: Update parent spec future-phases table**

In `docs/specs/2026-06-08-swift-warnings-strategy-design.md`, replace the Phase 2 row:

```markdown
| 2 | **Done** — test-target warnings fixed; `TREAT_WARNINGS_AS_ERRORS` on test targets. See `docs/specs/2026-06-08-swift-warnings-phase2-design.md` |
```

- [ ] **Step 4: Update PR template**

Change line 17 in `.github/pull_request_template.md`:

```markdown
- [ ] No new compiler warnings in any target (CI enforces via warnings-as-errors on `MusicWall`, `MusicWallTests`, `MusicWallUITests`)
```

- [ ] **Step 5: Commit**

```bash
git add Agent.md MusicWallTests/Agent.md \
  docs/specs/2026-06-08-swift-warnings-strategy-design.md \
  .github/pull_request_template.md
git commit -m "docs: update warnings policy for phase 2 test-target gate"
```

---

## Acceptance checklist

- [ ] `bundle exec fastlane ci_tests` passes with zero warnings in all `check_warnings.sh` buckets.
- [ ] `SWIFT_TREAT_WARNINGS_AS_ERRORS` on `MusicWall`, `MusicWallTests`, and `MusicWallUITests` — not project-wide.
- [ ] ViewInspector at latest resolved `0.10.x`; shim applied only if bump alone did not clear Sendable warnings.
- [ ] Deliberate test-target warning causes compile failure (verified, reverted).
- [ ] Docs updated; parent spec Phase 2 row links to phase 2 spec.

## PR delivery

- **Title:** `ci: warnings-as-errors on test targets (phase 2)`
- **Body:** Link `docs/specs/2026-06-08-swift-warnings-phase2-design.md` and parent spec; paste `check_warnings.sh` summary (all buckets zero); note ViewInspector version and whether shim was required; confirm negative-case verification done locally.
- **Human verification:** Confirm `project.pbxproj` has `TREAT_WARNINGS_AS_ERRORS` on all three targets.

## Follow-on (out of scope)

| Phase | Action |
|-------|--------|
| 3 | Evaluate `SWIFT_STRICT_CONCURRENCY = complete` on app target |
| 4 | Swift 6 language mode assessment |

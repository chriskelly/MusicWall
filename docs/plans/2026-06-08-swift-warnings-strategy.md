# Swift Warnings Strategy Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enforce zero app-target compiler warnings in CI via warnings-as-errors, report test-target warnings without failing, and fix the existing app baseline.

**Architecture:** `SWIFT_TREAT_WARNINGS_AS_ERRORS` / `GCC_TREAT_WARNINGS_AS_ERRORS` on the `MusicWall` app target only; `fastlane ci_tests` tees xcodebuild output to `build/xcodebuild.log`; `Scripts/check_warnings.sh` classifies warnings into app / tests / filtered buckets. App warnings fail at compile time; test warnings are reported only in v1.

**Tech Stack:** Swift 5, Xcode 26+, Bash + Python 3 stdlib, Fastlane, GitHub Actions (`macos-26`), simulator `iPhone 17`.

**Spec:** `docs/specs/2026-06-08-swift-warnings-strategy-design.md`

**Branch:** `cursor/swift-warnings-strategy` (from `main`)

---

## File map

| Action | Path | Notes |
|--------|------|-------|
| Modify | `MusicWall/Adapters/CarPlay/CarPlayCoordinator.swift` | Fix unused `try?` |
| Modify | `MusicWall/Adapters/FileExportService.swift` | Add `Sendable` conformance |
| Modify | `MusicWall.xcodeproj/project.pbxproj` | Warnings-as-errors on app target only |
| Create | `Scripts/check_warnings.sh` | Log parser + report |
| Modify | `fastlane/Fastfile` | `tee` log + script invocation |
| Modify | `Agent.md` | Warnings policy section |
| Modify | `MusicWallTests/Agent.md` | Local warnings script commands |
| Modify | `.github/pull_request_template.md` | App warnings checkbox |

---

### Task 0: Branch setup

**Files:** (none)

- [ ] **Step 1: Create branch from main**

```bash
git checkout main
git pull origin main
git checkout -b cursor/swift-warnings-strategy
```

---

### Task 1: Fix app baseline warnings

**Files:**
- Modify: `MusicWall/Adapters/CarPlay/CarPlayCoordinator.swift:108-110`
- Modify: `MusicWall/Adapters/FileExportService.swift:3`

- [ ] **Step 1: Fix unused `try?` in CarPlayCoordinator**

In `setRootTemplate`, assign the result to `_`:

```swift
private func setRootTemplate(_ template: CPTemplate) async {
    _ = try? await interfaceController.setRootTemplate(template, animated: true)
}
```

- [ ] **Step 2: Make FileExportService Sendable**

`FileManager` is `Sendable`; the struct has no mutable state across calls:

```swift
struct FileExportService: Sendable {
    private let fileManager: FileManager
    // ... rest unchanged
}
```

- [ ] **Step 3: Verify app build is warning-free (before enabling gate)**

```bash
xcodebuild build -project MusicWall.xcodeproj -scheme MusicWall \
  -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tee /tmp/mw-build.log
grep 'MusicWall/.*warning:' /tmp/mw-build.log || echo "ok: no app warnings"
```

Expected: `ok: no app warnings` (AppIntents processor lines may still appear — those are tooling, not app Swift warnings).

- [ ] **Step 4: Commit**

```bash
git add MusicWall/Adapters/CarPlay/CarPlayCoordinator.swift MusicWall/Adapters/FileExportService.swift
git commit -m "fix: clear app compiler warnings before warnings-as-errors gate"
```

---

### Task 2: Enable warnings-as-errors on app target

**Files:**
- Modify: `MusicWall.xcodeproj/project.pbxproj` — configs `835DD9942E5FB592001CD95F` (Debug) and `835DD9952E5FB592001CD95F` (Release)

- [ ] **Step 1: Add build settings to MusicWall app target (Debug + Release)**

In both `835DD994… /* Debug */` and `835DD995… /* Release */` `buildSettings` blocks (the ones with `PRODUCT_BUNDLE_IDENTIFIER = chris.MusicWall`), add after `SWIFT_VERSION = 5.0;`:

```
GCC_TREAT_WARNINGS_AS_ERRORS = YES;
SWIFT_TREAT_WARNINGS_AS_ERRORS = YES;
```

Do **not** add these to project-level configs (`835DD991`, `835DD992`) or test-target configs (`F0ADCAC3`, `944A8491`, `C0DE00112233445566779902`, `C0DE00112233445566779903`).

- [ ] **Step 2: Verify Release configuration builds**

```bash
xcodebuild build -project MusicWall.xcodeproj -scheme MusicWall \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -configuration Release 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add MusicWall.xcodeproj/project.pbxproj
git commit -m "ci: treat warnings as errors on MusicWall app target"
```

---

### Task 3: Add check_warnings.sh

**Files:**
- Create: `Scripts/check_warnings.sh`

- [ ] **Step 1: Create the script**

```bash
cat > Scripts/check_warnings.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <path-to-xcodebuild.log>" >&2
  exit 2
fi

LOG="$1"
FAIL_ON_TEST_WARNINGS="${FAIL_ON_TEST_WARNINGS:-false}"
FAIL_CI="${FAIL_CI:-true}"

if [[ ! -f "$LOG" ]]; then
  echo "error: build log not found: $LOG" >&2
  exit 2
fi

python3 - "$LOG" "$FAIL_ON_TEST_WARNINGS" "$FAIL_CI" <<'PY'
import re, sys

log_path, fail_on_tests, fail_ci = sys.argv[1], sys.argv[2].lower() == "true", sys.argv[3].lower() == "true"

ALLOWLIST = re.compile(r"appintentsmetadataprocessor.*Metadata extraction skipped", re.I)
WARNING_LINE = re.compile(r"warning:", re.I)
PATH_BUCKETS = [
    ("app", re.compile(r"/MusicWall/")),
    ("tests", re.compile(r"/MusicWallTests/")),
    ("ui_tests", re.compile(r"/MusicWallUITests/")),
]

buckets = {name: [] for name, _ in PATH_BUCKETS}
buckets["filtered"] = []
buckets["other"] = []
seen = set()

with open(log_path, encoding="utf-8", errors="replace") as f:
    for line in f:
        if not WARNING_LINE.search(line):
            continue
        key = line.strip()
        if key in seen:
            continue
        seen.add(key)
        if ALLOWLIST.search(line):
            buckets["filtered"].append(key)
            continue
        placed = False
        for name, pattern in PATH_BUCKETS:
            if pattern.search(line):
                buckets[name].append(key)
                placed = True
                break
        if not placed:
            buckets["other"].append(key)

print("Warnings summary")
print(f"{'Bucket':<12} {'Count':>6}")
for name in ("app", "tests", "ui_tests", "other", "filtered"):
    print(f"{name:<12} {len(buckets[name]):>6}")

for name in ("app", "tests", "ui_tests", "other"):
    if buckets[name]:
        print(f"\n--- {name} ---")
        for w in buckets[name]:
            print(w)

test_count = len(buckets["tests"]) + len(buckets["ui_tests"])
if buckets["app"]:
    print("\nerror: app warnings found in log (compiler should have failed)", file=sys.stderr)
    sys.exit(1)

if fail_on_tests and test_count > 0 and fail_ci:
    print(f"\nerror: {test_count} test-target warning(s) (FAIL_ON_TEST_WARNINGS=true)", file=sys.stderr)
    sys.exit(1)

if test_count > 0:
    print(f"\nnote: {test_count} test-target warning(s) reported (not failing in v1)")
PY
EOF
chmod +x Scripts/check_warnings.sh
```

- [ ] **Step 2: Smoke-test the script against a fresh build log**

```bash
xcodebuild test -project MusicWall.xcodeproj -scheme MusicWall \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:MusicWallTests 2>&1 | tee build/xcodebuild.log
Scripts/check_warnings.sh build/xcodebuild.log
echo "exit code: $?"
```

Expected: summary table with `app` count **0**, `tests` count **>0**, exit code **0**.

- [ ] **Step 3: Commit**

```bash
git add Scripts/check_warnings.sh
git commit -m "ci: add check_warnings.sh for test-target warning reporting"
```

---

### Task 4: Wire Fastlane ci_tests

**Files:**
- Modify: `fastlane/Fastfile` — `ci_tests` lane (~lines 194–206)

- [ ] **Step 1: Replace ci_tests lane body**

```ruby
desc "CI Tests workflow: unit tests on iOS Simulator"
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

- [ ] **Step 2: Run full CI lane locally**

```bash
bundle exec fastlane ci_tests
```

Expected: all tests pass, coverage gate passes, warnings summary printed with `app: 0`, exit 0.

- [ ] **Step 3: Commit**

```bash
git add fastlane/Fastfile
git commit -m "ci: tee xcodebuild log and run check_warnings in ci_tests"
```

---

### Task 5: Update documentation

**Files:**
- Modify: `Agent.md`
- Modify: `MusicWallTests/Agent.md`
- Modify: `.github/pull_request_template.md`

- [ ] **Step 1: Add Warnings policy to Agent.md**

Insert after the `### Code quality` section (before `### Xcode project`):

```markdown
### Warnings policy

- **App target (`MusicWall/`):** zero compiler warnings — `SWIFT_TREAT_WARNINGS_AS_ERRORS` and `GCC_TREAT_WARNINGS_AS_ERRORS` are enabled on the app target. CI fails at compile time if a PR introduces an app warning.
- **Test targets:** warnings are **reported** by `Scripts/check_warnings.sh` in `ci_tests` but do not fail CI in v1 (ViewInspector Sendable backlog).
- **Tooling noise:** `appintentsmetadataprocessor` "Metadata extraction skipped" lines are allowlisted.
- **Future:** phase 2 will gate test-target warnings; phase 3+ evaluates `SWIFT_STRICT_CONCURRENCY` and Swift 6.
```

Also add to the `## Specs and plans` bullet list:

```markdown
- **Warnings gate:** `docs/specs/2026-06-08-swift-warnings-strategy-design.md`
```

- [ ] **Step 2: Add warnings commands to MusicWallTests/Agent.md**

Insert after the coverage gate `FAIL_CI=false` block in **Commands**:

```markdown
Inspect warnings report only (after a test run produced a log):

```bash
xcodebuild test -project MusicWall.xcodeproj -scheme MusicWall \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  2>&1 | tee build/xcodebuild.log
Scripts/check_warnings.sh build/xcodebuild.log
```

Or re-use the log from `bundle exec fastlane ci_tests` (`build/xcodebuild.log`).

Test-target warnings are reported but do not fail CI (`FAIL_ON_TEST_WARNINGS` defaults to `false`). To simulate phase 2 locally:

```bash
FAIL_ON_TEST_WARNINGS=true Scripts/check_warnings.sh build/xcodebuild.log
```
```

Add a short **Warnings policy** subsection at the end of the file:

```markdown
## Warnings policy

| Target | CI behavior |
|--------|-------------|
| `MusicWall/` app source | Compile fails on any warning |
| `MusicWallTests/`, `MusicWallUITests/` | Reported in `check_warnings.sh` summary; v1 does not fail |

Known test backlog: ViewInspector `Sendable` extensions and unnecessary `try` in view tests. Fix in a follow-on PR before enabling `FAIL_ON_TEST_WARNINGS=true`.
```

- [ ] **Step 3: Add PR template checkbox**

In `.github/pull_request_template.md`, under **Tests**, add:

```markdown
- [ ] No new app compiler warnings (CI enforces via warnings-as-errors on `MusicWall` target)
```

- [ ] **Step 4: Commit**

```bash
git add Agent.md MusicWallTests/Agent.md .github/pull_request_template.md
git commit -m "docs: document hybrid Swift warnings policy"
```

---

### Task 6: Negative-case verification

**Files:**
- Modify (temporarily): any `MusicWall/` Swift file — revert before merge

- [ ] **Step 1: Introduce a deliberate app warning**

Add to any app file (e.g. bottom of `MusicWall/Core/AlbumID.swift`):

```swift
private let _warningsGateSmokeTest = ()
```

Or use an unused variable:

```swift
let _deliberateWarning = "smoke test"
```

- [ ] **Step 2: Confirm build fails**

```bash
xcodebuild build -project MusicWall.xcodeproj -scheme MusicWall \
  -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -10
```

Expected: `** BUILD FAILED **` with "warnings being treated as errors" or unused variable error.

- [ ] **Step 3: Revert the deliberate warning**

Do not commit the smoke-test change.

- [ ] **Step 4: Final full CI run**

```bash
bundle exec fastlane ci_tests
```

Expected: PASS with warnings summary showing `app: 0`.

---

## Acceptance checklist

- [ ] `bundle exec fastlane ci_tests` passes with zero app warnings.
- [ ] Deliberate app warning causes compile failure (verified, reverted).
- [ ] `check_warnings.sh` reports test-target warning count; exits 0 in v1.
- [ ] `appintentsmetadataprocessor` lines in `filtered` bucket, not `other`.
- [ ] `SWIFT_TREAT_WARNINGS_AS_ERRORS` on `MusicWall` target only.
- [ ] Docs updated in `Agent.md` and `MusicWallTests/Agent.md`.

## PR delivery

- **Title:** `ci: hybrid Swift warnings gate (app zero-tolerance + test report)`
- **Body:** Link spec; paste `check_warnings.sh` summary from CI log (test bucket count); note negative-case verification done locally.
- **Human verification:** Confirm CI log shows test warnings reported, app bucket 0, build succeeded.

## Follow-on (out of scope)

| Phase | Action |
|-------|--------|
| 2 | Fix ViewInspector test warnings; set `FAIL_ON_TEST_WARNINGS=true` |
| 3 | Evaluate `SWIFT_STRICT_CONCURRENCY = complete` on app target |
| 4 | Swift 6 language mode assessment |

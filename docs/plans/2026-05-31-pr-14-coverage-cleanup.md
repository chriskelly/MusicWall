# PR 14 — Coverage Gates + Legacy Cleanup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enforce layer-based coverage thresholds in CI, remove pre-PR-6 legacy migration code, consolidate all testing docs into `MusicWallTests/Agent.md`, and verify red/green CI checkpoints before merge.

**Architecture:** `fastlane ci_tests` runs `xcodebuild test` with `-resultBundlePath`, then `Scripts/check_coverage.sh` parses `xccov` JSON, maps files to Core/ViewModels/Adapters layers, applies adapter exclusions, and exits non-zero below threshold. Legacy load path removed from `AlbumLibraryLoader`. Gap-filling tests land after first CI push confirms the gate fails.

**Tech Stack:** Swift 5, Swift Testing, Xcode 26+, `xccov`, Bash + Python 3 stdlib, Fastlane, GitHub Actions (`macos-26`), simulator `iPhone 17`.

**Spec:** `docs/specs/2026-05-31-pr-14-coverage-cleanup-design.md`

**Branch:** `cursor/test-refactor-pr-14-coverage-cleanup` (from `main`)

---

## File map

| Action | Path | Notes |
|--------|------|-------|
| Delete | `MusicWall/Adapters/LegacyStoredAlbum.swift` | Migration shim |
| Delete | `MusicWallTests/Fixtures/LegacyFixtureTests.swift` | Migration tests |
| Delete | `MusicWallTests/Fixtures/legacy_stored_albums_v1.json` | Golden fixture |
| Delete | `docs/testing.md` | Merged into Agent.md |
| Modify | `MusicWall/Adapters/AlbumLibraryLoader.swift` | Remove legacy branch |
| Modify | `MusicWall/Core/PreferencesKey.swift` | Remove `.storedAlbumsItems` |
| Modify | `MusicWallTests/Core/AlbumLibraryLoaderTests.swift` | Remove legacy tests |
| Modify | `MusicWallTests/Adapters/UserDefaultsPreferencesStoreTests.swift` | Remove legacy test + MusicKit import |
| Modify | `MusicWallTests/Agent.md` | Full testing guide |
| Modify | `Agent.md` | Point to `MusicWallTests/Agent.md` |
| Modify | `.cursor/skills/musicwall-test-refactor/SKILL.md` | Doc path update |
| Modify | `.cursor/skills/musicwall-test-refactor-pr-14/SKILL.md` | Doc path update |
| Modify | `.github/pull_request_template.md` | Coverage checkbox |
| Create | `Scripts/check_coverage.sh` | Coverage gate |
| Modify | `fastlane/Fastfile` | `ci_tests` result bundle + gate |
| Create | `MusicWallTests/Core/DomainErrorTests.swift` | Gap-filling (Task 5) |
| Modify | `MusicWallTests/Features/Home/HomeViewModelTests.swift` | Gap-filling (Task 5) |

---

### Task 0: Branch setup

**Files:** (none)

- [ ] **Step 1: Create branch from main**

```bash
git checkout main
git pull origin main
git checkout -b cursor/test-refactor-pr-14-coverage-cleanup
```

---

### Task 1: Remove legacy migration

**Files:**
- Delete: `MusicWall/Adapters/LegacyStoredAlbum.swift`
- Delete: `MusicWallTests/Fixtures/LegacyFixtureTests.swift`
- Delete: `MusicWallTests/Fixtures/legacy_stored_albums_v1.json`
- Modify: `MusicWall/Core/PreferencesKey.swift`
- Modify: `MusicWall/Adapters/AlbumLibraryLoader.swift`
- Modify: `MusicWallTests/Core/AlbumLibraryLoaderTests.swift`
- Modify: `MusicWallTests/Adapters/UserDefaultsPreferencesStoreTests.swift`

- [ ] **Step 1: Remove `.storedAlbumsItems` from `PreferencesKey.swift`**

```swift
enum PreferencesKey: String, CaseIterable, Sendable {
    case albumRecordsItems = "albumRecordsItemsKey"
    case backupAlbumIDs = "backupIDsKey"
    case sortDirection = "sortDirectionKey"
    case currentSort = "currentSortKey"
    case homePageLayout = "homePageLayoutKey"
}
```

- [ ] **Step 2: Simplify `AlbumLibraryLoader.swift`**

Remove the legacy branch (lines 20–26). Final `load` body:

```swift
@MainActor
static func load(
    preferences: PreferencesStore,
    repository: any AlbumRepository
) async -> LoadResult {
    if let records = preferences.load([AlbumRecord].self, for: .albumRecordsItems),
       !records.isEmpty {
        return LoadResult(records: records, shouldPersistCanonical: false)
    }

    let backupIDs = preferences.load([String].self, for: .backupAlbumIDs) ?? []
    guard !backupIDs.isEmpty else {
        return LoadResult(records: [], shouldPersistCanonical: false)
    }

    let ids = backupIDs.map { AlbumID(rawValue: $0) }
    let fetched = (try? await repository.fetch(ids: ids)) ?? []
    return LoadResult(records: fetched, shouldPersistCanonical: !fetched.isEmpty)
}
```

- [ ] **Step 3: Delete legacy source files**

```bash
rm MusicWall/Adapters/LegacyStoredAlbum.swift
rm MusicWallTests/Fixtures/LegacyFixtureTests.swift
rm MusicWallTests/Fixtures/legacy_stored_albums_v1.json
```

- [ ] **Step 4: Trim `AlbumLibraryLoaderTests.swift`**

Remove tests `migratesLegacyFixtureAndFlagsPersist`, `legacyMigrateWritesNewKey`, and the private `legacyFixtureData()` / `BundleToken` helpers. Keep:

- `loadsFromNewKeyWhenPresent`
- `hydratesFromBackupWhenCanonicalAndLegacyEmpty` (rename to `hydratesFromBackupWhenCanonicalEmpty`)
- `fetchThrowsLeavesEmpty`
- `partialFetchReturnsSubset`

- [ ] **Step 5: Trim `UserDefaultsPreferencesStoreTests.swift`**

Remove `roundTripLegacyStoredAlbumsItems` and the `import MusicKit` line (no longer needed).

- [ ] **Step 6: Verify no orphaned references**

```bash
rg 'LegacyStoredAlbum|storedAlbumsItems|legacy_stored_albums' --glob '*.swift'
```

Expected: no matches (historical docs under `docs/` may still mention them — OK).

- [ ] **Step 7: Run unit tests**

```bash
xcodebuild test -project MusicWall.xcodeproj -scheme MusicWall \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:MusicWallTests
```

Expected: **TEST SUCCEEDED**

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "$(cat <<'EOF'
test refactor PR 14: remove legacy StoredAlbum migration path

EOF
)"
```

---

### Task 2: Consolidate testing documentation

**Files:**
- Modify: `MusicWallTests/Agent.md`
- Delete: `docs/testing.md`
- Modify: `Agent.md`
- Modify: `.cursor/skills/musicwall-test-refactor/SKILL.md`
- Modify: `.cursor/skills/musicwall-test-refactor-pr-14/SKILL.md`

- [ ] **Step 1: Replace `MusicWallTests/Agent.md` with consolidated content**

```markdown
# Agent guide — MusicWallTests

`MusicWallTests` is the deterministic test target for MusicWall. UI smoke tests live in `MusicWallUITests`. Both run through the shared `MusicWall` scheme on the iPhone 17 simulator.

## Test pyramid

| Layer | Target | Framework |
|-------|--------|-----------|
| Core / Adapters / ViewModels | `MusicWallTests` | Swift Testing |
| SwiftUI views (Snackbar, SortMenu, AlbumEdit) | `MusicWallTests` | Swift Testing + ViewInspector |
| End-to-end smoke | `MusicWallUITests` | XCTest / XCUITest |

North-star architecture: `.cursor/skills/musicwall-test-refactor/references/architecture.md`

## Commands

Run all tests (unit + UI + coverage gate):

```bash
bundle exec fastlane ci_tests
```

Run unit tests only:

```bash
xcodebuild test -project MusicWall.xcodeproj -scheme MusicWall \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:MusicWallTests
```

Run UI tests only:

```bash
xcodebuild test -project MusicWall.xcodeproj -scheme MusicWall \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:MusicWallUITests
```

Run a single UI test:

```bash
xcodebuild test -project MusicWall.xcodeproj -scheme MusicWall \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:MusicWallUITests/MusicWallUITests/testLaunch_savedLibrary_showsFixtureTitles
```

Inspect coverage gate only (after a test run produced a bundle):

```bash
xcodebuild test -project MusicWall.xcodeproj -scheme MusicWall \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -resultBundlePath build/MusicWallTestResults.xcresult
Scripts/check_coverage.sh build/MusicWallTestResults.xcresult
```

Set `FAIL_CI=false` to print the report without failing locally:

```bash
FAIL_CI=false Scripts/check_coverage.sh build/MusicWallTestResults.xcresult
```

## UI tests

### Launch arguments

| Argument | Required | Values |
|----------|----------|--------|
| `-UITestMockMusic` | Yes (flag) | Enables mock dependencies (no MusicKit / Apple ID) |
| `-UITestLoadScenario` | Yes when mock enabled | `savedLibrary` \| `restoreFromBackup` |

**savedLibrary** — pre-seeded album records in isolated UserDefaults (typical returning user).

**restoreFromBackup** — pre-seeded backup IDs only; mock repository returns fixture albums on fetch.

Production launch omits both arguments and uses `AppDependencies.live`.

### Adding a UI test

1. Launch with `launchArguments` (see helpers in `MusicWallUITests.swift`).
2. Prefer `accessibilityIdentifier` over label text (`home.addAlbum`, `search.cancel`).
3. Use `waitForExistence` — avoid fixed `sleep`.
4. Use a fresh `launch()` per scenario; do not switch load mode mid-session.

### Accessibility identifiers

| Identifier | Element |
|------------|---------|
| `home.addAlbum` | Add album toolbar button |
| `search.cancel` | Search sheet Cancel |
| `uitest.lastPlayedAlbum` | Hidden playback bridge (mock launch only) |

## ViewInspector (PR 12)

PR 12 adds [ViewInspector](https://github.com/nalexn/ViewInspector) (MIT) for high-value SwiftUI unit tests without XCUITest cost. Linked to **MusicWallTests only**.

### Adding a view test

1. `import ViewInspector` and `@testable import MusicWall`.
2. Annotate `@MainActor` and `throws` (or `async throws` for hosted views).
3. Prefer `find(text:)` / `find(button:)` over deep hierarchy chains.
4. Test views in isolation.

### Inspection pattern (`@State` / `@Environment`)

- **Main target:** `MusicWall/TestSupport/Inspection.swift`
- **Test target:** `MusicWallTests/TestSupport/ViewInspector+MusicWall.swift`
- **View under test:** `internal let inspection = Inspection<Self>()` + `.onReceive(inspection.notice) { … }`

### Stability rules

- No animation timing or auto-dismiss assertions.
- No snapshot reference images.
- No `glassEffect()` branch coverage unless trivial.
- Avoid inspecting content inside `Menu` / `contextMenu` wrappers.

### View test inventory

| Suite | File | Coverage |
|-------|------|----------|
| Snackbar | `UI/SnackbarViewTests.swift` | message, action button, undo callback |
| Sort menu | `UI/SortMenuViewTests.swift` | direction arrow on active sort |
| Edit album | `UI/AlbumEditViewTests.swift` | Save disabled when title whitespace-only |

## Coverage policy

CI enforces line coverage via `Scripts/check_coverage.sh` after every `bundle exec fastlane ci_tests` run.

| Layer | Path rule | Threshold |
|-------|-----------|-----------|
| Core / Persistence | `MusicWall/Core/**` | ≥ 95% |
| ViewModels | `MusicWall/Features/**/*ViewModel.swift` | ≥ 90% |
| Adapters | `MusicWall/Adapters/**` minus exclusions | ≥ 80% |

### Adapter exclusions (live / device-only)

These files are omitted from the adapter denominator:

| File | Reason |
|------|--------|
| `MusicKitAlbumRepository.swift` | Live catalog/library search |
| `SystemMusicPlayerAdapter.swift` | Live playback |
| `MusicKitArtworkProvider.swift` | Live artwork fetch |
| `AlbumMapper.swift` | MusicKit mapping (tested via mocks) |
| `SecurityScopedResourceReader.swift` | Security-scoped file picker I/O |
| `LiveMusicAuthorizationProvider.swift` | Live authorization dialog |

### Human-verified (not CI-gated)

- Live MusicKit authorization success paths
- Live Apple Music catalog or library responses
- `SystemMusicPlayer` playback on device
- SwiftUI animations, vinyl effects, snackbar auto-dismiss timing

Keep `MusicWallTests` and `MusicWallUITests` in the shared `MusicWall` scheme `TestAction`. Keep scheme coverage gathering enabled.

## Fixtures

- `MusicWallTests/Fixtures/AlbumFixtures.swift` — canonical `AlbumRecord` samples (`baseTrio`, UTC date helpers).
- `MusicWall/UITestSupport/UITestFixtures.swift` — must match `AlbumFixtures.baseTrio` IDs/titles for UI tests.

## Framework

- Default: Swift Testing
- UI tests: XCTest / XCUITest only
```

- [ ] **Step 2: Delete `docs/testing.md`**

```bash
rm docs/testing.md
```

- [ ] **Step 3: Update root `Agent.md`**

In the **Architecture** subsection under "iOS / Swift best practices", after the MVVM bullet list, add:

```markdown
- **Testing & coverage:** see `MusicWallTests/Agent.md` (commands, UI launch args, ViewInspector, coverage thresholds).
- **Layered architecture (north star):** `.cursor/skills/musicwall-test-refactor/references/architecture.md`.
```

In **Specs and plans**, change the test refactor bullet to reference `MusicWallTests/Agent.md` instead of implying separate `docs/testing.md`.

- [ ] **Step 4: Update `.cursor/skills/musicwall-test-refactor/SKILL.md`**

Replace all `docs/testing.md` references with `MusicWallTests/Agent.md` (paths frontmatter, step 6, Decisions table, Coverage policy pointer).

- [ ] **Step 5: Update `.cursor/skills/musicwall-test-refactor-pr-14/SKILL.md`**

Replace `docs/testing.md` in paths and in-scope bullets with `MusicWallTests/Agent.md`. Update Agent.md bullet to: "architecture section points to layered model + `MusicWallTests/Agent.md`".

- [ ] **Step 6: Commit**

```bash
git add MusicWallTests/Agent.md Agent.md .cursor/skills/musicwall-test-refactor/SKILL.md \
  .cursor/skills/musicwall-test-refactor-pr-14/SKILL.md
git rm docs/testing.md
git commit -m "$(cat <<'EOF'
docs: consolidate testing guide into MusicWallTests/Agent.md

EOF
)"
```

---

### Task 3: Wire coverage gate

**Files:**
- Create: `Scripts/check_coverage.sh`
- Modify: `fastlane/Fastfile`

- [ ] **Step 1: Create `Scripts/check_coverage.sh`**

```bash
#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <path-to.xcresult>" >&2
  exit 2
fi

BUNDLE="$1"
FAIL_CI="${FAIL_CI:-true}"

if [[ ! -d "$BUNDLE" ]]; then
  echo "error: xcresult bundle not found: $BUNDLE" >&2
  exit 2
fi

python3 - "$BUNDLE" "$FAIL_CI" <<'PY'
import json, subprocess, sys, os

bundle, fail_ci = sys.argv[1], sys.argv[2].lower() == "true"

proc = subprocess.run(
    ["xcrun", "xccov", "view", "--report", "--json", bundle],
    capture_output=True, text=True,
)
if proc.returncode != 0:
    print(proc.stderr or proc.stdout, file=sys.stderr)
    sys.exit(2)

data = json.loads(proc.stdout)
target = next(
    (t for t in data.get("targets", []) if t.get("name", "").endswith("MusicWall.app")),
    None,
)
if target is None:
    print("error: MusicWall.app target not found in coverage report", file=sys.stderr)
    sys.exit(2)

EXCLUDED_ADAPTERS = {
    "MusicKitAlbumRepository.swift",
    "SystemMusicPlayerAdapter.swift",
    "MusicKitArtworkProvider.swift",
    "AlbumMapper.swift",
    "SecurityScopedResourceReader.swift",
    "LiveMusicAuthorizationProvider.swift",
}

THRESHOLDS = {
    "Core": 0.95,
    "ViewModels": 0.90,
    "Adapters": 0.80,
}

layers = {
    "Core": {"covered": 0, "total": 0, "files": []},
    "ViewModels": {"covered": 0, "total": 0, "files": []},
    "Adapters": {"covered": 0, "total": 0, "files": []},
}

def classify(path: str):
    if "/Features/" in path and path.endswith("ViewModel.swift"):
        return "ViewModels"
    if "/Core/" in path:
        return "Core"
    if "/Adapters/" in path:
        return "Adapters"
    return None

for f in target.get("files", []):
    path = f.get("path", "")
    name = os.path.basename(path)
    layer = classify(path)
    if layer is None:
        continue
    if layer == "Adapters" and name in EXCLUDED_ADAPTERS:
        continue
    covered = int(f.get("coveredLines", 0))
    total = int(f.get("executableLines", 0))
    if total == 0:
        continue
    layers[layer]["covered"] += covered
    layers[layer]["total"] += total
    layers[layer]["files"].append((name, covered, total, covered / total))

print(f"{'Layer':<14}{'Covered':>8}{'Total':>8}{'Pct':>8}{'Threshold':>12}{'Status':>8}")
print("-" * 58)

failed = []
for layer, threshold in THRESHOLDS.items():
    cov = layers[layer]["covered"]
    tot = layers[layer]["total"]
    pct = (cov / tot) if tot else 0.0
    status = "PASS" if pct >= threshold else "FAIL"
    if status == "FAIL":
        failed.append(layer)
    print(f"{layer:<14}{cov:>8}{tot:>8}{pct:>7.1%}{threshold:>11.0%}{status:>8}")

if failed:
    for layer in failed:
        print(f"\nLowest coverage in {layer}:")
        for name, c, t, p in sorted(layers[layer]["files"], key=lambda x: x[3])[:5]:
            print(f"  {p:6.1%}  {c:3}/{t:3}  {name}")
    if fail_ci:
        sys.exit(1)
    print("\nFAIL_CI=false — reporting only.")
PY
```

```bash
chmod +x Scripts/check_coverage.sh
```

- [ ] **Step 2: Update `fastlane/Fastfile` `ci_tests` lane**

Replace the existing `ci_tests` body with:

```ruby
desc "CI Tests workflow: unit tests on iOS Simulator"
lane :ci_tests do
  result_bundle = "../build/MusicWallTestResults.xcresult"
  sh("rm -rf #{result_bundle}")
  sh("mkdir -p ../build")
  sh(
    "xcodebuild test -project ../#{XCODEPROJ} -scheme #{SCHEME} " \
    "-destination 'platform=iOS Simulator,name=iPhone 17' " \
    "-resultBundlePath #{result_bundle}"
  )
  sh("../Scripts/check_coverage.sh #{result_bundle}")
end
```

- [ ] **Step 3: Run locally — expect gate failure**

```bash
bundle exec fastlane ci_tests
```

Expected: tests **SUCCEED**, then coverage gate **FAILS** with Core and/or ViewModels below threshold (Adapters should PASS). This confirms the gate is wired before the red CI checkpoint.

- [ ] **Step 4: Commit**

```bash
git add Scripts/check_coverage.sh fastlane/Fastfile
git commit -m "$(cat <<'EOF'
ci: add layer coverage gate to ci_tests

EOF
)"
```

---

### Task 4: Push PR + babysit (red checkpoint)

**Files:** (none — CI verification)

- [ ] **Step 1: Push branch and open PR**

```bash
git push -u origin HEAD

gh pr create --title "test refactor PR 14: coverage gates + legacy cleanup" --body "$(cat <<'EOF'
## Summary

- Remove pre-PR-6 `LegacyStoredAlbum` migration path
- Consolidate testing docs into `MusicWallTests/Agent.md`
- Wire `Scripts/check_coverage.sh` into `fastlane ci_tests`

## Red checkpoint (this push)

Coverage gate is live; gap-filling tests intentionally not yet added. **CI should fail on coverage thresholds** — that is expected.

## Spec

`docs/specs/2026-05-31-pr-14-coverage-cleanup-design.md`

## Test plan

- [ ] Red: `ci-tests` fails at `check_coverage.sh` (Core/ViewModels below threshold)
- [ ] Green (follow-up push): all layers PASS

EOF
)"
```

- [ ] **Step 2: Watch CI**

```bash
gh pr checks --watch
```

- [ ] **Step 3: Validate red checkpoint**

Open the failed `ci-tests` log. Confirm:

1. `xcodebuild test` step **passed** (all unit + UI tests green).
2. `Scripts/check_coverage.sh` step **failed** with output like `Core ... FAIL` and/or `ViewModels ... FAIL`.
3. Failure is **not** a script crash, missing `.xcresult`, or build error.

If CI fails for an **unexpected** reason (compile error, test failure, script bug), fix on branch, push, and re-watch until only coverage thresholds fail.

- [ ] **Step 4: Note red checkpoint in PR**

Add a PR comment documenting the expected failure:

```bash
gh pr comment --body "Red checkpoint ✅: ci-tests failed on coverage gate as expected (Core/ViewModels below threshold). Gap-filling tests next."
```

**Do not merge.** Proceed to Task 5.

---

### Task 5: Close coverage gaps + PR template

**Files:**
- Create: `MusicWallTests/Core/DomainErrorTests.swift`
- Modify: `MusicWallTests/Features/Home/HomeViewModelTests.swift`
- Modify: `.github/pull_request_template.md`
- Modify: `MusicWall.xcodeproj/project.pbxproj` (register new test file — mirror `BackupCodecTests.swift` entries)

- [ ] **Step 1: Create `MusicWallTests/Core/DomainErrorTests.swift`**

```swift
import Testing
@testable import MusicWall

struct DomainErrorTests {
    @Test
    func backupErrorDescriptions() {
        #expect(BackupError.emptyExport.errorDescription == "No albums to export")
        #expect(BackupError.emptyImport.errorDescription == "Import file contains no album IDs")
        #expect(BackupError.fileAccessDenied.errorDescription == "Could not access file")
        #expect(BackupError.fileReadFailed("disk").errorDescription == "Failed to read file: disk")
        #expect(BackupError.invalidFormat.errorDescription == "Invalid file format")
    }

    @Test
    func playbackErrorDescriptions() {
        #expect(PlaybackError.albumNotFound.errorDescription == "Album not found")
        #expect(PlaybackError.playbackFailed("timeout").errorDescription == "Playback failed: timeout")
    }

    @Test
    func albumRepositoryErrorDescriptions() {
        #expect(AlbumRepositoryError.invalidQuery.errorDescription == "Search query cannot be empty")
        #expect(AlbumRepositoryError.albumNotFound.errorDescription == "Album not found")
        #expect(AlbumRepositoryError.searchFailed("x").errorDescription == "Search failed: x")
        #expect(AlbumRepositoryError.networkError("offline").errorDescription == "Network error: offline")
    }
}
```

- [ ] **Step 2: Register test file in `project.pbxproj`**

Mirror how `BackupCodecTests.swift` appears: add to `MusicWallTests` target `PBXBuildFile`, `PBXFileReference`, and `PBXSourcesBuildPhase` for the `MusicWallTests` group.

- [ ] **Step 3: Add HomeViewModel gap tests**

Append to `HomeViewModelTests.swift`:

```swift
    @Test @MainActor
    func load_hydratesFromSavedPreferences() async {
        let preferences = InMemoryPreferencesStore()
        let records = [AlbumFixtures.record(id: "loaded", title: "Loaded", artistName: "Artist")]
        preferences.save(records, for: .albumRecordsItems)
        let viewModel = HomeViewModel(
            preferences: preferences,
            repository: MockAlbumRepository(),
            backup: MockAlbumBackupService()
        )

        await viewModel.load()

        #expect(viewModel.store.items == records)
    }

    @Test @MainActor
    func shuffleAlbums_preservesItemCount() {
        let (viewModel, _, _, _) = makeViewModel()
        for fixture in AlbumFixtures.baseTrio {
            viewModel.store.addAlbum(fixture)
        }
        let count = viewModel.store.items.count

        viewModel.shuffleAlbums()

        #expect(viewModel.store.items.count == count)
    }
```

- [ ] **Step 4: Update PR template**

Add under TestFlight section in `.github/pull_request_template.md`:

```markdown
## Tests

- [ ] Unit tests added/updated where logic changed
- [ ] `bundle exec fastlane ci_tests` passes locally (including coverage gate)
```

- [ ] **Step 5: Run full CI locally**

```bash
bundle exec fastlane ci_tests
```

Expected: tests **SUCCEED** and coverage gate prints **PASS** for Core, ViewModels, and Adapters.

If any layer still FAILs, inspect lowest files in gate output and add targeted tests before proceeding.

- [ ] **Step 6: Commit**

```bash
git add MusicWallTests/Core/DomainErrorTests.swift \
  MusicWallTests/Features/Home/HomeViewModelTests.swift \
  MusicWall.xcodeproj/project.pbxproj \
  .github/pull_request_template.md
git commit -m "$(cat <<'EOF'
test: close coverage gaps for PR 14 gate thresholds

EOF
)"
```

---

### Task 6: Push again + babysit (green checkpoint)

**Files:** (none — CI verification)

- [ ] **Step 1: Push gap-filling commit**

```bash
git push origin HEAD
```

- [ ] **Step 2: Watch CI until green**

```bash
gh pr checks --watch
```

Expected: **`ci-tests`** check **passes**.

- [ ] **Step 3: Validate green checkpoint in Actions log**

Confirm gate output shows:

```
Core      ... PASS
ViewModels ... PASS
Adapters  ... PASS
```

- [ ] **Step 4: Triage PR comments**

Use babysit skill: resolve any valid Bugbot/reviewer comments; fix in-scope issues; push fixes if needed and re-watch CI.

- [ ] **Step 5: Mark PR ready**

Update PR body green checkpoint:

```bash
gh pr comment --body "Green checkpoint ✅: ci-tests passed with all coverage layers at/above threshold."
```

PR is merge-ready when: CI green, comments triaged, red/green checkpoints documented.

---

## Spec coverage checklist (self-review)

| Spec requirement | Task |
|------------------|------|
| Remove legacy migration | Task 1 |
| Consolidate docs → `MusicWallTests/Agent.md` | Task 2 |
| Coverage gate script + fastlane | Task 3 |
| Red CI checkpoint | Task 4 |
| Gap-filling tests | Task 5 |
| Green CI checkpoint | Task 6 |
| PR template checkbox | Task 5 |
| Adapter exclusions documented | Task 2 |
| Root `Agent.md` pointers | Task 2 |
| No orphaned legacy references | Task 1 Step 6 |

## PR delivery

- **Title:** `test refactor PR 14: coverage gates + legacy cleanup`
- **Link:** PR 14 of 14; reference spec + red/green checkpoint notes in description
- **Human verification:** Confirm red failure was coverage-only; confirm green shows all layers PASS

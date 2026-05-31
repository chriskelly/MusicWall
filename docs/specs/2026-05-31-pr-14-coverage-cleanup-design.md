# PR 14 — Coverage gates + legacy cleanup

**Status:** Approved (2026-05-31)  
**Program:** MusicWall testability refactor  
**Requires:** PR 12, PR 13 merged  
**Blocks:** optional PR 15  
**Approach:** `xccov` + custom gate script in CI; remove pre-PR-6 legacy migration; consolidate all testing docs into `MusicWallTests/Agent.md`; red/green CI verification before merge

## Summary

Enforce layer-based coverage thresholds in **`ci-tests`** via a custom **`Scripts/check_coverage.sh`** wired into **`fastlane ci_tests`**. Remove **`LegacyStoredAlbum`** and the **`storedAlbumsItems`** migration path (assumes no users remain on pre-PR-6 on-disk format). Consolidate **`docs/testing.md`** into **`MusicWallTests/Agent.md`** (single testing doc for unit, ViewInspector, UI, and coverage policy). Update root **`Agent.md`** to point agents at the layered architecture reference and **`MusicWallTests/Agent.md`**.

Implementation uses a **red/green CI checkpoint**: push with the gate wired but gap-filling tests not yet added — CI must fail on coverage; then add tests, push again — CI must pass.

## Goals

- CI **fails** on PRs and **`main`** when any enforced layer drops below its threshold.
- Delete legacy migration code with no orphaned references.
- **`MusicWallTests/Agent.md`** is the sole testing guide (commands, UI launch args, ViewInspector, coverage table, exclusions).
- Root **`Agent.md`** architecture section references layered model + **`MusicWallTests/Agent.md`**.

## Non-goals

- SPM extraction (PR 15).
- PR comment bot / coverage badge upload.
- SwiftUI view line-coverage gates (coordinator + UI tests remain the strategy).
- Keeping **`LegacyStoredAlbum`** or **`storedAlbumsItems`** read path.

## Decisions (brainstorming)

| Topic | Choice |
|-------|--------|
| Legacy migration | **Remove** — delete **`LegacyStoredAlbum`**, legacy load branch, fixtures, and **`.storedAlbumsItems`** key |
| Coverage enforcement | **Immediate fail** — no report-only phase; gate exits non-zero below threshold |
| Coverage tooling | **`xccov` + custom script** (not Slather) |
| Documentation | **Consolidate** **`docs/testing.md`** → **`MusicWallTests/Agent.md`**; delete source file |
| Gap-filling tests | **Deferred** until after first CI checkpoint (see task order) |
| CI verification | **Red/green** — push once expecting coverage failure; push again expecting pass |

## Approaches considered

### Coverage gate implementation

| Option | Description | Why not chosen |
|--------|-------------|----------------|
| **`xccov` + custom script (chosen)** | Parse JSON from **`xccov view --report --json`**; path-based layer mapping + exclusion list; exit non-zero on miss | — |
| Slather | Ruby gem + **`.slather.yml`** | Extra dependency; overkill for three layer thresholds |
| Inline Fastfile Ruby | Parse **`xccov`** JSON in **`ci_tests`** lane | Harder to run/test outside Fastlane; mixes concerns |

### Legacy migration

| Option | Description | Why not chosen |
|--------|-------------|----------------|
| **Remove (chosen)** | Delete shim + branch; load canonical key → backup fetch → empty | — |
| Keep indefinitely | Document as supported upgrade path | Conflicts with cleanup goal; **`LegacyStoredAlbum`** imports MusicKit in Adapters |
| Deprecate only | Comment/doc marking removal target | Leaves dead code in tree |

## Architecture

### Coverage gate flow

```
fastlane ci_tests
  │
  ├─ xcodebuild test -resultBundlePath build/MusicWallTestResults.xcresult
  │
  └─ Scripts/check_coverage.sh build/MusicWallTestResults.xcresult
        │
        ├─ xcrun xccov view --report --json <bundle>
        ├─ Map files → layers (path rules)
        ├─ Apply adapter exclusion list
        ├─ Print per-layer summary table
        └─ exit 1 if any layer < threshold (FAIL_CI=true, default in CI)
```

### Layer thresholds

| Layer | Path rule | Threshold |
|-------|-----------|-----------|
| Core / Persistence | **`MusicWall/Core/**`** | ≥ 95% |
| ViewModels | **`MusicWall/Features/**/*ViewModel.swift`** | ≥ 90% |
| Adapters | **`MusicWall/Adapters/**`** minus exclusions | ≥ 80% |

**Line coverage** = `coveredLines / executableLines` aggregated per layer across matching files.

Protocol-only declarations contribute 0 executable lines and do not penalize the layer.

### Adapter exclusions (documented, omitted from denominator)

| File | Reason |
|------|--------|
| `MusicKitAlbumRepository.swift` | Live catalog/library search |
| `SystemMusicPlayerAdapter.swift` | Live **`SystemMusicPlayer`** playback |
| `MusicKitArtworkProvider.swift` | Live artwork fetch |
| `AlbumMapper.swift` | MusicKit type mapping (covered via mocks) |
| `SecurityScopedResourceReader.swift` | Security-scoped file picker I/O |
| `LiveMusicAuthorizationProvider.swift` | Live authorization dialog |

### Load order after legacy removal

```
AlbumLibraryLoader.load()
  │
  ├─ .albumRecordsItems non-empty → return records (shouldPersistCanonical: false)
  │
  ├─ else .backupAlbumIDs non-empty → repository.fetch → return (shouldPersistCanonical: !empty)
  │
  └─ else → empty
```

**Risk (accepted):** Users still on pre-PR-6 **`savedAlbumsItemsKey`** lose local title/artist overrides until they re-add albums or restore from backup IDs.

## Legacy cleanup

### Delete

| Path | Reason |
|------|--------|
| `MusicWall/Adapters/LegacyStoredAlbum.swift` | Migration-only Codable shim |
| `MusicWallTests/Fixtures/LegacyFixtureTests.swift` | Migration golden tests |
| `MusicWallTests/Fixtures/legacy_stored_albums_v1.json` | Migration fixture |
| `docs/testing.md` | Consolidated into **`MusicWallTests/Agent.md`** |

### Modify

| Path | Change |
|------|--------|
| `MusicWall/Adapters/AlbumLibraryLoader.swift` | Remove legacy branch |
| `MusicWall/Core/PreferencesKey.swift` | Remove **`.storedAlbumsItems`** |
| `MusicWallTests/Core/AlbumLibraryLoaderTests.swift` | Remove 3 legacy tests + **`legacyFixtureData()`** helper |
| `MusicWallTests/Adapters/UserDefaultsPreferencesStoreTests.swift` | Remove **`roundTripLegacyStoredAlbumsItems`** |

Already removed in earlier PRs (verify no resurrection): **`StoredAlbum`**, **`StoredAlbums`**, static **`MusicService`**, **`UserDefaultsManager`**, legacy **`BackupService`** monolith.

## Gap-filling tests

Add after first CI checkpoint (when gate is wired but thresholds not yet met):

| Gap | Fix |
|-----|-----|
| **`HomeViewModel`** (~77%) | Tests for **`shuffleAlbums()`**, **`load()`** delegation |
| **`BackupError`** partial | All **`errorDescription`** branches |
| **`BackupCodec`** (~90%) | Remaining decode edge case(s) if still below threshold after re-measure |

Re-run **`bundle exec fastlane ci_tests`** locally before second push.

## CI

### Fastlane — extend **`ci_tests`**

```ruby
lane :ci_tests do
  result_bundle = "../build/MusicWallTestResults.xcresult"
  sh("rm -rf #{result_bundle}")
  sh("mkdir -p ../build")
  sh("xcodebuild test -project ../#{XCODEPROJ} -scheme #{SCHEME} " \
     "-destination 'platform=iOS Simulator,name=iPhone 17' " \
     "-resultBundlePath #{result_bundle}")
  sh("../Scripts/check_coverage.sh #{result_bundle}")
end
```

### Script — **`Scripts/check_coverage.sh`**

- Bash wrapper + Python 3 stdlib (no pip deps).
- Args: path to **`.xcresult`** bundle.
- Env: **`FAIL_CI`** (default **`true`**); set **`false`** locally to inspect report without failing.
- Output: layer summary table; on failure, list lowest-coverage files in failing layer(s).
- Exit **`1`** if any enforced layer below threshold.

### Workflow

No change to **`.github/workflows/ci-tests.yml`** — existing **`bundle exec fastlane ci_tests`** step picks up the gate.

### Failure output (example)

```
Layer          Covered  Total   Pct    Threshold  Status
Core           158      174    90.8%   95%        FAIL
ViewModels     150      167    89.8%   90%        FAIL
Adapters        70       72    97.2%   80%        PASS
```

## Documentation — `MusicWallTests/Agent.md`

Restructure as single testing guide:

1. **Overview** — test pyramid (unit / ViewInspector / UI smoke).
2. **Commands** — all tests, unit-only, UI-only, single test, local coverage gate.
3. **UI tests** — launch args, scenarios, accessibility IDs, adding a test (from former **`docs/testing.md`**).
4. **ViewInspector** — existing PR 12 content (unchanged).
5. **Coverage policy** — threshold table, adapter exclusions, gate script usage.
6. **Fixtures** — **`AlbumFixtures`**; remove migration fixture references.

### Root **`Agent.md`**

- Architecture bullet list: keep layered model summary.
- Add pointer: full testing/coverage policy in **`MusicWallTests/Agent.md`**.
- Add pointer: north-star architecture in **`.cursor/skills/musicwall-test-refactor/references/architecture.md`**.

### Other reference updates

| Path | Change |
|------|--------|
| `.cursor/skills/musicwall-test-refactor/SKILL.md` | **`docs/testing.md`** → **`MusicWallTests/Agent.md`** |
| `.cursor/skills/musicwall-test-refactor-pr-14/SKILL.md` | Same |
| `.github/pull_request_template.md` | Optional checkbox: unit tests + coverage gates pass |

Historical specs/plans under **`docs/specs/`** and **`docs/plans/`** are not rewritten.

## Error handling

- Coverage script: clear stderr message if **`.xcresult`** missing or **`xccov`** fails; exit non-zero.
- Gate failure: CI log shows which layer(s) failed and worst files — no silent pass.
- Legacy removal: no runtime migration fallback; empty library if only legacy key present.

## Implementation task order

1. **Remove legacy migration** — code, tests, fixtures, **`.storedAlbumsItems`** key.
2. **Consolidate docs** — merge **`docs/testing.md`** into **`MusicWallTests/Agent.md`**; delete **`docs/testing.md`**; update root **`Agent.md`** and skill refs.
3. **Wire coverage gate** — add **`Scripts/check_coverage.sh`**; extend **`fastlane ci_tests`** with **`-resultBundlePath`** + script invocation.
4. **Push PR + babysit (red checkpoint)** — open PR; confirm **`ci-tests`** fails as expected on coverage thresholds (gap-filling tests intentionally not yet added). Resolve any unexpected failures (merge conflicts, build breaks, script bugs) — coverage threshold failure is the **expected** outcome.
5. **Close coverage gaps** — add gap-filling unit tests; PR template checkbox.
6. **Push again + babysit (green checkpoint)** — confirm **`ci-tests`** passes including coverage gate; PR merge-ready.

## Acceptance criteria

- [ ] CI fails when any enforced layer is below threshold (verified at red checkpoint).
- [ ] CI passes with all layers at/above threshold (verified at green checkpoint).
- [ ] **`LegacyStoredAlbum`**, migration tests, and **`.storedAlbumsItems`** removed; no orphaned references.
- [ ] **`AlbumLibraryLoader`** load order: canonical → backup fetch → empty.
- [ ] **`MusicWallTests/Agent.md`** is the sole testing doc; **`docs/testing.md`** deleted.
- [ ] Root **`Agent.md`** points to **`MusicWallTests/Agent.md`** for testing/coverage.
- [ ] Adapter exclusions documented in **`MusicWallTests/Agent.md`**.
- [ ] PR template checkbox for tests + coverage (optional but included).

## Human verification (PR description)

- Confirm red checkpoint CI log shows coverage gate failure (not an unrelated error).
- Confirm green checkpoint shows all three layers PASS in gate output.
- Spot-check Release build: no regression from legacy removal (existing users on canonical key unaffected).

## PR delivery

- Branch: `cursor/test-refactor-pr-14-coverage-cleanup` (or team convention).
- PR title: `test refactor PR 14: coverage gates + legacy cleanup`
- Link PR 14 of 14; note red/green CI verification and doc consolidation.

## Follow-on PRs

| PR | Relationship |
|----|----------------|
| PR 15 (optional) | SPM split; update **`MusicWallTests/Agent.md`** if package layout changes reporting paths |

# Swift Warnings Phase 3 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enable `SWIFT_STRICT_CONCURRENCY = complete` on the `MusicWall` app target after clearing six strict-concurrency diagnostics via isolation-alignment fixes.

**Architecture:** Fix baseline warnings first (AlbumTapCoordinator return-value API, `ImageCache` Sendable, CarPlay `@MainActor` + `assumeIsolated`), then add `SWIFT_STRICT_CONCURRENCY = complete` to `MusicWall` Debug + Release in `project.pbxproj`. Test targets unchanged. Existing `TREAT_WARNINGS_AS_ERRORS` on all targets provides CI enforcement; no script or Fastlane changes.

**Tech Stack:** Swift 5, Xcode 26+, Bash + Python 3, Fastlane, iPhone 17 simulator.

**Spec:** `docs/specs/2026-06-08-swift-warnings-phase3-design.md`

**Branch:** `cursor/swift-warnings-phase3` (design spec already committed)

---

## File map

| Action | Path | Notes |
|--------|------|-------|
| Modify | `MusicWall/Core/AlbumTapCoordinator.swift` | Return `String?` instead of setter closure |
| Modify | `MusicWallTests/Core/AlbumTapCoordinatorTests.swift` | Assign return value |
| Modify | `MusicWall/LayoutViews.swift` | Two tap call sites (grid + list) |
| Modify | `MusicWall/ImageCache.swift` | `Sendable` or `@unchecked Sendable` |
| Modify | `MusicWall/Adapters/CarPlay/CarPlaySetupTemplate.swift` | `@MainActor` on enum |
| Modify | `MusicWall/Adapters/CarPlay/CarPlayBarButtons.swift` | `@MainActor` + `assumeIsolated` |
| Modify | `MusicWall.xcodeproj/project.pbxproj` | `SWIFT_STRICT_CONCURRENCY = complete` on app target |
| Modify | `Agent.md` | Warnings policy — strict concurrency on app |
| Modify | `docs/specs/2026-06-08-swift-warnings-strategy-design.md` | Mark Phase 3 Done |
| Modify | `.github/pull_request_template.md` | Note app strict concurrency |

No changes: `Scripts/check_warnings.sh`, `fastlane/Fastfile`, `.github/workflows/ci-tests.yml`, `MusicWallTests/Agent.md`.

---

### Task 0: Branch setup and baseline capture

**Files:** (none — probe log only)

- [ ] **Step 1: Confirm branch and base**

```bash
git checkout cursor/swift-warnings-phase3
git log --oneline -1
```

Expected: latest commit is `docs: add Swift warnings phase 3 design spec` (or later). Branch is based on `main` with Phase 2 merged.

- [ ] **Step 2: Capture strict-concurrency baseline**

```bash
mkdir -p build
set -o pipefail
xcodebuild build -project MusicWall.xcodeproj -scheme MusicWall \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  SWIFT_STRICT_CONCURRENCY=complete \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=NO \
  GCC_TREAT_WARNINGS_AS_ERRORS=NO \
  2>&1 | tee build/strict-concurrency-baseline.log
grep -E 'warning:|error:' build/strict-concurrency-baseline.log | grep MusicWall/ | sort -u
```

Expected: six unique Swift diagnostics in four files:

1. `CarPlaySetupTemplate.swift:9` — main-actor-isolated init from nonisolated context
2–3. `CarPlayBarButtons.swift:19` — sending `button` / `handler` risks data races
4. `CarPlayCoordinator.swift:140` — sending `imageCache` risks data races
5–6. `LayoutViews.swift:80` and `:183` — sending non-Sendable `@MainActor` closure

---

### Task 1: Refactor `AlbumTapCoordinator` to return selection

**Files:**
- Modify: `MusicWall/Core/AlbumTapCoordinator.swift`
- Modify: `MusicWallTests/Core/AlbumTapCoordinatorTests.swift`

- [ ] **Step 1: Update unit tests to expect return value**

Replace `MusicWallTests/Core/AlbumTapCoordinatorTests.swift` with:

```swift
import Foundation
import Testing
@testable import MusicWall

@Suite struct AlbumTapCoordinatorTests {
    @Test func deselectPausesAndClearsSelection() async {
        let playback = MockPlaybackController()
        let albumID = AlbumID(rawValue: "album-1")

        let selected = await AlbumTapCoordinator.handleTap(
            albumID: albumID,
            rawSelectedID: "album-1",
            playback: playback
        )

        #expect(playback.pauseCallCount == 1)
        #expect(playback.playCalls.isEmpty)
        #expect(selected == nil)
    }

    @Test func newSelectionPlaysAlbum() async {
        let playback = MockPlaybackController()
        let albumID = AlbumID(rawValue: "album-2")

        let selected = await AlbumTapCoordinator.handleTap(
            albumID: albumID,
            rawSelectedID: nil,
            playback: playback
        )

        #expect(playback.playCalls == [albumID])
        #expect(selected == "album-2")
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
xcodebuild test -project MusicWall.xcodeproj -scheme MusicWall \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:MusicWallTests/AlbumTapCoordinatorTests 2>&1 | tail -15
```

Expected: FAIL — compile error (return type mismatch or missing return).

- [ ] **Step 3: Update `AlbumTapCoordinator` implementation**

Replace `MusicWall/Core/AlbumTapCoordinator.swift` with:

```swift
import Foundation

enum AlbumTapCoordinator {
    static func handleTap(
        albumID: AlbumID,
        rawSelectedID: String?,
        playback: any PlaybackController
    ) async -> String? {
        let rawAlbumID = albumID.rawValue
        if rawSelectedID == rawAlbumID {
            playback.pause()
            return nil
        } else {
            _ = try? await playback.play(albumId: albumID)
            return rawAlbumID
        }
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
xcodebuild test -project MusicWall.xcodeproj -scheme MusicWall \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:MusicWallTests/AlbumTapCoordinatorTests 2>&1 | tail -10
```

Expected: `** TEST SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add MusicWall/Core/AlbumTapCoordinator.swift MusicWallTests/Core/AlbumTapCoordinatorTests.swift
git commit -m "refactor: AlbumTapCoordinator returns selection instead of setter closure"
```

---

### Task 2: Update `LayoutViews` tap call sites

**Files:**
- Modify: `MusicWall/LayoutViews.swift:78-86` (grid)
- Modify: `MusicWall/LayoutViews.swift:181-189` (list)

- [ ] **Step 1: Update grid tap handler**

Replace the grid `.onTapGesture` body:

```swift
                        .onTapGesture {
                            Task {
                                selectedAlbumID = await AlbumTapCoordinator.handleTap(
                                    albumID: AlbumID(rawValue: album.id.rawValue),
                                    rawSelectedID: selectedAlbumID,
                                    playback: playback
                                )
                            }
                        }
```

- [ ] **Step 2: Update list tap handler**

Replace the list `.onTapGesture` body the same way (inside `ListLayout` / list `ForEach`).

- [ ] **Step 3: Build app target with strict concurrency probe**

```bash
xcodebuild build -project MusicWall.xcodeproj -scheme MusicWall \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  SWIFT_STRICT_CONCURRENCY=complete \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=NO \
  GCC_TREAT_WARNINGS_AS_ERRORS=NO 2>&1 | \
  grep -E 'LayoutViews.swift.*warning:|LayoutViews.swift.*error:' || echo "LayoutViews clean"
```

Expected: `LayoutViews clean` (no LayoutViews strict-concurrency lines).

- [ ] **Step 4: Commit**

```bash
git add MusicWall/LayoutViews.swift
git commit -m "fix: apply AlbumTapCoordinator return value in LayoutViews tap handlers"
```

---

### Task 3: Make `ImageCache` `Sendable`

**Files:**
- Modify: `MusicWall/ImageCache.swift:8`

- [ ] **Step 1: Try synthesized `Sendable`**

Change the struct declaration:

```swift
struct ImageCache: Sendable {
```

- [ ] **Step 2: Build and check for Sendable errors**

```bash
xcodebuild build -project MusicWall.xcodeproj -scheme MusicWall \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  SWIFT_STRICT_CONCURRENCY=complete \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=NO \
  GCC_TREAT_WARNINGS_AS_ERRORS=NO 2>&1 | \
  grep -E 'ImageCache.swift.*(warning|error):' || echo "ImageCache Sendable OK"
```

Expected: either `ImageCache Sendable OK`, or errors about `FileManager` not being `Sendable`.

- [ ] **Step 3: Fall back to `@unchecked Sendable` if Step 2 failed**

If the compiler rejects synthesized conformance, use:

```swift
// FileManager is not Sendable; cache reads/writes use a dedicated directory synchronously.
struct ImageCache: @unchecked Sendable {
```

Re-run the build grep from Step 2. Expected: no `ImageCache` or `CarPlayCoordinator.swift:140` data-race warnings.

- [ ] **Step 4: Run ImageCache unit tests**

```bash
xcodebuild test -project MusicWall.xcodeproj -scheme MusicWall \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:MusicWallTests/ImageCacheTests 2>&1 | tail -10
```

Expected: `** TEST SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add MusicWall/ImageCache.swift
git commit -m "fix: mark ImageCache Sendable for strict concurrency"
```

---

### Task 4: CarPlay isolation fixes

**Files:**
- Modify: `MusicWall/Adapters/CarPlay/CarPlaySetupTemplate.swift`
- Modify: `MusicWall/Adapters/CarPlay/CarPlayBarButtons.swift`

- [ ] **Step 1: Mark `CarPlaySetupTemplate` `@MainActor`**

Replace file contents:

```swift
import CarPlay

@MainActor
enum CarPlaySetupTemplate {
    static func make() -> CPInformationTemplate {
        let item = CPInformationItem(
            title: CarPlayCopy.appName,
            detail: CarPlayCopy.setupDetail
        )
        return CPInformationTemplate(
            title: CarPlayCopy.appName,
            layout: .leading,
            items: [item],
            actions: []
        )
    }
}
```

- [ ] **Step 2: Mark `CarPlayBarButtons` `@MainActor` and use `assumeIsolated`**

Replace file contents:

```swift
import CarPlay
import UIKit

@MainActor
enum CarPlayBarButtons {
    static func shuffle(handler: @escaping @MainActor (CPBarButton) -> Void) -> CPBarButton {
        imageButton(systemName: "shuffle", handler: handler)
    }

    private static func symbolImage(_ name: String) -> UIImage {
        UIImage(systemName: name) ?? UIImage()
    }

    private static func imageButton(
        systemName: String,
        handler: @escaping @MainActor (CPBarButton) -> Void
    ) -> CPBarButton {
        CPBarButton(image: symbolImage(systemName)) { button in
            MainActor.assumeIsolated {
                handler(button)
            }
        }
    }
}
```

- [ ] **Step 3: Verify CarPlay strict-concurrency diagnostics cleared**

```bash
xcodebuild build -project MusicWall.xcodeproj -scheme MusicWall \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  SWIFT_STRICT_CONCURRENCY=complete \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=NO \
  GCC_TREAT_WARNINGS_AS_ERRORS=NO 2>&1 | \
  grep -E 'CarPlay(SetupTemplate|BarButtons|Coordinator).*warning:|CarPlay(SetupTemplate|BarButtons|Coordinator).*error:' || echo "CarPlay clean"
```

Expected: `CarPlay clean`

- [ ] **Step 4: Commit**

```bash
git add MusicWall/Adapters/CarPlay/CarPlaySetupTemplate.swift \
  MusicWall/Adapters/CarPlay/CarPlayBarButtons.swift
git commit -m "fix: CarPlay strict-concurrency isolation (@MainActor, assumeIsolated)"
```

---

### Task 5: Enable `SWIFT_STRICT_CONCURRENCY` on app target

**Files:**
- Modify: `MusicWall.xcodeproj/project.pbxproj` — `835DD994` (MusicWall Debug) and `835DD995` (MusicWall Release)

- [ ] **Step 1: Confirm baseline is zero before enabling**

```bash
xcodebuild build -project MusicWall.xcodeproj -scheme MusicWall \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  SWIFT_STRICT_CONCURRENCY=complete \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=NO \
  GCC_TREAT_WARNINGS_AS_ERRORS=NO 2>&1 | \
  grep -E 'MusicWall/.*warning:|MusicWall/.*error:' | grep -v appintentsmetadataprocessor || echo "baseline zero"
```

Expected: `baseline zero`

- [ ] **Step 2: Add build setting to MusicWall Debug and Release**

In `MusicWall.xcodeproj/project.pbxproj`, add to **MusicWall app target only** (blocks `835DD994` Debug and `835DD995` Release — `PRODUCT_BUNDLE_IDENTIFIER = chris.MusicWall`):

```text
				SWIFT_STRICT_CONCURRENCY = complete;
```

Place immediately before `SWIFT_TREAT_WARNINGS_AS_ERRORS = YES;` in both configurations.

Do **not** add to `MusicWallTests` or `MusicWallUITests` blocks.

- [ ] **Step 3: Verify settings present**

```bash
grep -B5 'SWIFT_STRICT_CONCURRENCY' MusicWall.xcodeproj/project.pbxproj
grep -c 'SWIFT_STRICT_CONCURRENCY' MusicWall.xcodeproj/project.pbxproj
```

Expected: exactly **2** occurrences, both adjacent to `chris.MusicWall` bundle ID blocks.

- [ ] **Step 4: Commit**

```bash
git add MusicWall.xcodeproj/project.pbxproj
git commit -m "ci: enable SWIFT_STRICT_CONCURRENCY=complete on MusicWall app target"
```

---

### Task 6: Verify locally (positive + negative)

**Files:**
- Temporarily modify: `MusicWall/Adapters/CarPlay/CarPlaySetupTemplate.swift` (negative case only — revert before commit)

- [ ] **Step 1: Full CI lane — positive case**

```bash
cd fastlane
bundle exec fastlane ci_tests
```

Expected: PASS. At end of log, `check_warnings.sh` summary shows `app: 0`, `tests: 0`, `ui_tests: 0`, `other: 0`.

- [ ] **Step 2: Negative case — deliberate app strict-concurrency failure**

Temporarily remove `@MainActor` from `MusicWall/Adapters/CarPlay/CarPlaySetupTemplate.swift` (revert the Task 4 change only for this probe).

Run:

```bash
xcodebuild build -project MusicWall.xcodeproj -scheme MusicWall \
  -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -20
```

Expected: `** BUILD FAILED **` with `CarPlaySetupTemplate.swift` — main-actor-isolated initializer in synchronous nonisolated context (warnings treated as errors).

- [ ] **Step 3: Revert the deliberate probe**

Restore `@MainActor` on `CarPlaySetupTemplate`. Do not commit the probe change.

- [ ] **Step 4: Final full CI run**

```bash
cd fastlane
bundle exec fastlane ci_tests
```

Expected: PASS with all warning buckets at zero.

---

### Task 7: Update documentation

**Files:**
- Modify: `Agent.md:139-144`
- Modify: `docs/specs/2026-06-08-swift-warnings-strategy-design.md:159-163`
- Modify: `.github/pull_request_template.md:17`

- [ ] **Step 1: Update `Agent.md` warnings policy**

Replace the Warnings policy subsection with:

```markdown
### Warnings policy

- **All targets (`MusicWall/`, `MusicWallTests/`, `MusicWallUITests/`):** zero compiler warnings — `SWIFT_TREAT_WARNINGS_AS_ERRORS` and `GCC_TREAT_WARNINGS_AS_ERRORS` are enabled on the app and both test targets. CI fails at compile time if a PR introduces a warning in any target.
- **App strict concurrency:** `SWIFT_STRICT_CONCURRENCY = complete` on the `MusicWall` app target only (Phase 3). Test targets use default checking until a future phase.
- **Tooling noise:** `appintentsmetadataprocessor` "Metadata extraction skipped" lines are allowlisted in `Scripts/check_warnings.sh` (report-only).
- **Future:** phase 4 assesses Swift 6 language mode.
- **Specs:** Phase 1 — `docs/specs/2026-06-08-swift-warnings-strategy-design.md`; Phase 2 — `docs/specs/2026-06-08-swift-warnings-phase2-design.md`; Phase 3 — `docs/specs/2026-06-08-swift-warnings-phase3-design.md`.
```

- [ ] **Step 2: Update parent spec future-phases table**

In `docs/specs/2026-06-08-swift-warnings-strategy-design.md`, replace the Phase 3 row:

```markdown
| 3 | **Done** — strict concurrency on app target. See `docs/specs/2026-06-08-swift-warnings-phase3-design.md` |
```

- [ ] **Step 3: Update PR template**

Change line 17 in `.github/pull_request_template.md`:

```markdown
- [ ] No new compiler warnings in any target (CI enforces via warnings-as-errors; app target also uses `SWIFT_STRICT_CONCURRENCY = complete`)
```

- [ ] **Step 4: Commit**

```bash
git add Agent.md \
  docs/specs/2026-06-08-swift-warnings-strategy-design.md \
  .github/pull_request_template.md
git commit -m "docs: update warnings policy for phase 3 strict concurrency"
```

---

## Acceptance checklist

- [ ] `bundle exec fastlane ci_tests` passes with zero warnings in all `check_warnings.sh` buckets.
- [ ] `SWIFT_STRICT_CONCURRENCY = complete` on `MusicWall` only (Debug + Release).
- [ ] `MusicWallTests` and `MusicWallUITests` do **not** have strict concurrency enabled.
- [ ] All six baseline diagnostics resolved without `@preconcurrency` imports.
- [ ] Deliberate app strict-concurrency diagnostic causes compile failure (verified, reverted).
- [ ] Docs updated; parent spec Phase 3 row marked Done.

## PR delivery

- **Title:** `ci: strict concurrency on app target (phase 3)`
- **Body:** Link `docs/specs/2026-06-08-swift-warnings-phase3-design.md` and parent spec; paste baseline inventory (six warnings) and post-fix `check_warnings.sh` summary (all buckets zero); note whether `ImageCache` needed `@unchecked Sendable`; confirm negative-case verification done locally.
- **Human verification:** Confirm `project.pbxproj` has `SWIFT_STRICT_CONCURRENCY = complete` on `MusicWall` target only (two occurrences).

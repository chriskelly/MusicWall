# PR 2 — Core domain + AlbumSorter Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extract pure album sorting into `MusicWall/Core/`, cover it with golden Swift Testing fixtures, and delegate `StoredAlbums.applySort()` through a thin adapter without changing persistence or UI contracts.

**Architecture:** Foundation-only Core types (`AlbumID`, `AlbumRecord`, `AlbumSortKey`, `AlbumSorter`) live under `MusicWall/Core/`. The app target adds `StoredAlbum+AlbumRecord.swift` for MusicKit bridging. `StoredAlbums.applySort()` maps to records, sorts via `AlbumSorter`, and rebuilds `[StoredAlbum]` by ID lookup.

**Tech Stack:** Swift 5, Swift Testing, Xcode 16+, scheme `MusicWall`, simulator `iPhone 17`, `bundle exec fastlane ci_test`.

**Spec:** `docs/specs/2026-05-27-pr-02-core-album-sorter-design.md`

**Branch:** `cursor/test-refactor-pr-02-core-album-sorter-c3d5`

---

## File map

| Action | Path | Notes |
|--------|------|-------|
| Create | `MusicWall/Core/AlbumID.swift` | Foundation only |
| Create | `MusicWall/Core/AlbumRecord.swift` | Foundation only |
| Create | `MusicWall/Core/AlbumSortKey.swift` | Foundation only |
| Create | `MusicWall/Core/AlbumSorter.swift` | Verbatim comparators from legacy `applySort()` |
| Create | `MusicWall/StoredAlbum+AlbumRecord.swift` | Adapter + `SortOptions.albumSortKey` |
| Modify | `MusicWall/Album.swift` | Replace inline comparators with delegation |
| Create | `MusicWallTests/Fixtures/AlbumFixtures.swift` | Shared UTC dates + `baseTrio` records (reused PR 4+) |
| Create | `MusicWallTests/Core/AlbumSorterTests.swift` | Golden matrix + edge cases; uses `AlbumFixtures` |
| Modify | `MusicWall.xcodeproj/project.pbxproj` | Register new test files in `MusicWallTests` target |

**Xcode note:** The `MusicWall` app target uses `PBXFileSystemSynchronizedRootGroup` on the `MusicWall/` folder — new files there are picked up automatically. Test files under `MusicWallTests/` must be registered in `project.pbxproj` manually (mirror `SmokeTests.swift`).

**Fixtures note:** `AlbumFixtures.baseTrio` is the canonical three-album sample for unit tests (mirrors `StoredAlbums.dummyData()` content with stable IDs/dates). Golden **sort order** expectations stay in `AlbumSorterTests`. PR 6 migration will add JSON files under the same `MusicWallTests/Fixtures/` folder.

---

## Golden fixture reference

`AlbumFixtures.baseTrio` (defined in `MusicWallTests/Fixtures/AlbumFixtures.swift`):

| ID | Title | Artist | `releaseDate` (UTC) |
|----|-------|--------|---------------------|
| `fixture-drake` | Take Care | Drake | 2011-11-15 |
| `fixture-cole` | Born Sinners | J. Cole | `nil` |
| `fixture-kendrick` | Good Kid, m.A.A.d City | Kendrick Lamar | 2012-10-22 |

Expected order (base trio only):

| Key | Ascending IDs | Descending IDs |
|-----|---------------|----------------|
| `.artist` | drake, cole, kendrick | kendrick, cole, drake |
| `.title` | cole, kendrick, drake | drake, kendrick, cole |
| `.year` | drake, kendrick, cole | kendrick, drake, cole |

---

### Task 1: Core domain types

**Files:**
- Create: `MusicWall/Core/AlbumID.swift`
- Create: `MusicWall/Core/AlbumRecord.swift`
- Create: `MusicWall/Core/AlbumSortKey.swift`

- [ ] **Step 1: Create `AlbumID.swift`**

```swift
import Foundation

struct AlbumID: RawRepresentable, Codable, Hashable, Sendable {
    let rawValue: String
}
```

- [ ] **Step 2: Create `AlbumRecord.swift`**

```swift
import Foundation

struct AlbumRecord: Equatable, Sendable {
    let id: AlbumID
    let title: String
    let artistName: String
    let releaseDate: Date?
}
```

- [ ] **Step 3: Create `AlbumSortKey.swift`**

```swift
import Foundation

enum AlbumSortKey: String, CaseIterable, Sendable {
    case artist
    case title
    case year
}
```

- [ ] **Step 4: Build app target to verify Core compiles**

Run:

```bash
xcodebuild build -project MusicWall.xcodeproj -scheme MusicWall \
  -destination 'platform=iOS Simulator,name=iPhone 17' -quiet
```

Expected: `BUILD SUCCEEDED`

- [ ] **Step 5: Commit**

```bash
git add MusicWall/Core/
git commit -m "feat(core): Add AlbumID, AlbumRecord, and AlbumSortKey"
```

---

### Task 2: Shared fixtures + `AlbumSorter` failing tests

**Files:**
- Create: `MusicWallTests/Fixtures/AlbumFixtures.swift`
- Create: `MusicWallTests/Core/AlbumSorterTests.swift`
- Modify: `MusicWall.xcodeproj/project.pbxproj`

- [ ] **Step 1: Create `AlbumFixtures.swift`**

```swift
import Foundation
@testable import MusicWall

enum AlbumFixtures {
    static var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    static func utcDate(year: Int, month: Int, day: Int) -> Date {
        utcCalendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    static func record(
        id: String,
        title: String,
        artistName: String,
        releaseDate: Date? = nil
    ) -> AlbumRecord {
        AlbumRecord(
            id: AlbumID(rawValue: id),
            title: title,
            artistName: artistName,
            releaseDate: releaseDate
        )
    }

    /// Canonical three-album sample (stable IDs/dates). Reused by PR 4+ collection tests.
    static var baseTrio: [AlbumRecord] {
        [
            record(id: "fixture-drake", title: "Take Care", artistName: "Drake", releaseDate: utcDate(year: 2011, month: 11, day: 15)),
            record(id: "fixture-cole", title: "Born Sinners", artistName: "J. Cole", releaseDate: nil),
            record(id: "fixture-kendrick", title: "Good Kid, m.A.A.d City", artistName: "Kendrick Lamar", releaseDate: utcDate(year: 2012, month: 10, day: 22)),
        ]
    }
}
```

- [ ] **Step 2: Register test files in Xcode project**

Add both files to the `MusicWallTests` target (Sources build phase + group), following the same pattern as `SmokeTests.swift`:

1. `MusicWallTests/Fixtures/AlbumFixtures.swift`
2. `MusicWallTests/Core/AlbumSorterTests.swift`

For each: `PBXFileReference`, `PBXBuildFile` in Sources phase, entry under `MusicWallTests` group (use `Fixtures` / `Core` subgroups).

Or open Xcode → add existing files → check `MusicWallTests` target membership.

- [ ] **Step 3: Write `AlbumSorterTests.swift` (tests will fail — `AlbumSorter` not implemented yet)**

```swift
import Foundation
import Testing
@testable import MusicWall

struct AlbumSorterTests {
    private func sortedIDs(
        _ albums: [AlbumRecord],
        key: AlbumSortKey,
        ascending: Bool
    ) -> [String] {
        AlbumSorter.sorted(albums, key: key, ascending: ascending).map(\.id.rawValue)
    }

    @Test(arguments: [
        (AlbumSortKey.artist, true, ["fixture-drake", "fixture-cole", "fixture-kendrick"]),
        (AlbumSortKey.artist, false, ["fixture-kendrick", "fixture-cole", "fixture-drake"]),
        (AlbumSortKey.title, true, ["fixture-cole", "fixture-kendrick", "fixture-drake"]),
        (AlbumSortKey.title, false, ["fixture-drake", "fixture-kendrick", "fixture-cole"]),
        (AlbumSortKey.year, true, ["fixture-drake", "fixture-kendrick", "fixture-cole"]),
        (AlbumSortKey.year, false, ["fixture-kendrick", "fixture-drake", "fixture-cole"]),
    ])
    func goldenSortOrder(key: AlbumSortKey, ascending: Bool, expectedIDs: [String]) {
        let result = sortedIDs(AlbumFixtures.baseTrio, key: key, ascending: ascending)
        #expect(result == expectedIDs)
    }

    @Test
    func artistSortIsCaseInsensitive() {
        let albums = [
            AlbumFixtures.record(id: "lower", title: "x", artistName: "beta"),
            AlbumFixtures.record(id: "upper", title: "y", artistName: "ALPHA"),
        ]
        let ascending = sortedIDs(albums, key: .artist, ascending: true)
        #expect(ascending == ["upper", "lower"])
        let descending = sortedIDs(albums, key: .artist, ascending: false)
        #expect(descending == ["lower", "upper"])
    }

    @Test
    func titleSortIsCaseInsensitive() {
        let albums = [
            AlbumFixtures.record(id: "lower", title: "hello", artistName: "A"),
            AlbumFixtures.record(id: "upper", title: "HELLO", artistName: "B"),
        ]
        let ascending = sortedIDs(albums, key: .title, ascending: true)
        #expect(ascending == ["lower", "upper"])
    }

    @Test
    func nilReleaseDateSortsLastAscendingYear() {
        let result = sortedIDs(AlbumFixtures.baseTrio, key: .year, ascending: true)
        #expect(result.last == "fixture-cole")
    }

    @Test
    func nilReleaseDateSortsLastDescendingYear() {
        let result = sortedIDs(AlbumFixtures.baseTrio, key: .year, ascending: false)
        #expect(result.last == "fixture-cole")
    }
}
```

- [ ] **Step 4: Run tests to verify they fail**

Run:

```bash
xcodebuild test -project MusicWall.xcodeproj -scheme MusicWall \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:MusicWallTests/AlbumSorterTests 2>&1 | tail -20
```

Expected: FAIL — `AlbumSorter` not found / cannot compile

- [ ] **Step 5: Commit failing tests**

```bash
git add MusicWallTests/Fixtures/AlbumFixtures.swift MusicWallTests/Core/AlbumSorterTests.swift MusicWall.xcodeproj/project.pbxproj
git commit -m "test: Add AlbumFixtures and AlbumSorter golden sort matrix (red)"
```

---

### Task 3: Implement `AlbumSorter`

**Files:**
- Create: `MusicWall/Core/AlbumSorter.swift`

- [ ] **Step 1: Create `AlbumSorter.swift`**

```swift
import Foundation

enum AlbumSorter {
    static func sorted(
        _ albums: [AlbumRecord],
        key: AlbumSortKey,
        ascending: Bool
    ) -> [AlbumRecord] {
        var copy = albums
        switch key {
        case .artist:
            if ascending {
                copy.sort { $0.artistName.lowercased() < $1.artistName.lowercased() }
            } else {
                copy.sort { $0.artistName.lowercased() > $1.artistName.lowercased() }
            }
        case .title:
            if ascending {
                copy.sort { $0.title.lowercased() < $1.title.lowercased() }
            } else {
                copy.sort { $0.title.lowercased() > $1.title.lowercased() }
            }
        case .year:
            if ascending {
                copy.sort { ($0.releaseDate ?? Date.distantFuture) < ($1.releaseDate ?? Date.distantFuture) }
            } else {
                copy.sort { ($0.releaseDate ?? Date.distantPast) > ($1.releaseDate ?? Date.distantPast) }
            }
        }
        return copy
    }
}
```

- [ ] **Step 2: Run AlbumSorter tests**

Run:

```bash
xcodebuild test -project MusicWall.xcodeproj -scheme MusicWall \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:MusicWallTests/AlbumSorterTests 2>&1 | tail -20
```

Expected: all `AlbumSorterTests` PASS

- [ ] **Step 3: Commit**

```bash
git add MusicWall/Core/AlbumSorter.swift
git commit -m "feat(core): Add AlbumSorter with legacy comparators"
```

---

### Task 4: Adapter — `StoredAlbum` ↔ `AlbumRecord`

**Files:**
- Create: `MusicWall/StoredAlbum+AlbumRecord.swift`

- [ ] **Step 1: Create adapter file**

```swift
import Foundation
import MusicKit

extension StoredAlbum {
    var asAlbumRecord: AlbumRecord {
        AlbumRecord(
            id: AlbumID(rawValue: id.rawValue),
            title: title,
            artistName: artistName,
            releaseDate: releaseDate
        )
    }
}

extension StoredAlbums.SortOptions {
    var albumSortKey: AlbumSortKey {
        switch self {
        case .artist: .artist
        case .title: .title
        case .date: .year
        }
    }
}
```

- [ ] **Step 2: Build app target**

Run:

```bash
xcodebuild build -project MusicWall.xcodeproj -scheme MusicWall \
  -destination 'platform=iOS Simulator,name=iPhone 17' -quiet
```

Expected: `BUILD SUCCEEDED`

- [ ] **Step 3: Commit**

```bash
git add MusicWall/StoredAlbum+AlbumRecord.swift
git commit -m "feat: Add StoredAlbum to AlbumRecord adapter"
```

---

### Task 5: Delegate `StoredAlbums.applySort()`

**Files:**
- Modify: `MusicWall/Album.swift` (replace `applySort()` body, lines ~99–122)

- [ ] **Step 1: Replace `applySort()` with delegation**

Replace the entire `applySort()` function with:

```swift
    func applySort() {
        let ascending = sortDirection[currentSort] ?? true
        let records = items.map(\.asAlbumRecord)
        let sortedRecords = AlbumSorter.sorted(
            records,
            key: currentSort.albumSortKey,
            ascending: ascending
        )
        let byID = Dictionary(uniqueKeysWithValues: items.map { ($0.id.rawValue, $0) })
        items = sortedRecords.compactMap { byID[$0.id.rawValue] }
    }
```

Confirm no inline comparator closures remain in `Album.swift`.

- [ ] **Step 2: Run full test suite**

Run:

```bash
bundle exec fastlane ci_test
```

Expected: all tests PASS (SmokeTests + AlbumSorterTests)

- [ ] **Step 3: Commit**

```bash
git add MusicWall/Album.swift
git commit -m "refactor: Delegate StoredAlbums.applySort to AlbumSorter"
```

---

### Task 6: Final verification and PR prep

**Files:**
- None (verification only)

- [ ] **Step 1: Confirm Core has no forbidden imports**

Run:

```bash
rg "import (MusicKit|SwiftUI|UIKit)" MusicWall/Core/
```

Expected: no matches

- [ ] **Step 2: Confirm UserDefaults keys unchanged**

Run:

```bash
rg "storedAlbumsItemsKey|sortDirectionKey|currentSortKey" MusicWall/
```

Expected: same keys as before; no new keys added

- [ ] **Step 3: Run full CI test lane one more time**

Run:

```bash
bundle exec fastlane ci_test
```

Expected: PASS

- [ ] **Step 4: Push branch and open PR**

Do **not** add the `no-deploy` label — this PR should run the full PR pipeline including TestFlight so sort behavior can be verified on a physical device.

```bash
git push -u origin cursor/test-refactor-pr-02-core-album-sorter-c3d5
gh pr create --title "test refactor PR 2: Core domain + AlbumSorter" --body "$(cat <<'EOF'
## Summary
- Add Foundation-only Core types under `MusicWall/Core/`
- Extract sort comparators into `AlbumSorter` with golden Swift Testing fixtures
- Delegate `StoredAlbums.applySort()` via `StoredAlbum` → `AlbumRecord` adapter

## Test plan
- [ ] `ci-tests` workflow passes (`fastlane ci_test`)
- [ ] `testflight-release` workflow passes (no `no-deploy` label)
- [ ] Sort by Artist / Title / Year on device (TestFlight internal build)
- [ ] No UserDefaults / on-disk format changes

## Spec
docs/specs/2026-05-27-pr-02-core-album-sorter-design.md
EOF
)"
```

- [ ] **Step 5: Monitor PR checks until green**

After opening the PR, watch GitHub Actions until all required checks complete. Fix any failures before merge.

```bash
# PR number from gh pr create output
gh pr checks <PR_NUMBER> --watch
```

Expected workflows:

| Check | Workflow | On failure |
|-------|----------|------------|
| CI Tests | `ci-tests.yml` | Read logs; fix tests/build; push fix |
| TestFlight release | `testflight-release.yml` | Read Fastlane/signing logs; push fix |

Re-run failed jobs after fixes: `gh run rerun <run-id> --failed`

Do not merge until `ci-tests` and `testflight-release` (or whatever the repo requires) are passing.

---

## Spec coverage self-review

| Spec requirement | Task |
|------------------|------|
| `AlbumID`, `AlbumRecord`, `AlbumSortKey` in Core | Task 1 |
| `AlbumSorter.sorted` verbatim comparators | Task 3 |
| Shared `AlbumFixtures.baseTrio` | Task 2 |
| Golden matrix all keys × asc/desc | Task 2 |
| Nil date + case insensitivity tests | Task 2 |
| `StoredAlbum.asAlbumRecord` adapter | Task 4 |
| `SortOptions.albumSortKey` mapping | Task 4 |
| `applySort()` delegation, inline removed | Task 5 |
| Core free of MusicKit/SwiftUI/UIKit | Task 6 step 1 |
| UserDefaults unchanged | Task 6 step 2 |
| CI green (`ci-tests` + `testflight-release`) | Task 5–6 |
| PR checks monitored / failures fixed | Task 6 step 5 |
| No SPM / no persistence migration | Implicit — not in file map |

No placeholders. Type names consistent across tasks.

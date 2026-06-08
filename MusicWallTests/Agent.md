# Agent guide — MusicWallTests

`MusicWallTests` is the deterministic test target for MusicWall. UI smoke tests live in `MusicWallUITests`. Both run through the shared `MusicWall` scheme on the iPhone 17 simulator.

## Test pyramid

| Layer | Target | Framework |
|-------|--------|-----------|
| Core / Adapters / ViewModels | `MusicWallTests` | Swift Testing |
| SwiftUI views (Snackbar, SortMenu, AlbumEdit) | `MusicWallTests` | Swift Testing + ViewInspector |
| End-to-end smoke | `MusicWallUITests` | XCTest / XCUITest |

Layer rules and file placement: `Agent.md` (Architecture section). CI also enforces `Scripts/check_core_imports.sh`.

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

Inspect warnings report only (after a test run produced a log):

```bash
xcodebuild test -project MusicWall.xcodeproj -scheme MusicWall \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  2>&1 | tee build/xcodebuild.log
Scripts/check_warnings.sh build/xcodebuild.log
```

Or re-use the log from `bundle exec fastlane ci_tests` (`build/xcodebuild.log`).

## UI tests

### Launch arguments

| Argument | Required | Values |
|----------|----------|--------|
| `-UITestMockMusic` | Yes (flag) | Enables mock dependencies (no MusicKit / Apple ID) |
| `-UITestLoadScenario` | Yes when mock enabled | `savedLibrary` \| `restoreFromBackup` \| `emptyCollection` |

**savedLibrary** — pre-seeded album records in isolated UserDefaults (typical returning user).

**restoreFromBackup** — pre-seeded backup IDs only; mock repository returns fixture albums on fetch.

**emptyCollection** — no seeded albums; home shows the empty welcome screen.

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
| `home.emptyWelcome` | Empty collection welcome container |
| `home.emptyWelcome.addAlbum` | Welcome primary button |
| `home.emptyWelcome.import` | Welcome import button |
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

Hosted async example:

```swift
try await ViewHosting.host(view) {
    try await view.inspection.inspect { inspected in
        #expect(try inspected.find(button: "Save").isDisabled())
    }
}
```

See the [ViewInspector guide](https://github.com/nalexn/ViewInspector/blob/master/guide.md).

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

## Warnings policy

| Target | CI behavior |
|--------|-------------|
| `MusicWall/` app source | Compile fails on any warning |
| `MusicWallTests/`, `MusicWallUITests/` | Compile fails on any warning |

ViewInspector `InspectionEmissary` shim lives in `TestSupport/ViewInspector+MusicWall.swift` (`@retroactive`, `@unchecked Sendable` if needed). `Scripts/check_warnings.sh` still prints a bucket summary in CI logs but enforcement is compiler-first.

# PR 13 — UI tests + launch configuration

**Status:** Approved (2026-05-31)  
**Program:** MusicWall testability refactor  
**Requires:** PR 8, PR 9 merged (or rebased onto their changes)  
**Blocks:** PR 14  
**Approach:** XCUITest smoke suite + launch-argument mock dependencies + dual load scenarios (saved library + restore from backup) + accessibility playback bridge

## Summary

Add a **`MusicWallUITests`** target and wire **`AppDependencies.uiTest(scenario:)`** behind a launch flag (`-UITestMockMusic`). Four end-to-end smoke tests run on the iPhone 17 simulator without real MusicKit or Apple ID: two launch scenarios (typical saved library and backup-ID restore), album tap → mock playback, and search sheet open/dismiss. Production launch is unchanged when the flag is absent. Extend **`ci-tests`** (via existing `fastlane ci_tests` / `xcodebuild test`) to run UI tests alongside unit tests. Document commands in new **`docs/testing.md`**; unit/ViewInspector docs remain in **`MusicWallTests/Agent.md`**.

## Goals

- **`MusicWallUITests`** target added to Xcode project and **`MusicWall`** scheme `TestAction`.
- **`AppDependencies.uiTest(scenario:)`** with mock auth (authorized), mock repository, mock playback, and scenario-specific preferences seeding.
- Launch arguments read in **`MusicWallApp`**; **`AppDependencies.live`** when arguments absent.
- Smoke tests (minimum four):
  1. Launch (**saved library**) → fixture album titles visible
  2. Launch (**restore from backup**) → same fixture titles visible
  3. Tap album → mock **`play(albumId:)`** invoked (asserted via accessibility bridge)
  4. Open search sheet → dismiss via Cancel
- CI: UI tests pass on GitHub Actions simulator (~+2–3 min acceptable).
- **`docs/testing.md`**: local UI test commands and launch-argument reference.

## Non-goals

- Real Apple Music catalog search in UI tests.
- Coverage gates or thresholds (PR 14).
- Snapshot / reference-image testing.
- Shuffle, sort menu, backup import/export, edit/delete flows.
- Swift Testing for UI tests (XCUITest uses XCTest).
- Skipping **`load()`** or injecting a pre-populated **`HomeViewModel`** (Option C — parallel startup path).

## Decisions (brainstorming)

| Topic | Choice |
|-------|--------|
| Load scenarios | **Both A + B** — two launch scenarios, two XCTest methods, shared assertions |
| Saved library (A) | Pre-seed **`.albumRecordsItems`** with **`UITestFixtures.baseTrio`** in isolated UserDefaults |
| Restore (B) | Pre-seed **`.backupAlbumIDs`** only; **`UITestAlbumRepository.fetch`** returns **`baseTrio`** |
| Fixture source | **`UITestFixtures`** in main target; values must match **`AlbumFixtures.baseTrio`** in unit tests |
| Playback assertion | **Accessibility bridge** — hidden element **`uitest.lastPlayedAlbum`** exposes last played ID |
| Search dismiss | **Cancel toolbar button** with **`search.cancel`** identifier (not swipe-only) |
| Test framework | **XCTest / XCUITest** |
| CI | Extend existing **`ci-tests`** workflow — no separate lane required |
| Documentation | **`docs/testing.md`** for UI tests; **`MusicWallTests/Agent.md`** unchanged scope (unit + ViewInspector) |

## Approaches considered

### Album data on launch

| Option | Description | Why not chosen |
|--------|-------------|----------------|
| **A + B (chosen)** | Pre-seed prefs (saved) or backup IDs + mock fetch (restore); two launches | — |
| A only | Saved library path only | Misses backup-restore wiring smoke |
| C | Skip **`load()`**, inject pre-populated ViewModel | Parallel startup path; drifts from production |

### Playback assertion

| Option | Description | Why not chosen |
|--------|-------------|----------------|
| **Accessibility bridge (chosen)** | **`UITestPlaybackController`** + hidden reader view exposes ID to XCUITest | — |
| Tap-only | Assert selection UI only | Does not prove **`PlaybackController`** DI/wiring |
| File / UserDefaults IPC | App writes state test reads from disk | XCUITest cannot read app UserDefaults; file IPC is brittle |

### Search sheet dismiss

| Option | Description | Why not chosen |
|--------|-------------|----------------|
| **Cancel button (chosen)** | Explicit Cancel with accessibility id | — |
| Swipe to dismiss | No production change | Flaky in CI; no explicit affordance today |

## Architecture

### Launch dependency resolution

```
MusicWallApp
  │
  ├─ arguments contain "-UITestMockMusic"?
  │     no  → AppDependencies.live          (unchanged production path)
  │     yes → AppDependencies.uiTest(scenario:)
  │              scenario from "-UITestLoadScenario savedLibrary|restoreFromBackup"
  │
  └─ ContentView(dependencies:)
        → AuthViewModel → authorized (mock)
        → HomePageView → .task { await viewModel.load() }
```

**Launch arguments**

| Argument | Required | Values |
|----------|----------|--------|
| `-UITestMockMusic` | Yes (flag) | — enables mock dependencies |
| `-UITestLoadScenario` | Yes when mock enabled | `savedLibrary` \| `restoreFromBackup` |

### `AppDependencies.uiTest(scenario:)`

| Dependency | Implementation |
|------------|----------------|
| `preferencesStore` | `UserDefaultsPreferencesStore` on suite `com.musicwall.uitest.<scenario>.<UUID>` |
| `albumRepository` | `UITestAlbumRepository` — `fetch(ids:)` returns matching records from **`UITestFixtures.baseTrio`**; `search` returns `[]` |
| `playbackController` | `UITestPlaybackController` — records **`lastPlayedAlbumID`** on **`play(albumId:)`** |
| `musicAuthorization` | `PreviewMusicAuthorizationProvider(status: .authorized)` |
| `artworkProvider` | `PreviewArtworkProvider()` |
| `albumBackupService` | `LiveAlbumBackupService()` (unused in smoke flows) |

**Scenario seeding**

| Scenario | Preferences written | `load()` path |
|----------|---------------------|---------------|
| `savedLibrary` | **`UITestFixtures.baseTrio`** → `.albumRecordsItems` | First branch — synchronous |
| `restoreFromBackup` | Backup ID strings (`fixture-drake`, …) → `.backupAlbumIDs`; no album items | Third branch — async **`fetch`** |

Each launch uses a **fresh UserDefaults suite** (UUID suffix) so scenarios do not leak state across tests.

### UITest playback bridge

Only present when `-UITestMockMusic` is set:

1. **`UITestPlaybackController`** stores the last **`AlbumID.rawValue`** passed to **`play(albumId:)`**.
2. **`UITestStateReader`** (hidden overlay in **`ContentView`** or **`HomePageView`**) binds to the controller and sets:
   - `accessibilityIdentifier`: `uitest.lastPlayedAlbum`
   - `accessibilityValue`: last played album ID (empty until first play)

XCUITest asserts **`value`** after tapping an album title. Single tap only (second tap on same album calls **`pause()`** per **`AlbumTapCoordinator`**).

### File layout

```
MusicWall/
  UITestSupport/
    UITestFixtures.swift           # baseTrio — mirror AlbumFixtures.baseTrio IDs/titles
    UITestLoadScenario.swift       # enum + ProcessInfo parsing
    UITestAlbumRepository.swift
    UITestPlaybackController.swift
    UITestStateReader.swift        # accessibility bridge view
  AppDependencies.swift            # + uiTest(scenario:)
  MusicWallApp.swift               # resolveDependencies()

MusicWallUITests/
  MusicWallUITests.swift           # or split by flow
  UITestLaunch.swift               # launchApp(scenario:), assertFixtureAlbumsVisible

MusicWall/Features/
  Home/HomePageView.swift          # accessibilityIdentifier on Add button
  Search/AlbumSearchView.swift     # Cancel toolbar + search.cancel id

docs/
  testing.md                       # UI test commands + launch args
```

## Test cases

### Shared helpers (UITest target)

```swift
func launchApp(scenario: String) -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments += ["-UITestMockMusic", "-UITestLoadScenario", scenario]
    app.launch()
    return app
}

func assertFixtureAlbumsVisible(in app: XCUIApplication, timeout: TimeInterval = 5) {
    XCTAssertTrue(app.staticTexts["Take Care"].waitForExistence(timeout: timeout))
    XCTAssertTrue(app.staticTexts["Born Sinners"].waitForExistence(timeout: timeout))
    XCTAssertTrue(app.staticTexts["Good Kid, m.A.A.d City"].waitForExistence(timeout: timeout))
}
```

### `testLaunch_savedLibrary_showsFixtureTitles`

| Step | Action |
|------|--------|
| Launch | `-UITestLoadScenario savedLibrary` |
| Wait | Navigation title **"My Albums"** (or album list id if added) |
| Assert | **`assertFixtureAlbumsVisible`** |

### `testLaunch_restoreFromBackup_showsFixtureTitles`

| Step | Action |
|------|--------|
| Launch | `-UITestLoadScenario restoreFromBackup` |
| Wait | Same as above; allow slightly longer timeout for async **`fetch`** if needed |
| Assert | Same three titles |

### `testTapAlbum_invokesPlayback`

| Step | Action |
|------|--------|
| Launch | `savedLibrary` |
| Wait | **"Take Care"** visible |
| Tap | **"Take Care"** (first tap — select + play) |
| Assert | `app.otherElements["uitest.lastPlayedAlbum"].value as? String == "fixture-drake"` |

### `testSearchSheet_openAndDismiss`

| Step | Action |
|------|--------|
| Launch | `savedLibrary` |
| Wait | Home loaded |
| Tap | Button **`home.addAlbum`** |
| Wait | **"Find Album"** navigation title |
| Tap | **`search.cancel`** |
| Assert | **"My Albums"** visible; **"Find Album"** does not exist |

## Production UI changes

| View | Change |
|------|--------|
| **`HomePageView`** | `accessibilityIdentifier("home.addAlbum")` on Add toolbar button |
| **`AlbumSearchView`** | Cancel toolbar item, `accessibilityIdentifier("search.cancel")` |
| **`ContentView`** / **`HomePageView`** | Conditional **`UITestStateReader`** when mock launch flag set |

No accessibility identifiers required on individual album tiles — assertions use visible title strings from fixtures.

## Stability rules

- Use **`waitForExistence`** — no fixed **`sleep`**.
- Separate XCTest methods with separate **`launch()`** per scenario; do not switch load mode mid-session.
- Default smoke tests (tap, search) use **`savedLibrary`** (faster, no fetch wait).
- Do not assert on vinyl animation, artwork loading, or snackbar auto-dismiss timing.

## CI

Extend existing **`.github/workflows/ci-tests.yml`** — no new workflow file required:

- **`bundle exec fastlane ci_tests`** → **`xcodebuild test -scheme MusicWall -destination 'platform=iOS Simulator,name=iPhone 17'`**
- Scheme **`TestAction`** includes **`MusicWallTests`** and **`MusicWallUITests`**.
- PR 13 skill reference to **`no-deploy`** means PRs that skip TestFlight still get UI tests via **`ci-tests`** (same job as unit tests today).

Expected runtime increase: ~2–3 minutes for four UI test launches.

## Documentation — `docs/testing.md`

New file covering:

1. **Test pyramid pointer** — unit/ViewInspector in **`MusicWallTests/Agent.md`**; UI smoke here.
2. **Local commands** — `bundle exec fastlane ci_tests`, filtered `xcodebuild test -only-testing:MusicWallUITests/...`.
3. **Launch arguments** — table from Architecture section.
4. **Adding a UI test** — set launch args, use accessibility ids, prefer **`waitForExistence`**.

## Error handling

- Mock auth always returns **`.authorized`** — no denied-state UI tests in PR 13.
- Empty home on failure surfaces as XCTest timeout on fixture titles — no new user-facing error UI.
- **`UITestAlbumRepository.fetch`** returns only matching IDs from **`baseTrio`**; unknown IDs omitted (same as production adapter behavior expectation).

## Acceptance criteria

- [ ] **`MusicWallUITests`** target in project + scheme
- [ ] **`AppDependencies.uiTest(scenario:)`** with **`savedLibrary`** and **`restoreFromBackup`** seeding
- [ ] **`MusicWallApp`** uses **`.live`** when `-UITestMockMusic` absent
- [ ] Four smoke tests pass locally and on GitHub Actions simulator
- [ ] Playback bridge asserts **`fixture-drake`** after tapping **"Take Care"**
- [ ] Search Cancel dismisses sheet reliably
- [ ] **`docs/testing.md`** documents UI test commands and launch args

## Human verification (PR description)

- Run UI tests once in Xcode with mock launch args enabled in scheme (sanity check).
- Confirm Release build without launch args does not include test-only overlay in normal use (flag-gated).
- Spot-check **`restoreFromBackup`** scenario on simulator if CI is slow to fail.

## PR delivery

- Branch: `cursor/test-refactor-pr-13-ui-tests` (or team convention).
- PR title: `test refactor PR 13: XCUITest smoke + launch mocks`
- Link PR 13 of 14; note dual load scenarios and accessibility playback bridge.

## Follow-on PRs

| PR | Relationship |
|----|----------------|
| PR 14 | Coverage policy; may inventory UI smoke tests in docs |
| PR 15 | SPM split; UI test target stays with app |

# MusicWall testing

## Test pyramid

| Layer | Target | Docs |
|-------|--------|------|
| Core / ViewModels / ViewInspector | `MusicWallTests` | [MusicWallTests/Agent.md](../MusicWallTests/Agent.md) |
| End-to-end smoke (simulator) | `MusicWallUITests` | This file |

## Commands

Run all tests (unit + UI):

```bash
bundle exec fastlane ci_tests
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

## UI test launch arguments

| Argument | Required | Values |
|----------|----------|--------|
| `-UITestMockMusic` | Yes (flag) | Enables mock dependencies (no MusicKit / Apple ID) |
| `-UITestLoadScenario` | Yes when mock enabled | `savedLibrary` \| `restoreFromBackup` |

**savedLibrary** — pre-seeded album records in isolated UserDefaults (typical returning user).

**restoreFromBackup** — pre-seeded backup IDs only; mock repository returns fixture albums on fetch.

Production launch omits both arguments and uses `AppDependencies.live`.

## Adding a UI test

1. Launch with `launchArguments` (see helpers in `MusicWallUITests.swift`).
2. Prefer `accessibilityIdentifier` over label text for controls (`home.addAlbum`, `search.cancel`).
3. Use `waitForExistence` — avoid fixed `sleep`.
4. Use a fresh `launch()` per scenario; do not switch load mode mid-session.

## Accessibility identifiers (UI tests)

| Identifier | Element |
|------------|---------|
| `home.addAlbum` | Add album toolbar button |
| `search.cancel` | Search sheet Cancel |
| `uitest.lastPlayedAlbum` | Hidden playback bridge (mock launch only) |

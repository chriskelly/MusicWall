# UI tests

Launch arguments, scenarios, and accessibility identifiers for `MusicWallUITests`. Read before adding or debugging a UI test.

## Launch arguments

| Argument | Required | Values |
|----------|----------|--------|
| `-UITestMockMusic` | Yes (flag) | Enables mock dependencies (no MusicKit or Apple ID) |
| `-UITestLoadScenario` | Yes when mock is enabled | `savedLibrary` \| `restoreFromBackup` \| `emptyCollection` |

- **savedLibrary** — pre-seeded album records in isolated UserDefaults (a typical returning user).
- **restoreFromBackup** — pre-seeded backup IDs only; the mock repository returns fixture albums on fetch.
- **emptyCollection** — no seeded albums; home shows the empty welcome screen.

A production launch omits both arguments and uses `AppDependencies.live`.

## Adding a UI test

1. Launch with `launchArguments` (see the helpers in `MusicWallUITests/MusicWallUITests.swift`).
2. Prefer `accessibilityIdentifier` over label text.
3. Use `waitForExistence`; avoid a fixed `sleep`.
4. Use a fresh `launch()` per scenario; do not switch load mode mid-session.

## Accessibility identifiers

| Identifier | Element |
|------------|---------|
| `home.addAlbum` | Add album toolbar button |
| `home.emptyWelcome` | Empty collection welcome container |
| `home.emptyWelcome.addAlbum` | Welcome primary button |
| `home.emptyWelcome.import` | Welcome import button |
| `search.cancel` | Search sheet Cancel |
| `uitest.lastPlayedAlbum` | Hidden playback bridge (mock launch only) |

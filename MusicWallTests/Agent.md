# Agent guide — MusicWallTests

`MusicWallTests` is the deterministic unit-test target for MusicWall. It runs through the shared `MusicWall` scheme on the iPhone 17 simulator.

## Fixtures

- `MusicWallTests/Fixtures/AlbumFixtures.swift` — canonical `AlbumRecord` samples (`baseTrio`, UTC date helpers). Reused across sort/collection tests; PR 6 adds JSON migration fixtures in the same folder.

## Framework

- Default: Swift Testing
- Fallback: switch this target to XCTest only if Swift Testing causes scheme or CI instability disproportionate to PR 1

## View tests (ViewInspector)

PR 12 adds [ViewInspector](https://github.com/nalexn/ViewInspector) (MIT) for high-value SwiftUI unit tests without XCUITest cost. Linked to **MusicWallTests only** — not the app target.

### Test pyramid

| Layer | Framework | Hosting |
|-------|-----------|---------|
| Core / Adapters / ViewModels | Swift Testing | None |
| SwiftUI views (`SnackbarView`, `SortMenu`, `AlbumEditView`) | Swift Testing + ViewInspector | Sync for simple views; `ViewHosting.host` for `@State` / `@Environment` |

### Adding a view test

1. `import ViewInspector` and `@testable import MusicWall` in the test file.
2. Annotate tests `@MainActor` and `throws` (or `async throws` for hosted views).
3. Prefer `find(text:)` / `find(button:)` over deep hierarchy chains.
4. Test views **in isolation** — e.g. `SortMenu` directly, not inside `Menu`.

### Inspection pattern (`@State` / `@Environment`)

Views with `@State` or `@Environment` need the Inspection helper:

- **Main target:** `MusicWall/TestSupport/Inspection.swift`
- **Test target:** `MusicWallTests/TestSupport/ViewInspector+MusicWall.swift` (`InspectionEmissary`)
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

- No animation timing or auto-dismiss assertions (do not test `.snackbar(isPresented:)` modifier).
- No snapshot reference images.
- No `glassEffect()` branch coverage unless trivial.
- Avoid inspecting content inside `Menu` / `contextMenu` wrappers.

### View test inventory (PR 12)

| Suite | File | Coverage |
|-------|------|----------|
| Snackbar | `UI/SnackbarViewTests.swift` | message, action button, undo callback |
| Sort menu | `UI/SortMenuViewTests.swift` | direction arrow on active sort |
| Edit album | `UI/AlbumEditViewTests.swift` | Save disabled when title whitespace-only |

## Commands

- `bundle exec fastlane ci_tests`
- `xcodebuild test -project MusicWall.xcodeproj -scheme MusicWall -destination 'platform=iOS Simulator,name=iPhone 17'`

## Coverage

- Keep `MusicWallTests` in the shared `MusicWall` scheme `TestAction`
- Keep scheme coverage gathering enabled

## Exclusions

These remain human-verified or future-test work, not deterministic CI coverage:

- live MusicKit authorization
- live Apple Music catalog or library responses
- `SystemMusicPlayer` playback behavior
- device-only behavior that cannot be reproduced on the simulator

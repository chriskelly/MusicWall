# ViewInspector

[ViewInspector](https://github.com/nalexn/ViewInspector) (MIT) enables high-value SwiftUI unit tests without XCUITest cost. It is linked to `MusicWallTests` only. Read before adding a view test.

## Adding a view test

1. `import ViewInspector` and `@testable import MusicWall`.
2. Annotate `@MainActor` and `throws` (or `async throws` for hosted views).
3. Prefer `find(text:)` / `find(button:)` over deep hierarchy chains.
4. Test views in isolation.

## Inspection pattern (`@State` / `@Environment`)

- **Main target:** `MusicWall/TestSupport/Inspection.swift`
- **Test target and shim:** `MusicWallTests/TestSupport/ViewInspector+MusicWall.swift` holds the test-target conformance and the `InspectionEmissary` shim (`@retroactive`, `@unchecked Sendable` where needed).
- **View under test:** `internal let inspection = Inspection<Self>()` plus `.onReceive(inspection.notice) { … }`

Hosted async example:

```swift
try await ViewHosting.host(view) {
    try await view.inspection.inspect { inspected in
        #expect(try inspected.find(button: "Save").isDisabled())
    }
}
```

See the [ViewInspector guide](https://github.com/nalexn/ViewInspector/blob/master/guide.md).

## Inventory

| Suite | File | Coverage |
|-------|------|----------|
| Snackbar | `MusicWallTests/UI/SnackbarViewTests.swift` | message, action button, undo callback |
| Sort menu | `MusicWallTests/UI/SortMenuViewTests.swift` | direction arrow on active sort |
| Edit album | `MusicWallTests/UI/AlbumEditViewTests.swift` | Save disabled when the title is whitespace-only |

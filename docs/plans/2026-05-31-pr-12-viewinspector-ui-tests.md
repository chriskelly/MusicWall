# PR 12 — ViewInspector SwiftUI Unit Tests Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add ViewInspector-backed SwiftUI unit tests for `SnackbarView`, `SortMenu`, and `AlbumEditView`, with minimal Inspection scaffolding and documentation in `MusicWallTests/Agent.md`.

**Architecture:** ViewInspector SPM on `MusicWallTests` only. Sync tests for stateless/`@Bindable` views; async `ViewHosting.host` + Inspection pattern for `AlbumEditView` (`@State` / `@Environment`). Production adds `Inspection.swift` and inspection hooks on `AlbumEditView` only.

**Tech Stack:** Swift 5, Swift Testing, ViewInspector 0.10.x (MIT), SwiftUI, Xcode 26+, scheme `MusicWall`, simulator `iPhone 17`, `bundle exec fastlane ci_tests`.

**Spec:** `docs/specs/2026-05-31-pr-12-viewinspector-ui-tests-design.md`

**Branch:** `cursor/test-refactor-pr-12-viewinspector`

---

## File map

| Action | Path | Notes |
|--------|------|-------|
| Create | `MusicWall/TestSupport/Inspection.swift` | ViewInspector `@State` helper (main target) |
| Modify | `MusicWall/Features/Edit/AlbumEditView.swift` | Add `inspection` + `.onReceive` |
| Create | `MusicWallTests/TestSupport/ViewInspector+MusicWall.swift` | `InspectionEmissary` conformance |
| Create | `MusicWallTests/UI/SnackbarViewTests.swift` | 4 sync tests |
| Create | `MusicWallTests/UI/SortMenuViewTests.swift` | 3 sync tests |
| Create | `MusicWallTests/UI/AlbumEditViewTests.swift` | 2 async hosted tests |
| Modify | `MusicWallTests/Agent.md` | ViewInspector section |
| Modify | `MusicWall.xcodeproj/project.pbxproj` | Register UI test files; SPM package ref |
| Create | `MusicWall.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved` | Created by Xcode on package add |

**Xcode notes:**

- `MusicWall/` uses `PBXFileSystemSynchronizedRootGroup` — `Inspection.swift` auto-joins the app target when created under `MusicWall/TestSupport/`.
- `MusicWallTests/` files must be registered manually in `project.pbxproj` (mirror `SmokeTests.swift`).
- Link **ViewInspector** to **`MusicWallTests`** only — **not** `MusicWall`.

---

### Task 1: Branch + ViewInspector SPM

**Files:**
- Modify: `MusicWall.xcodeproj/project.pbxproj`
- Create: `MusicWall.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved` (via Xcode)

- [ ] **Step 1: Create branch**

```bash
git checkout main
git pull
git checkout -b cursor/test-refactor-pr-12-viewinspector
```

- [ ] **Step 2: Add ViewInspector SPM package**

In Xcode (project `MusicWall`):

1. **File → Add Package Dependencies…**
2. URL: `https://github.com/nalexn/ViewInspector`
3. Dependency rule: **Up to Next Major Version** from `0.10.0`
4. Add product **`ViewInspector`** to target **`MusicWallTests`** only (uncheck `MusicWall`)

Verify:

- `MusicWallTests` → **Frameworks, Libraries, and Embedded Content** includes `ViewInspector`
- `MusicWall` app target does **not** link ViewInspector

- [ ] **Step 3: Resolve packages**

```bash
cd /Users/chris/Projects/MusicWall
xcodebuild -resolvePackageDependencies -project MusicWall.xcodeproj -scheme MusicWall
```

Expected: resolves ViewInspector without error.

- [ ] **Step 4: Commit**

```bash
git add MusicWall.xcodeproj/project.pbxproj MusicWall.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved
git commit -m "chore: Add ViewInspector SPM to MusicWallTests"
```

---

### Task 2: Inspection scaffolding

**Files:**
- Create: `MusicWall/TestSupport/Inspection.swift`
- Create: `MusicWallTests/TestSupport/ViewInspector+MusicWall.swift`

- [ ] **Step 1: Create `Inspection.swift`**

```swift
import Combine
import SwiftUI

internal final class Inspection<V> {
    let notice = PassthroughSubject<UInt, Never>()
    var callbacks = [UInt: (V) -> Void]()

    func visit(_ view: V, _ line: UInt) {
        if let callback = callbacks.removeValue(forKey: line) {
            callback(view)
        }
    }
}
```

- [ ] **Step 2: Create `ViewInspector+MusicWall.swift`**

```swift
import ViewInspector
@testable import MusicWall

extension Inspection: InspectionEmissary {}
```

- [ ] **Step 3: Build app target (Inspection in main module)**

Run:

```bash
xcodebuild build -project MusicWall.xcodeproj -scheme MusicWall -destination 'platform=iOS Simulator,name=iPhone 17' -quiet
```

Expected: BUILD SUCCEEDED

- [ ] **Step 4: Register `ViewInspector+MusicWall.swift` in Xcode project**

Add to `MusicWallTests` → `TestSupport` group and Sources build phase in `project.pbxproj` (mirror `MockAlbumRepository.swift`):

- `PBXFileReference` for `ViewInspector+MusicWall.swift`
- `PBXBuildFile` in `CB9028FC613E793D35916DCD` Sources phase
- Group child under `D5E6F708192A3B4C5D6E7F809 /* TestSupport */`

- [ ] **Step 5: Commit**

```bash
git add MusicWall/TestSupport/Inspection.swift MusicWallTests/TestSupport/ViewInspector+MusicWall.swift MusicWall.xcodeproj/project.pbxproj
git commit -m "feat: Add ViewInspector Inspection scaffolding"
```

---

### Task 3: SnackbarViewTests

**Files:**
- Create: `MusicWallTests/UI/SnackbarViewTests.swift`
- Modify: `MusicWall.xcodeproj/project.pbxproj`

- [ ] **Step 1: Create `UI` group + register in project**

Add `UI` group under `MusicWallTests` in `project.pbxproj`.

- [ ] **Step 2: Write `SnackbarViewTests.swift`**

```swift
import SwiftUI
import Testing
import ViewInspector
@testable import MusicWall

struct SnackbarViewTests {
    @Test @MainActor
    func displaysMessage() throws {
        let sut = SnackbarView(message: "Added 3 albums")

        _ = try sut.inspect().find(text: "Added 3 albums")
    }

    @Test @MainActor
    func showsActionButton_whenLabelProvided() throws {
        let sut = SnackbarView(
            message: "Item added",
            actionLabel: "Undo",
            action: {}
        )

        _ = try sut.inspect().find(button: "Undo")
    }

    @Test @MainActor
    func actionButton_invokesCallback() throws {
        var didUndo = false
        let sut = SnackbarView(
            message: "Item added",
            actionLabel: "Undo",
            action: { didUndo = true }
        )

        try sut.inspect().find(button: "Undo").tap()

        #expect(didUndo)
    }

    @Test @MainActor
    func hidesActionButton_whenLabelNil() throws {
        let sut = SnackbarView(message: "Done")

        #expect(throws: (any Error).self) {
            try sut.inspect().find(button: "Undo")
        }
    }
}
```

- [ ] **Step 3: Register file in project + run tests**

Register `SnackbarViewTests.swift` in `project.pbxproj` Sources phase.

Run:

```bash
xcodebuild test -project MusicWall.xcodeproj -scheme MusicWall -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MusicWallTests/SnackbarViewTests 2>&1 | tail -20
```

Expected: all 4 tests PASS (or suite runs green).

- [ ] **Step 4: Commit**

```bash
git add MusicWallTests/UI/SnackbarViewTests.swift MusicWall.xcodeproj/project.pbxproj
git commit -m "test: Add SnackbarView ViewInspector tests"
```

---

### Task 4: SortMenuViewTests

**Files:**
- Create: `MusicWallTests/UI/SortMenuViewTests.swift`
- Modify: `MusicWall.xcodeproj/project.pbxproj`

- [ ] **Step 1: Write `SortMenuViewTests.swift`**

```swift
import SwiftUI
import Testing
import ViewInspector
@testable import MusicWall

struct SortMenuViewTests {
    @MainActor
    private func makeViewModel(
        sort: AlbumStore.SortOption = .artist,
        ascending: Bool = true
    ) -> HomeViewModel {
        let preferences = InMemoryPreferencesStore()
        let viewModel = HomeViewModel(
            preferences: preferences,
            repository: MockAlbumRepository(),
            backup: MockAlbumBackupService()
        )
        viewModel.store.currentSort = sort
        if !ascending {
            viewModel.store.toggleSortDirection(for: sort)
        }
        return viewModel
    }

    @MainActor
    private func directionArrowName(in button: InspectableView<ViewType.Button>) throws -> String? {
        let label = try button.labelView()
        let images = try label.findAll(ViewType.Image.self)
        guard let image = images.first else { return nil }
        return try image.actualImage().name()
    }

    @Test @MainActor
    func currentSort_showsDirectionArrow_ascending() throws {
        let viewModel = makeViewModel(sort: .artist, ascending: true)
        let sut = SortMenu(viewModel: viewModel)

        let artistButton = try sut.inspect().find(button: "Artist")
        #expect(try directionArrowName(in: artistButton) == "arrow.down")

        let titleButton = try sut.inspect().find(button: "Title")
        #expect(try directionArrowName(in: titleButton) == nil)
    }

    @Test @MainActor
    func currentSort_showsDirectionArrow_descending() throws {
        let viewModel = makeViewModel(sort: .artist, ascending: false)
        let sut = SortMenu(viewModel: viewModel)

        let artistButton = try sut.inspect().find(button: "Artist")
        #expect(try directionArrowName(in: artistButton) == "arrow.up")
    }

    @Test @MainActor
    func tapSortOption_updatesCurrentSort() throws {
        let viewModel = makeViewModel(sort: .artist, ascending: true)
        let sut = SortMenu(viewModel: viewModel)

        try sut.inspect().find(button: "Title").tap()

        #expect(viewModel.currentSort == .title)
    }
}
```

- [ ] **Step 2: Register file + run tests**

Register `SortMenuViewTests.swift` in `project.pbxproj`.

Run:

```bash
xcodebuild test -project MusicWall.xcodeproj -scheme MusicWall -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MusicWallTests/SortMenuViewTests 2>&1 | tail -20
```

Expected: all 3 tests PASS.

If `find(button: "Artist")` fails due to `Section` wrapper, inspect with:

```swift
try sut.inspect().find(button: "Artist")
```

If that fails, use `try sut.inspect().find(ViewType.Button.self, where: { try $0.labelView().text().string() == "Artist" })` and update the helper accordingly.

- [ ] **Step 3: Commit**

```bash
git add MusicWallTests/UI/SortMenuViewTests.swift MusicWall.xcodeproj/project.pbxproj
git commit -m "test: Add SortMenu ViewInspector tests"
```

---

### Task 5: AlbumEditView inspection hooks + tests

**Files:**
- Modify: `MusicWall/Features/Edit/AlbumEditView.swift`
- Create: `MusicWallTests/UI/AlbumEditViewTests.swift`
- Modify: `MusicWall.xcodeproj/project.pbxproj`

- [ ] **Step 1: Add inspection hooks to `AlbumEditView`**

Replace `AlbumEditView` with:

```swift
struct AlbumEditView: View {
    let onSave: (AlbumRecord) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: AlbumEditViewModel
    internal let inspection = Inspection<Self>()

    init(album: AlbumRecord, onSave: @escaping (AlbumRecord) -> Void) {
        self.onSave = onSave
        _viewModel = State(initialValue: AlbumEditViewModel(album: album))
    }

    var body: some View {
        AlbumEditContent(viewModel: viewModel, onSave: onSave, dismiss: dismiss)
            .onReceive(inspection.notice) { self.inspection.visit(self, $0) }
    }
}
```

Do **not** change `AlbumEditContent`.

- [ ] **Step 2: Write `AlbumEditViewTests.swift`**

```swift
import SwiftUI
import Testing
import ViewInspector
@testable import MusicWall

struct AlbumEditViewTests {
    @Test @MainActor
    func saveDisabled_whenTitleWhitespaceOnly() async throws {
        let album = AlbumFixtures.record(id: "a", title: "   ", artistName: "A")
        let view = AlbumEditView(album: album, onSave: { _ in })

        try await ViewHosting.host(view) {
            try await view.inspection.inspect { inspected in
                let save = try inspected.find(button: "Save")
                #expect(try save.isDisabled())
            }
        }
    }

    @Test @MainActor
    func saveEnabled_whenTitleValid() async throws {
        let album = AlbumFixtures.record(id: "a", title: "Abbey Road", artistName: "The Beatles")
        let view = AlbumEditView(album: album, onSave: { _ in })

        try await ViewHosting.host(view) {
            try await view.inspection.inspect { inspected in
                let save = try inspected.find(button: "Save")
                #expect(try save.isDisabled() == false)
            }
        }
    }
}
```

- [ ] **Step 3: Register file + run tests**

Register `AlbumEditViewTests.swift` in `project.pbxproj`.

Run:

```bash
xcodebuild test -project MusicWall.xcodeproj -scheme MusicWall -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MusicWallTests/AlbumEditViewTests 2>&1 | tail -30
```

Expected: both tests PASS.

If `find(button: "Save")` cannot locate toolbar button, use:

```swift
try inspected.navigationStack().toolbar().item(placement: .confirmationAction).button()
```

Adjust per ViewInspector API for your Xcode version.

- [ ] **Step 4: Commit**

```bash
git add MusicWall/Features/Edit/AlbumEditView.swift MusicWallTests/UI/AlbumEditViewTests.swift MusicWall.xcodeproj/project.pbxproj
git commit -m "test: Add AlbumEditView ViewInspector tests with Inspection hooks"
```

---

### Task 6: Update MusicWallTests/Agent.md

**Files:**
- Modify: `MusicWallTests/Agent.md`

- [ ] **Step 1: Append ViewInspector section**

Add after the **Framework** section:

```markdown
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
```

- [ ] **Step 2: Commit**

```bash
git add MusicWallTests/Agent.md
git commit -m "docs: Document ViewInspector view tests in MusicWallTests/Agent.md"
```

---

### Task 7: Full CI verification

**Files:** (none)

- [ ] **Step 1: Run full test suite**

```bash
bundle exec fastlane ci_tests
```

Expected: BUILD SUCCEEDED, all tests PASS (including new UI suites).

- [ ] **Step 2: Confirm app target has no ViewInspector link**

Run:

```bash
xcodebuild build -project MusicWall.xcodeproj -scheme MusicWall -destination 'platform=iOS Simulator,name=iPhone 17' -quiet 2>&1 | tail -5
```

Expected: BUILD SUCCEEDED with no ViewInspector in MusicWall link step.

- [ ] **Step 3: PR checklist**

PR description must include:

- **ViewInspector (MIT)** chosen over snapshot testing
- Link to spec: `docs/specs/2026-05-31-pr-12-viewinspector-ui-tests-design.md`
- PR 12 of 14 in test refactor program
- Human verification: spot-check one intentional failure for readable ViewInspector errors

Acceptance criteria from spec:

- [ ] ViewInspector on MusicWallTests only
- [ ] SnackbarViewTests (message, action, callback)
- [ ] SortMenuViewTests (direction arrows)
- [ ] AlbumEditViewTests (Save disabled)
- [ ] MusicWallTests/Agent.md updated
- [ ] No animation timing assertions
- [ ] ci-tests green

---

## Spec coverage checklist

| Spec requirement | Task |
|------------------|------|
| ViewInspector SPM, test target only | Task 1 |
| Inspection scaffolding | Task 2 |
| SnackbarViewTests (4 cases) | Task 3 |
| SortMenuViewTests (arrows, optional tap) | Task 4 |
| AlbumEditViewTests (disabled/enabled Save) | Task 5 |
| MusicWallTests/Agent.md (not docs/testing.md) | Task 6 |
| CI green, no workflow changes | Task 7 |
| Stability rules (no animation/snapshots) | Tasks 3–5 (test code excludes these) |

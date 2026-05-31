# PR 12 — ViewInspector SwiftUI unit tests

**Status:** Approved (2026-05-31)  
**Program:** MusicWall testability refactor  
**Requires:** PR 9, PR 10, PR 11 merged (or rebased onto their changes)  
**Blocks:** PR 14  
**Approach:** ViewInspector (Option A) + minimal Inspection scaffolding (Option 1) + Swift Testing throughout (Option 1) + sort arrow assertions as-is (Option A)

## Summary

Add **ViewInspector** (MIT) as an SPM dependency on the **`MusicWallTests`** target only. Introduce three view-level test suites for high-value SwiftUI: **`SnackbarView`**, **`SortMenu`**, and **`AlbumEditView`**. Use ViewInspector's **Inspection** async pattern only where **`@State`** / **`@Environment`** require hosted lifecycle (**`AlbumEditView`**). Document ViewInspector setup, patterns, and stability rules in **`MusicWallTests/Agent.md`** (not a separate `docs/testing.md`). Existing **`ci-tests`** workflow runs the new tests with no workflow changes.

## Goals

- ViewInspector on test target; license noted in PR description (MIT).
- **`SnackbarViewTests`**: message text, action button presence, undo callback on tap.
- **`SortMenuViewTests`**: direction arrow on active sort option (current UI — not checkmarks).
- **`AlbumEditViewTests`**: Save toolbar button disabled when title is whitespace-only.
- Tests stable: no animation timing, auto-dismiss, or snapshot reference images.
- Update **`MusicWallTests/Agent.md`** with ViewInspector documentation.

## Non-goals

- Full app XCUITest (PR 13).
- Snapshot testing (Point-Free or otherwise).
- Testing **`.snackbar(isPresented:)`** modifier (animation / auto-dismiss timing).
- Vinyl animation, **`glassEffect()`** / iOS 26 background branches, artwork loading UI.
- Changing **`SortMenu`** to use checkmarks like **`LayoutMenu`**.
- Refactoring **`AlbumEditContent`** for injectable dismiss (ViewModel tests already cover save logic).
- **`docs/testing.md`** — documentation lives in **`MusicWallTests/Agent.md`**.

## Decisions (brainstorming)

| Topic | Choice |
|-------|--------|
| Library | **ViewInspector** (MIT) — test target only |
| Test framework | **Swift Testing** (`@Test`, `#expect`, `throws`) — same as existing suites |
| Sort indicator | Assert **direction arrows** (`arrow.up` / `arrow.down`) on active sort; test current UI |
| SortMenu hosting | Instantiate **`SortMenu`** standalone with **`HomeViewModel.preview()`** — not inside **`Menu`** |
| Snackbar scope | Test **`SnackbarView`** struct only — not **`.snackbar`** modifier |
| AlbumEditView | **Inspection + ViewHosting** async pattern for **`@State`** / **`@Environment(\.dismiss)`** |
| Production changes | **`Inspection.swift`** helper + minimal inspection hooks on edit view only |
| Documentation | Extend **`MusicWallTests/Agent.md`** |

## Approaches considered

### Testing library

| Option | Description | Why not chosen |
|--------|-------------|----------------|
| **A (chosen)** | ViewInspector — programmatic hierarchy inspection | Fits behavioral tests; no reference images; prior PR specs defer here |
| B | Snapshot testing (Point-Free) | Pixel maintenance; **`glassEffect()`** branch fragile; skill requires picking one |
| C | UIHostingController + accessibility, no dependency | More boilerplate; less ergonomic than ViewInspector |

### Scaffolding depth

| Option | Description | Why not chosen |
|--------|-------------|----------------|
| **1 (chosen)** | Minimal **`Inspection.swift`** in main target; test views in isolation | Smallest diff; avoids fragile **`Menu`** hierarchy inspection |
| 2 | Refactor **`AlbumEditContent`** with injectable dismiss | Unnecessary scope; ViewModel tests cover save rules |
| 3 | XCTest for UI tests, Swift Testing for rest | Two styles in one target; Swift Testing + `throws` works with ViewInspector |

## Architecture

### Dependency

```
MusicWallTests  ──SPM──▶  ViewInspector (https://github.com/nalexn/ViewInspector)
MusicWall       ──(no ViewInspector link)──▶  production app
```

- Pin to latest stable release compatible with Xcode 26 / Swift 6.
- Add package in Xcode; link **only** to **`MusicWallTests`** target.

### File layout

```
MusicWall/
  TestSupport/
    Inspection.swift                 # ViewInspector helper for @State / @Environment views

MusicWallTests/
  Agent.md                           # + ViewInspector section (setup, patterns, stability)
  UI/
    SnackbarViewTests.swift
    SortMenuViewTests.swift
    AlbumEditViewTests.swift
  TestSupport/
    ViewInspector+MusicWall.swift    # extension Inspection: InspectionEmissary {}
```

### Production test support

**`Inspection.swift`** (main target, ~30 lines):

```swift
internal final class Inspection<V> {
    let notice = PassthroughSubject<UInt, Never>()
    var callbacks = [UInt: (V) -> Void]()
    func visit(_ view: V, _ line: UInt) {
        callbacks.removeValue(forKey: line)?(view)
    }
}
```

Test target:

```swift
import ViewInspector

extension Inspection: InspectionEmissary {}
```

**`AlbumEditView`** / **`AlbumEditContent`** only — add:

```swift
internal let inspection = Inspection<Self>()
// in body, after root content:
.onReceive(inspection.notice) { self.inspection.visit(self, $0) }
```

**`SnackbarView`** and **`SortMenu`** require **no** production changes.

### Why SortMenu is tested standalone

ViewInspector has limited support for inspecting content inside **`Menu`** / **`contextMenu`** wrappers (internal hierarchy varies by iOS version). **`SortMenu`**'s body is a **`Section`** of sort buttons — test it directly with a configured **`HomeViewModel`**, not embedded in **`HomePageMenu`**.

## Test cases

### `SnackbarViewTests` (sync — no ViewHosting)

| Test | Setup | Asserts |
|------|-------|---------|
| **displaysMessage** | `SnackbarView(message: "Added 3 albums")` | `find(text: "Added 3 albums")` succeeds |
| **showsActionButton_whenLabelProvided** | `actionLabel: "Undo"`, `action: {}` | `find(button: "Undo")` succeeds |
| **actionButton_invokesCallback** | `actionLabel: "Undo"`, capture flag | `tap()` → flag is `true` |
| **hidesActionButton_whenLabelNil** | no `actionLabel` | `find(button:)` throws / no button found |

Do **not** test **`.snackbar(isPresented:duration:…)`** — auto-dismiss uses **`DispatchQueue.main.asyncAfter`** and animation; explicitly unstable.

### `SortMenuViewTests` (sync — no ViewHosting)

Use **`HomeViewModel`** constructed with **`InMemoryPreferencesStore`** + mocks (or **`HomeViewModel.preview(dependencies:)`** with sort state configured before inspect).

| Test | Setup | Asserts |
|------|-------|---------|
| **currentSort_showsDirectionArrow_ascending** | `currentSort = .artist`, ascending for `.artist` | Row for `"Artist"` has `Image` with `"arrow.down"`; other sort labels have no arrow |
| **currentSort_showsDirectionArrow_descending** | same sort, descending | Active row shows `"arrow.up"` |
| **tapSortOption_updatesCurrentSort** *(optional)* | tap `"Title"` button | `viewModel.currentSort == .title` |

Use **`find(text:)`** / **`find(button:)`** over deep hierarchy traversal (ViewInspector best practice).

### `AlbumEditViewTests` (async — ViewHosting + Inspection)

| Test | Setup | Asserts |
|------|-------|---------|
| **saveDisabled_whenTitleWhitespaceOnly** | `AlbumFixtures.record(…, title: "   ", artistName: "A")` — VM initializes from album | Toolbar Save button `isDisabled() == true` |
| **saveEnabled_whenTitleValid** | Default fixture with valid title/artist | Save button not disabled |

ViewModel trim/validation logic remains in **`AlbumEditViewModelTests`** — UI test asserts only that toolbar Save reflects **`canSave`**. Whitespace title is seeded via the **`AlbumRecord`** passed to **`AlbumEditView(album:onSave:)`** init (no runtime **`@State`** mutation needed for the disabled case).

Example pattern:

```swift
@Test @MainActor
func saveDisabled_whenTitleWhitespaceOnly() async throws {
    let album = AlbumFixtures.record(id: "a", title: "   ", artistName: "A")
    let view = AlbumEditView(album: album, onSave: { _ in })

    let exp = view.inspection.inspect { view in
        let save = try view.find(button: "Save")
        #expect(try save.isDisabled())
    }
    ViewHosting.host(view: view)
    await fulfillment(of: [exp], timeout: 1)
}
```

## Stability rules

- No assertions on animation, transitions, or **`withAnimation`** side effects.
- No **`DispatchQueue.main.asyncAfter`** / snackbar duration timing.
- No snapshot / reference images.
- No coverage of **`glassEffect()`** iOS 26 branch in **`SnackbarView`**.
- Prefer **`find(button:)`** / **`find(text:)`** over chained deep traversal.
- All view tests annotated **`@MainActor`**.

## CI

No workflow changes. Existing **`.github/workflows/ci-tests.yml`** → **`bundle exec fastlane ci_tests`** → **`xcodebuild test`** on iPhone 17 simulator runs **`MusicWallTests`**. New test files must be included in the **`MusicWallTests`** target (filesystem-synced group if applicable).

## Documentation — `MusicWallTests/Agent.md`

Add a **ViewInspector** section covering:

1. **Test pyramid** — Core/ViewModel tests (Swift Testing, no hosting) vs View tests (ViewInspector + optional ViewHosting).
2. **Dependency** — SPM URL, test-target-only, MIT license.
3. **Adding a view test** — `import ViewInspector`, `@testable import MusicWall`, `throws` tests, `find` APIs.
4. **Inspection pattern** — when required (`@State`, `@Environment`); reference **`Inspection.swift`** and ViewInspector guide.
5. **Stability guidelines** — no animation timing; test views in isolation; avoid **`Menu`** wrapper inspection.
6. **Commands** — unchanged (`fastlane ci_tests`, `xcodebuild test`).

Keep existing sections (Fixtures, Framework, Commands, Coverage, Exclusions); append ViewInspector content.

## Error handling

View tests assert UI state only. No new user-facing error surfaces. Test failures surface as ViewInspector **`throws`** inspection errors or **`#expect`** mismatches — same as existing Swift Testing suites.

## Acceptance criteria

- [ ] ViewInspector SPM added to **`MusicWallTests`** only; MIT license noted in PR description
- [ ] **`SnackbarViewTests`**: message, action button, undo callback
- [ ] **`SortMenuViewTests`**: direction arrow on active sort (current UI)
- [ ] **`AlbumEditViewTests`**: Save disabled when title whitespace-only
- [ ] **`MusicWallTests/Agent.md`** updated with ViewInspector documentation
- [ ] No animation timing assertions
- [ ] **`ci-tests`** green on macOS job

## Human verification (PR description)

- Spot-check one failing assertion locally to confirm ViewInspector error messages are readable.
- Confirm no ViewInspector symbols linked in Release app build.

## PR delivery

- Branch: `cursor/test-refactor-pr-12-viewinspector` (or team convention).
- Add new files to Xcode targets.
- PR title: `test refactor PR 12: ViewInspector SwiftUI unit tests`
- Link PR 12 of 14; state **ViewInspector (MIT)** as the chosen approach (not snapshot testing).

## Follow-on PRs

| PR | Relationship |
|----|----------------|
| PR 13 | Full XCUITest flows |
| PR 14 | Coverage policy; may reference view test inventory in Agent.md |
| PR 15 | SPM split; view tests remain in app test target |

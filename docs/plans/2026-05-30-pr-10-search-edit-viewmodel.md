# PR 10 — Search + Edit ViewModels Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extract testable `SearchViewModel` and `AlbumEditViewModel` from search/edit views; replace `print(error)` with inline `errorMessage`; parallel catalog + library search with partial-failure UX; trim-aware edit validation.

**Architecture:** View-owned `@MainActor @Observable` VMs created in sheet view `init`. Search VM injects `AlbumRepository`, runs parallel `async let` with per-source `do/catch`. Edit VM owns form fields + `canSave` / `makeSavedRecord()`. Views under `Features/Search/` and `Features/Edit/` are thin SwiftUI bindings.

**Tech Stack:** Swift 5, Swift Testing, Observation, Xcode 16+, scheme `MusicWall`, simulator `iPhone 17`, `bundle exec fastlane ci_tests`.

**Spec:** `docs/specs/2026-05-30-pr-10-search-edit-viewmodel-design.md`

**Branch:** `cursor/test-refactor-pr-10-search-edit-vm`

---

## File map

| Action | Path | Notes |
|--------|------|-------|
| Create | `MusicWall/Features/Search/SearchViewModel.swift` | Parallel search orchestration |
| Move | `MusicWall/AlbumSearchView.swift` → `MusicWall/Features/Search/AlbumSearchView.swift` | Thin bindings + inline error |
| Create | `MusicWall/Features/Edit/AlbumEditViewModel.swift` | Trim + validation + save record |
| Move | `MusicWall/AlbumEditView.swift` → `MusicWall/Features/Edit/AlbumEditView.swift` | Thin form bindings |
| Create | `MusicWallTests/Features/Search/SearchViewModelTests.swift` | Search VM unit tests |
| Create | `MusicWallTests/Features/Edit/AlbumEditViewModelTests.swift` | Edit VM unit tests |
| Modify | `MusicWall.xcodeproj/project.pbxproj` | Register test files + Features/Search, Features/Edit groups |
| Modify | `Agent.md` | Note search/edit VMs |

**Unchanged:** `HomePageView.swift` sheet signature (`repository` + `onSelect`); `LayoutViews.swift` edit sheet signature (`album` + `onSave`).

**Xcode note:** `MusicWall/` uses `PBXFileSystemSynchronizedRootGroup` — new app files under `MusicWall/Features/` auto-join the target. **Delete** old `MusicWall/AlbumSearchView.swift` and `MusicWall/AlbumEditView.swift` after move so Xcode does not compile two copies. Test files must be registered in `project.pbxproj` (mirror `HomeViewModelTests.swift`).

---

### Task 1: Branch + register test files

**Files:**
- Modify: `MusicWall.xcodeproj/project.pbxproj`

- [ ] **Step 1: Create branch**

```bash
git checkout main
git pull
git checkout -b cursor/test-refactor-pr-10-search-edit-vm
```

- [ ] **Step 2: Register test files in Xcode project**

Add to `MusicWallTests` target:

- `SearchViewModelTests.swift` under new group `Features/Search/`
- `AlbumEditViewModelTests.swift` under new group `Features/Edit/`

Mirror `HomeViewModelTests.swift` registration: `PBXFileReference`, `PBXBuildFile`, group children, Sources build phase. Add `Search` and `Edit` groups under existing `Features` group alongside `Auth` and `Home`.

- [ ] **Step 3: Commit**

```bash
git add MusicWall.xcodeproj/project.pbxproj
git commit -m "chore: Register Search and Edit ViewModel test files"
```

---

### Task 2: `SearchViewModel` — failing tests + stub (TDD)

**Files:**
- Create: `MusicWallTests/Features/Search/SearchViewModelTests.swift`
- Create: `MusicWall/Features/Search/SearchViewModel.swift` (stub)

- [ ] **Step 1: Create stub `SearchViewModel.swift`**

```swift
import Foundation
import Observation

@MainActor
@Observable
final class SearchViewModel {
    var query = ""
    private(set) var catalogResults: [AlbumRecord] = []
    private(set) var libraryResults: [AlbumRecord] = []
    private(set) var isSearching = false
    var errorMessage: String?

    private let repository: any AlbumRepository

    init(repository: any AlbumRepository) {
        self.repository = repository
    }

    func search() async {
        fatalError("unimplemented")
    }
}
```

- [ ] **Step 2: Create `SearchViewModelTests.swift`**

```swift
import Foundation
import Testing
@testable import MusicWall

struct SearchViewModelTests {
    private func makeViewModel(
        repository: MockAlbumRepository = MockAlbumRepository()
    ) -> (SearchViewModel, MockAlbumRepository) {
        (SearchViewModel(repository: repository), repository)
    }

    @Test @MainActor
    func search_emptyQuery_doesNotCallRepository() async {
        let (viewModel, repository) = makeViewModel()
        viewModel.query = ""

        await viewModel.search()

        #expect(repository.searchCalls.isEmpty)
        #expect(viewModel.isSearching == false)
    }

    @Test @MainActor
    func search_success_populatesBothResultLists() async {
        let repository = MockAlbumRepository()
        let catalogRecord = AlbumFixtures.record(id: "cat-1", title: "Catalog", artistName: "Artist A")
        let libraryRecord = AlbumFixtures.record(id: "lib-1", title: "Library", artistName: "Artist B")
        repository.searchHandler = { _, source in
            switch source {
            case .catalog: return [catalogRecord]
            case .library: return [libraryRecord]
            }
        }
        let viewModel = SearchViewModel(repository: repository)
        viewModel.query = "test"

        await viewModel.search()

        #expect(viewModel.catalogResults == [catalogRecord])
        #expect(viewModel.libraryResults == [libraryRecord])
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.isSearching == false)
        #expect(repository.searchCalls.count == 2)
        #expect(repository.searchCalls.contains(where: { $0.1 == .catalog }))
        #expect(repository.searchCalls.contains(where: { $0.1 == .library }))
    }

    @Test @MainActor
    func search_bothFail_clearsResultsAndSetsErrorMessage() async {
        let repository = MockAlbumRepository()
        repository.searchHandler = { _, _ in
            throw AlbumRepositoryError.searchFailed("boom")
        }
        let viewModel = SearchViewModel(repository: repository)
        viewModel.query = "test"

        await viewModel.search()

        #expect(viewModel.catalogResults.isEmpty)
        #expect(viewModel.libraryResults.isEmpty)
        #expect(viewModel.errorMessage?.contains("Apple Music:") == true)
        #expect(viewModel.errorMessage?.contains("Library:") == true)
        #expect(viewModel.isSearching == false)
    }

    @Test @MainActor
    func search_catalogFails_showsPartialResults() async {
        let repository = MockAlbumRepository()
        let libraryRecord = AlbumFixtures.record(id: "lib-1", title: "Library", artistName: "Artist B")
        repository.searchHandler = { _, source in
            switch source {
            case .catalog:
                throw AlbumRepositoryError.networkError("offline")
            case .library:
                return [libraryRecord]
            }
        }
        let viewModel = SearchViewModel(repository: repository)
        viewModel.query = "test"

        await viewModel.search()

        #expect(viewModel.catalogResults.isEmpty)
        #expect(viewModel.libraryResults == [libraryRecord])
        #expect(viewModel.errorMessage?.contains("Apple Music:") == true)
        #expect(viewModel.errorMessage?.contains("Library:") == false)
    }

    @Test @MainActor
    func search_libraryFails_showsPartialResults() async {
        let repository = MockAlbumRepository()
        let catalogRecord = AlbumFixtures.record(id: "cat-1", title: "Catalog", artistName: "Artist A")
        repository.searchHandler = { _, source in
            switch source {
            case .catalog:
                return [catalogRecord]
            case .library:
                throw AlbumRepositoryError.networkError("offline")
            }
        }
        let viewModel = SearchViewModel(repository: repository)
        viewModel.query = "test"

        await viewModel.search()

        #expect(viewModel.catalogResults == [catalogRecord])
        #expect(viewModel.libraryResults.isEmpty)
        #expect(viewModel.errorMessage?.contains("Library:") == true)
        #expect(viewModel.errorMessage?.contains("Apple Music:") == false)
    }

    @Test @MainActor
    func search_repositoryError_usesLocalizedDescription() async {
        let repository = MockAlbumRepository()
        repository.searchHandler = { _, _ in
            throw AlbumRepositoryError.networkError("offline")
        }
        let viewModel = SearchViewModel(repository: repository)
        viewModel.query = "test"

        await viewModel.search()

        #expect(viewModel.errorMessage?.contains("offline") == true)
    }
}
```

- [ ] **Step 3: Run tests to verify they fail**

Run:

```bash
xcodebuild test -project MusicWall.xcodeproj -scheme MusicWall \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:MusicWallTests/SearchViewModelTests 2>&1 | tail -20
```

Expected: FAIL (`fatalError("unimplemented")` or crash on non-empty query tests)

- [ ] **Step 4: Commit**

```bash
git add MusicWall/Features/Search/SearchViewModel.swift \
  MusicWallTests/Features/Search/SearchViewModelTests.swift
git commit -m "test: Add SearchViewModel failing tests and stub"
```

---

### Task 3: `SearchViewModel` — implementation

**Files:**
- Modify: `MusicWall/Features/Search/SearchViewModel.swift`

- [ ] **Step 1: Implement `search()`**

Replace stub body with:

```swift
func search() async {
    guard !query.isEmpty else { return }

    isSearching = true
    errorMessage = nil

    async let catalogTask = repository.search(query: query, source: .catalog)
    async let libraryTask = repository.search(query: query, source: .library)

    var errorParts: [String] = []

    do {
        catalogResults = try await catalogTask
    } catch {
        catalogResults = []
        errorParts.append("Apple Music: \(error.localizedDescription)")
    }

    do {
        libraryResults = try await libraryTask
    } catch {
        libraryResults = []
        errorParts.append("Library: \(error.localizedDescription)")
    }

    isSearching = false
    errorMessage = errorParts.isEmpty ? nil : errorParts.joined(separator: "\n")
}
```

- [ ] **Step 2: Run SearchViewModel tests**

Run:

```bash
xcodebuild test -project MusicWall.xcodeproj -scheme MusicWall \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:MusicWallTests/SearchViewModelTests 2>&1 | tail -20
```

Expected: all `SearchViewModelTests` PASS

- [ ] **Step 3: Commit**

```bash
git add MusicWall/Features/Search/SearchViewModel.swift
git commit -m "feat(search): Implement SearchViewModel parallel search"
```

---

### Task 4: Thin `AlbumSearchView` + delete old file

**Files:**
- Create: `MusicWall/Features/Search/AlbumSearchView.swift`
- Delete: `MusicWall/AlbumSearchView.swift`

- [ ] **Step 1: Create `Features/Search/AlbumSearchView.swift`**

```swift
import SwiftUI

struct AlbumSearchView: View {
    let onSelect: (AlbumRecord) -> Void

    @State private var viewModel: SearchViewModel
    @FocusState private var isSearchFieldFocused: Bool

    init(repository: any AlbumRepository, onSelect: @escaping (AlbumRecord) -> Void) {
        self.onSelect = onSelect
        _viewModel = State(initialValue: SearchViewModel(repository: repository))
    }

    var body: some View {
        AlbumSearchContent(
            viewModel: viewModel,
            onSelect: onSelect,
            isSearchFieldFocused: $isSearchFieldFocused
        )
    }
}

private struct AlbumSearchContent: View {
    @Bindable var viewModel: SearchViewModel
    var onSelect: (AlbumRecord) -> Void
    @FocusState.Binding var isSearchFieldFocused: Bool

    var body: some View {
        NavigationStack {
            VStack {
                TextField("Search for an album", text: $viewModel.query)
                    .textFieldStyle(.roundedBorder)
                    .padding()
                    .focused($isSearchFieldFocused)
                Button("Search") {
                    isSearchFieldFocused = false
                    Task { await viewModel.search() }
                }
                .disabled(viewModel.isSearching)
                if viewModel.isSearching {
                    ProgressView("Searching…")
                        .padding(.vertical, 4)
                }
                if let message = viewModel.errorMessage {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                resultsView()
            }
            .navigationTitle("Find Album")
        }
    }

    private func resultsView() -> some View {
        List {
            Section(header: Text("Library")) {
                ForEach(viewModel.libraryResults, id: \.id) { record in
                    SearchResultButton(onSelect: onSelect, record: record)
                }
            }
            Section(header: Text("Apple Music")) {
                ForEach(viewModel.catalogResults, id: \.id) { record in
                    SearchResultButton(onSelect: onSelect, record: record)
                }
            }
        }
    }
}

extension AlbumSearchView {
    struct SearchResultButton: View {
        @Environment(\.dismiss) var dismiss

        var onSelect: (AlbumRecord) -> Void
        var record: AlbumRecord

        var body: some View {
            Button {
                onSelect(record)
                dismiss()
            } label: {
                HStack {
                    if record.isExplicit {
                        Image(systemName: "e.square.fill")
                    }
                    Text("\(record.title) — \(record.artistName)")
                }
            }
        }
    }
}

#Preview {
    let deps = AppDependencies.preview()
    AlbumSearchView(repository: deps.albumRepository, onSelect: { _ in })
}
```

- [ ] **Step 2: Delete old file**

```bash
rm MusicWall/AlbumSearchView.swift
```

- [ ] **Step 3: Verify no `print(error)` in search path**

Run:

```bash
rg 'print\(' MusicWall/Features/Search/
```

Expected: no matches

- [ ] **Step 4: Build app**

Run:

```bash
xcodebuild build -project MusicWall.xcodeproj -scheme MusicWall \
  -destination 'platform=iOS Simulator,name=iPhone 17' -quiet
```

Expected: `BUILD SUCCEEDED`

- [ ] **Step 5: Commit**

```bash
git add MusicWall/Features/Search/AlbumSearchView.swift MusicWall/AlbumSearchView.swift
git commit -m "refactor(search): Thin AlbumSearchView with SearchViewModel bindings"
```

---

### Task 5: `AlbumEditViewModel` — failing tests + implementation (TDD)

**Files:**
- Create: `MusicWallTests/Features/Edit/AlbumEditViewModelTests.swift`
- Create: `MusicWall/Features/Edit/AlbumEditViewModel.swift`

- [ ] **Step 1: Create `AlbumEditViewModelTests.swift`**

```swift
import Foundation
import Testing
@testable import MusicWall

struct AlbumEditViewModelTests {
    @Test @MainActor
    func canSave_whitespaceOnlyTitle_isFalse() {
        let album = AlbumFixtures.record(id: "a", title: "T", artistName: "A")
        let viewModel = AlbumEditViewModel(album: album)
        viewModel.title = "   "

        #expect(viewModel.canSave == false)
    }

    @Test @MainActor
    func canSave_whitespaceOnlyArtist_isFalse() {
        let album = AlbumFixtures.record(id: "a", title: "T", artistName: "A")
        let viewModel = AlbumEditViewModel(album: album)
        viewModel.artistName = "\t\n"

        #expect(viewModel.canSave == false)
    }

    @Test @MainActor
    func canSave_validFields_isTrue() {
        let album = AlbumFixtures.record(id: "a", title: "T", artistName: "A")
        let viewModel = AlbumEditViewModel(album: album)

        #expect(viewModel.canSave == true)
    }

    @Test @MainActor
    func makeSavedRecord_trimsWhitespace() {
        let album = AlbumFixtures.record(id: "a", title: "T", artistName: "A")
        let viewModel = AlbumEditViewModel(album: album)
        viewModel.title = "  Abbey Road  "
        viewModel.artistName = "  The Beatles  "

        let saved = viewModel.makeSavedRecord()

        #expect(saved.title == "Abbey Road")
        #expect(saved.artistName == "The Beatles")
    }

    @Test @MainActor
    func makeSavedRecord_preservesIdAndExplicit() {
        let releaseDate = AlbumFixtures.utcDate(year: 1969, month: 9, day: 26)
        let album = AlbumFixtures.record(
            id: "abbey-road",
            title: "Abbey Road",
            artistName: "The Beatles",
            releaseDate: releaseDate,
            isExplicit: true
        )
        let viewModel = AlbumEditViewModel(album: album)
        viewModel.title = "New Title"

        let saved = viewModel.makeSavedRecord()

        #expect(saved.id == album.id)
        #expect(saved.isExplicit == true)
        #expect(saved.title == "New Title")
        #expect(saved.releaseDate == releaseDate)
    }

    @Test @MainActor
    func setReleaseDateEnabled_true_usesExistingDate() {
        let releaseDate = AlbumFixtures.utcDate(year: 2011, month: 11, day: 15)
        let album = AlbumFixtures.record(id: "a", title: "T", artistName: "A", releaseDate: releaseDate)
        let viewModel = AlbumEditViewModel(album: album)
        viewModel.releaseDate = nil

        viewModel.setReleaseDateEnabled(true)

        #expect(viewModel.releaseDate == releaseDate)
    }

    @Test @MainActor
    func setReleaseDateEnabled_true_usesNowWhenMissing() {
        let album = AlbumFixtures.record(id: "a", title: "T", artistName: "A", releaseDate: nil)
        let viewModel = AlbumEditViewModel(album: album)

        viewModel.setReleaseDateEnabled(true)

        #expect(viewModel.releaseDate != nil)
    }

    @Test @MainActor
    func setReleaseDateEnabled_false_clearsDate() {
        let album = AlbumFixtures.record(
            id: "a",
            title: "T",
            artistName: "A",
            releaseDate: AlbumFixtures.utcDate(year: 2011, month: 11, day: 15)
        )
        let viewModel = AlbumEditViewModel(album: album)
        viewModel.setReleaseDateEnabled(true)

        viewModel.setReleaseDateEnabled(false)

        #expect(viewModel.releaseDate == nil)
    }
}
```

- [ ] **Step 2: Create `AlbumEditViewModel.swift`**

```swift
import Foundation
import Observation

@MainActor
@Observable
final class AlbumEditViewModel {
    var title: String
    var artistName: String
    var releaseDate: Date?

    private let album: AlbumRecord

    init(album: AlbumRecord) {
        self.album = album
        self.title = album.title
        self.artistName = album.artistName
        self.releaseDate = album.releaseDate
    }

    var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !artistName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func setReleaseDateEnabled(_ enabled: Bool) {
        if enabled {
            releaseDate = album.releaseDate ?? Date()
        } else {
            releaseDate = nil
        }
    }

    func makeSavedRecord() -> AlbumRecord {
        AlbumRecord(
            id: album.id,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            artistName: artistName.trimmingCharacters(in: .whitespacesAndNewlines),
            releaseDate: releaseDate,
            isExplicit: album.isExplicit
        )
    }
}
```

- [ ] **Step 3: Run AlbumEditViewModel tests**

Run:

```bash
xcodebuild test -project MusicWall.xcodeproj -scheme MusicWall \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:MusicWallTests/AlbumEditViewModelTests 2>&1 | tail -20
```

Expected: all PASS

- [ ] **Step 4: Commit**

```bash
git add MusicWall/Features/Edit/AlbumEditViewModel.swift \
  MusicWallTests/Features/Edit/AlbumEditViewModelTests.swift
git commit -m "feat(edit): Add AlbumEditViewModel with trim-aware validation"
```

---

### Task 6: Thin `AlbumEditView` + delete old file

**Files:**
- Create: `MusicWall/Features/Edit/AlbumEditView.swift`
- Delete: `MusicWall/AlbumEditView.swift`

- [ ] **Step 1: Create `Features/Edit/AlbumEditView.swift`**

```swift
import SwiftUI

struct AlbumEditView: View {
    let onSave: (AlbumRecord) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: AlbumEditViewModel

    init(album: AlbumRecord, onSave: @escaping (AlbumRecord) -> Void) {
        self.onSave = onSave
        _viewModel = State(initialValue: AlbumEditViewModel(album: album))
    }

    var body: some View {
        AlbumEditContent(viewModel: viewModel, onSave: onSave, dismiss: dismiss)
    }
}

private struct AlbumEditContent: View {
    @Bindable var viewModel: AlbumEditViewModel
    let onSave: (AlbumRecord) -> Void
    let dismiss: DismissAction

    var body: some View {
        NavigationStack {
            Form {
                Section("Changes made here are local and may be overridden by Apple Music") {
                    TextField("Title", text: $viewModel.title)
                    TextField("Artist Name", text: $viewModel.artistName)
                }

                Section {
                    Toggle("Set Release Date", isOn: Binding(
                        get: { viewModel.releaseDate != nil },
                        set: { viewModel.setReleaseDateEnabled($0) }
                    ))

                    if viewModel.releaseDate != nil {
                        DatePicker(
                            "Release Date",
                            selection: Binding(
                                get: { viewModel.releaseDate ?? Date() },
                                set: { viewModel.releaseDate = $0 }
                            ),
                            displayedComponents: .date
                        )
                    }
                }
            }
            .navigationTitle("Edit Album")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(viewModel.makeSavedRecord())
                        dismiss()
                    }
                    .disabled(!viewModel.canSave)
                }
            }
        }
    }
}

#Preview {
    let deps = AppDependencies.preview()
    AlbumEditView(
        album: AlbumStore.dummyData(
            preferences: deps.preferencesStore,
            repository: deps.albumRepository
        ).items.first!,
        onSave: { _ in }
    )
}
```

- [ ] **Step 2: Delete old file**

```bash
rm MusicWall/AlbumEditView.swift
```

- [ ] **Step 3: Build app**

Run:

```bash
xcodebuild build -project MusicWall.xcodeproj -scheme MusicWall \
  -destination 'platform=iOS Simulator,name=iPhone 17' -quiet
```

Expected: `BUILD SUCCEEDED`

- [ ] **Step 4: Commit**

```bash
git add MusicWall/Features/Edit/AlbumEditView.swift MusicWall/AlbumEditView.swift
git commit -m "refactor(edit): Thin AlbumEditView with AlbumEditViewModel bindings"
```

---

### Task 7: Full CI + docs + acceptance verification

**Files:**
- Modify: `Agent.md`

- [ ] **Step 1: Update `Agent.md`**

Under Architecture / MVVM notes, extend the bullet that mentions `HomeViewModel`:

```markdown
- **MVVM-style separation:** views in `*View.swift`, Apple Music access via `AlbumRepository` / `PlaybackController` (`AppDependencies.live`), persistence via `PreferencesStore` / `AlbumBackupService`. Home orchestration via `HomeViewModel` in `Features/Home/`; search via `SearchViewModel` in `Features/Search/`; album edit via `AlbumEditViewModel` in `Features/Edit/`. Search errors surface as inline `errorMessage` in the search sheet (not snackbar).
```

- [ ] **Step 2: Run full test suite**

Run:

```bash
bundle exec fastlane ci_tests
```

Expected: PASS (all unit tests + build)

- [ ] **Step 3: Acceptance grep checks**

Run:

```bash
rg 'print\(' MusicWall/Features/Search/ MusicWall/Features/Edit/
rg 'MusicKit' MusicWall/Features/Search/
```

Expected: no matches

- [ ] **Step 4: Commit**

```bash
git add Agent.md
git commit -m "docs: Note SearchViewModel and AlbumEditViewModel in Agent.md"
```

---

## Spec coverage checklist

| Spec requirement | Task |
|------------------|------|
| `SearchViewModel` parallel search | Task 2–3 |
| Inline `errorMessage`, no `print` | Task 3–4 |
| Partial results on parallel failure | Task 2–3 |
| `AlbumEditViewModel` trim-aware `canSave` | Task 5 |
| `makeSavedRecord()` testable output | Task 5 |
| Thin views; `onSelect` / `onSave` unchanged | Task 4, 6 |
| Move to `Features/Search/` and `Features/Edit/` | Task 4, 6 |
| `SearchViewModelTests` matrix | Task 2–3 |
| `AlbumEditViewModelTests` matrix | Task 5 |
| No `MusicKit.Album` in search layer | Task 4 (verify) |
| `ci-tests` green | Task 7 |

## Human verification (PR description)

| Scenario | Expected |
|----------|----------|
| Search with results | Library + Apple Music sections populate |
| Search network failure (one source) | Other section shows results; red inline error names failed source |
| Search empty query + tap Search | No spinner; no repository call |
| Edit album, whitespace title | Save disabled |
| Edit album, trim fields, Save | Store shows trimmed values |
| Add from search | Home snackbar unchanged |

## PR delivery

- Branch: `cursor/test-refactor-pr-10-search-edit-vm`
- PR title: `test refactor PR 10: SearchViewModel and AlbumEditViewModel`
- Link spec + plan; note device/simulator search QA

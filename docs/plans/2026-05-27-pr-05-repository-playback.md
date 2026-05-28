# PR 5 — AlbumRepository + PlaybackController Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace static `MusicService` with Core protocols, MusicKit adapters, and hybrid injection; migrate search, fetch, playback, and artwork to `AlbumRepository` / `PlaybackController`.

**Architecture:** Foundation-only protocols and errors in `MusicWall/Core/`. MusicKit lives in `MusicWall/Adapters/` (`AlbumMapper`, `MusicKitAlbumRepository`, `SystemMusicPlayerAdapter`). `AppDependencies` composes live adapters; `HomePageView` installs SwiftUI environment keys for leaf views; `StoredAlbums` and `AlbumSearchView` use constructor injection.

**Tech Stack:** Swift 5, Swift Testing, SwiftUI `@Entry`, MusicKit, Observation, Xcode 16+, scheme `MusicWall`, simulator `iPhone 17`, `bundle exec fastlane ci_tests`.

**Spec:** `docs/specs/2026-05-27-pr-05-repository-playback-design.md`

**Branch:** `cursor/test-refactor-pr-05-repository-playback` from `main`

---

## File map

| Action | Path | Notes |
|--------|------|-------|
| Modify | `MusicWall/Core/AlbumRecord.swift` | Add `isExplicit` |
| Create | `MusicWall/Core/AlbumRepository.swift` | Protocol, `AlbumSearchSource`, `AlbumRepositoryError` |
| Create | `MusicWall/Core/PlaybackController.swift` | Protocol, `PlaybackError` |
| Create | `MusicWall/Core/AlbumTapPlayback.swift` | Testable tap helper (Foundation) |
| Create | `MusicWall/Adapters/AlbumMapper.swift` | MusicKit → `AlbumRecord` |
| Create | `MusicWall/Adapters/MusicKitAlbumRepository.swift` | Search, fetch, artworkURL, internal `musicKitAlbum` |
| Create | `MusicWall/Adapters/SystemMusicPlayerAdapter.swift` | `PlaybackController` |
| Create | `MusicWall/Environment+Services.swift` | `@Entry` keys |
| Modify | `MusicWall/AppDependencies.swift` | `albumRepository`, `playbackController` |
| Modify | `MusicWall/StoredAlbum+AlbumRecord.swift` | `asAlbumRecord` includes `isExplicit: false` |
| Modify | `MusicWall/Album.swift` | `StoredAlbums(repository:)`; remove play/pause |
| Modify | `MusicWall/AlbumSearchView.swift` | `[AlbumRecord]`, injected repository |
| Modify | `MusicWall/HomePageView.swift` | Environment install, sheet, `onSearchSelect` |
| Modify | `MusicWall/ContentView.swift` | Pass repository into `StoredAlbums` |
| Modify | `MusicWall/LayoutViews.swift` | Environment playback, `AlbumTapPlayback` |
| Modify | `MusicWall/ImageCache.swift` | `repository.artworkURL` |
| Delete | `MusicWall/MusicService.swift` | After adapters compile |
| Modify | `Agent.md` | Optional one-line protocol pointer |
| Create | `MusicWallTests/TestSupport/MockAlbumRepository.swift` | |
| Create | `MusicWallTests/TestSupport/MockPlaybackController.swift` | |
| Create | `MusicWallTests/Core/AlbumRepositoryTests.swift` | |
| Create | `MusicWallTests/Core/AlbumTapPlaybackTests.swift` | |
| Modify | `MusicWallTests/Fixtures/AlbumFixtures.swift` | `isExplicit` param |
| Modify | `MusicWall.xcodeproj/project.pbxproj` | Register new test files |

**Xcode note:** `MusicWall/` uses synchronized root group — new app files auto-join target. Register each new test file in `project.pbxproj` (mirror `AlbumCollectionTests.swift`).

**Verify no stray references after delete:**

```bash
rg 'MusicService' --glob '*.swift'
```

Expected: no matches (or only comments/docs).

---

### Task 1: `AlbumRecord.isExplicit`

**Files:**
- Modify: `MusicWall/Core/AlbumRecord.swift`
- Modify: `MusicWall/StoredAlbum+AlbumRecord.swift`
- Modify: `MusicWallTests/Fixtures/AlbumFixtures.swift`

- [ ] **Step 1: Add field to `AlbumRecord`**

```swift
struct AlbumRecord: Equatable, Sendable {
    let id: AlbumID
    let title: String
    let artistName: String
    let releaseDate: Date?
    let isExplicit: Bool
}
```

- [ ] **Step 2: Default `isExplicit: false` in `asAlbumRecord`**

```swift
var asAlbumRecord: AlbumRecord {
    AlbumRecord(
        id: AlbumID(rawValue: id.rawValue),
        title: title,
        artistName: artistName,
        releaseDate: releaseDate,
        isExplicit: false
    )
}
```

(Persisted `StoredAlbum` JSON has no explicit flag until PR 6.)

- [ ] **Step 3: Update `AlbumFixtures.record`**

```swift
static func record(
    id: String,
    title: String,
    artistName: String,
    releaseDate: Date? = nil,
    isExplicit: Bool = false
) -> AlbumRecord {
    AlbumRecord(
        id: AlbumID(rawValue: id),
        title: title,
        artistName: artistName,
        releaseDate: releaseDate,
        isExplicit: isExplicit
    )
}
```

- [ ] **Step 4: Build + test**

```bash
xcodebuild build -project MusicWall.xcodeproj -scheme MusicWall \
  -destination 'platform=iOS Simulator,name=iPhone 17' -quiet
bundle exec fastlane ci_tests
```

Expected: `BUILD SUCCEEDED`; tests pass (fix any `AlbumRecord` initializer sites the compiler reports).

- [ ] **Step 5: Commit**

```bash
git add MusicWall/Core/AlbumRecord.swift MusicWall/StoredAlbum+AlbumRecord.swift \
  MusicWallTests/Fixtures/AlbumFixtures.swift
git commit -m "feat: Add isExplicit to AlbumRecord"
```

---

### Task 2: Core protocols and errors

**Files:**
- Create: `MusicWall/Core/AlbumRepository.swift`
- Create: `MusicWall/Core/PlaybackController.swift`

- [ ] **Step 1: Create `AlbumRepository.swift`**

```swift
import Foundation

enum AlbumSearchSource: Sendable {
    case catalog
    case library
}

enum AlbumRepositoryError: Error, LocalizedError, Equatable {
    case invalidQuery
    case albumNotFound
    case searchFailed(String)
    case networkError(String)

    var errorDescription: String? {
        switch self {
        case .invalidQuery:
            return "Search query cannot be empty"
        case .albumNotFound:
            return "Album not found"
        case .searchFailed(let message):
            return "Search failed: \(message)"
        case .networkError(let message):
            return "Network error: \(message)"
        }
    }
}

protocol AlbumRepository: Sendable {
    func search(query: String, source: AlbumSearchSource) async throws -> [AlbumRecord]
    func fetch(ids: [AlbumID]) async throws -> [AlbumRecord]
    func artworkURL(for id: AlbumID, width: Int, height: Int) async -> URL?
}
```

- [ ] **Step 2: Create `PlaybackController.swift`**

```swift
import Foundation

enum PlaybackError: Error, LocalizedError, Equatable {
    case albumNotFound
    case playbackFailed(String)

    var errorDescription: String? {
        switch self {
        case .albumNotFound:
            return "Album not found"
        case .playbackFailed(let message):
            return "Playback failed: \(message)"
        }
    }
}

protocol PlaybackController: Sendable {
    func play(albumId: AlbumID) async throws
    func pause()
}
```

- [ ] **Step 3: Build**

```bash
xcodebuild build -project MusicWall.xcodeproj -scheme MusicWall \
  -destination 'platform=iOS Simulator,name=iPhone 17' -quiet
```

- [ ] **Step 4: Commit**

```bash
git add MusicWall/Core/AlbumRepository.swift MusicWall/Core/PlaybackController.swift
git commit -m "feat: Add AlbumRepository and PlaybackController protocols"
```

---

### Task 3: Test doubles + tap helper

**Files:**
- Create: `MusicWallTests/TestSupport/MockAlbumRepository.swift`
- Create: `MusicWallTests/TestSupport/MockPlaybackController.swift`
- Create: `MusicWall/Core/AlbumTapPlayback.swift`
- Create: `MusicWallTests/Core/AlbumTapPlaybackTests.swift`
- Create: `MusicWallTests/Core/AlbumRepositoryTests.swift`
- Modify: `MusicWall.xcodeproj/project.pbxproj`

- [ ] **Step 1: `MockAlbumRepository`**

```swift
import Foundation
@testable import MusicWall

final class MockAlbumRepository: AlbumRepository, @unchecked Sendable {
    var searchHandler: ((String, AlbumSearchSource) async throws -> [AlbumRecord])?
    var fetchHandler: (([AlbumID]) async throws -> [AlbumRecord])?
    var artworkURLHandler: ((AlbumID, Int, Int) async -> URL?)?

    private(set) var searchCalls: [(String, AlbumSearchSource)] = []
    private(set) var fetchCalls: [[AlbumID]] = []

    func search(query: String, source: AlbumSearchSource) async throws -> [AlbumRecord] {
        searchCalls.append((query, source))
        if let searchHandler { return try await searchHandler(query, source) }
        return []
    }

    func fetch(ids: [AlbumID]) async throws -> [AlbumRecord] {
        fetchCalls.append(ids)
        if let fetchHandler { return try await fetchHandler(ids) }
        return []
    }

    func artworkURL(for id: AlbumID, width: Int, height: Int) async -> URL? {
        if let artworkURLHandler { return await artworkURLHandler(id, width, height) }
        return nil
    }
}
```

- [ ] **Step 2: `MockPlaybackController`**

```swift
import Foundation
@testable import MusicWall

final class MockPlaybackController: PlaybackController, @unchecked Sendable {
    private(set) var playCalls: [AlbumID] = []
    private(set) var pauseCallCount = 0
    var playHandler: ((AlbumID) async throws -> Void)?

    func play(albumId: AlbumID) async throws {
        playCalls.append(albumId)
        if let playHandler { try await playHandler(albumId) }
    }

    func pause() {
        pauseCallCount += 1
    }
}
```

- [ ] **Step 3: `AlbumTapPlayback` helper**

```swift
import Foundation

enum AlbumTapPlayback {
    /// Mirrors PR 5 `onAlbumTapped` behavior for unit tests (PR 11 extracts coordinator).
    static func handleTap(
        albumID: AlbumID,
        rawSelectedID: String?,
        setSelected: @MainActor (String?) -> Void,
        playback: any PlaybackController
    ) async {
        let rawAlbumID = albumID.rawValue
        if rawSelectedID == rawAlbumID {
            playback.pause()
            await setSelected(nil)
        } else {
            await setSelected(rawAlbumID)
            do {
                try await playback.play(albumId: albumID)
            } catch {
                // PR 10: surface to VM
            }
        }
    }
}
```

- [ ] **Step 4: Failing tests — `AlbumRepositoryTests.swift`**

```swift
import Foundation
import Testing
@testable import MusicWall

@Suite struct AlbumRepositoryTests {
    @Test func searchEmptyQueryThrowsInvalidQuery() async {
        let repo = MockAlbumRepository()
        repo.searchHandler = { _, _ in throw AlbumRepositoryError.invalidQuery }

        await #expect(throws: AlbumRepositoryError.invalidQuery) {
            _ = try await repo.search(query: "", source: .catalog)
        }
    }

    @Test func fetchEmptyIDsReturnsEmpty() async throws {
        let repo = MockAlbumRepository()
        let result = try await repo.fetch(ids: [])
        #expect(result.isEmpty)
        #expect(repo.fetchCalls == [[]])
    }

    @Test func searchRecordsSource() async throws {
        let repo = MockAlbumRepository()
        repo.searchHandler = { _, _ in [AlbumFixtures.record(id: "a", title: "T", artistName: "A")] }

        _ = try await repo.search(query: "drake", source: .library)
        #expect(repo.searchCalls == [("drake", .library)])
    }
}
```

- [ ] **Step 5: Failing tests — `AlbumTapPlaybackTests.swift`**

```swift
import Foundation
import Testing
@testable import MusicWall

@Suite struct AlbumTapPlaybackTests {
    @Test func deselectPausesAndClearsSelection() async {
        let playback = MockPlaybackController()
        let albumID = AlbumID(rawValue: "album-1")
        var selected: String? = "album-1"

        await AlbumTapPlayback.handleTap(
            albumID: albumID,
            rawSelectedID: selected,
            setSelected: { selected = $0 },
            playback: playback
        )

        #expect(playback.pauseCallCount == 1)
        #expect(playback.playCalls.isEmpty)
        #expect(selected == nil)
    }

    @Test func newSelectionPlaysAlbum() async {
        let playback = MockPlaybackController()
        let albumID = AlbumID(rawValue: "album-2")
        var selected: String? = nil

        await AlbumTapPlayback.handleTap(
            albumID: albumID,
            rawSelectedID: selected,
            setSelected: { selected = $0 },
            playback: playback
        )

        #expect(playback.playCalls == [albumID])
        #expect(selected == "album-2")
    }
}
```

- [ ] **Step 6: Register test files in `project.pbxproj`**

Add `PBXFileReference`, `PBXBuildFile`, group children under `MusicWallTests/Core/` and `MusicWallTests/TestSupport/`, and `Sources` build phase entries (copy pattern from `AlbumCollectionTests.swift`).

- [ ] **Step 7: Run tests**

```bash
bundle exec fastlane ci_tests
```

Expected: PASS

- [ ] **Step 8: Commit**

```bash
git add MusicWall/Core/AlbumTapPlayback.swift MusicWallTests/TestSupport/ \
  MusicWallTests/Core/AlbumRepositoryTests.swift MusicWallTests/Core/AlbumTapPlaybackTests.swift \
  MusicWall.xcodeproj/project.pbxproj
git commit -m "test: Add repository mocks and tap playback tests"
```

---

### Task 4: `AlbumMapper` + `MusicKitAlbumRepository`

**Files:**
- Create: `MusicWall/Adapters/AlbumMapper.swift`
- Create: `MusicWall/Adapters/MusicKitAlbumRepository.swift`

- [ ] **Step 1: `AlbumMapper`**

```swift
import Foundation
import MusicKit

enum AlbumMapper {
    static func record(from album: MusicKit.Album) -> AlbumRecord {
        AlbumRecord(
            id: AlbumID(rawValue: album.id.rawValue),
            title: album.title,
            artistName: album.artistName,
            releaseDate: album.releaseDate,
            isExplicit: album.contentRating == .explicit
        )
    }
}
```

- [ ] **Step 2: `MusicKitAlbumRepository`**

Move logic from `MusicService.swift` (search, library-first fetch, error mapping). Add:

```swift
import Foundation
import MusicKit

struct MusicKitAlbumRepository: AlbumRepository, Sendable {
    func search(query: String, source: AlbumSearchSource) async throws -> [AlbumRecord] {
        guard !query.isEmpty else { throw AlbumRepositoryError.invalidQuery }
        do {
            let albums: [MusicKit.Album]
            switch source {
            case .catalog:
                let request = MusicCatalogSearchRequest(term: query, types: [MusicKit.Album.self])
                albums = Array(try await request.response().albums)
            case .library:
                let request = MusicLibrarySearchRequest(term: query, types: [MusicKit.Album.self])
                albums = Array(try await request.response().albums)
            }
            return albums.map(AlbumMapper.record(from:))
        } catch {
            throw AlbumRepositoryError.searchFailed(error.localizedDescription)
        }
    }

    func fetch(ids: [AlbumID]) async throws -> [AlbumRecord] {
        guard !ids.isEmpty else { return [] }
        let musicKitAlbums = try await fetchMusicKitAlbums(ids: ids)
        return musicKitAlbums.map(AlbumMapper.record(from:))
    }

    func artworkURL(for id: AlbumID, width: Int, height: Int) async -> URL? {
        guard let album = try? await musicKitAlbum(for: id) else { return nil }
        return album.artwork?.url(width: width, height: height)
    }

    /// Used by `SystemMusicPlayerAdapter` — not on Core protocol.
    func musicKitAlbum(for id: AlbumID) async throws -> MusicKit.Album {
        let albums = try await fetchMusicKitAlbums(ids: [id])
        guard let album = albums.first else { throw AlbumRepositoryError.albumNotFound }
        return album
    }

    private func fetchMusicKitAlbums(ids: [AlbumID]) async throws -> [MusicKit.Album] {
        do {
            let musicItemIDs = ids.map { MusicItemID($0.rawValue) }
            var libraryRequest = MusicLibraryRequest<MusicKit.Album>()
            libraryRequest.filter(matching: \.id, memberOf: musicItemIDs)
            let libraryAlbums = Array(try await libraryRequest.response().items)
            if !libraryAlbums.isEmpty { return libraryAlbums }

            let catalogRequest = MusicCatalogResourceRequest<MusicKit.Album>(
                matching: \.id, memberOf: musicItemIDs
            )
            let catalogAlbums = Array(try await catalogRequest.response().items)
            if catalogAlbums.isEmpty { throw AlbumRepositoryError.albumNotFound }
            return catalogAlbums
        } catch let error as AlbumRepositoryError {
            throw error
        } catch {
            throw AlbumRepositoryError.networkError(error.localizedDescription)
        }
    }
}
```

- [ ] **Step 3: Build** (keep `MusicService.swift` until Task 8)

```bash
xcodebuild build -project MusicWall.xcodeproj -scheme MusicWall \
  -destination 'platform=iOS Simulator,name=iPhone 17' -quiet
```

- [ ] **Step 4: Commit**

```bash
git add MusicWall/Adapters/AlbumMapper.swift MusicWall/Adapters/MusicKitAlbumRepository.swift
git commit -m "feat: Add MusicKit album repository and mapper"
```

---

### Task 5: `SystemMusicPlayerAdapter`

**Files:**
- Create: `MusicWall/Adapters/SystemMusicPlayerAdapter.swift`

- [ ] **Step 1: Implement adapter**

```swift
import Foundation
import MusicKit

struct SystemMusicPlayerAdapter: PlaybackController, Sendable {
    let repository: MusicKitAlbumRepository

    func play(albumId: AlbumID) async throws {
        do {
            let album = try await repository.musicKitAlbum(for: albumId)
            let player = SystemMusicPlayer.shared
            player.queue = [album]
            try await player.play()
        } catch let error as AlbumRepositoryError {
            if case .albumNotFound = error {
                throw PlaybackError.albumNotFound
            }
            throw PlaybackError.playbackFailed(error.localizedDescription)
        } catch let error as PlaybackError {
            throw error
        } catch {
            throw PlaybackError.playbackFailed(error.localizedDescription)
        }
    }

    func pause() {
        SystemMusicPlayer.shared.pause()
    }
}
```

- [ ] **Step 2: Build + commit**

```bash
git add MusicWall/Adapters/SystemMusicPlayerAdapter.swift
git commit -m "feat: Add SystemMusicPlayer playback adapter"
```

---

### Task 6: `AppDependencies` + environment keys

**Files:**
- Create: `MusicWall/Environment+Services.swift`
- Modify: `MusicWall/AppDependencies.swift`

- [ ] **Step 1: Environment keys**

```swift
import SwiftUI

private struct UnimplementedAlbumRepository: AlbumRepository {
    func search(query: String, source: AlbumSearchSource) async throws -> [AlbumRecord] {
        preconditionFailure("albumRepository not installed — set .environment(\\.albumRepository, ...)")
    }
    func fetch(ids: [AlbumID]) async throws -> [AlbumRecord] {
        preconditionFailure("albumRepository not installed")
    }
    func artworkURL(for id: AlbumID, width: Int, height: Int) async -> URL? {
        preconditionFailure("albumRepository not installed")
    }
}

private struct UnimplementedPlaybackController: PlaybackController {
    func play(albumId: AlbumID) async throws {
        preconditionFailure("playback not installed")
    }
    func pause() {
        preconditionFailure("playback not installed")
    }
}

extension EnvironmentValues {
    @Entry var albumRepository: any AlbumRepository = UnimplementedAlbumRepository()
    @Entry var playback: any PlaybackController = UnimplementedPlaybackController()
}
```

- [ ] **Step 2: Extend `AppDependencies`**

```swift
struct AppDependencies {
    let preferencesStore: PreferencesStore
    let albumRepository: any AlbumRepository
    let playbackController: any PlaybackController

    static let live: AppDependencies = {
        let repository = MusicKitAlbumRepository()
        return AppDependencies(
            preferencesStore: UserDefaultsPreferencesStore(userDefaults: .standard),
            albumRepository: repository,
            playbackController: SystemMusicPlayerAdapter(repository: repository)
        )
    }()

    static func preview() -> AppDependencies {
        let suiteName = "com.musicwall.preview.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        return AppDependencies(
            preferencesStore: UserDefaultsPreferencesStore(userDefaults: defaults),
            albumRepository: MockAlbumRepository(),
            playbackController: MockPlaybackController()
        )
    }
}
```

**Note:** `MockAlbumRepository` / `MockPlaybackController` are in the test target. For previews, either:
- Move mocks to a small `MusicWall/PreviewSupport/` file included in app target, **or**
- Use live adapters in previews only, **or**
- Add `#if DEBUG` preview stubs in `AppDependencies.swift`.

**Recommended:** Add `MusicWall/PreviewSupport/PreviewMocks.swift` (app target) with minimal `PreviewAlbumRepository` / `PreviewPlaybackController` structs (empty search, no-op play). Keep full mocks in tests.

- [ ] **Step 3: Add `PreviewSupport` stubs** (if using recommended approach)

```swift
// MusicWall/PreviewSupport/PreviewMocks.swift
import Foundation

struct PreviewAlbumRepository: AlbumRepository {
    func search(query: String, source: AlbumSearchSource) async throws -> [AlbumRecord] { [] }
    func fetch(ids: [AlbumID]) async throws -> [AlbumRecord] { [] }
    func artworkURL(for id: AlbumID, width: Int, height: Int) async -> URL? { nil }
}

struct PreviewPlaybackController: PlaybackController {
    func play(albumId: AlbumID) async throws {}
    func pause() {}
}
```

Use in `AppDependencies.preview()`.

- [ ] **Step 4: Build + commit**

```bash
git add MusicWall/Environment+Services.swift MusicWall/AppDependencies.swift MusicWall/PreviewSupport/PreviewMocks.swift
git commit -m "feat: Wire AppDependencies and environment keys for repository/playback"
```

---

### Task 7: `StoredAlbums` + `ContentView`

**Files:**
- Modify: `MusicWall/Album.swift`
- Modify: `MusicWall/ContentView.swift`

- [ ] **Step 1: Remove `StoredAlbum.play` / `pause`**

Delete lines:

```swift
func play() async throws { try await MusicService.playAlbum(id: id) }
func pause() { MusicService.pauseAlbum() }
```

- [ ] **Step 2: Inject repository into `StoredAlbums`**

```swift
@Observable
class StoredAlbums {
    private let preferences: PreferencesStore
    private let repository: any AlbumRepository
    fileprivate let collection: AlbumCollection
    // ...

    init(preferences: PreferencesStore, repository: any AlbumRepository) {
        self.preferences = preferences
        self.repository = repository
        // existing collection init ...
    }
```

- [ ] **Step 3: `loadItems` backup hydration**

Replace `MusicService.fetchAlbums`:

```swift
let backupIDs = preferences.load([String].self, for: .backupAlbumIDs) ?? []
let ids = backupIDs.map { AlbumID(rawValue: $0) }
guard let records = try? await repository.fetch(ids: ids) else { return }

collection.replaceAll(records, persist: true)
refreshItems()
```

- [ ] **Step 4: `importAlbums`**

```swift
let ids = albumIDStrings.map { AlbumID(rawValue: $0) }
let fetched = try await repository.fetch(ids: ids)
collection.performWithoutPersist {
    for record in fetched {
        if !collection.contains(id: record.id) {
            _ = collection.add(record)
        }
    }
}
```

- [ ] **Step 5: `dummyData`**

```swift
static func dummyData(preferences: PreferencesStore, repository: any AlbumRepository) -> StoredAlbums {
    let storedAlbums = StoredAlbums(preferences: preferences, repository: repository)
    // ...
}
```

- [ ] **Step 6: `ContentView`**

```swift
let store = dependencies.preferencesStore
HomePageView(
    albums: StoredAlbums(preferences: store, repository: dependencies.albumRepository),
    preferences: store,
    dependencies: dependencies
)
```

(Add `dependencies` param to `HomePageView` — Task 8.)

- [ ] **Step 7: Build + commit**

```bash
git add MusicWall/Album.swift MusicWall/ContentView.swift
git commit -m "refactor: Inject AlbumRepository into StoredAlbums"
```

---

### Task 8: `AlbumSearchView` + `HomePageView`

**Files:**
- Modify: `MusicWall/AlbumSearchView.swift`
- Modify: `MusicWall/HomePageView.swift`

- [ ] **Step 1: `AlbumSearchView`**

- Replace `[MusicKitAlbum]` state with `[AlbumRecord]`.
- Add `let repository: any AlbumRepository`.
- `var onSelect: (AlbumRecord) -> Void`.
- `searchAlbums()`:

```swift
catalogSearchResults = try await repository.search(query: query, source: .catalog)
librarySearchResults = try await repository.search(query: query, source: .library)
```

- In `SearchResultButton`, show explicit badge when `record.isExplicit`:

```swift
if record.isExplicit {
    Image(systemName: "e.square.fill")
}
```

- Remove `import MusicKit` if no longer needed.

- [ ] **Step 2: `HomePageView`**

```swift
let dependencies: AppDependencies

init(albums: StoredAlbums, preferences: PreferencesStore, dependencies: AppDependencies) {
    self._albums = State(initialValue: albums)
    self.preferences = preferences
    self.dependencies = dependencies
    // ...
}

private func onSearchSelect(_ record: AlbumRecord) {
    albums.addAlbum(StoredAlbum(from: record))
    showingAlbumAddSnackbar = true
}

// In body, on NavigationStack content:
.environment(\.albumRepository, dependencies.albumRepository)
.environment(\.playback, dependencies.playbackController)

// Sheet:
.sheet(isPresented: $showingAddView) {
    AlbumSearchView(
        repository: dependencies.albumRepository,
        onSelect: onSearchSelect
    )
}
```

- [ ] **Step 3: Update previews**

```swift
let deps = AppDependencies.preview()
HomePageView(
    albums: StoredAlbums.dummyData(preferences: deps.preferencesStore, repository: deps.albumRepository),
    preferences: deps.preferencesStore,
    dependencies: deps
)
```

- [ ] **Step 4: Build + commit**

```bash
git add MusicWall/AlbumSearchView.swift MusicWall/HomePageView.swift
git commit -m "refactor: Migrate search to AlbumRepository and AlbumRecord"
```

---

### Task 9: `LayoutViews` tap + `ImageCache`

**Files:**
- Modify: `MusicWall/LayoutViews.swift`
- Modify: `MusicWall/ImageCache.swift`

- [ ] **Step 1: `GridLayout` / `ListLayout` — add environment**

```swift
@Environment(\.playback) private var playback
```

- [ ] **Step 2: Replace `onAlbumTapped` calls**

```swift
.onTapGesture {
    Task {
        await AlbumTapPlayback.handleTap(
            albumID: AlbumID(rawValue: album.id.rawValue),
            rawSelectedID: selectedAlbumID,
            setSelected: { selectedAlbumID = $0 },
            playback: playback
        )
    }
}
```

Remove the old private `onAlbumTapped` function.

- [ ] **Step 3: `AlbumArtwork` — repository environment**

```swift
@Environment(\.albumRepository) private var albumRepository

// In .task:
imageURL = await ImageCache(repository: albumRepository).getArtwork(
    albumID: album.id.rawValue,
    size: pixelSize
)
```

- [ ] **Step 4: `ImageCache`**

```swift
struct ImageCache {
    private let repository: any AlbumRepository
    private let fileManager = FileManager.default

    init(repository: any AlbumRepository) {
        self.repository = repository
    }

    func getArtwork(albumID: String, size: Int) async -> URL? {
        // ... existing cache hit logic ...
        let id = AlbumID(rawValue: albumID)
        guard let artworkURL = await repository.artworkURL(for: id, width: size, height: size) else {
            return nil
        }
        // ... existing download + write ...
    }
}
```

- [ ] **Step 5: Layout previews** — install environment on preview hierarchy:

```swift
.environment(\.albumRepository, deps.albumRepository)
.environment(\.playback, deps.playbackController)
```

- [ ] **Step 6: Build + commit**

```bash
git add MusicWall/LayoutViews.swift MusicWall/ImageCache.swift
git commit -m "refactor: Playback and artwork via injected protocols"
```

---

### Task 10: Delete `MusicService` + docs

**Files:**
- Delete: `MusicWall/MusicService.swift`
- Modify: `Agent.md` (optional)
- Modify: any preview/test using `StoredAlbums.dummyData` without repository

- [ ] **Step 1: Grep**

```bash
rg 'MusicService' --glob '*.swift'
```

Fix any remaining references.

- [ ] **Step 2: Delete file**

```bash
git rm MusicWall/MusicService.swift
```

- [ ] **Step 3: `Agent.md`** (optional)

Replace MusicService bullet with: album search/fetch via `AlbumRepository`; playback via `PlaybackController` (`AppDependencies.live`).

- [ ] **Step 4: Full CI**

```bash
bundle exec fastlane ci_tests
```

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "refactor: Remove MusicService; complete repository/playback migration"
```

---

### Task 11: PR hygiene

- [ ] **Step 1: Spec coverage grep**

```bash
rg 'MusicService' .
```

Expected: only docs/history, not Swift app code.

- [ ] **Step 2: Push branch**

```bash
git push -u origin cursor/test-refactor-pr-05-repository-playback
```

- [ ] **Step 3: Open PR**

Title: `test refactor PR 5: AlbumRepository + PlaybackController`

Body: link `docs/specs/2026-05-27-pr-05-repository-playback-design.md`, "PR 5 of 14", human verification checklist (search catalog/library, explicit badge, tap play/pause, artwork, backup ID restore).

---

## Spec coverage checklist (self-review)

| Spec requirement | Task |
|------------------|------|
| `AlbumRecord.isExplicit` | Task 1 |
| Core protocols + errors | Task 2 |
| `AlbumMapper` | Task 4 |
| `MusicKitAlbumRepository` + `artworkURL` | Task 4 |
| `SystemMusicPlayerAdapter` + no force-unwrap | Task 5 |
| Hybrid injection | Tasks 6–9 |
| `AlbumSearchView` → `AlbumRecord` | Task 8 |
| Remove `StoredAlbum.play`/`pause` | Task 7 |
| Tap via `PlaybackController` / `AlbumTapPlayback` | Tasks 3, 9 |
| `ImageCache` → `artworkURL` | Task 9 |
| Delete `MusicService` | Task 10 |
| Mock tests + tap order | Task 3 |
| `ci-tests` green | Tasks 1, 3, 10 |

## Human verification (PR description)

- Search Apple Music + Library; explicit **E** badge when applicable.
- Add album from search; appears in grid/list.
- Tap album → plays; tap again → pauses.
- Artwork loads (grid + list).
- Clear saved albums, keep backup IDs → relaunch restores from backup fetch.

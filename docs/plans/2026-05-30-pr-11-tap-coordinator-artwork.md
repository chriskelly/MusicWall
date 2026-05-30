# PR 11 — Tap Coordinator + Artwork Pipeline Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rename `AlbumTapPlayback` to `AlbumTapCoordinator`, introduce mockable `ArtworkProvider` + refactored `ImageCache`, remove `artworkURL` from `AlbumRepository`, and wire artwork through `AppDependencies` + environment.

**Architecture:** Split artwork resolution (`ArtworkProvider` / `MusicKitArtworkProvider`) from disk cache + download (`ImageCache` with injected session/filesystem). Hybrid injection matches PR 5: `AppDependencies` holds live/preview providers; `HomePageView` installs `@Environment(\.artworkProvider)`. Tap coordinator stays pure functions.

**Tech Stack:** Swift 5, Swift Testing, SwiftUI, Xcode 16+, scheme `MusicWall`, simulator `iPhone 17`, `bundle exec fastlane ci_tests`.

**Spec:** `docs/specs/2026-05-30-pr-11-tap-coordinator-artwork-design.md`

**Branch:** `cursor/test-refactor-pr-11-tap-coordinator-artwork`

---

## File map

| Action | Path | Notes |
|--------|------|-------|
| Create | `MusicWall/Core/ArtworkProvider.swift` | Core protocol |
| Create | `MusicWall/Core/URLSessionDataProviding.swift` | Network protocol |
| Create | `MusicWall/Adapters/URLSession+DataProviding.swift` | `URLSession` conformance |
| Create | `MusicWall/Adapters/MusicKitArtworkProvider.swift` | MusicKit URL resolution |
| Modify | `MusicWall/ImageCache.swift` | Inject artworkProvider, session, fileManager, cacheDirectory |
| Modify | `MusicWall/Core/AlbumRepository.swift` | Remove `artworkURL` |
| Modify | `MusicWall/Adapters/MusicKitAlbumRepository.swift` | Remove `artworkURL` |
| Modify | `MusicWall/Environment+Services.swift` | Add `artworkProvider` key; drop `artworkURL` from stub |
| Modify | `MusicWall/AppDependencies.swift` | Add `artworkProvider` field |
| Modify | `MusicWall/PreviewSupport/PreviewMocks.swift` | Add `PreviewArtworkProvider`; trim `PreviewAlbumRepository` |
| Modify | `MusicWall/Features/Home/HomePageView.swift` | Install artwork env |
| Modify | `MusicWall/LayoutViews.swift` | Artwork env + displayScale; tap rename; preview env |
| Rename | `MusicWall/Core/AlbumTapPlayback.swift` → `AlbumTapCoordinator.swift` | Same logic, new name |
| Create | `MusicWallTests/TestSupport/MockArtworkProvider.swift` | Test double |
| Create | `MusicWallTests/TestSupport/MockURLSession.swift` | Test double |
| Create | `MusicWallTests/Core/ImageCacheTests.swift` | Cache hit/miss/fail tests |
| Rename | `MusicWallTests/Core/AlbumTapPlaybackTests.swift` → `AlbumTapCoordinatorTests.swift` | Update type references |
| Modify | `MusicWallTests/TestSupport/MockAlbumRepository.swift` | Remove `artworkURL` |
| Modify | `MusicWall.xcodeproj/project.pbxproj` | Register new/rename test files |
| Modify | `Agent.md` | Note ArtworkProvider + AlbumTapCoordinator |

**Xcode note:** `MusicWall/` uses `PBXFileSystemSynchronizedRootGroup` — new app files under `MusicWall/Core/` and `MusicWall/Adapters/` auto-join the target. Test files must be registered in `project.pbxproj` (mirror `MockAlbumRepository.swift`). When renaming test files, update `PBXFileReference` path and group entries.

---

### Task 1: Branch + register test files

**Files:**
- Modify: `MusicWall.xcodeproj/project.pbxproj`

- [ ] **Step 1: Create branch**

```bash
git checkout main
git pull
git checkout -b cursor/test-refactor-pr-11-tap-coordinator-artwork
```

- [ ] **Step 2: Register test files in Xcode project**

Add to `MusicWallTests` target under `TestSupport/` and `Core/`:

- `MockArtworkProvider.swift`
- `MockURLSession.swift`
- `ImageCacheTests.swift`

Rename in project (update path on existing reference):

- `AlbumTapPlaybackTests.swift` → `AlbumTapCoordinatorTests.swift`

Mirror `MockAlbumRepository.swift` registration: `PBXFileReference`, `PBXBuildFile`, group children, Sources build phase.

- [ ] **Step 3: Commit**

```bash
git add MusicWall.xcodeproj/project.pbxproj
git commit -m "chore: Register PR 11 test files"
```

---

### Task 2: Core protocols

**Files:**
- Create: `MusicWall/Core/ArtworkProvider.swift`
- Create: `MusicWall/Core/URLSessionDataProviding.swift`
- Create: `MusicWall/Adapters/URLSession+DataProviding.swift`

- [ ] **Step 1: Create `ArtworkProvider.swift`**

```swift
import Foundation

protocol ArtworkProvider: Sendable {
    func artworkURL(for id: AlbumID, width: Int, height: Int) async -> URL?
}
```

- [ ] **Step 2: Create `URLSessionDataProviding.swift`**

```swift
import Foundation

protocol URLSessionDataProviding: Sendable {
    func data(from url: URL) async throws -> (Data, URLResponse)
}
```

- [ ] **Step 3: Create `URLSession+DataProviding.swift`**

```swift
import Foundation

extension URLSession: URLSessionDataProviding {}
```

- [ ] **Step 4: Build app target**

Run:

```bash
xcodebuild build -project MusicWall.xcodeproj -scheme MusicWall \
  -destination 'platform=iOS Simulator,name=iPhone 17' -quiet
```

Expected: `BUILD SUCCEEDED`

- [ ] **Step 5: Commit**

```bash
git add MusicWall/Core/ArtworkProvider.swift MusicWall/Core/URLSessionDataProviding.swift \
  MusicWall/Adapters/URLSession+DataProviding.swift
git commit -m "feat: Add ArtworkProvider and URLSessionDataProviding protocols"
```

---

### Task 3: Test doubles — `MockArtworkProvider` + `MockURLSession`

**Files:**
- Create: `MusicWallTests/TestSupport/MockArtworkProvider.swift`
- Create: `MusicWallTests/TestSupport/MockURLSession.swift`

- [ ] **Step 1: Create `MockArtworkProvider.swift`**

```swift
import Foundation
@testable import MusicWall

final class MockArtworkProvider: ArtworkProvider, @unchecked Sendable {
    var artworkURLHandler: ((AlbumID, Int, Int) async -> URL?)?
    private(set) var artworkURLCalls: [(AlbumID, Int, Int)] = []

    func artworkURL(for id: AlbumID, width: Int, height: Int) async -> URL? {
        artworkURLCalls.append((id, width, height))
        if let artworkURLHandler { return await artworkURLHandler(id, width, height) }
        return nil
    }
}
```

- [ ] **Step 2: Create `MockURLSession.swift`**

```swift
import Foundation
@testable import MusicWall

final class MockURLSession: URLSessionDataProviding, @unchecked Sendable {
    var dataHandler: ((URL) async throws -> (Data, URLResponse))?
    private(set) var dataCalls: [URL] = []

    func data(from url: URL) async throws -> (Data, URLResponse) {
        dataCalls.append(url)
        if let dataHandler { return try await dataHandler(url) }
        return (Data(), URLResponse())
    }
}
```

- [ ] **Step 3: Build tests target**

Run:

```bash
xcodebuild build-for-testing -project MusicWall.xcodeproj -scheme MusicWall \
  -destination 'platform=iOS Simulator,name=iPhone 17' -quiet
```

Expected: `BUILD SUCCEEDED`

- [ ] **Step 4: Commit**

```bash
git add MusicWallTests/TestSupport/MockArtworkProvider.swift \
  MusicWallTests/TestSupport/MockURLSession.swift
git commit -m "test: Add MockArtworkProvider and MockURLSession"
```

---

### Task 4: `ImageCache` — failing tests + implementation (TDD)

**Files:**
- Create: `MusicWallTests/Core/ImageCacheTests.swift`
- Modify: `MusicWall/ImageCache.swift`

- [ ] **Step 1: Create failing `ImageCacheTests.swift`**

```swift
import Foundation
import Testing
@testable import MusicWall

@Suite struct ImageCacheTests {
    private func makeTempCacheDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @Test func cacheHitReturnsLocalURLWithoutCallingProviderOrSession() async throws {
        let cacheDir = try makeTempCacheDirectory()
        defer { try? FileManager.default.removeItem(at: cacheDir) }

        let albumID = "album-1"
        let size = 100
        let cachedFile = cacheDir.appendingPathComponent("\(albumID)_\(size).jpg")
        try Data([0xFF, 0xD8, 0xFF]).write(to: cachedFile)

        let provider = MockArtworkProvider()
        let session = MockURLSession()
        let cache = ImageCache(
            artworkProvider: provider,
            session: session,
            fileManager: .default,
            cacheDirectory: cacheDir
        )

        let result = await cache.getArtwork(albumID: albumID, size: size)

        #expect(result == cachedFile)
        #expect(provider.artworkURLCalls.isEmpty)
        #expect(session.dataCalls.isEmpty)
    }

    @Test func cacheMissDownloadsAndWritesFile() async throws {
        let cacheDir = try makeTempCacheDirectory()
        defer { try? FileManager.default.removeItem(at: cacheDir) }

        let remoteURL = URL(string: "https://example.com/art.jpg")!
        let provider = MockArtworkProvider()
        provider.artworkURLHandler = { _, width, height in
            #expect(width == 100)
            #expect(height == 100)
            return remoteURL
        }
        let session = MockURLSession()
        session.dataHandler = { url in
            #expect(url == remoteURL)
            return (Data([0xFF, 0xD8, 0xFF]), URLResponse())
        }

        let cache = ImageCache(
            artworkProvider: provider,
            session: session,
            fileManager: .default,
            cacheDirectory: cacheDir
        )

        let result = await cache.getArtwork(albumID: "album-2", size: 100)

        let expectedLocal = cacheDir.appendingPathComponent("album-2_100.jpg")
        #expect(result == expectedLocal)
        #expect(FileManager.default.fileExists(atPath: expectedLocal.path))
        #expect(provider.artworkURLCalls.count == 1)
        #expect(session.dataCalls == [remoteURL])
    }

    @Test func downloadFailureReturnsRemoteURL() async throws {
        let cacheDir = try makeTempCacheDirectory()
        defer { try? FileManager.default.removeItem(at: cacheDir) }

        let remoteURL = URL(string: "https://example.com/art.jpg")!
        let provider = MockArtworkProvider()
        provider.artworkURLHandler = { _, _, _ in remoteURL }
        let session = MockURLSession()
        session.dataHandler = { _ in throw URLError(.notConnectedToInternet) }

        let cache = ImageCache(
            artworkProvider: provider,
            session: session,
            fileManager: .default,
            cacheDirectory: cacheDir
        )

        let result = await cache.getArtwork(albumID: "album-3", size: 100)

        #expect(result == remoteURL)
        let localFile = cacheDir.appendingPathComponent("album-3_100.jpg")
        #expect(FileManager.default.fileExists(atPath: localFile.path) == false)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
xcodebuild test -project MusicWall.xcodeproj -scheme MusicWall \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:MusicWallTests/ImageCacheTests -quiet
```

Expected: FAIL — `ImageCache` still requires `AlbumRepository` / missing `cacheDirectory` parameter.

- [ ] **Step 3: Refactor `ImageCache.swift`**

Replace entire file:

```swift
//
//  ImageCache.swift
//  MusicWall
//

import Foundation

struct ImageCache {
    private let artworkProvider: any ArtworkProvider
    private let session: any URLSessionDataProviding
    private let fileManager: FileManager
    private let cacheDirectory: URL

    init(
        artworkProvider: any ArtworkProvider,
        session: any URLSessionDataProviding = URLSession.shared,
        fileManager: FileManager = .default,
        cacheDirectory: URL? = nil
    ) {
        self.artworkProvider = artworkProvider
        self.session = session
        self.fileManager = fileManager
        self.cacheDirectory = cacheDirectory
            ?? fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
    }

    /// Get cached artwork for an album ID and size, or fetch and cache it
    func getArtwork(albumID: String, size: Int) async -> URL? {
        let filename = "\(albumID)_\(size).jpg"
        let localURL = cacheDirectory.appendingPathComponent(filename)

        if fileManager.fileExists(atPath: localURL.path) {
            return localURL
        }

        let id = AlbumID(rawValue: albumID)
        guard let artworkURL = await artworkProvider.artworkURL(for: id, width: size, height: size) else {
            return nil
        }

        do {
            let (data, _) = try await session.data(from: artworkURL)
            try data.write(to: localURL)
            return localURL
        } catch {
            print("Failed to cache artwork: \(error)")
            return artworkURL
        }
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run:

```bash
xcodebuild test -project MusicWall.xcodeproj -scheme MusicWall \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:MusicWallTests/ImageCacheTests -quiet
```

Expected: all 3 tests PASS

- [ ] **Step 5: Commit**

```bash
git add MusicWall/ImageCache.swift MusicWallTests/Core/ImageCacheTests.swift
git commit -m "feat: Refactor ImageCache with injectable ArtworkProvider and session"
```

---

### Task 5: `MusicKitArtworkProvider` adapter

**Files:**
- Create: `MusicWall/Adapters/MusicKitArtworkProvider.swift`
- Modify: `MusicWall/Adapters/MusicKitAlbumRepository.swift`

- [ ] **Step 1: Create `MusicKitArtworkProvider.swift`**

```swift
import Foundation
import MusicKit

struct MusicKitArtworkProvider: ArtworkProvider, Sendable {
    let repository: MusicKitAlbumRepository

    func artworkURL(for id: AlbumID, width: Int, height: Int) async -> URL? {
        guard let album = try? await repository.musicKitAlbum(for: id) else { return nil }
        return album.artwork?.url(width: width, height: height)
    }
}
```

- [ ] **Step 2: Remove `artworkURL` from `MusicKitAlbumRepository.swift`**

Delete this method (lines 29–32):

```swift
    func artworkURL(for id: AlbumID, width: Int, height: Int) async -> URL? {
        guard let album = try? await musicKitAlbum(for: id) else { return nil }
        return album.artwork?.url(width: width, height: height)
    }
```

Keep `musicKitAlbum(for:)` — still used by `SystemMusicPlayerAdapter`.

- [ ] **Step 3: Build app target**

Run:

```bash
xcodebuild build -project MusicWall.xcodeproj -scheme MusicWall \
  -destination 'platform=iOS Simulator,name=iPhone 17' -quiet
```

Expected: FAIL until Task 6 removes `artworkURL` from protocol — proceed to Task 6 before expecting green build.

- [ ] **Step 4: Commit**

```bash
git add MusicWall/Adapters/MusicKitArtworkProvider.swift MusicWall/Adapters/MusicKitAlbumRepository.swift
git commit -m "feat: Add MusicKitArtworkProvider; remove artworkURL from repository adapter"
```

---

### Task 6: Remove `artworkURL` from `AlbumRepository` + mocks

**Files:**
- Modify: `MusicWall/Core/AlbumRepository.swift`
- Modify: `MusicWall/Environment+Services.swift`
- Modify: `MusicWallTests/TestSupport/MockAlbumRepository.swift`
- Modify: `MusicWall/PreviewSupport/PreviewMocks.swift`

- [ ] **Step 1: Remove from `AlbumRepository` protocol**

Delete line:

```swift
    func artworkURL(for id: AlbumID, width: Int, height: Int) async -> URL?
```

- [ ] **Step 2: Remove from `UnimplementedAlbumRepository` in `Environment+Services.swift`**

Delete:

```swift
    func artworkURL(for id: AlbumID, width: Int, height: Int) async -> URL? {
        preconditionFailure("albumRepository not installed")
    }
```

- [ ] **Step 3: Trim `MockAlbumRepository.swift`**

Remove `artworkURLHandler`, `artworkURL(for:width:height:)`, and any test usages of `artworkURLHandler` elsewhere in test suite (grep to confirm none remain).

- [ ] **Step 4: Trim `PreviewAlbumRepository` in `PreviewMocks.swift`**

Remove `artworkURL(for:width:height:)` method.

Add:

```swift
struct PreviewArtworkProvider: ArtworkProvider {
    func artworkURL(for id: AlbumID, width: Int, height: Int) async -> URL? { nil }
}
```

- [ ] **Step 5: Build**

Run:

```bash
xcodebuild build -project MusicWall.xcodeproj -scheme MusicWall \
  -destination 'platform=iOS Simulator,name=iPhone 17' -quiet
```

Expected: FAIL until `LayoutViews` updated — continue Task 7–8.

- [ ] **Step 6: Commit**

```bash
git add MusicWall/Core/AlbumRepository.swift MusicWall/Environment+Services.swift \
  MusicWallTests/TestSupport/MockAlbumRepository.swift MusicWall/PreviewSupport/PreviewMocks.swift
git commit -m "refactor: Remove artworkURL from AlbumRepository protocol and mocks"
```

---

### Task 7: `AppDependencies` + environment key

**Files:**
- Modify: `MusicWall/AppDependencies.swift`
- Modify: `MusicWall/Environment+Services.swift`

- [ ] **Step 1: Add `artworkProvider` to `AppDependencies`**

```swift
struct AppDependencies {
    let preferencesStore: PreferencesStore
    let albumRepository: any AlbumRepository
    let artworkProvider: any ArtworkProvider
    let playbackController: any PlaybackController
    let albumBackupService: any AlbumBackupService
    let musicAuthorization: any MusicAuthorizationProviding

    static let live: AppDependencies = {
        let repository = MusicKitAlbumRepository()
        return AppDependencies(
            preferencesStore: UserDefaultsPreferencesStore(userDefaults: .standard),
            albumRepository: repository,
            artworkProvider: MusicKitArtworkProvider(repository: repository),
            playbackController: SystemMusicPlayerAdapter(repository: repository),
            albumBackupService: LiveAlbumBackupService(),
            musicAuthorization: LiveMusicAuthorizationProvider()
        )
    }()

    static func preview() -> AppDependencies {
        let suiteName = "com.musicwall.preview.\(UUID().uuidString)"
        let defaults = UserDefaults(suite: suiteName)!
        return AppDependencies(
            preferencesStore: UserDefaultsPreferencesStore(userDefaults: defaults),
            albumRepository: PreviewAlbumRepository(),
            artworkProvider: PreviewArtworkProvider(),
            playbackController: PreviewPlaybackController(),
            albumBackupService: LiveAlbumBackupService(),
            musicAuthorization: PreviewMusicAuthorizationProvider(status: .authorized)
        )
    }
}
```

- [ ] **Step 2: Add environment key to `Environment+Services.swift`**

Add unimplemented stub and entry:

```swift
private struct UnimplementedArtworkProvider: ArtworkProvider {
    func artworkURL(for id: AlbumID, width: Int, height: Int) async -> URL? {
        preconditionFailure("artworkProvider not installed — set .environment(\\.artworkProvider, ...)")
    }
}

extension EnvironmentValues {
    @Entry var artworkProvider: any ArtworkProvider = UnimplementedArtworkProvider()
}
```

(Keep existing `albumRepository` and `playback` entries unchanged.)

- [ ] **Step 3: Fix any `AppDependencies(` call sites**

Grep for `AppDependencies(` in tests/previews — update initializers if any construct `AppDependencies` manually beyond `live` / `preview()`.

- [ ] **Step 4: Commit**

```bash
git add MusicWall/AppDependencies.swift MusicWall/Environment+Services.swift
git commit -m "feat: Wire ArtworkProvider through AppDependencies and environment"
```

---

### Task 8: View wiring — `HomePageView` + `LayoutViews`

**Files:**
- Modify: `MusicWall/Features/Home/HomePageView.swift`
- Modify: `MusicWall/LayoutViews.swift`

- [ ] **Step 1: Install artwork environment in `HomePageView.swift`**

After existing environment lines (~27–28), add:

```swift
        .environment(\.artworkProvider, dependencies.artworkProvider)
```

- [ ] **Step 2: Update `AlbumArtwork` in `LayoutViews.swift`**

Replace `@Environment(\.albumRepository)` with `@Environment(\.artworkProvider)` and add `@Environment(\.displayScale)`.

Replace `.task` body:

```swift
        .task {
            let pixelSize = Int((viewSize * displayScale).rounded())
            imageURL = await ImageCache(artworkProvider: artworkProvider)
                .getArtwork(albumID: album.id.rawValue, size: pixelSize)
        }
```

Remove `import UIKit` from top of file if present and unused elsewhere.

- [ ] **Step 3: Update `#Preview` at bottom of `LayoutViews.swift`**

Add artwork environment to both layout previews:

```swift
        .environment(\.artworkProvider, deps.artworkProvider)
```

- [ ] **Step 4: Build app target**

Run:

```bash
xcodebuild build -project MusicWall.xcodeproj -scheme MusicWall \
  -destination 'platform=iOS Simulator,name=iPhone 17' -quiet
```

Expected: `BUILD SUCCEEDED`

- [ ] **Step 5: Commit**

```bash
git add MusicWall/Features/Home/HomePageView.swift MusicWall/LayoutViews.swift
git commit -m "feat: Wire artworkProvider env and displayScale in layout views"
```

---

### Task 9: Rename `AlbumTapPlayback` → `AlbumTapCoordinator`

**Files:**
- Rename: `MusicWall/Core/AlbumTapPlayback.swift` → `AlbumTapCoordinator.swift`
- Rename: `MusicWallTests/Core/AlbumTapPlaybackTests.swift` → `AlbumTapCoordinatorTests.swift`
- Modify: `MusicWall/LayoutViews.swift`
- Modify: `MusicWall.xcodeproj/project.pbxproj`

- [ ] **Step 1: Rename app file and update enum**

In `AlbumTapCoordinator.swift`:

```swift
import Foundation

enum AlbumTapCoordinator {
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
            _ = try? await playback.play(albumId: albumID)
        }
    }
}
```

Delete `AlbumTapPlayback.swift`.

- [ ] **Step 2: Update call sites in `LayoutViews.swift`**

Replace both `AlbumTapPlayback.handleTap` with `AlbumTapCoordinator.handleTap`.

- [ ] **Step 3: Rename test file and update references**

In `AlbumTapCoordinatorTests.swift`:

```swift
import Foundation
import Testing
@testable import MusicWall

@Suite struct AlbumTapCoordinatorTests {
    @Test func deselectPausesAndClearsSelection() async {
        let playback = MockPlaybackController()
        let albumID = AlbumID(rawValue: "album-1")
        var selected: String? = "album-1"

        await AlbumTapCoordinator.handleTap(
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

        await AlbumTapCoordinator.handleTap(
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

Delete `AlbumTapPlaybackTests.swift`. Update `project.pbxproj` file reference path if not done in Task 1.

- [ ] **Step 4: Run tap tests**

Run:

```bash
xcodebuild test -project MusicWall.xcodeproj -scheme MusicWall \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:MusicWallTests/AlbumTapCoordinatorTests -quiet
```

Expected: 2 tests PASS

- [ ] **Step 5: Commit**

```bash
git add MusicWall/Core/AlbumTapCoordinator.swift MusicWall/LayoutViews.swift \
  MusicWallTests/Core/AlbumTapCoordinatorTests.swift MusicWall.xcodeproj/project.pbxproj
git rm MusicWall/Core/AlbumTapPlayback.swift MusicWallTests/Core/AlbumTapPlaybackTests.swift 2>/dev/null || true
git commit -m "refactor: Rename AlbumTapPlayback to AlbumTapCoordinator"
```

---

### Task 10: Full CI + docs

**Files:**
- Modify: `Agent.md`

- [ ] **Step 1: Update `Agent.md`**

Add bullet under architecture/services (near existing `AlbumRepository` / `PlaybackController` notes):

```markdown
- Album artwork via `ArtworkProvider` + `ImageCache`; tap-to-play via `AlbumTapCoordinator` + `PlaybackController`.
```

- [ ] **Step 2: Run full test suite**

Run:

```bash
bundle exec fastlane ci_tests
```

Expected: all tests PASS

- [ ] **Step 3: Grep verification**

Run:

```bash
rg 'AlbumTapPlayback|artworkURL' --glob '*.swift'
```

Expected: no matches in app/test Swift files (docs/plans may still reference old names).

- [ ] **Step 4: Commit**

```bash
git add Agent.md
git commit -m "docs: Note ArtworkProvider and AlbumTapCoordinator in Agent.md"
```

---

## Spec coverage checklist

| Spec requirement | Task |
|------------------|------|
| Rename `AlbumTapPlayback` → `AlbumTapCoordinator` | Task 9 |
| `ArtworkProvider` protocol | Task 2 |
| `MusicKitArtworkProvider` adapter | Task 5 |
| `ImageCache` injects provider, session, fileManager, cacheDirectory | Task 4 |
| Remove `artworkURL` from `AlbumRepository` | Tasks 5–6 |
| `@Environment(\.artworkProvider)` + `AppDependencies` | Tasks 7–8 |
| `@Environment(\.displayScale)` in `AlbumArtwork` | Task 8 |
| Tap state machine tests | Task 9 (existing, renamed) |
| ImageCache: cache hit, miss+download, fail→remote | Task 4 |
| `ci-tests` green | Task 10 |

---

## Human verification (PR description)

- Grid and list artwork loads on device/simulator.
- Tap album to play; tap again to pause.
- SwiftUI previews for `GridLayout` / `ListLayout` render without crash.

**PR title:** `test refactor PR 11: AlbumTapCoordinator + ArtworkProvider`

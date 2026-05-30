# PR 11 — Tap coordinator + artwork pipeline

**Status:** Approved (2026-05-30)  
**Program:** MusicWall testability refactor  
**Requires:** PR 5 merged  
**Blocks:** PR 12  
**Approach:** Hybrid injection for `ArtworkProvider` (Option C) + split resolution/caching (Option 1) + rename tap helper to `AlbumTapCoordinator` (Option A) + `@Environment(\.displayScale)` (Option A)

## Summary

Rename the interim **`AlbumTapPlayback`** helper to **`AlbumTapCoordinator`** (pure functions, behavior unchanged). Introduce **`ArtworkProvider`** in Core with a **`MusicKitArtworkProvider`** adapter, refactor **`ImageCache`** to inject artwork resolution, network, and filesystem dependencies, and remove **`artworkURL`** from **`AlbumRepository`**. Wire **`ArtworkProvider`** through **`AppDependencies`** and **`@Environment(\.artworkProvider)`**. Replace **`UIScreen.main.scale`** in **`AlbumArtwork`** with **`@Environment(\.displayScale)`**. Unit tests cover the tap state machine (existing) and artwork cache hit, cache miss + download, and download-fail fallback paths using mocks only.

## Goals

- **`AlbumTapCoordinator`**: same PR 5 tap behavior (select/deselect, play, pause) via **`PlaybackController`**; coordinator unit-tested.
- **`ArtworkProvider`** protocol in Core; **`MusicKitArtworkProvider`** in Adapters owns MusicKit artwork URL resolution.
- **`ImageCache`** injects **`ArtworkProvider`**, **`URLSessionDataProviding`**, and **`FileManager`** — fully mockable, no network in tests.
- **`AlbumRepository`** no longer exposes **`artworkURL`** (no duplicate APIs).
- **`@Environment(\.artworkProvider)`** installed from **`HomePageView`**; live/preview values from **`AppDependencies`**.
- **`AlbumArtwork`** uses **`@Environment(\.displayScale)`** instead of **`UIScreen.main`**.
- **`ImageCacheTests`**: cache hit; cache miss + download; download fail returns remote URL.

## Non-goals

- ViewInspector or SwiftUI hosting tests (PR 12).
- Playback or search error UX changes (still `try?` / deferred).
- Fat **`ArtworkProvider`** that absorbs disk cache and download (Option 2 rejected).
- Grid/list layout refactor beyond artwork/tap wiring.
- SPM module split (PR 15).

## Decisions (brainstorming)

| Topic | Choice |
|-------|--------|
| Artwork injection | **`AppDependencies.artworkProvider`** + **`@Environment(\.artworkProvider)`** (hybrid, matches PR 5) |
| Tap coordinator shape | Rename **`AlbumTapPlayback`** → **`AlbumTapCoordinator`**; keep pure static functions |
| Display scale | **`@Environment(\.displayScale)`** in **`AlbumArtwork`** (no HomeViewModel) |
| Artwork pipeline | Split: **`ArtworkProvider`** resolves URL; **`ImageCache`** caches/downloads |
| URLSession mocking | Thin **`URLSessionDataProviding`** protocol; **`URLSession`** conformance extension |

## Approaches considered

### Artwork pipeline

| Option | Description | Why not chosen |
|--------|-------------|----------------|
| **1 (chosen)** | **`ArtworkProvider`** resolves remote URL; **`ImageCache`** handles disk + download | Matches skill; cache tests isolated from MusicKit |
| 2 | Fat **`ArtworkProvider`** absorbs **`ImageCache`** | Blurs boundaries; harder to test cache paths in isolation |
| 3 | Keep **`artworkURL`** on repository; inject session/filesystem only | Violates acceptance criteria; repository stays bloated |

### Artwork delivery

| Option | Description | Why not chosen |
|--------|-------------|----------------|
| **C (chosen)** | Field on **`AppDependencies`** + environment key for deep views | Single composition root; no parameter creep; matches PR 5 hybrid |
| A | Environment only, no **`AppDependencies`** field | Loses composition root; previews construct ad hoc |
| B | Explicit parameters through layout hierarchy | Parameter creep on **`GridLayout`** / **`ListLayout`** / tile views |

### Tap coordinator

| Option | Description | Why not chosen |
|--------|-------------|----------------|
| **A (chosen)** | Rename to **`AlbumTapCoordinator`**; same pure-function API | Skill naming; minimal diff; already tested |
| B | Struct holding **`playback`** with instance method | Ceremony without test benefit for ~15-line state machine |
| C | Leave **`AlbumTapPlayback`** name; artwork-only PR | Drift from roadmap/docs |

### Display scale

| Option | Description | Why not chosen |
|--------|-------------|----------------|
| **A (chosen)** | **`@Environment(\.displayScale)`** | Native SwiftUI; removes UIKit from artwork path |
| B | Thread scale from **`HomeViewModel`** | Unnecessary coupling for a view-local concern |

## Architecture

### Layer placement

```
MusicWall/
  Core/
    AlbumTapCoordinator.swift          # rename from AlbumTapPlayback
    ArtworkProvider.swift              # protocol
    URLSessionDataProviding.swift      # protocol for network mock
  Adapters/
    MusicKitArtworkProvider.swift      # MusicKit URL resolution
  ImageCache.swift                     # inject artworkProvider + session + fileManager
  Environment+Services.swift           # + artworkProvider env key
  AppDependencies.swift                # + artworkProvider field
  LayoutViews.swift                    # AlbumArtwork: env artworkProvider, displayScale
  PreviewSupport/
    PreviewMocks.swift                 # PreviewArtworkProvider; drop artworkURL from PreviewAlbumRepository

MusicWallTests/
  Core/
    AlbumTapCoordinatorTests.swift       # rename from AlbumTapPlaybackTests
    ImageCacheTests.swift                # new
  TestSupport/
    MockArtworkProvider.swift
    MockURLSession.swift                 # or handler-based URLSessionDataProviding double
    MockAlbumRepository.swift            # remove artworkURLHandler / artworkURL
```

Delete **`MusicWall/Core/AlbumTapPlayback.swift`** after rename.

### Dependency rules

| Module / folder | May import |
|-----------------|------------|
| **`MusicWall/Core/`** | Foundation |
| **`MusicWall/Adapters/`** | Foundation, MusicKit |
| **`Environment+Services.swift`** | SwiftUI, Core protocols |
| **`ImageCache.swift`** | Foundation, Core protocols |
| **`LayoutViews.swift`** | SwiftUI (no UIKit for scale) |

### Domain protocols

**`ArtworkProvider`** (Core):

```swift
protocol ArtworkProvider: Sendable {
    func artworkURL(for id: AlbumID, width: Int, height: Int) async -> URL?
}
```

**`URLSessionDataProviding`** (Core):

```swift
protocol URLSessionDataProviding: Sendable {
    func data(from url: URL) async throws -> (Data, URLResponse)
}
```

Extend **`URLSession`** to conform in the app target (or Adapters) with a one-line forwarding implementation.

**`AlbumRepository`** — remove **`artworkURL(for:width:height:)`** from protocol, **`MusicKitAlbumRepository`**, mocks, preview types, and unimplemented environment stub.

### Adapters

**`MusicKitArtworkProvider`**:

- Holds **`MusicKitAlbumRepository`** (uses existing **`musicKitAlbum(for:)`**).
- **`artworkURL`**: fetch MusicKit album → return **`album.artwork?.url(width:height:)`**.
- Logic moved from **`MusicKitAlbumRepository.artworkURL`**; delete that method from the repository.

### `ImageCache` (refactored)

```swift
struct ImageCache {
    init(
        artworkProvider: any ArtworkProvider,
        session: any URLSessionDataProviding = URLSession.shared,
        fileManager: FileManager = .default,
        cacheDirectory: URL? = nil
    )
}
```

When **`cacheDirectory`** is `nil`, resolve via **`fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!`** (production). Tests inject a temp directory URL so cache paths are isolated without mocking **`FileManager.urls(for:in:)`**.

**`getArtwork(albumID:size:)`** behavior unchanged:

1. Build cache path **`{cacheDirectory}/{albumID}_{size}.jpg`**.
2. **Cache hit** — file exists → return local URL.
3. **Cache miss** — call **`artworkProvider.artworkURL(for:width:height:)`** → `nil` if no artwork.
4. Download via injected **`session`**, write to cache path → return local URL.
5. Download/write failure — log with **`print`** (preserve current behavior) → return remote URL.

### `AlbumTapCoordinator` (rename only)

```swift
enum AlbumTapCoordinator {
    static func handleTap(
        albumID: AlbumID,
        rawSelectedID: String?,
        setSelected: @MainActor (String?) -> Void,
        playback: any PlaybackController
    ) async { … }
}
```

Same state machine as **`AlbumTapPlayback`**: deselect → **`pause()`** + clear selection; new tap → set selection + **`play(albumId:)`** (errors swallowed via **`try?`**).

### Injection (hybrid)

| Consumer | Mechanism |
|----------|-----------|
| **`AppDependencies.live`** | **`MusicKitArtworkProvider(repository: musicKitRepo)`** |
| **`AppDependencies.preview()`** | **`PreviewArtworkProvider()`** (returns `nil` or fixture URLs) |
| **`HomePageView`** | **`.environment(\.artworkProvider, dependencies.artworkProvider)`** |
| **`AlbumArtwork`** | **`@Environment(\.artworkProvider)`**; constructs **`ImageCache`** in **`.task`** |
| **`GridLayout` / `ListLayout`** | **`AlbumTapCoordinator.handleTap`** + **`@Environment(\.playback)`** (unchanged) |

**`albumRepository`** environment remains for search, load, and playback adapter wiring; grid/list artwork no longer reads it.

### `AlbumArtwork` changes

```swift
@Environment(\.artworkProvider) private var artworkProvider
@Environment(\.displayScale) private var displayScale

.task {
    let pixelSize = Int((viewSize * displayScale).rounded())
    imageURL = await ImageCache(artworkProvider: artworkProvider)
        .getArtwork(albumID: album.id.rawValue, size: pixelSize)
}
```

Remove **`import UIKit`** from **`LayoutViews.swift`** if unused elsewhere in the file.

## Data flow

### Tap-to-play

```
GridLayout / ListLayout
  └─ onTapGesture
       └─ AlbumTapCoordinator.handleTap(albumID, rawSelectedID, setSelected, playback)
            ├─ same album selected → playback.pause() → clear selection
            └─ different/none     → set selection → playback.play(albumId:)
```

Selection state stays in **`@State selectedAlbumID: String?`** on each layout.

### Artwork loading

```
AlbumArtwork (.task)
  ├─ pixelSize = viewSize × displayScale (rounded)
  └─ ImageCache(artworkProvider:).getArtwork(albumID, size:)
       ├─ cache hit  → local file URL
       ├─ cache miss → ArtworkProvider.artworkURL
       │                 └─ MusicKitArtworkProvider → MusicKit artwork URL
       ├─ download OK → write cache file → local URL
       └─ download fail → remote URL (AsyncImage loads from CDN)
```

### Composition root

```
AppDependencies.live
  ├─ albumRepository = MusicKitAlbumRepository()
  ├─ artworkProvider = MusicKitArtworkProvider(repository: albumRepository)
  └─ playbackController = SystemMusicPlayerAdapter(repository: albumRepository)

HomePageView
  ├─ .environment(\.albumRepository, …)
  ├─ .environment(\.playback, …)
  └─ .environment(\.artworkProvider, …)
```

## Error handling

| Path | Behavior | Rationale |
|------|----------|-----------|
| **`ArtworkProvider`** returns `nil` | **`getArtwork`** returns `nil`; placeholder shown | Same as today when no artwork |
| Download / write fails | **`print`** + return remote URL | Existing fallback for **`AsyncImage`** |
| **`playback.play`** fails | Swallowed via **`try?`** | Unchanged from PR 5 |
| Missing env key | **`preconditionFailure`** on unimplemented stub | Matches other service keys |

No new user-facing error surfaces in this PR.

## Testing

### `AlbumTapCoordinatorTests` (rename existing suite)

| Test | Asserts |
|------|---------|
| **`deselectPausesAndClearsSelection`** | **`pause`** once, no **`play`**, selection cleared |
| **`newSelectionPlaysAlbum`** | **`play`** with correct **`AlbumID`**, selection set |

### `ImageCacheTests` (new — mocks only)

Use **`MockArtworkProvider`**, a **`URLSessionDataProviding`** test double, injected **`FileManager`**, and an injected **`cacheDirectory`** pointing at a temp folder (create in test setup, delete in teardown):

| Test | Setup | Asserts |
|------|-------|---------|
| **Cache hit** | Pre-seed **`{albumID}_{size}.jpg`** in temp cache dir | Returns local URL; provider and session not called |
| **Cache miss + download** | Empty cache; provider returns remote URL; session returns bytes | File written; returns local URL |
| **Download fail → remote URL** | Empty cache; provider returns remote URL; session throws | Returns remote URL (not local) |

### Test support

- **Add** **`MockArtworkProvider`** with optional handler **`(AlbumID, Int, Int) async -> URL?`**
- **Add** **`MockURLSession`** (or handler-based double) implementing **`URLSessionDataProviding`**
- **Remove** **`artworkURLHandler`** / **`artworkURL(for:…)`** from **`MockAlbumRepository`**, **`PreviewAlbumRepository`**, and unimplemented environment stub
- **Add** **`PreviewArtworkProvider`** for previews

### Out of scope for unit tests

- Live MusicKit artwork resolution (human QA on device/simulator)
- **`AsyncImage`** rendering (PR 12)

## Acceptance criteria

- [ ] **`AlbumTapPlayback`** renamed to **`AlbumTapCoordinator`**; call sites and tests updated
- [ ] **`ArtworkProvider`** protocol in Core; **`MusicKitArtworkProvider`** in Adapters
- [ ] **`ImageCache`** injects **`ArtworkProvider`**, **`URLSessionDataProviding`**, **`FileManager`**
- [ ] **`artworkURL`** removed from **`AlbumRepository`** and all mocks/adapters
- [ ] **`@Environment(\.artworkProvider)`** wired from **`AppDependencies`** via **`HomePageView`**
- [ ] **`UIScreen.main.scale`** replaced with **`@Environment(\.displayScale)`** in **`AlbumArtwork`**
- [ ] Unit tests: tap state machine, cache hit, cache miss + download, download fail → remote URL
- [ ] **`ci-tests`** green

## Human verification (PR description)

- Grid and list artwork loads on device/simulator.
- Tap album to play; tap again to pause (unchanged).
- Previews render without crash (mock artwork provider).

## PR delivery

- Branch: `cursor/test-refactor-pr-11-tap-coordinator-artwork` (or team convention).
- Add new files to Xcode targets (filesystem-synced group if applicable).
- PR title: `test refactor PR 11: AlbumTapCoordinator + ArtworkProvider`
- Link PR 11 of 14; note MusicKit artwork requires device/simulator QA.

## Follow-on PRs

| PR | Relationship |
|----|----------------|
| PR 12 | ViewInspector; may assert artwork placeholder/loaded states |
| PR 15 | Physical SPM split; **`ArtworkProvider`** moves to Core package |

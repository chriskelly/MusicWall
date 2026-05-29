# PR 8 — Auth ViewModel + authorization protocol

**Status:** Approved (2026-05-29)  
**Program:** MusicWall testability refactor  
**Requires:** PR 6 merged  
**Blocks:** PR 13 (UI tests + launch mocks)  
**Approach:** Core protocol + Adapters live type (Option 1) + launch Option C (read status first)

## Summary

Extract authorization from `ContentView` into an `@MainActor` `@Observable` **`AuthViewModel`** backed by **`MusicAuthorizationProviding`**. On launch, read `authorizationStatus` first; call `requestAuthorization()` only when status is `.notDetermined` or when the user taps “Try Again”. `ContentView` binds to VM state only and drops `import MusicKit`. `AppDependencies` injects live vs mock provider; previews show home immediately via mock authorized state.

## Goals

- 100% unit-testable auth state machine (all `MusicAuthorizationStatus` branches including `.unknown`).
- `MusicAuthorizationProviding` protocol at Core boundary; `LiveMusicAuthorizationProvider` in Adapters.
- `ContentView` moved to `Features/Auth/`; no inline `MusicAuthorization.request()` calls.
- `AppDependencies.live` / `.preview()` inject live vs mock provider.
- Preview shows home without real MusicKit authorization.
- Preserve existing denied-screen copy and layout.

## Non-goals

- `HomeViewModel` (PR 9) — `AlbumStore` still created in `ContentView` when authorized.
- UI tests / launch arguments (PR 13).
- Settings deep-link to iOS privacy pane.
- Changing “Try Again” behavior beyond moving it to `AuthViewModel.retry()`.
- Refactoring `HomePageView` or `AlbumStore`.

## Approaches considered

### Launch behavior

| Option | Description | Why not chosen |
|--------|-------------|----------------|
| **C (chosen)** | Read `authorizationStatus` first; request only when `.notDetermined` or on retry | Best UX; matches MusicKit semantics; no loading flash for returning or denied users |
| A | Skip loading only when already `.authorized`; always call `request()` otherwise | Still calls `request()` for denied/restricted users unnecessarily |
| B | Always call `request()` on launch (current behavior) | Loading spinner on every launch; worse UX for denied/restricted |

### Protocol placement

| Option | Description | Why not chosen |
|--------|-------------|----------------|
| **1 (chosen)** | Core protocol + Adapters live type | Matches `AlbumRepository`, `PlaybackController`, `AlbumBackupService` pattern |
| 2 | Protocol under `Features/Auth/` | Breaks “protocols in Core” program rule; PR 13 mocks import Features |
| 3 | Closure injection, no protocol | Inconsistent with refactor; harder to swap in `AppDependencies` |

### ViewModel ownership

| Option | Description | Why not chosen |
|--------|-------------|----------------|
| **ContentView-owned (chosen)** | `@State private var viewModel = AuthViewModel(authorization: dependencies.musicAuthorization)` | Previews/tests swap via `AppDependencies`; no change to `MusicWallApp` |
| App-owned | `MusicWallApp` creates VM and passes down | Extra wiring for no benefit in PR 8 |

## Architecture

### Layer placement

```
MusicWall/
  Core/
    MusicAuthorizationStatus.swift
    MusicAuthorizationProviding.swift
  Adapters/
    LiveMusicAuthorizationProvider.swift
  Features/Auth/
    AuthViewModel.swift
    ContentView.swift              # moved from MusicWall/
  PreviewSupport/
    PreviewMusicAuthorizationProvider.swift
  AppDependencies.swift
  MusicWallApp.swift               # unchanged

MusicWallTests/
  Features/Auth/
    AuthViewModelTests.swift
  TestSupport/
    MockMusicAuthorizationProvider.swift
```

Delete `MusicWall/ContentView.swift` after move (same file, new path — update target membership if needed; filesystem-synced group picks up automatically).

### Data flow

```
Launch:
  ContentView.task
    → AuthViewModel.checkAuthorization()
      → read authorization.authorizationStatus
      → branch (Option C):
          .authorized     → state .authorized → HomePageView
          .notDetermined   → state .loading → requestAuthorization() → map result
          .denied/.restricted/.unknown → state .denied

Try Again:
  Button → AuthViewModel.retry()
    → state .loading
    → requestAuthorization()
    → map result → .authorized | .denied
```

### Dependency rules

| Unit | May import |
|------|------------|
| `MusicAuthorizationStatus`, `MusicAuthorizationProviding` | Foundation |
| `LiveMusicAuthorizationProvider` | Foundation, MusicKit |
| `AuthViewModel` | Foundation, Observation |
| `ContentView` | SwiftUI |
| `PreviewMusicAuthorizationProvider` | Foundation |
| Tests | `@testable import MusicWall` |

## Domain types

### `MusicAuthorizationStatus`

App-owned enum mirroring MusicKit authorization cases. Used in tests and ViewModel without importing MusicKit.

```swift
enum MusicAuthorizationStatus: Sendable, Equatable {
    case notDetermined
    case authorized
    case denied
    case restricted
    case unknown   // MusicKit @unknown default; VM maps to .denied
}
```

### `MusicAuthorizationProviding`

```swift
protocol MusicAuthorizationProviding: Sendable {
    var authorizationStatus: MusicAuthorizationStatus { get }
    func requestAuthorization() async -> MusicAuthorizationStatus
}
```

### `LiveMusicAuthorizationProvider`

```swift
struct LiveMusicAuthorizationProvider: MusicAuthorizationProviding {
    var authorizationStatus: MusicAuthorizationStatus {
        map(MusicAuthorization.currentStatus)
    }

    func requestAuthorization() async -> MusicAuthorizationStatus {
        map(await MusicAuthorization.request())
    }

    private func map(_ status: MusicAuthorization.Status) -> MusicAuthorizationStatus { … }
}
```

Mapping:

| `MusicAuthorization.Status` | `MusicAuthorizationStatus` |
|-----------------------------|----------------------------|
| `.notDetermined` | `.notDetermined` |
| `.authorized` | `.authorized` |
| `.denied` | `.denied` |
| `.restricted` | `.restricted` |
| `@unknown default` | `.unknown` |

## AuthViewModel

```swift
enum AuthState: Equatable {
    case loading
    case authorized
    case denied
}

@MainActor
@Observable
final class AuthViewModel {
    private(set) var state: AuthState = .loading
    private let authorization: any MusicAuthorizationProviding

    init(authorization: any MusicAuthorizationProviding)

    func checkAuthorization() async
    func retry() async
}
```

### State machine — initial check (`checkAuthorization`)

| `authorizationStatus` | `state` after check | Calls `requestAuthorization()`? |
|-----------------------|---------------------|----------------------------------|
| `.authorized` | `.authorized` | No |
| `.notDetermined` | `.loading` then post-request | Yes |
| `.denied` | `.denied` | No |
| `.restricted` | `.denied` | No |
| `.unknown` | `.denied` | No |

### State machine — after `requestAuthorization()` (initial `.notDetermined` path and `retry()`)

| Result status | `state` |
|---------------|---------|
| `.authorized` | `.authorized` |
| `.notDetermined` | `.denied` |
| `.denied` | `.denied` |
| `.restricted` | `.denied` |
| `.unknown` | `.denied` |

`retry()` sets `state = .loading` before calling `requestAuthorization()`.

Implementation uses a private `applyAfterRequest(_ status: MusicAuthorizationStatus)` helper shared by both paths so post-request mapping stays DRY.

**Note:** Post-request `.notDetermined` maps to `.denied` (user dismissed prompt without granting). This preserves current `ContentView` behavior where `.notDetermined` after request is treated as denied.

## ContentView

Move to `MusicWall/Features/Auth/ContentView.swift`.

Changes:

- Remove `import MusicKit`.
- Add `@State private var viewModel: AuthViewModel` initialized from `dependencies.musicAuthorization`.
- Switch on `viewModel.state`:
  - `.authorized` → `HomePageView` with `AlbumStore(preferences:repository:)` (unchanged wiring).
  - `.denied` → existing denied UI; “Try Again” calls `Task { await viewModel.retry() }`.
  - `.loading` → `ProgressView("Requesting Music Access…")`.
- `.task { await viewModel.checkAuthorization() }`.

Preview:

```swift
#Preview {
    ContentView(dependencies: .preview())
}
```

## Composition root and injection

### `AppDependencies`

```swift
struct AppDependencies {
    let preferencesStore: PreferencesStore
    let albumRepository: any AlbumRepository
    let playbackController: any PlaybackController
    let albumBackupService: any AlbumBackupService
    let musicAuthorization: any MusicAuthorizationProviding

    static let live: AppDependencies = {
        let repository = MusicKitAlbumRepository()
        return AppDependencies(
            preferencesStore: UserDefaultsPreferencesStore(userDefaults: .standard),
            albumRepository: repository,
            playbackController: SystemMusicPlayerAdapter(repository: repository),
            albumBackupService: LiveAlbumBackupService(),
            musicAuthorization: LiveMusicAuthorizationProvider()
        )
    }()

    static func preview() -> AppDependencies {
        let suiteName = "com.musicwall.preview.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        return AppDependencies(
            preferencesStore: UserDefaultsPreferencesStore(userDefaults: defaults),
            albumRepository: PreviewAlbumRepository(),
            playbackController: PreviewPlaybackController(),
            albumBackupService: LiveAlbumBackupService(),
            musicAuthorization: PreviewMusicAuthorizationProvider(status: .authorized)
        )
    }
}
```

### `MusicWallApp`

No changes — still `ContentView(dependencies: dependencies)`.

## Mocks

### `PreviewMusicAuthorizationProvider` (`PreviewSupport/`)

```swift
struct PreviewMusicAuthorizationProvider: MusicAuthorizationProviding {
    var authorizationStatus: MusicAuthorizationStatus
    var requestResult: MusicAuthorizationStatus?

    func requestAuthorization() async -> MusicAuthorizationStatus {
        requestResult ?? authorizationStatus
    }
}
```

Default for `.preview()`: `status: .authorized`.

### `MockMusicAuthorizationProvider` (`MusicWallTests/TestSupport/`)

Handler-based mock matching `MockAlbumRepository` style:

- Configurable `authorizationStatus`.
- Optional `requestHandler: () async -> MusicAuthorizationStatus`.
- `private(set) var requestCallCount` for assertions.

## Testing

### Framework

Swift Testing (consistent with PR 1–7).

### `AuthViewModelTests`

All tests use `MockMusicAuthorizationProvider`. Run on `@MainActor`.

| Test | Setup | Assert |
|------|-------|--------|
| `initialAuthorized_skipsRequest` | status `.authorized` | `state == .authorized`; `requestCallCount == 0` |
| `initialNotDetermined_requestAuthorized` | status `.notDetermined`, request → `.authorized` | ends `.authorized`; request called once |
| `initialNotDetermined_requestDenied` | status `.notDetermined`, request → `.denied` | ends `.denied` |
| `initialNotDetermined_requestNotDetermined` | request → `.notDetermined` | ends `.denied` |
| `initialNotDetermined_requestRestricted` | request → `.restricted` | ends `.denied` |
| `initialNotDetermined_requestUnknown` | request → `.unknown` | ends `.denied` |
| `initialDenied_skipsRequest` | status `.denied` | `state == .denied`; no request |
| `initialRestricted_skipsRequest` | status `.restricted` | `state == .denied`; no request |
| `initialUnknown_skipsRequest` | status `.unknown` | `state == .denied`; no request |
| `retry_fromDenied_toAuthorized` | start `.denied`, request → `.authorized` | ends `.authorized`; request called |
| `retry_fromDenied_staysDenied` | start `.denied`, request → each non-authorized status | ends `.denied` |

Target: 100% line and branch coverage on `AuthViewModel`.

### Smoke

- `AppDependencies.live` and `.preview()` construct successfully.
- `#Preview` compiles with mock authorized provider.

### Human verification (PR description)

| Scenario | Expected |
|----------|----------|
| First launch, grant access | System prompt → home |
| First launch, deny | Denied screen |
| Re-launch when authorized | Home immediately, no loading flash |
| Denied → Try Again → grant | Home |
| Parental-restricted device | Denied screen without loading spinner |

Real `MusicAuthorization` on device remains human-verified (not unit-tested).

### CI

No workflow changes. PR must pass existing `ci-tests` (`fastlane ci_tests`).

## Acceptance criteria

- [ ] `MusicAuthorizationStatus` and `MusicAuthorizationProviding` in `MusicWall/Core/`; Foundation only.
- [ ] `LiveMusicAuthorizationProvider` in `MusicWall/Adapters/`; maps all MusicKit status cases including `@unknown default`.
- [ ] `AuthViewModel` in `MusicWall/Features/Auth/` with `.loading`, `.authorized`, `.denied` states.
- [ ] `ContentView` in `Features/Auth/`; no `MusicKit` import; binds to `AuthViewModel` only.
- [ ] `AppDependencies` exposes `musicAuthorization`; live and preview inject appropriate providers.
- [ ] Preview uses mock authorized state (shows home).
- [ ] `AuthViewModelTests` cover 100% of state transitions (all status branches).
- [ ] `MockMusicAuthorizationProvider` in test support.
- [ ] App compiles; `ci-tests` green.

## PR delivery

- Branch from `main`: `cursor/test-refactor-pr-08-auth-vm` (or team convention).
- Add new Swift files under `MusicWall/` and `MusicWallTests/` (filesystem-synced Xcode group).
- Move `ContentView.swift` to `Features/Auth/`.
- PR description: link “PR 8 of 14”; note human auth verification on device/simulator.

## Follow-on PRs

| PR | Relationship |
|----|----------------|
| PR 9 | `HomeViewModel` owns home orchestration; auth gate unchanged |
| PR 13 | UI tests use launch mock for `MusicAuthorizationProviding` via `AppDependencies` |
| PR 14 | ViewModel coverage gates; confirm `AuthViewModel` ≥90% in CI report |

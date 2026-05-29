# PR 8 — Auth ViewModel + authorization protocol Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extract authorization from `ContentView` into a testable `AuthViewModel` backed by `MusicAuthorizationProviding`, with Option C launch behavior (read status first; request only when `.notDetermined` or on retry).

**Architecture:** Foundation-only Core types (`MusicAuthorizationStatus`, `MusicAuthorizationProviding`) plus `LiveMusicAuthorizationProvider` in Adapters (MusicKit). `@Observable` `AuthViewModel` in `Features/Auth/` owns the state machine. `ContentView` binds to VM state only; `AppDependencies` injects live vs preview mock.

**Tech Stack:** Swift 5, Swift Testing, Observation, Xcode 16+, scheme `MusicWall`, simulator `iPhone 17`, `bundle exec fastlane ci_tests`.

**Spec:** `docs/specs/2026-05-29-pr-08-auth-viewmodel-design.md`

**Branch:** `cursor/test-refactor-pr-08-auth-vm`

---

## File map

| Action | Path | Notes |
|--------|------|-------|
| Create | `MusicWall/Core/MusicAuthorizationStatus.swift` | App-owned auth enum |
| Create | `MusicWall/Core/MusicAuthorizationProviding.swift` | Protocol |
| Create | `MusicWall/Adapters/LiveMusicAuthorizationProvider.swift` | MusicKit adapter |
| Create | `MusicWall/PreviewSupport/PreviewMusicAuthorizationProvider.swift` | Preview mock |
| Create | `MusicWall/Features/Auth/AuthViewModel.swift` | State machine |
| Move | `MusicWall/ContentView.swift` → `MusicWall/Features/Auth/ContentView.swift` | Thin view |
| Modify | `MusicWall/AppDependencies.swift` | Add `musicAuthorization` |
| Modify | `MusicWallTests/SmokeTests.swift` | Touch `musicAuthorization` |
| Create | `MusicWallTests/TestSupport/MockMusicAuthorizationProvider.swift` | Test mock |
| Create | `MusicWallTests/Features/Auth/AuthViewModelTests.swift` | Full transition matrix |
| Modify | `MusicWall.xcodeproj/project.pbxproj` | Register test files |
| Modify | `Agent.md` | Auth / ContentView note |

**Xcode note:** `MusicWall/` uses `PBXFileSystemSynchronizedRootGroup` — new app files auto-join the target. Test files under `MusicWallTests/` must be registered in `project.pbxproj` (mirror `AlbumStoreImportTests.swift`).

---

### Task 1: Core authorization types

**Files:**
- Create: `MusicWall/Core/MusicAuthorizationStatus.swift`
- Create: `MusicWall/Core/MusicAuthorizationProviding.swift`

- [ ] **Step 1: Create `MusicAuthorizationStatus.swift`**

```swift
import Foundation

enum MusicAuthorizationStatus: Sendable, Equatable {
    case notDetermined
    case authorized
    case denied
    case restricted
    case unknown
}
```

- [ ] **Step 2: Create `MusicAuthorizationProviding.swift`**

```swift
import Foundation

protocol MusicAuthorizationProviding: Sendable {
    var authorizationStatus: MusicAuthorizationStatus { get }
    func requestAuthorization() async -> MusicAuthorizationStatus
}
```

- [ ] **Step 3: Build app target**

Run:

```bash
xcodebuild build -project MusicWall.xcodeproj -scheme MusicWall \
  -destination 'platform=iOS Simulator,name=iPhone 17' -quiet
```

Expected: `BUILD SUCCEEDED`

- [ ] **Step 4: Commit**

```bash
git add MusicWall/Core/MusicAuthorizationStatus.swift \
  MusicWall/Core/MusicAuthorizationProviding.swift
git commit -m "feat(core): Add MusicAuthorizationProviding protocol"
```

---

### Task 2: Live adapter + preview mock

**Files:**
- Create: `MusicWall/Adapters/LiveMusicAuthorizationProvider.swift`
- Create: `MusicWall/PreviewSupport/PreviewMusicAuthorizationProvider.swift`

- [ ] **Step 1: Create `LiveMusicAuthorizationProvider.swift`**

```swift
import Foundation
import MusicKit

struct LiveMusicAuthorizationProvider: MusicAuthorizationProviding {
    var authorizationStatus: MusicAuthorizationStatus {
        map(MusicAuthorization.currentStatus)
    }

    func requestAuthorization() async -> MusicAuthorizationStatus {
        map(await MusicAuthorization.request())
    }

    private func map(_ status: MusicAuthorization.Status) -> MusicAuthorizationStatus {
        switch status {
        case .notDetermined:
            return .notDetermined
        case .authorized:
            return .authorized
        case .denied:
            return .denied
        case .restricted:
            return .restricted
        @unknown default:
            return .unknown
        }
    }
}
```

- [ ] **Step 2: Create `PreviewMusicAuthorizationProvider.swift`**

```swift
import Foundation

struct PreviewMusicAuthorizationProvider: MusicAuthorizationProviding {
    var authorizationStatus: MusicAuthorizationStatus
    var requestResult: MusicAuthorizationStatus?

    init(status: MusicAuthorizationStatus, requestResult: MusicAuthorizationStatus? = nil) {
        self.authorizationStatus = status
        self.requestResult = requestResult
    }

    func requestAuthorization() async -> MusicAuthorizationStatus {
        requestResult ?? authorizationStatus
    }
}
```

- [ ] **Step 3: Build app target**

Run:

```bash
xcodebuild build -project MusicWall.xcodeproj -scheme MusicWall \
  -destination 'platform=iOS Simulator,name=iPhone 17' -quiet
```

Expected: `BUILD SUCCEEDED`

- [ ] **Step 4: Commit**

```bash
git add MusicWall/Adapters/LiveMusicAuthorizationProvider.swift \
  MusicWall/PreviewSupport/PreviewMusicAuthorizationProvider.swift
git commit -m "feat(adapters): Add live and preview music authorization providers"
```

---

### Task 3: Test mock + AuthViewModel (TDD)

**Files:**
- Create: `MusicWallTests/TestSupport/MockMusicAuthorizationProvider.swift`
- Create: `MusicWallTests/Features/Auth/AuthViewModelTests.swift`
- Create: `MusicWall/Features/Auth/AuthViewModel.swift`
- Modify: `MusicWall.xcodeproj/project.pbxproj`

- [ ] **Step 1: Register test files in Xcode project**

Add to `MusicWallTests` target (Sources build phase + groups):

- `MusicWallTests/TestSupport/MockMusicAuthorizationProvider.swift`
- `MusicWallTests/Features/Auth/AuthViewModelTests.swift`

Mirror `AlbumStoreImportTests.swift` registration. Create `Features` → `Auth` group if needed.

- [ ] **Step 2: Create `MockMusicAuthorizationProvider.swift`**

```swift
import Foundation
@testable import MusicWall

final class MockMusicAuthorizationProvider: MusicAuthorizationProviding, @unchecked Sendable {
    var authorizationStatus: MusicAuthorizationStatus
    var requestHandler: (() async -> MusicAuthorizationStatus)?
    private(set) var requestCallCount = 0

    init(authorizationStatus: MusicAuthorizationStatus = .notDetermined) {
        self.authorizationStatus = authorizationStatus
    }

    func requestAuthorization() async -> MusicAuthorizationStatus {
        requestCallCount += 1
        if let requestHandler {
            return await requestHandler()
        }
        return authorizationStatus
    }
}
```

- [ ] **Step 3: Write failing `AuthViewModelTests.swift`**

```swift
import Testing
@testable import MusicWall

struct AuthViewModelTests {
    @Test @MainActor
    func initialAuthorized_skipsRequest() async {
        let provider = MockMusicAuthorizationProvider(authorizationStatus: .authorized)
        let viewModel = AuthViewModel(authorization: provider)

        await viewModel.checkAuthorization()

        #expect(viewModel.state == .authorized)
        #expect(provider.requestCallCount == 0)
    }

    @Test @MainActor
    func initialNotDetermined_requestAuthorized() async {
        let provider = MockMusicAuthorizationProvider(authorizationStatus: .notDetermined)
        provider.requestHandler = { .authorized }
        let viewModel = AuthViewModel(authorization: provider)

        await viewModel.checkAuthorization()

        #expect(viewModel.state == .authorized)
        #expect(provider.requestCallCount == 1)
    }

    @Test @MainActor
    func initialNotDetermined_requestDenied() async {
        let provider = MockMusicAuthorizationProvider(authorizationStatus: .notDetermined)
        provider.requestHandler = { .denied }
        let viewModel = AuthViewModel(authorization: provider)

        await viewModel.checkAuthorization()

        #expect(viewModel.state == .denied)
        #expect(provider.requestCallCount == 1)
    }

    @Test @MainActor
    func initialNotDetermined_requestNotDetermined() async {
        let provider = MockMusicAuthorizationProvider(authorizationStatus: .notDetermined)
        provider.requestHandler = { .notDetermined }
        let viewModel = AuthViewModel(authorization: provider)

        await viewModel.checkAuthorization()

        #expect(viewModel.state == .denied)
    }

    @Test @MainActor
    func initialNotDetermined_requestRestricted() async {
        let provider = MockMusicAuthorizationProvider(authorizationStatus: .notDetermined)
        provider.requestHandler = { .restricted }
        let viewModel = AuthViewModel(authorization: provider)

        await viewModel.checkAuthorization()

        #expect(viewModel.state == .denied)
    }

    @Test @MainActor
    func initialNotDetermined_requestUnknown() async {
        let provider = MockMusicAuthorizationProvider(authorizationStatus: .notDetermined)
        provider.requestHandler = { .unknown }
        let viewModel = AuthViewModel(authorization: provider)

        await viewModel.checkAuthorization()

        #expect(viewModel.state == .denied)
    }

    @Test @MainActor
    func initialDenied_skipsRequest() async {
        let provider = MockMusicAuthorizationProvider(authorizationStatus: .denied)
        let viewModel = AuthViewModel(authorization: provider)

        await viewModel.checkAuthorization()

        #expect(viewModel.state == .denied)
        #expect(provider.requestCallCount == 0)
    }

    @Test @MainActor
    func initialRestricted_skipsRequest() async {
        let provider = MockMusicAuthorizationProvider(authorizationStatus: .restricted)
        let viewModel = AuthViewModel(authorization: provider)

        await viewModel.checkAuthorization()

        #expect(viewModel.state == .denied)
        #expect(provider.requestCallCount == 0)
    }

    @Test @MainActor
    func initialUnknown_skipsRequest() async {
        let provider = MockMusicAuthorizationProvider(authorizationStatus: .unknown)
        let viewModel = AuthViewModel(authorization: provider)

        await viewModel.checkAuthorization()

        #expect(viewModel.state == .denied)
        #expect(provider.requestCallCount == 0)
    }

    @Test @MainActor
    func retry_fromDenied_toAuthorized() async {
        let provider = MockMusicAuthorizationProvider(authorizationStatus: .denied)
        provider.requestHandler = { .authorized }
        let viewModel = AuthViewModel(authorization: provider)
        await viewModel.checkAuthorization()
        #expect(viewModel.state == .denied)

        await viewModel.retry()

        #expect(viewModel.state == .authorized)
        #expect(provider.requestCallCount == 1)
    }

    @Test @MainActor
    func retry_fromDenied_staysDenied() async {
        for status in [MusicAuthorizationStatus.notDetermined, .denied, .restricted, .unknown] {
            let provider = MockMusicAuthorizationProvider(authorizationStatus: .denied)
            provider.requestHandler = { status }
            let viewModel = AuthViewModel(authorization: provider)
            await viewModel.checkAuthorization()

            await viewModel.retry()

            #expect(viewModel.state == .denied)
        }
    }
}
```

- [ ] **Step 4: Run tests to verify they fail**

Run:

```bash
xcodebuild test -project MusicWall.xcodeproj -scheme MusicWall \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:MusicWallTests/AuthViewModelTests -quiet
```

Expected: FAIL — `AuthViewModel` not found

- [ ] **Step 5: Create `AuthViewModel.swift`**

```swift
import Foundation
import Observation

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

    init(authorization: any MusicAuthorizationProviding) {
        self.authorization = authorization
    }

    func checkAuthorization() async {
        switch authorization.authorizationStatus {
        case .authorized:
            state = .authorized
        case .notDetermined:
            state = .loading
            let status = await authorization.requestAuthorization()
            applyAfterRequest(status)
        case .denied, .restricted, .unknown:
            state = .denied
        }
    }

    func retry() async {
        state = .loading
        let status = await authorization.requestAuthorization()
        applyAfterRequest(status)
    }

    private func applyAfterRequest(_ status: MusicAuthorizationStatus) {
        switch status {
        case .authorized:
            state = .authorized
        case .notDetermined, .denied, .restricted, .unknown:
            state = .denied
        }
    }
}
```

- [ ] **Step 6: Run tests to verify they pass**

Run:

```bash
xcodebuild test -project MusicWall.xcodeproj -scheme MusicWall \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:MusicWallTests/AuthViewModelTests -quiet
```

Expected: all `AuthViewModelTests` PASS

- [ ] **Step 7: Commit**

```bash
git add MusicWall/Features/Auth/AuthViewModel.swift \
  MusicWallTests/TestSupport/MockMusicAuthorizationProvider.swift \
  MusicWallTests/Features/Auth/AuthViewModelTests.swift \
  MusicWall.xcodeproj/project.pbxproj
git commit -m "feat(auth): Add AuthViewModel with full state machine tests"
```

---

### Task 4: AppDependencies injection

**Files:**
- Modify: `MusicWall/AppDependencies.swift`

- [ ] **Step 1: Add `musicAuthorization` to `AppDependencies`**

Replace file contents with:

```swift
import Foundation

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

- [ ] **Step 2: Build**

Run:

```bash
xcodebuild build -project MusicWall.xcodeproj -scheme MusicWall \
  -destination 'platform=iOS Simulator,name=iPhone 17' -quiet
```

Expected: `BUILD SUCCEEDED`

- [ ] **Step 3: Commit**

```bash
git add MusicWall/AppDependencies.swift
git commit -m "feat(app): Inject musicAuthorization through AppDependencies"
```

---

### Task 5: Refactor ContentView

**Files:**
- Move: `MusicWall/ContentView.swift` → `MusicWall/Features/Auth/ContentView.swift`
- Delete: old `MusicWall/ContentView.swift` (after move)

- [ ] **Step 1: Move and replace `ContentView.swift`**

Create `MusicWall/Features/Auth/ContentView.swift`:

```swift
//
//  ContentView.swift
//  MusicWall
//
//  Created by Chris Kelly on 8/27/25.
//

import SwiftUI

struct ContentView: View {
    let dependencies: AppDependencies
    @State private var viewModel: AuthViewModel

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        _viewModel = State(
            initialValue: AuthViewModel(authorization: dependencies.musicAuthorization)
        )
    }

    var body: some View {
        Group {
            switch viewModel.state {
            case .authorized:
                let store = dependencies.preferencesStore
                HomePageView(
                    store: AlbumStore(
                        preferences: store,
                        repository: dependencies.albumRepository
                    ),
                    preferences: store,
                    dependencies: dependencies
                )
            case .denied:
                authorizationDeniedView()
            case .loading:
                ProgressView("Requesting Music Access…")
            }
        }
        .task {
            await viewModel.checkAuthorization()
        }
    }

    private func authorizationDeniedView() -> some View {
        VStack {
            Text("Apple Music access is required to use this app.")
                .multilineTextAlignment(.center)
                .padding()
            Button("Try Again") {
                Task {
                    await viewModel.retry()
                }
            }
        }
    }
}

#Preview {
    ContentView(dependencies: .preview())
}
```

- [ ] **Step 2: Delete `MusicWall/ContentView.swift`**

Remove the old file at the app root (git tracks as rename if using `git mv`).

Preferred:

```bash
git mv MusicWall/ContentView.swift MusicWall/Features/Auth/ContentView.swift
```

Then apply the content replacement above.

- [ ] **Step 3: Verify no remaining `MusicKit` import in ContentView**

Run:

```bash
rg 'MusicAuthorization|import MusicKit' MusicWall/Features/Auth/ContentView.swift
```

Expected: no matches

- [ ] **Step 4: Build**

Run:

```bash
xcodebuild build -project MusicWall.xcodeproj -scheme MusicWall \
  -destination 'platform=iOS Simulator,name=iPhone 17' -quiet
```

Expected: `BUILD SUCCEEDED`

- [ ] **Step 5: Commit**

```bash
git add MusicWall/Features/Auth/ContentView.swift
git commit -m "refactor(auth): Bind ContentView to AuthViewModel"
```

---

### Task 6: Smoke tests and docs

**Files:**
- Modify: `MusicWallTests/SmokeTests.swift`
- Modify: `Agent.md`

- [ ] **Step 1: Update `SmokeTests.swift`**

```swift
import Testing
@testable import MusicWall

struct SmokeTests {
    @Test
    func appDependenciesLiveConstructs() {
        let dependencies = AppDependencies.live
        _ = dependencies.preferencesStore
        _ = dependencies.albumRepository
        _ = dependencies.playbackController
        _ = dependencies.albumBackupService
        _ = dependencies.musicAuthorization
        #expect(true)
    }

    @Test
    func appDependenciesPreviewConstructs() {
        let dependencies = AppDependencies.preview()
        _ = dependencies.musicAuthorization
        #expect(true)
    }
}
```

- [ ] **Step 2: Update `Agent.md`**

Replace:

```markdown
- Respect authorization flow in `ContentView` / entry points before calling catalog APIs.
```

With:

```markdown
- Authorization via `AuthViewModel` + `MusicAuthorizationProviding` (`AppDependencies.musicAuthorization`); `ContentView` in `Features/Auth/` binds to VM state only.
```

- [ ] **Step 3: Verify no inline MusicAuthorization in views**

Run:

```bash
rg 'MusicAuthorization\.request' --glob '*.swift'
```

Expected: match only in `LiveMusicAuthorizationProvider.swift`

- [ ] **Step 4: Commit**

```bash
git add MusicWallTests/SmokeTests.swift Agent.md
git commit -m "test: Extend smoke tests for musicAuthorization; update Agent.md"
```

---

### Task 7: Full CI verification

- [ ] **Step 1: Run full test suite**

Run:

```bash
bundle exec fastlane ci_tests
```

Expected: all tests green

- [ ] **Step 2: Human verification checklist (PR description)**

| Scenario | Expected |
|----------|----------|
| First launch, grant access | System prompt → home |
| First launch, deny | Denied screen |
| Re-launch when authorized | Home immediately, no loading flash |
| Denied → Try Again → grant | Home |
| Xcode preview | Home via mock authorized provider |

- [ ] **Step 3: Final commit if any fixups needed**

Only if Task 7 step 1 required changes.

---

## Spec coverage checklist

| Spec requirement | Task |
|------------------|------|
| `MusicAuthorizationStatus` in Core | Task 1 |
| `MusicAuthorizationProviding` in Core | Task 1 |
| `LiveMusicAuthorizationProvider` + `@unknown default` | Task 2 |
| `PreviewMusicAuthorizationProvider` | Task 2 |
| `AuthViewModel` state machine (Option C) | Task 3 |
| `MockMusicAuthorizationProvider` | Task 3 |
| All status branch tests | Task 3 |
| `AppDependencies.musicAuthorization` live + preview | Task 4 |
| `ContentView` moved, no MusicKit | Task 5 |
| Preview uses mock authorized | Task 5 |
| Smoke tests | Task 6 |
| `Agent.md` update | Task 6 |
| CI green | Task 7 |

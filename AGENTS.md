# Agent guide — MusicWall (iOS)

This repo is a **SwiftUI + MusicKit** iOS app. Agent work is mostly Swift under `MusicWall/`. Builds, signing, and distribution run on **GitHub Actions (`macos-26`, Xcode 26)** — not on Linux cloud agents. **CI is the source of truth** for whether it builds; never claim a build, TestFlight, or App Store result without workflow evidence.

## Guardrails

- Never commit secrets, `.p8`, `.p12`, passwords, `AuthKey_*` files, `xcuserdata/`, or `DerivedData/`. Reference secret **names** only.
- Never change `DEVELOPMENT_TEAM` or the bundle ID without an explicit human request.
- Prefer small, focused PRs. A docs-only or trivial change should carry the **`no-deploy`** label so the TestFlight upload is skipped.
- Never disable signing to make CI green. If CI fails, read the Actions log for the `fastlane` step, then fix the code or ask the human to fix the Apple portal or secrets.

## Project layout

```
MusicWall/                 # App source (SwiftUI, services, models); guide in MusicWall/AGENTS.md
MusicWallTests/            # Deterministic unit tests (UI smoke tests in MusicWallUITests/)
MusicWall.xcodeproj/       # Xcode project — scheme: MusicWall
fastlane/                  # match, build, upload lanes
.github/workflows/         # ci-tests, testflight-release, app-store-release
docs/                      # Agent reference plus the published support site
```

- **Bundle ID:** `chris.MusicWall`
- **MusicKit:** the App ID needs the capability, and real playback or authorization needs **device + TestFlight** — the simulator is not enough.

## Docs index

- CI pipeline, TestFlight, secrets, workflow failures → `docs/ci.md`
- Build numbers, versions, precheck, release flow → `docs/release.md`
- App source rules and architecture index → `MusicWall/AGENTS.md`
- Tests, coverage, UI tests, ViewInspector → `MusicWallTests/AGENTS.md`

## Architecture

- **SwiftUI** for UI; use `@Observable`, `@State`, and `@Environment` the way existing files do.
- **MVVM-style separation:** views in `*View.swift`; Apple Music through `AlbumRepository` / `PlaybackController` (`AppDependencies.live`); artwork through `ArtworkProvider` + `ImageCache`; tap-to-play through `AlbumTapCoordinator`; persistence through `PreferencesStore` / `AlbumBackupService`. Home orchestration lives in `MusicWall/Features/Home/`, search in `MusicWall/Features/Search/`, album edit in `MusicWall/Features/Edit/`. Search errors surface inline in the search sheet, not as a snackbar.
- Keep views thin; move testable logic into types that do not need `MusicPlayer`. Tests and coverage: `MusicWallTests/AGENTS.md`.

### Layers and folders

```
MusicWall App (SwiftUI, ViewModels, AppDependencies)
    │
    ├── Core/           Foundation only — domain types + protocols
    ├── Adapters/       I/O and MusicKit implementations
    └── Features/       *ViewModel.swift + views per feature area
```

| Folder | Put here | Examples |
|--------|----------|----------|
| `MusicWall/Core/` | App-owned types, pure logic, protocols | `AlbumRecord`, `AlbumSorter`, `BackupCodec`, `AlbumRepository`, `PreferencesStore`, `ArtworkProvider` |
| `MusicWall/Adapters/` | Side effects, platform APIs, MusicKit | **Persistence:** `UserDefaultsPreferencesStore`, `FileExportService`, `LiveAlbumBackupService`, `AlbumLibraryLoader`, `SecurityScopedResourceReader`. **MusicKit:** `MusicKitAlbumRepository`, `AlbumMapper`, `SystemMusicPlayerAdapter`, `MusicKitArtworkProvider`, `LiveMusicAuthorizationProvider` |
| `MusicWall/Features/<Area>/` | Screen state and UI for one flow | `HomeViewModel`, `HomePageView`, `SearchViewModel`, `AuthViewModel` |
| `MusicWall/` root | App shell, design system, composition | `MusicWallApp`, `AppDependencies`, `ImageCache`, `LayoutViews`, `SnackbarView` |

CI runs `Scripts/check_core_imports.sh`: `MusicWall/Core/` must not import MusicKit, SwiftUI, or UIKit.

### Design rules

| Rule | Rationale |
|------|-----------|
| Core has zero MusicKit / SwiftUI / UIKit imports | Fast, deterministic unit tests |
| Domain types are app-owned (`AlbumID`, `AlbumRecord`) | Tests do not construct `MusicKit.Album` |
| No playback on model types | Use `PlaybackController` + `AlbumTapCoordinator` |
| Views do not call repositories directly | ViewModels own async work; views bind only |
| Single composition root (`AppDependencies.live`) | Previews and tests swap fakes; leaf views may use `@Environment` for services |
| Side effects at adapter boundaries | Core logic stays testable without I/O |
| Map MusicKit errors to domain errors in adapters only | ViewModels surface user-visible errors |

### Where new code goes

| You are adding… | Location |
|-----------------|----------|
| Protocol or domain type | `MusicWall/Core/` |
| UserDefaults, files, security-scoped I/O | `MusicWall/Adapters/` (no MusicKit unless mapping Apple types) |
| MusicKit search, playback, authorization, artwork | `MusicWall/Adapters/` |
| CarPlay templates, scene delegate | `MusicWall/Adapters/CarPlay/` |
| Screen logic or async UI state | `MusicWall/Features/<Area>/*ViewModel.swift` |
| SwiftUI layout | `MusicWall/Features/<Area>/*View.swift` or shared design-system files |
| Test doubles | `MusicWallTests/TestSupport/` |

### MusicKit

- Use `AlbumRepository` for catalog/library search and fetch; do not duplicate MusicKit request types across views.
- Authorization goes through `AuthViewModel` + `MusicAuthorizationProviding` (`AppDependencies.musicAuthorization`); `ContentView` binds to VM state only.
- Do not log user tokens or private listening data.

### UI

- Reuse `LayoutViews`, `SnackbarView`, and `ImageCache` patterns.
- Support Dynamic Type and accessibility labels on interactive controls you touch.
- Never block the main actor on async MusicKit calls; use `async/await` as existing code does.

### Data & persistence

- Collections use **UserDefaults** and backup JSON; preserve backward compatibility when encoded shapes change.
- Export/import through `AlbumBackupService` (`LiveAlbumBackupService` + `BackupCodec`); test the round trip when changing the album model.

### Code quality

- Match existing naming and placement; no drive-by refactors.
- Prefer compiler-driven safety over force-unwraps.
- Add **unit tests** under `MusicWallTests/` for pure logic and composition-root smoke coverage — not every UI tweak.

**TDD rules** — follow these before any skill's checklist.

1. A red is valid only when the test runs and fails on its assertion. A compile error, missing symbol, or import error is **scaffolding**, not a red; add the minimum structure and run again. Do not record the structural run as the red step.
2. Test our logic — branches, calculations, state transitions, error mapping — not framework wiring, trivial getters, or defaults with no logic.
3. Fakes and mocks are normal at boundaries (MusicKit, files, UserDefaults, time); the repo's conventions decide the tool. Assert on the state or value produced, not on mock calls.
4. When a skill's checklist conflicts with these rules, follow these rules and say which clause was overridden. The TDD skill still supplies the workflow.

### Warnings policy

- **All targets** (`MusicWall/`, `MusicWallTests/`, `MusicWallUITests/`): zero compiler warnings. `SWIFT_TREAT_WARNINGS_AS_ERRORS` and `GCC_TREAT_WARNINGS_AS_ERRORS` are on; CI fails at compile time. `appintentsmetadataprocessor` "Metadata extraction skipped" lines are allowlisted in `Scripts/check_warnings.sh` (report-only).
- **Swift 6 language mode** (`SWIFT_VERSION = 6.0`) on all targets. The app target runs `SWIFT_STRICT_CONCURRENCY = complete`; test targets get complete checking through Swift 6 mode. UI tests are `@MainActor`.

## Git workflow

- Branch from `main` with descriptive names; do not push directly to `main` when branch protection is enabled.
- Releases are **tag-driven** (`vX.Y.Z`), not merge-driven.

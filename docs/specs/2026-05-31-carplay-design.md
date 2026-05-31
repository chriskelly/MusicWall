# CarPlay — simplified album grid

**Status:** Approved (2026-05-31)  
**Feature:** CarPlay Audio integration for MusicWall  
**Requires:** Existing `AlbumStore`, `PlaybackController`, `ArtworkProvider`, `AppDependencies.live`  
**Blocks:** App Store release until Apple grants CarPlay Audio entitlement  
**Approach:** Dedicated CarPlay adapter layer (`MusicWall/Adapters/CarPlay/`)

## Summary

Add a CarPlay Audio app that shows the user's saved album wall as a paginated artwork grid (`CPGridTemplate`). The CarPlay experience is read-only: no search, edit, import/export, or sort UI. Shuffle is session-only (same semantics as iPhone). Album tap starts or restarts playback; pause/skip use system Now Playing. Unauthorized or empty-library states show a single setup message via `CPInformationTemplate`.

## Goals

- CarPlay shows the same curated library as iPhone (UserDefaults-backed `AlbumStore`), in the user's saved sort order.
- Grid-only browsing with shuffle; all library management stays on iPhone.
- Reuse existing playback and artwork infrastructure (`PlaybackController`, `ArtworkProvider`, `ImageCache`).
- Fit the layered architecture: CarPlay code lives in `Adapters/`, testable grid/coordinator logic in unit tests.
- Document entitlement request and human verification steps.

## Non-goals

- Porting SwiftUI `GridLayout` or vinyl selection animation to CarPlay.
- List layout, context menus, snackbars, or any editing from the car.
- Live sync between iPhone and CarPlay while both are active (v1 reloads on connect only).
- Shared in-memory `AlbumStore` between phone and CarPlay (Approach 2 — rejected).
- CarPlay-only separate library (user chose same library, read-only in car).

## Brainstorming decisions

| Topic | Choice |
|-------|--------|
| Library source | Same as iPhone — read-only in car |
| Playback tap | Single tap starts/restarts album; pause via Now Playing only |
| Shuffle | Session-only reorder on CarPlay; independent from phone shuffle |
| CarPlay entitlement | Not yet granted — include request + portal setup in spec |
| Unauthorized | `CPInformationTemplate` — open MusicWall on iPhone to set up |
| Empty library | Same setup template as unauthorized (one generic message) |
| Architecture | Dedicated CarPlay adapter layer (Approach 1) |

## Approaches considered

### CarPlay integration shape

| Option | Description | Why not chosen |
|--------|-------------|----------------|
| **Dedicated adapter layer (chosen)** | `Adapters/CarPlay/` with scene delegate, coordinator, pure grid builder | — |
| App-level shared `AlbumStore` | Single store instance for phone + CarPlay | Larger refactor; couples shuffle across surfaces |
| CarPlay-only fork | One large scene delegate file | Hard to test; drifts from conventions |

## UX specification

### In scope

- CarPlay Audio app using `CPGridTemplate` — album artwork buttons, **8 items per page** with pagination.
- Albums displayed in saved sort order (no sort controls on CarPlay).
- Toolbar shuffle button — calls `AlbumStore.temporarilyShuffle()`; does not persist; reconnect restores saved order.
- Single tap on album → `PlaybackController.play(albumId:)` (always play/restart; no tap-to-pause).
- Pause, skip, and scrub via system Now Playing UI.

### Setup required state

When **either** Apple Music is not authorized **or** the saved library is empty, show one `CPInformationTemplate`:

- **Title:** MusicWall
- **Body:** Open MusicWall on your iPhone to set up your album wall.
- No action buttons required (user cannot fix auth or add albums from the car).

### Out of scope on CarPlay

- Search, add album, edit, delete, import/export, sort menu, list layout, vinyl animation, snackbars.

## Architecture

### Component map

```
CarPlaySceneDelegate (CPTemplateApplicationSceneDelegate)
    └── CarPlayCoordinator (@MainActor)
            ├── AlbumStore (local instance, UserDefaultsPreferencesStore.standard)
            ├── PlaybackController (AppDependencies.live)
            ├── ArtworkProvider + ImageCache (existing)
            ├── CarPlayGridBuilder (pure — pagination + CPGridButton mapping)
            └── CarPlaySetupTemplate (factory — CPInformationTemplate)
```

| Component | Location | Responsibility |
|-----------|----------|----------------|
| `CarPlaySceneDelegate` | `Adapters/CarPlay/` | Scene connect/disconnect; creates coordinator |
| `CarPlayCoordinator` | `Adapters/CarPlay/` | Auth check, load library, template selection, shuffle, tap handling |
| `CarPlayGridBuilder` | `Adapters/CarPlay/` | `[AlbumRecord]` → `[CPGridTemplate]` with pagination |
| `CarPlaySetupTemplate` | `Adapters/CarPlay/` | Static setup `CPInformationTemplate` |

CarPlay code belongs in **Adapters** (UIKit/CarPlayKit platform boundary), not Features (SwiftUI).

### Connect lifecycle

```
CarPlay connects
  → CarPlayCoordinator created (AppDependencies.live)
  → MusicAuthorization.status != .authorized?
        yes → push CarPlaySetupTemplate
        no  → await store.load()
              → store.items.isEmpty?
                    yes → push CarPlaySetupTemplate
                    no  → CarPlayGridBuilder.build(templates from store.items)
                          → set root CPGridTemplate (first page)
                          → attach shuffle bar button
```

### Shuffle

1. User taps shuffle on CarPlay toolbar.
2. `store.temporarilyShuffle()` (no persist — existing `AlbumCollection` behavior).
3. Rebuild grid templates from shuffled `store.items`.
4. Replace current template stack root with new first page.

Shuffle on iPhone does **not** affect CarPlay order mid-session (separate `AlbumStore` instances).

### Album tap

```
CPGridButton handler(albumID)
  → try? await playback.play(albumId: albumID)
```

No `AlbumTapCoordinator` toggle logic on CarPlay. Playback errors are silent (no CarPlay snackbar equivalent).

### Library refresh

- Reload from UserDefaults on **each CarPlay connect** via `AlbumStore.load()`.
- Albums added/removed on iPhone appear on the **next** CarPlay session.
- No notification-based live sync in v1.

### Artwork on grid buttons

- Use `ArtworkProvider` + `ImageCache` (same as `AlbumArtwork` on phone).
- Load artwork asynchronously when building/rebuilding templates; use placeholder until loaded.
- Target size: CarPlay grid button artwork dimensions (typically ~100pt; use display scale for pixel size).

## App shell & project changes

### Scene configuration

Register a CarPlay scene in the app entry point (multi-scene pattern):

- `MusicWallApp.swift`: add `CPTemplateApplicationSceneDelegate` scene to `@main` app.
- Generated Info.plist keys (via `project.pbxproj`):
  - `UIApplicationSceneManifest` — include CarPlay scene configuration with delegate class name.
  - CarPlay scene role: `CPTemplateApplicationSceneSessionRoleApplication`.

### Frameworks & entitlements

- Link `CarPlay.framework`.
- Add entitlement: `com.apple.developer.carplay-audio` (after Apple approval).
- Re-run match to refresh provisioning profiles once capability is enabled on App ID `chris.MusicWall`.

### CarPlay Audio entitlement request (human)

1. Log in to [Apple Developer](https://developer.apple.com) → Certificates, Identifiers & Profiles.
2. Submit a CarPlay entitlement request: **App Services → CarPlay → Audio App** (or equivalent portal flow for third-party audio apps).
3. Provide app description: MusicWall is a curated album wall for Apple Music; CarPlay shows the saved grid for one-tap album playback while driving.
4. Wait for Apple approval email.
5. Enable **CarPlay Audio** capability on App ID `chris.MusicWall`.
6. Run `bundle exec fastlane match appstore` (or CI match step) to regenerate profiles.
7. Verify on a physical device with CarPlay (simulator CarPlay also requires the entitlement).

**Note:** CarPlay will not function on device or pass App Review without this entitlement. Implementation can proceed in parallel; TestFlight validation requires approval.

## Testing

### Unit tests (CI — deterministic)

| Test file | Cases |
|-----------|-------|
| `CarPlayGridBuilderTests` | Empty → no templates; 1–8 albums → 1 page; 9 albums → 2 pages; button titles match album titles |
| `CarPlayCoordinatorTests` | Unauthorized → setup template; authorized + empty → setup template; authorized + items → grid; shuffle changes item order without calling persist |

Use `MockPlaybackController`, in-memory `UserDefaults` preferences, and preview/mock repository — no live MusicKit or CarPlay runtime.

### Not unit-tested

- Live CarPlay template rendering (requires entitlement + CarPlay simulator or head unit).
- Async artwork appearance on grid buttons (manual verification).

### Human verification checklist

- [ ] CarPlay Audio entitlement approved; profiles updated via match.
- [ ] MusicWall appears in CarPlay app list when iPhone is connected.
- [ ] Unauthorized → setup template with iPhone message.
- [ ] Authorized but empty library → same setup template.
- [ ] Grid shows albums in saved sort order with artwork.
- [ ] Tap album → playback starts; Now Playing shows correct album.
- [ ] Shuffle reorders grid; disconnect/reconnect restores saved sort order.
- [ ] Add album on iPhone → appears after next CarPlay connect.
- [ ] No search, edit, import/export, sort, or list UI on CarPlay.

## Error handling

| Condition | Behavior |
|-----------|----------|
| Not authorized | Setup template |
| Empty library | Setup template (same message) |
| `store.load()` failure | Setup template (treat as empty/unavailable) |
| `playback.play` failure | Silent no-op |
| Artwork load failure | Grid button shows without image or system placeholder |

## Dependencies on existing code

| Existing | CarPlay usage |
|----------|---------------|
| `AlbumStore` | Load/display library; shuffle |
| `AppDependencies.live` | Wire repository, playback, artwork, preferences |
| `PlaybackController` | Album playback |
| `ArtworkProvider` + `ImageCache` | Grid button images |
| `AlbumLibraryLoader` | Indirect via `AlbumStore.load()` |

No changes to Core domain types. No new MusicKit imports in Core.

## Risks

| Risk | Mitigation |
|------|------------|
| Entitlement approval delay | Implement and unit-test before approval; gate TestFlight CarPlay QA on approval |
| Stale library mid-drive | Document v1 behavior; reload on connect is sufficient for most use |
| CarPlay template API changes | Isolate in Adapters; grid builder is pure and easy to adjust |

## Success criteria

- CarPlay grid mirrors iPhone library (sort order, artwork, album set) after connect.
- Shuffle works session-only on CarPlay without affecting persisted order.
- Setup template covers both unauthorized and empty-library cases with one message.
- Unit tests cover grid pagination and coordinator state selection.
- Entitlement and human verification steps documented and completed before store release.

# Target architecture (MusicWall test refactor)

## Layer diagram

```
MusicWall App (SwiftUI + ViewModels + AppDependencies)
    │
    ├── MusicWallCore (no MusicKit / SwiftUI / UIKit)
    │     AlbumID, AlbumRecord, AlbumCollection, AlbumSorter, BackupCodec
    │     Protocols: AlbumRepository, PlaybackController, PreferencesStore, ArtworkProvider
    │
    ├── MusicWallPersistence
    │     UserDefaultsPreferencesStore, file I/O helpers
    │
    └── MusicWallMusicKit
          MusicKitAlbumRepository, SystemMusicPlayerAdapter, AlbumMapper
```

Physical layout may be `Packages/*` (PR 15) or `MusicWall/Core/`, `MusicWall/Adapters/` until then.

## Design rules (enforce in review)

| Rule | Rationale |
|------|-----------|
| Core has zero MusicKit/SwiftUI/UIKit imports | Fast, deterministic unit tests |
| Domain types are app-owned | Tests don't construct `MusicKit.Album` |
| No `play()` / `pause()` on `AlbumRecord` or `StoredAlbum` | Playback is `PlaybackController` (PR 5+) |
| Views don't call repositories directly | PR 5: search uses injected `AlbumRepository`; PR 10+: ViewModels own async (see PR 5 design) |
| Single composition root (`AppDependencies.live`) | Previews/tests swap fakes; leaf views may use `@Environment` for services (PR 5 hybrid) |
| Side effects at boundaries | Sort/add/remove testable without I/O |

## Legacy → target mapping

| Legacy | Target |
|--------|--------|
| `StoredAlbum` + `MusicItemID` | `AlbumRecord` + `AlbumID` |
| `StoredAlbums` | `AlbumCollection` + `PreferencesStore` |
| `UserDefaultsManager` static | `PreferencesStore` protocol |
| `MusicService` enum | `AlbumRepository` + `PlaybackController` |
| `BackupService` | `BackupCodec` + `FileExportService` / `SecurityScopedReader` |
| `StoredAlbum.play()` / `onAlbumTapped` inline | PR 5: `PlaybackController` in `onAlbumTapped`; PR 11: `AlbumTapCoordinator` |
| `ImageCache` + `MusicService` | PR 5: `AlbumRepository.artworkURL`; PR 11: `ArtworkProvider` + injected session/filesystem |

## Environment injection pattern

```swift
// PR 5 (services) — installed from HomePageView; facades use constructor injection
extension EnvironmentValues {
  @Entry var albumRepository: any AlbumRepository
  @Entry var playback: any PlaybackController
}

// PR 6+ (collection state)
// @Entry var albumCollection: AlbumCollection
```

Previews: `AppDependencies.preview()` mocks + `.environment(\.playback, deps.playbackController)` on subtree.

**`AlbumRecord` fields (PR 5):** `id`, `title`, `artistName`, `releaseDate`, `isExplicit`.

## Error handling

- Replace `print(...)` in search/tap flows with ViewModel-visible errors → snackbar.
- Map MusicKit errors to domain errors at adapter boundary only.

## File organization (after PR 11)

```
MusicWall/
  App/              MusicWallApp, AppDependencies
  Features/
    Home/           HomePageView, HomeViewModel
    Search/         AlbumSearchView, SearchViewModel
    Auth/           ContentView, AuthViewModel
  DesignSystem/     SnackbarView, layout containers
  Core/             (until SPM) pure types + protocols
  Adapters/         MusicKit, UserDefaults, files
```

## Human verification (not unit-tested)

- Real `MusicAuthorization` on device
- Catalog/library search with live Apple Music
- `SystemMusicPlayer` playback
- Internal TestFlight build (existing CI loop)

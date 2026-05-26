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
| No `play()` / `pause()` on `AlbumRecord` | Playback is `PlaybackController` |
| Views don't call repositories | Only ViewModels/coordinators do |
| Single composition root (`AppDependencies.live`) | Previews/tests swap fakes |
| Side effects at boundaries | Sort/add/remove testable without I/O |

## Legacy → target mapping

| Legacy | Target |
|--------|--------|
| `StoredAlbum` + `MusicItemID` | `AlbumRecord` + `AlbumID` |
| `StoredAlbums` | `AlbumCollection` + `PreferencesStore` |
| `UserDefaultsManager` static | `PreferencesStore` protocol |
| `MusicService` enum | `AlbumRepository` + `PlaybackController` |
| `BackupService` | `BackupCodec` + `FileExportService` / `SecurityScopedReader` |
| `StoredAlbum.play()` / `onAlbumTapped` inline | `AlbumTapCoordinator` + `PlaybackController` |
| `ImageCache` + `MusicService` | `ArtworkProvider` with injected session/filesystem |

## Environment injection pattern

```swift
// Example — adapt names to codebase
extension EnvironmentValues {
  @Entry var albumCollection: AlbumCollection
  @Entry var playback: any PlaybackController
}
```

Previews: `.environment(\.albumCollection, .fixture(count: 3))`

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

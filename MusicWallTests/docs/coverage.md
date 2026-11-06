# Coverage policy

Thresholds, adapter exclusions, and the boundary between CI-gated and human-verified behavior. Read before changing coverage scripts or exclusions.

CI enforces line coverage through `Scripts/check_coverage.sh` after every `bundle exec fastlane ci_tests` run.

| Layer | Path rule | Threshold |
|-------|-----------|-----------|
| Core / Persistence | `MusicWall/Core/**` | ≥ 95% |
| ViewModels | `MusicWall/Features/**/*ViewModel.swift` | ≥ 90% |
| Adapters | `MusicWall/Adapters/**` minus exclusions | ≥ 80% |

## Adapter exclusions (live or device-only)

These files are omitted from the adapter denominator:

| File or path | Reason |
|--------------|--------|
| `MusicWall/Adapters/MusicKitAlbumRepository.swift` | Live catalog and library search |
| `MusicWall/Adapters/SystemMusicPlayerAdapter.swift` | Live playback |
| `MusicWall/Adapters/MusicKitArtworkProvider.swift` | Live artwork fetch |
| `MusicWall/Adapters/AlbumMapper.swift` | MusicKit mapping, tested through mocks |
| `MusicWall/Adapters/SecurityScopedResourceReader.swift` | Security-scoped file picker I/O |
| `MusicWall/Adapters/LiveMusicAuthorizationProvider.swift` | Live authorization dialog |
| `MusicWall/Adapters/CarPlay/` (six of nine files; the set is in `Scripts/check_coverage.sh`) | Device-only CarPlay templates |

## Human-verified (not CI-gated)

- Live MusicKit authorization success paths.
- Live Apple Music catalog or library responses.
- `SystemMusicPlayer` playback on device.
- SwiftUI animations, vinyl effects, and snackbar auto-dismiss timing.

Keep `MusicWallTests` and `MusicWallUITests` in the shared `MusicWall` scheme `TestAction`, and keep scheme coverage gathering enabled.

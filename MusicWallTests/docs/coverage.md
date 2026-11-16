# Coverage policy

Thresholds, adapter exclusions, and the boundary between CI-gated and human-verified behavior. Read before changing coverage scripts or exclusions.

CI enforces line coverage through `Scripts/check_coverage.sh` after every `bundle exec fastlane ci_tests` run.

| Layer | Path rule | Threshold |
|-------|-----------|-----------|
| Core / Persistence | `MusicWall/Core/**` | ≥ 95% |
| ViewModels | `MusicWall/Features/**/*ViewModel.swift` | ≥ 90% |
| Adapters | `MusicWall/Adapters/**` minus exclusions | ≥ 80% |

## Adapter exclusions

The excluded adapter files are the basenames listed in `EXCLUDED_ADAPTERS` in `Scripts/check_coverage.sh`; to exclude another, add its basename there. Matching ignores folders, so a same-named file anywhere under `MusicWall/Adapters/` is excluded too, and other `CarPlay/` files still count until their basenames are added.

Exclusions use one of these reasons:

- **Live API** — MusicKit search, playback, artwork, and authorization; security-scoped file access that only real picked files exercise.
- **Device-only** — CarPlay scene delegate, coordinator, templates, and their helpers, excluded as a set even where a simulator test exists.
- **Tested through mocks** — behavior covered through test doubles instead of direct tests; no current exclusion qualifies, and `AlbumMapper` is a known gap: no direct test exists, and its only callers are in the excluded live repository.

## Human-verified (not CI-gated)

- Live MusicKit authorization success paths.
- Live Apple Music catalog or library responses.
- `SystemMusicPlayer` playback on device.
- SwiftUI animations, vinyl effects, and snackbar auto-dismiss timing.

Keep `MusicWallTests` and `MusicWallUITests` in the shared `MusicWall` scheme `TestAction`, and keep scheme coverage gathering enabled.

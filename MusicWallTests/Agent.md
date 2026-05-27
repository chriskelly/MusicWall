# Agent guide — MusicWallTests

`MusicWallTests` is the deterministic unit-test target for MusicWall. It runs through the shared `MusicWall` scheme on the iPhone 17 simulator.

## Fixtures

- `MusicWallTests/Fixtures/AlbumFixtures.swift` — canonical `AlbumRecord` samples (`baseTrio`, UTC date helpers). Reused across sort/collection tests; PR 6 adds JSON migration fixtures in the same folder.

## Framework

- Default: Swift Testing
- Fallback: switch this target to XCTest only if Swift Testing causes scheme or CI instability disproportionate to PR 1

## Commands

- `bundle exec fastlane ci_test`
- `xcodebuild test -project MusicWall.xcodeproj -scheme MusicWall -destination 'platform=iOS Simulator,name=iPhone 17'`

## Coverage

- Keep `MusicWallTests` in the shared `MusicWall` scheme `TestAction`
- Keep scheme coverage gathering enabled

## Exclusions

These remain human-verified or future-test work, not deterministic CI coverage:

- live MusicKit authorization
- live Apple Music catalog or library responses
- `SystemMusicPlayer` playback behavior
- device-only behavior that cannot be reproduced on the simulator

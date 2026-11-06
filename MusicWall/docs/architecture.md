# App architecture and project setup

How the app is composed and how the Xcode project is wired. Read before changing dependency injection, project settings, or device-only behavior.

## Composition and injection

- **Production:** `AppDependencies.live` wires the live adapters. Install services on the SwiftUI tree from `HomePageView`, using environment keys for `albumRepository`, `playback`, and the others.
- **Previews and unit tests:** use `AppDependencies.preview()` or mocks in `MusicWallTests/TestSupport/`. Never require live MusicKit in unit tests.
- **Backup injection:** `HomePageView` makes no direct `albumBackupService` calls; backup work belongs to `HomeViewModel`.
- **`AlbumRecord` fields:** `id`, `title`, `artistName`, `releaseDate`, `isExplicit`.

## Xcode project

- The app target uses a **filesystem-synchronized** `MusicWall/` group, so new Swift files are picked up automatically.
- Scheme: **MusicWall**, shared in `MusicWall.xcodeproj/xcshareddata/xcschemes`.
- Deployment target: `IPHONEOS_DEPLOYMENT_TARGET` in `MusicWall.xcodeproj/project.pbxproj`; keep the CI Xcode version compatible.

## Human verification (not unit-tested)

- Live `MusicAuthorization` on device.
- Catalog and library search against live Apple Music.
- `SystemMusicPlayer` playback.
- CarPlay Audio — needs the Apple entitlement plus a physical device or the CarPlay simulator.
- An internal TestFlight build, through the CI loop.

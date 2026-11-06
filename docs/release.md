# Release process

How build numbers, marketing versions, metadata, and App Store submission work. Read before cutting a release or changing Fastlane release settings.

## Versions and build numbers

- **PR / TestFlight:** `CFBundleVersion` comes from Fastlane `resolve_build_number_for_upload` — the app-wide latest build on App Store Connect plus one, not per marketing version. Preview and release share this logic so build numbers never collide across workflows.
- **PR marketing version:** Fastlane `resolve_marketing_version_for_preview` reads the highest version on App Store Connect. If `MARKETING_VERSION` in `MusicWall.xcodeproj/project.pbxproj` is not above it, CI bumps the patch for the upload only; you do not need to bump the project after every shipped release for TestFlight to work.
- **Source of truth in git:** `MARKETING_VERSION` in `MusicWall.xcodeproj/project.pbxproj` is the version you are developing toward. Bump it when the next feature cycle starts; if you forget, a preview run selects the next version automatically.
- **Release tag or manual dispatch:** `CFBundleShortVersionString` comes from the tag or workflow input; the build number uses the same App Store Connect lookup for that version.

## Release flow

- Releases are tag-driven: pushing `vX.Y.Z` (or running **Actions → App Store Release → Run workflow**) uploads and submits for review.
- `automatic_release: true` in Fastlane: the version goes live when App Review passes, not "Pending Developer Release". To hold a release, set it to false or change the version in App Store Connect before approval.
- **Export compliance:** `INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO` is set in `MusicWall.xcodeproj/project.pbxproj`. The TestFlight upload passes `uses_non_exempt_encryption: false`; the App Store upload uses the plist only.
- **Metadata:** edit `fastlane/metadata/en-CA/release_notes.txt` and keep `fastlane/metadata/en-CA/copyright.txt` current before each release. The primary locale is **English (Canada)** (`en-CA`); the deliver step uploads these files when `skip_metadata: false`.

## Precheck

Precheck runs on preview (before build) and release (before submit). `default_rule_level: :error`, so warnings fail CI. IAP checks are off because of an API key limitation. It validates the **live App Store Connect listing**, not the PR diff.

```bash
export APP_STORE_CONNECT_API_KEY_KEY_ID=...
export APP_STORE_CONNECT_API_KEY_ISSUER_ID=...
export APP_STORE_CONNECT_API_KEY_CONTENT=...   # base64 .p8
bundle exec fastlane ios precheck_release
```

After adding metadata for the first time, run **App Store Release** once (or set copyright in App Store Connect) so TestFlight precheck passes on copyright.

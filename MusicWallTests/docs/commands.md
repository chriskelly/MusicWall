# Test commands

Full commands for running one test, checking coverage, and checking warnings. Read when the short summary in `../AGENTS.md` is not enough.

## All tests

Run unit tests, UI tests, and the coverage gate:

```bash
bundle exec fastlane ci_tests
```

## Unit tests only

```bash
xcodebuild test -project MusicWall.xcodeproj -scheme MusicWall \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:MusicWallTests
```

## UI tests only

```bash
xcodebuild test -project MusicWall.xcodeproj -scheme MusicWall \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:MusicWallUITests
```

## A single UI test

```bash
xcodebuild test -project MusicWall.xcodeproj -scheme MusicWall \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:MusicWallUITests/MusicWallUITests/testLaunch_savedLibrary_showsFixtureTitles
```

## Coverage gate only

Run the tests with a result bundle, then inspect coverage:

```bash
xcodebuild test -project MusicWall.xcodeproj -scheme MusicWall \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -resultBundlePath build/MusicWallTestResults.xcresult
Scripts/check_coverage.sh build/MusicWallTestResults.xcresult
```

Set `FAIL_CI=false` to print the report without failing locally:

```bash
FAIL_CI=false Scripts/check_coverage.sh build/MusicWallTestResults.xcresult
```

## Warnings report only

```bash
xcodebuild test -project MusicWall.xcodeproj -scheme MusicWall \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  2>&1 | tee build/xcodebuild.log
Scripts/check_warnings.sh build/xcodebuild.log
```

You can re-use the log from `bundle exec fastlane ci_tests` (`build/xcodebuild.log`).

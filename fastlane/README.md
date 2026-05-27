fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## iOS

### ios ci_build

```sh
[bundle exec] fastlane ios ci_build
```

Simulator build only (no signing upload; local / no-deploy)

### ios ci_tests

```sh
[bundle exec] fastlane ios ci_tests
```

CI Tests workflow: unit tests on iOS Simulator

### ios testflight_release

```sh
[bundle exec] fastlane ios testflight_release
```

TestFlight Release workflow: internal TestFlight upload

### ios precheck_release

```sh
[bundle exec] fastlane ios precheck_release
```

App Store precheck only (run locally before release; needs ASC API key env)

### ios app_store_release

```sh
[bundle exec] fastlane ios app_store_release
```

App Store Release workflow: upload and submit for review

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).

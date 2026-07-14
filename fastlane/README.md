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

### ios cut_release

```sh
[bundle exec] fastlane ios cut_release
```

Cut a new release branch and bump the marketing version

### ios beta

```sh
[bundle exec] fastlane ios beta
```

Build a signed release and upload it to TestFlight

### ios publish

```sh
[bundle exec] fastlane ios publish
```

Tag, create a GitHub release, and merge the release branch back to main

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).

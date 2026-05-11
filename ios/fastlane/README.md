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

### ios match_dev

```sh
[bundle exec] fastlane ios match_dev
```

Sync development certs + profiles from match repo

### ios match_release

```sh
[bundle exec] fastlane ios match_release
```

Sync App Store certs + profiles from match repo

### ios beta

```sh
[bundle exec] fastlane ios beta
```

Upload the IPA at ../build/ios/ipa/*.ipa to TestFlight.

Auth path:

  - If APP_STORE_CONNECT_API_KEY_ID/ISSUER_ID/PRIVATE_KEY env vars are set,

    use the API key (preferred for CI / Codemagic).

  - Else, fall back to FASTLANE_USER + interactive 2FA prompt.

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).

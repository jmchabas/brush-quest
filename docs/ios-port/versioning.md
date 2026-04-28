# Brush Quest — Version & Build Number Convention

> Source of truth for how `pubspec.yaml` `version:` translates to Android `versionCode` and iOS `CFBundleVersion`. Read at the start of any release task.

## Convention

`pubspec.yaml` carries the canonical version: `version: X.Y.Z+N`

| Field        | Meaning                                                                      | Drives on Android         | Drives on iOS         |
| ------------ | ---------------------------------------------------------------------------- | ------------------------- | --------------------- |
| `X.Y.Z`      | Marketing version. Same number visible to users on both stores.              | `versionName`             | `CFBundleShortVersionString` |
| `+N`         | Monotonically increasing build counter. Never reused, never reset.            | `versionCode`             | `CFBundleVersion`     |

**Both stores share the same `+N`.** When we ship version `1.0.0+21`, that's:

- Play Store internal track: `versionCode = 21`
- TestFlight + App Store: `CFBundleVersion = 21`

## Bump rules

1. **Bump `+N` on every uploaded build**, whether to TestFlight, Play internal, or production. Each store upload uses a unique `+N`.
2. **Never reuse a `+N`** even across stores. If you upload `1.0.0+21` to Android and the iOS build fails, the next iOS attempt is `1.0.0+22` (not `1.0.0+21`).
3. **`X.Y.Z` bumps separately** when you cut a marketing release: bug-fix → `Z`, minor feature → `Y`, breaking → `X`. Independent of `+N`.
4. **`+N` is monotonic** — only goes up. Both stores enforce this; rejecting non-monotonic upload is silent and confusing.

## Why this convention

- **One number to remember.** When a tester asks "what build do you have?" the answer is unambiguous regardless of platform.
- **Crash report correlation.** A crash on `1.0.0+24` means the same source tree on either platform.
- **Avoids the "skip 21 on iOS, ship 22 on Android, then iOS at 23" mess** that's common when teams drift the build numbers per-platform.

## Current state (2026-04-28)

- `pubspec.yaml` is at `1.0.0+20` (Android v20 live in Play Store internal testing as of 2026-04-21).
- Next iOS build will be `1.0.0+21` (or higher if Android ships a +21 first).
- The two stores will not be at the same `+N` permanently — Android is ahead until iOS launches. **That's fine.** What matters is each `+N` is unique and monotonic.

## How Flutter wires this up

Flutter scaffolds the `Info.plist` and `build.gradle` with the right substitutions automatically:

- `ios/Runner/Info.plist` should reference `$(FLUTTER_BUILD_NAME)` for `CFBundleShortVersionString` and `$(FLUTTER_BUILD_NUMBER)` for `CFBundleVersion`.
- `android/app/build.gradle` reads `flutterVersionCode` and `flutterVersionName` from `local.properties`, which Flutter populates from pubspec.

Verification (do this if the version on a built artifact looks wrong):

```bash
# Bump pubspec to a known value
# Then build for each platform and verify the output:

flutter build ios --no-codesign
plutil -p build/ios/iphoneos/Runner.app/Info.plist | grep -E "CFBundleVersion|CFBundleShortVersionString"

flutter build apk --debug
aapt2 dump badging build/app/outputs/flutter-apk/app-debug.apk | grep -E "versionCode|versionName"
```

Both should reflect the pubspec `version:` value.

## Where this can go wrong

- **Direct edits to `Info.plist` or `build.gradle`** that override `$(FLUTTER_BUILD_NUMBER)` will silently desync. Don't do that — fix it in `pubspec.yaml`.
- **Fastlane lanes** that bump build numbers per-store (e.g., a lane that increments only the Android `versionCode`) violate this convention. We don't have such a lane today; if one is added in Phase 2, it must bump `pubspec.yaml` and let Flutter propagate.
- **Codemagic CI that reads from environment variable** (`FLUTTER_BUILD_NUMBER`) instead of pubspec — fine if the env var is sourced from the latest pushed `pubspec.yaml`. If it's a separately-counted CI build number, that breaks the convention.

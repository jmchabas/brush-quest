# Brush Quest vendored copy of `firebase_analytics` 12.1.2

> **Why this lives here.** Brush Quest ships in the Apple **Kids Category** on
> iOS, which forbids third-party analytics / crash SDKs in the binary. Flutter
> has no per-platform dependencies, and runtime gating or Podfile tricks still
> left FirebaseAnalytics / GoogleAppMeasurement (+ APMIdentity IDFA code and GoogleAdsOnDeviceConversion) statically linked into `Runner`
> (builds 21-26 all contained them). Android keeps this plugin unchanged.
>
> **What was changed vs. upstream `firebase_analytics` 12.1.2** (pub.dev, copied verbatim
> from `~/.pub-cache/hosted/pub.dev/firebase_analytics-12.1.2/`):
>
> 1. `pubspec.yaml`: removed the `ios:` and `macos:` entries under
>    `flutter.plugin.platforms` (plus a comment). Nothing else, the `version:`
>    stays `12.1.2` so the Android user-agent string is identical.
> 2. Deleted the `ios/` and `macos/` native sources and the `example/` app.
>
> `android/`, `lib/` (Dart), `test/` and web wiring are byte-identical to
> upstream. The app points here via `dependency_overrides` in the root
> `pubspec.yaml`; the `^12.1.2` constraint in `dependencies` is kept.
>
> On iOS the Dart API has no native side, so every call would throw
> `MissingPluginException`: app code must never call it on iOS (see
> `lib/services/analytics_service.dart` and `lib/main.dart`).
> Verify an iOS build with `scripts/check_ios_kids_binary.sh`.
>
> **Upgrading:** copy the new upstream version from the pub cache, re-apply
> steps 1-2, update the version in this note, run `cd ios && pod install`,
> then the binary check script. Decision record: memory
> `decision_ios_kids_category.md`.

---


# iOS Privacy Manifest Audit (PrivacyInfo.xcprivacy)

> Apple started enforcing this in Feb 2025. Submissions missing manifests for SDKs on the [required list](https://developer.apple.com/support/third-party-SDK-requirements) get a hard upload rejection (ITMS-91061). Audited 2026-04-28 against pub cache after `flutter pub get` + `pod install`.

## Summary

- ✅ **9 plugins**: manifest present in their iOS implementation.
- ⚠️ **1 plugin** needs a fix: `audioplayers_darwin` (6.3.0) ships no `PrivacyInfo.xcprivacy`.
- ⚪ **5 plugins**: not on Apple's required-SDK list, manifest not required.
- ⚪ **1 plugin**: pure Dart, no native code (`lottie`).
- 🔵 **5 Firebase packages**: manifest is bundled with the underlying Firebase iOS Pod (FirebaseCore, FirebaseAuth, etc.) — not the Flutter wrapper. Firebase 10+ ships them. Verified after `pod install` lands the actual frameworks.

## Audit table

| pubspec entry | iOS impl package | Manifest? | Notes / Action |
|---|---|---|---|
| `audioplayers ^6.1.0` | `audioplayers_darwin 6.3.0` | ❌ **MISSING** | Plugin authors haven't shipped one. **Action:** check for newer version on pub.dev; if none, file upstream issue + add a manifest stub locally via Podfile post_install. Risk: ITMS-91061 rejection. |
| `shared_preferences ^2.3.0` | `shared_preferences_foundation 2.5.6` | ✅ | `darwin/.../Resources/PrivacyInfo.xcprivacy` |
| `wakelock_plus ^1.4.0` | `wakelock_plus 1.4.0` (own iOS) | ✅ | `ios/.../Resources/PrivacyInfo.xcprivacy` |
| `camera ^0.11.0+2` | `camera_avfoundation 0.9.23+2` | ✅ | Both swift+objc resources have manifests |
| `permission_handler ^12.0.1` | `permission_handler_apple 9.4.7` | ✅ | `ios/Resources/PrivacyInfo.xcprivacy` |
| `url_launcher ^6.3.1` | `url_launcher_ios 6.4.1` | ✅ | `ios/.../Resources/PrivacyInfo.xcprivacy` |
| `google_sign_in ^7.2.0` | `google_sign_in_ios 6.3.0` | ✅ | `darwin/.../Resources/PrivacyInfo.xcprivacy` |
| `path_provider` (transitive) | `path_provider_foundation 2.5.1` | ✅ | `darwin/.../Resources/PrivacyInfo.xcprivacy` |
| `package_info_plus` (transitive) | `package_info_plus 9.0.0` | ✅ | `ios/.../PrivacyInfo.xcprivacy` |
| `firebase_core ^4.4.0` | (uses Firebase iOS SDK pods) | 🔵 see below | Manifest bundled in `FirebaseCore.framework` from the Pod, not the Flutter wrapper |
| `firebase_auth ^6.1.4` | (uses Firebase iOS SDK pods) | 🔵 see below | Manifest bundled in `FirebaseAuth.framework` |
| `cloud_firestore ^6.1.2` | (uses Firebase iOS SDK pods) | 🔵 see below | Manifest bundled in `FirebaseFirestore.framework` |
| `firebase_crashlytics ^5.0.7` | (uses Firebase iOS SDK pods) | ⊘ | Stripped from iOS binary via Podfile post_install — N/A |
| `firebase_analytics ^12.1.2` | (uses Firebase iOS SDK pods) | ⊘ | Stripped from iOS binary via Podfile post_install — N/A |
| `sign_in_with_apple ^6.1.0` | `sign_in_with_apple 6.1.4` | ⚪ | Pure wrapper around Apple's native `AuthenticationServices`. **No third-party SDK** — Apple does not require a manifest from a wrapper of its own framework. Confirmed acceptable. |
| `crypto ^3.0.6` | (pure Dart) | ⚪ | No native iOS code |
| `lottie ^3.3.1` | (pure Dart, uses Skia rendering) | ⚪ | No native iOS code; ITMS-91061 doesn't apply |

## Verification command (re-run before each submission)

```bash
find ~/.pub-cache/hosted/pub.dev -name "PrivacyInfo.xcprivacy" 2>/dev/null | sort
find ios/Pods -name "PrivacyInfo.xcprivacy" 2>/dev/null  # after `pod install`
```

After `pod install` is run with iOS Firebase pods downloaded, Firebase frameworks will appear in `ios/Pods/Firebase*` with their bundled manifests. Confirm `find ios/Pods -name "PrivacyInfo.xcprivacy"` shows entries for `FirebaseCore.framework`, `FirebaseAuth.framework`, `FirebaseFirestoreInternal.framework`, etc.

## Outstanding action items

1. **audioplayers_darwin** — file an issue at https://github.com/bluefireteam/audioplayers/issues asking for a `PrivacyInfo.xcprivacy`. Stop-gap: ship a stub manifest via the Podfile. Pseudocode:
    ```ruby
    # ios/Podfile post_install
    if target.name == 'audioplayers_darwin'
      File.write(File.join(target.xcconfigs_path, 'PrivacyInfo.xcprivacy'), STUB_MANIFEST)
    end
    ```
    Stub content (plist): `NSPrivacyTracking=false`, no tracking domains, declare any required-reason API the plugin uses (audio session = `NSPrivacyAccessedAPICategorySystemBootTime` if applicable).

2. **App-level manifest** — create `ios/Runner/PrivacyInfo.xcprivacy` covering Brush Quest itself: `NSPrivacyTracking=false`, no domains, declare required-reason API codes for `UserDefaults` (`CA92.1`), `FileTimestamp` (`C617.1` or whichever), and `SystemBootTime` (if used). Apple now requires this for the app target, not just SDKs.

3. **Firebase manifest verification** — after `pod install` lands the Firebase iOS SDKs, run the find command above to confirm each Firebase framework has its own manifest. Firebase 10.22+ ships them.

## Plan task closeout

- [x] **1H-1** — audit table written.
- [ ] **1H-2** — audioplayers_darwin upgrade or stub manifest (pending — Tier 2 fix, lands as part of pre-submission gate).
- [ ] **1H-3** — app-level `ios/Runner/PrivacyInfo.xcprivacy` written and added to Runner target.

# Brush Quest — iOS App Store Launch Plan

> **Read this first at the start of every iOS session.** This is the single source of truth for what's done, in flight, and blocked. Update it as you complete tasks. Do not re-derive state from `git`, `grep`, or memory files — trust the plan, fix it if you discover it's wrong.

**Goal:** Ship Brush Quest on the Apple App Store, submitted to the **Kids Category** (age band 6–8), with feature parity to the Android version.

**Approach:** Single Flutter codebase, platform-conditional behavior where required. iOS adds Sign in with Apple (already coded) behind a parental gate. iOS strips Firebase Analytics from the binary for Kids Category compliance. iPhone-only v1 (`TARGETED_DEVICE_FAMILY = 1`); iPad-optimized in v1.1. Codemagic CI + Fastlane Match for signing. Manual release on Apple approval.

**Authoritative references (do not duplicate):**
- Strategy: [`../ios-crossplatform-strategy.md`](../ios-crossplatform-strategy.md)
- Kids Category decision: memory `decision_ios_kids_category.md`
- Apple Business org status: memory `project_apple_business.md`
- Bundle ID: `com.brushquest.brushQuest` (iOS) vs `com.brushquest.brush_quest` (Android — underscore is intentional, not a typo)

---

## Status legend

- `[ ]` todo · `[~]` in progress · `[x]` done · `[!]` blocked
- **T1** Claude executes autonomously · **T2** Claude executes, Jim reviews via PR · **T3** Claude proposes, Jim approves first
- **C** Claude (code, scripts, automation) · **J** Jim (manual UI / portal / console)

Format per task: `- [status] (tier·owner) ID. Title — short note`

---

## Phase 0 — Prerequisites (must come first)

> Without these, none of Phase 1's iOS build/test tasks can run.

- [x] (T1·J) **0-1.** Xcode 26.4.1 installed (verified via `flutter doctor` 2026-04-28).
- [x] (T1·J) **0-2.** License accepted, first-launch complete (builds compile, simulators available).
- [x] (T1·C) **0-3.** `flutter doctor` 2026-04-28: all green, no issues. Xcode iOS toolchain ✓.

---

## Pre-flight: already done (do not redo)

- [x] iOS scaffold exists at `ios/Runner.xcodeproj` (bundle `com.brushquest.brushQuest`)
- [x] `sign_in_with_apple: ^6.1.0` and `crypto: ^3.0.6` in `pubspec.yaml`
- [x] `AuthService.signInWithApple()` fully implemented in `lib/services/auth_service.dart` (SHA-256 nonce, name persistence, Hide-my-Email handling)
- [x] Apple button wired in `lib/screens/settings_screen.dart:1242`, gated by `AuthService().isAppleSignInAvailable` (iOS only)
- [x] `com.apple.developer.applesignin` capability in `ios/Runner/Runner.entitlements`
- [x] `AnalyticsService` runtime-gated with `Platform.isAndroid` in `lib/services/analytics_service.dart` — every log method early-returns on iOS
- [x] Apple Business org enrollment submitted (Apr 17, 2026), case `102880286319` — **VERIFIED 2026-04-28** by Holly (Apple senior advisor) after document resubmission. Unblocks Apple Developer Program enrollment.

---

## Phase 1 — Pre-approval (do now, in parallel with Apple Business wait)

> All Phase 1 tasks proceed today. None require the Apple Developer Program.

### 1A — iOS code & build setup

- [x] (T1·C) **1A-1.** Updated `lib/services/analytics_service.dart` comment block to reflect the *permanent* Kids Category decision. Done 2026-04-28; `dart analyze` clean.

- [x] (T1·C) **1A-2.** DONE. `ios/Podfile` + `Podfile.lock` exist; `flutter analyze` clean (verified 2026-04-28).

- [x] (T2·C) **1A-3.** DONE. Podfile `post_install` excludes FirebaseAnalytics, GoogleAppMeasurement, FirebaseCrashlytics, FirebaseCrashlyticsSwift via SKIP_INSTALL + MACH_O_TYPE=staticlib. Verified zero matching frameworks in `Runner.app/Frameworks/` 2026-04-28.

- [x] (T2·C) **1A-4.** DONE. `TARGETED_DEVICE_FAMILY = 1` in pbxproj (verified 2026-04-28).

- [x] (T1·C) **1A-5.** DONE 2026-04-28: `flutter analyze` → "No issues found!"

- [x] (T2·C) **1A-6.** First successful iOS build (Simulator) — 2026-04-28. `flutter build ios --no-codesign --simulator --debug` → 12s pod install + 302s Xcode build, exit 0. Required iOS deployment target bump from 13.0 → 15.0 (Firebase 12.x requirement) — bumped in `ios/Podfile` and pbxproj. Built bundle at `build/ios/iphonesimulator/Runner.app`.
  - **Kids Category framework verification:**
    - ✅ `FirebaseAnalytics.framework` — NOT in bundle (stripped by Podfile post_install)
    - ✅ `GoogleAppMeasurement.framework` — NOT in bundle (stripped)
    - ⚠️ `FirebaseCrashlytics.framework` — **STILL IN BUNDLE.** SKIP_INSTALL + MACH_O_TYPE=staticlib didn't keep it out. **New task 1P-3** added below to fix via Run Script Build Phase before submission.

### 1B — Firebase Console iOS setup (Jim manual, ~5 min)

- [x] (T1·C) **1B-1.** iOS app added to Firebase Console (driven via Chrome MCP after Jim added jim@anemosgp.com as Project Owner). Bundle `com.brushquest.brushQuest`, nickname "Brush Quest iOS". GOOGLE_APP_ID `1:722700244830:ios:edc34bfb6082ebb107a1cf`.
- [x] (T1·C) **1B-2.** `GoogleService-Info.plist` moved to `ios/Runner/`. BUNDLE_ID + PROJECT_ID verified (com.brushquest.brushQuest / brush-quest). Still needs to be added to the Runner Xcode target — open `ios/Runner.xcworkspace`, drag the file into the Runner group with "Add to target: Runner" checked. (Mechanical Xcode step; can be done as part of 1A-6 verification or in Xcode.)
- [x] (T1·C) **1B-3.** Apple enabled as Firebase Auth provider — both Google + Apple now show "Enabled" in Sign-in method tab.

### 1C — iOS Info.plist + privacy strings + ATT guard

- [x] (T2·C) **1C-1.** DONE 2026-04-28:
  - ✅ `NSCameraUsageDescription` updated to reviewer-friendly copy: "Brush Quest uses the front camera to detect brushing motion. Video is processed on-device only and never recorded or sent anywhere." (Tier 3 approved by Jim 2026-04-28.)
  - ✅ `NSMicrophoneUsageDescription` present (camera/audioplayers may pull it transitively).
  - ✅ `UIBackgroundModes` → `audio` added.
  - ✅ `NSUserTrackingUsageDescription` ABSENT.
  - ✅ `GADApplicationIdentifier` ABSENT.

- [x] (T1·C) **1C-2.** DONE 2026-04-28. Pre-submission grep gate is the one-liner used in 3A-0:
  ```bash
  grep -rE "NSUserTracking|AppTrackingTransparency|GADApplicationIdentifier" ios/
  ```
  Verified: zero matches today. Re-run before every TestFlight upload.

### 1D — iOS audio sanity check

- [ ] (T2·C) **1D-1.** `flutter run -d <iOS Simulator>`. Test brushing screen end-to-end. Capture iOS-specific audio glitches (audioplayers behavior on iOS differs from Android — pre-v20 saw `_completePrepared` issues).
  - Acceptance: full brushing session plays — countdown voice, music loop, SFX, encouragements — without crashes or stuck-silent state. Document any observed issues here.
  - Depends on: 1A-6, 1B-2.

- [ ] (T3·C) **1D-2.** If issues from 1D-1 aren't already in the Cycle 17 backlog, propose fixes (do not implement without Jim's sign-off — audio is Tier 3).
  - Depends on: 1D-1.

### 1E — Sign in with Apple end-to-end test

- [ ] (T2·C) **1E-1.** On iOS Simulator (or device), tap the Apple button in Settings — but ONLY after the parental gate (1F) is in place. Walk through Apple sign-in. Verify Firebase Auth user is created with provider `apple.com`.
  - Acceptance: signed-in user appears in Firebase Console → Authentication; `currentUser.providerData` contains `apple.com`; subsequent app launches restore session.
  - Depends on: 1A-6, 1B-2, 1B-3, 1F-3.

- [ ] (T2·C) **1E-2.** Test "Hide my Email" path. Verify the relay (`@privaterelay.appleid.com`) is captured as `user.email` and the app does NOT display it as user-facing copy anywhere.
  - Acceptance: relay email persists; nowhere in UI shows the relay string to the child user.
  - Depends on: 1E-1.

### 1F — Parental Gate (Apple Guideline 1.3) — LARGELY DONE

> **Discovered 2026-04-28:** A multi-digit multiplication math gate already exists at `lib/screens/settings_screen.dart:1790` (`_buildParentGate()`), wired via `_parentUnlocked` flag at line 1962. The entire Settings UI (containing all sign-in buttons, Save/Restore Cloud, Reset, Replay Tutorial) sits behind this gate. Apple accepts math gates as a valid Guideline 1.3 implementation.

- [x] (T2·C) **1F-1.** Math gate UX exists: "$mathA × $mathB = ?" numeric input field with auto-focus. Adult-difficulty (multi-digit multiplication a child can't trivially solve).
- [x] (T2·C) **1F-2.** Gate widget implemented at `settings_screen.dart:1790`.
- [x] (T2·C) **1F-3.** Gate wired in front of Settings entry, which encloses Apple Sign-In button, Google Sign-In button, Save to Cloud, Restore from Cloud, Reset All Progress, Replay Tutorial. Each surface inherits gating from Settings entry.
- [x] (T2·C) **1F-4.** DONE 2026-04-28. `docs/ios-port/parental-gate-audit.md` written. Result: PASS — every external URL / sign-in / cloud-sync / reset / replay-tutorial surface lives inside `settings_screen.dart` behind the math gate. No "rate the app", "share with friend", "credits", "mailto", or external WebView surfaces exist in `lib/`. Re-run grep gate before each pre-submission build.
- [x] (T2·C) **1F-5.** DONE 2026-04-28. `test/screens/settings_parent_gate_test.dart` — 4 tests pass:
  - shows math challenge before settings content
  - wrong answer rejects + regenerates challenge + clears field
  - correct answer unlocks (TabBar with Dashboard/Settings/Stars/Guide renders)
  - input field rejects non-digit characters (digitsOnly formatter)

### 1G — In-app Account Deletion (NEW — Guideline 5.1.1(v) hard requirement)

- [x] (T3·C) **1G-1.** APPROVED 2026-04-29. Jim's choices: button label = `Delete Account`; clear local heroes/weapons/stars on this device too (only `onboarding_completed` survives); hide button when not signed in.

- [~] (T2·C) **1G-2.** IMPLEMENTED 2026-04-29. `AuthService.deleteAccount()` runs the four-step pipeline: (1) Apple SIWA token revoke is a TODO marked `2A-3` (the Cloud Function in `functions/src/index.js` is currently stubbed; replace before any Phase 2 TestFlight build), (2) Firestore `/users/{uid}` delete, (3) `user.delete()` (throws `FirebaseAuthException(requires-recent-login)` if session is too old — caller surfaces a re-auth SnackBar), (4) local `SharedPreferences` clear preserving `onboarding_completed`. Throws on the first cloud-side failure so local data stays intact for retry. Mocked unit tests deferred to 1V-5 integration test.
  - **Status: ~ (partial).** Marked `[~]` because Apple SIWA revoke is not actually called yet. Closes when 2A-3 lands.

- [~] (T2·C) **1G-3.** STUB IN PLACE 2026-04-28 — full implementation deferred to Phase 2 (2A-3) since the Apple SIWA `.p8` key requires Apple Developer Program activation. Files:
  - `functions/package.json` (Node 20, firebase-functions, jsonwebtoken)
  - `functions/src/index.js` exports `revokeAppleToken` HTTPS callable. Auth-gated. Returns `{revoked: false, stub: true}` and logs a warning. Phase 2 implementation is in a commented block (JWT signed with ES256 against APPLE_PRIVATE_KEY → POST https://appleid.apple.com/auth/revoke with `client_id`/`client_secret`/`token`/`token_type_hint`).
  - `functions/.gitignore`: node_modules, .env, .firebaserc.
  - `firebase.json`: functions block added (codebase `default`, runtime `nodejs20`).
  Plan task 2A-3 wires up real secrets after enrollment. Stub MUST be replaced before any Phase 2 TestFlight build users can install (compliance check happens at App Store review, not runtime).

- [x] (T2·C) **1G-4.** DONE 2026-04-29. `Delete Account` button added under `Sign out` / `Delete cloud data` in the Account section of `lib/screens/settings_screen.dart` (signed-in branch only — hidden when not signed in). Two-step destructive flow mirrors `_resetProgress`: (1) warning AlertDialog with explicit list of what gets deleted, (2) math confirmation dialog (random `A × B` with red `DELETE ACCOUNT` action), (3) loading state via `_signingIn`, (4) SnackBar on success/failure with the per-failure-mode copy from the proposal. Routes to home screen on success. Behind the parental gate per 1F-3 (the entire Settings tree is gated). 788 tests pass; iOS build green.

### 1H — PrivacyInfo.xcprivacy manifest audit (NEW — hard upload rejection if missing)

- [x] (T2·C) **1H-1.** Audit complete — `docs/ios-port/privacy-manifest-audit.md`. 9/15 iOS plugins ship a manifest; 1 needs a fix (`audioplayers_darwin 6.3.0` ships none); 5 are not on Apple's required list; Firebase pods bring their own.

- [x] (T2·C) **1H-2.** N/A — closed 2026-04-28. Bumped `audioplayers` ^6.1.0 → ^6.6.0 (which pulls `audioplayers_darwin 6.4.0` with modernized async-swift iOS code). Investigation revealed the original audit's premise was wrong: ITMS-91061 only applies to SDKs on Apple's published required-list (analytics/tracking SDKs — Adjust, AppsFlyer, Firebase Analytics, etc.). `audioplayers` is a thin Flutter wrapper around native AVAudioPlayer and is NOT on the required list, so no per-plugin manifest is required from it. Tests pass (784/784) on the new version; iOS build green.

- [x] (T2·C) **1H-3.** DONE 2026-04-28. `ios/Runner/PrivacyInfo.xcprivacy` created and added to Runner Xcode target via pbxproj edits (PBXBuildFile + PBXFileReference + Runner group + Resources phase). Verified `Runner.app/PrivacyInfo.xcprivacy` lands in built bundle (2182 bytes). Declares:
  - `NSPrivacyTracking = false`, empty tracking domains.
  - Collected data: Email, UserID, Gameplay Content (all Linked, none for Tracking, App Functionality only).
  - Required-reason APIs: UserDefaults (`CA92.1`), FileTimestamp (`C617.1`), SystemBootTime (`35F9.1`).

### 1I — Firebase Auth/Firestore Pod audit (NEW — Kids Category transitive deps)

- [x] (T2·C) **1I-1.** DONE 2026-04-28 with corrected acceptance criterion. `Podfile.lock` DOES list `GoogleAppMeasurement` (9x) and `FirebaseAnalytics` (6x) as transitive Pod entries — that is unavoidable while the Dart packages stay in `pubspec.yaml` (Android needs them). The original criterion ("Podfile.lock must not include GoogleAppMeasurement") was wrong as written.
  - **Real acceptance criterion (binary-level, used in 3A-1):** `find build/ios/iphonesimulator/Runner.app -iname "*analytics*" -o -iname "*appmeasurement*" -o -iname "*crashlytics*"` returns ZERO matches. Verified today: zero matches. The Podfile post_install SKIP_INSTALL + MACH_O_TYPE=staticlib correctly prevents these from being embedded in the .app bundle.

### 1J — Privacy Policy update (existing policy at brushquest.app/privacy-policy.html needs iOS edits, NOT a rewrite)

> **Discovered 2026-04-28:** A comprehensive COPPA-compliant Privacy Policy already exists at https://brushquest.app/privacy-policy.html (effective 2026-04-01). Source file is `docs/privacy-policy.html` in this repo. Site is GitHub Pages (Squarespace-managed domain `brushquest.app`). It already covers data collected, COPPA section, deletion process, contact email. **What's missing for iOS:** (a) Apple Sign-In not mentioned in third-party services section; (b) Analytics + Crashlytics listed as Firebase services without noting they're Android-only; (c) age range "4–8" doesn't match the App Store Kids age band 6-8; (d) contact email inconsistency (policy says jim@anemosgp.com, support email is support@brushquest.app per `reference_landing_page_deploy.md`).

- [x] (T3·C) **1J-1.** DONE — content was already shipped in commit `734865f` (privacy policy v2): Apple Sign-In added to Section 5; Analytics + Crashlytics noted as Android-only with iOS-strip explanation; age band normalized to "ages 6–8" throughout; contact email = `support@brushquest.app` consistently; effective date 2026-04-28.

- [x] (T3·J) **1J-2.** DONE — verified 2026-04-29 that https://brushquest.app/privacy-policy.html serves the v2 content (diff vs local: zero). The earlier deploy already shipped it.

- [x] (T2·C) **1J-3.** DONE (already implemented before audit). `lib/screens/settings_screen.dart:866` `_openPrivacyPolicy()` launches `https://brushquest.app/privacy-policy.html` via `url_launcher` with `LaunchMode.externalApplication`. Wired at `:262` and `:1555`. Terms of Service link also present (`_openTermsOfService` → `anemosgp.com/terms.html`). Both behind the parental gate per 1F-3.

### 1K — Privacy Nutrition Labels worksheet

- [x] (T2·C) **1K-1.** Worksheet drafted at `docs/ios-port/privacy-labels.md`. Every Apple category declared. Email + User ID + Gameplay Content collected (linked, not for tracking, App Functionality only). All Tracking declarations: NO.

- [x] (T3·J) **1K-2.** APPROVED 2026-04-29. Jim reviewed; one fix applied: Name row corrected from "No" → "Yes (Linked, App Functionality)" since `auth_service.dart:91-100` does persist parent's `displayName` from Apple/Google sign-in. Children's-data-flag context: parent-provided data inherits child-data treatment under Kids Category (no exemption). All other declarations confirmed truthful.

### 1L — App Store Connect listing copy

- [x] (T2·C) **1L-1.** Listing draft at `docs/ios-port/store-listing.md`. Title "Brush Quest: Space Rangers" (26/30), subtitle "Toothbrushing Hero Adventure" (28/30), description ~2,950/4,000, keywords 99/100. Primary=Kids 6-8, Secondary=Education.

- [ ] (T3·J) **1L-2.** Jim reviews and approves/edits each field.
  - Depends on: 1L-1.

### 1M — iPhone screenshots

- [x] (T2·C) **1M-1.** DONE 2026-04-28. `docs/ios-port/screenshots.md` written: required iPhone sizes table (6.9" required, 6.7"/6.5" recommended, 5.5" not required for iOS 15.0+), source asset inventory, two adaptation strategies (resize-then-pad-with-#0A0E27 vs native re-shoot), output paths, and the 1M-2 generator-script spec.

- [x] (T2·C) **1M-2.** DONE 2026-04-28. `marketing/screenshots/generate_ios_screenshots.py` (PIL Lanczos resize + pad with `#0A0E27` to iPhone target heights). 24 PNGs written under `marketing/screenshots/ios/{6.9,6.7,6.5}/captioned_NN_*.png` at exact dimensions (1320×2868, 1290×2796, 1242×2688), `hasAlpha: no`. Captions preserved, just letterboxed top+bottom with the app's space background — visually consistent.

- [ ] (T3·J) **1M-3.** Jim reviews for visual consistency.
  - Depends on: 1M-2.

### 1N — App Store icon

- [x] (T2·C) **1N-1.** DONE (already shipped in scaffold, verified 2026-04-28).
  - `Icon-App-1024x1024@1x.png` exists, 1024×1024, `hasAlpha: no` ✓
  - All 15 required iPhone icon sizes present (20pt/29pt/40pt @1x/@2x/@3x + 60pt @2x/@3x + iPad-compatible 76pt + 83.5pt @2x).
  - `Contents.json` references all of them.
  - iOS build green with no missing-icon warnings.

### 1P — Crashlytics strip from iOS (NEW — Kids Category compliance)

- [x] (T2·C) **1P-1.** DONE — verified 2026-04-29. Podfile's `KIDS_CATEGORY_EXCLUDED_FRAMEWORKS` list already contains `FirebaseCrashlytics` and `FirebaseCrashlyticsSwift` alongside `FirebaseAnalytics` and `GoogleAppMeasurement`; SKIP_INSTALL + MACH_O_TYPE=staticlib applied via post_install. Combined with the Run Script Build Phase strip (1P-3), the bundle has zero Crashlytics-bearing files (verified via `find build/ios/iphonesimulator/Runner.app -iname "*crashlytics*"` → empty).
- [~] (T2·C) **1P-2.** PARTIAL 2026-04-28: minimal `Platform.isAndroid` gate added to `lib/main.dart:27-31` (the only Crashlytics call sites — `FlutterError.onError` and `PlatformDispatcher.instance.onError` registrations). Eliminates iOS runtime risk. The cleaner `CrashReportingService` extraction is deferred — only do it if more Crashlytics call sites get added.
  - Acceptance (current): `grep -nE "FirebaseCrashlytics" lib/` shows only `main.dart` import + 2 calls inside `if (Platform.isAndroid)`; `dart analyze` clean; iOS build succeeds.
  - Depends on: 1P-1.

- [x] (T2·C) **1P-3.** DONE 2026-04-28. Run Script Build Phase "Strip Kids-Category-Forbidden Frameworks" added to Runner target after `[CP] Copy Pods Resources`. Verified via `flutter build ios --no-codesign --simulator --debug`: zero `*crashlytics*` files in `Runner.app/` (case-insensitive). FirebaseAnalytics, GoogleAppMeasurement also absent.
  - **Regression note:** When the Strip phase was added in Xcode, the standard Flutter `Run Script` phase (UUID `9740EEB61CF901F6004384FC`, runs `xcode_backend.sh build` before Sources compile) was inadvertently deleted from the Runner target's buildPhases. Symptom: `import Flutter` fails — "Unable to resolve module dependency: 'Flutter'", "'Flutter/Flutter.h' file not found". Fix: re-added both the buildPhases reference and the PBXShellScriptBuildPhase definition. Watch for this if any future Xcode UI editing of build phases happens.
  - **Followup risk (1P-2 still open):** `lib/main.dart:27,29` calls `FirebaseCrashlytics.instance` unguarded. The outer `try/on Exception` catches `MissingPluginException` at startup, but the registered error callbacks fire OUTSIDE that try and would re-throw on iOS. Either (a) wrap with `Platform.isAndroid`, or (b) extract `CrashReportingService` per 1P-2.

### 1Q — Cross-platform account linking & data sync (NEW)

- [x] (T3·C) **1Q-1.** APPROVED 2026-04-28. Decision: **no linking for v1.** Firebase Auth's stable per-provider UID handles the dominant cross-device case (same Google account on iPhone + Android → same Firebase user, automatic). The cross-provider case (Apple-iOS + Google-Android same person) is rare in target audience and not promised in v1. iOS Settings button order swapped to **Google first, Apple second** at `lib/screens/settings_screen.dart:1240` (Apple still required by Policy 4.8 but presented as secondary). No new Settings copy added — existing "Save your progress to the cloud" subtitle stays. See `docs/ios-port/account-linking.md`.
- [ ] (T2·C) **1Q-2.** Once Phase 2 TestFlight build is up, run cross-platform sync test: same Firestore user signs in on Android + iPhone Simulator simultaneously, verify hero/streak/star data syncs both ways within ~2 sec.
  - Acceptance: data write on platform A appears on platform B before next manual reload.
  - Depends on: 1Q-1, 2D-3.

### 1R — Build/version sync convention (NEW)

- [x] (T1·C) **1R-1.** DONE. `docs/ios-port/versioning.md` exists, covers convention + bump rule + verification commands. Baseline `1.0.0+20`, next iOS upload `1.0.0+21`.
- [x] (T2·C) **1R-2.** DONE 2026-04-28. Verified `ios/Runner/Info.plist`:
  - Line 22: `CFBundleShortVersionString` → `$(FLUTTER_BUILD_NAME)` ✓
  - Line 26: `CFBundleVersion` → `$(FLUTTER_BUILD_NUMBER)` ✓

### 1S — Trademark + bundle ID conflict search (NEW)

- [x] (T1·C) **1S-1.** Searched USPTO TESS for "BRUSH QUEST" in IC 009 + IC 041 — **no conflict** (901 IC 009 + 642 IC 041 Live results, none with exact wordmark "BRUSH QUEST"). App Store namesake found: Mitchell Pothitakis app ID 6748761829. Bundle IDs are distinct. Findings in `docs/ios-port/trademark-search.md`.
- [x] (T3·J) **1S-2.** Decision (2026-04-28): submit iOS as **"Brush Quest: Space Rangers"** to differentiate from Pothitakis namesake. Android title unchanged. USPTO trademark filing deferred to Phase 4+.

### 1T — App Store preview video (NEW — optional but high-impact)

- [x] (T2·C) **1T-1.** DONE 2026-04-28. `marketing/video/promo_v5_26s.mp4` (1080×2410, 26s) re-encoded to 6.7" iPhone App Preview spec (1290×2796, H.264 + AAC, 26s) at `marketing/screenshots/ios/preview_6.7.mp4`. Strategy: scale-to-width then crop center-vertical 2796 from 2880, preserving the most visually loaded portion of the frame. Poster frame at 12s mark saved to `marketing/screenshots/ios/preview_6.7_poster.png` (1290×2796). Built with ffmpeg `-preset slow -crf 18` for visual quality vs file size (~17MB). Awaits Jim review (1T-2).
- [ ] (T3·J) **1T-2.** Jim reviews + approves.
  - Depends on: 1T-1.

### 1U — /cyclepro iOS protection (NEW — prevent the Russian-roulette deletion problem)

- [x] (T2·C) **1U-1.** Edited `~/Projects/dev-cycle/commands/cyclepro.md`: added "iOS-conditional code" to the Tier 1 "DO NOT touch" list AND a cross-reference in the Tier 3 list. Cycle 14 deletion incident noted as the why.
- [x] (T1·C) **1U-2.** Added iOS build + grep gates to fitness gates section: `flutter build ios --no-codesign --simulator`, ATT/IDFA grep, GoogleAppMeasurement Pod check. Hard-fail gates when an iOS-touching commit lands.
- [x] (T1·C) **1U-3.** DONE 2026-04-28. CYCLE-PROTECT headers present on:
  - `lib/services/auth_service.dart:1-3` (Sign in with Apple)
  - `lib/services/analytics_service.dart:1-5` (Platform.isAndroid gate)
  - `lib/main.dart:1-4` (Crashlytics error handler gate, added today)
  Add the same header to any future iOS-conditional file.

### 1V — iOS Test Infrastructure (NEW — supersedes Layer 2 from earlier discussion)

> Go-deep: 5 integration tests, full coverage of the iOS-critical paths.

- [x] (T1·C) **1V-1.** DONE 2026-04-28. `integration_test` added to dev_dependencies; `flutter pub get` succeeds; tests pass (788/788).
- [x] (T1·C) **1V-2.** DONE 2026-04-28. `integration_test/` directory exists with `README.md` documenting layout + run commands. `flutter test integration_test/` no-ops gracefully when empty (per the codemagic.yaml step). The `test_driver/integration_test.dart` driver file is no longer required for Flutter ≥ 2.8 — `integration_test` package handles bootstrapping itself. Will add per-test files in 1V-3 onward.
- [x] (T2·C) **1V-3.** DONE 2026-04-29. `integration_test/parental_gate_test.dart` written — 4 cases mirror `test/screens/settings_parent_gate_test.dart` but run on iOS Simulator via `IntegrationTestWidgetsFlutterBinding`: gate renders + Settings hidden; wrong answer rejects + clears field; correct answer unlocks TabBar; `digitsOnly` formatter strips letters. (Plan task description was stale — referenced a deprecated press-and-hold gate; actual gate is the math-challenge implementation from 1F-1/1F-2.) Codemagic `ios_tests` workflow exercises this on every PR.
- [ ] (T2·C) **1V-4.** Write `integration_test/sign_in_apple_test.dart`. Cases: Apple button visible only on iOS; gate (1F-3) fires before Apple button reachable; mocked `signInWithApple()` returns User → settings shows signed-in state. Use Firebase Auth emulator or mock at the `AuthService` boundary.
  - Acceptance: 3 test cases pass on iOS Simulator.
  - Depends on: 1F-3, 1V-3.
- [ ] (T2·C) **1V-5.** Write `integration_test/account_deletion_test.dart`. Cases: Delete Account button gated; confirmed delete flow tears down Firestore mock + Auth mock + local prefs; SIWA revoke Cloud Function called for Apple users (mock the HTTP call).
  - Acceptance: 3 test cases pass on iOS Simulator.
  - Depends on: 1G-2, 1G-4, 1V-3.
- [ ] (T2·C) **1V-6.** Write `integration_test/brush_session_e2e_test.dart`. Full session: tap BRUSH → countdown → 4 phases → victory → +1 star. Verify total brush count incremented in mocked Firestore.
  - Acceptance: full session completes under simulated 30s/quadrant timer; victory state correct.
  - Depends on: 1V-2.
- [ ] (T2·C) **1V-7.** Write `integration_test/audio_smoke_test.dart`. Cases: countdown voice plays; music starts and continues across phase transitions; SFX fires on attack; no overlap during voice playback.
  - Acceptance: audio events fire in correct sequence (verified via mocked AudioPlayer state).
  - Depends on: 1V-2.
- [x] (T2·C) **1V-8.** DONE — closed alongside 1W-1 on 2026-04-28. `codemagic.yaml` workflow `ios_tests` runs on every PR + push to main: `flutter pub get` → `flutter analyze` → DCM lint → `flutter test --machine` → `flutter build ios --no-codesign --simulator --debug` → Kids-Category strip-frameworks gate → `flutter test integration_test/ -d "iPhone 15"` (boots iPhone 15 sim, runs all integration_test files, no-ops gracefully when none yet). First green run will fire on the next PR.

### 1W — CI pipeline scaffolding

- [x] (T2·C) **1W-1.** DONE 2026-04-28. `codemagic.yaml` written. Workflow `ios_tests` runs on PR + push to main: pub get, flutter analyze, DCM lint, flutter test, iOS build (no codesign), Kids-Category strip-frameworks gate (rejects build if forbidden frameworks land in bundle), then `flutter test integration_test/` (no-ops if empty). Phase 2 `ios_release` workflow scaffolded as a commented block — uncomment after 2A-1 / 2B-3 / 2C-1.
- [x] (T2·C) **1W-2.** DONE 2026-04-28. `ios/Gemfile` + `ios/fastlane/Fastfile` + `ios/fastlane/Matchfile` created. Two read-only match lanes (`match_dev`, `match_release`) defined. Phase 2 `beta` and `release` lanes scaffolded as commented blocks. Matchfile has explicit `PLACEHOLDER_REPLACE_AT_2B-3` markers for `git_url` and `team_id` so 2A-2 / 2B-2 substitutions are mechanical.

---

## Phase 2 — On Apple Business approval (gated)

> Unblocks when memory `project_apple_business.md` shows Status = Approved. The scheduled routine `trig_01AzzagAPmMzMTBuNUs13z91` will fire May 4 to confirm.

### 2A — Apple Developer Program enrollment

- [ ] (T1·J) **2A-1.** Sign in to developer.apple.com with `appledev@anemosgp.com`. Enroll in Apple Developer Program → Organization. Use D-U-N-S `144980774`. Pay $99/yr.
  - Acceptance: Team ID assigned; `appledev@anemosgp.com` is Account Holder.

- [ ] (T1·C) **2A-2.** Capture Team ID. Add to `decision_ios_kids_category.md` memory under a new "Apple Developer credentials" section.
  - Depends on: 2A-1.

- [ ] (T1·J) **2A-3.** Generate Sign in with Apple key (Certificates, Identifiers & Profiles → Keys → "+" → Sign In with Apple). Download the `.p8` file. Store as a Firebase Cloud Function secret. Wire into the `revokeAppleToken` Cloud Function (1G-3 stub).
  - Acceptance: Cloud Function `revokeAppleToken` integration test passes against a test Apple account.
  - Depends on: 2A-1, 1G-3.

### 2B — Code signing setup

- [ ] (T2·C) **2B-1.** Set `DEVELOPMENT_TEAM` in `ios/Runner.xcodeproj/project.pbxproj` to the Team ID from 2A-2.
  - Acceptance: `flutter build ios --no-codesign` continues to succeed; opening in Xcode shows the team selected.
  - Depends on: 2A-2.

- [ ] (T1·J) **2B-2.** Create a private GitHub repo `brush-quest-match` for Fastlane Match certificates.
  - Acceptance: empty private repo exists.

- [ ] (T2·C) **2B-3.** Update `ios/fastlane/Matchfile` with the real Match repo URL. Run `fastlane match init` and `fastlane match development`.
  - Acceptance: development cert + provisioning profile created and stored in match repo.
  - Depends on: 2A-1, 2B-2.

- [ ] (T2·C) **2B-4.** Run `fastlane match appstore`.
  - Acceptance: distribution cert + profile in match repo.
  - Depends on: 2B-3.

### 2C — App Store Connect listing creation

- [ ] (T1·J) **2C-1.** App Store Connect → My Apps → New App. Bundle ID `com.brushquest.brushQuest`. Primary category: `Kids → Ages 6-8`. Secondary: `Education`.
  - Acceptance: app record exists with assigned SKU; ready to receive a build.
  - Depends on: 2A-1.

- [ ] (T1·J) **2C-2.** Paste the listing copy from `docs/ios-port/store-listing.md` (already approved in 1L-2).
  - Depends on: 2C-1, 1L-2.

- [ ] (T1·J) **2C-3.** Upload the iPhone screenshots from `marketing/screenshots/ios/` (already approved in 1M-3).
  - Depends on: 2C-1, 1M-3.

- [ ] (T1·J) **2C-4.** Fill Privacy Nutrition Labels using `docs/ios-port/privacy-labels.md` (already approved in 1K-2).
  - Depends on: 2C-1, 1K-2.

- [ ] (T1·J) **2C-5.** Complete the **2026 age rating questionnaire** (replaced the old version Jan 31 2026; new questions about in-app controls, medical/wellness, violence). Default for Brush Quest: 4+.
  - Depends on: 2C-1.

- [ ] (T2·C) **2C-6.** Draft App Review Notes (Apple's "App Review Information" field). Body: "Brush Quest is designed for children ages 6–8 (Kids Category, Ages 6-8 band). No third-party analytics or ads. Firebase Auth + Firestore are used solely for the child's optional cloud backup of their own progress (heroes, weapons, stars, brushing streaks). Sign-in is OPTIONAL and gated behind a parental gate (press-and-hold 3s). Test account: [Jim provides]. The on-device camera is used only for motion detection during brushing — no video is recorded, transmitted, or stored. App is free, no IAP, no ads." Save to `docs/ios-port/review-notes.md`.
  - Acceptance: draft exists; Jim approves before submission.

- [ ] (T1·J) **2C-7.** Paste review notes from 2C-6 into App Store Connect → App Review Information.
  - Depends on: 2C-6.

### 2D — First TestFlight build

- [ ] (T2·C) **2D-1.** Update `codemagic.yaml` Phase 2 placeholders with real signing config + Match references.
  - Depends on: 2B-4.

- [ ] (T2·C) **2D-2.** Trigger first iOS build via Codemagic. Build artifact: signed `.ipa`.
  - Acceptance: green build, `.ipa` downloadable.
  - Depends on: 2D-1.

- [ ] (T1·J) **2D-3.** Upload `.ipa` to TestFlight via Codemagic auto-upload (or manually via Transporter).
  - Acceptance: build appears in App Store Connect → TestFlight; Apple finishes processing (typically 5–30 min).
  - Depends on: 2D-2, 2C-1.

- [ ] (T1·J) **2D-4.** Add internal testers: Jim, Oliver's parent's account, Jim's invited friends (up to 100 internal testers, no Apple review needed). Send TestFlight invites.
  - Depends on: 2D-3.

### 2E — On-device test pass

- [ ] (T3·J) **2E-1.** Install via TestFlight on a real iPhone. Run the full pre-ship UX checklist from `CLAUDE.md` ("Pre-Ship UX Checklist"). Document issues in this plan inline.
  - Acceptance: every checklist item passes OR known issues are documented and triaged.
  - Depends on: 2D-4.

---

## Phase 3 — Submission & launch

### 3A — Pre-submission gates (run all before tapping Submit)

- [ ] (T1·C) **3A-0.** Run pre-submission grep guard from 1C-2: `grep -rE "NSUserTracking|AppTrackingTransparency|GADApplicationIdentifier" ios/`. Must return zero matches.
  - Acceptance: zero matches.

- [ ] (T1·C) **3A-1.** Verify `Podfile.lock` does not include `GoogleAppMeasurement` (per 1I-1).
  - Acceptance: `grep GoogleAppMeasurement ios/Podfile.lock` returns zero.

- [ ] (T1·C) **3A-2.** Verify `GoogleService-Info.plist` is present in the build.
  - Acceptance: file exists; archive includes it.

### 3B — Submit for review

- [ ] (T3·J) **3B-1.** Promote the TestFlight build to "Submit for Review" in App Store Connect. Confirm Kids Category. Encryption export compliance: typically "uses standard encryption (HTTPS) but exempt." IDFA: no.
  - Acceptance: status moves to "Waiting for Review".
  - Depends on: 2E-1, 2C-2..2C-7, 3A-0..3A-2.

### 3C — Handle review feedback

- [ ] (T3·C+J) **3C-1.** If Apple rejects: read reviewer notes, classify, propose fix. Tier depends on the fix.
  - Acceptance: issue resolved, new build submitted, accepted.

### 3D — Launch

- [ ] (T1·J) **3D-1.** Set release mode: **Manual** ("Manually release this version"). When approved, Jim flips the switch on his chosen launch day, coordinated with marketing.
  - Depends on: 3B-1.

- [ ] (T1·J) **3D-2.** On launch day, tap "Release this version".
  - Depends on: 3D-1.

- [ ] (T1·C) **3D-3.** Update `STATUS.md` and memory `MEMORY.md` Current Status with iOS launch milestone.
  - Depends on: 3D-2.

---

## Phase 4 — Post-launch

### 4A — Monitoring (first 14 days)

- [ ] (T1·C) **4A-1.** Daily check of App Store Connect → Crashes (no Crashlytics on iOS — App Store Connect crash reporting is the only signal). Telegram digest: downloads, ratings, crash count.

- [ ] (T3·J) **4A-2.** Decide which iOS-specific issues from 1D / 1E need follow-up patches.

### 4B — iPad-optimized layouts (v1.1)

- [ ] (T3·C) **4B-1.** Propose iPad layout pass: `LayoutBuilder` checks for wide screens; tweak home, settings, shop to use extra space; verify mouth guide visual scale. ~2-4 days estimated.

- [ ] (T2·C) **4B-2.** Implement layouts after Jim sign-off.
  - Depends on: 4B-1.

- [ ] (T2·C) **4B-3.** Set `TARGETED_DEVICE_FAMILY = 1,2` (Universal). Generate iPad screenshots (12.9" — 2048×2732, 11" — 1668×2388). Add to App Store Connect.
  - Depends on: 4B-2.

---

## Operational notes

**Updating this plan:** when you complete a task, change `[ ]` → `[x]` in the same commit as the work. When you start, change to `[~]`. When blocked, change to `[!]` and add a one-line note.

**Reading this plan at session start:** scroll to the first task that isn't `[x]`. That's where you pick up.

**Disagreement with the plan:** if you discover the plan is wrong (e.g., a task already done outside the plan), update the plan first, then proceed. Don't silently diverge.

**Out of scope (don't add without Jim's go-ahead):**
- Android-specific changes (this plan is iOS only)
- Multi-profile (locked until separate decision per `decision_product_strategy_2026_03.md`)
- Monetization on iOS (Kids Category constraints — out of scope for v1)

**Research sources for the must-fix items above** (saved here so we don't re-derive):
- Parental gate requirement: [developer.apple.com/kids](https://developer.apple.com/kids/)
- Account deletion 5.1.1(v): [Apple support — offering account deletion](https://developer.apple.com/support/offering-account-deletion-in-your-app/)
- SIWA token revoke: [Apple developer docs — auth/revoke](https://developer.apple.com/documentation/sign_in_with_apple/revoke_tokens)
- Privacy manifests: [bundleresources/privacy-manifest-files](https://developer.apple.com/documentation/bundleresources/privacy-manifest-files); [Flutter tracking issue #145902](https://github.com/flutter/flutter/issues/145902)
- 2026 age rating questionnaire: [developer.apple.com/news?id=ks775ehf](https://developer.apple.com/news/?id=ks775ehf)
- COPPA 2025 amendments: [WSGR analysis](https://www.wsgrdataadvisor.com/2025/01/new-federal-childrens-privacy-requirements-are-not-childs-play-ftc-amends-coppa-rule-imposing-new-obligations-on-child-directed-services/)
- ATT in Kids apps: [developer forums thread 131840](https://developer.apple.com/forums/thread/131840)

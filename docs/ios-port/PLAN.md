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

- [ ] (T1·J) **0-1.** Install Xcode from Mac App Store (~50 GB, 1–2 hr download). Either run `sudo mas install 497799835` in terminal, or open App Store → search "Xcode" → Get.
  - Acceptance: `xcodebuild -version` returns a real version; `xcode-select -p` returns `/Applications/Xcode.app/Contents/Developer`.
- [ ] (T1·J) **0-2.** After Xcode install: open it once to accept the GUI license dialog. Then run in terminal:
    ```
    sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
    sudo xcodebuild -license accept
    sudo xcodebuild -runFirstLaunch
    ```
  - Acceptance: `xcode-select -p` returns `/Applications/Xcode.app/Contents/Developer`; `xcrun simctl list devices` returns iPhone simulators.
  - Depends on: 0-1 (Xcode.app exists at /Applications/Xcode.app — confirmed 2026-04-28).
- [ ] (T1·C) **0-3.** Run `flutter doctor`. Confirm iOS toolchain reports green.
  - Acceptance: `flutter doctor` shows iOS section ✓ (or only known-acceptable warnings).
  - Depends on: 0-2.

---

## Pre-flight: already done (do not redo)

- [x] iOS scaffold exists at `ios/Runner.xcodeproj` (bundle `com.brushquest.brushQuest`)
- [x] `sign_in_with_apple: ^6.1.0` and `crypto: ^3.0.6` in `pubspec.yaml`
- [x] `AuthService.signInWithApple()` fully implemented in `lib/services/auth_service.dart` (SHA-256 nonce, name persistence, Hide-my-Email handling)
- [x] Apple button wired in `lib/screens/settings_screen.dart:1242`, gated by `AuthService().isAppleSignInAvailable` (iOS only)
- [x] `com.apple.developer.applesignin` capability in `ios/Runner/Runner.entitlements`
- [x] `AnalyticsService` runtime-gated with `Platform.isAndroid` in `lib/services/analytics_service.dart` — every log method early-returns on iOS
- [x] Apple Business org enrollment submitted (Apr 17, 2026), case `102880286319`, awaiting verification (ETA Mon May 4)

---

## Phase 1 — Pre-approval (do now, in parallel with Apple Business wait)

> All Phase 1 tasks proceed today. None require the Apple Developer Program.

### 1A — iOS code & build setup

- [x] (T1·C) **1A-1.** Updated `lib/services/analytics_service.dart` comment block to reflect the *permanent* Kids Category decision. Done 2026-04-28; `dart analyze` clean.

- [ ] (T1·C) **1A-2.** Run `flutter pub get` to generate `ios/Podfile` and `ios/Podfile.lock`.
  - Acceptance: `ios/Podfile` exists; `flutter analyze` clean.

- [ ] (T2·C) **1A-3.** Add `post_install` hook to `ios/Podfile` excluding `FirebaseAnalytics` and `GoogleAppMeasurement` frameworks from the iOS build.
  - Acceptance: `flutter build ios --no-codesign` succeeds; `find build/ios -name "*.framework"` does NOT include `FirebaseAnalytics.framework` or `GoogleAppMeasurement.framework`.
  - Depends on: 1A-2.

- [ ] (T2·C) **1A-4.** Set `TARGETED_DEVICE_FAMILY = 1` in `ios/Runner.xcodeproj/project.pbxproj` (iPhone-only for v1; v1.1 will add iPad-optimized layouts).
  - Acceptance: build setting reflects `1` (iPhone), not `1,2` (Universal).

- [ ] (T1·C) **1A-5.** Run `flutter analyze`. Fix any iOS-only warnings.
  - Acceptance: zero analyzer issues.
  - Depends on: 1A-2.

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

- [ ] (T2·C) **1C-1.** Audit `ios/Runner/Info.plist`. Add:
  - `NSCameraUsageDescription` — "Brush Quest uses the front camera to detect brushing motion. Video is processed on-device only and never recorded or sent anywhere."
  - `NSMicrophoneUsageDescription` — only if camera plugin demands it (iOS sometimes pulls this transitively).
  - `UIBackgroundModes` → `audio` — so battle music survives screen-blank during brushing.
  - **VERIFY ABSENT:** `NSUserTrackingUsageDescription` (any presence = ATT prompt = automatic Kids Category rejection).
  - **VERIFY ABSENT:** `GADApplicationIdentifier` (Google Ads identifier, must not be present).
  - Acceptance: required keys present; forbidden keys absent; `flutter build ios --no-codesign` succeeds without missing-key errors.
  - Depends on: 1A-3.

- [ ] (T1·C) **1C-2.** Add a one-shot grep guard to documentation: `grep -rE "NSUserTracking|AppTrackingTransparency|GADApplicationIdentifier" ios/` must return zero. Document this command in this plan as a pre-submission check (referenced from 3A-0).
  - Acceptance: command returns zero matches; recorded as a Phase 3 gate.

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
- [ ] (T2·C) **1F-4.** Audit every other code path that opens an external URL, sends an email, or starts an account-creation flow OUTSIDE settings_screen.dart. Verify each is also gated. Likely surfaces to inspect: any "rate the app" link, "share with friend" link, in-app credits/about screen.
  - Acceptance: written audit in `docs/ios-port/parental-gate-audit.md` listing every gated surface and its gating mechanism; any unprotected surface gets a follow-up task.
- [ ] (T2·C) **1F-5.** Add a widget test for the math gate (`test/screens/settings_parent_gate_test.dart`): wrong answer rejects + retries; correct answer unlocks; cancel exits Settings. Use `_mathController` programmatically.
  - Acceptance: test file exists, 3+ test cases pass.

### 1G — In-app Account Deletion (NEW — Guideline 5.1.1(v) hard requirement)

- [ ] (T3·C) **1G-1.** Propose UX: "Delete Account" button in Settings → Account section, behind parental gate (1F-3). Confirmation step ("This will permanently delete your hero progress and stars. Are you sure?"). Required to be reachable in-app, NOT routed to email/support.
  - Acceptance: written proposal; Jim approves.

- [ ] (T2·C) **1G-2.** Add `deleteAccount()` to `AuthService`. Steps: (1) call SIWA token revoke Cloud Function (1G-3) for Apple users; (2) delete `/users/{uid}` Firestore doc; (3) call `FirebaseAuth.deleteUser()`; (4) clear local `shared_preferences`.
  - Acceptance: method exists, fully tested with mocks; Tier 3 sign-off from Jim.
  - Depends on: 1G-1, 1G-3.

- [ ] (T2·C) **1G-3.** Create Firebase Cloud Function `revokeAppleToken` that calls Apple's `https://appleid.apple.com/auth/revoke` endpoint with the SIWA private key. (Required by Apple — Firebase `deleteUser()` does NOT revoke the SIWA refresh token.) Store the Apple key as a Cloud Function secret.
  - Acceptance: Cloud Function deployed to Firebase; integration test with a test Apple account succeeds; revocation returns HTTP 200.
  - Depends on: 2A-1 (need Apple Developer Program for the Apple key) — **so this task is partially Phase 2.** Stub it in Phase 1 with TODO; finish in Phase 2.

- [ ] (T2·C) **1G-4.** Wire "Delete Account" button in Settings UI behind parental gate.
  - Acceptance: button present, calls `deleteAccount()`, shows progress + completion state.
  - Depends on: 1G-2, 1F-3.

### 1H — PrivacyInfo.xcprivacy manifest audit (NEW — hard upload rejection if missing)

- [x] (T2·C) **1H-1.** Audit complete — `docs/ios-port/privacy-manifest-audit.md`. 9/15 iOS plugins ship a manifest; 1 needs a fix (`audioplayers_darwin 6.3.0` ships none); 5 are not on Apple's required list; Firebase pods bring their own.

- [ ] (T2·C) **1H-2.** For any plugin without a manifest, bump to a version that has one. If no such version exists, document the workaround (fork, vendor, or replace).
  - Acceptance: `flutter pub get` succeeds; pubspec updated; audit document marks every entry resolved.
  - Depends on: 1H-1.

- [ ] (T2·C) **1H-3.** Create the **app-level** `PrivacyInfo.xcprivacy` at `ios/Runner/PrivacyInfo.xcprivacy`. Declare: NSPrivacyTracking = false; NSPrivacyTrackingDomains = empty; NSPrivacyAccessedAPITypes for any required-reason API used (file timestamps, system boot time, disk space, user defaults — Flutter framework typically requires these).
  - Acceptance: file exists; `flutter build ios --no-codesign` succeeds; xcrun reports no ITMS-91061 warnings on a test archive.
  - Depends on: 1H-2.

### 1I — Firebase Auth/Firestore Pod audit (NEW — Kids Category transitive deps)

- [ ] (T2·C) **1I-1.** After Pods are installed (post 1A-2), `cd ios && pod install` then run `pod deintegrate && pod install` once. Inspect `Podfile.lock` for any pod containing `GoogleAppMeasurement`, `GoogleAds`, `FirebaseAnalytics`, `FirebaseRemoteConfig` as a transitive dep of `firebase_auth` or `cloud_firestore`. Pin pod versions to the latest known-good versions that exclude these.
  - Acceptance: `Podfile.lock` does NOT include `GoogleAppMeasurement` after the post_install hook (1A-3) executes.
  - Depends on: 1A-3.

### 1J — Privacy Policy update (existing policy at brushquest.app/privacy-policy.html needs iOS edits, NOT a rewrite)

> **Discovered 2026-04-28:** A comprehensive COPPA-compliant Privacy Policy already exists at https://brushquest.app/privacy-policy.html (effective 2026-04-01). Source file is `docs/privacy-policy.html` in this repo. Site is GitHub Pages (Squarespace-managed domain `brushquest.app`). It already covers data collected, COPPA section, deletion process, contact email. **What's missing for iOS:** (a) Apple Sign-In not mentioned in third-party services section; (b) Analytics + Crashlytics listed as Firebase services without noting they're Android-only; (c) age range "4–8" doesn't match the App Store Kids age band 6-8; (d) contact email inconsistency (policy says jim@anemosgp.com, support email is support@brushquest.app per `reference_landing_page_deploy.md`).

- [ ] (T3·C) **1J-1.** Edit `docs/privacy-policy.html`:
  - Section 5 (Third-Party Services): add Apple Sign-In as a service used on iOS only, link to Apple's privacy policy.
  - Section 5: note that Firebase Analytics + Crashlytics are present on Android only (stripped from iOS binary for Kids Category compliance).
  - Section 6 (COPPA): change "ages 4–8" → "ages 6–8" to align with App Store Kids age band. (Or keep 4–8 and explain the 6-8 App Store band is the closest available — Jim decides.)
  - Contact email block: pick one — `support@brushquest.app` (recommended, customer-facing) or `privacy@brushquest.app` (privacy-specific) or `jim@anemosgp.com` (legacy). Use the same address consistently throughout the policy.
  - Bump effective date to today.
  - Acceptance: edits drafted in a PR or branch; Jim reviews before pushing to main.

- [ ] (T3·J) **1J-2.** After 1J-1 approval: deploy to brushquest.app via the deploy workflow in `reference_landing_page_deploy.md` (merge branch → main, push). Verify https://brushquest.app/privacy-policy.html serves the new content.
  - Acceptance: live URL returns 200 with new content; cache-busting confirmed.
  - Depends on: 1J-1.

- [ ] (T2·C) **1J-3.** Add a "Privacy Policy" link in Settings (in-app), opening `https://brushquest.app/privacy-policy.html` via `url_launcher` (Safari View Controller on iOS). Apple reviewers check this is reachable from inside the app, not just the App Store listing.
  - Acceptance: Settings → "Privacy Policy" link present and tappable; verified on iOS Simulator.
  - Depends on: 1J-2.

### 1K — Privacy Nutrition Labels worksheet

- [x] (T2·C) **1K-1.** Worksheet drafted at `docs/ios-port/privacy-labels.md`. Every Apple category declared. Email + User ID + Gameplay Content collected (linked, not for tracking, App Functionality only). All Tracking declarations: NO.

- [ ] (T3·J) **1K-2.** Jim reviews `privacy-labels.md`, confirms or corrects each entry.
  - Depends on: 1K-1.

### 1L — App Store Connect listing copy

- [x] (T2·C) **1L-1.** Listing draft at `docs/ios-port/store-listing.md`. Title "Brush Quest: Space Rangers" (26/30), subtitle "Toothbrushing Hero Adventure" (28/30), description ~2,950/4,000, keywords 99/100. Primary=Kids 6-8, Secondary=Education.

- [ ] (T3·J) **1L-2.** Jim reviews and approves/edits each field.
  - Depends on: 1L-1.

### 1M — iPhone screenshots

- [ ] (T2·C) **1M-1.** Create `docs/ios-port/screenshots.md`: required iPhone screenshot sizes (6.9" — 1320×2868, 6.7" — 1290×2796, 6.5" — 1242×2688, 5.5" — 1242×2208), the 8 captioned Play Store screenshots already in `marketing/screenshots/`, and a mapping of which adapt to which iPhone size.
  - Acceptance: file exists with size table + adaptation map.

- [ ] (T2·C) **1M-2.** Generate iPhone-aspect-ratio versions of the 8 captioned screenshots into `marketing/screenshots/ios/`. Maintain caption styling.
  - Acceptance: 8 screenshots × required sizes, all at exact pixel dimensions.
  - Depends on: 1M-1.

- [ ] (T3·J) **1M-3.** Jim reviews for visual consistency.
  - Depends on: 1M-2.

### 1N — App Store icon

- [ ] (T2·C) **1N-1.** Generate a 1024×1024 App Store icon from the existing app icon source. **No transparency, no rounded corners** (Apple rounds them). Save to `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png`. Verify all required sizes exist (20pt @2x/@3x, 29pt @2x/@3x, 40pt @2x/@3x, 60pt @2x/@3x).
  - Acceptance: every required size populated; `flutter build ios --no-codesign` doesn't warn about missing icons.

### 1P — Crashlytics strip from iOS (NEW — Kids Category compliance)

- [ ] (T2·C) **1P-1.** Add `FirebaseCrashlytics` and `FirebaseCrashlyticsSwift` to the Podfile `post_install` hook frameworks-to-exclude (alongside `FirebaseAnalytics` from 1A-3). Result: iOS binary contains zero Google Crashlytics code.
  - Acceptance: `find build/ios -name "FirebaseCrashlytics*"` returns empty after `flutter build ios --no-codesign`.
  - Depends on: 1A-3.
- [ ] (T2·C) **1P-2.** Wrap every `FirebaseCrashlytics` call site in `lib/` with a `Platform.isAndroid` runtime gate. Pattern: extract a `CrashReportingService` singleton mirroring `AnalyticsService`'s shape — every method early-returns on iOS. Replace direct `FirebaseCrashlytics.instance.recordError(...)` calls with `CrashReportingService().recordError(...)`.
  - Acceptance: `grep -nE "FirebaseCrashlytics" lib/` returns ONLY the new service file; all other call sites use the wrapper; `dart analyze` clean.
  - Depends on: 1P-1.

- [ ] (T2·C) **1P-3.** Add a Run Script Build Phase to `ios/Runner.xcodeproj` that physically deletes `Frameworks/FirebaseCrashlytics.framework` from the `.app` bundle pre-signing (only when building for iOS, not when re-using the framework e.g. on macOS). The SKIP_INSTALL hook in 1A-3 stripped Analytics + GoogleAppMeasurement but NOT Crashlytics — so this is the bulletproof fix. Script body: `if [ -d "${TARGET_BUILD_DIR}/${PRODUCT_NAME}.app/Frameworks/FirebaseCrashlytics.framework" ]; then rm -rf "${TARGET_BUILD_DIR}/${PRODUCT_NAME}.app/Frameworks/FirebaseCrashlytics.framework"; fi`. Add to Runner target's "Build Phases" tab, after "Embed Pods Frameworks", named "Strip Kids-Category-Forbidden Frameworks".
  - Acceptance: re-run `flutter build ios --no-codesign --simulator`; `find build/ios/iphonesimulator/Runner.app/Frameworks -name "FirebaseCrashlytics*"` returns empty. Pre-submission gate (3A-2) verifies this.

### 1Q — Cross-platform account linking & data sync (NEW)

- [ ] (T3·C) **1Q-1.** Decide linking model: do we treat Google-on-Android + Apple-on-iOS as the *same Firebase user* (account linking) or separate users (no linking)?
  - Tradeoff: linking requires Firebase `linkWithCredential` flow + email verification UX. No-linking is simpler but loses progress when a kid switches platforms.
  - Recommendation: **No linking for v1.** Every sign-in method = its own Firebase user. Document this in onboarding so parents understand "sign in with the same method on each device for save sync."
  - Acceptance: decision documented in `docs/ios-port/account-linking.md`; Jim approves.
- [ ] (T2·C) **1Q-2.** Once Phase 2 TestFlight build is up, run cross-platform sync test: same Firestore user signs in on Android + iPhone Simulator simultaneously, verify hero/streak/star data syncs both ways within ~2 sec.
  - Acceptance: data write on platform A appears on platform B before next manual reload.
  - Depends on: 1Q-1, 2D-3.

### 1R — Build/version sync convention (NEW)

- [ ] (T1·C) **1R-1.** Document version convention in `docs/ios-port/versioning.md`: pubspec `version: X.Y.Z+N` drives both Android `versionCode = N` AND iOS `CFBundleVersion = N`. Marketing version `X.Y.Z` is shared. Bump rule: `+N` increments on every uploaded build (TestFlight or Play Store), never reused, monotonic across both stores.
  - Acceptance: doc written; current version `1.0.0+20` flagged as the baseline; next iOS upload will be `1.0.0+21`.
- [ ] (T2·C) **1R-2.** Verify `ios/Runner/Info.plist` reads `CFBundleVersion` from the pubspec via Flutter's standard `$(FLUTTER_BUILD_NUMBER)` substitution. (Flutter scaffolds it correctly by default — verify it wasn't customized.)
  - Acceptance: `Info.plist` uses `$(FLUTTER_BUILD_NUMBER)` and `$(FLUTTER_BUILD_NAME)`.

### 1S — Trademark + bundle ID conflict search (NEW)

- [x] (T1·C) **1S-1.** Searched USPTO TESS for "BRUSH QUEST" in IC 009 + IC 041 — **no conflict** (901 IC 009 + 642 IC 041 Live results, none with exact wordmark "BRUSH QUEST"). App Store namesake found: Mitchell Pothitakis app ID 6748761829. Bundle IDs are distinct. Findings in `docs/ios-port/trademark-search.md`.
- [x] (T3·J) **1S-2.** Decision (2026-04-28): submit iOS as **"Brush Quest: Space Rangers"** to differentiate from Pothitakis namesake. Android title unchanged. USPTO trademark filing deferred to Phase 4+.

### 1T — App Store preview video (NEW — optional but high-impact)

- [ ] (T2·C) **1T-1.** Adapt the existing 30s promo video (cut yesterday from the 1:55 screen recording) to App Store preview video specs: 15–30 seconds, MP4 H.264, portrait orientation matching iPhone screenshot size, no subtitles required, audio optional.
  - Acceptance: `marketing/screenshots/ios/preview.mp4` exists at the correct spec; thumbnail frame selected at the most visually striking moment.
  - Depends on: existing promo video at `marketing/video/`.
- [ ] (T3·J) **1T-2.** Jim reviews + approves.
  - Depends on: 1T-1.

### 1U — /cyclepro iOS protection (NEW — prevent the Russian-roulette deletion problem)

- [x] (T2·C) **1U-1.** Edited `~/Projects/dev-cycle/commands/cyclepro.md`: added "iOS-conditional code" to the Tier 1 "DO NOT touch" list AND a cross-reference in the Tier 3 list. Cycle 14 deletion incident noted as the why.
- [x] (T1·C) **1U-2.** Added iOS build + grep gates to fitness gates section: `flutter build ios --no-codesign --simulator`, ATT/IDFA grep, GoogleAppMeasurement Pod check. Hard-fail gates when an iOS-touching commit lands.
- [ ] (T1·C) **1U-3.** Add header comment to `lib/services/auth_service.dart`, `lib/services/analytics_service.dart`, and any future iOS-conditional service:
    ```dart
    // CYCLE-PROTECT: Contains iOS-conditional code. Do not auto-remove
    // "unused" imports, methods, or branches without iOS build verification.
    // See docs/ios-port/PLAN.md.
    ```
  - Acceptance: comment present at top of every iOS-conditional file.

### 1V — iOS Test Infrastructure (NEW — supersedes Layer 2 from earlier discussion)

> Go-deep: 5 integration tests, full coverage of the iOS-critical paths.

- [ ] (T1·C) **1V-1.** Add `integration_test:` to dev_dependencies in `pubspec.yaml` (Flutter ships it; just declare it).
  - Acceptance: `flutter pub get` succeeds; `integration_test/` is the standard location.
- [ ] (T1·C) **1V-2.** Create `integration_test/` directory with `test_driver/integration_test.dart` boilerplate.
  - Acceptance: `flutter test integration_test/` runs (even with no tests yet).
- [ ] (T2·C) **1V-3.** Write `integration_test/parental_gate_test.dart`. Cases: hold-too-short rejects; full 3s hold passes; cancel mid-hold rejects; voiceover instruction plays at start.
  - Acceptance: 4 test cases pass on iOS Simulator.
  - Depends on: 1F-2 (parental gate widget exists), 0-3.
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
- [ ] (T2·C) **1V-8.** Add Codemagic workflow `ios_tests` to `codemagic.yaml`: macOS worker, runs `flutter test` + `flutter test integration_test/ -d "iPhone 15"`. Triggers on every PR.
  - Acceptance: workflow YAML exists; first run is green.
  - Depends on: 1V-3 through 1V-7, 1W-1.

### 1W — CI pipeline scaffolding

- [ ] (T2·C) **1W-1.** Create `codemagic.yaml` at repo root with iOS build workflow placeholders. Signing config marked `# Phase 2: signing`.
  - Acceptance: file exists; syntactically valid; placeholders clearly marked.

- [ ] (T2·C) **1W-2.** Create `ios/fastlane/` with `Fastfile` and `Matchfile` (Match repo URL placeholder).
  - Acceptance: skeleton exists; `bundle install` (if Ruby/bundler ready) succeeds.

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

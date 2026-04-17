# iOS & Cross-Platform Deployment Strategy

> Brush Quest — from Android-only to dual-store automated deployment.
> Created: 2026-04-17

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│                    GitHub Repository                     │
│                  (brush-quest, main branch)              │
│                                                         │
│  ┌─────────┐  ┌───────────┐  ┌──────────┐              │
│  │  lib/   │  │  android/ │  │   ios/   │              │
│  │ (Dart)  │  │           │  │          │              │
│  │ Shared  │  │ fastlane/ │  │ fastlane/│              │
│  │  code   │  │ Fastfile  │  │ Fastfile │              │
│  └────┬────┘  │ Appfile   │  │ Appfile  │              │
│       │       │ service-  │  │ Matchfile│              │
│       │       │ account   │  └─────┬────┘              │
│       │       └─────┬─────┘        │                   │
└───────┼─────────────┼──────────────┼───────────────────┘
        │             │              │
        │      ┌──────┴──────┐  ┌───┴────────────┐
        │      │  CI: Build  │  │  CI: Build     │
        │      │  Android    │  │  iOS           │
        │      │  (Linux)    │  │  (macOS M2)    │
        │      └──────┬──────┘  └───┬────────────┘
        │             │              │
        │      ┌──────┴──────┐  ┌───┴────────────┐
        │      │ flutter     │  │ flutter        │
        │      │ build aab   │  │ build ipa      │
        │      └──────┬──────┘  └───┬────────────┘
        │             │              │
        │      ┌──────┴──────┐  ┌───┴────────────┐
        │      │ fastlane    │  │ fastlane match │
        │      │ internal    │  │ + testflight   │
        │      └──────┬──────┘  └───┬────────────┘
        │             │              │
        │      ┌──────┴──────┐  ┌───┴────────────┐
        │      │ Google Play │  │  TestFlight    │
        │      │ (Internal)  │  │  (Internal)    │
        │      └──────┬──────┘  └───┬────────────┘
        │             │              │
        │      ┌──────┴──────┐  ┌───┴────────────┐
        │      │ Promote to  │  │ Promote to     │
        │      │ Production  │  │ App Store      │
        │      └─────────────┘  └────────────────┘
```

## Deploy Flow (Single Push → Both Stores)

```
  Developer pushes to main (or tags a release)
                    │
                    ▼
        ┌───── CI Triggers ─────┐
        │                       │
        ▼                       ▼
  ┌───────────┐          ┌───────────┐
  │  Android  │          │    iOS    │
  │  Pipeline │          │  Pipeline │
  │           │          │           │
  │ 1. build  │          │ 1. match  │
  │    aab    │          │    certs  │
  │           │          │ 2. build  │
  │ 2. sign   │          │    ipa    │
  │    (key-  │          │ 3. sign   │
  │    store) │          │    (pro-  │
  │           │          │    file)  │
  │ 3. upload │          │ 4. upload │
  └─────┬─────┘          └─────┬─────┘
        │                       │
        ▼                       ▼
  ┌───────────┐          ┌───────────┐
  │  Google   │          │ TestFlight│
  │  Play     │          │           │
  │  Internal │          │  Internal │
  │  Testing  │          │  Testing  │
  └───────────┘          └───────────┘
```

## Project Tree (Target State)

```
brush-quest/
├── lib/                              # Shared Flutter/Dart code
│   ├── main.dart
│   ├── screens/
│   ├── services/
│   │   ├── auth_service.dart         # Google Sign-In + Sign in with Apple
│   │   ├── analytics_service.dart    # Platform-gated (disabled on iOS v1)
│   │   └── ...
│   └── widgets/
│
├── android/
│   ├── app/
│   │   ├── build.gradle.kts
│   │   ├── google-services.json      # Firebase Android config
│   │   └── src/main/AndroidManifest.xml
│   └── fastlane/
│       ├── Appfile                   # ✅ EXISTS — Play Store package name
│       ├── Fastfile                  # ✅ EXISTS — internal + promote lanes
│       ├── service-account.json      # ✅ EXISTS — Play Store API key (NEVER commit)
│       └── metadata/                 # Store listing metadata
│
├── ios/                              # ← TO CREATE (flutter create --platforms=ios)
│   ├── Runner/
│   │   ├── Info.plist                # Permissions, URL schemes, privacy
│   │   ├── GoogleService-Info.plist  # Firebase iOS config
│   │   ├── Runner.entitlements       # Sign in with Apple capability
│   │   └── PrivacyInfo.xcprivacy     # Apple privacy manifest (required 2024+)
│   ├── Podfile                       # CocoaPods — override for IDFA-less Firebase
│   └── fastlane/
│       ├── Appfile                   # Apple ID, team ID, bundle ID
│       ├── Fastfile                  # testflight + appstore lanes
│       └── Matchfile                 # Points to private cert repo
│
├── .github/
│   └── workflows/
│       ├── android-deploy.yml        # Linux runner → build aab → fastlane internal
│       └── ios-deploy.yml            # macOS runner → match → build ipa → testflight
│
├── Gemfile                           # Root-level: gem "fastlane"
├── pubspec.yaml                      # Single version source: 1.0.0+N
└── docs/
    └── ios-crossplatform-strategy.md # This document
```

## Tools & Services

| Tool | Purpose | Status |
|------|---------|--------|
| **Fastlane** (Android) | Build + upload to Google Play | ✅ Working |
| **Fastlane** (iOS) | Build + upload to TestFlight/App Store | To set up |
| **Fastlane Match** | iOS cert/profile sync via private Git repo | To set up |
| **Codemagic** | CI/CD — 500 free macOS M2 min/month | Recommended |
| **Firebase** | Auth, Firestore, Crashlytics, Analytics | ✅ Android, iOS to configure |
| **Apple Business** | Org enrollment → Managed Apple Account | In review (ETA 2026-04-24) |
| **Apple Developer Program** | Code signing, App Store Connect, TestFlight | After Apple Business approved |

## CI/CD Choice: Codemagic

**Why Codemagic over GitHub Actions:**
- 500 free macOS M2 minutes/month (enough for ~10-15 builds)
- Built for Flutter — less YAML config than GitHub Actions
- Handles iOS signing natively
- Free tier covers solo developer needs
- Can always migrate to GitHub Actions later if needed

**Pay-as-you-go fallback:** $0.095/min macOS, $0.045/min Linux

## iOS Code Signing Strategy

```
  Private GitHub repo: anemosgp/ios-certificates
                    │
                    │  encrypted certs + profiles
                    │
        ┌───────────┴───────────┐
        │                       │
        ▼                       ▼
  ┌───────────┐          ┌───────────┐
  │ Jim's Mac │          │ Codemagic │
  │           │          │    CI     │
  │ fastlane  │          │ fastlane  │
  │ match     │          │ match     │
  │ appstore  │          │ (readonly)│
  └───────────┘          └───────────┘
```

**Fastlane Match** syncs certificates via a private Git repo:
- `fastlane match init` → creates Matchfile pointing to private repo
- `fastlane match appstore` → generates + encrypts + stores App Store certs
- CI runs `match(readonly: true)` → pulls certs without modifying them
- One passphrase (`MATCH_PASSWORD`) unlocks everything

## Apple Kids Category Compliance (iOS-Specific)

| Requirement | Status | Action |
|-------------|--------|--------|
| No IDFA collection | Needs Podfile override | Use `GoogleAppMeasurementWithoutAdIdSupport` |
| No ATT prompt | ✅ Not in codebase | Don't add it |
| Ad consent denied | ✅ Done in analytics_service.dart | Already compliant |
| No PII in analytics | ✅ Only ids/counts/durations | Already compliant |
| Privacy Manifest | Needed | Generate PrivacyInfo.xcprivacy |
| Sign in with Apple | Required (Guideline 4.8) | Must implement alongside Google Sign-In |
| Firebase Analytics | Risk of rejection | **Disable on iOS for v1**, re-enable after approval |

## Fastlane Configuration

### Android (✅ Already Working)

```ruby
# android/fastlane/Fastfile
platform :android do
  lane :internal do
    upload_to_play_store(
      track: "internal",
      aab: "../build/app/outputs/bundle/release/app-release.aab",
      release_status: "completed",
    )
  end

  lane :promote_to_production do
    upload_to_play_store(
      track: "internal",
      track_promote_to: "production",
    )
  end
end
```

### iOS (To Create)

```ruby
# ios/fastlane/Fastfile
platform :ios do
  lane :testflight_release do
    match(type: "appstore", readonly: true)
    build_app(
      workspace: "Runner.xcworkspace",
      scheme: "Runner",
      export_method: "app-store",
    )
    upload_to_testflight(
      skip_waiting_for_build_processing: true
    )
  end

  lane :promote_to_appstore do
    deliver(
      submit_for_review: false  # manual review trigger
    )
  end
end
```

## Implementation Sequence

| # | Step | Depends on | Can start |
|---|------|-----------|-----------|
| 1 | Scaffold iOS (`flutter create --platforms=ios .`) | Nothing | Now |
| 2 | Add Sign in with Apple to auth layer + UI | Step 1 | Now |
| 3 | Platform-gate Firebase Analytics (disable iOS) | Step 1 | Now |
| 4 | Write Info.plist permissions + privacy manifest | Step 1 | Now |
| 5 | Add iOS app to Firebase Console + regenerate config | Step 1 | Now |
| 6 | Podfile override for IDFA-less Firebase | Step 1 | Now |
| 7 | Apple Business approval | Submitted 2026-04-17 | Waiting (~5 biz days) |
| 8 | Google Workspace federation in Apple Business | Step 7 | After approval |
| 9 | Apple Developer Program enrollment ($99) | Step 8 | After federation |
| 10 | Fastlane Match setup (private cert repo) | Step 9 | After Dev Program |
| 11 | `cd ios && fastlane init` + Fastfile | Step 9, 10 | After Dev Program |
| 12 | First TestFlight build | Steps 1-6, 10-11 | After all above |
| 13 | Codemagic CI setup | Step 12 works locally | After first manual deploy |
| 14 | App Store submission | Step 12 tested | After TestFlight validation |

**Steps 1-6 can start today. Steps 7-9 are waiting on Apple (~5 days).**

## Accounts & Credentials Summary

| Credential | Where stored | Used by |
|------------|-------------|---------|
| Play Store service account JSON | `android/fastlane/service-account.json` | Fastlane Android |
| Android upload keystore | Local + CI secret | Android signing |
| App Store Connect API key | CI secret (after setup) | Fastlane iOS |
| Match passphrase | `MATCH_PASSWORD` env var | Fastlane Match |
| iOS certs + profiles | Private Git repo (encrypted) | Match |
| Firebase Android config | `android/app/google-services.json` | Firebase SDK |
| Firebase iOS config | `ios/Runner/GoogleService-Info.plist` | Firebase SDK |

## Key Decisions

- **CI/CD:** Codemagic (free tier, Flutter-native)
- **iOS signing:** Fastlane Match with private GitHub repo
- **Analytics on iOS v1:** Disabled (reduce first-review rejection risk)
- **Sign in with Apple:** Required — implement before iOS submission
- **Apple account path:** Apple Business → Managed Account → Developer Program
- **Version management:** Single source in `pubspec.yaml`, both platforms read it

# Brush Quest — Status Board
<!-- Every session reads this at start. Every session updates its section at end. -->
<!-- Jim says "update the status board" → session updates its workstream below. -->

**Current #1 Priority**: Both stores launch in flight. **Android v22 submitted to Play Store production review 2026-05-11** (auto-checks running, then human review ≤7 days). **iOS v22 on TestFlight** awaiting feedback from 3 testers (Antoine, Matt, Jan) before clicking "Add for Review" — Apple submission is one click away once test confirms build is sound.
**CEO Streak**: Week 0 (starting fresh)
**Phase**: 2 — production launch in flight on both platforms

---

## Workstream Status

### APP
- **Status**: **v24 iOS audio + auth fix flight built 2026-05-19** — 5 commits addressing Jim's TestFlight observation that iOS audio is broken (voice cuts mid-sentence, intermittent) AND both Apple/Google sign-in buttons silently no-op. Android v22 still in Play Store production review (untouched). iOS v22 still on TestFlight pending tester feedback. v24 is iOS-only material — Android v22 stays as-is until prod ships.
- **Last session**: 2026-05-19
- **Last commit**: `5289d66` — fix(audio): cancel victory's 1500ms music Timer in dispose (1.0.0+24)
- **What happened (2026-05-19, v24 audio + auth fix flight)**:
  - **Diagnostic**: 5 parallel research agents + Codex CLI independent audit. Codex significantly course-corrected the analysis — caught that the proposed `AudioContextIOS` fix was redundant (iOS default IS playback) and that the real high-confidence iOS audio bug was the lifecycle policy killing audio on transient `inactive` events.
  - **Auth (commit `805f3aa`)** — both buttons silently no-op'd because of TWO independent config gaps: (1) `Runner.entitlements` was orphaned — `project.pbxproj` never referenced it, so the signed binary shipped without `com.apple.developer.applesignin`; (2) `Info.plist` was missing both `CFBundleURLTypes` (Google OAuth callback scheme) and `GIDClientID`. Also added null-user SnackBar in settings_screen so silent failures surface.
  - **Audio lifecycle + interruptions (commit `5554b8f`)** — Codex's highest-confidence catch: `main.dart` was killing all audio on iOS `inactive` (transient — fires for Control Center, notification banners), making audio appear permanently dead after every minor interruption. Now iOS only stops on `paused`. Paired with `AppDelegate.swift` `AVAudioSession.interruptionNotification` observer that re-activates the session after phone calls / Siri / FaceTime — the `audioplayers` plugin doesn't install this observer itself.
  - **iOS-gated music dispose (commit `015a0c4`)** — `playMusic` was doing `unawaited(_musicPlayer.dispose())` immediately before assigning new player + `setSource`. On iOS the AVPlayer KVO teardown can be in flight when new player attaches → silent/stuck music. Now `await` on iOS only; Android v22 baseline fire-and-forget unchanged.
  - **Music serialization (commit `631afb7`)** — applied proven home_screen pattern (`await playMusic` → mounted check → `await setMusicVolume` → mounted check → `unawaited(ensureMusicPlaying)`) to `world_map_screen`, `trophy_wall_screen`, `hero_shop_screen`. The unawaited pair raced on iOS — volume got applied to the prior disposed player.
  - **Victory Timer leak (commit `5289d66`)** — the 1500ms music kickoff Timer in `victory_screen.dart:336` was bare. If kid tapped DONE before 1500ms, the late Timer's `playMusic` raced Home's postFrame `playMusic` on the singleton. Now stored as `Timer? _victoryMusicTimer` and cancelled in dispose alongside `_doneSafetyTimer`. Documented as the safest single-file fix in `project_home_music_dropout` memory.
  - **Verification**: dart analyze clean across all 5 commits, 788 tests pass each commit, `audio_regression_test` 6/6 each commit. All cross-platform fixes were either iOS-gated (`Platform.isIOS`) or used patterns already proven safe on Android v22 production.
  - **Not done — deferred for v25 if TestFlight shows it's needed**: AudioContextIOS `mixWithOthers` experiment (Codex flagged as debatable for kids' app, doesn't explain internal cuts), iOS-only voice completion mechanism replacement (current `Future.any` + StateError catch is fine; "voice cuts mid-sentence" is call-site-driven not completion-mechanism-driven).
  - **Next**: Build + upload v24 to TestFlight via `fastlane beta` for real-device validation. Codex's pre-commit verification commands ready: `codesign -d --entitlements :- build/ios/iphoneos/Runner.app` and `plutil -p build/ios/iphoneos/Runner.app/Info.plist | rg 'CFBundleURLTypes|GIDClientID'` to prove the entitlement + URL scheme actually made it into the signed binary.
- **What happened (2026-05-11, Android v22 production submission)**:
- **Last commit before v24**: `460e1db` — feat: parent-gated camera onboarding + home discoverability nudge (1.0.0+22)
- **What happened (2026-05-10..11, dual-platform v22 cycle + Android production submission)**:
  - **Parallel session changes merged** (commit `460e1db`): 4th onboarding page = camera permission, parent-gated behind math gate + COPPA consent dialog; Home screen camera-discoverability chip near PARENTS for users who skipped onboarding camera ask; default brush phase 20s→15s so the "2-minute brushing" claim holds with transitions. Plus new `voice_camera_prompt.mp3` in buddy + classic packs (ElevenLabs George/Jessica via `/tmp/gen_camera_prompt.py`). 788 tests pass, dart analyze clean.
  - **iOS commit `5488e2d`** (2026-05-09): Replaced default Flutter icon with Brush Quest fox across all 15 AppIcon sizes (master = `tmp/icon-candidates/option3_battle.png`, 1024×1024 RGB no-alpha). Also added `ITSAppUsesNonExemptEncryption=false` to Info.plist so future builds skip the ASC App Encryption Documentation prompt.
  - **iOS v21 + v22 → TestFlight**: v21 uploaded 2026-05-09 (icon fix), v22 uploaded 2026-05-11 07:48 via `fastlane beta` using App Store Connect API key `4YY7329MH5`. Both VALID on Apple's side. ASC submission currently has v21 selected; will swap to v22 once tester feedback comes in.
  - **TestFlight testers added via ASC REST API** (script pattern `/tmp/asc_*.py` using cryptography lib for JWT — Family & Friends group is internal-only so we attach testers directly to specific builds, then POST betaTesterInvitations to trigger Apple's email): Jan Deloach `jandeloach273@gmail.com` (build 21), Antoine Markarian `amarkarian@gmail.com` (build 21 → also v22), Matt Ganser `mattganser@gmail.com` (build 22). Jan's first phone had issues yesterday; Antoine + Matt emailed by Jim 2026-05-11 with short ask-for-feedback note.
  - **Android v22 → Play Store**: AAB built (`flutter build appbundle`, exit-1 was non-fatal "strip-debug-symbols" warning), uploaded to internal track 2026-05-11 08:03 via `fastlane internal` (after retry — first attempt hit Google's 300s timeout, the 112MB AAB needed `SUPPLY_UPLOAD_MAX_RETRIES=3`).
  - **`fastlane promote_to_production` failed twice with "Release in track targeting no countries"** — production track had never had country availability set at the app level. API has no setter (`countryavailability` endpoint is read-only; `countryTargeting` on a release is only allowed for staged rollouts; first prod release CANNOT be staged). Resolved via Chrome MCP walking Play Console → Production → Countries/regions → "Select all rows" → Save → "Go to overview" → Production → Create new release → Add from library (v22 bundle) → release notes → Save → Send 7 changes for review.
  - **The 7 changes Google has under review now**: Production add 176 countries + rest of world + v22 release; Public Beta (Early Access) cascade — Google auto-cleared 4 countries that overlap with prod, paused track, paused open access, limited users to 0. The cascade is normal: when production goes live worldwide, the open-access public beta is superseded. Internal testing track is untouched (Jim + Oliver still test v22 there).
  - **TestFlight invite gotcha (worth remembering)**: Apple's POST `/v1/betaTesters` with `betaGroups` relationship returns 409 STATE_ERROR for the internal Family & Friends group — internal testers must be ASC users (Apple ID linkable). Workaround: attach to `builds` relationship instead (any VALID build), no ASC user account required. Confirmed working for 3 testers.
- **What happened (2026-04-23..04-28, prior Play Store work — unchanged from earlier sessions)**: Play Store listing overhaul + Closed testing public-beta track set up (4 countries US/CA/UK/AU, Google Group gate) — those public beta changes are the ones that just got auto-paused by today's worldwide production submission.
- **Blocked on**: Tester feedback from Antoine, Matt, Jan (Apple side); Google human reviewer (Play side, ≤7 days).
- **Next up**:
  1. Tonight/tomorrow: read Antoine + Matt feedback emails. If clean → swap ASC build #21 → #22 in App Store Connect, click "Add for Review" (Claude can drive both via Chrome MCP).
  2. Watch for Google Play approval email — if any policy issue surfaces in auto-checks (≤14 min), fix and resend. If human review approves → app goes live on Play Store worldwide.
  3. Once Play Store URL is live: push Nicole-Facebook + NextDoor distribution (was the prior #1 priority, simply gated on this approval).
- **What happened (2026-04-28, Early Access track "Public Beta" set up + 7 changes submitted for review)**:
  - **Pivot from Open Testing → Early Access** — Open Testing track requires countries with a Production release (we don't have one); Google's recommended replacement for pre-Production public beta is the Early Access track.
  - **Reddit GTM dead end (lesson)** — r/Daddit auto-removed for self-promo (rule #3), r/AlphaAndBetaUsers auto-removed by Reddit's site-wide spam filter (low-karma + external-link signal). Reddit not viable for new accounts; pivoting to non-karma channels.
  - **Public Beta track configured**: 4 countries (US/CA/UK/AU), v20 release with parent-outcome notes, Open invites enabled (unlimited users, no email gate, no group gate), feedback channel `jim@anemosgp.com`. 7 changes submitted for review 2026-04-28.
  - **Once approved (~24-48h)**: Public Play Store install URL will be available — that's what goes into Nicole's Facebook post + NextDoor + pediatric dentist flyers. Replaces the Google Group friction gate as the primary distribution channel.
  - **Reddit monitor decommissioned** (cron `c0f628a0` deleted; post is dead).
- **What happened (2026-04-27, Promo video shipped + linked in Play Store listing)**:
  - **30s vertical promo video** (`marketing/video/promo_v5_26s.mp4`, 26s, 10MB, 1080×2410):
    - 6-segment structure: Home (4s) → World Map (3s) → Hero Shop (3s) → Brushing (7s) → Victory (5s) → End card (4s)
    - Static stills (clean Play Store screenshots) for menu segments — no source-recording transition bleed
    - Source video footage for brushing + victory beats
    - Custom end card PNG generated via `marketing/video/endcard.py` (yellow BRUSH QUEST logo + "Get it on Google Play" pill)
  - **Parent voiceover (ElevenLabs Sarah, 6 lines layered with sidechain ducking — base 55%, ducks to 30% under VO)**:
    - 0.5s "Turn bedtime brushing into the part your kid can't wait for."
    - 4.4s "Choose a world to conquer."
    - 7.3s "Pick a hero. Start the quest."
    - 11.5s "Every stroke powers their hero."
    - 17.7s "Celebrate the brush. Open the chest for a surprise."
    - 22.5s "Brush Quest. Free on Google Play."
  - **5 iterations** (v1 raw cut → v5 final): v1 source-cut + 3 clips, v2 layered VO, v3 reordered to home-first sequence, v4 swapped menus to clean stills (fixed scene-bleed bug), v5 added world+victory VO lines
  - **YouTube uploaded** as Unlisted on personal channel (jmchabas@gmail.com): https://youtube.com/watch?v=XwkGoLBKW4A — Audience set to "Not made for kids" (parent-narrated marketing, install CTA targets adults)
  - **Play Console listing updated** + 1 change submitted for Google review
- **What happened (2026-04-23, Play Store listing overhaul + Closed testing setup)**:
  - **Store listing audit + edits** (3 fields changed):
    - Title → `Brush Quest: Kids Toothbrush` (28/30 chars, +Kids/Toothbrush keywords for ASO)
    - Short desc → `Make toothbrushing the part kids beg for — not fight.` (53/80)
    - Full desc grammar polish: victory line comma fix; credit line rewrite (`Built by a dad in California with his two sons (ages 7 and 3)`)
  - **8 new branded phone screenshots** captioned with Fredoka Medium + black+yellow band + 3px stroke, built via `marketing/screenshots/v2/caption_v2.py`:
    - #1 Home: "Pick a hero. Start the quest"
    - #2 World Map: "10 worlds to conquer"
    - #3 Heroes: "Heroes earned by brushing"
    - #4 Brushing: "Voice-guided — no reading needed"
    - #5 Victory: "Every brush defeats a monster" (NEW — closes the missing story beat)
    - #6 Parent Dashboard: "A progress dashboard for parents" (NEW — the dashboard view wasn't in old listing)
    - #7 Settings: "Grows with ages 3–12"
    - #8 Monsters: "Catch all 50 cavity monsters"
  - **Closed testing track "Alpha" fully configured**:
    - Release: promoted v20 (1.0.0) from library (no new build needed)
    - Countries: US / CA / UK / AU (unsynced from Production)
    - Tester gate: public Google Group — `brush-quest-testers@googlegroups.com` (anyone-can-join, managers-only membership view for parent privacy)
    - Feedback channel: `jim@anemosgp.com`
    - Release notes: parent-outcome-first ("Turn nightly toothbrushing from a battle into the part your kid looks forward to...")
  - **Google Group created** — `https://groups.google.com/g/brush-quest-testers` (public signup URL, live now)
  - **All 10 changes submitted to Google for review** — typical 2–48h window for kids apps
  - Personal jmchabas@ dev account confirmed blocked (identity + phone unverified) — deferred, Brush Quest is cleanly on the AnemosGP org account
- **What happened (2026-04-21, Cycle 16 — Oliver v19 regression fixes)**:
  - SS1 hero multi-tap → `_brushTapLocked` flag + 1500ms→400ms post-tap delay + greeting barrier auto-launches brush
  - SS2 countdown voice restored → recorded "Three!/Two!/One!" via ElevenLabs George, one per tick alongside the beep (C15 had ripped voice_countdown.mp3 because its baked "3-2-1-GO!" fired 2.5s before GO)
  - SS3 world voice bleed → `_dismissWorldIntro` now calls `stopVoice()` (was missing; `_exitWorldIntro` already had it)
  - SS4 greeting clarity → streak 2-9 icon no longer duplicates the flame below; added "N days in a row!" caption for parents
  - 784 tests pass (+3 from new audio assets), dart analyze clean, 4/4 fitness gates
  - v1.0.0+20 verified via Play Developer API: `status=completed`, auto-publishing to testers
- **What happened (2026-04-20, Cycle 15 — 13 T3 UX fixes from C14 findings)**:
  - Critical: chest-tap mandatory on victory (T3-32) — removed immediate-DONE setState, kept 60s safety timer as stuck fallback
  - Shop symmetry: new `_FeaturedHeroDisplay` widget mirroring weapons; amber "+N" delta readout on evolution cells when price-wallet ≤ 3 (C14 4-agent convergent)
  - Trophy wall: dropped "???" text on uncaptured trophies; silhouette PNG carries the mystery (no label needed for non-readers)
  - Home polish: amplified hero aura ring (size swing 16→30px, 1.4s loop), post-brush ✓ sticker for 4s, PARENTS shield → lock_outline icon
  - World intro auto-advance: voice-driven (2s after voice ends, 5s floor, 10s cap) instead of hardcoded 10s
  - Settings gate: stopMusic on entry (parents get silence/focus)
  - Audio pool: 7 new Buddy voices — `voice_home_return_{1-4}` (dedicated home-return pool, not exertion reruns), `voice_locked_{soon,save_stars}`, `voice_go_brushing` ("Go!" aligned to actual GO moment)
  - 781 tests pass, 120.6 MB APK, 4/4 fitness gates
- **What happened (2026-04-17, Cycle 14 — `auto-full max=3`, stopped after pass 1)**:
  - Phase 0 caught CI red on main (format regression v16/v17) — fixed before analysis
- **What happened (2026-04-11, Cycle 13 — `auto-full` mode debut)**:
  - New `/cyclepro auto-full` mode: full 9-agent analysis + autonomous T1/T2 fixing
  - Auto-clean: 197 dart analyze infos resolved (unawaited, catch clauses, const, etc.)
  - 110 findings synthesized; 6 T2 auto-fixed; 20 T3 implemented across 8 streams
  - Trophy wall: voice on locked taps, monster silhouettes (no more "???"), Pokemon-style mystery
  - Home: military_tech badge for rank (P11), icon-first greeting popup (P1), stat animations on return
  - Victory: bigger stats, audio crossfade fix, K.O. voice variety (5 lines)
  - Settings: simplified Stars tab, delete cloud data button (COPPA), purchase mutex
  - Shop: snackbar icon-only (P1), evolution arrows
  - Onboarding P3: space theme, consistent button color
  - **Hotfix (Oliver same-day playtest)**: removed auto-chest, fixed voice cut, removed LEGENDARY badge + bonus pills (-310 lines)
  - 773 tests, 121.4 MB APK, 4/4 fitness gates
- **Play Store**:
  - v1.0.0+13 LIVE on internal testers (Apr 11 8:00 PM)
  - All 10 policy declarations actioned (Advertising ID added today w/ AD_ID permission removed from manifest)
  - Store listing complete (icon, feature graphic, 8 screenshots, descriptions)
  - **8 changes submitted for Google review** — typical 1-7 day window
- **What happened (2026-04-10, Cycle 12)**:
  - 28 findings, 25 implemented across 6 parallel streams (victory, services, UI, audio, etc.)
- **COPPA Compliance Tracker**:
  - [x] P1.1-P1.6: All code + Firebase Console done
  - [x] P1.1 (updated): Camera defaults OFF, onboarding no longer sets camera_mode_configured
  - [x] P2.2: Privacy policy overhauled — COPPA 2025 + CCPA + data security program
  - [x] AD_ID permission removed from manifest (`tools:node="remove"`) — clean COPPA "No" declaration
  - [ ] P2.1: Google Play Console families policy config (still pending — separate from app review)
- **What happened (2026-04-17, Cycle 14 — `auto-full max=3`, stopped after pass 1)**:
  - Phase 0 caught CI red on main (format regression v16/v17) — fixed before analysis
  - 9 agents → 144 findings → 13 T1/T2 auto-implemented
  - Music volume restore bug fix (audio no longer surges 3-4x after voice on home/map/shop/trophy)
  - Daily bonus nav-timing fix (claims on brush-return path + app resume, not only via greeting)
  - Evolution auto-equip guard (no more silent hero switch on evo purchase)
  - `isPurchasing` mutex stuck-flag reset on cold start
  - Consent dialog now discloses Firebase Analytics + Crashlytics (COPPA)
  - Restore + Start-Fresh dialogs warn about data loss
  - Sign-in 30s timeout + typed TimeoutException
  - Settings gate re-lock now dismisses open popups
  - World map planet tap + trophy wall locked-chip gain SFX/haptic/voice (P3, P7)
  - Home screen `WidgetsBindingObserver` for app-resume refresh
  - Greeting popup listener leak fixed
  - Featured weapon tappable → picker voice
  - COPPA allowlist updated for iOS Apple Sign-In deps
  - 774 tests, 120.4 MB APK (-1.0 MB vs C13), 4/4 fitness gates
- **Blocked on**: Google review of 10 queued changes (submitted 2026-04-23). Crashlytics on v20 still worth monitoring.
- **Next up**: (1) Record promo video for listing (adb screenrecord + voiceover, upload YouTube unlisted, paste URL); (2) Prep tester-invite GTM copy for when Closed testing activates (Substack post, social, parenting forums); (3) Oliver v20 retest confirmation; (4) iOS TestFlight prep when Apple Business approves (~2026-04-24).
- **Needs CEO decision**: When Closed testing goes live — how aggressive to promote the Google Group signup link vs keep it quiet until UX is more polished? Current answer is "public Google Group URL ready to share, but drip via trusted channels first (Substack)."

### LANDING PAGE
- **Status**: Live at brushquest.app — email capture LIVE via Buttondown
- **Last session**: 2026-03-18
- **Last commit**: `9354055` — Desktop hero: QR code to open on phone, email form secondary
- **What happened**:
  - Platform-aware email capture (6 forms across the page)
  - Android mobile: download button + email section below screenshots
  - iOS mobile: email form in hero + sticky bar ("Coming to iPhone")
  - Desktop: QR code in hero (scan to open on phone) + secondary email form
  - FAQ inline forms for "What about iPhone?" and "Why not on Play Store?"
  - Buttondown account created (handle: `brushquest`, free tier, 100 subs)
  - Privacy policy updated with Buttondown disclosure + data retention
  - Tags for segmentation: ios/desktop/android + interest metadata
- **Blocked on**: No Play Store link yet (developer account appeal pending)
- **Next up**: Play Store badge once approved, monitor first signups
- **Needs CEO decision**: None

### PRICING
- **Status**: APPROVED — "Space Ranger Pass" $4.99/mo or $39.99/yr
- **Last session**: 2026-03-15
- **What happened**:
  - Deep research (6 files in `research/`). Parent subscription rejected. Content-led model approved.
  - Jim raised price from $2.99→$4.99 ("$2.99 signals cheap, doesn't reflect health value, Roblox parents spend $5-10/mo without thinking")
  - Free parent activity log + weekly email approved as conversion funnel
  - Monster card collection (21/70 gap) approved as kid-driven conversion engine
  - Full spec in `research/monetization-models.md` (Section 5)
- **Blocked on**: Phase 1 validation needed before implementation (100 users, D7 retention > 35% per D-003)
- **Next up**: Implement paywall + RevenueCat after Phase 1 metrics hit
- **Needs CEO decision**: None — model approved

### LLC
- **Status**: DONE — LLC approved, EIN obtained, bank open, D-U-N-S received, Google Play registered
- **Last session**: 2026-04-01
- **Entity name**: AnemosGP LLC (California), DBA Brush Quest (filing TBD)
- **EIN**: 41-5007192
- **D-U-N-S**: 144980774 (received 2026-03-29)
- **Command**: `/llc` — dedicated session command with full checklist
- **What happened**:
  - LLC approved by SoS on 03/19/2026
  - EIN obtained: 41-5007192
  - Mercury bank account opened (checking ending 2545)
  - Operating Agreement created
  - Privacy policy overhauled (COPPA 2025 + CCPA, phone number, 10 sections)
  - Data security program document created (COPPA 312.8)
  - DBA "Brush Quest" form pre-filled (not yet filed)
  - D-U-N-S 144980774 received (2026-03-29)
  - Google Play org developer account registered (2026-04-01, Account ID: 5965081279664275195)
  - Signed up with jim@anemosgp.com, developer name "Brush Quest"
  - support@anemosgp.com alias created in Google Workspace
  - anemosgp.com verified in Google Search Console (DNS TXT record)
  - Website + identity verification in progress
- **Checklist**:
  - [x] Choose state: California
  - [x] Registered agent: Northwest ($125/yr, active 03/15/2026 - 03/15/2027)
  - [x] Articles of Organization filed (CA Form LLC-1, $75 — Doc# B20260127451)
  - [x] LLC approved by Secretary of State (03/19/2026)
  - [x] EIN obtained (41-5007192)
  - [x] Operating Agreement created
  - [x] Business bank account opened (Mercury, checking ending 2545)
  - [x] Update privacy policy with LLC info + phone (510) 214-6383
  - [ ] File Statement of Information (CA Form LLC-12, $20) — within 90 days of formation (due ~06/13/2026)
  - [ ] File DBA "Brush Quest" (FBN form pre-filled)
  - [x] D-U-N-S received (144980774, 2026-03-29)
  - [x] Register Google Play organization account (Account ID: 5965081279664275195, 2026-04-01)
  - [x] Website verified (anemosgp.com via Search Console)
  - [x] Identity verification (CP 575 + passport, 2026-04-01)
  - [x] Phone number verification (2026-04-01)
- **Blocked on**: Nothing
- **Next up**: Complete identity + phone verification, then create app listing
- **Estimated cost**: ~$1,040 year 1, ~$935/year ongoing (CA franchise tax is $800/yr, Play Store $25 one-time)

### APPLE BUSINESS / iOS LAUNCH
- **Status**: ✅ Apple Business **VERIFIED**. ✅ Apple Developer Program **ACTIVE** (Team ID J846H79L2X). ✅ SIWA key + Cloud Function `revokeAppleToken` deployed. ✅ fastlane match + signed IPA pipeline working. ✅ App Store Connect listing 100% populated (description, screenshots, App Preview video, privacy nutrition labels, age rating 4+, Made-for-Kids 6-8, Apple SIWA tested). **v21 + v22 IPAs on TestFlight (VALID)**. **3 TestFlight testers invited 2026-05-11** (Jan, Antoine, Matt). Apple submission gate is one click ("Add for Review") + a build-21→22 swap.
- **Last session**: 2026-05-11
- **What happened (2026-05-09..11)**: see APP workstream above — iOS v21 icon fix, v22 onboarding feature, TestFlight uploads, tester invites via ASC REST API, ASC listing fully prepared and saved with build 21 selected.
- **Blocked on**: Real-device tester feedback before clicking "Add for Review". Apple Review queue itself runs 1-3 days typical.
- **What happened (2026-05-04)**:
  - Apple Developer Program License Agreement signed at 18:49 UTC; $99/yr membership purchased at 18:51 UTC (Order W1578089183, billed to jmchabas@gmail.com / 3101 Lincoln Ave Alameda).
  - Apple email status: "Your order is being processed." Team ID assignment expected within minutes to 24h.
  - Once Team ID known: run `scripts/capture_team_id.sh <TEAM_ID>` to wire it into pbxproj DEVELOPMENT_TEAM + ios/fastlane/Matchfile + REGISTRY.md (script is idempotent + sandbox-tested).
  - Phase 2 cascade then unblocks: 2A-3 SIWA `.p8` key generation → Cloud Function fill-in → 2B-3/2B-4 fastlane match init → 2C-1 App Store Connect listing → 2D-2 first signed iOS build → TestFlight upload.
- **What happened (2026-04-29)**:
  - Closed all four Tier 3 review items: privacy labels (1K-2), store listing (1L-2 — subtitle now "Make brushing the easy part"), iPhone screenshots (1M-3), App Preview video (1T-2 — re-cut with George VO + privacy end card).
  - Created `brush-quest-match` private GitHub repo (2B-2) via `gh repo create`.
  - Diagnosed iOS audio bugs in 1D-1 hand-walk: firebase_options.dart had no iOS branch (fixed inline); audioplayers_darwin 6.4.0 had Swift continuation leak (reverted to 6.3.0 via dependency_overrides; upstream issue filed at bluefireteam/audioplayers#1982); 3 voice timeouts + music-on-home-after-Done remain Simulator-flaky.
- **What happened (2026-04-28, earlier in this multi-session series)**:
  - Apple Business org verified by Holly (case `102880286319`).
  - 28 plan tasks closed including: Crashlytics framework strip via Run Script + Podfile post_install, app-level PrivacyInfo.xcprivacy, audio strict-async revert, BRUSHING_FAST_MODE flag for integration tests, full iPhone screenshot pipeline (24 PNGs at 1320×2868/1290×2796/1242×2688), App Preview video at 1290×2796, codemagic.yaml + Fastlane skeleton, Cloud Function stub for Apple SIWA token revoke, integration tests (parental_gate, brush_session_e2e, audio_smoke).
- **Blocked on**: Apple to assign Team ID (passive wait, expected within 24h).
- **Next up (when Team ID lands)**:
  1. Run `bash scripts/capture_team_id.sh <TEAM_ID>` from brush-quest repo
  2. Generate Sign in with Apple `.p8` key at developer.apple.com → Keys (2A-3), wire it into `functions/src/index.js` revokeAppleToken
  3. Run `cd ios && bundle exec fastlane match development` then `match appstore` (2B-3/2B-4)
  4. Create App Store Connect listing record (2C-1, manual via App Store Connect web — paste from `docs/ios-port/store-listing.md`)
  5. Trigger first signed iOS build via Codemagic (2D-2) → TestFlight upload (2D-3)
  6. On real iPhone via TestFlight: validate audio behavior (3 voice timeouts + music-on-home-after-Done were Simulator-only? — this is the test)
- **Needs CEO decision**: None — execute the post-Team-ID runbook in `docs/ios-port/phase-2-runbook.md`.

#### Original entry (Apple Business approval 2026-04-28)
- **Last session**: 2026-04-28
- **What happened (2026-04-28)**:
  - Apple sent "Unable to verify" email at 8:39am PT requesting additional documentation
  - Holly (senior advisor, Apple Deployment Program) took over case at 8:43am PT
  - Jim resubmitted via secure upload + business.apple.com → Settings → Organization → Verify Now: Passport, Driver License, Articles of Organization, CP575G (EIN), Operating Agreement
  - Holly approved enrollment at 12:58pm PT — Apple confirmation email "AnemosGP LLC is verified on Apple Business" received 12:52pm PT
  - 11-day total turnaround (submitted 2026-04-17, verified 2026-04-28)
- **What this unblocks**:
  - Apple Developer Program organizational enrollment using D-U-N-S 144980774 (no more SMS-verification blocker that derailed personal Apple ID path)
  - Managed Apple Account creation for App Store Connect access
  - Phase 2 of `docs/ios-port/PLAN.md` (signing, TestFlight, App Store submission)
- **Holly's parting note**: Add a second administrator for account recovery — https://support.apple.com/guide/apple-business-manager/manually-add-users-axme2e2158c6/web
- **Blocked on**: Nothing
- **Next up**: (1) Add backup admin in business.apple.com → People; (2) Set up Google Workspace federation so managed accounts auth via Google (avoids Apple SMS); (3) Create managed Apple Account for jim@anemosgp.com; (4) Enroll in Apple Developer Program at developer.apple.com/programs ($99/yr, D-U-N-S 144980774); (5) Continue iOS Phase 1 code-side tasks per `docs/ios-port/PLAN.md` (Podfile post_install for Crashlytics strip, Info.plist privacy strings, etc.).
- **Needs CEO decision**: None — execute the post-approval checklist.

### AMAZON APPSTORE
- **Status**: Developer account registration — identity verification pending
- **Last session**: 2026-03-28
- **What happened**:
  - Registered Amazon Developer account (jmchabas@gmail.com)
  - Completed US tax interview (W-9 with AnemosGP LLC / EIN 41-5007192)
  - Completed Canada tax interview
  - Company profile, payment, tax identity all set up
  - Identity verification failed on auto-check — submitted support case with passport
  - Support case **19804300171** — status: "In Process: pending Amazon action"
  - W-9 saved: `anemosgp-business/legal/amazon/W9_amazon-developer_2026-03-21.pdf`
  - Customer support email: support@brushquest.app
- **Checklist**:
  - [x] Register Amazon Developer account
  - [x] Complete US tax interview (W-9)
  - [x] Complete Canada tax interview
  - [x] Set up company profile + payment
  - [ ] Identity verification approved (case 19804300171)
  - [ ] Submit Brush Quest APK
  - [ ] App published on Amazon Appstore
- **Blocked on**: Identity verification (support case pending)
- **Next up**: Wait for Amazon to verify identity → submit APK
- **Why**: Plan B distribution while waiting for D-U-N-S / Google Play org account
- **Needs CEO decision**: None

### ACCOUNTING
- **Status**: In progress — QuickBooks + Mercury bank open, need to connect and log expenses
- **Last session**: 2026-03-20
- **Command**: `/accounting` — dedicated session command
- **What happened**:
  - Chose accounting stack: Mercury (bank) + QuickBooks Simple Start ($15/mo) + Mercury credit card
  - Signed up for QuickBooks Simple Start
  - Mercury bank account opened (checking ending 2545)
  - Tax type: sole proprietor (single-member LLC, Schedule C)
  - Tax calendar reminders set (franchise tax July 15, annual return April 2027)
  - Google Drive structure for business docs: `gdrive:Projects/AnemosGP LLC/`
- **Checklist**:
  - [x] QuickBooks Simple Start signed up
  - [x] Tax calendar reminders set
  - [x] Open Mercury bank account (checking ending 2545)
  - [ ] Connect Mercury → QuickBooks
  - [ ] Log existing expenses (RA $125, LLC filing $75, all receipts in `AnemosGP LLC/Receipts/`)
  - [ ] Set up expense categories in QuickBooks
  - [ ] Get Mercury credit card
- **Blocked on**: Nothing
- **Next up**: Connect Mercury → QuickBooks, log all existing expenses
- **Needs CEO decision**: None

### MERCH
- **Status**: DONE
- **Last session**: 2026-03-16
- **What happened**:
  - New app icon: 3D battle scene (fox vs monster with toothbrush) replacing old 2D cartoon tooth. Installed to all Android mipmap densities + website favicon.
  - APK rebuilt and uploaded to Google Drive
  - Merch assets created: Shadow action (Oliver), Blaze action (Theo), Monster Squad group, 2 logo badges (circle + shield)
  - All assets AI-upscaled 4x via Real-ESRGAN to print-ready resolution (4096px+)
  - T-shirt layouts with "BRUSH QUEST" text integrated
  - Shield badge die-cut with transparent background following shield contour
  - Design decisions: no QR on shirts, black tees, character-first with small branding
- **Assets**: `assets/images/merch/` (source) + `assets/images/merch/print-ready/` (4x upscaled)
- **Next up**: Order on Printful (Oliver YS/YM black, Theo 4T/5T black)
- **Needs CEO decision**: None

### DEV CYCLE
- **Status**: Cycle 10 complete — 32 findings shipped (9 deferred), LEARN phase done
- **Last session**: 2026-04-07
- **Command**: `/cycle` (full audit), `/cycle quick` (lightweight), `/cycle ship` (verify+ship), `/cycle visual` (emulator screenshots), `/cycle resume` (deferred findings)
- **Repo**: `~/Projects/dev-cycle` (GitHub: jmchabas/dev-cycle, private)
- **Cycles completed**: 1, 2, 3, 4, 5, 6, 8, 9, 10 (Cycle 7 informal — shipped but no LEARN phase)
- **Documentation**: `docs/dev-cycle.md` — full explanation of how `/cycle` works
- **Blocked on**: Nothing
- **Next up**: Cycle 11 after Oliver testing feedback
- **Needs CEO decision**: None

### TELEGRAM
- **Status**: LIVE — Claude Code reachable from Jim's phone
- **Last session**: 2026-04-07
- **What happened**:
  - Installed `telegram@claude-plugins-official` plugin
  - Bot ID: `8512732647`, Jim's user ID: `8567015757`
  - Policy: `allowlist` — locked to Jim only
  - Launch: `claude --channels plugin:telegram@claude-plugins-official`
- **Blocked on**: Nothing
- **Next up**: Use it
- **Needs CEO decision**: None

### STRATEGY
- **Status**: Phase 0 plan complete, operational system built
- **Last session**: 2026-03-14
- **What happened**: Created 5-phase master plan (STRATEGY.md). Built cross-session coordination system. Defined operational cadence.
- **Blocked on**: Nothing — waiting for workstreams to execute
- **Next up**: First Monday weekly brief
- **Needs CEO decision**: N/A

### MEMORY SYSTEM
- **Status**: Active — 4-tier architecture built, knowledge graph operational
- **Last session**: 2026-03-20
- **What happened**:
  - Built 4-tier memory model: HOT (MEMORY.md index) → WARM (topic files with frontmatter) → COLD (archive) → CACHE (.remember/ session handoff)
  - Write gate criteria to prevent memory bloat
  - Size limits enforced per tier (150 lines hot, 200 lines warm, 25 files max)
  - Staleness tracking via last_verified dates with 30/90 day thresholds
  - Knowledge graph (mcp-knowledge-graph) for cross-project entities and relationships
  - Promotion/demotion rules between tiers
  - Frontmatter standard for warm files (name, description, type, last_verified)
  - Cross-project orchestration in ~/Projects/CLAUDE.md
- **Blocked on**: Nothing
- **Next up**: Refine write gate criteria from real usage, improve cross-project entity linking, session handoff reliability
- **Needs CEO decision**: None

### AUTOMATION
- **Status**: Active — 2 remote triggers, 2 local skills, tiered autonomy model
- **Last session**: 2026-03-27
- **What happened**:
  - Created tiered autonomy model (Tier 1: full auto, Tier 2: do+show, Tier 3: propose+wait)
  - Created `/health` local skill — daily build verification (dart analyze + flutter test + economy sim)
  - Created `/gtm-prep` local skill — generates app store listing drafts for Jim to review
  - Set up 2 remote triggers on claude.ai:
    1. **Weekly Code Review + Economy Audit** — Mondays 8:17am PT (trig_01PxsVcosU8Y5ps8BGBkLMMk). Opens PR with ECONOMY_AUDIT.md + CODE_REVIEW.md + Tier 1 lint fixes.
    2. **Weekly GTM Prep** — Wednesdays 8:43am PT (trig_01RacAcnw7VecbELYRQp7QvD). Opens PR with marketing/ directory (Play Store listing, Amazon listing, screenshot captions).
  - Remote triggers run in Anthropic cloud against GitHub repo, survive restarts
  - Local `/health` requires Jim to run it (needs Flutter SDK)
- **Manage triggers**: https://claude.ai/code/scheduled
- **Autonomy tiers**:
  - Tier 1 (full auto): lint fixes, test additions, unused imports, code comments
  - Tier 2 (do + PR for review): economy analysis, code review, GTM copy drafts
  - Tier 3 (propose only, wait for Jim): ANY user-facing change, economy values, UI, audio, onboarding
- **Blocked on**: Nothing
- **Next up**: Review first round of PRs from remote triggers, adjust prompts based on quality
- **Needs CEO decision**: None

---

## Open Decisions

### D-001: Ship now vs polish (2026-03-14)
**Context**: App at v7 with 30 UX fixes. v7 todo has 10 polish/refactor items.
**Decision**: SHIP NOW. Submit to Play Store immediately. Polish during 3-7 day review wait.
**Affects**: APP
**Status**: ACTIVE

### D-002: Freemium model (2026-03-14)
**Context**: Need pricing before Phase 2. Free = Worlds 1-2, Premium = all 10 + all heroes/weapons.
**Decision**: Freemium. Exact price TBD after user data. $4.99/mo or $29.99/yr as starting hypothesis.
**Affects**: APP, PRICING
**Status**: PENDING — needs user data first

### D-003: Feature freeze (2026-03-14)
**Context**: App has 10 worlds, 70 monsters, 6 heroes, 6 weapons. More than enough for launch.
**Decision**: ~~NO new features until 100 real users.~~ **REMOVED** (2026-03-15) — the app needs to keep improving. Features, bug fixes, and improvements all welcome.
**Affects**: APP
**Status**: REMOVED

---

## Blockers Tracker

| Blocker | Owner | Since | Impact | Status |
|---------|-------|-------|--------|--------|
| D-U-N-S number pending | Jim | 2026-03-20 | Blocks Google Play org account | DONE — 144980774 received 2026-03-29 |
| Google Play developer account (personal) suspended | Jim | 2026-03-14 | N/A — going org account route | DONE — org account registered under AnemosGP LLC (jim@anemosgp.com) 2026-04-01 |
| No Firebase Analytics events | APP | 2026-03-14 | Flying blind on retention | DONE — COPPA-compliant, 10 events instrumented |
| No privacy policy page | LANDING | 2026-03-14 | Blocks Play Store | DONE — COPPA 2025 + CCPA compliant, 10 sections, live |
| No email capture on landing page | LANDING | 2026-03-14 | Losing potential early adopters | DONE — Buttondown, platform-aware forms, QR code for desktop |

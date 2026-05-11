# Brush Quest — Android Launch Plan

> **Read this first at the start of every Android launch session.** Single source of truth for what's done, in flight, and blocked. Update as tasks complete. Don't re-derive state from `git`, `grep`, or memory files — trust the plan, fix it if you discover it's wrong.

**Goal:** Bring Brush Quest from "v20 LIVE on Internal Testing" through **Public Beta** → **Production** on Google Play Store, on Android's own technical timeline (independent of iOS).

**Approach:** Three-phase progression with independent decision gates. Phase 1 (Public Beta) is signal-focused, not volume-focused — target persona is iOS-skewed, so Android Phase 1 harvests retention/crash/feedback signal at modest scale (~30-50 engaged testers) to de-risk both Android Production AND the cross-platform GTM that follows iOS readiness. Phase 2 promotes Public Beta → Production based on quantitative gates. Phase 3 monitors Production health.

**Authoritative references (do not duplicate):**
- iOS plan: [`../ios-port/PLAN.md`](../ios-port/PLAN.md) — independent timeline, parallel
- Cross-platform GTM (fires when both stores at Production): [`../launch/CROSS-PLATFORM-GTM.md`](../launch/CROSS-PLATFORM-GTM.md)
- Crashlytics liveness: memory `project_crashlytics_status.md`
- Bundle ID: `com.brushquest.brush_quest` (Android — underscore is intentional)

---

## Status legend

- `[ ]` todo · `[~]` in progress · `[x]` done · `[!]` blocked
- **T1** Claude executes autonomously · **T2** Claude executes, Jim reviews via PR · **T3** Claude proposes, Jim approves first
- **C** Claude (code, scripts, automation) · **J** Jim (manual UI / portal / console)

Format per task: `- [status] (tier·owner) ID. Title — short note`

---

## Pre-flight: already shipped (do not redo)

- [x] v20 (1.0.0+20) LIVE on Internal Testing track since 2026-04-21
- [x] Closed Testing track "Alpha" submitted for review 2026-04-23 (4 countries: US/CA/UK/AU; tester gate: Google Group `brush-quest-testers@googlegroups.com`)
- [x] Listing overhaul submitted 2026-04-23: title `Brush Quest: Kids Toothbrush`, short desc, full desc grammar, 8 fresh phone screenshots
- [x] Promo video shipped 2026-04-27: 26s with 6-line parent voiceover, Unlisted YouTube `https://youtube.com/watch?v=XwkGoLBKW4A`, linked in Play Console listing
- [x] Public Beta (Early Access track) submitted 2026-04-28: 4 countries, v20 release, open invites unlimited, feedback channel `jim@anemosgp.com` — 7 changes in Google review queue
- [x] COPPA compliance: 10 declarations actioned, AD_ID permission removed, privacy policy COPPA-compliant
- [x] Firebase Analytics confirmed flowing (17 users in 30d; Crashlytics liveness deferred — see Phase 1)
- [x] Telegram bot LIVE for monitoring (`tg send`)
- [x] LLC + EIN + D-U-N-S + Mercury bank — admin layer complete (AnemosGP LLC, EIN 41-5007192, D-U-N-S 144980774)

---

## Phase 1 — Public Beta operations (now → ~6 weeks)

> **Purpose:** Harvest signal at small scale to de-risk Production launch. Target ~30-50 engaged testers, not hundreds. Quality of feedback > volume of installs. iOS-skewed personas means we deliberately avoid Nicole's network during this phase — it fires in Cross-Platform GTM Timeline C.

### 1A — Crashlytics liveness validation ✅ COMPLETED 2026-04-28

- [x] (T3·C) **1A-1.** Added debug-only 5-tap-on-version-string gesture in `lib/screens/settings_screen.dart`, behind `kDebugMode`. `recordError(Exception('crashlytics_smoke_test'), fatal: false)` + SnackBar confirmation.
- [x] (T1·J) **1A-2.** Debug APK built (`gdrive:BrushQuest/brush-quest-v20-debug-crashlytics-smoketest.apk`, 215 MB) and installed by Jim. Smoke test fired and event verified in Firebase Crashlytics console.
- [x] (T1·C) **1A-3.** Code reverted (git diff empty, dart analyze clean). Memory `project_crashlytics_status.md` updated with `last_verified: 2026-04-28` and SDK-liveness-confirmed status.

### 1B — Public Beta launch (post-Google-review)

- [ ] (T1·J) **1B-1.** Wait for Public Beta review approval (~24-48h from 2026-04-28 submission). Telegram notification will fire when Google emails approval.
  - Acceptance: Public Beta status shows "Active" with public opt-in URL accessible.
- [ ] (T1·C) **1B-2.** Capture the public opt-in URL (typical format: `https://play.google.com/store/apps/details?id=com.brushquest.brush_quest`) and add it to STATUS.md + this plan as the canonical Android Phase 1 URL.
  - Depends on: 1B-1.
- [ ] (T2·C) **1B-3.** Verify the URL works for an unauthenticated browser (incognito) — confirm "Early Access" badge displays and install button is functional from US Play Store.
  - Depends on: 1B-2.

### 1C — Android-skewed distribution (Phase 1 channels)

> **Constraint reminder:** target personas (Alameda parent peer group) are iOS-skewed. Phase 1 channels are deliberately ≠ those personas. Do not use Nicole's Facebook here. These channels harvest signal, not target market.

- [ ] (T2·C) **1C-1.** Print pediatric dentist flyer (8.5×11", QR code → Public Beta URL, 3 sentences of copy, branding consistent with app icon). Source quote: "Brush Quest helps your kids actually want to brush — built by a dad in California."
  - Acceptance: PDF generated, QR scans correctly to Public Beta URL.
  - Depends on: 1B-2.
- [ ] (T1·J) **1C-2.** Drop flyer at 3 Alameda pediatric dentist offices (in-person walk-in; ask front desk to keep on counter). Track which offices accept.
  - Acceptance: 2-3 offices have flyer on counter.
  - Depends on: 1C-1.
- [ ] (T2·C) **1C-3.** Draft NextDoor post (neighborly tone, 200 words max, link to Public Beta URL). Different from Reddit/Facebook drafts — emphasizes "local Alameda dad," asks for honest feedback, not hard install ask.
  - Acceptance: draft saved at `docs/android-launch/copy/nextdoor.md`.
  - Depends on: 1B-2.
- [ ] (T1·J) **1C-4.** Post NextDoor draft to Alameda + adjacent neighborhood feeds. Monitor for first 24h.
  - Depends on: 1C-3.
- [ ] (T2·C) **1C-5.** Identify 2-3 Discord beta-tester servers (Google Play Beta, Android Beta Apps, indie-dev beta groups). Validate they allow recruitment posts.
  - Acceptance: list of servers + their posting rules saved at `docs/android-launch/copy/discord-channels.md`.
- [ ] (T1·J) **1C-6.** Join 2-3 Discord servers from 1C-5; post draft + Public Beta URL.
  - Depends on: 1C-5, 1B-2.
- [ ] (T2·C) **1C-7.** Reddit karma rebuild plan: 1-2 weeks of helpful comments in r/AlphaAndBetaUsers, r/TestMyApp, r/Daddit (no original posts about Brush Quest). Target: 50+ karma before re-attempting Brush Quest post. Track in a simple log.
  - Acceptance: log doc started; ground rules documented.

### 1D — Tester feedback loop

- [ ] (T2·C) **1D-1.** Set up shared spreadsheet or Notion page for tester feedback intake. Columns: tester name/email (or anonymous), source channel, install date, app version, feedback text, severity (P0/P1/P2/P3), status (open/triaged/fixed/declined).
  - Acceptance: doc URL captured in this plan.
- [ ] (T1·J) **1D-2.** Personally email/DM each tester within 48h of install: thank them, ask 2 specific questions ("What was the moment your kid first lit up?" + "What felt rough?"). One-on-one outreach, not mass mail.
  - Cadence: ongoing during Phase 1.
- [ ] (T1·J) **1D-3.** Weekly review: read all new feedback, triage to severity, update intake doc, add to backlog if it requires code change.

### 1E — Phase 1 metrics baseline

- [ ] (T2·C) **1E-1.** Document the baseline metrics dashboard: Firebase Analytics 30-day active users, day-1 retention, day-7 retention, average session length, screens-per-session. Capture as snapshot at end of Phase 1 week 1.
  - Acceptance: snapshot saved at `docs/android-launch/metrics/phase1-week1.md`.
- [ ] (T2·C) **1E-2.** Configure Crashlytics weekly summary email or scheduled check. Record any crashes that surface — with version, stacktrace, repro steps.
  - Depends on: 1A-3 (Crashlytics liveness verified).

---

## Phase 2 — Production launch readiness gates

> **Decision gate, not a date.** Promote Public Beta → Production when ALL gates pass. If a gate fails, fix the underlying issue or stay in Public Beta longer. Don't time-box this — quality > schedule.

### 2A — Quantitative gates (must pass before promoting)

- [ ] (T1·J) **2A-1.** Crash-free user rate ≥ 99.5% sustained over the most recent 14 days, version code 20+ only.
- [ ] (T1·J) **2A-2.** Day-7 retention ≥ 25% (cohort size ≥ 20 users).
- [ ] (T1·J) **2A-3.** Day-1 retention ≥ 50% (cohort size ≥ 30 users).
- [ ] (T1·J) **2A-4.** Average session length ≥ 90s (excludes brushing time which IS the session for many).
- [ ] (T1·J) **2A-5.** No P0 (crash, data loss, money/billing) bug open. ≤2 P1 (UX-breaking on common path) bugs open.
- [ ] (T1·J) **2A-6.** ≥ 25 unique testers reached, ≥ 10 with at least 2 sessions, ≥ 5 with written qualitative feedback.

### 2B — Qualitative gates (judgment calls Jim makes)

- [ ] (T1·J) **2B-1.** Feedback signal is mostly positive AND specific (not generic "looks great"). Specific feedback ≥ generic feedback.
- [ ] (T1·J) **2B-2.** ≥ 1 unsolicited "my kid loves it" or equivalent moment captured in writing (testimonial-grade).
- [ ] (T1·J) **2B-3.** Oliver retest of latest version still passes Jim's parent-CUJ checklist.
- [ ] (T1·J) **2B-4.** No surprise on either side (Apple Business approval / iOS launch timing) that would make a coordinated launch dramatically better in the next 2-4 weeks. If iOS is imminent, decision shifts to Cross-Platform GTM Timeline C.

### 2C — ASO + listing finalization

- [ ] (T2·C) **2C-1.** Keyword research review: validate the current title `Brush Quest: Kids Toothbrush` against actual Play Store search-volume data (Google Play Console "Acquisition reports" once Public Beta has data).
- [ ] (T2·C) **2C-2.** A/B test screenshot order via Play Experiments (in-console feature). Test current order vs. lead-with-victory variant. Run 1 week minimum.
- [ ] (T1·J) **2C-3.** Draft first response template for negative reviews (parent-friendly, empathetic, 2-3 sentences). Save at `docs/android-launch/copy/review-responses.md`.

---

## Phase 3 — Production launch + monitoring

> **Trigger:** Phase 2 gates pass AND (a) iOS is still ≥ 4 weeks out — Android Production launches solo OR (b) iOS is imminent (≤ 2 weeks) — defer to Cross-Platform GTM Timeline C for synchronized launch.

### 3A — Promotion mechanics

- [ ] (T1·J) **3A-1.** In Play Console, promote Public Beta release v20 (or whatever current version is) to Production track. Same 4 countries + add any others Jim wants.
- [ ] (T1·J) **3A-2.** Set staged rollout: 1% → monitor 48h → 10% → monitor 48h → 50% → monitor 48h → 100%.
- [ ] (T1·J) **3A-3.** Send Production for review. Typical review window: 1-7 days for kids apps.

### 3B — Production-specific GTM (when launching solo)

> If Cross-Platform GTM Timeline C is firing instead, skip 3B and execute that plan.

- [ ] (T2·C) **3B-1.** Update YouTube promo video description with Production install URL.
- [ ] (T2·C) **3B-2.** Update privacy policy + landing page with "Available on Google Play" badge.
- [ ] (T2·C) **3B-3.** Submit to Android-only press: AndroidPolice tip line, AndroidAuthority kids-app coverage, niche dental-parent blogs (research list at `docs/android-launch/copy/press-list.md`).
- [ ] (T1·J) **3B-4.** Reddit re-attempt with built karma: post in r/AlphaAndBetaUsers, r/AndroidGaming with Production framing ("now publicly available"). Less likely to be auto-removed than the Public Beta era.

### 3C — Production health monitoring

- [ ] (T1·J) **3C-1.** Daily check (during rollout): Crashlytics dashboard, Play Console reviews, Firebase Analytics ramp.
- [ ] (T1·J) **3C-2.** Respond to every review within 24h using template from 2C-3.
- [ ] (T1·J) **3C-3.** Weekly metrics summary saved at `docs/android-launch/metrics/production-week-N.md` for first 12 weeks.

---

## What's NOT in this plan (handled elsewhere)

- iOS development, signing, App Store review → [`../ios-port/PLAN.md`](../ios-port/PLAN.md)
- Nicole's Facebook campaign + Substack pitches + paid acquisition → [`../launch/CROSS-PLATFORM-GTM.md`](../launch/CROSS-PLATFORM-GTM.md)
- **Brand defense workstream (Apple App Store name conflict, trademark filing, domain + social handle locks, `.com` snipe) → [`../brand/PLAN.md`](../brand/PLAN.md).** Conflict findings may force a rebrand which would invalidate this plan's listing assumptions.
- Monetization decisions → memory `decision_product_strategy_2026_03.md`
- App development cycles (UX iteration, bug fixes) → `/cyclepro` workflow

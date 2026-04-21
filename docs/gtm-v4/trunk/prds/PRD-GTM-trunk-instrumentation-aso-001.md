---
id: PRD-GTM-trunk-instrumentation-aso-001
title: Pillar 1 — Retention instrumentation + ASO polish (Cycle 16.5, Week 1)
parent_question: "Reach weekly-active kids (WAK) brushing by 2026-07-20 via agentic execution on $1–2K budget — how do we measure D1/D7/D30 retention joined to install source, and polish the Play listing, before any distribution spend fires?"
parent_node: trunk
tier: 1
status: draft
owner_agent: instrumentation-eng-agent
budget:
  dollars: 50
  tokens: 800000
  agent_hours: 25
  jim_hours: 12
timeline:
  start: 2026-04-22
  checkpoints: [2026-04-25, 2026-04-28]
  end: 2026-04-29
depends_on: []
blocks:
  - _meta-prd-pillar-2-dentists.md
  - _meta-prd-pillar-3a-earned-media.md
  - _meta-prd-t2a-newsletter-pilot.md
  - _meta-prd-t2b-text-chain.md
  - _meta-prd-t2c-youtube-kids.md
  - _meta-prd-t2e-micro-creator.md
  - PRD-GTM-trunk-cross-promo-outreach-001.md
experiments: []
created: 2026-04-21
last_updated: 2026-04-21
---

## Goal

By Day 7 (2026-04-29), `Play Install Referrer → UTM → PostHog/Amplitude cohort`
join event is visible in the cohort dashboard for at least one real install, AND
the public Google Play listing has shipped ASO-polished copy + screenshots
(including a CSM-badge placeholder for later swap).

## Context brief

### Product state (what's live)
- Brush Quest v1.0.0+17 is LIVE on Google Play internal testing (2026-04-11)
  and has been SUBMITTED for Play public review (1–7 day window — likely
  clearing any day now).
- 774+ tests, `dart analyze` clean. Codebase Flutter/Dart.
- Metrics currently tracked: total brushes, streak, daily brushes, stars,
  Ranger Rank, wallet, brush history, Firebase Auth events, Firestore sync,
  Play Console installs/uninstalls/rating.
- Metrics NOT tracked: marketing attribution (UTM + Play referrer match),
  retention cohorts (D1/D7/D30 WAK — data exists, no dashboard), per-channel
  install attribution, parent touchpoints (email capture source, QR scan
  source). This PRD closes all four gaps.
- Landing page live at brushquest.app (Buttondown email capture, QR code).
  `/rangers` bridge page exists in scaffolded form; A/B scaffolding needed.
- Cycle 16 (UX) is explicitly DEFERRED one week to make room for this work
  (synth-final §7 sequencing, binding). `tg send` to Jim confirms deferral
  before Week 1 begins.

### Target persona
Internal: instrumentation is for the team (Jim + agents). No end-user shipped
surface changes except the ASO polish + Play listing screenshots. Parents
continue to see the Play listing; ASO polish (icon, screenshots, description,
CSM-badge placeholder, keyword density) lifts store_listing_conv ~3× per L5.

### Constraints
- COPPA strict. No child PII in any event payload. User-level identifiers are
  Firebase Auth UID (opaque). Parent email (if captured via Buttondown) lives
  only server-side.
- No ads in app; no prompts to children; Brush Quest+ $9.99 one-time + star
  packs are the only monetization and are already locked.
- Voice: Buddy (George) only.
- Home screen is minimal (feedback_home_screen_clean.md) — do not add any
  start affordance or CTA. Instrumentation is non-visible to user.

### Prior decisions from `_synth-final.md` (binding)
1. Play Install Referrer join event — not "dashboard live" — is the
   acceptance criterion (synth-final §3 Pillar 1, §7 sequencing, §8 #4).
2. Every outbound link / sponsorship / pitch / creator gift carries a unique
   `utm_source={channel}_{subchannel}_{id}` (synth-final §8 #15).
3. `brushquest.app/rangers` is the binding destination-URL bridge for all
   social-origin traffic until explicitly A/B-tested and retired (§8 #14).
4. Pillar 2 device-stitch fallback: email capture at QR → Firebase Auth
   sign-in event match. This PRD ships the attribution primitive;
   pillar-2 meta-PRD consumes it (§8 #16).
5. Buttondown UTM → subscriber attribution glue is a sub-task of this PRD
   (synth-final §8 #28, E3 gap #4).
6. CSM badge placeholder on store-listing screenshot — the screenshot slot
   is reserved now; badge image swapped in when CSM approves (§8 #21).

### What's been tried
- Firebase Auth events + Firestore sync events already fire and are visible
  in Firebase console. Event volume is healthy.
- Play Console referrer data appears in raw install reports but is not
  joined to any in-app event.
- No cohort dashboard exists.

## Inputs required

- Play Console credentials (stored; Jim has access — agent pauses for
  human-in-loop confirmation before modifying ASO listing).
- Firebase/Firestore project admin (`brush-quest` project).
- PostHog OR Amplitude free-tier account (agent creates; $0 tier).
- Buttondown API key (existing integration).
- Landing page repo access (`brushquest.app` repo) — for `/rangers` A/B
  scaffolding.
- Google Play Install Referrer library for Android (`com.android.installreferrer:installreferrer`).
- Tools/MCPs:
  - Bash (Flutter SDK local; JDK 17; `flutter build appbundle`)
  - Web (PostHog/Amplitude docs; Install Referrer docs)
  - Firebase console access (manual confirm steps allowed via `tg send`)

## Outputs required

### Code artifacts
- `lib/services/attribution_service.dart` — new service that reads Install
  Referrer on first launch, parses `utm_source` / `utm_medium` / `utm_campaign`,
  persists to `shared_preferences`, and forwards to analytics event
  `install_attributed` (fires once per install).
- `lib/services/analytics_service.dart` — PostHog or Amplitude wrapper.
  Events: `install_attributed`, `brush_completed`, `day_1_returning`,
  `day_7_returning`, `day_30_returning`, `parent_email_captured`.
- `pubspec.yaml` — add `install_referrer` (or equivalent) + analytics SDK.
- Landing page: `/rangers` route A/B scaffolding with variant persistence
  via URL param + cookie.

### Dashboard / config artifacts
- PostHog (or Amplitude) cohort dashboard: D1 / D7 / D30 returning-brush
  cohort by `utm_source`. Saved as shareable public URL.
- Buttondown: subscriber custom-field `utm_source` populated on signup;
  Zapier or webhook glue so `email_captured` event carries source.

### ASO artifacts
- 6 updated Play Store screenshots (5+ kid-visible gameplay; screenshot #1
  reserves a CSM-badge slot — placeholder art OK, real badge swapped in when
  CSM approves).
- Updated Play listing short description (80 chars) + long description
  (~3000 chars) focused on nightly-fight parent feel (synth-final §8 #18).
- Keyword targets: toothbrushing app, kids brushing timer, tooth brush
  timer, cavity fighter, space ranger kids, COPPA-safe kids app.

### Data artifacts
- `trunk/_data/attribution_events_baseline.yaml` — first 48h of events
  post-ship for sanity check.
- `trunk/_data/aso_baseline.yaml` — store_listing_conv, install rate,
  uninstall rate at moment ASO polish ships (t0 baseline).

### Docs
- `docs/gtm-v4/trunk/prds/_pillar1_runbook.md` — how to read the dashboard,
  what "join visible" looks like, how to add a new `utm_source`.

## Acceptance criteria

- [ ] Play Install Referrer library integrated and firing on first launch.
- [ ] One real install carries `utm_source` value end-to-end: Play Console
      referrer → Install Referrer API → `install_attributed` event → PostHog
      (or Amplitude) cohort row. Screenshot of the joined row attached to
      this PRD before marking done.
- [ ] D1 / D7 / D30 returning-brush cohort chart in dashboard is live, with
      at least 1 row per metric (can be sparse — real cohort data at 30d
      lands later; chart must render and query must be saved).
- [ ] Buttondown signup writes `utm_source` to subscriber custom field; test
      signup via `brushquest.app/rangers?utm_source=test_pillar1_001` shows
      up with source in Buttondown UI.
- [ ] Public Play Store listing updated (post public-review-clear) with
      new screenshots + description; ASO metrics baseline captured.
- [ ] `brushquest.app/rangers` A/B scaffolding live with two variants and
      variant persistence; both variants render at 375px / 768px / 1440px.
- [ ] `dart analyze` clean, `flutter test` passes, no new warnings.
- [ ] `tg send` to Jim when the end-to-end join is first observed.
- [ ] Runbook doc written at `docs/gtm-v4/trunk/prds/_pillar1_runbook.md`.
- [ ] No COPPA issue: no child PII in any analytics event. Privacy policy
      updated if new SDK warrants (Jim approves one-time).

## Metrics

- **Primary:** boolean — "Install Referrer → UTM → cohort dashboard join
  event visible for ≥1 real install" by 2026-04-29.
- **Secondary:**
  - `store_listing_conv` lift vs. baseline at t+7d and t+14d (post-ASO).
  - Count of `install_attributed` events in 7d window.
  - Count of distinct `utm_source` values observed in 7d window.
- **Attribution window:** 28 days (Install Referrer horizon).
- **Measurement system:** PostHog/Amplitude dashboard (primary),
  `trunk/_data/attribution_events_baseline.yaml` (archival), Play Console
  (referrer report baseline).

## Tools the executor needs

- Bash (Flutter build, git, `flutter test`, `dart analyze`)
- PostHog or Amplitude dashboard UI (manual confirm steps allowed)
- Google Play Console (Jim-gated ASO upload — one approval point)
- Buttondown API / webhook config (existing key)
- Firebase console (read-only sanity checks)
- `tg send` for escalation
- Human-in-loop approvals:
  1. Choice of analytics SDK (PostHog vs Amplitude) — Jim picks; agent
     posts pros/cons.
  2. Final Play listing copy/screenshots — Jim approves upload.
  3. Privacy policy update if new SDK requires — Jim approves text.

## Escalation triggers

Executor pauses and `tg send`s Jim when:
- Agent-hours ≥ 20 (80% of 25-hr ceiling) before acceptance met.
- Day 5 arrives and no end-to-end join is yet observable in test.
- Install Referrer API returns permission denied or deprecated error.
- Any analytics SDK requires opt-in consent UI (COPPA interaction).
- Play Console upload is blocked / flagged.
- Any `dart analyze` warning introduced that can't be resolved in <1 hour.
- Day 10 arrives without acceptance — escalates to Cycle 17 deferral
  discussion (synth-final §7 sequencing — hard block on downstream pillars).

## Risks + mitigations

- **Risk:** Install Referrer API has a 90-day (or shorter) window and
  `PENDING` race on cold starts. → **Mitigation:** retry on next launch
  until non-`PENDING` result or window expiry; log failures.
- **Risk:** Play public review clears mid-cycle and ASO copy is stale by
  the time screenshots are ready. → **Mitigation:** ship listing text
  update (fast) separately from screenshot upload (slower); gate screenshot
  upload behind Jim approval even if it slips into Week 2.
- **Risk:** PostHog/Amplitude free tier caps ingestion. → **Mitigation:**
  sample at 10% for non-cohort events if volume spikes; all cohort-defining
  events (`install_attributed`, `brush_completed`) are unsampled.
- **Risk:** Buttondown webhook reliability → **Mitigation:** fallback
  direct-API call from Flutter on signup + client-side retry queue.
- **Risk:** agent-hours blow past 25 on SDK integration edge cases. →
  **Mitigation:** at 20 hrs, ship the Install Referrer join alone; defer
  D30 cohort viz to a follow-on hotfix PRD.
- **Risk:** COPPA concern on new analytics SDK. → **Mitigation:** verify
  SDK does not auto-collect advertising ID; configure SDK for
  children's-data compliance mode (PostHog: no session recording,
  no autocapture, hashed UIDs only).

## Change log

- 2026-04-21 Created PRD-GTM-trunk-instrumentation-aso-001 from
  `_synth-final.md` §3 Pillar 1 (all 6 gate criteria hold at trunk freeze).

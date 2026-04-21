# Context for loop at trunk

## Question

Reach **1,000 weekly-active kids brushing** with Brush Quest by **2026-07-20**
(90 days from today, 2026-04-21), via **agentic GTM execution** on a
**$1,000–$2,000 total launch budget**, with Brush Quest live on **Google Play
(public)** and **iOS TestFlight / App Store** by that date.

**Node path:** `trunk`
**Loop kind:** trunk-level portfolio loop (question B). First real loop after
the C-pass validation at `trunk/marketing/ugc/instagram-reels`.

## Master brief (current state — 2026-04-21)

### Product

- Kids' toothbrushing app. Space Rangers vs Cavity Monsters theme. Gamified
  2-min timer (4 configurable quadrants), defeat monsters, earn stars, unlock
  heroes + weapons + worlds.
- Target user: kids 4–8 (primary: 7yo boys). Primary testers: Oliver (7),
  Theo (3).
- Platforms: Android (Flutter) — LIVE on Google Play internal testing since
  2026-04-11. Public Play review submitted 2026-04-11 (1–7 day window — likely
  clearing any day now). iOS — scaffolded + SignInWithApple wired, Apple
  Business in review since 2026-04-17 (expected ~2026-04-24). iOS TestFlight
  target: 2–4 weeks out.
- Current build: v1.0.0+17 (Cycle 15 added 13 T3 UX fixes; v19 in flight per
  landing metadata). 774+ tests, `dart analyze` clean.
- Locked decisions:
  - Voice: Buddy (George) only for v1 launch.
  - Economy prices locked until multi-profile ships.
  - Monetization: Free (4 worlds / 3 heroes / 3 weapons) + Brush Quest+ $9.99
    one-time for full content. Star packs $0.99 / $2.99 / $4.99 in parent
    settings. NO ads, NO subscription, NO in-app prompts to children.
  - Content approach: curated AND user-generated both acceptable.

### Business

- LLC: AnemosGP LLC (EIN 41-5007192, D-U-N-S 144980774).
- Google Play org VERIFIED (jim@anemosgp.com).
- Apple Developer (Business) in review.
- Amazon Appstore pending identity verification (case 19804300171).
- Bank: Mercury.
- Budget for launch GTM: $1,000–$2,000 TOTAL over the 90-day window.
- Founder: Jim Chabas. Solo, NOT full-time (has other job). ~5–10 hrs/week
  for GTM. Willing to hire eventually but for now agentic execution
  wherever possible.
- Face of the brand: NOT Jim (hire if revenue allows).

### Constraints

- COPPA-strict. No child PII in marketing. No child face/name in shareable
  artifacts (hero character = proxy).
- No ads inside the app. Marketing may run ads targeting parents.
- Brand tone: warm, practical, slightly irreverent about "brushing is
  miserable." Never patronizing. Never "screen time is bad."

### Distribution surfaces

- Google Play — internal testing LIVE; public review submitted 2026-04-11.
- iOS App Store — scaffolded, awaiting Apple Business + TestFlight.
- Amazon Appstore — pending identity verification.
- Direct APK — possible, not prioritized.
- Landing page — live at brushquest.app (QR code, email capture via Buttondown).

### Prior GTM work

- `docs/gtm-engine/GTM_ENGINE_v3.md` + `rounds/` — 10,304 lines from
  2026-04-03. Pre-launch synthesis. Treat as L4 pattern-matching input.
- Weekly GTM-prep Railway trigger Wed 8:43am PT (opens PR with drafts). To
  be reconciled with this factory later.
- C-pass validation loop completed at `trunk/marketing/ugc/instagram-reels`
  (2026-04-20). Produced 2 PRDs + 6 meta-PRDs. Key emergent insight from
  L5: Play Store internal-testing URL is a funnel-killer (5-step Google-
  group flow looks like phishing to non-technical parents);
  `tester_signup_rate` likely <10%. Every Reels-facing bet in that loop now
  routes through a `brushquest.app/rangers` email-capture bridge. **This
  destination-URL rule is likely to be a binding trunk-level decision too.**

### Metrics already tracked

Total brushes, best streak, daily active brushes, stars earned, Ranger Rank,
wallet balance, brush history timestamps, Firebase Auth events, Firestore
sync events, Play Console installs/uninstalls/rating.

### Metrics NOT yet tracked (gaps to name in PRDs that need them)

- Marketing attribution (UTM + Play referrer match)
- Retention cohorts (D1/D7/D30 WAK) — data exists, no dashboard
- Per-channel install attribution
- Parent touchpoints (email capture source, QR scan source)

### What's live in parallel to this GTM work

- Play Store public review (submitted 2026-04-11; 1–7 day window)
- iOS TestFlight prep (Apple Business approval expected ~2026-04-24)
- Cycle 15 UX fixes just shipped (0a1eba5)
- Oliver v17/v19 retest feedback loop (informal)

## Decisions log (cross-node)

- v4 supersedes v3 OUTPUT shape; v3 inputs still usable as L4 pattern-match
  source.
- Carried forward from v3 (binding): budget $1–2K, curated + UGC content,
  founder not full-time, face-of-brand not Jim, COPPA strict, no ads in app,
  no purchase prompts to children.
- Superseded vs v3: v3 assumed pre-launch — we are LIVE on Play internal
  testing; v3's 2026-04-11 free-launch target has passed; timeline anchor is
  now 2026-07-20 (90 days); iOS was out-of-scope in v3 but v4 plans iOS
  launch inside 90-day window.
- Phase 1 of this factory is complete (C-pass validation shipped). This
  trunk loop is the first real use.
- Emergent from C-pass: destination-URL matters more than creative quality
  for Reels; email-capture bridge at brushquest.app/rangers is blocking for
  any social-originated bet while internal-testing is the only Play surface.

## Ancestor synth-finals

None. This is trunk.

## Ancestor meta-PRDs

None.

## Sibling loops already run

- `trunk/marketing/ugc/instagram-reels/` — C-pass validation (2026-04-20).
  Findings should inform but NOT bind the trunk plan (the validation was
  designed to test the machine, not to decide the portfolio). Trunk loop
  is free to de-prioritize Instagram Reels entirely if Tier-1 belongs
  elsewhere.

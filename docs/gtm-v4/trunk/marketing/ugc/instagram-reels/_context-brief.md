# Context for loop at trunk/marketing/ugc/instagram-reels

## Question

Produce a complete set of agent-executable PRDs to get 50 qualified parent
installs to Play Store internal testing in 14 days via organic Instagram
Reels, and hand them to executor agents to run.

**Node path:** `trunk/marketing/ugc/instagram-reels`
**Loop kind:** C-pass validation (narrow, exercises every gate).

## Master brief (current state — 2026-04-20)

### Product

- Kids' toothbrushing app. Space Rangers vs Cavity Monsters theme. Gamified
  2-min timer (4 configurable quadrants), defeat monsters, earn stars, unlock
  heroes + weapons + worlds.
- Target user: kids 4–8 (primary: 7yo boys). Primary testers: Oliver (7),
  Theo (3).
- Platforms: Android (Flutter) — LIVE on Google Play internal testing since
  2026-04-11. iOS — scaffolded + SignInWithApple wired, Apple Business in
  review since 2026-04-17 (expected ~2026-04-24). iOS TestFlight target: 2–4
  weeks out.
- Current build: v1.0.0+17. 774 tests. `dart analyze` clean.
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
- Amazon Appstore pending identity verification.
- Bank: Mercury.
- Budget for launch GTM: $1,000–$2,000 TOTAL.
- Founder: Jim Chabas. Solo, NOT full-time (has other job). Willing to hire
  but for now agentic execution wherever possible.
- Face of the brand: NOT Jim (hire if revenue allows).

### Constraints

- COPPA-strict. No child PII in marketing. No child face/name in shareable
  artifacts (hero character = proxy).
- No ads inside the app. Marketing may run ads targeting parents.
- Brand tone: warm, practical, slightly irreverent about "brushing is
  miserable." Never patronizing. Never "screen time is bad."

### Distribution surfaces

- Google Play — internal testing LIVE, submitted for public review 2026-04-11.
- iOS App Store — scaffolded, awaiting Apple Business + TestFlight.
- Amazon Appstore — pending identity verification.
- Direct APK — possible, not prioritized.
- Landing page — live at brushquest.app (QR code, email capture live).

### Prior GTM work

- `docs/gtm-engine/GTM_ENGINE_v3.md` + `rounds/` — 10,304 lines from
  2026-04-03. Pre-launch synthesis. Treat as reference input, not binding.
- Weekly GTM-prep Railway trigger Wed 8:43am PT (opens PR with drafts). To
  be reconciled with this factory later.

### Metrics already tracked

Total brushes, best streak, daily active brushes, stars earned, Ranger Rank,
wallet balance, brush history timestamps, Firebase Auth events, Firestore
sync events, Play Console installs/uninstalls/rating.

### Metrics NOT yet tracked (gaps to name in PRDs that need them)

- Marketing attribution (UTM + Play referrer match)
- Retention cohorts (D1/D7/D30 weekly-active kids, WAK) — data exists, no dashboard
- Per-channel install attribution
- Parent touchpoints (email capture source, QR scan source)

### What's live in parallel to this GTM work

- Play Store public review (submitted 2026-04-11; 1–7 day window)
- iOS TestFlight prep (Apple Business approval pending)
- Oliver v17 retest feedback loop (informal)

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
- Phase 1 of this factory: validation loop only (this run). Trunk loop runs
  next. Feedback loops (A/B/C), experiments execution, dashboard are
  follow-on plans.

## Ancestor synth-finals

None. Trunk loop and intermediate branch loops have not yet run. This
validation loop runs standalone as a C-pass.

## Ancestor meta-PRDs

None.

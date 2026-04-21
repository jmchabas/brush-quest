# Master Brief — Brush Quest as of 2026-04-20

> Refreshed automatically before each new loop. Every agent (lens, evaluator, synth)
> receives this as context along with any ancestor `_synth-final.md` files.

## Product

- **What it is:** Kids' toothbrushing app. Theme: Space Rangers vs Cavity Monsters.
  Gamified 2-minute timer (4 configurable quadrants), defeat monsters, earn stars,
  unlock heroes + weapons + worlds.
- **Target user:** Kids aged 4–8 (primary: 7yo boys). Primary testers: Oliver (7) and
  Theo (3).
- **Platforms:** Android (Flutter) — LIVE on Google Play internal testing as of
  2026-04-11. iOS — scaffolded + SignInWithApple wired, Apple Business org in review
  since 2026-04-17 (expected ~2026-04-24). iOS TestFlight target: ~2–4 weeks out.
- **Current build:** v1.0.0+17. 774 tests. `dart analyze` clean.
- **Key product decisions locked:**
  - Voice: Buddy (George) only for v1 launch — others in backup.
  - Economy prices: locked until multi-profile ships.
  - Monetization: Free tier (4 worlds / 3 heroes / 3 weapons) + Brush Quest+ $9.99
    one-time for full content. Star packs $0.99 / $2.99 / $4.99 in parent settings.
    NO ads ever. NO subscription. No in-app purchase prompts shown to children.
  - Content approach: curated and user-generated both acceptable.

## Business

- **LLC:** AnemosGP LLC (formed, EIN 41-5007192, D-U-N-S 144980774).
- **Google Play:** Org account VERIFIED (jim@anemosgp.com).
- **Apple Developer (Business):** In review. Expect 2026-04-24.
- **Amazon Appstore:** Identity verification pending (case 19804300171).
- **Bank:** Mercury.
- **Budget for launch GTM:** $1,000–$2,000 total.
- **Founder:** Jim Chabas. Solo, not full-time (has another job). Willing to hire,
  but for now: agentic execution wherever possible.
- **Face of the brand:** Not Jim. If revenue covers it, hire a face later.

## Constraints

- **COPPA-strict.** No child personally identifiable data in marketing. No child name
  or face in shareable artifacts (hero character serves as proxy).
- **No ads inside the app.** Marketing may run ads targeting parents.
- **Brand tone:** warm, practical, slightly irreverent to the "brushing is miserable"
  parent experience. Never patronizing. Never "screen time is bad."

## Distribution surfaces (status as of 2026-04-20)

- Google Play — internal testing LIVE, submitted for public review 2026-04-11
- iOS App Store — scaffolded, awaiting Apple Business + TestFlight
- Amazon Appstore — pending identity verification
- Direct APK — possible, not prioritized
- Landing page — live at brushquest.app (active, QR code present, email capture live)

## Prior GTM work

- `docs/gtm-engine/GTM_ENGINE_v3.md` + `rounds/` — 10,304 lines from 2026-04-03. Pre-
  launch synthesis. Treat as one reference input, not a binding plan. Some assumptions
  (pre-launch) are now stale.
- Weekly GTM-prep Railway trigger runs Wednesdays 8:43am PT (opens PR with marketing
  drafts). To be reconciled with this factory later.

## Metrics already tracked

- Total brushes, best streak (per user)
- Daily active brushes
- Stars earned, Ranger Rank, wallet balance
- Brush history timestamps
- Firebase Auth events (sign-in rate)
- Firestore sync events (user count with cloud sync)
- Play Console: installs, uninstalls, rating

## Metrics not yet tracked (gaps to name in PRDs that need them)

- Marketing attribution (UTM + Play referrer match)
- Retention cohorts (D1/D7/D30 WAK) — data exists, no dashboard
- Per-channel install attribution
- Parent touchpoints (email capture source, QR scan source)

## What's live in parallel to any GTM work

- Play Store public review (2026-04-11 submitted; 1–7 day window)
- iOS TestFlight prep (Apple Business approval pending)
- Oliver v17 retest feedback loop (informal, ad-hoc)

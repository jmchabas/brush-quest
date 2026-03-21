# Brush Quest — Status Board
<!-- Every session reads this at start. Every session updates its section at end. -->
<!-- Jim says "update the status board" → session updates its workstream below. -->

**Current #1 Priority**: Get the app on Google Play Store. Nothing else matters.
**CEO Streak**: Week 0 (starting fresh)
**Phase**: 0 — Pre-Launch

---

## Workstream Status

### APP
- **Status**: Cycle 6 shipped — 30 findings across 9 streams, onboarding overhaul, victory flow, home UX, 4 new voice arcs + 651 tests
- **Last session**: 2026-03-20
- **Last commit**: `e9cb7d5` — Cycle 6 implementation (30 findings, 9 streams)
- **What happened**:
  - **Onboarding**: comic-strip how-to-play (no step numbers), animated quadrant cycling on mouth guide
  - **Victory screen**: PopScope blocks exit, voice-chained chest sequence, power-up voice on dups, milestone voices at 70/80/90 stars, legendary ranger badge
  - **Home screen**: nav hidden until first brush, voice_tap_hero for new users, 15% bigger hero, "NEW!" streak badge, voice-driven greeting dismiss
  - **Settings**: narrator subtitles (Jessica/George), distinctive preview voice, direct tutorial replay, full navigator reset after progress wipe
  - **Voice system**: 4 new encouragement arcs (7-10, total 10), 5s companion suppression near arc beats, world intro trimmed
  - **Quick fixes**: friendly sync/restore errors, auth retry safety, reset keys for camera/voice_style, deleted orphan voice file
  - **World map**: pulsing rocket beacon replaces "YOU ARE HERE" text, locked worlds more visible
  - **Tests**: 30 greeting service tests + 7 home screen widget tests (651 total)
  - APK **99MB**, uploaded to Google Drive
  - 651 tests passing, dart analyze clean
- **COPPA Compliance Tracker**:
  - [x] P1.1-P1.6: All code + Firebase Console done
  - [x] P1.1 (updated): Camera defaults OFF, onboarding no longer sets camera_mode_configured
  - [ ] P2.1: Google Play Console families policy config
  - [ ] P2.2: Physical mailing address -> LLC workstream (see `/llc`)
- **Blocked on**: Google Play developer account suspended (appeal pending)
- **Next up**: Kid testing buddy voice with Oliver & Theo, Play Store submission
- **Needs CEO decision**: None

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
- **Status**: In progress — registered agent hired, filing next
- **Last session**: 2026-03-15
- **Entity name**: AnemosGP (California LLC)
- **Command**: `/llc` — dedicated session command with full checklist
- **What happened**:
  - Decided on California (home state — cheapest since CA charges $800/yr franchise tax regardless)
  - Hired Northwest Registered Agent ($125/yr, paid)
  - Filed Articles of Organization (Doc# B20260127451, $75 paid)
  - Business address: 2108 N ST, STE N, Sacramento, CA 95816
  - Google Drive folder structure: `gdrive:Projects/Brush-quest/Business/`
  - Phone: existing Google Fi number for business use
- **Checklist**:
  - [x] Choose state: California
  - [x] Registered agent: Northwest ($125/yr, active 03/15/2026 - 03/15/2027)
  - [x] Articles of Organization filed (CA Form LLC-1, $75 — Doc# B20260127451)
  - [ ] File Statement of Information (CA Form LLC-12, $20) — within 90 days of formation
  - [ ] Get EIN (irs.gov, free, instant)
  - [ ] Get D-U-N-S number (dnb.com, free, ~30 day wait)
  - [ ] Open business bank account (Mercury/Relay/Chase)
  - [ ] Update privacy policy with LLC info
  - [ ] Switch Google Play to organization account
- **Blocked on**: Secretary of State processing Articles of Organization (~5 business days from 03/15/2026)
- **Next up**: Wait for LLC approval → EIN → D-U-N-S → bank account (calendar reminder set for March 20)
- **Estimated cost**: ~$1,015 year 1, ~$935/year ongoing (CA franchise tax is $800/yr)
- **Why it matters**: COPPA requires physical address in privacy policy. Google Play shows address publicly for monetized apps. Home address should not be public.

### ACCOUNTING
- **Status**: In progress — QuickBooks set up, bank account pending
- **Last session**: 2026-03-15
- **Command**: `/accounting` — dedicated session command
- **What happened**:
  - Chose accounting stack: Mercury (bank) + QuickBooks Simple Start ($15/mo) + Mercury credit card
  - Signed up for QuickBooks Simple Start
  - Tax type: sole proprietor (single-member LLC, Schedule C)
  - Tax calendar reminders set (franchise tax July 15, annual return April 2027)
  - Google Drive structure for business docs created
- **Checklist**:
  - [x] QuickBooks Simple Start signed up
  - [x] Tax calendar reminders set
  - [ ] Log existing expenses ($125 RA + $75 LLC filing)
  - [ ] Set up expense categories in QuickBooks
  - [ ] Open Mercury bank account — BLOCKED on EIN
  - [ ] Get Mercury credit card — after bank
  - [ ] Connect Mercury → QuickBooks
- **Blocked on**: EIN (which is blocked on LLC approval ~March 20)
- **Next up**: Log first expenses in QuickBooks, then Mercury bank after EIN
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
- **Status**: Cycle 6 complete — 30 findings shipped
- **Last session**: 2026-03-20
- **Command**: `/cycle` (full audit), `/cycle ship` (verify+ship), `/cycle visual` (emulator screenshots)
- **Repo**: `~/Projects/dev-cycle` (GitHub: jmchabas/dev-cycle, private)
- **Cycles completed**: 1, 5, 6 (Cycle 2 analysis done but framework overhauled before implementation)
- **Blocked on**: Nothing
- **Next up**: Run next cycle when ready
- **Needs CEO decision**: None

### STRATEGY
- **Status**: Phase 0 plan complete, operational system built
- **Last session**: 2026-03-14
- **What happened**: Created 5-phase master plan (STRATEGY.md). Built cross-session coordination system. Defined operational cadence.
- **Blocked on**: Nothing — waiting for workstreams to execute
- **Next up**: First Monday weekly brief
- **Needs CEO decision**: N/A

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
| Google Play developer account suspended | Jim | 2026-03-14 | Blocks ALL user acquisition | APPEAL PENDING — verification failed, appeal submitted |
| No Firebase Analytics events | APP | 2026-03-14 | Flying blind on retention | DONE — COPPA-compliant, 10 events instrumented |
| No privacy policy page | LANDING | 2026-03-14 | Blocks Play Store | DONE — COPPA-compliant, in-app link added |
| No email capture on landing page | LANDING | 2026-03-14 | Losing potential early adopters | DONE — Buttondown, platform-aware forms, QR code for desktop |

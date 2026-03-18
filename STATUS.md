# Brush Quest — Status Board
<!-- Every session reads this at start. Every session updates its section at end. -->
<!-- Jim says "update the status board" → session updates its workstream below. -->

**Current #1 Priority**: Get the app on Google Play Store. Nothing else matters.
**CEO Streak**: Week 0 (starting fresh)
**Phase**: 0 — Pre-Launch

---

## Workstream Status

### APP
- **Status**: v7 shipped + COPPA done + Cycle 2 complete (19 findings implemented)
- **Last session**: 2026-03-16
- **Last commit**: `7da3ca6` — Cycle 2: 19 UX/audio/economy fixes, cosmetic frames system, COPPA camera fix
- **What happened**:
  - Cycle 2 full audit: 4 parallel analysis agents + synthesizer, benchmark vs Brusheez
  - Onboarding: visual panels, motion icon, COPPA camera fix (no longer silently enabled), hero art
  - Card album: mystery silhouettes for uncollected cards
  - World map: adventure path with zigzag layout and curved connectors
  - Home: skip picker for new users, hero breathing animation, welcome-back voice rotation
  - Battle: hero 40% larger, cosmetic frame glow
  - Shop: new FRAMES tab (7 cosmetic frames 3-17★), unlock voice stutter fix, progress indicators
  - Settings: voice after parent gate, 2-step delete with math confirmation
  - Victory: achievement voice rotation (3 variants)
  - Audio: removed 19 orphaned preloads, committed voice arc system (33 files)
  - Economy: hero frames fill dead zones between major unlocks
  - 588 tests passing, APK 86.4MB
- **COPPA Compliance Tracker**:
  - [x] P1.1-P1.6: All code + Firebase Console done
  - [x] P1.1 (updated): Camera defaults OFF, onboarding no longer sets camera_mode_configured
  - [ ] P2.1: Google Play Console families policy config
  - [ ] P2.2: Physical mailing address -> LLC workstream (see `/llc`)
- **Blocked on**: Google Play developer account suspended (appeal pending)
- **Next up**: Kid testing with Cycle 2 changes, Play Store submission
- **Needs CEO decision**: None

### LANDING PAGE
- **Status**: Live at jmchabas.github.io/brush-quest
- **Last session**: 2026-03-14
- **Last commit**: `e35f87d` — Landing page audit fixes: SEO, performance, conversion, security
- **What happened**: Copy rewritten to sell outcomes. SEO/OG tags added. Security headers.
- **Blocked on**: No Play Store link yet (developer account appeal pending)
- **Next up**: Email capture form, Play Store badge once approved
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
- **Status**: Framework built, command installed, ready for first cycle
- **Last session**: 2026-03-16
- **Command**: `/cycle` (full audit), `/cycle ship` (verify+ship), `/cycle visual` (emulator screenshots)
- **Repo**: `~/Projects/dev-cycle` (GitHub: jmchabas/dev-cycle, private)
- **What happened**:
  - Built structured dev loop framework: CONTEXT → ANALYZE → PLAN → APPROVE → IMPLEMENT → VERIFY → SHIP → LEARN → FEEDBACK
  - 3 parallel analysis agents: visual walkthrough (emulator), code health, kid experience + freshness
  - 4th synthesizer agent de-duplicates and ranks findings
  - Config with 3 personas, 12 audit lenses, economy model, emulator setup
  - Cycle history (append-only) + kid feedback file (Jim writes after real-world testing)
  - Symlinked command: `brush-quest/.claude/commands/cycle.md` → `dev-cycle/commands/cycle.md`
  - `settings.local.json` updated with permissions for flutter, adb, emulator, rclone
- **Blocked on**: Nothing — ready to run first cycle
- **Next up**: Run `/cycle` for first full audit
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
| No email capture on landing page | LANDING | 2026-03-14 | Losing potential early adopters | TODO |

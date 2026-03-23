# Brush Quest — Status Board
<!-- Every session reads this at start. Every session updates its section at end. -->
<!-- Jim says "update the status board" → session updates its workstream below. -->

**Current #1 Priority**: Get the app on Google Play Store. Nothing else matters.
**CEO Streak**: Week 0 (starting fresh)
**Phase**: 0 — Pre-Launch

---

## Workstream Status

### APP
- **Status**: Cycle 8 shipped — 17 findings, 10 streams, 6-zone brushing, victory safety, parent stats + 623 tests
- **Last session**: 2026-03-23
- **Last commit**: `606c40b` — Cycle 8 (17 findings, 10 streams)
- **What happened**:
  - **6-zone brushing**: TL/TF/TR/BL/BF/BR, default 20s/zone, visual mouth guide (no text labels)
  - **Victory safety**: try/catch prevents dead-end trap, early DONE button
  - **Voice timeout**: 5s→15s (fixed 47+ truncated voice files)
  - **Parent gate**: hardened math floor (min 4×3=12)
  - **Onboarding P2**: animated battle scene replacing abstract diagram
  - **Greeting tease**: item icon + progress bar + voice (replaces text-only)
  - **Parent stats**: 7-day activity, consistency ring, morning/evening, minutes brushed
  - **World intro**: skips after first visit per world
  - **Pause voice**: whoosh on pause, "Let's fight!" on resume
  - **Reset**: added onboarding_completed, camera_enabled, muted, phase_duration
  - **Fix**: cosmic_burst unlock voice key
  - APK **90.3MB** (-8.8%), uploaded to Google Drive
  - 623 tests passing, dart analyze clean
- **COPPA Compliance Tracker**:
  - [x] P1.1-P1.6: All code + Firebase Console done
  - [x] P1.1 (updated): Camera defaults OFF, onboarding no longer sets camera_mode_configured
  - [x] P2.2: Privacy policy overhauled — COPPA 2025 + CCPA + data security program
  - [ ] P2.1: Google Play Console families policy config — BLOCKED on org account
- **Blocked on**: Google Play org account (need D-U-N-S number first)
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
- **Status**: Nearly complete — LLC approved, EIN obtained, bank open, D-U-N-S pending
- **Last session**: 2026-03-20
- **Entity name**: AnemosGP LLC (California), DBA Brush Quest (filing TBD)
- **EIN**: 41-5007192
- **Command**: `/llc` — dedicated session command with full checklist
- **What happened**:
  - LLC approved by SoS on 03/19/2026
  - EIN obtained: 41-5007192
  - Mercury bank account opened (checking ending 2545)
  - Operating Agreement created
  - Privacy policy overhauled (COPPA 2025 + CCPA, phone number, 10 sections)
  - Data security program document created (COPPA 312.8)
  - DBA "Brush Quest" form pre-filled (not yet filed)
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
  - [x] D-U-N-S applied (03/20/2026, Case # DFC-507818 / D&B # 10170423, expedited $229)
  - [ ] D-U-N-S number received (expedited 8 biz days, expected ~April 1)
  - [ ] Register Google Play organization account — BLOCKED on D-U-N-S
- **Blocked on**: D-U-N-S processing (expedited, expected ~April 1)
- **Next up**: Wait for D-U-N-S → register Google Play org account. Answer unknown calls (D&B verification).
- **Estimated cost**: ~$1,015 year 1, ~$935/year ongoing (CA franchise tax is $800/yr)

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
- **Status**: Cycle 8 complete — 17 findings shipped (5 deferred)
- **Last session**: 2026-03-23
- **Command**: `/cycle` (full audit), `/cycle ship` (verify+ship), `/cycle visual` (emulator screenshots)
- **Repo**: `~/Projects/dev-cycle` (GitHub: jmchabas/dev-cycle, private)
- **Cycles completed**: 1, 2, 3, 4, 5, 6, 8 (Cycle 7 informal — shipped but no LEARN phase)
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
| D-U-N-S number pending | Jim | 2026-03-20 | Blocks Google Play org account | APPLIED — Case DFC-507818, expedited $229, expected ~April 1 |
| Google Play developer account (personal) suspended | Jim | 2026-03-14 | N/A — going org account route | ABANDONED — registering org account under AnemosGP LLC instead |
| No Firebase Analytics events | APP | 2026-03-14 | Flying blind on retention | DONE — COPPA-compliant, 10 events instrumented |
| No privacy policy page | LANDING | 2026-03-14 | Blocks Play Store | DONE — COPPA 2025 + CCPA compliant, 10 sections, live |
| No email capture on landing page | LANDING | 2026-03-14 | Losing potential early adopters | DONE — Buttondown, platform-aware forms, QR code for desktop |

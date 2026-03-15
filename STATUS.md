# Brush Quest — Status Board
<!-- Every session reads this at start. Every session updates its section at end. -->
<!-- Jim says "update the status board" → session updates its workstream below. -->

**Current #1 Priority**: Get the app on Google Play Store. Nothing else matters.
**CEO Streak**: Week 0 (starting fresh)
**Phase**: 0 — Pre-Launch

---

## Workstream Status

### APP
- **Status**: v7 shipped + COPPA compliance DONE (all P1 items complete)
- **Last session**: 2026-03-15
- **Last commit**: uncommitted (COPPA compliance changes — camera default OFF, consent dialogs, privacy policy, url_launcher)
- **What happened**:
  - Firebase Analytics with COPPA child-directed treatment (10 events, ad IDs disabled)
  - COPPA compliance: camera defaults OFF, consent dialogs for Sign-In + camera, privacy policy link in Settings, "Delete child's data" relabeled, privacy policy rewritten (operator info, retention table, parental rights, consent mechanisms, internal ops exception)
  - `url_launcher` added for in-app privacy policy link
  - Business research stored in `research/` (6 files: competitors, pricing, monetization, B2B, COPPA, parent features)
- **COPPA Compliance Tracker**:
  - [x] P1.1: Camera default → OFF
  - [x] P1.2: Consent dialog before Google Sign-In
  - [x] P1.3: Consent notice before camera enable
  - [x] P1.4: Privacy policy link in Settings
  - [x] P1.5: Privacy policy updated (COPPA 312.4 requirements)
  - [x] P1.6: Firebase Console — data retention 2 months, Google Signals OFF, granular location OFF, ads personalization OFF, reporting identity Device-based (done 2026-03-15)
  - [ ] P2.1: Google Play Console families policy config
  - [ ] P2.2: Physical mailing address → LLC workstream (see `/llc`) — AnemosGP LLC filed, waiting on approval
- **Blocked on**: Google Play developer account suspended (appeal pending)
- **Next up**: Commit COPPA changes, update privacy policy with LLC address once approved, Play Store submission
- **Needs CEO decision**: None — COPPA code complete, LLC in progress via `/llc` workstream

### LANDING PAGE
- **Status**: Live at jmchabas.github.io/brush-quest
- **Last session**: 2026-03-14
- **Last commit**: `e35f87d` — Landing page audit fixes: SEO, performance, conversion, security
- **What happened**: Copy rewritten to sell outcomes. SEO/OG tags added. Security headers.
- **Blocked on**: No Play Store link yet (developer account appeal pending)
- **Next up**: Email capture form, Play Store badge once approved
- **Needs CEO decision**: None

### PRICING
- **Status**: Research complete, model proposed, awaiting Jim's decision
- **Last session**: 2026-03-15
- **What happened**: Deep research done (6 files in `research/`). Parent subscription at $5.99/mo rejected — camera "verification" is dishonest, other features are table stakes. Proposed content-led "Space Ranger Pass" at $2.99/mo or $24.99/yr instead. Jim said to hold on pricing front for now.
- **Blocked on**: Jim's decision on pricing model + needs analytics data from real users
- **Next up**: Jim reviews `research/monetization-models.md` and `research/parent-features-evaluation.md`, decides on model
- **Needs CEO decision**: Approve/modify "Space Ranger Pass" model ($2.99/mo or $24.99/yr) — see D-002 in STRATEGY.md

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
**Decision**: NO new features until 100 real users. Only allowed: bug fixes that block brush completion, Play Store requirements, analytics.
**Affects**: APP
**Status**: ACTIVE

---

## Blockers Tracker

| Blocker | Owner | Since | Impact | Status |
|---------|-------|-------|--------|--------|
| Google Play developer account suspended | Jim | 2026-03-14 | Blocks ALL user acquisition | APPEAL PENDING — verification failed, appeal submitted |
| No Firebase Analytics events | APP | 2026-03-14 | Flying blind on retention | DONE — COPPA-compliant, 10 events instrumented |
| No privacy policy page | LANDING | 2026-03-14 | Blocks Play Store | DONE — COPPA-compliant, in-app link added |
| No email capture on landing page | LANDING | 2026-03-14 | Losing potential early adopters | TODO |

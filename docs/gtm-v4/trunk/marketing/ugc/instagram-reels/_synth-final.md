# Synth-Final — Instagram Reels Node

**Node:** `trunk/marketing/ugc/instagram-reels`
**Date frozen:** 2026-04-20
**Status:** FROZEN. Immutable context for all downstream child loops.

---

## 1. Headline decision

Defend a **realistic target of 25–40 qualified parent installs in 14 days** (not the original 50) by treating **Instagram Reels as a content asset, not a funnel**, and front-loading attribution + warm-network + Reddit + one dual-creator proxy. The single top Tier-1 bet is **T1c — the brushquest.app/rangers landing path with UTM round-trip attribution + CSV-to-inbox tester pipeline**, because it is the dominant conversion coefficient and every other bet is vibes without it. Per E3, 50 is not achievable with current tool coverage and Jim's 5-hr/week budget; per E1, CAC math only becomes defensible after the UTM→tester→first-brush join passes end-to-end on a burner phone. We ship T1c Day 1–2, then fan out to Reddit + warm-network + dual creator proxies, with a hard Day 3 telemetry kill-gate.

---

## 2. Changes from Synth-1 (transparency)

- **Target reframed from "50 qualified installs" to "25–40, honest floor 50 stretch"** — per **E3 §6** ("realistically, agent+Jim pair hits 25–40 … plan under-counts Jim-hours by ~30%"). E1's 45–55% confidence band corroborates.
- **T1c upgraded to blocking prerequisite with UTM round-trip burner-phone acceptance test** — per **E1 §3.1** ("no attribution, no spend"). Test must pass before any Reddit/creator dollar is spent.
- **"Qualified install" redefined as a deterministic Firestore query** — per **E1 §3.2**: `parent_email_captured=true AND play_tester_enrolled=true AND first_brush_timestamp IS NOT NULL within 72h`. Query is embedded in PRD-001 so Day-14 retro is deterministic, not narrative.
- **T1b creator scale gate moved from n=1 to n=2 parallel proxies** — per **E1 §3.3** (n=1 at $120 "is a coin flip, not a signal"). Two $120 proxies = $240, scale batch trimmed from $400 to $280. Tier-1 cap stays under $640.
- **"Auto-enroll" replaced with "CSV-to-Jim-inbox"** in T1c until Play Publishing API is wired — per **E3 §4** ("honest naming"). API wiring moves to a Tier-2 experiment (T2g).
- **Killed "internal tester / Google group" language in all parent-facing copy; replaced with "early access"** — per **E2 §5.1** ("one copy change worth more than half the creator budget").
- **Creator brief hard-bans Space Ranger aesthetic from first 3 seconds; meltdown hook at 0s, game reveal at second 6** — per **E2 §5.2** and §3. Codified in PRD-003 creative spec.
- **T1d PTA channel upgraded to 3-line text template from Jim's phone (not newsletter)** — per **E2 §5.3**. Buttondown send stays; PTA piece is plain-text-from-Jim.
- **Day 3 kill-gate added** — per **E3 §4**. If zero installs attributed by end of Day 3, attribution is broken, NOT the funnel — debug before spending further.
- **5 human-gates batched into one 60-min daily Jim window** — per **E3 §4**. PTA DM, Reddit post, creator DM, landing copy signoff, email send all stacked.
- **T2c dentist poster, T2e slideshow carousel, T2f FB groups → demoted to Tier-3** with tightened triggers — per **E1 §5** and **E3 §5** (unmeasurable / no API / link suppression).
- **T1b "$400 scale batch" moved to Tier-3** — per **E3 §5**. Trigger: attribution proven + proxy CAC <$15 + ≥3 confirmed qualified installs. Only the dual $240 proxy remains in Tier-1.
- **7 tool-gap PRDs flagged as pre-requisite meta-PRDs** for child loops — per **E3 §2**. Most Tier-1 bets are NOT PRD-executable now; they need child loops on infrastructure first.
- **Play Install Referrer instrumentation added to T1c** — per **E1 §3.4**. Enables auto-upgrade when public review clears mid-sprint.
- **T1a Reddit posts must originate from Jim's personal account**, not @brushquest — per **E3 §4** (androidtesting mods catch fresh accounts).
- **iOS waitlist capture added to landing page** — per Synth-1 §9.6 carried forward; Apple Business expected ~2026-04-24, inside sprint.

---

## 3. Tier-1 bets (final)

### T1a — Reddit dual-post (r/androidtesting + r/daddit), Jim's personal account

| Field | Value |
|---|---|
| Hypothesis | Parent subs + androidtesting convert 15–40% on honest founder posts from an aged personal account; Reels on @brushquest exist as a trust wall for parents who google the app |
| Expected CAC | $0–2 (time only) |
| Expected volume (14d) | 12–25 qualified installs (dilution accounted) |
| Time-to-signal | 48–72 hrs |
| Budget | $0 |
| Agent-hrs | 4 (draft + monitor) |
| Jim-hrs | 2 (post + reply window) |
| **Addressing evaluator concerns** | E1 §3.1: post via Jim's aged account (lower removal risk); mod-DM pre-approval dry run (E1 §4.2). E2: bypasses Instagram — correctly not load-bearing for IG-resident parents. E3 §4: codified that Jim posts, not a fresh @brushquest account. |
| **Spawns** | PRD-002 (Reddit post drafts + reply SLA) + dependency on meta-PRD-reddit-pipeline (child loop — PRAW/CLI tool) |

### T1b — Dual micro-creator paid proxy (n=2, parallel archetypes)

| Field | Value |
|---|---|
| Hypothesis | Two $120 proxies with different archetypes (tired-mom vs. dentist-adjacent) give n=2 signal, distinguishing creator-fit from audience-fit |
| Expected CAC | $8–20 per proxy; $5–12 if scaled |
| Expected volume (14d) | 12–25 qualified installs from two proxies |
| Time-to-signal | 72h per proxy |
| Budget | $240 (two $120 proxies) |
| Agent-hrs | 8 (scouting both archetypes, outreach, brief) |
| Jim-hrs | 2 (contracts, payment approval) |
| **Addressing evaluator concerns** | E1 §3.3: n=2 per CFO. E1 §4.3: audience-fit verification is a hard PRD precondition (creator must screenshot IG Insights: ≥50% F25–44, ≥40% US-parent share) BEFORE payment transfers. E2 §3: creative brief bans Space Ranger aesthetic from first 3 sec; meltdown-confessional hook; game reveal at 0:06. E2 §2: NO QVC-kitchen creators — explicit red-flag list in brief. E3 §2.6: screenshot-based fit check is trust-based and flagged honestly. |
| **Spawns** | PRD-003 (creator brief + creative spec) + PRD-004 (audience-fit checklist) + dependency on meta-PRD-creator-scouting (child loop — without Modash, how do agents verify at scale?) |

### T1c — brushquest.app/rangers landing + UTM attribution + CSV-to-inbox tester pipeline

| Field | Value |
|---|---|
| Hypothesis | Dominant conversion coefficient is the Play internal-testing funnel; replacing destination with a landing page that (a) captures email, (b) shows 3-tap "early access" walkthrough, (c) writes UTM + parent_id to Firestore, (d) exports nightly CSV to Jim's inbox for Play Console upload — lifts every other bet 2–3× |
| Expected CAC | N/A (enabler) |
| Expected volume (14d) | Zero directly; unlocks 100% of the other bets |
| Time-to-signal | Must ship Day 1–2; Day 3 kill-gate on telemetry |
| Budget | $0 |
| Agent-hrs | 16 (landing page + Buttondown→Firestore bridge + UTM capture + Play Install Referrer instrumentation + CSV export cron) |
| Jim-hrs | 1 (copy review, visual QA on iPhone, CSV→Play Console upload daily) |
| **Addressing evaluator concerns** | E1 §3.1: UTM round-trip burner-phone test is blocking acceptance criterion — no Reddit/creator spend until green. E1 §3.2: "qualified install" embedded as deterministic Firestore query. E1 §3.4: Play Install Referrer wired so attribution auto-upgrades when public review clears mid-sprint. E2 §2 (T1c): "Google group" language BANNED from every parent-facing surface; use "early access." Page respects 4-second attention budget. E3 §4: "auto-enroll" renamed to "CSV-to-inbox" — honest. iOS waitlist capture included (Synth-1 §9.6). |
| **Spawns** | PRD-001 (landing + attribution, the root PRD of this node) + PRD-005 (UTM round-trip burner-phone acceptance test) + dependency on meta-PRD-buttondown-firebase-bridge (child loop — webhook + Cloud Function) + dependency on meta-PRD-attribution-schema (child loop — Firestore schema for `parents/` + `testers/`) |

### T1d — Buttondown blast + PTA text-from-Jim

| Field | Value |
|---|---|
| Hypothesis | Highest-trust, lowest-cost lane. Buttondown list opens 20–40%. Oliver's 2nd-grade class-parent text (plain text, Jim's phone) is the actual mechanism by which parent apps get installed |
| Expected CAC | $0 |
| Expected volume (14d) | 8–18 qualified installs |
| Time-to-signal | 48 hrs |
| Budget | $0 |
| Agent-hrs | 2 (email draft + 3-line text template) |
| Jim-hrs | 2 (send email + physically text parents) |
| **Addressing evaluator concerns** | E2 §4: "the PTA / 2nd-grade-mom email is literally how every app my kid uses got on my phone." E2 §5.3: explicitly 3-line text from Jim's phone, NOT a newsletter template with stock art. E3 §1 T1d: PTA outreach is explicitly non-delegable relationship work; agent drafts, Jim sends. |
| **Spawns** | PRD-006 (Buttondown email draft + Jim's PTA text template — both approved in the one-60-min Jim window) |

### Tier-1 totals

| Resource | Amount |
|---|---|
| Budget (hard cap) | $240 |
| Agent-hours | 30 |
| Jim-hours (over 14 days) | 7 concentrated in 60-min daily batched window |
| Stacked mid-case qualified installs | 32–68 |
| Realistic target (E3-adjusted) | 25–40 qualified installs |

---

## 4. Tier-2 experiments (final)

| # | Experiment | Single variable | Kill criterion | Analyzer agent | Budget | Agent-hrs |
|---|---|---|---|---|---|---|
| T2a | **Throwaway-handle parent-confessional format test** | Does "things I said tonight as a parent" format pop at cold-start from zero followers? | Median reach <500/Reel across 3 posts in 5 days → kill format AND @brushquest-handle strategy | Dashboard Agent (§3 E3) reads IG Insights via Chrome MCP, logs to `experiments/t2a.csv` | $0 | 4 |
| T2b | **2 Reels from Jim's personal IG** (not @brushquest) | Does warm personal account deliver >3× cold-handle reach for same creative? | Personal-account reach <2× @brushquest same-day → warm-start hypothesis dead | Dashboard Agent | $0 | 2 |
| T2d | **Substack cold pitch to 3 parenting writers** (Parent Data, Screen Time Consultant, What Fresh Hell) | Does founder-story land a mention? | 0 of 3 respond in 10 days → kill | Outbound Comms Agent (§3 E3) logs replies | $0 | 3 |
| T2g | **Play Publishing API tester-list auto-enroll** (replaces manual CSV) | Can service-account edits replace Jim's nightly CSV upload? | Service account can't write internal-testing list OR API throws before Day 7 → park | Landing + Pipeline Agent (§3 E3) | $0 | 6 |

Tier-2 total: **$0 + 15 agent-hours + 0 concentrated Jim-hours** (all review batched into the same 60-min window as Tier-1).

**Removed from Tier-2** (demoted to Tier-3, see §5): T2c (dentist poster), T2e (slideshow carousel), T2f (FB groups), T1b-scale ($400 batch).

---

## 5. Tier-3 parked (tightened triggers)

| # | Route | Tightened trigger |
|---|---|---|
| T3a | **Paid Meta/TikTok app-install ads** | Any organic Reel ≥50K plays OR dual-proxy CAC <$15 with attribution confirmed |
| T3b | **Public retention dashboard on brushquest.app/live** | WAK ≥ 50 (real numbers to display) |
| T3c | **Pediatric-dentist QR poster (Oliver's dentist first)** | When T1c landing surfaces ≥10 captured emails from ANY offline surface, confirming QR→email pipeline works (tightened per E1 §5) |
| T3d | **Product Hunt Kids/Family launch** | Public Play review clears AND email list ≥200 |
| T3e | **Brand-handle daily Reels engine** | One Reel (any surface) clears 10K plays with a repeatable hook |
| T3f | **"Changelog-as-marketing" / founder build-in-public** | Face-of-brand constraint resolved (hired creator OR Jim changes mind) |
| T3g | **Moshi-style paid UA + ASO + partnerships** | Monetization unlocked AND paid-conversion tracking live |
| T3h | **(was T2c) Pediatric-dentist QR poster** | Same as T3c — unmeasurable below 3 installs/14d, needs offline→email bridge first |
| T3i | **(was T2e) Slideshow-carousel Reel format** | Any single Reel clears 2K plays on a warmer surface (format-signal isolable from suppression-signal) |
| T3j | **(was T2f) FB mom group seed** | Reddit T1a yields ≥10 installs (parent-community pitch converts) OR group admin explicitly invites |
| T3k | **(was T1b-scale) $280 creator batch scale** | T1c attribution confirms dual-proxy CAC <$15 AND ≥3 qualified installs attributed per creator |

---

## 6. Termination gate result

For each Tier-1 and Tier-2 bet, mark PRD-executable status against 6 criteria (measurable goal+window, context specified, inputs named+located, acceptance checkable, tools exist or flagged, escalation triggers specified).

| Bet | Status | Artifact |
|---|---|---|
| **T1a — Reddit dual-post** | `[ ] Needs child loop` | `_meta-prd-reddit-pipeline.md` (no Reddit MCP; PRAW CLI or Chrome-MCP flow, reply SLA monitor) → child loop resolves, then `prds/PRD-002-reddit-dual-post.md` becomes executable |
| **T1b — Dual creator proxy** | `[ ] Needs child loop` | `_meta-prd-creator-scouting.md` (no Modash/Creator Marketplace MCP; how do agents verify audience-fit at scale beyond trust-based screenshots?) → then `prds/PRD-003-creator-brief.md` + `prds/PRD-004-audience-fit-checklist.md` |
| **T1c — Landing + attribution + CSV pipeline** | `[ ] Needs child loop` (largest) | `_meta-prd-attribution-schema.md` (Firestore schema: `parents/{parent_id}`, `testers/{parent_id}`, UTM capture, Play Install Referrer) + `_meta-prd-buttondown-firebase-bridge.md` (Buttondown webhook → Cloud Function → Firestore) → then `prds/PRD-001-rangers-landing.md` + `prds/PRD-005-utm-round-trip-test.md` |
| **T1d — Buttondown + PTA text** | `[✓] PRD-executable now` | `prds/PRD-006-warm-network-sweep.md` (Buttondown email draft + 3-line Jim-phone text template + class-parent contact list) |
| **T2a — Throwaway IG format test** | `[ ] Needs child loop` | `_meta-prd-ig-posting-pipeline.md` (no IG Graph API MCP; Chrome-MCP semi-auto vs. Buffer/Later vs. Jim manual) → then PRD |
| **T2b — Jim's personal IG, 2 Reels** | `[ ] Needs child loop` | Same `_meta-prd-ig-posting-pipeline.md` as T2a resolves this one too |
| **T2d — Substack cold pitches** | `[✓] PRD-executable now` | `prds/PRD-007-substack-cold-pitch.md` (Gmail MCP, 3 target writers, one-click approve flow) |
| **T2g — Play Publishing API auto-enroll** | `[ ] Needs child loop` | `_meta-prd-play-publishing-api.md` (service account, internal-testing list edit endpoint, auth flow) → then PRD |

**Summary:**
- 2 of 8 bets (T1d, T2d) are PRD-executable now
- 6 of 8 bets need child loops first
- 7 meta-PRDs spawned: `reddit-pipeline`, `creator-scouting`, `attribution-schema`, `buttondown-firebase-bridge`, `ig-posting-pipeline`, `play-publishing-api` (+ the T1c landing PRD itself depends on the first two meta-PRDs)

This matches E3's prediction that "given tool gaps, many Tier-1 bets will NOT be PRD-executable now." That is correct and honest; it is NOT a plan failure. The child loops are the next recursion level's job.

---

## 7. Budget + sequencing commitments

### Budget (hard-frozen)

| Tier | $ allocated | % of node cap | Rationale |
|---|---|---|---|
| Tier-1 | $240 | ~46% | Two creator proxies at $120 each. No Tier-1 spend before T1c UTM round-trip passes. |
| Tier-2 | $0 | 0% | All Tier-2 tests are free (agent-time only). |
| Activation reserve | $260 (unspent of $500 node cap) | ~54% | Held for Tier-3 promotions: either T3k creator scale batch ($280) OR Tier-3 paid UA seed if organic Reel pops. |
| **Node cap** | **$500** | **100%** | Of whole-launch $1–2K budget, this node commits $500 max. Remainder ($500–$1500) reserved for post-sprint scale decisions. |

### Sequencing rule (FROZEN)

- **Day 0–2:** Ship T1c landing + attribution + CSV pipeline. Ship UTM round-trip burner-phone test (PRD-005). **Gate:** test must pass green end-to-end (Reddit-tagged click → email capture → tester CSV row → first-brush Firestore stamp, all joinable on `parent_id`) before ANY Day 3 work begins.
- **Day 3 — KILL-GATE:** if zero installs attributed by EOD Day 3, attribution is broken. Debug telemetry. Do NOT scale spend. (Per E3 §4.)
- **Day 3 (if green):** Fire T1a Reddit r/androidtesting post from Jim's personal account. Fire T1d Buttondown email + PTA text. Begin T1b dual-creator scouting.
- **Day 4:** T1a r/daddit (24h stagger). T2a/T2b format tests begin (if IG pipeline meta-PRD has shipped).
- **Day 5:** T1b dual $120 proxies go live (different archetypes). T2d Substack cold pitches sent.
- **Day 7 — decision gate:** count qualified installs via deterministic Firestore query (PRD-001 §acceptance). Cull Tier-2 per kill criteria. Check Tier-3 triggers.
- **Day 8–10:** If dual proxy CAC <$15 AND ≥3 qualified installs attributed per creator → promote T3k ($280 scale) to Tier-1 for remaining days. Else hold $260 reserve.
- **Day 10:** Second Reddit window (cross-sub, new angle).
- **Day 14:** Retro. Dashboard Agent writes `_retro.md` from Firestore + Play Console CSV.

### Human-gate batching (FROZEN)

Per E3 §4: Jim-hours concentrated into **one 60-min window per day**. Agents prepare all artifacts in `/tmp/jim-queue/YYYY-MM-DD/`:
- Reddit post draft (ready to copy-paste)
- Creator outreach DMs (approve → Gmail MCP sends)
- Landing copy diffs (approve → deploy)
- Buttondown email (approve → send)
- PTA text (Jim sends from his phone)

Any out-of-window interrupt requires: money-out ≥$50, any legal/COPPA copy, or any real-named-human response that can't wait.

### Escalation triggers (FROZEN)

| Trigger | Action |
|---|---|
| T1c burner-phone UTM test fails by Day 2 EOD | STOP all spend. Debug attribution. Do not fire T1a/T1b. |
| Day 3 zero-installs gate fails | STOP scaling. Debug telemetry (NOT funnel). |
| Play public review clears mid-sprint | Re-score portfolio: the internal-tester coefficient drops, T1c switches to "public install mode" via config flag, T3a and T1b scale become cheaper. |
| Dual creator proxy CAC >$50 | Kill T3k promotion. Reserve $260 → Tier-3 T3a seed (paid UA with proven creative, if any Reel popped). |
| Reddit post removed <6h on first attempt | Mod-DM pre-approval required before any re-post (E1 §4.2). |
| iOS Apple Business clears ~2026-04-24 | Flip landing-page iOS waitlist CTA to active TestFlight signup. Do NOT change Tier-1 allocation. |
| Jim-hours >10/wk actual vs. 7 planned | Deprioritize T2a/T2b (IG manual posting) first. |

---

## 8. What this synth-final binds for children (immutable)

Downstream loops MUST inherit these decisions. They cannot be re-litigated in child loops without explicit trunk-level override.

1. **Target is 25–40 qualified installs in 14 days.** 50 is stretch, not commit. Any child loop claiming 50 as base case must justify against E3's Jim-hour math.
2. **"Qualified install" = deterministic Firestore query:** `parent_email_captured=true AND play_tester_enrolled=true AND first_brush_timestamp IS NOT NULL within 72h`. No other definition is valid for the Day-14 retro.
3. **T1c (landing + attribution + CSV pipeline) is the dominant-coefficient bet.** All other spend is gated on T1c's burner-phone UTM round-trip test passing. Child loops on T1a/T1b/T1d cannot ship before T1c.
4. **"Internal tester" / "Google group" language is BANNED from every parent-facing surface.** Use "early access." This is a copy rule, not a suggestion.
5. **Creator brief BANS Space Ranger aesthetic from first 3 seconds of any Reel aimed at parents.** Meltdown-confessional hook at 0s, game reveal no earlier than 0:06. Hands-only (no kid face), COPPA-strict.
6. **T1b scale gate requires n=2 parallel proxies, not n=1.** The "$400 scale batch" is Tier-3, not Tier-1. Any child loop proposing single-proxy scale must clear E1's n=1 statistical objection.
7. **PTA channel is plain-text-from-Jim's-phone, not a newsletter.** 3-line template max.
8. **Reddit posts originate from Jim's aged personal account, never a fresh @brushquest handle.**
9. **Jim's time is 7 hours over 14 days, batched into daily 60-min windows.** No interrupt-driven pings except for the escalation triggers in §7.
10. **Budget cap for this node is $500.** Of that, $240 is committed to dual-creator proxies. $260 is activation reserve — it unlocks only on proven attribution + CAC math.
11. **Day 3 zero-install kill-gate is non-negotiable.** If attribution shows zero qualified installs by EOD Day 3, stop spending and debug telemetry before any further action.
12. **Play Install Referrer instrumentation ships with T1c on Day 1.** When public Play review clears mid-sprint, attribution auto-upgrades; this path must be wired, not retrofitted.
13. **iOS waitlist capture is part of T1c landing on Day 1.** Android-now-iOS-soon is the copy.
14. **Agents pin required MCPs + credentials in every PRD header.** Missing a tool = the PRD spawns a meta-PRD, not a best-effort workaround.
15. **Any money-out, any message to a real named human, any COPPA/legal copy edit, any Firestore schema change → Jim approves in the daily 60-min window.** Everything else runs autonomously.

**End of synth-final. This file is frozen.**

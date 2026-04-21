# Trunk — Synth-1 Portfolio

**Node:** `trunk`
**Question:** Reach 1,000 weekly-active kids (WAK) brushing by 2026-07-20 (90 days) via agentic execution on a $1,000–$2,000 total budget, with Google Play public + iOS live by that date.
**Loop kind:** trunk portfolio (first real loop; C-pass validation only sibling)
**Date:** 2026-04-21

---

## 1. Question restated

This loop answers: **how do we allocate a $1–2K, ~5–10 hrs/week-of-Jim, 90-day budget across distribution pillars to land 1,000 WAK, given Android goes public any day and iOS is ~6–8 weeks out?** No parent synth-finals bind this — it's trunk. The only prior decisions carried in: (a) budget cap $2K, (b) face-of-brand ≠ Jim, (c) COPPA strict / no in-app ads / no prompts to children, (d) emergent C-pass rule — every social-origin bet routes through `brushquest.app/rangers` bridge, and this rule **does not retire even after Play public** because iOS TestFlight is equally hostile to non-technical parents (L5 §3).

---

## 2. Where the lenses agree (≥3 of 5)

| Signal | L1 | L2 | L3 | L4 | L5 | Read |
|---|---|---|---|---|---|---|
| **Pediatric-dentist distribution is highest-leverage offline channel** | T1 | T1 (Bet B) | T1 (Play B, "the one move this week") | T1–T2 (Brush DJ precedent, Yoto waiting-room play) | — | 4/5 converge — hardest consensus in the portfolio |
| **Paid UA (Meta/TikTok CPI bidding) is structurally broken at this budget** | skip | "structurally impossible" (§3) | "trap until ≥100 ratings" (§3) | "tuning not volume" (§2) | "off by 30–80×" (§1) | 5/5 — **portfolio must be ≥90% organic/earned** |
| **Parenting earned media / newsletter + Substack mentions** | T1 (Romper, Fatherly, Lifehacker) | (implicit in Bet C) | T1–T2 (Play C Substack machine) | T2 (Lenny "go narrow") | — | 3/5 — reliable Tier-1 or Tier-2 pillar |
| **Micro-creator gifting (parent + dental-pro), not marketplace** | T2 (hero-proxy creative) | — | T3 trap warning on marketplaces | T1 (Lingokids, Dr Kahng 4.1M views, Buddle) | — | 3/5 with L4 providing strongest empirical backing |
| **Editor's Choice / Common Sense Media** | T2 | — | T2 | T1 (4× lift, Khan Academy precedent) | — | 3/5 — cheap nomination, asymmetric |
| **COPPA/legal exposure on paid-to-kids retargeting kills most paid playbooks** | — | — | implied | T1 warning (FTC rule 2025-01) | implied | 2/5 explicit + 3/5 implicit — do not ignore |

---

## 3. Where the lenses disagree

### 3a. "Can $500 Meta smoke test produce signal?"
- **L1** says yes, optimized to landing-page email not install.
- **L2/L5** say no, structurally — Meta CPMs priced for $40-LTV subscription apps; Brush Quest's $1–2 LTV loses money forever.
- **L3** says "defer until ≥100 Play ratings."
- **Resolution:** L5 is right on the math ($0.105 blended ceiling). L1's framing has merit *only if reframed* as brand-reach / content-amplification CPM (not CPI bidding). We park paid entirely in Tier-3 with an explicit trigger.

### 3b. "Reddit/community — Tier-1 or Tier-3?"
- **L3** puts Reddit concierge #3 play, risk-flagged.
- **L1** says Reddit is "show up useful not build."
- **L4** cites Lenny's narrow-first but cautions it "reliably delivers 100s not 1000s."
- **Resolution:** Reddit caps at 300–500 WAK (L3 §5 ceiling trap) and Jim-time is the binding resource. Reddit = Tier-2 with a hard 6-hrs/week cap, not Tier-1.

### 3c. "Character-IP kids-music moonshot (L2 Bet A) — real or romance?"
- **L2** says 25% × 50× = highest EV.
- **L4** finds no kids-app precedent at this budget (Lingokids, Moshi all had funding); survivorship-bias warning.
- **L5** math: 1 viral song ≈ 5M+ plays, but only ~0.05% convert to branded landing → ~2,500 visits → ~100 installs. Plausible but NOT "all 1,000 WAK."
- **Resolution:** Run Bet A as a **Tier-2 killable proxy** ($150 ceiling, 72h signal). L2 is right the plan *needs* a low-probability/high-upside swing, but wrong about magnitude. Cap it, don't center it.

### 3d. "Instrument retention in Week 1 — mandatory or a pillar of its own?"
- **L5** declares it an invariant: "no Tier-1 pillar is real without this dashboard live in Week 1."
- Other lenses don't mention it.
- **Resolution:** L5 is dead right and the other lenses are blind to it because they're thinking distribution not learning. **Promote to Tier-1 Pillar 1** — it's both an engineering pre-requisite AND it unblocks every other pillar's ability to report signal.

---

## 4. Tier-1 bets (main pushes)

Four pillars. **Pillar 1 is an engineering/instrumentation bet that gates the other three.** Pillars 2, 3, 4 all spawn child loops — trunk is recognizing the pillars; drill-down will name specific PRDs.

| # | Pillar | Source lenses | Hypothesis | CAC band (lo / mid / hi) | Expected volume | Time-to-signal | Budget | Agent-hrs | Readiness |
|---|---|---|---|---|---|---|---|---|---|
| **1** | **Retention instrumentation + ASO fundamentals ship Week 1** | L5 (dominant coefficient), L1 (ASO = #1 organic), L5 §5 (destination-URL) | Until D1/D7/D30 cohorts are measured and joined to install source, every downstream $ is non-compounding. Shipping Play public listing also auto-lifts store_listing_conv ~3× (L5 §2). | $0 (build cost only) | — (unlocks all 3 below) | 7 days (dashboard live) | $0 marketing; ~$50 tool (posthog/amplitude free tier) | 15–25 eng-hrs | **PRD-executable now.** Write directly, no child loop. |
| **2** | **Pediatric-dentist partnership program** | L1, L2 (Bet B), L3 (Play B "the one move"), L4 (Brush DJ precedent) | Dentist is the single highest-intent trust proxy for this exact product. 5 practices × 20 handouts/mo × 25% activation = 250 WAK. Offline + summer-resistant + compounding. | $3 / $6 / $12 per WAK (incl. print+postage) | 200–400 WAK by Day 90 | 21 days (first practice yes + first 10 installs) | $400–$600 (print kits + postage + courier) | 30–50 agent-hrs (scraping, personalization, Canva) + Jim ~6hrs/wk | **Needs child loop** — pillar-level meta-PRD required. Sub-PRDs: (a) dentist list + outreach machine, (b) flyer/kit design, (c) at-office QR → brushquest.app/rangers flow, (d) at-office attribution scheme. |
| **3** | **Parenting earned-media + Editor's Choice / Common Sense Media** | L1, L3 (Play C), L4 (Khan Academy, 4× lift) | Three compounding moves: (a) pitch Romper/Fatherly/Lifehacker Parenting on the "solo founder + agentic dev + Oliver-tested" angle, (b) submit Common Sense Media review, (c) nominate for Play Editor's Choice via developer console. Two hits + a CSM listing = 1,000–3,000 visits × 40% LP conv × 25% install = 100–300 WAK + long-tail SEO moat. | $1 / $4 / $10 per WAK | 150–400 WAK by Day 90 | 30–45 days (first pickup) | $0–$200 (optional paid newsletter slot) | 20–40 agent-hrs (list build, pitch drafts, CSM submission) + Jim 2–3hrs/wk | **Needs child loop.** Sub-PRDs: (a) press-list + personalized-pitch machine, (b) CSM submission packet, (c) Google Play Editor's Choice nomination, (d) press kit + public metrics page (L1's non-obvious bet — bundle here). |
| **4** | **Substack / newsletter-sponsor pipeline (parenting Beehiivs)** | L1, L3 (Play C), L4 | One mid-tier parenting newsletter placement ($100–200) = 500–2,000 visits per send. 2–4 placements across 90 days = 1,000–8,000 visits → 100–400 WAK. Also lowest-variance paid spend in portfolio (known CPM, measurable LP click). | $2 / $5 / $15 per WAK | 100–400 WAK by Day 90 | 14 days (first placement live) | $400–$600 (2–4 sponsorships) | 15–25 agent-hrs (Substack discovery + pitch) + Jim 1–2hrs/wk | **Needs child loop.** Sub-PRDs: (a) Substack/Beehiiv target list + reply-rate tracking, (b) pitch-and-placement automation, (c) offer package + creative assets. |

**Why these four:** they span the four quadrants the 5 lenses converge on — instrumentation (L5 invariant), high-trust offline (L1/L2/L3/L4 all converge), earned media long-lever (L1/L3/L4), and paid-organic hybrid (L1/L3) with clean unit economics. They also avoid all four "don't do this" consensuses: no kid PII, no CPI bidding, no Discord-build, no Product Hunt reliance.

**Paid proportion:** Pillar 4 includes ~$400–600 of *placement* spend (newsletter sponsorship, CPM-priced, not CPI). Total paid = ~$600 of ~$2,000 = **~30%**. This exceeds L2/L5's ≤10% guidance — justified because newsletter sponsorship is CPM not CPI, has a known impression price, and is the only tested-at-this-scale paid lever. Flag: if Pillar 4 Sub-PRD (c) reveals sponsorship math is worse than projected, re-cap at $300 and shift remainder to Pillar 2 kit-drop volume.

---

## 5. Tier-2 experiments (parallel, cheap, killable)

Each budgeted ≤20% of Tier-1 total (≤$200 each), each one variable, each with an explicit kill criterion.

| # | Experiment | Hypothesis | Budget | Kill criterion | Source |
|---|---|---|---|---|---|
| T2-A | **Cavity Monster character-IP proxy song** | A 45s "Plaque Attack" Fiverr song + 1 dance clip seeded on new TikTok account tests whether character-first media pulls plays without product pitch. | $150 | <5K plays in 72h = kill. 25K+ = promote to Tier-1 child loop. | L2 Bet A (proxy test) |
| T2-B | **Sleep/bedtime-app cross-promo outreach** | Cold email 10 bedtime/routine app founders (Moshi Sleep, Slumberkins, Hatch, Yoto content partners) pitching a bedtime-routine swap. Zero cash; Jim's time only. | $0 | <1 "let's talk" reply in 14 days = kill thesis. ≥2 = pursue as T1 child loop. | L2 Bet C |
| T2-C | **Reddit Comment Concierge (r/Parenting + r/daddit + r/Mommit + r/toddlers)** | Agent drafts, Jim ships 2–3 comments/day from his account; target one upvoted reply per week driving 500+ LP visits. | $0 (Jim time capped at 6 hrs/wk) | No comment hits >100 upvotes in 30 days = deprioritize. Ban / shadowban = kill. | L3 Play A, L4 Lenny §2 |
| T2-D | **Public metrics page + build-log Beehiiv ("Built in 90 Days")** | Transparent metrics page at brushquest.app/stats + weekly Beehiiv post. Dual-purpose: parent-trust signal + press hook for Pillar 3. | $0 (builds on Pillar 1 instrumentation) | 0 press mentions reference it in 60 days AND <100 newsletter subs = retire (still trust asset, just not distribution). | L1 §3 "non-obvious bet" |
| T2-E | **Micro-creator gifting — parent + dental-pro TikTok/Reels (hero-proxy creative)** | Free Brush Quest+ codes to 15–20 nano creators (<10K, parent or dental-pro). Hero-proxy creative (kid's hand + toothbrush, no face). | $100 (print/ship + minor creative) | <2 creators post in 30 days, OR <500 combined views = kill. ≥5 posts + 10K+ views = promote. | L4 #1 (Lingokids, Dr Kahng, Buddle), L1 |
| T2-F | **Local Facebook mom-group admin relationships (2 cities)** | Slow trust-build with admins of 2 "Moms of [City]" groups. No posts month 1–2; offer free kits month 3. | $50 (kit samples) | No admin receptive in 45 days = kill. | L3 Surface #4 |

**Tier-2 total:** ~$300 / ~80 agent-hrs / Jim 4–6 hrs/wk *all experiments combined* (Pillar 1 runs solo first; T2 ramps Week 2–3).

---

## 6. Tier-3 parked (revisit on explicit trigger)

| Route | Why parked | Trigger condition to promote |
|---|---|---|
| **Meta / TikTok paid UA (CPI bidding)** | Math is broken at $1–2 LTV (L5). COPPA exposure (L4). | Promote to T2 only when: (a) blended organic CAC proven <$2/WAK AND (b) Play Store has ≥100 ratings AND (c) LTV model shows ≥$4 from Brush Quest+ conversion. |
| **Product Hunt launch** | Audience mismatch (L1, L3, L4). | Promote if we acquire a parenting-focused PH "hunter" or audience pivots — unlikely. |
| **Content/SEO flywheel (long-tail blog)** | 90-day horizon too short (L1). | Always-on: write 1 evergreen post/week regardless; revisit as channel if WAK >500 and organic search referrals >10% of installs. |
| **School / PTA newsletters** | Summer dead zone (L3 Surface #8). | Promote September 2026; start list-building July. |
| **Library / YMCA / community summer programs** | Agent-hr vs volume unfavorable; hyper-local. | Promote if Pillar 2 dentist model proves out and we want 2nd offline channel. |
| **TikTok Creator Marketplace / Aspire / #paid** | $500–2K minimums; kid-app vertical underperforms (L3 §3). | Promote when budget ≥ $5K AND one creator format has proven organic traction. |
| **Discord / community-build** | Parents of 4–8yo don't join Discords (L1). | Do not promote. Leave dead. |
| **Celebrity narrator / press-agency play (Yoto/Moshi model)** | Requires $10K+ retainer (L4). | Promote on Series-A. |

---

## 7. Sequencing

**Week 0–1:** Pillar 1 runs solo. **Nothing else starts until retention dashboard is live** (L5 invariant). ASO optimization + Play public store-listing polish ship in parallel (same commit window). Why first: it unblocks every downstream pillar's ability to report signal, AND Play public auto-lifting store_listing_conv ~3× is free money only if measured.

**Week 2:** Pillar 2 (dentist) + Pillar 4 (newsletter) child loops kick off in parallel. Both are outreach-heavy and agent-automatable with minimal dependency on each other. T2-A (Cavity Monster song), T2-B (cross-promo outreach), T2-D (metrics page / Beehiiv) all launch Week 2 — they're cheap and each has a 14–30 day kill clock.

**Week 3–4:** Pillar 3 (earned media + Editor's Choice + CSM) child loop starts. Later than 2/4 because it needs the Pillar 1 dashboard + T2-D metrics page as **press assets** — journalists quote numbers. Pillar 3 without instrumentation has a weaker story.

**Week 4–6:** First pillar-level kill/double-down decision. Whichever pillar is <25% of projected WAK-pace gets 50% budget cut; reallocate to the leader. Tier-2 experiments that hit their promote criteria (T2-A if song pings, T2-B if cross-promo replies ≥2, T2-E if creator gifting works) become child-loop pilars.

**Week 7–12:** Ride the leaders. Reserve ~$300 for a single paid content-amplification boost on whatever organic format has already proven CTR (L5 rule: CPM boost of a proven creative, never CPI bidding of unproven creative).

**Trigger for first Tier-3 promotion:** blended organic CAC must be measured and <$2/WAK before any CPI-priced paid spend activates. If Pillar 1 dashboard shows we're tracking to 1,000 WAK by Day 75 with budget remaining, shift to retention/LTV instrumentation rather than more top-of-funnel.

---

## 8. Budget allocation

Total budget: **$1,500 (midpoint of $1,000–$2,000 range).** Hold $500 reserve against the ceiling.

| Bucket | Amount | % | Notes |
|---|---|---|---|
| Pillar 1 (instrumentation + ASO) | $50 | 3% | Almost all engineering time, not cash |
| Pillar 2 (dentist kits) | $500 | 33% | Print, postage, 1–2 courier drops |
| Pillar 3 (earned media + CSM) | $100 | 7% | Mostly agent-hrs; small press-kit + CSM fees |
| Pillar 4 (newsletter sponsorships) | $500 | 33% | 2–4 placements × $100–200 |
| Tier-2 reserve | $300 | 20% | T2-A ($150) + T2-E ($100) + T2-F ($50) |
| Unallocated / Tier-3 activation reserve | $50 | 3% | Held for paid amplification of a proven creative |
| **Total** | **$1,500** | 100% | |

**Deviation from default 70/20/10:** Tier-1 = 76%, Tier-2 = 20%, T3 reserve = 4%. Within spec.
**Paid proportion:** $500 (Pillar 4) + potential $50 (T3 amplification) = ~$550 = **37% paid**, but all CPM/sponsorship-priced, **zero CPI bidding**. Flag honored.

---

## 9. Open questions + uncertainty

1. **What WAK-to-install conversion do we actually have?** L5 base-case 20% D7 / 35% stickiness is a guess. One week of Pillar 1 dashboard data changes which pillar-volume projections are real.
2. **Does iOS land inside the window?** L5 realistic estimate is ~2026-06-05 public iOS. If Apple Business approval slips past 2026-05-01, iOS is out of 90-day window — all 1,000 WAK must come from Android. Pillar allocation doesn't change (none require iOS) but volume ceilings on 2/3/4 tighten ~30%.
3. **Do pediatric dentists actually convert at the rates L2/L3 claim?** Zero public case-study data (L4 §5). The first 3 practices' first 30 days is the real test — if <5 installs/practice/week, Pillar 2 caps at ~100 WAK not 300.
4. **Does Common Sense Media review drive measurable installs?** No public attribution (L4 §5). May be a trust/compounding asset not a WAK driver.
5. **Is the C-pass finding (bridge-page at brushquest.app/rangers) still binding once Play goes public?** L5 says yes for iOS-origin traffic. Worth re-testing with direct Play deep-link A/B once public — could free up 10–15% conversion if bridge is no longer needed for Android.
6. **Is "1,000 WAK" the right target?** L5's sharpest question. If we hit 300 WAK + clean retention cohort data + a working unit-economics model by Day 90, is that a better outcome than 1,000 WAK with no retention data? Current plan aims for both (Pillar 1 guarantees the data even if WAK misses). But if Jim's downstream decision is "raise a seed" vs "keep shipping," the answer changes.

A week of Pillar 1 data changes questions 1, 3, 5. A week of Pillar 2 outreach data kills or confirms the dentist thesis. A week of T2-A (Cavity Monster song) resolves whether character-IP deserves a child loop. **This loop's highest-value next action: write the Pillar 1 PRD now (it's PRD-executable without child loop) and spawn child loops for Pillars 2, 3, 4 in parallel.**

# L5 — First Principles (trunk)

**Question:** 1,000 WAK by 2026-07-20 (90 days) on $1–2K, agentic, Play public + iOS live.

## 1. The growth equation

**WAK target = Installs × D7_retention × habit_stickiness**

Solve for installs given a WAK = 1,000 target at steady state by Day 90:

- Optimistic: D7 = 35%, habit_stickiness (D7→WAK in week 12) = 0.50 → **installs ≈ 5,700**
- Base: D7 = 20%, stickiness = 0.35 → **installs ≈ 14,300**
- Pessimistic (kids apps norm): D7 = 12%, stickiness = 0.25 → **installs ≈ 33,300**

**Installs = Impressions × CTR_creative × LP_conv × store_listing_conv × install_completion**

Plug base-case numbers (Reels/organic social, parent-targeted):
- CTR_creative: 1.5% (ad), 3–5% (organic that hits)
- LP_conv (brushquest.app → Play link click): 25–40%
- store_listing_conv (Play store-listing-page → install): 25% (Play median)
- install_completion: 0.92

→ **Impressions-to-install ≈ 0.10–0.20%** (organic) or **0.02–0.05%** (paid).
For 14,300 installs we need **~7M–70M impressions** over 90 days.

**CAC math:** $1,500 / 14,300 = **$0.105 blended CAC**. Paid ads to parents on Meta run $3–$8 CPI in this vertical. **Paid is off by 30–80×.** Any paid spend must be CPM-priced content amplification, NOT CPI bidding, OR the whole plan is arithmetically impossible.

## 2. Bottlenecks — the dominant coefficient

Ranked by leverage (2× change → outcome delta):

1. **habit_stickiness** (D7 WAK → Week-12 WAK). We have no cohort data. A 2× here cuts required installs in half. Data-gap risk: we literally cannot measure this today (no D1/D7/D30 dashboard). **This is THE coefficient.**
2. **Impressions.** Agentic content engine output volume. Zero-marginal-cost means 2× is cheap IF a format works. But until a format works, 10× is still zero.
3. **LP_conv + destination flow.** C-pass already proved this is a funnel-killer while Play is internal-only. Once Play goes public, this coefficient jumps 3–5× automatically — free money if the public release lands.
4. **D7 retention.** Product-determined. Jim won't change economy until multi-profile ships. Treat as fixed for 90 days.
5. **CTR_creative.** Matters only after #1-3 are unblocked.

## 3. Assumptions that deserve re-test

- **"1,000 WAK is the right target."** Assumed. If wrong, $1–2K is wasted chasing a vanity number. At 20% D7 × 35% stickiness, 1,000 WAK ≈ 14K installs. A better Tier-1 outcome on this budget might be **300 WAK + signed 90-day retention cohort data + a working paid-loop unit economics model** — actionable for a Series-A-style decision, cheaper to hit, more informative. **Test:** ask "what decision does 1,000 vs 300 WAK unlock?" If no decision changes, the number is vanity.
- **"Agentic + $1–2K are compatible."** Assumed. Agentic content production is cheap; paid distribution is not. **Compatible only if the plan is 95% organic/earned.** If any Tier-1 pillar requires paid bidding CPI, the plan breaks. **Test:** strip every dollar of CPI bidding from the top candidate pillars and check if the install math still closes.
- **"Play public + iOS live by 2026-07-20 is the binding constraint."** Assumed. Play public is imminent (submitted 2026-04-11, likely clears any day). iOS depends on Apple Business (due ~2026-04-24) + TestFlight (2–4 weeks) + App Review (1–2 weeks) = **realistic iOS public ~2026-06-05**. iOS live is PROBABLE but not guaranteed. **If iOS slips, Android-only 1,000 WAK is still feasible.** Don't design any Tier-1 pillar that REQUIRES iOS.
- **"C-pass tester_signup_rate finding is resolved by Play public."** Partially. Public Play listing eliminates the 5-step Google-group phishing flow — that coefficient goes from ~8% to ~25% (Play median). **But iOS parents still hit TestFlight signup (code + email + Apple ID flow) which is equally hostile.** The bridge-page (brushquest.app/rangers) rule stays binding for iOS-origin traffic even after Play public. Don't retire it.
- **"Installs convert to brushing."** Assumed. Onboarding → first-brush completion rate is untracked. If <50%, the whole equation shifts. **Test:** add first-brush event in next release, measure for 1 week.

## 4. The invariant

**Regardless of route: we must instrument D1/D7/D30 cohort retention and first-brush-completion BEFORE Day 30, or the 90-day plan is flying blind.** Every dollar and hour spent on distribution without this instrument is non-compounding — we learn nothing from 100 installs or 10,000. The factory currently tracks installs and brushes separately; nothing joins them into a cohort. **No Tier-1 pillar is real without this dashboard live in Week 1.**

## 5. Ranked takeaway (requirements, not routes)

1. **Cohort retention instrumentation** (blocks learning from any pillar)
2. **Destination-URL rule** (brushquest.app/rangers bridge; binding for iOS even after Play public)
3. **One organic format that hits** — the engine needs proof-of-format before volume matters
4. **Play public listing live** (unlocks store_listing_conv ≈ 3× automatically, free)
5. **Parent-facing value prop** (kid can't read; parent is installer AND gatekeeper AND sharer)

## 6. Quick failure modes

- **Mistaking the equation for the territory.** The model ignores word-of-mouth compounding (which parent apps actually survive on) and assumes linear impression→install. Real kid-app growth is bimodal: zero, or viral.
- **Over-indexing on installs vs first-brush.** 10,000 installs where 20% never open is worse than 2,000 installs where 80% activate. The question anchors on WAK, but the equation above anchors on installs — watch the handoff.
- **Treating "agentic" as free.** Agent time has no dollar cost but consumes Jim's 5–10 hrs/week review bandwidth. Three pillars × agent churn = Jim becomes the bottleneck, not the budget.

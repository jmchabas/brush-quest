# Synth-v1 — Instagram Reels → 50 Qualified Parent Installs in 14 Days

**Node:** `trunk/marketing/ugc/instagram-reels`
**Date:** 2026-04-20
**Binding decisions:** budget $1–2K total for whole launch (this node ~$500 cap), founder not face-of-brand, COPPA-strict (no child face/voice in repostable artifacts), organic IG Reels is the named channel, Play internal testing is LIVE but public review pending (1–7 day window from 2026-04-11).

---

## 1. Question restated

Produce agent-executable PRDs that deliver **50 qualified parent installs** (parent of a 4–8yo, completed Play internal-tester enrollment, installed, ideally D1-retained) in **14 days** from **organic Instagram Reels**. The question is nominally Reels-only; L5 and L2 both argue the scoping is the trap. The honest framing: Reels is the node, but the fitness function is installs — so Reels must either (a) drive enough cold-traffic to overcome the internal-testing enrollment funnel, or (b) act as a trust/credibility layer while a warmer channel books most of the 50.

---

## 2. Where the lenses agree (≥3 of 5)

1. **Cold-start on a brand-new @brushquest handle will not deliver 50 installs in 14 days from Reels alone.** L1 ("14 days is too short … creator content compounds 30–90 days"), L2 ("cold-start penalty is 2–4 weeks minimum … organic Reels at your account age is a physics problem"), L4 ("no public kids-app organic-Reels case study surfaced in 15 queries"), L5 ("~310 reels required at median coefficients" — mathematically infeasible). This is the single loudest signal in the research.
2. **Borrowed warm-start beats built warm-start inside 14 days.** L1 (#1 ranked play: micro-creator seeding), L2 (Bet A: one paid creator, $400–600 batch), L4 (small-creator seeding is the empirically highest-probability path), L5 ("a single micro-influencer parent-share beats 50 brand reels"). All four agree: the account that posts the winning Reel should already have followers.
3. **Reddit (specifically r/androidtesting + parent subs) is a near-layup for 15–40 testers in days, not weeks.** L1 §2, L2 (Bet C), L3 (ranked #1 by installs/hour). L5 doesn't name Reddit but implicitly endorses "replace the destination" with any surface that short-circuits the Play internal-testing funnel — Reddit androidtesting users already know the Google-group dance.
4. **The Play internal-testing funnel is the dominant coefficient killing conversion** for cold, non-technical parents. L3 warns explicitly ("FB/Reddit shadow-remove Play links … send traffic to brushquest.app"). L5 formalizes it ("Play internal testing is NOT a consumer install URL … requires joining a Google group … <10% completion"). L1 and L2 flag the same asymmetry via "bridge via brushquest.app email capture." Four of five lenses converge on: **redirect to landing page, don't send cold Reels traffic to the Play link.**
5. **Brand tone / format: parent-confessional, tired-9pm voice, hands-only or hero-character framing (no kid face) — that's the organic Reels creative spec.** L1 (founder-POV), L2 (Bet B confessional format), L3 ("things my 7yo hates #7: brushing"), L4 (tired-parent genre, hands-only Yoto-style framing).

---

## 3. Where the lenses disagree

**Disagreement A — "Is the question as-stated achievable?"**
- L5 says no: the math demands virality and the destination is broken.
- L1/L2/L3/L4 say the **50-install number** is achievable but **not from Reels alone** — Reddit + micro-creator + founder network fill the gap; Reels is the content asset, not the sole funnel.
- **Resolution:** Trust L5 on the math, trust L1–L4 on the portfolio shape. The plan below accepts L5's infeasibility-if-Reels-only finding and reshapes the portfolio so (a) Reels is instrumented as a content asset that feeds multiple surfaces, and (b) the 50-install target is defended by Reddit + micro-creator + warm network in parallel. The stated question stays; the plan is honest that Reels is co-author, not sole author.

**Disagreement B — "Brand handle Reels from scratch: valuable or doomed?"**
- L1 says ship a founder-POV handle anyway (brand exists for credibility downstream).
- L2 says cold brand handle is algorithmically suppressed — the whole 14 days is wasted there; borrow a creator's warm-start instead.
- L4 says pure brand-handle no-face Reels have the lowest confidence.
- **Resolution:** L2 wins on the 14-day horizon. Brand handle gets 3–5 warm-up Reels as a trust layer (so Reddit parents who google the app find something real — matches L2 Bet C's framing) but is NOT load-bearing for installs. Load-bearing work is done via borrowed warm accounts (creators, Reddit, Jim's network).

**Disagreement C — "Paid-creator-organic-post: is it 'organic'?"**
- L2 says yes (IG algorithm doesn't know about the handshake — the post itself is organic-feed reach).
- L1 aligns (UGC micro-creator seeding is #1 ranked).
- L3 warns about flat $200–500 micro-creator pay being a money trap without a warm relationship.
- **Resolution:** L2's framing is correct on the reach mechanic, L3 is correct on the $-per-post risk. Synthesis: do NOT pay a flat $400–600 upfront. Run L2's **cheap proxy test first** — $120 single paid post or free-app + $20 gift card (L3's variant) — and only scale to a batch after proxy hits ≥8 installs.

**Disagreement D — "Destination: Play Store directly, or brushquest.app?"**
- L5 says brushquest.app is mandatory (internal-testing funnel is the dominant coefficient killer).
- L3 says brushquest.app is the bridge so you keep attribution when FB/Reddit suppress Play links.
- L1 implicitly assumes Play direct.
- **Resolution:** L5 wins. All Reels bio links, Reddit links, creator captions route to **brushquest.app/rangers** (new UTM-sourced landing path) which: (1) captures email → Buttondown, (2) shows a "how to join internal testing in 3 taps" walkthrough with screenshots, (3) auto-enrolls tester via backend once public review clears. This is an additive PRD the node must ship.

---

## 4. Tier-1 bets (main pushes)

| # | Bet | Hypothesis (lens) | Expected CAC | Expected volume (14d) | Time-to-signal | Budget + agent-hrs | Readiness |
|---|---|---|---|---|---|---|---|
| T1a | **r/androidtesting + r/daddit dual-post, Reels in profile as trust layer** | L2 Bet C + L3 rank-1: parent subs + androidtesting convert 15–40% on honest founder posts; Reels exists so parents who google find something | $0–2 (time only) | 20–35 installs (of which ~12–20 "qualified parents" after dilution filter) | 48–72 hrs from first post | $0 + 4 agent-hrs draft, 2 Jim-hrs reply | **PRD-executable now** |
| T1b | **Micro-creator paid proxy → scale** | L1 #1 + L2 Bet A + L4 #1: one $120 nano-creator post (5–30K, parenting/bedtime niche, audience-fit verified) → if ≥8 installs in 72h, scale to $400 batch with same creator | $8–20 proxy, $5–12 at scale | 8–15 from proxy; 20–40 from batch if promoted | 72 hrs proxy, 10 days batch | $120 proxy + $0–400 scale + 6 agent-hrs scouting/outreach + 2 Jim-hrs contracts | **PRD-executable now** (needs creator-scouting PRD + audience-fit verification PRD) |
| T1c | **brushquest.app/rangers landing path + email-to-auto-tester pipeline** | L5 #1 + L3: replace the destination. All Reels/Reddit/creator traffic lands here; email capture + 3-tap internal-testing walkthrough + auto-enroll backend | N/A (enables all others) | Lifts every other bet's conversion ~2–3× | Must ship Day 1–3 | $0 + 8 agent-hrs landing-page + 6 agent-hrs Buttondown→Firebase auto-enroll + 1 Jim-hr review | **PRD-executable now** (but is a dependency for T1a/T1b/T2) |
| T1d | **Buttondown list + warm network sweep** | L1 #2: cheapest installs on the plan. Existing list opens at 20–40%. Plus Oliver's 2nd-grade parent list (L3 rank-2, PTA = highest installs/hour) | $0 | 10–25 installs (layup) | 48 hrs | $0 + 2 agent-hrs email draft + 1 Jim-hr send + 2 Jim-hrs PTA outreach | **PRD-executable now** |

Tier-1 total: ~$520 max, ~31 agent-hours, ~7 Jim-hours. Stacks to ~58–115 installs if all hit mid-case — intentionally over-subscribed because Reddit posts get removed (L3's "1 of 2 gets removed") and creator proxy may kill.

---

## 5. Tier-2 experiments (parallel cheap tests, each ≤$100 and one variable)

| # | Experiment | Single variable | Kill criterion | Budget | Agent-hrs |
|---|---|---|---|---|---|
| T2a | **Throwaway-handle parent-confessional format test** (L2 Bet B proxy) | Does the "things I said tonight as a parent" format pop at cold-start from zero followers? | Median reach <500/Reel across 3 posts in 5 days → kill format | $0 | 4 |
| T2b | **2 Reels from Jim's personal IG** (not @brushquest) | Does a warm personal account delivery >3× cold brand-handle reach for same creative? | If personal-account reach <2× @brushquest same-day posts → warm-start hypothesis wrong | $0 | 2 |
| T2c | **Pediatric-dentist QR poster (Oliver's dentist first)** (L1 + L3) | Does a warm offline surface convert? | <3 installs in 14 days → deprioritize; leave poster up for month-2 compound | $20 print | 2 agent + 1 Jim |
| T2d | **Substack pitch to 3 parenting writers** (Parent Data, Screen Time Consultant, What Fresh Hell) | Does founder-story cold pitch land a mention? | 0 of 3 respond in 10 days → kill | $0 | 3 |
| T2e | **Slideshow-carousel-Reel format** (L4: proven format for habit apps) | Does a 5-slide UI-screenshot Reel out-perform talking-head on our handle? | Views < talking-head baseline after 2 posts → kill format, not channel | $0 | 3 |
| T2f | **FB group seed (Tired as a Mother + 1 local)** (L3 rank-6) | Does any FB mom group convert past link-suppression via bio→landing bridge? | <3 installs from FB-tracked UTM in 14 days → confirm L3's low-confidence call | $0 | 3 + 1 Jim |

Tier-2 total: ~$20 + ~17 agent-hours + ~2 Jim-hours. All single-variable, all killable by Day 7.

---

## 6. Tier-3 parked (revisit on trigger)

| # | Route | Trigger to promote |
|---|---|---|
| T3a | **Paid Meta/TikTok app-install ads** | When any organic Reel ≥50K plays OR creator proxy CAC <$15 (then paid can lean on proven creative) |
| T3b | **Public retention dashboard on brushquest.app/live** (L1 non-obvious bet) | When WAK ≥ 50 (need real numbers to display) |
| T3c | **Pediatric-dentist / Montessori partner network** (beyond Oliver's) | When Oliver's-dentist poster hits ≥5 installs in 30 days |
| T3d | **Product Hunt Kids/Family launch** (L3) | When public Play review clears AND email list ≥200 (needs warm cohort to upvote Day 1) |
| T3e | **Brand-handle daily Reels engine** (L1 #4 / L4 #2) | When ONE reel from anywhere (throwaway, creator, Jim's personal) clears 10K plays with a repeatable hook — then invest in scaling THAT hook |
| T3f | **"Changelog-as-marketing" + founder-POV build-in-public** (L1 non-obvious) | When face-of-brand constraint is resolved (hired creator OR Jim changes mind) |
| T3g | **Moshi-style paid UA + ASO + partnerships** (L4 analogue pattern) | When monetization unlocks and CAC math reverses (post-launch + paid conversions tracking) |

---

## 7. Sequencing

- **Day 0–1:** Ship T1c (landing path + email-auto-enroll). This is the bottleneck for every other bet. Non-negotiable prerequisite.
- **Day 1:** Fire T1a Reddit posts (r/androidtesting first, then r/daddit 24 hrs later). Fire T1d (Buttondown email + PTA outreach). Start T1b creator scouting + T2b personal-account test in parallel.
- **Day 2–4:** T1b $120 proxy post goes live. T2a throwaway-handle format test starts posting. T2c dentist poster up.
- **Day 5:** First decision gate. If T1a ≥12 installs AND T1b proxy ≥8 installs → green-light T1b scale batch ($400). If T1a ≥20 → consider NOT scaling T1b (we're on pace). If T1b proxy <3 → kill T1b, reallocate $400 to T3b (public dashboard becomes the content hook) OR hold as activation reserve.
- **Day 7:** Tier-2 cull. T2a/T2b/T2e get killed per criteria above. Any Tier-3 trigger that fires → promote.
- **Day 10:** Second Reddit post window (cross-sub, different angle). Creator batch Reel #2 if scaled.
- **Day 14:** Count qualified installs (definition: parent-identified email on landing + Play internal-tester enrollment confirmed + ≥1 brush session logged in Firestore). Write loop retrospective.

---

## 8. Budget allocation

Default is 70/20/10. Actual for this node:

| Tier | $ | % | Why |
|---|---|---|---|
| Tier-1 | $520 | 90% | Creator proxy+scale ($520) plus dentist print ($20 classified under T2c) — this node's budget cap is ~$500–$600 of the $1–2K whole-launch budget |
| Tier-2 | $20 | 3% | Most T2s are $0 (format tests on throwaway handles, substack cold pitches) |
| Tier-3 activation reserve | $40 | 7% | Small; most T3 triggers require product-side progress (public review, WAK) not money |

**Deviation from default:** Tier-1 is 90% not 70% because the creator-scale step (conditional on proxy) is the single biggest bet in the portfolio and must not be starved. Tier-2 is intentionally under-budgeted because these experiments are near-free — the cost is agent-time, not dollars. The unspent $400–$800 of whole-launch budget is reserved for post-14-day scale decisions (Tier-3 T3a paid UA once creative is proven).

---

## 9. Open questions + uncertainty

**Question premise reshaping (per L5, surfaced per instructions):**
1. **The 50-installs-from-Reels-only goal is misfit with cold-start physics.** The portfolio above defends the *50 installs in 14 days* target but sources most from Reddit + warm network + creator, not from @brushquest organic Reels. If the trunk loop reads this and says "no, we need 50 specifically from Reels" — the honest answer is: wait 30–60 more days, budget $2K paid, or accept that Reels is a content asset not a funnel for the first 14 days. L5's math is not wrong; we're routing around it.
2. **"Qualified" is undefined.** Context brief lists marketing attribution and retention cohorts as not-yet-tracked. PRD T1c must also ship a minimum attribution stack (UTM → Firebase → "qualified = email captured + tester enrolled + ≥1 brush in 3 days"). Without this, 14-day retro is vibes.
3. **Play internal-testing enrollment completion rate** for non-technical parents is unknown (L5 §3 "expect <30%"). T1c needs a measurable walkthrough step so we can see the drop-off. If drop-off is >80%, wait for public review before scaling T1b.
4. **Public Play review ETA.** Submitted 2026-04-11; window is 1–7 days. As of 2026-04-20 it's Day 9 and review may clear mid-sprint — if it lands Day 5, T1c's "auto-enroll" path becomes a direct Play URL and conversion jumps 2–3×. Build T1c to flip between "tester enrollment mode" and "public install mode" on a single config flag.
5. **Creator audience-fit verification.** L2 correctly flags that a $600 creator with wrong audience is worse than $0. PRD for T1b must require creator to send screenshot of follower demographic breakdown (age 25–44F share ≥50%, US parent share ≥40%) BEFORE payment.
6. **iOS is scaffolded and Apple Business review clears ~2026-04-24** — inside our 14-day window. No PRD should hard-code "Android-only." Landing page copy should read "Android now, iOS soon" with email capture for iOS waitlist; that increases conversion of iPhone parents (probably 55% of our reachable audience) from 0% to email-capture rate.

**What a week of data would change:**
- If T1a (Reddit) overshoots by Day 5, T1b scale becomes optional and budget rolls to T3a.
- If T1b proxy confirms creator route, we buy 2–3 more creator proxies on Day 8 and push Tier-1 to 5 bets for the second week.
- If @brushquest organic Reels (posted as warm-up) hit 10K plays on any single Reel, T3e promotes to Tier-1 for loop 2.
- If Play public review clears, re-score the whole portfolio — the funnel coefficient L5 identified stops dominating and Reels-direct becomes viable again.

---

**Child loops needed (flagged to trunk synthesizer):**
- T1b creator-scouting PRD (how agents verify audience-fit without Modash paid tier)
- T1c landing-path + auto-enroll engineering PRD (Buttondown → Firebase tester-list writer)
- Attribution PRD (UTM + Play referrer + Firestore "first-brush" stamp)

**Everything else in this plan is PRD-executable now.**

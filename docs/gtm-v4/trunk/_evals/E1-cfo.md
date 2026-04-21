# E1 — Skeptical CFO + Attribution Evaluation

**Target:** Synth-1 trunk portfolio (2026-04-21)
**Reviewer lens:** post-seed consumer-app CFO; burned by unprovable CAC.

---

## 1. Overall ROI read

The plan is **internally coherent but weakest on volume math in Pillars 3 and 4.** The Pillar 1 instrumentation-first thesis is financially sound: $50 cash + 15–25 eng-hrs to gate ~$1,450 of downstream spend means every attribution-less dollar saved pays for Pillar 1 three-times-over. That sequencing is the single strongest call in the synth.

**The weakest number: Pillar 3's "1,000–3,000 visits × 40% LP conv × 25% install = 100–300 WAK."** A 40% LP→email and 25% email→install is aspirational; published parenting-app LP benchmarks run 15–25% and 10–15% respectively. Real yield is closer to **1,000–3,000 × 20% × 12% = 24–72 WAK**, i.e. a 3–4× haircut. The CAC band "$1/$4/$10" silently assumes the high end holds.

Second-weakest: **Pillar 4's "500–2,000 visits per $100–200 send"** (effective $50–400 CPM). Parenting Beehiivs at ~5K subs and 40% open rates yield closer to $150–250 CPM once you strip bot clicks. Acceptable, but tighter than implied.

---

## 2. Attribution audit (by bet)

**Pillar 1 — Instrumentation.** Measurable: yes, by definition. Attribution gap: none (it IS the attribution). Time-to-signal 7 days is realistic **only if** Play install referrer is wired on day 1 (Play Console exposes `INSTALL_REFERRER` → UTM match). Tail risk: dashboard ships without Play-referrer join → every downstream pillar reports blind. **Acceptance criterion must be "Play referrer events visible in posthog cohort view," not "dashboard live."**

**Pillar 2 — Dentists.** Measurable: partially. QR-at-office → `brushquest.app/rangers?utm_source=dentist_{practice_id}` is trackable. Gap: parent may scan QR in-office but install at home on a different device — no stitch. Time-to-signal 21 days is **optimistic**; cold pediatric-practice outreach typically takes 45–60 days to first yes. Tail risk (2× cost / 0.5× volume): $1,000 printed, 100 WAK — CAC = $10/WAK, still inside the $12 hi band. Acceptable tail.

**Pillar 3 — Earned media + CSM + Editor's Choice.** Measurable: weakly. Press mentions can't be attributed without unique URLs in every pitch (do this). CSM driving installs: **zero public attribution data** (synth §9 Q4 admits this). Editor's Choice: **timing is entirely Google's call, 6–12 month typical window** for new apps — this is the item I'm most skeptical of as Tier-1. Tail risk: 0 pickups × $200 = sunk; but the real tail is **10–40 agent-hrs sunk into CSM packet that yields vanity-badge not installs.**

**Pillar 4 — Newsletter sponsorships.** Measurable: yes, cleanest of the four (UTM in send link, Beehiiv exposes clicks). Attribution gap: small. Tail risk: 2 sends × $250 × 0% install conversion = $500 gone, 0 WAK. CPM-priced is honest but **ROI measurability ≠ ROI guarantee** — known cost, unknown conversion.

---

## 3. Strengthen

1. **Pillar 1 acceptance criterion:** "Play Install Referrer join visible in cohort dashboard" — not "dashboard live." No downstream pillar PRD starts until this fires.
2. **Every Pillar 3 pitch email** carries a unique tracking URL (`/rangers?utm_source=press_{outlet}_{writer}`). No exceptions.
3. **Pillar 2 sub-PRD (d)** must specify the **device-stitch fallback**: parent email capture at QR scan → email→install match via Firebase Auth sign-in event. Otherwise dentist attribution collapses.
4. **Pillar 3 CAC band revise to $3 / $10 / $25** to reflect realistic LP→install yield. If this breaks portfolio math, that's the real signal.
5. **Pillar 4 first sponsorship is $100 test-send**, not $200 — one data point on real click→install before committing the other $400.

---

## 4. Test (cheap experiments to de-risk)

1. **$100 Pillar 4 single-send pilot (Week 2).** Buy one $100 parenting-Beehiiv sponsorship, UTM-tracked. Decision: install conv <2% → cap Pillar 4 at $300 total. Changes confidence on 33% of budget.
2. **Pillar 2 "yes-rate" email blast (Week 2, $0).** 30 pediatric practices cold-emailed with agent-personalized pitch. <3 replies in 14 days = dentist thesis is 40% less real than assumed; redirect $200 to Pillar 4 or T2-E. This is the highest-leverage cheap test in the whole plan.
3. **CSM timeline-reality check (Week 1, $0, 30 min).** Email one CSM reviewer or check their public queue. If review-cycle is >90 days, Editor's Choice + CSM cannot contribute to the 1,000-WAK target by 2026-07-20 — reclassify immediately.

---

## 5. De-prioritize

- **Editor's Choice nomination as Tier-1 component of Pillar 3.** Timing is unforecastable and typically post-1,000-install. **Move to Tier-3 with trigger: promote when Play installs ≥ 5,000 AND rating ≥ 4.5 with ≥ 100 reviews.** Keep CSM + press pitches as Tier-1; strip Editor's Choice out.
- **Common Sense Media as install driver.** Keep submission (trust asset, ~2 agent-hrs), but **remove from WAK-volume projection.** Trigger to promote back: any referral ≥ 50 installs attributable to CSM within 60 days.

---

## 6. Overall confidence

**Medium-high (~70%) that Pillar 1 + Pillar 2 ship and measure; medium-low (~40%) on hitting 1,000 WAK by 2026-07-20.** Flip me to high with one number: **Pillar 2's first-practice yes-rate ≥ 15% on the first 30 cold emails** — that single datum converts the dentist thesis from literature-backed to owned.

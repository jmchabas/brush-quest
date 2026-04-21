# L5 — First Principles

**Lens:** L5 (First Principles)
**Node:** `trunk/marketing/ugc/instagram-reels`
**Question:** 50 qualified parent installs to Play Store **internal testing** in 14 days via organic Reels.

---

## 1. The growth equation

Mechanical funnel for organic Reels → Play internal testing install:

```
installs = reels_published
         × avg_plays_per_reel
         × profile_visit_rate     (plays → profile taps)
         × link_in_bio_click_rate (profile → outbound tap)
         × tester_signup_rate     (bio link → opt-in form submit + Google group join)
         × play_install_rate      (email accepted → Play listing → install)
```

Believable organic-IG ranges for a brand-new, zero-follower kids account in 2026:

| Coefficient | Believable range | Rationale |
|---|---|---|
| `avg_plays_per_reel` | 200 – 5,000 (median ~800) | No follower graph; depends entirely on the algorithm pushing to cold interest clusters. |
| `profile_visit_rate` | 0.5% – 3% | Parent viewers "save, don't click." Curiosity > intent. |
| `link_in_bio_click_rate` | 3% – 10% of profile visits | Friction: bio link is extra tap. SaaS benchmarks (>20%) do NOT apply. |
| `tester_signup_rate` | 15% – 40% | Internal-testing flow requires (a) email submission, (b) joining a Google group, (c) accepting a tester link, (d) THEN seeing Play listing. Each step halves throughput. |
| `play_install_rate` | 40% – 70% | After a parent makes it this far, intent is high. |

Solving for 50 installs at mid-point coefficients (800 × 0.015 × 0.06 × 0.25 × 0.55):
**One reel converts ≈ 0.01 installs.** To hit 50 installs → **~5,000 plays per install** → need **~250,000 aggregate plays in 14 days**. At 800 plays/reel median, that's **~310 reels** — not feasible organically. At one viral reel of 50k+ plays, 5 hits would do it. **The equation demands virality, not volume.**

## 2. Bottlenecks (by the equation)

1. **`tester_signup_rate` is the silent killer.** Play internal testing is NOT a consumer install URL. It's a ~5-step enrollment flow that looks like phishing to a non-technical parent. This coefficient is likely **<10%**, not 25%. If true, we need 2–3× the top-of-funnel. **This single coefficient dominates.**
2. **`avg_plays_per_reel`** on a cold account. No follower base = no graph boost = algorithmic cold-start. First 5–10 reels typically plateau at 200–500 plays regardless of quality.
3. **`profile_visit_rate`** for a kids-brushing topic: parents watch, laugh, scroll. Low intent-to-act signal on IG vs. TikTok (TikTok has 2–3× higher profile-tap rates for parenting content per 2025 Later/Hootsuite data).

## 3. Assumptions that deserve re-test

- **Assumed: "Parents of 4–8yo are reachable on Instagram Reels."** Partially true. Pew 2024: ~50% of US parents 30–49 use IG, but Reels engagement skews <30yo and non-parent. The addressable parent-on-Reels segment that also watches parenting content is maybe 15–25% of total IG usage. **Test:** Post one reel, measure parent-demo share in IG Insights after 72h. If <30% of viewers are 25–44F, the channel is misfit.
- **Assumed: "Play Store internal testing" is a usable funnel destination.** Almost certainly false for cold parents. The flow requires joining a Google group, waiting for propagation, re-clicking a Play link — this is a **dead-end** for non-technical users. **Test:** Have 5 real parents (non-Jim network) attempt the flow end-to-end. Measure completion. Expect <30%. **If true, this single coefficient makes the 14-day target nearly impossible unless public Play review lands first.**
- **Assumed: organic Reels can produce 50 of ANYTHING in 14 days from a zero-follower account.** Benchmark: new kids/parenting IG accounts typically need 3–6 weeks before the algorithm gives consistent 1k+ play delivery. **Test:** Audit 10 cold-start kids-app IG launches (publicly visible via Socialblade). Median time to 50 off-platform conversions is likely 45–90 days.
- **Assumed: "qualified parent" is definable/measurable.** What is "qualified"? Has a 4–8yo kid? Completed the tutorial? Brushed twice? The target number means nothing without the definition — and measurement requires attribution (UTM + Play referrer), which is listed in context as **not yet tracked**.
- **Assumed: COPPA-compliant Reels can be compelling.** No kid faces, no kid voices, hero-as-proxy. This strips the most reliably viral format (real-kid reaction). **Test:** Compare CTR of hero-puppet reel vs. parent-POV voiceover reel (both COPPA-safe).

## 4. The invariant

**Regardless of the route, the funnel dies at whichever step parents hit a non-consumer-grade surface.** Today that step is Play internal testing enrollment. No volume of reels, no creative virality, and no influencer boost can push more water through a pipe that requires a Google group invite to reach the tap. Every Reels PRD must either (a) wait for public Play review to unblock a clean install URL, or (b) redirect traffic to `brushquest.app` email capture and accept that "install" becomes "email, then install on launch day" — which is not the 50-installs metric as stated.

## 5. Ranked requirements (by leverage)

1. **Replace the destination.** Land all traffic at `brushquest.app`, collect email, auto-enroll tester + auto-send Play link when public review clears. Fixes the dominant coefficient. Applies to every other route (TikTok, influencer, PR).
2. **Redefine the goal.** "50 qualified email-captured parent leads + public-install conversion" is achievable in 14d; "50 internal-testing installs" is not, under current Play mechanics.
3. **Instrument attribution before the first post.** UTMs + Play referrer + landing-page source param. Otherwise none of the reel data is learnable.
4. **Seed the algorithm before scale.** 3–5 warm-up reels to any organic audience before expecting creative A/B data to be valid.
5. **COPPA-safe format library**, chosen last — creative matters less than a working funnel.

## 6. Failure modes of first-principles thinking

- **Model-as-territory:** the equation treats parents as coefficients; actual parents make install decisions inside 3-second emotional windows the math cannot capture.
- **Bottoms-up math over-indexes on medians.** Organic social is a power law; one 500k-play reel trashes the whole average model. "250k plays required" may be wrong by 10× in either direction.
- **"Re-derive from atoms"** can discount real community dynamics (a single micro-influencer parent-share beats 50 brand reels) and treat a warm-start playbook as inadmissible when it is, in fact, the dominant mechanism.

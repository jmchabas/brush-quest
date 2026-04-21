# E1 — Skeptical CFO + Attribution Evaluation

## 1. Overall ROI read

Plan is internally coherent on portfolio shape but NOT on ROI math, because the ROI math is written against an undefined "qualified install." Budget $520 / target 50 qualified = **blended CAC ceiling $10.40**. Synth claims stack-to-115 installs mid-case — if real, CAC lands $4.50, which would be a bargain for a kids app (industry paid UA CAC $3–$8 organic-equivalent, $15–$40 paid). **Weakest number: T1b proxy "≥8 installs in 72h at $120" = $15 CAC with n=1 creator.** A single-post binomial at n≈5K–30K followers has an enormous variance band; one post is not a signal, it's a coin flip. Everything downstream (the $400 scale decision at Day 5) rests on a sample size that cannot distinguish signal from noise.

## 2. Attribution audit (by bet)

**T1a — Reddit (r/androidtesting + r/daddit).** *Measurable?* Partially. Reddit→brushquest.app/rangers UTM is trackable in GA/Plausible; Play internal-tester enrollment is trackable in Play Console (testers tab). *Attribution gap:* No Play Install Referrer for internal testers (it only fires on public Play URLs); we cannot confirm a UTM-tagged click and a tester enrollment are the same human without email match. *Time-to-signal:* 48–72h is believable for Reddit (peaks within 24h). *Tail risk:* Posts get removed (L3's 50% removal rate) → 0 installs, $0 burned. Low cash risk, high volume risk.

**T1b — Micro-creator proxy→scale.** *Measurable?* Creator→UTM→landing yes; creator→Play tester conversion requires email-join as the pivot. *Attribution gap:* Major. n=1 at $120 cannot distinguish a 3% CTR winner from a 0.5% CTR dud; "≥8 installs in 72h" as a scale gate is statistically underpowered. *Time-to-signal:* 72h is IG-realistic for Reel saturation but brand-new creators often keep growing 14+ days. *Tail risk:* 2× cost / 0.5× volume = $1040 for ~10 installs = **$104 CAC**, blowing 50% of whole-launch budget on one channel.

**T1c — Landing path + auto-enroll.** *Measurable?* Yes — the whole attribution stack depends on this. Email capture, UTM persistence, Firebase tester-list writer are all event-generating. *Attribution gap:* None if built correctly; every other bet degrades to vibes without it. *Time-to-signal:* N/A (infrastructure). *Tail risk:* 14 agent-hrs of build for a component that may be obsoleted by Play public review clearing mid-sprint.

**T1d — Buttondown + PTA.** *Measurable?* Buttondown open/click yes; PTA word-of-mouth is a black hole. *Attribution gap:* PTA installs will arrive untagged. *Time-to-signal:* 48h believable. *Tail risk:* Near-zero cash; capped volume ceiling.

## 3. Strengthen

1. **Acceptance criterion on T1c BEFORE T1a/T1b fire:** UTM round-trip test from a burner phone — click Reddit-tagged link → email capture → tester enrollment → first brush in Firestore, with all four events joinable on a single `parent_id`. No attribution, no spend.
2. **Define "qualified install" as code, not prose:** `parent_email_captured=true AND play_tester_enrolled=true AND first_brush_timestamp IS NOT NULL within 72h`. Write the Firestore query into the PRD so the Day-14 count is deterministic.
3. **Move T1b scale gate from n=1 to n=2.** Run TWO $120 proxies in parallel with different creator archetypes (tired-mom vs. dentist-adjacent). Total risk rises to $240, but scale decision is no longer a coin flip. Scale budget drops from $400 to $280 to keep Tier-1 total under $640.
4. **Require Play Install Referrer instrumentation NOW** so the moment public review clears mid-sprint the plan auto-upgrades attribution quality.

## 4. Test (cheap experiments to de-risk)

1. **UTM plumbing smoke test ($0, 2 agent-hrs):** Before any creator spend, verify landing→Buttondown→Firebase joinable on `parent_id`. Kill T1b until green.
2. **Reddit removal-rate dry run ($0, 1 Jim-hr):** Post a benign "seeking testers" thread in r/androidtesting with a throwaway account 48h before T1a. If removed within 6h, rewrite T1a copy and secure mod DM pre-approval.
3. **Creator audience-fit verification gate ($0, 3 agent-hrs):** Require screenshots of Instagram Insights showing ≥50% F25–44 and ≥40% US-parent share BEFORE the $120 transfers. Synth §9.5 flags this; make it a hard PRD precondition, not a soft ask.

## 5. De-prioritize to Tier-3 (with trigger)

- **T2c Pediatric-dentist QR poster → Tier-3.** CAC story is unmeasurable (QR scan source is trackable but in-office attribution decays; <3 installs in 14d is below measurement threshold). Trigger back to Tier-2: when T1c landing surfaces ≥10 captured emails from ANY offline surface, confirming QR→email pipeline works.
- **T2f FB group seed → Tier-3.** L3 low-confidence + link-suppression + zero attribution clarity in closed groups. Trigger: when a Reddit-parallel post (T1a) yields ≥10 installs, signaling the parent-community pitch converts, THEN test FB with proven copy.
- **T2e Slideshow carousel format → Tier-3.** Format test on a cold handle conflates format-signal with algorithmic-suppression-signal. Trigger: when any single Reel (warm or cold) clears 2K plays, then A/B format on the warmer surface where the variable is isolable.

## 6. Overall confidence

**Confidence band: 45–55%** the plan hits 50 qualified installs in 14 days as defined. The single number that would flip me to 70%+: **T1c UTM round-trip test passes end-to-end (email→tester→first-brush joinable) before Day 3**, with a burner-phone proof artifact in the PRD. Without that, Day-14 retro is a story, not a number.

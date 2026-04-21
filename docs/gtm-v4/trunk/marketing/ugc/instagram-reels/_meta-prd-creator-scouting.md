# Meta-PRD — Micro-creator scouting + audience-fit verification at scale

**Parent node:** `trunk/marketing/ugc/instagram-reels`
**Serves bet:** T1b — Dual $120 paid micro-creator proxies (n=2, parallel archetypes)
**Status:** charter for a child loop — NOT PRD-executable until child loop resolves
**Created:** 2026-04-20

---

## Child question

Without a Modash, Creator.co, or IG Creator Marketplace MCP, how does an agent scout, verify audience-fit for, and shortlist micro-creators (follower 5K–50K) whose audience is ≥50% F25–44 and ≥40% US-parent share, in a way that's reproducible and auditable rather than trust-based?

## Why this isn't PRD-executable now

Missing criterion 5 (tools exist OR flagged TO-BUILD) — decisively. Secondary gaps on 2, 3, 4.

- **No creator-discovery MCP** in the current toolkit. `WebSearch` + `WebFetch` can surface public creator handles, but audience demographics are *not* public — they live inside IG Creator Studio / TikTok Analytics and are only visible to the creator themselves.
- **E1 §4.3 set a hard precondition:** "creator must screenshot IG Insights before payment transfers" — this is trust-based (screenshots can be faked, cropped, or stale) and the evaluator flagged this as n=1 coin-flip risk. We need either (a) a better verification loop or (b) explicit acceptance of the trust-based approach with controls.
- **E3 §2.6 flagged the screenshot-based fit check as "honestly flagged, but this is a gap, not a solution."**
- **Two archetypes required (Synth-final T1b):** tired-mom lane vs. dentist-adjacent lane. Scouting at $120/proxy means we probably pick from a shortlist of ≤5 per archetype, not the top-of-market $500+ creators. This lane is adversely selected — less-vetted creators.
- **Payment + contract mechanism** is also undefined. $120 via PayPal? Stripe? Creator invoice? FTC-disclosure language in the Reel's caption? Not specified.

## What the child loop must produce

1. **Scouting protocol (reproducible):** for each archetype, name the specific discovery path.
   - Option A: Search IG/TikTok for hashtags (`#momlife #toothbrushing #kidsroutines` etc.), manually click through top 50 creators, log follower count + recent-post engagement rate.
   - Option B: Scrape public parenting-newsletter recommendations, dentist-office Instagram partnerships, or lists like "best mom creators 2026."
   - Option C: Referral from Oliver's dentist + PTA network (warm intro, slower but higher trust).
   - Pick a combination; estimate Jim-hours (per §8.9 this must fit in the 60-min window or be agent-time only).
2. **Audience-fit verification ladder:**
   - Tier A (best): creator sends a timestamped screen-recording of IG Insights → agent OCRs + checks against claim.
   - Tier B: creator sends PNG screenshot → agent verifies no obvious tampering (screen-recording beats PNG).
   - Tier C: creator tells us a number, we check against 3rd-party estimators if any exist.
   - Specify the MINIMUM tier we accept before paying. Recommendation is Tier A.
3. **Payment + contract mechanism:**
   - Payment rail (PayPal/Stripe/bank transfer), FTC-disclosure caption language ("#ad" or "#sponsored"), deliverable specification (1 Reel in 14 days, ≥0:30 in length, specific creative-brief compliance), refund/no-refund policy for non-delivery.
4. **Archetype-specific shortlist format:**
   - Archetype 1 (tired-mom-confessional): named handle, follower count, recent-post velocity, audience-fit estimate with method, proposed payment, specific recent post that proves they'd land the meltdown-hook brief.
   - Archetype 2 (dentist-adjacent): same columns. Dental hygienist, pediatric-dental-assistant, "kid-dentist-mom" lanes.
5. **Red-flag kill list** (E2 §2 "NO QVC-kitchen creators" — explicit handles or patterns to reject):
   - QVC-voice (overly performative product-demo tone)
   - Anyone with >3 brand-deal posts in the last 4 weeks (brand-deal fatigue)
   - Anyone under 18 or unclear age
   - Anyone whose audience looks majority non-parent per available signals
   - Anyone whose aesthetic is actively Space-Rangers-adjacent (Synth-final §8.5 bans that opener)
6. **Output format for handoff to PRD-003 (creator brief) + PRD-004 (audience-fit checklist):** what shape does the "creator package" take when handed to the executor PRD? (Candidate shortlist YAML + brief template + contract template.)

## Criteria the child loop will resolve

| Gate criterion | Status now | Resolved by |
|---|---|---|
| 1. Measurable goal with specific metric + window | Partial — Synth-final targets 12–25 installs at $8–20 CAC per proxy; need creator-level sub-targets | Child loop sets per-creator signal thresholds (e.g. ≥2K views at 72h, ≥1% save rate) |
| 2. Context fully specified | No — scouting protocol undefined | Child loop picks a protocol |
| 3. Every input named + located | No — no shortlist exists, no payment rail specified | Child loop produces shortlist YAML + payment decision |
| 4. Acceptance criteria checkable | Partial — screenshot is a step, OCR + tamper-detection is not defined | Child loop defines verification ladder + which tier is acceptance |
| 5. Tools exist OR flagged TO-BUILD | No — no Modash, no Creator MCP | Child loop flags these as TO-BUILD or accepts manual-agent search + frames the reliability cost |
| 6. Escalation triggers | Partial — Synth-final §7 has "CAC >$50 → kill T3k" but no per-creator in-flight trigger | Child loop adds "creator ghosts after payment" trigger |

## Dependencies on other meta-PRDs / PRDs

- **Depends on:** `PRD-GTM-instagram-reels-001` (landing + attribution) — creators' Reel captions link to the UTM'd landing; no attribution = can't measure CAC.
- **Depends on:** `_meta-prd-attribution-schema.md` — `utm_source=ig_creator&utm_content={creator_handle}` shape must be defined.
- **Blocks:** `prds/PRD-GTM-instagram-reels-003.md` (creator brief + creative spec) and `prds/PRD-GTM-instagram-reels-004.md` (audience-fit checklist).
- **Informs:** `_meta-prd-ig-posting-pipeline.md` — if we end up needing to re-post creator Reels from @brushquest, the posting pipeline applies.

## Binding upstream decisions (from Synth-final §8 — DO NOT re-litigate)

- §8.5: creative brief BANS Space Ranger aesthetic from first 3 seconds. Meltdown-confessional hook at 0s, game reveal no earlier than 0:06. Hands-only (no kid face), COPPA-strict. This is baked into the PRD-003 brief; scouting must filter creators who can execute this.
- §8.6: n=2 parallel proxies, not n=1. Budget is $240 ($120 × 2). The $280 scale batch is Tier-3 (T3k), gated on attribution + CAC math.
- §8.9: Jim approves contract + payment in the 60-min window (non-delegable, per §8.15 — "any money-out → Jim approves").
- §8.14: missing a tool = spawn a meta-PRD, not a workaround. Trust-based screenshot MUST be explicitly accepted as the verification floor, not silently.

## Rough size estimate for the child loop

Medium. ~8–12 hrs agent time. Needs L3/L4 research on creator-discovery techniques at this budget tier, L4 pattern-match on successful micro-creator kid-app activations (Moshi, Khan Academy Kids, etc.), probably one round of A/B/C evals on the verification-ladder decision because it's where evaluator E1 pushed back hardest. Worth doing carefully — this is where $240 of real money goes.

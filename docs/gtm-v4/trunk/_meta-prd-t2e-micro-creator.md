# Meta-PRD — T2-E: Micro-creator gifting (parent + dental-pro, YouTube Kids + Instagram Reels)

**Loop kind:** Tier-2 experiment child loop (partnerships branch)
**Parent node:** `trunk`
**Parent synth:** `trunk/_synth-final.md` §4 T2-E + §8 #24 (YouTube Kids / dental-pro creators specifically)
**Tier:** 2
**Created:** 2026-04-21
**Status:** charter — child loop not yet launched

---

## Child loop question (crisp)

**Does gifting Brush Quest+ premium codes + a small creative prompt kit to 15–20 nano creators (<10K followers, skewing parent or dental-pro) with hero-proxy creative only, produce ≥2 posts and ≥10K combined views in 30 days on ≤$100 — and is dental-pro (hygienist on IG Reels, pediatric dentist on YT) specifically the higher-yield tier vs. generic parent creator, the way E2 §2 implied?**

---

## Why this needs a child loop (not a direct PRD)

- **Creator list doesn't exist.** Dental-pro creator scene on Instagram and TikTok/YT is real and identifiable but requires research. Nano-parent creators need separate list.
- **Gift "kit" is undesigned.** What's in it — a code? a physical postcard? a kit? a creative brief? undetermined.
- **Creative prompts must be COPPA-safe.** Hero-proxy only; no ask for child face. Creators may not comply unless prompt is explicit.
- **Attribution mechanism requires decision.** Unique code per creator vs. unique UTM vs. both.
- **Legal/disclosure rules.** FTC requires disclosure for any gift creating posting obligation; kit must include disclosure guidance.

5 of 6 gate criteria unresolved.

---

## What the child loop must produce

### Leaf PRDs expected (4)

1. **PRD-GTM-t2e-creator-shortlist-001** — 30-candidate list, two tiers:
   (A) **Parent-nano** (<10K followers, parent of 4–8yo kid, posts
   daily-life content), target 15 candidates.
   (B) **Dental-pro** (hygienists + pediatric dentists on IG Reels / YT
   Shorts), target 15 candidates.
   Scoring: follower count, post frequency, audience
   parent/dental-parent skew, prior receptiveness to indie kids-app,
   contact availability. Output: `trunk/_data/t2e_creator_shortlist.yaml`.

2. **PRD-GTM-t2e-gift-kit-design-001** — the gift itself. Scope:
   - Unique Brush Quest+ premium code per creator
   - Physical postcard with hero-proxy art (no child face)
   - Creative prompt card (3 suggestions: "show your kid's reaction
     without their face in frame," "voice-over your family review,"
     "show the quadrant mouth guide — parent POV")
   - FTC-disclosure language printed on card
   - Premium shipping envelope ($2 each). Budget: $100 total kit +
     postage for 20.

3. **PRD-GTM-t2e-outreach-001** — DM + email outreach to all 30 creators;
   offer kit if they agree to receive one (no post obligation). Track
   response rate. `utm_source=creator_{tier}_{slug}` (`tier` = parent
   or dental).

4. **PRD-GTM-t2e-measure-001** — 30-day measurement window. Scope: track
   posts per creator, views, UTM-attributed visits, code-redemption on
   premium codes (second attribution layer — unique codes are
   strongest). Compare parent-nano vs dental-pro tiers.

### Design artifacts (non-PRD)

- Postcard print file
- Creative prompt card copy
- FTC disclosure snippet
- Gift unboxing moment — make it presentation-worthy

### Data artifacts

- `trunk/_data/t2e_creator_shortlist.yaml`
- `trunk/_data/t2e_outreach_log.yaml`
- `trunk/_data/t2e_post_attribution.yaml`
- `trunk/prds/_t2e_postmortem.md`

---

## Missing gate criteria (of the 6)

| Gate | Status at trunk | Resolved by |
|---|---|---|
| 1. Measurable goal + metric + window | Named (<2 posts in 30d or <500 views = kill; ≥5 posts + 10K views = promote) | Trunk |
| 2. Context brief complete | Partial | Leaf 1 |
| 3. Inputs enumerable | **Missing** — creator list, kit design | Leaves 1, 2 |
| 4. Outputs concrete | **Missing** — kit, postcard, prompt card | Leaf 2 |
| 5. Acceptance criteria binary | Present | Trunk |
| 6. No blocking dependencies | **Pillar 1 attribution** + **premium code generation** (needs Brush Quest+ code system live or placeholder) | Pillar 1 Week 1; premium codes TBD |

---

## Dependencies on other trunk-level PRDs / meta-PRDs

- **Hard dependency:** `PRD-GTM-trunk-instrumentation-aso-001.md` — UTM
  attribution for creator clicks.
- **Hard dependency:** Brush Quest+ premium code generation system.
  Currently, BQ+ is shipped as $9.99 one-time via store IAP; free-code
  issuance mechanism may need design (promo codes on Play Console can
  issue 500 free codes per quarter — this is the path).
- **Cross-feed:** dental-pro creators may overlap with Pillar 2
  practice-list; cross-link.

## Budget + agent shape (inherited from trunk)

- Budget: $100 (print/ship + minor creative).
- Agent: `experiment-runner` generalist.
- Jim hours: ~2 total (approve kit design + approve creator list).
- Escalation: `tg send` on any FTC/COPPA flag, kill/promote triggers,
  >$100 spend.

## Binding inheritance from `_synth-final.md` (do NOT re-litigate)

- Hero-proxy only; no child face in prompted creative (§8 #10,
  CLAUDE.md).
- Nano creators (<10K), not mid/top (§4 T2-E — "ToS-compliant,
  cost-efficient").
- Dental-pro creators specifically named as higher-yield tier to test
  (§4 T2-E + E2 §2).
- `utm_source=creator_{tier}_{slug}` (§8 #15).
- `brushquest.app/rangers` bridge (§8 #14).
- Zero CPI (§8 #6); production-priced only.

## Child loop sequencing (recommended)

1. **Week 2:** leaves 1 (shortlist) + 2 (kit design) in parallel.
2. **Week 3:** leaf 3 (outreach) launches.
3. **Week 3–4:** kits mail out to accepting creators.
4. **Week 4–7:** 30-day measurement window.
5. **Week 8:** postmortem + gate decision; compare parent-nano vs
   dental-pro tier.

## Charter termination criteria

- Posts observed per tier.
- Views per tier.
- UTM installs per tier.
- Code redemptions per tier.
- Which tier was higher-yield? Does this confirm/deny E2 §2 dental-pro
  hypothesis?
- Promote / kill decision + reasoning.

---

**END META-PRD.** Charter frozen.

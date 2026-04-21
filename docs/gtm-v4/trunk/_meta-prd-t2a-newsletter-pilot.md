# Meta-PRD — T2-A: Newsletter sponsorship pilot ($100 single-send)

**Loop kind:** Tier-2 experiment child loop (short — ≤1 week design + 2 weeks run)
**Parent node:** `trunk`
**Parent synth:** `trunk/_synth-final.md` §4 T2-A + §8 #8 (pilot-gated spend)
**Tier:** 2
**Created:** 2026-04-21
**Status:** charter — child loop not yet launched

---

## Child loop question (crisp)

**Given that Beehiiv inventory for parenting newsletters is thin and books 60–90 days out, and that parenting-newsletter CPM/sponsorship economics at our $1–2 LTV are unproven — which single $100 sponsorship placement tests install conversion ≥ 2% most fairly (warm-voice mom-forward newsletter vs. mid-tier curated parenting list vs. niche brushing/oral-health adjacent), and what is the operational runbook (slot-booking → copy delivery → UTM → measurement) that makes a follow-on $300 commit (or kill) decidable by Day 21?**

---

## Why this needs a child loop (not a direct PRD)

- **Newsletter inventory is not enumerated.** Which specific newsletter? (Lucie's List is aspirational; Big Little Feelings has a paywalled list; small mom-newsletters are abundant but quality varies.)
- **Sponsorship format is not specified.** Display ad? Native mention? Founder-note style? Each converts differently.
- **Copy does not exist.** Must match newsletter voice (synth-final §8 #18: nightly-fight parent feel).
- **Measurement window + gate need to be sub-criteria.** "Install conv ≥ 2%" must specify over what visit count and over what attribution window.
- **Legal/COPPA exposure on a sponsor's list** (if they collect minors' data) needs a quick check.

4 of 6 gate criteria unresolved.

---

## What the child loop must produce

### Leaf PRDs expected (3)

1. **PRD-GTM-t2a-newsletter-shortlist-001** — shortlist 6 candidate
   newsletters. Scope: mom-forward, parenting-of-4–8yo, ≥5K subscribers,
   open rate ≥ 30% (self-reported), willing to take ≤$100 sponsorship.
   Short: Lucie's List (stretch), Big Little Feelings, Mother Untitled,
   Cup of Jo ReadMore section, Romper newsletter, Lifehacker Parenting
   newsletter. Deliverable: `trunk/_data/t2a_newsletter_shortlist.yaml`
   with `name`, `subscribers`, `open_rate`, `sponsor_contact_email`,
   `rate_card_100_slot_available`, `lead_time_days`.

2. **PRD-GTM-t2a-sponsorship-book-001** — book one $100 slot.
   Scope: contact 6 sponsor managers, negotiate single-send at ≤$100 (or
   closest — max stretch $125 with Jim approval), lock slot date,
   deliver copy + asset, verify UTM on send. Escalation: `tg send` on any
   spend > $100, any slot > $125, any content guideline conflict.

3. **PRD-GTM-t2a-pilot-run-measure-001** — ship + measure. Scope: send
   date to send+7d attribution window. Measure visit count via
   `utm_source=newsletter_{slug}_{sendid}`, install conv rate via
   Pillar 1 join event. Deliverables: `trunk/_data/t2a_pilot_result.yaml`
   + `trunk/prds/_t2a_postmortem.md`. Gate decision written: commit
   $300 follow-on (install conv ≥ 2%), cap at $300 (1–2%), or kill
   entirely (<1%).

### Design artifacts (non-PRD)

- **Sponsorship copy** — 3 variants tuned to newsletter voice (warm,
  first-name, not corporate).
- **Hero-proxy image** — 1 newsletter-format image; COPPA-safe.
- **Landing flow** — sponsor link → `brushquest.app/rangers?utm_source=newsletter_{slug}_{sendid}` → email capture → Play/iOS CTA.

### Data artifacts

- `trunk/_data/t2a_newsletter_shortlist.yaml`
- `trunk/_data/t2a_pilot_result.yaml`
- `trunk/prds/_t2a_postmortem.md`

---

## Missing gate criteria (of the 6)

| Gate | Status at trunk | Resolved by |
|---|---|---|
| 1. Measurable goal + metric + window | Named (install conv ≥ 2% on single-send; $100 cap) | Trunk (inherited) |
| 2. Context brief complete | Partial — copy + sponsor voice TBD | Leaf PRD 2 |
| 3. Inputs required enumerable | **Missing** — specific newsletter + rate card + contact TBD | Leaf PRD 1 |
| 4. Outputs concrete | **Missing** — copy, image, landing-flow TBD | Leaf PRD 2 |
| 5. Acceptance criteria binary & verifiable | Present (kill/cap/commit thresholds are numbers) | Trunk |
| 6. No blocking dependencies | **Blocked on Pillar 1 attribution live** for measurement | Pillar 1 ships Week 1 |

---

## Dependencies on other trunk-level PRDs / meta-PRDs

- **Hard dependency:** `PRD-GTM-trunk-instrumentation-aso-001.md` (Pillar 1)
  must ship UTM + cohort dashboard before send-date. No attribution = no
  gate decision.
- **Soft dependency:** `_meta-prd-pillar-3a-earned-media.md` outlet research
  may surface a newsletter candidate; cross-link.

## Budget + agent shape (inherited from trunk)

- Budget: $100 pilot + conditional $300 follow-on (only if install conv
  ≥ 2%).
- Agent: `newsletter-sponsor-agent` (synth-final §8 #29).
- Jim hours: minimal — 1–2 total (approve sponsor pick + approve copy).
- Escalation: `tg send` on >$100 spend, >$125 ceiling, or copy reject.

## Binding inheritance from `_synth-final.md` (do NOT re-litigate)

- $100 pilot BEFORE $300 follow-on (§8 #8). Not negotiable.
- Target max 2 placements in 90 days (§2 #14). Do not over-stretch.
- Nightly-fight parent feel in copy (§8 #18).
- COPPA — no child PII / face.
- `utm_source=newsletter_{slug}_{sendid}` (§8 #15).
- `brushquest.app/rangers` bridge page (§8 #14).

## Child loop sequencing (recommended)

1. **Week 2:** leaves 1 (shortlist) + 2 (book) in sequence (book depends on shortlist).
2. **Week 3–4:** leaf 3 (pilot-run-measure) — send occurs when sponsor slot opens (may slip into Week 4 depending on inventory).
3. **Week 5:** postmortem + gate decision written; `tg send` to Jim.
4. **Child loop completes** at gate decision.

## Charter termination criteria

- Which newsletter was picked and why?
- What install conv was observed?
- Commit / cap / kill decision + reasoning.
- If promote, what's the T2-A v2 charter (repeat? scale?)?
- Does any finding invalidate trunk §8 #25 ("Substack at-scale is NOT the reach mechanism")? If so, raise as trunk amendment.

---

**END META-PRD.** Charter frozen.

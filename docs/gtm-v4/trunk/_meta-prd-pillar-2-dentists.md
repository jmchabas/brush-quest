# Meta-PRD — Pillar 2: Pediatric-dentist partnerships (hygienist verbal handoff)

**Loop kind:** pillar-level child loop
**Parent node:** `trunk`
**Parent synth:** `trunk/_synth-final.md` §3 Pillar 2 + §8 #17 (binding)
**Tier:** 1
**Created:** 2026-04-21
**Status:** charter — child loop not yet launched

---

## Child loop question (crisp)

**Given that "hygienist verbally mentions the app when handing a card to a parent" is the Pillar 2 acceptance criterion — not "flyer on a wall" — what is the minimum-viable practice-partnership unit (1 dentist + 1 hygienist + script + kit), and how do we build a repeatable outreach + activation + measurement system that signs 3–5 practices with active hygienist handoff by Day 45 on a $450 budget, without a CRM MCP until practice count crosses ~30?**

---

## Why this needs a child loop (not a direct PRD)

At least 3 of the 6 PRD-executable gate criteria are unresolved at trunk:

1. **Inputs not yet enumerable.** Target practice list does not exist. Scoring rubric (distance from Jim, pediatric-specialty flag, practice size, parent-age demographic) is undefined. Without the list, outreach templates cannot be concretely personalized.
2. **Outputs not yet concrete.** The hygienist verbal handoff "script + laminated card" is a designed artifact that does not exist. Canva flyer / kit design with CSM badge slot does not exist. Device-stitch QR → email → install attribution wiring is unspecified at wire level (the primitive ships in Pillar 1; the practice-side instrument does not).
3. **Acceptance criteria need sub-criteria.** "Hygienist verbal handoff committed per practice" requires a verification mechanism (follow-up call? written confirmation? photo of card in use?). Not yet defined.
4. **Dependencies branch.** A CRM MCP decision (Attio vs Pipedrive vs Gmail-labels-only) depends on practice-scale threshold — this is its own design question.
5. **Sequencing.** The child loop must resolve whether practice-outreach and kit-design run in parallel, or kit-design gates outreach (because outreach without a kit to promise is wasted).

The trunk-level direct bet is recognizing the pillar and freezing the binding constraints. The leaf PRDs must come from one level down.

---

## What the child loop must produce

### Leaf PRDs expected (5–6)

1. **PRD-GTM-pillar-2-practice-list-001** — agent-driven practice list builder.
   Scope: 100–150 pediatric dental practices scored + ranked; Gmail labels
   workflow until ~30 practices, then CRM MCP kicks in (see sub-PRD #5).
   Inputs: Google Maps / Yelp / state dental-board directories. Outputs:
   `trunk/_data/dental_practices.yaml`, scoring rubric, Jim approval of
   top-20 outreach batch.

2. **PRD-GTM-pillar-2-outreach-machine-001** — Gmail-based cold outreach
   with personalization. Scope: 2–3 email variants, 1 follow-up, 1 phone
   "warm" prompt if ≥3 replies stall at email. Jim-gated on any phone
   close. `utm_source=dentist_practice_{slug}_{city}` on every embedded
   link. Escalation: `tg send` on any reply requiring phone.

3. **PRD-GTM-pillar-2-kit-design-001** — Canva flyer + laminated hygienist
   handoff card + QR sticker. Scope: CSM badge slot (even if placeholder
   pre-approval), kid-visible hero imagery, "parents: brushing turns into
   a 2-min quest — your hygienist suggested it" one-liner, bilingual
   EN/ES if practice serves Spanish-primary families. Outputs: print-ready
   PDF, 1 courier drop + 1 postage batch.

4. **PRD-GTM-pillar-2-hygienist-handoff-script-001** — the verbal script
   itself. 30–45 sec delivery. Scope: what the hygienist actually says when
   handing the card; how a practice "commits" (written confirmation via
   portal form OR reply-to-email OR phone confirm). Includes a "retrain"
   follow-up at Day 14 post-shipment. **This PRD is the Pillar 2 centerpiece
   — without it, the pillar's acceptance criterion is unmet.**

5. **PRD-GTM-pillar-2-device-stitch-attribution-001** — QR scan → email
   capture → Firebase Auth sign-in match. Consumes Pillar 1 primitive.
   Scope: Buttondown-side `utm_source=dentist_practice_{slug}` flows
   through to `install_attributed` event. Tests end-to-end with fake
   practice slug `dentist_practice_test_sf` before first kit ships.

6. **PRD-GTM-pillar-2-crm-mcp-decision-001** — decision PRD (not work
   PRD). Fires only when practice count crosses 30 OR Gmail-labels fails
   a search. Scope: evaluate Attio MCP vs Pipedrive MCP vs Folk MCP vs
   continuing Gmail-labels. Picks one, wires it up, migrates labels to
   CRM state.

### Design artifacts (non-PRD)

- **Hygienist verbal script** — recorded video of Jim reading it, shared
  with practice as part of onboarding kit.
- **Kit-design spec** — measurements, paper stock, card quantity per
  practice (start at 25 cards/practice = ~$1–2 print cost).
- **Commitment-confirmation mechanism** — choose one of: (a) portal form,
  (b) reply-to-email checkbox, (c) phone confirm. Default: reply-to-email.

### Data artifacts

- `trunk/_data/dental_practices.yaml` — master list + status.
- `trunk/_data/pillar_2_kit_shipments.yaml` — which practice got which
  kit, when, and did a hygienist confirm.
- `trunk/_data/pillar_2_attribution_events.yaml` — dedupe + rollup of
  install events with a `dentist_*` utm_source.

---

## Missing gate criteria (of the 6)

| Gate | Status at trunk | Resolved by |
|---|---|---|
| 1. Measurable goal + metric + window | Named (120–250 WAK by Day 90; Day-45 kill gate at <2 practices signed) | Trunk (inherited by leaves) |
| 2. Context brief complete | Mostly (product, constraints, decisions) — practice-list + kit design not yet defined | Leaf PRDs 1, 3, 4 |
| 3. Inputs required enumerable | **Missing** — practice list, kit design, handoff script all TBD | Leaf PRDs 1, 3, 4 |
| 4. Outputs concrete | **Missing** — kit design, script, commitment mechanism TBD | Leaf PRDs 3, 4 |
| 5. Acceptance criteria binary & verifiable | **Missing** — "hygienist verbally committed" needs a verification mechanism | Leaf PRD 4 |
| 6. No blocking dependencies | **Partial** — depends on Pillar 1 attribution primitive (named); depends on CRM-MCP decision at scale (deferred to leaf 6) | Resolved as Pillar 1 ships + leaf 6 fires on threshold |

---

## Dependencies on other trunk-level PRDs / meta-PRDs

- **Hard dependency:** `PRD-GTM-trunk-instrumentation-aso-001.md` (Pillar 1)
  must ship Install Referrer attribution primitive + `/rangers` bridge
  before any kit-bearing QR code is mailed. A QR without attribution is
  a flyer — which violates the Pillar 2 acceptance criterion.
- **Soft dependency:** `_meta-prd-pillar-3a-earned-media.md` (CSM badge
  workflow). If CSM approves before kits ship, kits carry a real badge;
  otherwise kits use the placeholder slot and get re-issued post-approval.
- **Soft dependency:** `_meta-prd-t2b-text-chain.md`. Mom-text-chain
  seeders may overlap with practice-parents (a parent who found Brush Quest
  via dentist may be a natural seeder). Leaves should cross-link but not
  block.

## Budget + agent shape (inherited from trunk)

- Budget: $450 (print + postage + 1–2 courier drops).
- Agent: `dentist-outreach-agent` (synth-final §8 #29). One agent, not six.
- Jim hours: ~6/wk (phone/in-person close is binding — E2 §2, E3 §1).
- Kill gate: Day 45 with <2 practices signed → cut 50% of remaining budget,
  redirect to Pillar 3a or T2-B (synth-final §7).

## Binding inheritance from `_synth-final.md` (do NOT re-litigate)

- Hygienist VERBAL handoff — not flyer placement — is the acceptance
  criterion (§8 #17).
- Device-stitch is required; flyer-only placements do not count toward
  WAK projection (§8 #16).
- CRM MCP named as blocking sub-PRD at >30 practices (§8 #26).
- Every pitch carries unique `utm_source` (§8 #15).
- COPPA strict; hero-proxy imagery; no child faces in kit (§8 #10,
  CLAUDE.md rules).

## Child loop sequencing (recommended)

1. **Week 2 kickoff:** launch leaves 1 (practice list) and 3 (kit design)
   in parallel — they're independent.
2. **Week 2 mid:** leaf 4 (hygienist script) drafted; Jim records video.
3. **Week 2 end:** leaf 5 (device-stitch attribution) wired + tested with
   fake practice slug.
4. **Week 3:** leaf 2 (outreach machine) launches first 20 emails. Leaf 6
   (CRM decision) paused until threshold.
5. **Week 4–6:** kits mail to first-yes practices. Day-45 gate fires.
6. **Child loop completes** when ≥3 practices have confirmed hygienist
   handoff AND attribution pipeline has shown ≥1 install from a
   `dentist_practice_*` utm_source (or kill gate fires at Day 45).

## Charter termination criteria

Child loop's own synth-final must answer:

- Which practice-type scored highest on first 3 signed? (pattern for
  scale)
- What reply-rate does the outreach email template achieve?
- Which commitment-confirmation mechanism actually correlated with
  installs (reply-checkbox vs portal vs phone)?
- At what practice count did Gmail-labels fail and CRM MCP become
  necessary?
- Should Day-90 WAK projection (120–250) be updated up or down?

---

**END META-PRD.** Charter frozen; child loop inherits trunk `_synth-final.md` and this file as context. Sub-PRDs live at `trunk/pillar-2-dentists/prds/`.

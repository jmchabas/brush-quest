# Meta-PRD — Pillar 3a: Earned media + Common Sense Media (badge + pitches)

**Loop kind:** pillar-level child loop
**Parent node:** `trunk`
**Parent synth:** `trunk/_synth-final.md` §3 Pillar 3 + §8 #21 (CSM badge binding)
**Tier:** 1
**Created:** 2026-04-21
**Status:** charter — child loop not yet launched

---

## Child loop question (crisp)

**Which 10 mid-tier parenting outlets are both (a) realistically reachable by a zero-relationship agent in a 45-day pitch window and (b) likely to convert reader → install at ≥12% — and what pitch hook (nightly-fight parent empathy vs. CSM-approved badge vs. Oliver testimonial vs. solo-founder-for-tech-press) actually pulls a reply? And: how do we get the Common Sense Media submission + badge live on the Play Store listing screenshot inside the same 45 days so it appears at install-decision moment?**

---

## Why this needs a child loop (not a direct PRD)

Pillar 3a bundles two linked but distinct sub-bets:

- **3a.1 — earned media pitches:** outlet list + pitch-hook test. Requires
  research (which outlets, which writers, what hooks), templating, and a
  measurement loop for reply-rate by hook.
- **3a.2 — CSM submission + badge integration:** submission packet + badge
  renderer + Play listing screenshot swap.

Both are agent-runnable but neither is specified enough for a single direct PRD today. At least 4 of the 6 gate criteria are unresolved:

1. **Inputs not yet enumerable.** Outlet list does not exist. Writer-beat mapping (who covers kids-apps? who covers dental health? who covers "indie-dev parent tools"?) is undone.
2. **Outputs not concrete.** Press kit imagery, COPPA-safe hero-proxy renders, CSM submission packet, badge-rendering workflow on Play screenshot — all TBD.
3. **Acceptance criteria need sub-criteria.** "CSM badge on store-listing screenshot" requires: (a) CSM approval received, (b) badge image/logo licensed or rendered, (c) screenshot updated and re-uploaded to Play Console. Each is verifiable; none is specified yet.
4. **Hook-testing is an embedded experiment.** The child loop IS an A/B over hooks — that's why it's a loop, not a single PRD.

Trunk-level direct PRDs would be premature.

---

## What the child loop must produce

### Leaf PRDs expected (5)

1. **PRD-GTM-pillar-3a-outlet-research-001** — outlet + writer list builder.
   Scope: 20 candidate outlets (Romper, Fatherly, Lifehacker Parenting,
   Lucie's List, Cup of Jo, Today's Parent, Motherly, Scary Mommy, Big
   Little Feelings, Moms.com, Common Sense Media editorial, etc.); writer
   beat tags; most-recent bylines to confirm active. Outputs:
   `trunk/_data/pillar_3a_outlets.yaml` with `name`, `writer`, `beat`,
   `recent_article_url`, `pitch_ranking`.

2. **PRD-GTM-pillar-3a-pitch-experiment-001** — A/B pitch-hook
   experiment. Scope: 4 hook variants pitched across 12+ outlets:
   (H1) nightly-fight parent empathy, (H2) CSM-approved badge + data,
   (H3) Oliver-testimonial (COPPA: Jim narrates, no kid voice / face),
   (H4) solo-founder-AI-agents tech-press angle (ONLY to tech outlets;
   synth-final §8 #19). Unique `utm_source=press_{outlet}_{writer}` per
   pitch (§8 #15). Primary: reply rate by hook. Secondary: publish rate,
   install-attributable on publish.

3. **PRD-GTM-pillar-3a-press-kit-001** — COPPA-safe press kit.
   Scope: 6 hero-proxy images (no child faces), 3 gameplay GIFs, 1
   30-sec parent-voiced demo video, fact sheet, founder headshot, brand
   colors, quote library. Asset delivery at
   `brushquest.app/press` (behind optional email capture — agent
   decides; if gated, UTM must still pass).

4. **PRD-GTM-pillar-3a-csm-submission-001** — CSM submission + badge
   integration. Scope: complete Common Sense Media app submission form,
   upload required assets, track submission, write CSM-approved-badge
   rendering into a Play Store screenshot (placeholder slot already
   shipping in PRD-01). **This is the single-most-important downstream
   artifact per E2 §5 — badge at install-decision moment.**

5. **PRD-GTM-pillar-3a-public-stats-page-001** — public metrics page at
   `brushquest.app/stats`. Scope: live D1/D7/D30 retention numbers
   (from Pillar 1 dashboard), total brushes aggregate, parent-testimonial
   quotes. Doubles as press hook ("indie dev ships public retention
   data") and CSM trust proof. Data source is the PostHog/Amplitude
   dashboard (Pillar 1 primitive).

### Design artifacts (non-PRD)

- **Pitch copy library** — 4 hooks × 2 lengths (40-word DM variant +
  ~250-word email variant) × personalization slots.
- **Press-kit visual system** — COPPA-safe hero-proxy composition rules.
- **Stats page design** — lightweight, shareable, screenshottable.

### Data artifacts

- `trunk/_data/pillar_3a_outlets.yaml` — outlet + writer list.
- `trunk/_data/pillar_3a_pitch_log.yaml` — send log + reply state.
- `trunk/_data/pillar_3a_csm_submission.yaml` — submission state,
  approval date, badge-live date on store listing.

---

## Missing gate criteria (of the 6)

| Gate | Status at trunk | Resolved by |
|---|---|---|
| 1. Measurable goal + metric + window | Named (50–150 WAK by Day 90; first pickup in 30–45 days; CSM badge live by Day 45) | Trunk (inherited) |
| 2. Context brief complete | Mostly — outlet-beat map TBD | Leaf PRD 1 |
| 3. Inputs required enumerable | **Missing** — outlet list, writer list, press-kit assets all TBD | Leaves 1, 3 |
| 4. Outputs concrete | **Missing** — press kit, badge-on-screenshot, stats page all TBD | Leaves 3, 4, 5 |
| 5. Acceptance criteria binary & verifiable | **Partial** — "first pickup" is binary; "CSM approved + badge live on Play" is 3-step gated | Leaf PRD 4 |
| 6. No blocking dependencies | **Blocked on Pillar 1 stats** for leaf 5; **CSM approval unforecastable** but submission is agent-executable | Leaves 4, 5 |

---

## Dependencies on other trunk-level PRDs / meta-PRDs

- **Hard dependency (stats page):** `PRD-GTM-trunk-instrumentation-aso-001.md`
  (Pillar 1) must ship retention dashboard before `brushquest.app/stats`
  can render real numbers. Stats page is a Pillar 1 consumer.
- **Soft dependency:** `_meta-prd-pillar-2-dentists.md` kit-design leaf
  reserves a CSM-badge slot. Once Pillar 3a's leaf 4 lands the badge,
  dentist kits update to carry it.
- **Cross-feed:** press outlet learnings may identify a parenting-newsletter
  outlet that belongs in T2-A pilot list — cross-reference when that
  child loop is designed.
- **Tier-3 future link:** if Pillar 3a generates a Play BD intro, the
  Editor's Choice Tier-3 trigger (synth-final §5) may fire — route to
  that promotion path.

## Budget + agent shape (inherited from trunk)

- Budget: $100 (press-kit production + CSM-adjacent).
- Agent: `press-pitcher-agent` (synth-final §8 #29).
- Jim hours: ~4–6/wk in burst weeks (journalist 48h windows — E3 §1).
- Sub-agent: no separate CSM-submission agent; `press-pitcher-agent`
  owns both 3a.1 and 3a.2.

## Binding inheritance from `_synth-final.md` (do NOT re-litigate)

- Editor's Choice is **Tier-3, not Tier-1** (§5; §8 #22).
- CSM badge MUST appear on Play store-listing screenshot, not just
  "submitted to CSM" (§8 #21).
- Every pitch carries unique `utm_source=press_{outlet}_{writer}`
  (§8 #15).
- Lead pitches with **nightly-fight parent feel**, not product features
  or solo-founder-AI angle (§8 #18, #19).
- Solo-founder-AI angle is tech-press-only; not primary for parenting
  outlets (§8 #19).
- Face of brand is NOT Jim. Kit uses hero-proxy + no child face
  (§8 #20, CLAUDE.md).
- CSM submission counts as a trust asset, NOT as WAK-volume contribution
  (§3 Pillar 3 note; promote to WAK route only at ≥50 attributable
  installs in 60 days — §10).

## Child loop sequencing (recommended)

1. **Week 2 kickoff:** leaf 1 (outlet list) + leaf 3 (press kit build) +
   leaf 4 (CSM submission — starts immediately; approval timeline
   unforecastable so start on Day 1).
2. **Week 2 mid:** leaf 5 (stats page) gated on Pillar 1 dashboard
   being live; builds in parallel once unblocked.
3. **Week 3:** leaf 2 (pitch experiment) launches first 12 pitches
   across 4 hooks.
4. **Week 4–6:** reply + publish tracking; first pickup expected Day
   30–45. Hook winner declared at Day 30 (or NO_WINNER).
5. **Week 6+:** if CSM approves, badge renders onto Play screenshot;
   Play listing re-uploads; `tg send` to Jim.
6. **Child loop completes** when EITHER: (a) ≥2 press pickups with
   attributable installs, OR (b) CSM badge live on Play, OR (c) Day 60
   arrives with neither — hook winner declared, synth-final written.

## Charter termination criteria

Child loop's own synth-final must answer:

- Which of the 4 hooks had highest reply rate? Highest publish rate?
- Which outlet tier (A/B/C) converted at what install rate?
- Did CSM approval arrive inside 45 days? What were the blockers?
- Should Day-90 WAK projection (50–150) update based on first-pickup
  install-throughput?
- Does Editor's Choice Tier-3 trigger fire based on any BD intro
  received?

---

**END META-PRD.** Charter frozen; child loop inherits trunk `_synth-final.md` and this file as context. Sub-PRDs live at `trunk/pillar-3a-earned-media/prds/`.

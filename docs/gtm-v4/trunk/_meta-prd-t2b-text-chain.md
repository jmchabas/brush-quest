# Meta-PRD — T2-B: Mom-text-chain seed program

**Loop kind:** Tier-2 experiment child loop (community branch — warm-network design)
**Parent node:** `trunk`
**Parent synth:** `trunk/_synth-final.md` §4 T2-B + §8 #25 ("warm-network + mom-text-chains are" the real reach mechanism)
**Tier:** 2
**Created:** 2026-04-21
**Status:** charter — child loop not yet launched

---

## Child loop question (crisp)

**E2 called mom-text-chain "the only route that matters — after it actually works twice" — so: how do we identify 15–20 real parents of 4–8yo (not Facebook mom-group performers, not Reddit-audience, not acquaintances-of-acquaintances), get them and their kid using Brush Quest for ≥2 real brushing sessions, and then design a prompt / ask / incentive that gets them to text ONE specific friend naturally — without coming off as MLM, without violating COPPA in the share artifact, and with attribution strong enough that a friend-install is measurable?**

---

## Why this needs a child loop (not a direct PRD)

- **Seeder identification requires Jim's warm network.** Agent can list criteria but cannot cold-identify real parents of 4–8yo in 3 cities. This is a human discovery step that must happen before any artifact design.
- **The "ask" is the whole experiment.** "After your kid brushes twice, text one friend" is a designed prompt — wording, timing, channel (in-app? email? Jim text?), incentive (perk?), COPPA-safe share artifact (what does the forwarded text actually contain?). All TBD.
- **COPPA risk is sharp.** A parent sharing an app "your kid would love" is fine; a parent being prompted to share a screenshot with their kid's face visible is not. Share artifact must be designed COPPA-first.
- **Attribution mechanism is non-trivial.** `utm_source=friend_{seeder_slug}` works if the seeder shares a specific link — but the specific link must be auto-generated per seeder, and friends on iPhone may strip UTM when pasting into iMessage. Fallback: in-app "how did you hear" single-question survey.
- **Promote criteria specified at trunk (≥10 friend-installs = T1 child loop) but need sub-criteria** on what "friend-install" even means (link click? attributed install? organic "yeah my friend told me"?).

4 of 6 gate criteria unresolved.

---

## What the child loop must produce

### Leaf PRDs expected (4)

1. **PRD-GTM-t2b-seeder-recruitment-001** — Jim-led seeder recruitment.
   Scope: Jim identifies 15–20 warm-network parents of 4–8yo across 3
   cities (SF Bay, LA, NY — or Jim picks); screens for: (a) kid in target
   age, (b) not previously-heard-of-app, (c) willing to answer 3 questions
   at Day 14. Agent prepares Jim with outreach text + screener questions.
   Jim does outreach himself (this step is NOT agent-runnable; warm
   network is Jim's).

2. **PRD-GTM-t2b-seeder-onboarding-001** — seeder onboarding kit.
   Scope: 1-page welcome letter, install link
   (`utm_source=seeder_{slug}_onboard`), 1 small perk (e.g. early-access to
   a not-yet-shipped hero, or thank-you card). Tracks `seeder_active`
   status: did their kid brush ≥2x in the first 14 days? Via Pillar 1
   events.

3. **PRD-GTM-t2b-share-prompt-design-001** — the forwarded-text artifact
   and the ask. Scope: after Day-14 if `seeder_active` = true, prompt via
   Jim text (NOT in-app — seeders must feel this is founder-to-friend,
   not app-asking) that says "hey, if you had to recommend one friend
   whose kid is 4–8, would you text them this? <pasteable text with
   seeder-specific UTM link>". Pre-composed text is COPPA-safe (hero
   character only, no kid mentions). A/B two prompt styles.

4. **PRD-GTM-t2b-attribution-survey-001** — backup attribution layer.
   Scope: in-app single-question on first launch after Pillar 1 ships:
   "How did you hear about Brush Quest?" with options: A friend / A
   dentist / Press / Social / Other. Adds belt-and-suspenders to UTM
   (iMessage strips UTM for some users).

### Design artifacts (non-PRD)

- **Seeder screener questions** (for Jim to use)
- **Forwarded-text copy** (COPPA-safe, 2 variants)
- **Seeder perk mailer** (physical, $3–5/unit)

### Data artifacts

- `trunk/_data/t2b_seeders.yaml` (seeder list + state)
- `trunk/_data/t2b_friend_installs.yaml` (attributed installs by seeder)
- `trunk/prds/_t2b_postmortem.md`

---

## Missing gate criteria (of the 6)

| Gate | Status at trunk | Resolved by |
|---|---|---|
| 1. Measurable goal + metric + window | Named (<3 seeders activate in 30d OR <5 friend-installs in 45d = kill; ≥10 friend-installs = promote) | Trunk |
| 2. Context brief complete | Partial — seeders TBD | Leaf PRD 1 |
| 3. Inputs required enumerable | **Missing** — seeder list does not exist; Jim must recruit | Leaf PRD 1 (Jim-driven) |
| 4. Outputs concrete | **Missing** — share-prompt copy, perk, artifact TBD | Leaves 2, 3 |
| 5. Acceptance criteria binary & verifiable | Thresholds named; attribution mechanism ambiguous | Leaf PRD 4 |
| 6. No blocking dependencies | **Blocked on Pillar 1 attribution** + on Jim-time for recruitment | Pillar 1 ships Week 1; recruitment Week 2 |

---

## Dependencies on other trunk-level PRDs / meta-PRDs

- **Hard dependency:** `PRD-GTM-trunk-instrumentation-aso-001.md` (Pillar 1)
  must ship UTM + `install_attributed` event + `brush_completed` event
  so `seeder_active` is measurable.
- **Hard dependency:** Jim-time for warm-network recruitment. Agent cannot
  substitute. If Jim capacity is <2 hr/wk, experiment slips.
- **Cross-feed:** `_meta-prd-pillar-2-dentists.md` — practice-parent
  populations may overlap with seeder candidates; cross-link if a
  dentist-parent becomes a seeder.

## Budget + agent shape (inherited from trunk)

- Budget: $50 (seeder perks: $3–5/unit × 15–20 seeders).
- Agent: `experiment-runner` generalist + Jim outreach.
- Jim hours: ~4 hrs across recruitment window; ~1 hr/wk thereafter.
- Escalation: `tg send` on <3 seeders activating by Day 14, on any
  promote-trigger fire, on any COPPA-adjacent share-artifact flag.

## Binding inheritance from `_synth-final.md` (do NOT re-litigate)

- Warm-network + mom-text-chains ARE the real reach mechanism (§8 #25).
  Treat this as the one organic-loop experiment.
- COPPA strict. Share artifacts cannot include kid names / faces.
- `utm_source=seeder_{slug}_friend` pattern (§8 #15).
- `brushquest.app/rangers` bridge (§8 #14).
- Not Facebook mom-groups, not Reddit (T3 in synth-final §5).

## Child loop sequencing (recommended)

1. **Week 2:** leaf 1 (Jim-led recruitment) starts. Target 15–20 seeders
   locked by end of Week 2.
2. **Week 2–3:** leaf 2 (onboarding kit) ships to each seeder as they
   sign on.
3. **Week 3–5:** `seeder_active` measurement window (Day-14 from each
   seeder's start).
4. **Week 4–5:** leaf 3 (share prompt) sent to active seeders, Jim texts
   individually. A/B ongoing.
5. **Week 5–7:** attribution window for friend-installs. Leaf 4 (in-app
   survey) deployed Week 3 as backup.
6. **Week 7:** postmortem + gate decision. Promote (≥10 friend-installs)
   → T1 child loop on referral playbook. Kill (<5) → learnings only.

## Charter termination criteria

- How many seeders recruited, how many activated?
- How many friend-installs attributed?
- Which share-prompt variant pulled more shares?
- Did in-app survey corroborate UTM counts? (sanity on iMessage strip)
- Is this a scalable organic loop or a 1:1 curiosity? Promote or kill.

---

**END META-PRD.** Charter frozen.

# GTM Decisions Log

Cross-node decisions that span multiple branches. This is a running log — append,
don't rewrite. Decisions here bind child loops.

## 2026-04-20 — Supersede v3 output shape, reuse v3 inputs

**Decision:** v4 (this factory) supersedes v3's output shape. v3's narrative doc
(`docs/gtm-engine/GTM_ENGINE_v3.md`) remains on disk as a source for Lens L4
(pattern-matching) — "what did we previously conclude and does current state
invalidate any of it?"

**Why:** v3 produced ~10K lines of unused narrative. Output shape change (tree of
executable PRDs) addresses execution bottleneck. v3 research still has value.

## Carried forward from v3 (still binding)

- Budget: $1,000–$2,000 for launch GTM.
- Content approach: both curated and user-generated acceptable.
- Founder constraint: not full-time; agentic wherever possible.
- Face of brand: not Jim (hire if revenue allows).
- Legal posture: COPPA-strict, pursue compliance without shortcuts.
- No ads inside app. No purchase prompts to children.

## Superseded / re-opened vs v3

- v3 assumed pre-launch; we are now live on Play internal testing. All "launch
  day" framings in v3 are re-interpreted as "public-release day" (pending Play
  review).
- v3's free-launch target (2026-04-11) has passed; timeline anchor is now
  2026-07-20 (90 days).
- iOS was out-of-scope in v3; v4 plans for iOS launch inside the 90-day window.

## Decisions from this plan (Phase 1)

- Skill lives at `.claude/commands/gtm-factory.md` (repo-local, matches /cyclepro).
- Loop artifacts tree-structured at `docs/gtm-v4/<node-path>/`.
- Phase 1 ships with validation loop only (trunk loop runs next, as first real use).
- Feedback loops (A/B/C), experiments execution, dashboard are follow-on plans.

## Phase 1 complete (2026-04-21)

Validation loop at `trunk/marketing/ugc/instagram-reels` executed end-to-end.
Machinery works: 5 diverse lens outputs, honest Synth-1/2 tiered portfolio,
3 distinct evaluator voices, termination gate emitted 2 PRDs + 6 meta-PRDs
(refused to fake-emit PRDs for under-specified bets).

### Key emergent insight from the validation run

L5 first-principles math reshaped the entire portfolio: the Play Store
internal-testing URL is a 5-step enrollment flow that looks like phishing
to non-technical parents. `tester_signup_rate` is likely <10%, not the
25%+ implicit in other lenses' funnels. Every Reels-facing bet now routes
through a `brushquest.app` email-capture bridge with auto-enroll at
public launch. This is a BINDING decision for all children of this node.

### Follow-on plans required

1. **Trunk loop (question B)** — run `/gtm-factory new-loop trunk "Reach 1,000 WAK by 2026-07-20 on $1–2K via agentic execution"` and emit pillar-level meta-PRDs.
2. **Loop A — pulse agent** — spec §6; Railway trigger at `jobs.json` in `~/Projects/claude-telegram-bridge/src/jobs.json`; idempotency by ISO week.
3. **Loop B — re-rank triggers + partial re-synth** — spec §6.
4. **Loop C — template meta-eval** — after 5+ loops exist.
5. **Experiments execution runtime** — spec §5; experiment-analyzer agent; `experiments-executor` wrapper.
6. **Dashboard at `brushquest.app/GTM-dashboard`** — spec §8; `frontend-design` skill.
7. **Child loops spawned by this validation's 6 meta-PRDs** — reddit-pipeline, creator-scouting, attribution-schema, buttondown-firebase-bridge, ig-posting-pipeline, play-publishing-api. Running these before Tier-1 Reels bets can fire as executable PRDs.

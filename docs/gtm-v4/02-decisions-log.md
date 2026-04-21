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

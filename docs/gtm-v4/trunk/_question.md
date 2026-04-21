# Trunk Loop Question (question B)

## Question

Reach **1,000 weekly-active kids brushing** with Brush Quest by **2026-07-20**
(90 days from today, 2026-04-21), via **agentic GTM execution** on a
**$1,000–$2,000 total launch budget**, with Brush Quest live on **Google Play
(public)** and **iOS TestFlight / App Store** by that date.

## Node path
`trunk`

## Why this framing
- **1,000 WAK** = real engagement metric (kids who brushed ≥1× in the last 7
  days using the app), not an install vanity number. Implies ~2–3K total
  installs at typical kids-app activation rates.
- **90 days / 2026-07-20** — long enough for iOS launch + two channel-learning
  cycles; short enough to force focus.
- **$1,000–$2,000** — honest about constraints; locks the portfolio to
  organic + micro-spend.
- **"Live on Play (public) + iOS live"** — forces sequencing around platform
  milestones in flight (Play public release, Apple Business approval due
  ~2026-04-24).
- **"Via agentic execution"** — the machine knows executor agents are the
  target consumer of the produced PRDs/meta-PRDs, not Jim doing everything
  manually.

## Expected output shape
- Portfolio: Tier-1 pillars (2–3 likely), Tier-2 experiments, Tier-3 parked
  routes with trigger conditions.
- For each Tier-1 pillar: `_meta-prd.md` (charter) that spawns the pillar's
  own child loop.
- For each Tier-2 experiment: either an experiment spec directly, or a
  compact pillar loop.
- Budget allocation across pillars + experiments.
- Sequencing: which pillar loop runs first, what triggers the second.

## Acceptance criteria (for the trunk loop itself)
- [ ] 5 distinct lens outputs in `_research/` (different voices visible)
- [ ] Synth-1 contains Tier-1, Tier-2, Tier-3 sections
- [ ] 3 distinct evaluator outputs in `_evals/`
- [ ] Synth-2 folds evaluator feedback visibly
- [ ] At least 1 meta-PRD emitted per Tier-1 pillar (charters for child loops)
- [ ] `_status.yaml` present at trunk

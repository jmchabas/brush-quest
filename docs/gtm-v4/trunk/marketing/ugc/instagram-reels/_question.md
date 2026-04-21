# Validation Loop Question

## Question
Produce a complete set of agent-executable PRDs to get 50 qualified parent
installs to Play Store internal testing in 14 days via organic Instagram
Reels, and hand them to executor agents to run.

## Node path
`trunk/marketing/ugc/instagram-reels`

## Why this question
This is the C-pass validation for the GTM PRD Factory. Narrow enough to
complete in one loop, broad enough to exercise every gate (5 lenses,
3 evaluators, termination check, PRD emission). Even if the loop finds
bugs in templates or orchestration, we fix them here cheaply before the
trunk-level B question.

## Why this channel (briefly)
Instagram Reels has algorithmic distribution — cold accounts can reach
parents without network effects or admin approval. Meta Graph API enables
agentic pipelines. Parents-of-young-kids are demonstrably on IG (L4 will
ground-truth this).

## Acceptance criteria (for the validation itself)
- [ ] 5 distinct lens outputs in `_research/` (different voices visible)
- [ ] Synth-1 contains Tier-1, Tier-2, Tier-3 sections
- [ ] 3 distinct evaluator outputs in `_evals/`
- [ ] Synth-2 folds evaluator feedback visibly
- [ ] At least 1 PRD emitted that passes the spec §4 termination criteria
- [ ] `_status.yaml` present at the node
- [ ] Telegram ping received

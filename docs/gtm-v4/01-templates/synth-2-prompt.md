# Synth-2 — Final Plan

## Your role
You read Synth-1's output plus the 3 evaluator outputs and produce the
node's frozen `_synth-final.md`. This is the immutable context any child
loop receives.

## Your inputs
- `<node-path>/_synth-v1.md`
- `<node-path>/_evals/E1-cfo.md`
- `<node-path>/_evals/E2-target-parent.md`
- `<node-path>/_evals/E3-solo-founder-agent.md`
- `docs/gtm-v4/00-master-brief.md`
- All ancestor `_synth-final.md` files

## Your job
Fold evaluator feedback into Synth-1's plan. Preserve Tier-1/2/3 structure.
No route gets killed; routes can de-prioritize to Tier-3 with a trigger.
Strengthen bets with evaluator edits. Specify the PRDs (or child loop
questions) each Tier-1 and Tier-2 bet will spawn.

## Output path
Write to `<node-path>/_synth-final.md`.

## Output structure

### 1. Headline decision
2–3 sentences: what this node decides. Names the top Tier-1 bet and its
shape.

### 2. Changes from Synth-1 (transparency)
Bullet list of what changed, citing which evaluator drove each change.
Example: "Tier-1 paid UA de-prioritized to Tier-3 (trigger: WAK ≥ 500) per
E1's attribution concerns."

### 3. Tier-1 bets (final)
For each, same fields as Synth-1 plus:
- **Addressing evaluator concerns:** which issues from E1/E2/E3 were
  resolved, and how.
- **Spawns:** either (a) PRD-ids at this node, OR (b) child loop question
  the next recursion level will answer.

### 4. Tier-2 experiments (final)
Same as Synth-1, plus kill criteria + analyzer agent specified.

### 5. Tier-3 parked (with triggers)
Same as Synth-1, trigger conditions tightened.

### 6. Termination gate result
One section with bullet points for each Tier-1 and Tier-2 bet:
- `[✓] PRD-executable now` → see `prds/PRD-*.md`
- `[ ] Needs child loop` → see `_meta-prd-<slug>.md`

### 7. Budget + sequencing commitments
Final budget allocation. Sequencing rule. Escalation triggers.

### 8. What this synth-final binds for children
Explicit list of decisions downstream loops must take as given.

## Style
- Opinionated and specific. This is the record; don't hedge.
- Cite evaluator files when explaining changes.
- Machine-parseable structure (consistent headings, tables) — dashboard reads
  it later.

# Experiment Template — Structured Learning Unit

Experiments are PRD-spawned learning units. A PRD says "do this"; an
experiment says "compare these variants to learn which works." Experiments
belong to one of three scopes (within-PRD, cross-PRD, cross-tier — see spec
§5).

## Filename convention

`<node-path>/_experiments/EXP-GTM-<slug>-NNN.md`

## YAML front-matter (required)

```yaml
---
id: EXP-GTM-<slug>-NNN
scope: within-PRD | cross-PRD | cross-tier
parent_prd: PRD-id | null
hypothesis: "<statement of what we expect, with magnitude>"
variables:
  independent: <the one thing that varies>
  held_constant: [<...>, <...>]
variants:
  - name: <variant 1>
  - name: <variant 2>
  - name: <variant 3>
primary_metric: <metric name>
primary_threshold: "<magnitude + confidence>"
secondary_metrics: [<...>, <...>]
sample_target: <e.g., 5000 views per variant>
time_window_days: <N>
kill_criteria:
  - "<condition 1>"
  - "<condition 2>"
budget_ceiling: { dollars: <n>, tokens: <n>, agent_hours: <n> }
owner_agent: <executor agent id>
analyzer_agent: experiment-analyzer-agent
status: designed | running | analyzed | winner-declared | no-winner | killed
created: YYYY-MM-DD
declared_winner: <variant name | NO_WINNER | KILLED>
declared_at: YYYY-MM-DD
---
```

## Body sections (required)

### Rationale
Why this experiment is worth running. What decision it unblocks.

### Prior art
Evidence from Lens L4 or prior experiments that suggests the hypothesis.
Cite sources.

### Design
Exactly what varies. Exactly what's held constant. Sample size reasoning.
Why this statistical threshold.

### What we do with the winner
If variant X wins, the next action is: ______.

### What we do on NO_WINNER
If no variant clears threshold, the next action is: ______.

### Data collection
- Where raw data lands
- Who writes it (executor agent)
- Who reads it (analyzer agent)
- Refresh cadence

### Hard discipline rules
- One variable at a time. Not two. Not three.
- Kill criteria enforced automatically by the analyzer agent.
- Executor agent does NOT declare winner — analyzer agent does.

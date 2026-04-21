# GTM v4 — PRD Factory

The live tree of GTM loops, plans, and executable PRDs for Brush Quest.
See spec: `docs/superpowers/specs/2026-04-20-gtm-prd-factory-design.md`.

## Layout

- `00-master-brief.md` — current product + business state, refreshed before each loop.
- `01-templates/` — lens prompts, evaluator prompts, synth prompts, PRD template, experiment template.
- `02-decisions-log.md` — running log of decisions that span nodes; reconciles with v3.
- `<node-path>/` — one folder per tree node (trunk → branches → sub-branches → leaves).
  Each node contains its loop artifacts (`_research/`, `_evals/`, `_synth-v1.md`,
  `_synth-final.md`, `_status.yaml`, optional `prds/`, optional `_meta-prd.md`).

## Running a loop

`/gtm-factory new-loop <node-path> "<question>"`

The skill reads ancestor `_synth-final.md` files, dispatches 5 lens agents in parallel,
runs Synth-1, dispatches 3 evaluators in parallel, runs Synth-2, checks the termination
gate, and emits either PRDs (at leaves) or `_meta-prd.md` child charters (at branches).

## Supersedes

`docs/gtm-engine/GTM_ENGINE_v3.md` (narrative) — v3 stays on disk as historical context.
v4 reshapes output from one narrative doc to a tree of executable PRDs.

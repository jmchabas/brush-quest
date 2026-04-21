# /gtm-factory — GTM PRD Factory

Orchestrator for the GTM PRD Factory. Produces agent-executable PRDs via a
loop of 5 lens research agents → Synth-1 → 3 persona evaluators → Synth-2 →
termination gate.

Design spec: `docs/superpowers/specs/2026-04-20-gtm-prd-factory-design.md`
Templates: `docs/gtm-v4/01-templates/`
Master brief: `docs/gtm-v4/00-master-brief.md`

## Route on arguments

Parse `$ARGUMENTS`:

- **`new-loop <node-path> "<question>"`** → Run a full loop at the named node
  path for the given question. Core Phase 1 command. Details below.
- **`pulse <node-path>`** → NOT YET IMPLEMENTED (Phase 2). Say so and exit.
- **`re-rank <node-path>`** → NOT YET IMPLEMENTED (Phase 2). Say so and exit.
- **`meta-eval`** → NOT YET IMPLEMENTED (Phase 3). Say so and exit.
- **`status`** → Read all `_status.yaml` files in `docs/gtm-v4/` and print a
  tree snapshot.
- **No args or unknown** → Print usage.

Strict rule for unimplemented subcommands: output "Phase 2 — not yet
implemented. See `docs/superpowers/specs/2026-04-20-gtm-prd-factory-design.md`
§6 for design; implementation plan to follow." and exit without side effects.

## Phase 1 command: `new-loop <node-path> "<question>"`

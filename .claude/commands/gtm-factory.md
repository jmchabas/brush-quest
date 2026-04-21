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

### Step 1: Assemble the context brief

Before dispatching any agent, build the context brief every lens agent,
evaluator, and synth agent will receive.

1. **Refresh the master brief.** Check `git log -1 docs/gtm-v4/00-master-brief.md`.
   If older than 7 days, regenerate it from:
   - `~/.claude/projects/-Users-jimchabas-Projects-brush-quest/memory/MEMORY.md`
   - Recent `git log --oneline -30`
   - `pubspec.yaml` (current version)
   - `STATUS.md` (if present)
   Rewrite the brief in place; commit the update.

2. **Gather ancestor synth-finals.** For the given `<node-path>`, walk from
   root (`docs/gtm-v4/trunk/`) down to the parent. For each ancestor, read
   its `_synth-final.md` if present. Missing at intermediate nodes is OK
   (the node hasn't run a loop yet); record this fact in the assembled
   brief.

3. **Gather ancestor meta-PRDs.** Same walk. Read any `_meta-prd*.md` files
   at ancestors if they exist.

4. **Read any `_escalation.md` at the current node.** If present, halt and
   report: "Open escalation at this node; resolve before running new loop."

5. **Compose the assembled brief** as a single string:

   ```
   # Context for loop at <node-path>
   ## Question
   <the question>
   ## Master brief
   <verbatim contents of 00-master-brief.md>
   ## Ancestor synth-finals (root → parent)
   <each file as its own section, clearly labeled with source path>
   ## Ancestor meta-PRDs (root → parent)
   <each file as its own section>
   ## Decisions log (cross-node)
   <verbatim contents of 02-decisions-log.md>
   ```

   Write this assembled brief to `<node-path>/_context-brief.md`. Overwrite
   any prior version. This file exists for audit and debugging; it is an
   intermediate artifact.

6. **Create the loop directory structure:**

   ```bash
   mkdir -p <node-path>/_research
   mkdir -p <node-path>/_evals
   # prds/ and _experiments/ only created if loop output produces them
   ```

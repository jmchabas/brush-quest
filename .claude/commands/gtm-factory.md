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

### Step 2: Research phase — dispatch 5 lens agents in parallel

Dispatch 5 Agent tool calls in a SINGLE message (parallel execution). All 5
agents use `subagent_type: general-purpose` — this subagent type already has
WebSearch and WebFetch available, which L4's pattern-matching template
explicitly directs the agent to use for web research.

For each lens, the prompt is a concatenation of:
1. The lens template file contents (e.g., `docs/gtm-v4/01-templates/lens-digital-native.md`)
2. The assembled context brief written in Step 1
3. An instruction to write its output to a specific file path:
   "Write your output to `<node-path>/_research/L1-digital-native.md`. Use
   the output structure specified in the template. Do not write anywhere else."

The 5 agents and their output paths:

| Agent | Template | Output path |
|-------|----------|-------------|
| L1 | `docs/gtm-v4/01-templates/lens-digital-native.md` | `<node-path>/_research/L1-digital-native.md` |
| L2 | `docs/gtm-v4/01-templates/lens-bold-contrarian.md` | `<node-path>/_research/L2-bold-contrarian.md` |
| L3 | `docs/gtm-v4/01-templates/lens-frugal-scrappy.md` | `<node-path>/_research/L3-frugal-scrappy.md` |
| L4 | `docs/gtm-v4/01-templates/lens-pattern-matching.md` | `<node-path>/_research/L4-pattern-matching.md` |
| L5 | `docs/gtm-v4/01-templates/lens-first-principles.md` | `<node-path>/_research/L5-first-principles.md` |

After all 5 agents return:
- Verify all 5 output files exist and are non-empty.
- Skim each to confirm the lens voice is distinct (a smoke check; if L1 and
  L3 produce near-identical output, flag a template problem and stop).

Commit the 5 research files:

```bash
git add <node-path>/_research/
git commit -m "loop(<node-path>): 5 lens research outputs"
```

### Step 3: Synth-1

Dispatch a single Agent tool call with `subagent_type: general-purpose`.

Prompt is a concatenation of:
1. The Synth-1 template: `docs/gtm-v4/01-templates/synth-1-prompt.md`
2. The assembled context brief
3. The 5 research files (read and inlined or handed by path — prefer inline)
4. An instruction: "Write your output to `<node-path>/_synth-v1.md`."

After the agent returns, verify the output file exists, is non-empty, and
contains Tier-1, Tier-2, Tier-3 section headings. If any missing, re-dispatch
with an explicit correction instruction (once); if still missing, stop and
escalate via `tg send`.

Commit:

```bash
git add <node-path>/_synth-v1.md
git commit -m "loop(<node-path>): synth-1 portfolio draft"
```

### Step 4: Evaluator phase — dispatch 3 persona agents in parallel

Dispatch 3 Agent tool calls in a SINGLE message (parallel).
`subagent_type: general-purpose`.

For each evaluator, the prompt is:
1. The evaluator template file contents
2. The assembled context brief
3. The Synth-1 output (inlined)
4. An instruction to write to the specific output path

| Agent | Template | Output path |
|-------|----------|-------------|
| E1 | `docs/gtm-v4/01-templates/evaluator-cfo.md` | `<node-path>/_evals/E1-cfo.md` |
| E2 | `docs/gtm-v4/01-templates/evaluator-target-parent.md` | `<node-path>/_evals/E2-target-parent.md` |
| E3 | `docs/gtm-v4/01-templates/evaluator-solo-founder-agent.md` | `<node-path>/_evals/E3-solo-founder-agent.md` |

Verify all 3 files exist and contain distinct feedback (smoke check: if two
evaluators produce near-identical critiques, flag template problem).

Commit:

```bash
git add <node-path>/_evals/
git commit -m "loop(<node-path>): 3 evaluator outputs"
```

### Step 5: Synth-2 — final plan

Dispatch a single Agent tool call with `subagent_type: general-purpose`.

Prompt is a concatenation of:
1. `docs/gtm-v4/01-templates/synth-2-prompt.md`
2. The assembled context brief
3. Synth-1 output
4. All 3 evaluator outputs
5. Instruction: "Write your output to `<node-path>/_synth-final.md`."

After the agent returns, verify the file exists and contains the termination
gate section (step 6 depends on it).

Commit:

```bash
git add <node-path>/_synth-final.md
git commit -m "loop(<node-path>): synth-final — plan frozen"
```

### Step 6: Termination gate

Read `<node-path>/_synth-final.md`. For each bet in Tier-1 and Tier-2,
determine which branch:

**Branch A — PRD-executable now.** The gate passes when ALL of the following
are demonstrably present in the Synth-final's description of this bet:
1. Measurable goal with specific metric + window.
2. Context fully specified (can an executor agent act without Jim?).
3. Every input named with location (path, credential id, MCP id, prior PRD).
4. Acceptance criteria are checkable (no "looks good").
5. Tools required exist or are explicitly flagged as TO-BUILD (which becomes
   a blocking PRD of its own).
6. Escalation triggers specified.

If all 6 pass → **Emit a PRD** at `<node-path>/prds/PRD-GTM-<slug>-NNN.md`
using the `docs/gtm-v4/01-templates/prd-template.md` structure. Fill in
every section based on the Synth-final's description of this bet. Commit.

**Branch B — Needs child loop.** Any of the 6 fails → **Emit a meta-PRD** at
`<node-path>/_meta-prd-<slug>.md` that serves as the charter for the child
loop on this bet. The meta-PRD names: (a) the child question to answer,
(b) what the child loop must produce, (c) which of the 6 criteria above are
missing that the child loop will resolve.

**Tier-3 bets** get neither — they stay in `_synth-final.md`'s Tier-3 list
with their trigger condition. No PRD, no meta-PRD.

For this task, dispatch one Agent tool call with `subagent_type:
general-purpose`. Prompt includes the Synth-final, the PRD template, and
instructions to read through each bet and emit the appropriate file(s).
The agent writes PRDs + meta-PRDs directly.

After the agent returns, read `<node-path>/prds/` and `<node-path>/` for
the emitted files. Verify at least one artifact per Tier-1/2 bet exists.

Commit:

```bash
git add <node-path>/prds/ <node-path>/_meta-prd-*.md 2>/dev/null
git commit -m "loop(<node-path>): termination gate — PRDs + meta-PRDs emitted"
```

### Step 7: Emit `_status.yaml`

Write `<node-path>/_status.yaml`:

```yaml
node: <node-path>
depth: <int, derived from path depth under docs/gtm-v4/>
created: <YYYY-MM-DD of first loop — keep if exists>
last_loop_completed: <YYYY-MM-DD of today>
last_pulse: null           # filled when Loop A ships
active_prds: <count of PRDs in prds/ with status in [draft, approved, in-flight]>
completed_prds: <count with status: done>
active_experiments: 0      # placeholder until experiments execute
learnings_count: 0         # placeholder
children:                  # directories under this node with _status.yaml
  - <child-path>
tier: <this node's tier at its parent — pull from parent's _synth-final.md>
open_escalations: <count of _escalation.md files here or in descendants>
```

Commit:

```bash
git add <node-path>/_status.yaml
git commit -m "loop(<node-path>): status emitted"
```

### Step 8: Summary + notification

After all steps:
1. Print a one-line summary: `Loop at <node-path> complete. N PRDs emitted,
   M meta-PRDs queued, K Tier-3 parked.`
2. Ping Jim via Telegram: `tg send "GTM loop complete: <node-path> — <summary>"`
3. If any escalation was written during the loop, include it in the ping
   with a link to the file.

### Escalation valve (invoked from any step)

If during any step, a lens agent, evaluator, or synth agent identifies strong
evidence that a parent decision (from an ancestor `_synth-final.md`) is
invalidated by new information, the loop halts and emits:

```markdown
# Escalation — <node-path>

## Date
YYYY-MM-DD

## Parent decision challenged
<quote from ancestor _synth-final.md>

## Evidence
<the new information>

## Proposed revision
<what the ancestor would need to change>

## Blocking
<what's halted waiting on resolution>
```

Write to `<node-path>/_escalation.md`. Then:
1. Commit the escalation doc.
2. `tg send "GTM escalation at <node-path>: <one-line summary>"`.
3. STOP the loop. Do not run subsequent steps.

Escalations should be rare. If multiple fire in short succession, flag a
template problem (future Loop C input).

## Subcommand: `status`

Print a tree snapshot of `docs/gtm-v4/` showing every node with its status.

Algorithm:
1. Find all `_status.yaml` files under `docs/gtm-v4/`.
2. Parse each; print indented by path depth.
3. For each node, print: path, last_loop_completed, active_prds, tier,
   open_escalations.
4. At the end, list all open escalation files and all active PRDs across
   the tree.

Output format (plaintext, not rendered):

```
docs/gtm-v4/
├─ trunk/                    [loop: 2026-05-01  PRDs: 0  tier: –  esc: 0]
│  ├─ marketing/             [loop: 2026-05-02  PRDs: 0  tier: 1  esc: 0]
│  │  └─ ugc/
│  │     └─ instagram-reels/ [loop: 2026-05-03  PRDs: 2  tier: 1  esc: 0]
│  └─ partnerships/          [loop: –           PRDs: 0  tier: 2  esc: 0]

Active PRDs (2):
- PRD-GTM-instagram-reels-001  draft  owner: instagram-executor-agent
- PRD-GTM-instagram-reels-002  draft  owner: instagram-executor-agent

Open escalations (0).
```

No agent dispatch needed. Pure file-read + format.

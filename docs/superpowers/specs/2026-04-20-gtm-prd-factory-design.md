# GTM PRD Factory — Design Spec

**Date:** 2026-04-20
**Author:** Jim + Claude (brainstorm session)
**Status:** Approved design — pending implementation plan (next step: `superpowers:writing-plans`)
**Supersedes:** `docs/gtm-engine/GTM_ENGINE_v3.md` (2026-04-03) — v3 stays on disk as historical reference; v4 re-grounds planning in current product state (live on Play internal testing) and changes the output shape from a single narrative doc to a tree of agent-executable PRDs.

---

## 1. What this is

A **PRD factory for GTM**.

**Input:** a question (e.g., *"what's our route to market?"*, *"how do we nail TikTok as a channel?"*, *"how do we design the UGC asset pipeline?"*).

**Output:** two things:
1. A synthesized decision document at the level of the question (short, human-readable).
2. A set of **agent-executable PRDs** (work orders). Each PRD is consumed by an **executor agent** (TikTok agent, Instagram agent, dentist-outreach agent, paid-UA agent, etc.) that runs the actual GTM work.

**Role separation:**
- **The factory** produces plans and PRDs. It does not execute GTM tactics.
- **Executor agents** run PRDs. One executor per active PRD, specialized by domain.
- **Jim** supervises the factory, builds executor agents, and approves escalations.

**Three implications of this reframe:**
- Every leaf output must be executable by an agent without Jim present. That forces the factory to emit tool specs, credentials lists, escalation rules, acceptance criteria — not just narrative.
- Recursion terminates at *"an executor agent has everything it needs"*, not at a fixed tree depth. Data-driven termination.
- Templates (lens library, evaluator personas, PRD template, experiment spec, pulse output) are first-class assets — versioned in the repo, improved by Loop C.

**What this is NOT:**
- Not a static plan. The tree + PRDs + experiments update continuously via feedback loops.
- Not a replacement for strategic judgment. Jim approves Tier promotions, escalations, and budget reallocations.
- Not a general-purpose tool (yet). Built for Brush Quest first; generic-layer extraction is a deferred Phase 2.

---

## 2. The loop (one level of recursion)

Every node in the tree runs this loop exactly once to produce its plan and children. Re-runs happen only via Loop B (re-rank) or escalation.

```
INPUT: question + context brief (see §3)
  ↓
[Mandate generator]
   For the question, emit 5 lens prompts (from lens library).
   Each lens covers the FULL question, through its lens — does not champion one route.
  ↓
[Research phase] — 5 agents in parallel (Agent tool, general-purpose or specialized):
  L1 Digital-native lens   — "How would a modern D2C/SaaS/dev-tool founder think about this?
                             What feels obvious inside that world? Which playbooks transfer?"
  L2 Bold / contrarian lens — "What's the audacious 10× play? What's the bet nobody sane
                             is making? What would you do with 100× the budget — and which
                             cheap proxy tests that thesis now?"
  L3 Frugal / scrappy lens — "What works with $0–$500 and one founder, no team, this week?
                             Where are the zero-cost distribution surfaces?"
  L4 Pattern-matching lens  — "What actually worked for 5 comparable apps in 2024–2026
                             (Lingokids, Khan Kids, Yoto, Dr. Panda, Smash Karts, BabyBus,
                             Duolingo-for-kids, etc.)? Use real web research — cite sources."
                             This agent is explicitly allowed/expected to do WebSearch/WebFetch.
  L5 First-principles lens  — "Strip to fundamentals. What must be true for ANY route to work?
                             What's the minimum viable distribution engine this app needs?
                             What assumptions are we taking for granted that deserve re-test?"
  ↓
[Synth-1 agent] → integrated portfolio plan:
  • Tier-1 bets (main pushes — most agent-hours + budget)
  • Tier-2 experiments (parallel cheap tests — learn whether to promote)
  • Tier-3 parked (revisit on trigger condition — NEVER "killed")
  For each bet, emit:
    - hypothesis (why we think this works)
    - expected CAC band (lo/mid/hi)
    - expected volume (over what time window)
    - time-to-signal (how long before we know if it's working)
    - budget + agent-hours required
    - the sub-question that would open it (feeds child loop)
  ↓
[Evaluator phase] — 3 persona agents in parallel. Realistic lens, not gatekeeping.
   Each emits: strengthen / test / de-prioritize (ranked, with reasoning). No "kill".
  E1 Skeptical CFO + attribution     — "Is this measurable? Is the ROI honest? Where are
                                       we assuming attribution we can't actually see?
                                       What's the cash-burn tail risk?"
  E2 Target parent (ICP)             — "I'm a tired parent of a 7yo scrolling at 9pm.
                                       Will any of this reach me? Will it make me trust
                                       and install? What's the moment I bounce?"
  E3 Solo-founder executor-agent     — "Can an executor agent (not a full-time human team)
                                       actually run this with budget $X and tools Y,
                                       next week? What's missing from the plan to make
                                       it actually executable?"
  ↓
[Synth-2 agent] → final plan (tiered structure preserved, eval feedback folded in).
   Emits `_synth-final.md` at this node — FROZEN as context for any child loops (§3).
  ↓
[Termination gate]
   For each Tier-1 AND Tier-2 bet: can we write an agent-executable PRD NOW
   (per §4 criteria)?
     Yes → emit PRDs at this node to `prds/` folder → stop recursing this branch
     No  → enqueue the unresolved dimension as a child loop question;
           emit a `_meta-prd.md` (charter for the child loop) instead of a full PRD
   Tier-3 stays parked — no PRD until its trigger condition fires.
  ↓
OUTPUT per node:
   _research/*.md        (5 lens agent outputs, verbatim)
   _synth-v1.md          (Synth-1 output)
   _evals/*.md           (3 evaluator outputs, verbatim)
   _synth-final.md       (Synth-2 output — frozen child context)
   _status.yaml          (machine-readable status — dashboard-friendly)
   prds/PRD-*.md         (executable PRDs at leaves)
   _meta-prd-*.md        (charters for child loops at branches)
```

**Key design choices (and why):**

- **5 lenses, not adversarial stances.** Adversarial stances (A-champion, B-champion, C-champion) would cause early narrowing and shallow coverage. Each lens agent must cover the *full* question through its lens, producing a rich map. The synth's job is composing across rich maps, not picking between thin bets.
- **Lenses are deliberately complementary.** Digital-native + bold-contrarian + frugal-scrappy span the budget/ambition axis. Pattern-matching grounds in reality. First-principles prevents path-dependency on what comparable apps did.
- **Web research is explicit in L4.** The lens has WebSearch/WebFetch in its tool set; others should cite only general knowledge. Keeps "what actually worked" separate from "what I think will work."
- **Evaluators strengthen, don't gatekeep.** User constraint: "don't kill routes too early." De-prioritize = move to Tier-3 (parked with trigger), never delete.
- **Tier-1/2/3 preserves optionality.** Tier-2 experiments are the mechanism by which we learn whether Tier-3 should promote. Tier-3 is a watchlist, not a graveyard.
- **Termination gate is data-driven.** Recursion stops when PRDs can be written. Some branches resolve in 1 loop; others need 3–4 levels.

---

## 3. The tree + context cascade

The factory organizes its work as a **tree**, not a flat backlog. Each node has exactly one parent (except trunk). Each child inherits frozen context from its parent.

### Tree structure (starting shape — will evolve)

```
GTM (trunk)
├─ Marketing (branch)
│  ├─ UGC (sub-branch)
│  │  ├─ TikTok (leaf → PRDs)
│  │  ├─ Instagram Reels (leaf → PRDs)
│  │  ├─ YouTube Shorts (leaf → PRDs)
│  │  ├─ UGC assets pipeline (leaf → PRDs)
│  │  └─ UGC tools/infra (leaf → PRDs)
│  ├─ Paid UA (sub-branch)
│  ├─ PR / earned media (sub-branch)
│  └─ ASO (sub-branch)
├─ Partnerships (branch)
│  ├─ Pediatric dentists (sub-branch)
│  ├─ Pediatricians (sub-branch)
│  └─ Schools / parent orgs (sub-branch)
├─ Product-led growth / referral (branch)
└─ Community / earned audience (branch)
```

Depth is data-driven — not every branch needs to go 4 levels deep. A sub-branch may resolve directly to PRDs (2 levels) or recurse further (3–4 levels). The termination gate decides.

### Context cascade rules

**Child context brief = concatenation of:**
1. **Current-state brief** (`00-master-brief.md`) — product status, budget, team, monetization model, constraints. Refreshed from `MEMORY.md` + `git log` + `STATUS.md` at the start of each run.
2. **All ancestor `_synth-final.md` files** (trunk → branch → sub-branch, in order).
3. **All ancestor `_meta-prd-*.md` files** relevant to this child.
4. **The specific question for this level.**

Example — the TikTok leaf loop gets as input:
```
00-master-brief.md                             # current state
trunk/_synth-final.md                          # GTM portfolio decisions
trunk/marketing/_synth-final.md                # Marketing branch decisions
trunk/marketing/ugc/_synth-final.md            # UGC sub-branch decisions
trunk/marketing/ugc/tiktok/_meta-prd.md        # TikTok charter from UGC loop
QUESTION: "How do we execute TikTok specifically?"
```

### Frozen decisions + escalation valve

**Frozen rule:** parent decisions committed in `_synth-final.md` are IMMUTABLE context for children. A child loop does not re-litigate whether UGC is a Tier-1 bet; it takes that as given and asks "how does UGC execute?"

**Escalation valve:** if during a child loop, research or evaluator output surfaces strong evidence that a parent decision was wrong, the child loop halts and emits:
```
<node>/_escalation.md
```
This doc names: which parent decision is challenged, what evidence, proposed revision. Human (Jim) reviews and either (a) accepts and triggers a parent re-loop, (b) rejects and resumes the child, or (c) parks the concern in a watchlist.

Escalations should be rare. If they're common, lenses or evaluators need tuning (Loop C's job).

### Why this shape

- Mirrors real PRD tracks: vision → strategy → PRD → spec → task. Each layer commits the previous.
- Enables **depth-first execution**: we deep-dive one pillar at a time (user's design), not breadth-first portfolio.
- Keeps the context window at child loops bounded and focused. No child agent ever needs to re-derive trunk-level tradeoffs.
- Dashboard-friendly: tree structure maps 1:1 to nav/breadcrumb UI.

---

## 4. Agent-executable PRD format

PRDs are the terminal output of the factory. They are written in markdown with YAML front-matter for machine parsing. **Length is not capped** — each PRD must contain enough context for an executor agent to act without Jim present.

### Front-matter (YAML)

```yaml
---
id: PRD-GTM-<slug>-NNN                 # e.g., PRD-GTM-instagram-reels-001
title: <one-line description>
parent_question: <the loop question that produced this PRD>
parent_node: <path in tree, e.g., trunk/marketing/ugc/instagram-reels>
tier: 1 | 2 | 3
status: draft | approved | in-flight | done | parked | escalated
owner_agent: <executor agent id, e.g., instagram-executor-agent>
budget:
  dollars: <ceiling>
  tokens: <ceiling>
  agent_hours: <estimate>
  jim_hours: <estimate — human-in-loop minutes>
timeline:
  start: YYYY-MM-DD
  checkpoints: [YYYY-MM-DD, YYYY-MM-DD]
  end: YYYY-MM-DD
depends_on: [PRD-ids this PRD can't start without]
blocks: [PRD-ids waiting on this]
experiments: [EXP-ids this PRD runs]
created: YYYY-MM-DD
last_updated: YYYY-MM-DD
---
```

### Body sections (markdown)

```markdown
# Goal
One sentence, measurable. "Post 3 Instagram Reels/week for 14 days, achieving
5K views per Reel median and 50 total attributable Play Store installs."

# Context brief
Everything the executor agent needs to act without asking Jim:
- Product state (live on Play internal testing, iOS in review, etc.)
- Target persona (parent of 4-8yo, tired, 9pm scroll window)
- Constraints (COPPA, no ads in copy targeting kids, no paid creator without approval)
- Prior decisions from ancestor `_synth-final.md` (what's been decided upstream)
- What's been tried before and what happened

# Inputs required
- Credentials: Instagram Business account, Meta Graph API token
- Assets: 10 existing gameplay clips in `assets/marketing/clips/`
- Prior outputs: copy variants from PRD-GTM-copy-bank-001
- Brand pack: voice guide, logo kit, color palette — `docs/brand/`
- Tools MCP: `@meta-graph-mcp`, ElevenLabs (voiceover), FFmpeg (editing)

# Outputs required
- Artifacts: 6+ Reels posted, each with caption + first-comment link
- Tracking: UTM'd Play Store URLs in bio + first comment
- Data: posting log with timestamp, video ID, variant, metrics snapshot at 24h/72h/7d
- Location: Reels published to @brushquestapp; data in
  `trunk/marketing/ugc/instagram-reels/_data/posts.yaml`

# Acceptance criteria (executor agent does not mark done until ALL pass)
- [ ] 6 Reels posted within 14 days
- [ ] Each Reel tagged with experiment variant (§5)
- [ ] Each Reel's view/save/share/click metrics logged at 24h and 7d
- [ ] UTM attribution captured; attempt Play Console referrer match
- [ ] Experiment analyzer agent invoked at day-14; winner declared (or NO_WINNER)
- [ ] Post-mortem doc written to `_learnings.md`

# Metrics
Primary: view-to-install conversion (attributed via UTM + Play referrer)
Secondary: median views, save rate, share rate, comment sentiment
Attribution window: 7 days from video view
Measurement system: posts.yaml written by executor; pulse agent aggregates

# Tools the executor needs
- MCP: `@meta-graph-mcp` (post, read insights)
- MCP: `elevenlabs` (optional, for voiceover variants)
- CLI: FFmpeg via Bash
- Human-in-loop: Jim approves first Reel before posting (one-time)

# Escalation triggers (executor pings Jim via `tg send`)
- Budget spent: ≥80% of ceiling → pause + ping
- Metric miss: view median <500 after 3 posts → pause + ping
- COPPA/brand flag: any comment/DM involving child identifiable data → pause + ping
- Platform flag: IG warning/flag on account → pause + ping immediately

# Risks + mitigations
- Risk: account cold-start means early Reels get <1K views
  → Mitigation: L4 research showed 5 Reels burn-in is normal; budget 5 warmup posts
- Risk: IG Reels algorithm changes mid-run
  → Mitigation: cross-post one variant to TikTok and Shorts as control

# Change log
- 2026-04-22  Created — PRD-GTM-instagram-reels-001
- (future edits logged here)
```

### What makes a PRD "executable" (termination gate criterion)

The gate passes when ALL of the following are true:
1. Goal is measurable with a specific metric + window.
2. Context brief is complete enough that the executor agent never needs to ask Jim "what do you mean by X".
3. Every required input is named with location (file path, credential id, MCP id, prior PRD id).
4. Acceptance criteria are checkable (no vague "looks good").
5. All tools required exist or are explicitly flagged as TO-BUILD (which itself becomes a blocking PRD).
6. Escalation triggers are specified (when to stop and ask Jim).

If any of 1–6 fails, the termination gate returns NO and the loop recurses.

---

## 5. Experiments framework

Experiments are a first-class concept, separate from PRDs. A PRD says "do this"; an experiment says "compare these variants to learn which works." PRDs run experiments; experiments produce learnings; learnings update templates (Loop C).

### Three scopes

**Within-PRD experiments** (A/B/C inside one channel):
The most common case. Every channel PRD runs at least one structured A/B test. Example: Instagram Reels PRD tests *hook style* (parent-face / kid-face / voiceover-only) with other variables held constant. One variable per experiment.

**Cross-PRD experiments within a branch** (e.g., same creative on Reels vs Shorts vs TikTok):
Live at the branch node, not inside any single PRD. Answers "which leaf wins the same creative?"

**Cross-tier experiments** (e.g., Tier-2 dentist outreach vs Tier-1 Reels on CAC):
Live at parent pillar/trunk level. Drive Loop B re-rank decisions.

### Experiment spec format

Each experiment gets its own file under `<node>/_experiments/EXP-<slug>-NNN.md` with YAML front-matter + markdown body.

```yaml
---
id: EXP-GTM-instagram-hook-001
scope: within-PRD | cross-PRD | cross-tier
parent_prd: PRD-GTM-instagram-reels-001        # null if cross-PRD/cross-tier
hypothesis: "Parent-face hooks outperform kid-face hooks on Reels by ≥2× view-to-click CTR"
variables:
  independent: hook_style
  held_constant: [caption, CTA, posting_time, music]
variants:
  - name: parent-face
  - name: kid-face
  - name: voiceover-only
primary_metric: view-to-click CTR
primary_threshold: "≥2× between best and worst variant, p<0.1 with n≥5K views/variant"
secondary_metrics: [watch_time, saves, installs]
sample_target: 5000 views per variant
time_window_days: 14
kill_criteria:
  - "No variant clears 0.5% CTR by day 7 → kill, re-plan"
  - "Total spend reaches $500 with no signal → kill"
budget_ceiling: { dollars: 500, tokens: 200000, agent_hours: 4 }
owner_agent: instagram-executor-agent
analyzer_agent: experiment-analyzer-agent
status: designed | running | analyzed | winner-declared | no-winner | killed
created: YYYY-MM-DD
declared_winner: <variant name | NO_WINNER | KILLED>
declared_at: YYYY-MM-DD
---
```

Body sections: rationale, prior art (citations from L4 pattern-matching), what we'll do with the winner, what we'll do if NO_WINNER.

### Discipline rules (hard)

- **One variable per experiment.** Never change hook AND CTA AND time simultaneously. If multiple variables need testing, sequence them.
- **Every experiment has a kill criterion.** No zombies consuming budget forever.
- **Separation of duties.** The executor agent runs the experiment. The **experiment-analyzer agent** (different agent) reads the data and declares winner. This prevents "I ran it, therefore it worked" bias.
- **Winners promote to rules.** When a winner is declared with strong effect, the rule goes into `_learnings.md` at the experiment's node and is absorbed into lens/PRD templates via Loop C (see §6).
- **Losers also log.** NO_WINNER outcomes write to `_learnings.md` too — they're valuable negative evidence.

### Experiment registry per node

Every node with experiments maintains `_experiments/_registry.yaml`:

```yaml
experiments:
  - id: EXP-GTM-instagram-hook-001
    status: winner-declared
    winner: parent-face
    declared_at: 2026-05-06
  - id: EXP-GTM-instagram-cadence-001
    status: running
    started: 2026-05-07
```

The dashboard reads this registry to show per-node experiment status.

---

## 6. Feedback loops

The tree is **live**, not static. Three nested loops keep it healthy.

### Loop A — Intelligent Pulse (weekly, per subtree)

A **pulse agent** runs weekly at each active subtree root (minimum: trunk). Reads all PRD + experiment status in the subtree; emits `_pulse-YYYY-MM-DD.md`.

**Six analyses per pulse:**

1. **Status roll-up.** For every PRD: pull status + latest outcome numbers. Classify: on-track / diverging / at-risk / done / stalled.
2. **Variance analysis.** For each PRD, compare actuals vs shipped hypothesis (CAC, volume, time-to-signal). Flag any >2× delta (positive or negative) as an anomaly.
3. **Root-cause hypotheses.** For each diverging/at-risk PRD, write 2–3 candidate causes ranked by likelihood. Never blind. Example: "Reels views on target but installs 5× below predicted → H1: landing friction, H2: CTA unclear, H3: wrong-intent audience."
4. **Cross-PRD pattern mining.** Look for signals spanning PRDs in this subtree. "Every video PRD hits view targets but misses install targets → systemic funnel issue, not creative."
5. **Prediction updates.** Rewrite the forecast fields in each PRD's front-matter with empirical priors. Future re-synth at parent nodes inherits better priors.
6. **Trigger checks + recommendations.** Is this pulse hitting a Loop B re-rank trigger (§6 below)? Is any experiment complete? Which new spike-PRDs should be created to investigate anomalies? Specific next actions, ranked.

**Pulse output structure:**

```markdown
# Pulse — <node path> — YYYY-MM-DD

## Status across active PRDs
<table: PRD id | status | primary metric actual | target | on-track?>

## Anomalies (>2× delta vs prediction)
- PRD-001 view-to-install: predicted 1%, actual 0.22% → ROOT CAUSE (ranked)
- PRD-004 organic shares: predicted 5, actual 47 → POSITIVE ANOMALY, investigate

## Cross-PRD learnings this week
- Parent-led Reels: 2.3× higher CTR than kid-only (EXP-001 declared)
- Morning post slot > evening by 40% across three PRDs

## Predictions updated
- UGC/Instagram CAC: $20 → $45 (3 weeks of data)
- Reel time-to-signal: 7 days → 10 days

## Recommendations (ranked, actionable)
- [ ] PRD-001: iterate CTA copy — new within-PRD experiment
- [ ] PRD-002: escalate voiceover rate limit to Jim
- [ ] NEW: spike PRD to investigate org-share anomaly (PRD-004)
- [ ] Update parent-node forecast (trunk/marketing/ugc/_synth-final.md)

## Loop B trigger checks
- Tier-2 TikTok vs Tier-1 Reels CAC delta: 1.3× (trigger at 2×, not yet)
- Any Tier-1 missing time-to-signal by ≥50%? No.

## Next pulse: YYYY-MM-DD
```

The pulse is itself an Agent call — reads the subtree, runs the analyses, writes the output. Idempotent (see §7).

### Loop B — Portfolio re-rank (triggered, not scheduled)

Re-rank = re-run Synth-2 **only** (not the full loop) at an affected parent node with new evidence as additional context. Cheap, focused re-synthesis — does not redo lens research or evaluator pass.

**Trigger conditions (any one fires Loop B):**
- A Tier-2 experiment beats a Tier-1 bet on CAC by ≥2× over ≥14 days.
- A Tier-1 bet misses its time-to-signal window by ≥50% with no recovery path in the latest pulse.
- A Tier-3 parked route hits its revisit trigger (e.g., "when WAK ≥500, revisit schools outreach").
- An escalation valve (§3) fires.

**Loop B outputs:**
- Updated `_synth-final.md` at the affected node (version-bumped; previous kept as `_synth-final-vN.md`).
- New or revised `_meta-prd.md` for affected children.
- Telegram ping to Jim: "Loop B re-rank at <node> — <summary>."

**Tier-2 and Tier-1 run in parallel, always.** This is the learning engine. Budget allocation default: 70% Tier-1 / 20% Tier-2 / 10% Tier-3 activation reserve. The trunk plan commits this split; branch plans inherit and may adjust.

### Loop C — Meta-eval (every N completed loops, self-improvement)

Every N complete loops (start with N=5; tunable), a **meta-eval agent** reads the last N loops' full artifacts and asks:

- Were the 5 lens agents actually diverse, or did they converge? Which lens added least?
- Did evaluator personas catch what reality caught (per pulses and experiments)? Which persona needs re-tuning?
- Did PRDs have fields executor agents didn't use? Did they need fields that weren't there?
- Which experiment winners were consistent enough to promote to **rules** in the lens library?
- Which comparable-app examples in L4 research turned out predictive vs misleading?

**Loop C outputs edits to `01-templates/`** (mandate library, lens definitions, evaluator prompts, PRD template, experiment spec template). The machine gets smarter over time.

Loop C also writes a `01-templates/CHANGELOG.md` so template evolution is traceable.

### How the three loops compose (the self-improving machine)

```
Loop A (weekly)     → surfaces anomalies, forecasts updated, spike PRDs created
    ↓ evidence
Loop B (triggered)  → portfolio re-rank at affected nodes; Tier-2 promotes or parks
    ↓ evidence
Loop C (every N)    → template updates; next loops start smarter
    ↓ better templates
Next loops          → higher-quality PRDs, fewer wasted experiments, faster signal
```

Compound learning. This is the answer to "how do we build a self-improving machine."

---

## 7. Scheduling infrastructure

### Hard rule: never use `launchd` for recurring agents

`launchd` cron silently skips scheduled runs if the Mac is asleep at that moment. No make-up run. This is the wrong substrate for weekly pulses that *must eventually run*.

### Use Railway-queued triggers

- Reference: `~/Projects/claude-telegram-bridge/` — Railway dispatcher owns durable cron queue + Telegram bot connection. Mac agent polls Railway every ~10s and spawns `claude -p --resume <session-id>` per job.
- If the Mac is asleep/off at the scheduled moment, the job sits in the queue and runs when the Mac next polls.
- Registration via `/schedule` skill or `RemoteTrigger` tool.

See `~/.claude/projects/-Users-jimchabas-Projects-brush-quest/memory/reference_scheduling_infrastructure.md`.

### Idempotency (mandatory)

Every recurring agent must be idempotent. Because the Railway queue can deliver late (or twice if retried), the agent must detect "already ran this cadence" and no-op.

**Pulse idempotency check:** before writing, check whether `_pulse-YYYY-MM-DD.md` already exists for this ISO week. If yes → no-op + log. If no → run.

Similar pattern for Loop C (monthly) and experiment checks.

### Escalation via Telegram

Pulse anomalies, experiment kills, Loop B triggers, and escalation-valve fires all push through the same Telegram bridge (`tg send` / `tg ask`). Reaches Jim even when away from the Mac. Message format: one sentence + link to the relevant `_pulse-*.md` / `_synth-final.md` / `_escalation.md`.

### Recurring triggers registered

At minimum, register these Railway triggers during Phase 1:

| Trigger name | Cadence | Action | Idempotency key |
|---|---|---|---|
| `gtm-pulse-trunk` | Weekly (Mon 08:00 PT) | Run pulse at trunk | ISO week |
| `gtm-pulse-active-pillars` | Weekly (Mon 08:30 PT) | Run pulse at each active pillar branch | ISO week + node |
| `gtm-loop-b-check` | Daily (09:00 PT) | Check Loop B triggers; fire if hit | Day |
| `gtm-meta-eval` | On demand (fires when N=5 loops logged) | Run Loop C | Loop counter |

---

## 8. Implementation shape

### Claude Code skill at `.claude/skills/gtm-factory/`

Project-local skill (not yet a plugin). Built bespoke for Brush Quest; generic-layer extraction deferred (Phase 2).

**Subcommands:**

| Command | Purpose |
|---|---|
| `/gtm-factory new-loop <node-path> <question>` | Kick off a full loop at a node. Emits all loop artifacts + PRDs. |
| `/gtm-factory pulse <node-path>` | Run Loop A pulse manually at a node (also called by cron). |
| `/gtm-factory re-rank <node-path> [reason]` | Run Loop B partial re-synth at a node. |
| `/gtm-factory meta-eval` | Run Loop C template self-improvement. |
| `/gtm-factory run-experiment <EXP-id>` | Fire an experiment's executor agent for a cycle. |
| `/gtm-factory analyze-experiment <EXP-id>` | Fire the experiment-analyzer agent on a completed experiment. |
| `/gtm-factory status` | Emit a tree snapshot (all nodes, PRD statuses, experiments). |
| `/gtm-factory escalate <node-path>` | Write `_escalation.md` and ping Jim. |

### Agent roster (all dispatched via Agent tool)

| Agent | Subagent_type | Role |
|---|---|---|
| Lens agents L1–L5 | general-purpose | Research phase, per loop |
| Synth-1 agent | general-purpose | Combines L1–L5 |
| Evaluator agents E1–E3 | general-purpose (or specialized) | Evaluation phase |
| Synth-2 agent | general-purpose | Final plan at node |
| Pulse agent | general-purpose | Loop A |
| Re-rank agent | general-purpose | Loop B (Synth-2 with new evidence) |
| Meta-eval agent | general-purpose | Loop C |
| Experiment-analyzer agent | general-purpose | Declare winner on completed EXP |
| Executor agents | specialized per channel (instagram-agent, tiktok-agent, dentist-outreach-agent, etc.) | Run PRDs |

Executor agents are **where the agentic ecosystem grows over time**. Start with `instagram-executor-agent` for the validation pass; grow the roster as branches open.

### Directory layout

```
docs/gtm-v4/
  00-master-brief.md                     # current-state brief, refreshed each run
  00-directory-map.md                    # this file — shape docs for future sessions
  01-templates/
    lens-digital-native.md
    lens-bold-contrarian.md
    lens-frugal-scrappy.md
    lens-pattern-matching.md
    lens-first-principles.md
    evaluator-cfo.md
    evaluator-target-parent.md
    evaluator-solo-founder-agent.md
    prd-template.md
    experiment-template.md
    pulse-prompt.md
    synth-1-prompt.md
    synth-2-prompt.md
    meta-eval-prompt.md
    CHANGELOG.md                         # Loop C template evolution log
  02-decisions-log.md                    # cross-node decisions log; notes what from v3 is superseded/still-valid
  trunk/
    _research/
      L1-digital-native.md
      L2-bold-contrarian.md
      L3-frugal-scrappy.md
      L4-pattern-matching.md
      L5-first-principles.md
    _evals/
      E1-cfo.md
      E2-target-parent.md
      E3-solo-founder-agent.md
    _synth-v1.md
    _synth-final.md
    _status.yaml
    _pulse-YYYY-MM-DD.md                 # weekly
    _learnings.md
    _experiments/
      _registry.yaml
    marketing/
      _meta-prd.md                       # charter from trunk
      _research/
      _evals/
      _synth-final.md
      _status.yaml
      _pulse-*.md
      _learnings.md
      ugc/
        _meta-prd.md
        _synth-final.md
        instagram-reels/
          _meta-prd.md
          _synth-final.md                # Synth-2 always runs; at leaves this is brief
          prds/
            PRD-GTM-instagram-reels-001.md
          _experiments/
            _registry.yaml
            EXP-GTM-instagram-hook-001.md
          _data/
            posts.yaml                   # executor-written; pulse-readable
          _status.yaml
          _learnings.md
        tiktok/
        youtube-shorts/
        ugc-assets/
        ugc-tools/
      paid-ua/
      pr/
      aso/
    partnerships/
    plg/
    community/
```

### Machine-readable sidecars

Every node has `_status.yaml`. Every PRD has YAML front-matter. Every experiment has YAML front-matter + `_registry.yaml` at node level. Every `_data/*.yaml` is structured for programmatic read.

This is dashboard-prep. The dashboard (Phase 2) is a read layer over these files — no duplicate source of truth.

### `_status.yaml` example

```yaml
node: trunk/marketing/ugc/instagram-reels
depth: 4
created: 2026-04-22
last_loop_completed: 2026-04-23
last_pulse: 2026-05-06
active_prds: 2
completed_prds: 0
active_experiments: 1
learnings_count: 3
children: []
tier: 1                                 # this node's tier at its parent
open_escalations: 0
```

### Dashboard (Phase 2, deferred)

After the machine runs its first real loop and there is real data, we design a dashboard at `brushquest.app/GTM-dashboard`:

- Tree view with status badges per node (on-track / diverging / at-risk).
- PRD board filtered by status/tier/owner.
- Experiments panel (running / winners / kills).
- Pulse feed (latest pulses across subtrees, with anomalies highlighted).
- Learnings feed (cross-cutting patterns).
- Next actions queue (pulse recommendations, aggregated).

Design with the `frontend-design` skill. Reads only; no write-back (writes happen in the file tree, canonical).

---

## 9. Validation pass (C) — Instagram Reels, 50 installs in 14 days

**Goal of this pass:** prove the machinery works end-to-end on a narrow question before running the trunk loop. Catch template bugs, missing fields, broken gates, agent-prompt misses cheaply.

**Validation question:**

> *"Produce a complete set of agent-executable PRDs to get 50 qualified parent installs to Play Store internal testing in 14 days via organic Instagram Reels, and hand them to executor agents to run."*

**Why Instagram Reels (vs Reddit, vs FB groups):**
- Algorithmic distribution — cold accounts can reach parents without network effects.
- Tractable for an agentic pipeline (Meta Graph API, no admin approvals).
- Parents-of-young-kids are demonstrably on IG (L4 will confirm/deny with data).
- Single channel keeps validation scope clean.

**What validates the machine:**
- [ ] All 5 lens agents produce materially different outputs (not 5 versions of the same plan).
- [ ] Synth-1 produces a tiered portfolio, not a single-winner doc.
- [ ] All 3 evaluators surface distinct issues (if 2 overlap heavily, personas need tuning).
- [ ] Synth-2 produces a plan where every Tier-1/2 bet has a PRD stub or a child-loop question.
- [ ] Termination gate produces 1–3 PRDs that pass the §4 criteria.
- [ ] `instagram-executor-agent` (the first executor we'll build) can actually read a PRD and run at least one step without asking Jim.
- [ ] First pulse run 7 days later produces a useful anomaly report or confirmed-on-track.

**Validation is allowed to fail.** If the machinery has bugs, we find them here and fix templates/prompts before the trunk run. Budget: 1 full loop + 1 pulse cycle (~2 weeks wall-clock, but the loop itself runs in a day).

**Full-size loop (5 lens + 3 eval), not a lighter version.** Per user: "learn before optimize." Cheaper to run the real machine on a small question than to guess what a lighter version would reveal.

---

## 10. Trunk question (B) — the real first run

**Trunk question (after validation):**

> *"Reach 1,000 weekly-active kids brushing with Brush Quest by 2026-07-20 (90 days from today), via agentic GTM execution on a $1–2K launch budget, with Brush Quest live on Google Play (public) and iOS TestFlight / App Store by that date."*

**Why this framing:**
- **1,000 WAK (weekly-active kids brushing)** — real engagement metric, not install vanity. Implies roughly 2–3K total installs at typical kids-app activation rates.
- **90 days / 2026-07-20** — long enough for iOS launch + two channel-learning cycles; short enough to force focus.
- **$1–2K** — locks the portfolio to organic + micro-spend mix, which is honest about current constraints.
- **"Live on Play (public) + iOS live"** — forces sequencing around platform milestones already in flight (Play public release, Apple Business approval).
- **"Via agentic execution"** — the machine knows executor agents are the target consumer.

Jim may tune 1,000 up or down after seeing the trunk synth; keeping it aggressive forces the interesting tradeoffs.

**Expected trunk output:**
- Portfolio: Tier-1 pillars (likely 2–3 of marketing / partnerships / PLG), Tier-2 experiments, Tier-3 parked.
- For each Tier-1: `_meta-prd.md` (charter) + scheduled pillar-level loop.
- For each Tier-2: either an experiment spec directly, or a compact pillar loop.
- Budget allocation across pillars + experiments (default 70/20/10).
- Sequencing: which pillar loop runs first, what the trigger for the second is.

**After trunk:** deep-dive into Tier-1 pillar #1 (likely Marketing → UGC branch given early signal from validation). Produce pillar-level plan + meta-PRDs + start sub-branch loops.

---

## 11. Open questions + deferred

- **Generic-layer extraction for other apps** — DEFERRED. Build for Brush Quest first. After 5+ loops and validated templates, extract `01-templates/` + skill code into a plugin.
- **Dashboard implementation** — DEFERRED until first real loop runs. Design with `frontend-design` skill.
- **Lens tuning over time** — Loop C will surface whether any lens is consistently weak. Expect to iterate after 3–5 loops.
- **Executor-agent roster** — build lazily as branches open. Start with `instagram-executor-agent` for validation.
- **Cost budget per loop** — intentionally not capped upfront (user: "learn first, optimize after"). Instrument token spend per loop so we have data to set a cap later.
- **Cross-project entities** — surface any people, vendors, commitments into the knowledge graph as the machine runs (standard rule from `~/Projects/CLAUDE.md`).
- **Relationship with existing `/gtm-prep` skill and weekly GTM-prep Railway trigger (Wednesdays 8:43am PT)** — reconcile during implementation. Likely `/gtm-prep` becomes a thin alias for `gtm-factory pulse trunk` or retires. Decide in the implementation plan.

---

## Appendix A — Template stubs (to be filled in the implementation plan)

The implementation plan (next step) will flesh out:
- Full prompts for each lens agent (L1–L5).
- Full prompts for each evaluator persona (E1–E3).
- Full prompts for Synth-1, Synth-2, Pulse, Re-rank, Meta-eval.
- PRD template body guidelines (what goes in each section, length expectations, worked example).
- Experiment template with 2 worked examples.
- Railway trigger registration YAML.
- Skill implementation details (how subcommands orchestrate Agent calls, error handling, resumption after partial failures).

---

## Appendix B — Relationship to v3

The v3 engine (`docs/gtm-engine/`, 10,304 lines across v3 + rounds) stays on disk as historical reference. v4 re-grounds planning in:
- Current product state (live on Play internal testing; iOS scaffolded + in review).
- Current constraints (budget, COPPA, locked monetization model).
- New output shape (tree of executable PRDs instead of one narrative doc).

The trunk loop (§10) will ingest v3's synth outputs as one of the inputs to Lens L4 (pattern-matching) — "what did we previously conclude, and does current state invalidate any of it?" v3 is a source, not a spec.

`02-decisions-log.md` tracks which v3 decisions are carried forward vs superseded.

---

## Approval

- [x] Design approved by Jim during brainstorm 2026-04-20 (sections 1–11).
- [ ] Spec reviewed by Jim.
- [ ] Implementation plan written (next: `superpowers:writing-plans`).
- [ ] Validation pass (C) executed.
- [ ] Trunk loop (B) executed.

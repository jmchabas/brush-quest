# Memory Management System — Design Spec

**Date:** 2026-03-20
**Author:** Jim + Claude
**Status:** Draft
**Scope:** Cross-project memory architecture for all Jim's projects with Claude Code

---

## Problem Statement

Jim works with Claude Code across 5 projects (scaling to 20-30+). The current memory system is per-project, file-based, and hitting limits:
- MEMORY.md exceeds the 200-line auto-load cap (45 lines silently dropped)
- No cross-project awareness (LLC decisions don't inform Play Store timeline)
- No write gate (everything saved, nothing pruned)
- No tiered lifecycle (hot context mixed with historical changelogs)
- Shared patterns (accounting, code verification) duplicated across projects

## Vision

Claude Code as a life OS — persistent memory across all projects, capable of routing questions to the right context, remembering people and commitments, and answering "what should I work on next?" from any directory.

## Non-Goals (for v1)

- Temporal reminders / cron jobs (future work)
- Multi-machine sync (Jim works from one machine)
- Vector/semantic search (corpus too small to justify PostgreSQL + pgvector)
- Custom MCP server development (use existing tools)

---

## Architecture

### Three-Layer Hierarchy

Claude Code loads memory hierarchically by directory path. We exploit this:

```
Layer 1: GLOBAL          ~/.claude/CLAUDE.md
                         Loaded in every session, every project.
                         Contains: behavioral rules, quality gates, tool preferences.

Layer 2: CROSS-PROJECT   ~/Projects/ level
                         Loaded when in ~/Projects/ or any subdirectory.
                         Contains: project registry, routing rules, shared context,
                                   knowledge graph, people, business context.

Layer 3: PER-PROJECT     ~/Projects/<project>/ level
                         Loaded only in that project.
                         Contains: 4-tier memory (hot/warm/cold/cache).
```

When Jim is in `~/Projects/brush-quest/`, Claude gets all three layers.
When Jim is in `~/Projects/`, Claude gets layers 1 and 2 (cross-project brain).
When Jim is in `~/Downloads/` or elsewhere outside `~/Projects/`, only layer 1 loads. This is expected — cross-project orchestration requires being in the Projects tree.

### Two Mechanisms at Each Layer

Each layer has two parts that work together:

| Mechanism | Where it lives | What it does | Who writes it |
|-----------|---------------|--------------|---------------|
| **CLAUDE.md** | In the directory itself (e.g., `~/Projects/CLAUDE.md`) | Instructions — tells Claude *how to behave* | Jim (or Claude with Jim's approval) |
| **Auto-memory** | `~/.claude/projects/<path-encoded>/memory/` | Knowledge — what Claude *remembers* | Claude (via write gate) |

Both are loaded by Claude Code at session start. CLAUDE.md is the rulebook. Auto-memory is the notebook.

For the cross-project layer:
- `~/Projects/CLAUDE.md` = routing rules, tier definitions, hygiene rules
- `~/.claude/projects/-Users-jimchabas-Projects/memory/` = project registry, people, shared patterns, business context

### Version Control & Backup

- `~/Projects/CLAUDE.md` is NOT in a git repo. Back it up by keeping a copy in `~/.claude/` or a dedicated config repo.
- Knowledge graph (`~/.aim/memory.jsonl`) is a single JSONL file. Back up weekly via `cp ~/.aim/memory.jsonl ~/Projects/anemosgp-business/backups/` or rclone to Google Drive.
- Per-project auto-memory files are machine-local (not in git). They're rebuilt from conversation context if lost — this is acceptable because they're a cache of decisions already made, not the source of truth.

### Knowledge Graph (mcp-knowledge-graph)

A structured store for entities and relationships that span projects. Runs as an MCP server via `npx mcp-knowledge-graph`. Stores data in `~/.aim/memory.jsonl`.

**What goes in the graph vs. markdown:**
- **Graph:** Entities you'd search by name or type — people, projects, blockers, commitments, reusable patterns, decisions with cross-project impact.
- **Markdown:** Narrative context — *why* a decision was made, *how* a pattern works, the story behind a relationship.

**Rule of thumb:** If I'd query it ("who is Nicole?", "what blocks Play Store?"), it's a graph node. If I need the backstory, it's markdown.

---

## Layer 2: Cross-Project Design

### `~/Projects/CLAUDE.md`

Orchestration instructions that tell Claude how to behave at the Projects level:

1. **Routing Rules** — how to decide if a question is cross-project or project-specific:
   - Mentions a person → check knowledge graph for which projects they relate to
   - Mentions a pattern/workflow → cross-project (shared-patterns.md)
   - Mentions a specific feature or screen → route to that project
   - Ambiguous → ask Jim

2. **Memory Tier Definitions** — canonical definition of hot/warm/cold/cache (defined once, not per-project)

3. **Hygiene Rules** — write gate, size limits, staleness protocol (see Section: Hygiene)

4. **Project Registry Reference** — points to project-registry.md for the full table

**Draft routing rules (to be included in ~/Projects/CLAUDE.md):**

```markdown
## Routing

When Jim asks a question, determine scope before answering:

1. **Person mentioned** → search knowledge graph for that person's relationships.
   Route to the project(s) they're connected to. If multiple, summarize cross-project.
2. **Specific feature/screen/file** → route to the project that owns it.
   If unsure which project, check project-registry.md.
3. **Pattern or workflow** (accounting, deploy, code verification) →
   check shared-patterns.md first. If the pattern exists, answer from there.
   If project-specific, route to that project.
4. **Business/legal/financial** → read business-context.md.
   These almost always affect multiple projects.
5. **"What should I work on?"** → read project-registry.md for all project statuses,
   check knowledge graph for active blockers, prioritize by urgency.
6. **Ambiguous** → ask Jim which project this relates to. Don't guess.
```

### Cross-Project Memory Files

Location: `~/.claude/projects/-Users-jimchabas-Projects/memory/`

| File | Purpose | Size target |
|------|---------|-------------|
| `MEMORY.md` | Index — pointers to topic files only | ≤80 lines |
| `project-registry.md` | All projects: name, path, status, category, relationships | ~5 lines per project |
| `people.md` | Key people: name, role, which projects they touch, last contact | ~3 lines per person |
| `shared-patterns.md` | Reusable solutions: accounting workflow, code verification, deploy patterns | One section per pattern |
| `business-context.md` | LLC, financials, legal obligations — things affecting multiple projects | Updated as business evolves |

### Knowledge Graph Entity Types

| Type | Fields | Example |
|------|--------|---------|
| `Person` | name, role, contact, notes | Nicole — dental partnership contact |
| `Project` | name, status, path, category | Brush Quest — kids app, v7, Play Store prep |
| `Decision` | what, when, why, affects | "Go LLC org account" — affects brush-quest, alameda-t |
| `Pattern` | name, description, used_by | Accounting pipeline — used by brush-quest, alameda-t |
| `Commitment` | what, to_whom, by_when | "Follow up with Nicole by Thursday" |
| `Blocker` | what, blocks, blocked_by | D-U-N-S — blocks Play Store org account |
| `Lesson` | what, context, severity | "Don't stack visual effects — characters become invisible" |

### Knowledge Graph Relationship Types

`works_on`, `owns`, `blocks`, `depends_on`, `relates_to`, `uses_pattern`, `committed_to`, `learned_from`

### Knowledge Graph: Concrete Example

Creating a Person node with relationships using `mcp-knowledge-graph` tools:

```
# Create entity
create_entities([{
  name: "Nicole",
  entityType: "Person",
  observations: [
    "Dental partnership contact",
    "Met through Jim's dentist",
    "Interested in kids' dental apps for practice"
  ]
}])

# Create relationship
create_relations([{
  from: "Nicole",
  to: "Brush Quest",
  relationType: "relates_to"
}])

# Query later
search_nodes("Nicole")  →  returns entity + all relationships
search_nodes("Blocker") →  returns all blocker entities
```

The JSONL file (`~/.aim/memory.jsonl`) stores these as one JSON object per line. Human-readable, git-diffable, backed up with a simple `cp`.

### Graceful Degradation

If the knowledge graph MCP server is unavailable (not started, crashed, npx fails):
- Cross-project routing falls back to reading `project-registry.md` and `people.md` (markdown files)
- Entity queries return nothing — Claude should notice and tell Jim: "Knowledge graph isn't available. Falling back to markdown files."
- No data is lost — markdown files always contain the narrative context regardless of graph state
- The graph can be re-seeded from markdown files if `memory.jsonl` is lost

### Source of Truth

If the knowledge graph and a markdown file disagree (e.g., graph says "D-U-N-S: pending" but markdown says "D-U-N-S: obtained"):
- **Markdown wins.** Markdown files are updated by Claude during sessions with Jim's oversight. The graph is supplementary.
- When a contradiction is noticed, update the graph to match markdown, and flag it to Jim.

---

## Layer 3: Per-Project Memory Tiers

Every project follows the same four-tier structure.

### Tier 1: HOT (always loaded)

**File:** `MEMORY.md` in the project's memory directory
**Size limit:** ≤150 lines (hard cap)
**Loaded:** Every session (auto-loaded by Claude Code)

**Contains:**
- What this project is (2-3 lines)
- Current status (1 line)
- Active decisions — only unresolved ones
- Categorized pointers to warm files (one line each)

**Does NOT contain:**
- History, changelogs, git commit lists
- Detailed explanations
- Session notes
- Anything derivable from code or `git log`

### Tier 2: WARM (on-demand topic files)

**Directory:** Same memory directory as MEMORY.md
**Size limit:** ≤200 lines per file, ≤25 files total (Brush Quest currently has ~22 warm-eligible files after migration; 25 accommodates growth)
**Loaded:** When the conversation topic requires it

**File naming convention:**
- `feedback_<topic>.md` — behavioral corrections (permanent)
- `decision_<topic>.md` — why we chose X over Y (permanent)
- `architecture_<topic>.md` — how systems are built (updated when changed)
- `reference_<topic>.md` — where to find things (updated as resources move)
- `context_<topic>.md` — current work context (pruned when stale)
- `lesson_<topic>.md` — bugs, debugging lessons, patterns to avoid (permanent)
- `project_<topic>.md` — project-specific milestones, initiatives, system designs (updated or archived when complete)

**Each file has frontmatter:**
```markdown
---
name: <descriptive name>
description: <one-line — used for relevance matching>
type: <feedback|decision|architecture|reference|context|lesson|project>
last_verified: <date>
---
```

### Tier 3: COLD (archive)

**Directory:** `memory/archive/` subdirectory
**Size limit:** None (but add dates for annual purge consideration)
**Loaded:** Only when explicitly asked about history

**Naming convention:** Archived files keep their original name with a date prefix: `2026-03_changelog.md`, `2026-03_decision_auth_approach.md`. The date indicates when it was archived, not when it was created.

**Contains:**
- Shipped cycle summaries
- Old changelogs (Brush Quest's 496-line `changelog.md` gets split: last 3 sessions stay warm as `context_recent_changes.md`, rest archived as `2026-03_changelog_sessions_1-17.md`)
- Superseded decisions
- Completed initiative postmortems

### Tier 4: CACHE (session handoff)

**File:** `<project-root>/.remember/remember.md`
**Size limit:** ≤20 lines
**Loaded:** Start of next session
**Lifecycle:** Overwritten every session

**Contains:**
- What's done, what's not (files, commits, branches)
- What to pick up next
- Non-obvious gotchas or blockers

Uses the existing `remember` plugin. No changes needed.

---

## Hygiene System

### The Write Gate

Before saving to memory, apply this filter:

**SAVE if:**
- It changes Claude's future behavior (feedback, corrections, preferences)
- It records a decision and the *reasoning* that can't be derived from the diff
- It captures a lesson — the pattern that caused a bug, the misleading symptom, the "never do X because Y"
- It names a person, commitment, or relationship needed later
- It's a reusable pattern across projects
- Jim explicitly says "remember this"

**DON'T SAVE if:**
- It duplicates facts already in code, git history, or CLAUDE.md
- It records *what* was fixed (git has the diff) without capturing *the lesson*
- It's session-specific progress (use cache tier / .remember)
- It's a "just in case" save with no clear future use

**Principle:** Don't duplicate facts that git or code already store. Do save lessons, patterns, and context that aren't obvious from reading the diff.

### Size Enforcement

| Tier | Scope | Limit | Action when exceeded |
|------|-------|-------|---------------------|
| HOT | Per-project MEMORY.md | 150 lines | Move content to warm or delete |
| HOT | Cross-project MEMORY.md | 80 lines | It's an index — tighten it |
| WARM | Any topic file | 200 lines | Split into multiple files or archive old sections |
| WARM | Total file count per project | 25 files | Archive or consolidate related files |
| COLD | archive/ directory | No limit | Add dates; consider annual purge |
| CACHE | .remember/remember.md | 20 lines | Overwritten each session anyway |

### Staleness Protocol

Session-count tracking is impractical (Claude Code has no session counter). Use time-based heuristics instead:

- Warm files with `last_verified` older than 30 days: print a one-line notice before responding to Jim's first message (e.g., "Note: `architecture_audio.md` hasn't been verified since Feb 15 — may be stale")
- `last_verified` is updated whenever Claude reads a warm file and confirms its content is still accurate (not deferred to end-of-session)
- Any memory referencing a specific file path, function, or flag: verify existence before acting on it
- Cross-project registry: reviewed whenever Jim starts a new project or completes a major milestone

### Promotion & Demotion

- **Warm → Hot:** If a warm file keeps being relevant across many sessions, add a summary line to the hot index (the file stays warm — the pointer promotes)
- **Hot → Warm:** If a hot index entry is about a completed initiative, remove it from the index (the warm file stays)
- **Warm → Cold:** If a warm file's `last_verified` is older than 90 days and it covers a completed initiative, archive it
- **Cold → Warm:** If Jim asks about historical context, promote the relevant archive file back to warm

### Session Boundaries

**Start of session:**
1. Hot tier loads automatically (Claude Code built-in)
2. Read `.remember/remember.md` for handoff context
3. If at `~/Projects/` level: scan project registry for urgent items
4. Check if any warm files have stale `last_verified` dates

**End of session (best-effort — Claude may not always do end-of-session cleanup unprompted):**
1. Write/update `.remember/remember.md` (handled by remember plugin)
2. If feedback was given, save to warm tier immediately (this should happen in-session, not deferred)
3. If MEMORY.md has grown past 150 lines, prune before closing
4. If a cross-project entity was discovered (person, pattern, blocker), update knowledge graph

Note: `last_verified` is updated when files are read mid-session, not at session end. This avoids the risk of end-of-session cleanup being skipped.

---

## Implementation Components

### 1. Install & configure mcp-knowledge-graph
- Add to Claude Code MCP settings (`~/.claude/settings.json`)
- Configure global storage at `~/.aim/memory.jsonl`
- Seed with initial entities from existing memory files

### 2. Create ~/Projects/CLAUDE.md
- Routing rules, tier definitions, hygiene rules
- Project registry reference

### 3. Build out cross-project memory
- Create `project-registry.md` from existing projects
- Create `people.md` from scattered references
- Create `shared-patterns.md` from duplicated patterns
- Create `business-context.md` from LLC/accounting files

### 4. Migrate Brush Quest memory to tiered structure
- Rewrite MEMORY.md as ≤150-line index (hot)
- Add `last_verified` frontmatter to all warm files
- Create `memory/archive/` and move cold content
- Fix stale data (test counts, cycle status)
- Verify `.remember/remember.md` is working (already is)

### 5. Migrate other project memories
- Apply same tier structure to alameda-t, anemosgp-business, change-app
- Consolidate duplicated LLC content

### 6. Update global CLAUDE.md
- Replace current auto-memory instructions with new tier system reference
- Point to ~/Projects/CLAUDE.md for full rules

### 7. Seed the knowledge graph
- Extract entities from existing memory files
- Create nodes for people, projects, blockers, patterns
- Create relationships between them

---

## Success Criteria

1. No MEMORY.md exceeds its size limit (150 lines project, 80 lines cross-project)
2. "What should I work on next?" returns a useful answer from `~/Projects/`
3. Cross-project entities (people, blockers, patterns) are queryable via knowledge graph
4. Feedback and lessons are never lost, always findable
5. System doesn't degrade — hygiene rules prevent the bloat that caused this redesign
6. New projects can be onboarded in <5 minutes (create memory dir, add to registry, done)

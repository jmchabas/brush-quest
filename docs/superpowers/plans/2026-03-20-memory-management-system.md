# Memory Management System — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a three-layer memory system with tiered per-project storage and cross-project knowledge graph, migrating all existing memory files to the new structure.

**Architecture:** Three-layer hierarchy (global → cross-project → per-project) using Claude Code's native directory-based memory loading. Per-project memory uses 4 tiers (hot/warm/cold/cache). Cross-project entities stored in mcp-knowledge-graph MCP server. All rules defined in ~/Projects/CLAUDE.md.

**Tech Stack:** Claude Code auto-memory, mcp-knowledge-graph (npx), markdown files, JSONL knowledge graph.

**Spec:** `docs/superpowers/specs/2026-03-20-memory-management-system-design.md`

---

## Task 1: Install and Configure mcp-knowledge-graph

**Files:**
- Modify: `~/.claude/settings.json`
- Create: `~/.aim/` directory (auto-created by MCP server)

- [ ] **Step 1: Add mcp-knowledge-graph to Claude Code MCP settings**

Add to `~/.claude/settings.json` under a new `mcpServers` key:

```json
{
  "mcpServers": {
    "knowledge-graph": {
      "command": "npx",
      "args": ["-y", "mcp-knowledge-graph"],
      "env": {
        "MEMORY_FILE_PATH": "/Users/jimchabas/.aim/memory.jsonl"
      }
    }
  }
}
```

The final merged `settings.json` should look like:

```json
{
  "enabledPlugins": {
    "frontend-design@claude-plugins-official": true,
    "superpowers@claude-plugins-official": true,
    "code-review@claude-plugins-official": true,
    "github@claude-plugins-official": true,
    "code-simplifier@claude-plugins-official": true,
    "playwright@claude-plugins-official": true,
    "claude-code-setup@claude-plugins-official": true,
    "remember@claude-plugins-official": true
  },
  "mcpServers": {
    "knowledge-graph": {
      "command": "npx",
      "args": ["-y", "mcp-knowledge-graph"],
      "env": {
        "MEMORY_FILE_PATH": "/Users/jimchabas/.aim/memory.jsonl"
      }
    }
  },
  "effortLevel": "high",
  "voiceEnabled": true,
  "skipDangerousModePermissionPrompt": true
}
```

- [ ] **Step 2: Create the .aim directory and empty JSONL file**

```bash
mkdir -p ~/.aim
touch ~/.aim/memory.jsonl
```

- [ ] **Step 3: Verify MCP server is available**

Restart Claude Code (or start a new session). Verify the knowledge graph tools are available by checking for `create_entities`, `search_nodes`, `open_nodes` in the tool list.

If `npx` isn't available or the package fails to install, run:
```bash
npm install -g mcp-knowledge-graph
```

- [ ] **Step 4: Commit checkpoint (if applicable)**

This is config outside the repo — no git commit needed. Note in `.remember/remember.md` that the MCP server is configured.

---

## Task 2: Create ~/Projects/CLAUDE.md (Cross-Project Orchestration)

**Files:**
- Create: `~/Projects/CLAUDE.md`

This file is the brain of the cross-project layer. It tells Claude how to route questions, manage memory tiers, and enforce hygiene rules.

- [ ] **Step 1: Write ~/Projects/CLAUDE.md**

Create the file with these sections (full content below):

```markdown
# Cross-Project Orchestration — Jim's Projects

## Identity

Jim is a solo founder building multiple projects. Claude Code is his operating system —
managing code, business, strategy, and coordination across all projects.

## Routing

When Jim asks a question, determine scope before answering:

1. **Person mentioned** — search knowledge graph for that person's relationships.
   Route to the project(s) they're connected to. If multiple, summarize cross-project.
2. **Specific feature/screen/file** — route to the project that owns it.
   If unsure which project, check project-registry.md.
3. **Pattern or workflow** (accounting, deploy, code verification) —
   check shared-patterns.md first. If the pattern exists, answer from there.
   If project-specific, route to that project.
4. **Business/legal/financial** — read business-context.md.
   These almost always affect multiple projects.
5. **"What should I work on?"** — read project-registry.md for all project statuses,
   check knowledge graph for active blockers, prioritize by urgency.
6. **Ambiguous** — ask Jim which project this relates to. Don't guess.

## Memory Tier System

Every project uses the same four-tier memory structure:

### HOT (always loaded, ≤150 lines)
- **File:** MEMORY.md in the project's auto-memory directory
- **Contains:** What the project IS, current status, active decisions, pointers to warm files
- **Does NOT contain:** history, changelogs, session notes, anything derivable from code/git
- **Hard rule:** If it exceeds 150 lines, move content to warm or delete

### WARM (on-demand topic files, ≤200 lines each, ≤25 files)
- **Directory:** Same as MEMORY.md
- **Naming:** `feedback_`, `decision_`, `architecture_`, `reference_`, `context_`, `lesson_`, `project_`
- **Frontmatter required:**
  ```
  ---
  name: <descriptive name>
  description: <one-line for relevance matching>
  type: <feedback|decision|architecture|reference|context|lesson|project>
  last_verified: <YYYY-MM-DD>
  ---
  ```
- **Lifecycle:** Updated when things change. `last_verified` updated when Claude reads and confirms accuracy.

### COLD (archive, rarely accessed)
- **Directory:** `memory/archive/` subdirectory
- **Naming:** Date prefix: `YYYY-MM_original-name.md`
- **Contains:** Shipped cycle summaries, old changelogs, superseded decisions
- **Loaded:** Only when Jim explicitly asks about history

### CACHE (session handoff, overwritten each session)
- **File:** `<project-root>/.remember/remember.md`
- **Contains:** What's in progress, next steps, blockers (≤20 lines)

## Write Gate

Before saving to memory, apply this filter:

**SAVE if:**
- It changes Claude's future behavior (feedback, corrections, preferences)
- It records a decision and the reasoning that can't be derived from the diff
- It captures a lesson — the pattern that caused a bug, the misleading symptom, the "never do X"
- It names a person, commitment, or relationship needed later
- It's a reusable pattern across projects
- Jim explicitly says "remember this"

**DON'T SAVE if:**
- It duplicates facts already in code, git history, or CLAUDE.md
- It records what was fixed without capturing the lesson
- It's session-specific progress (use cache tier / .remember)
- It's a "just in case" save with no clear future use

**Principle:** Don't duplicate facts. Do save lessons, patterns, and context not obvious from the diff.

## Size Limits

| Tier | Limit | Action when exceeded |
|------|-------|---------------------|
| HOT (per-project MEMORY.md) | 150 lines | Move content to warm or delete |
| HOT (cross-project MEMORY.md) | 80 lines | Tighten — it's an index |
| WARM (per file) | 200 lines | Split or archive old sections |
| WARM (file count per project) | 25 files | Archive or consolidate |

## Staleness

- When reading a warm file, check: is this still true? If yes, update `last_verified`.
- If `last_verified` is older than 30 days, print a one-line notice before responding.
- Any memory referencing a file path or function: verify it exists before acting on it.

## Promotion & Demotion

- Warm file keeps being relevant → add summary pointer to hot index
- Hot index entry about completed work → remove from index (warm file stays)
- Warm file's `last_verified` older than 90 days + completed initiative → archive to cold
- Jim asks about history → promote relevant cold file back to warm

## Knowledge Graph

The `mcp-knowledge-graph` MCP server stores cross-project entities and relationships.

**Entity types:** Person, Project, Decision, Pattern, Commitment, Blocker, Lesson
**Relationships:** works_on, owns, blocks, depends_on, relates_to, uses_pattern, committed_to, learned_from

**Graph vs. markdown:** If you'd search by name/type, it's a graph node. If you need the story, it's markdown.
**Source of truth:** If graph and markdown disagree, markdown wins. Update graph to match.
**Graceful degradation:** If MCP server is unavailable, fall back to markdown files. Tell Jim.

## Session Boundaries

**Start:**
1. Hot tier loads automatically
2. Read .remember/remember.md for handoff
3. If at ~/Projects/ level: scan project registry for urgent items

**During session:**
- Update `last_verified` on warm files when read and confirmed accurate
- Save feedback to warm tier immediately when given (don't defer)

**End (best-effort):**
1. .remember plugin handles cache
2. Prune MEMORY.md if over 150 lines
3. Update knowledge graph with new cross-project entities

## Backup

- `~/Projects/CLAUDE.md`: not version-controlled. Keep a backup copy at `~/.claude/Projects-CLAUDE-backup.md`
- Knowledge graph (`~/.aim/memory.jsonl`): back up weekly via `cp ~/.aim/memory.jsonl ~/Projects/anemosgp-business/backups/`
```

- [ ] **Step 2: Create a backup copy**

```bash
cp ~/Projects/CLAUDE.md ~/.claude/Projects-CLAUDE-backup.md
```

- [ ] **Step 3: Verify loading**

Start a Claude Code session in `~/Projects/` and verify the CLAUDE.md instructions are loaded in the system context.

---

## Task 3: Build Cross-Project Memory Files

**Files:**
- Create: `~/.claude/projects/-Users-jimchabas-Projects/memory/MEMORY.md` (rewrite)
- Create: `~/.claude/projects/-Users-jimchabas-Projects/memory/project-registry.md`
- Create: `~/.claude/projects/-Users-jimchabas-Projects/memory/people.md`
- Create: `~/.claude/projects/-Users-jimchabas-Projects/memory/shared-patterns.md`
- Create: `~/.claude/projects/-Users-jimchabas-Projects/memory/business-context.md`
- Move: `~/.claude/projects/-Users-jimchabas-Projects/memory/user_profile.md` (keep, update)

- [ ] **Step 1: Rewrite cross-project MEMORY.md as concise index**

Read the existing file first, then replace with a ≤80 line index:

```markdown
# Cross-Project Memory Index

## Jim
- [user_profile.md](user_profile.md) — role, goals, dev environment, preferences

## Projects
- [project-registry.md](project-registry.md) — all active projects, status, relationships

## People & Business
- [people.md](people.md) — key people across all projects
- [business-context.md](business-context.md) — LLC, financials, legal obligations

## Shared Knowledge
- [shared-patterns.md](shared-patterns.md) — reusable solutions across projects
```

- [ ] **Step 2: Create project-registry.md**

Read each project's MEMORY.md and STATUS.md to extract current status. Create:

```markdown
---
name: Project Registry
description: All active projects with status, path, category, and relationships
type: reference
last_verified: 2026-03-20
---

## Active Projects

| Project | Path | Category | Status | Key Blocker |
|---------|------|----------|--------|-------------|
| Brush Quest | ~/Projects/brush-quest | Product (kids app) | v7 — Play Store prep | D-U-N-S → org account |
| AnemosGP Business | ~/Projects/anemosgp-business | Business ops | LLC approved, bank open | D-U-N-S application |
| Alameda_T | ~/Projects/Alameda_T | E-commerce (merch) | Active — Shopify + Printful | None |
| Change App | ~/Projects/Change-app | Product (utility) | Early/paused | None |
| Mercury | ~/Projects/Mercury | Business banking | Active — accounts open | None |

## Relationships

- **AnemosGP Business** owns the LLC that publishes **Brush Quest** and **Alameda_T**
- **Brush Quest** and **Alameda_T** both use the accounting pattern from **shared-patterns.md**
- **Mercury** provides banking for **AnemosGP Business**
- **D-U-N-S** blocker affects both **Brush Quest** (Play Store) and **AnemosGP Business** (org account)
```

Verify the project list by running `ls ~/Projects/` and checking each directory.

- [ ] **Step 3: Create people.md**

Extract people references from all existing memory files (search for names, roles, relationships):

```markdown
---
name: People
description: Key people across all projects — roles, relationships, which projects they touch
type: reference
last_verified: 2026-03-20
---

## Family (Primary Testers)
- **Oliver** (7) — Jim's son, primary tester, loves Shadow (hero), tall for age
- **Theo** (3) — Jim's son, secondary tester, loves Blaze (hero), tall for age

## Business
(Add people as they come up in conversations — this starts sparse and grows)
```

- [ ] **Step 4: Create shared-patterns.md**

Extract reusable patterns from across projects:

```markdown
---
name: Shared Patterns
description: Reusable solutions and workflows that apply across multiple projects
type: reference
last_verified: 2026-03-20
---

## Accounting Pipeline
- **Used by:** Brush Quest, Alameda_T, AnemosGP Business
- **Stack:** Mercury (banking) + QuickBooks Simple Start + receipt workflow
- **Pattern:** Scan Gmail for receipts → extract amounts → deduplicate by email ID → record in CSV/QuickBooks
- **Details:** See brush-quest memory `accounting_stack.md` for full workflow

## Google Drive Upload (rclone)
- **Used by:** All projects for file distribution
- **Command:** `rclone copy <local-path> "gdrive:Projects/<folder>/"`
- **Note:** Google Drive is NOT mounted via CloudStorage — always use rclone

## Code Quality Gates
- **Dart/Flutter:** `dart analyze` + `flutter test` + `semgrep` + `gitleaks`
- **General:** Run quality tools before reporting done (per global CLAUDE.md Way 3)

## Dev Cycle Framework
- **Used by:** Brush Quest (primary), extensible to other projects
- **Repo:** ~/Projects/dev-cycle (GitHub: jmchabas/dev-cycle, private)
- **Pattern:** 4-agent audit → plan → approve → implement → verify → ship
```

- [ ] **Step 5: Create business-context.md**

Consolidate LLC, financial, and legal context from brush-quest and anemosgp-business memories:

```markdown
---
name: Business Context
description: LLC status, financial picture, legal obligations affecting multiple projects
type: project
last_verified: 2026-03-20
---

## AnemosGP LLC
- **Status:** Approved (California), DBA Brush Quest (filing TBD)
- **EIN:** 41-5007192
- **Registered Agent:** Northwest Registered Agent (1 year prepaid)
- **Bank:** Mercury — checking account 2545, open and active
- **Accounting:** QuickBooks Simple Start (connected to Mercury TBD)

## Google Play Store
- **Personal dev account:** Suspended (abandoned — going org route)
- **Org account plan:** Need D-U-N-S number → register org account under AnemosGP LLC
- **D-U-N-S:** NOT STARTED — apply at dnb.com (next action)
- **Alternative distribution:** Amazon Appstore + direct APK via GitHub Releases

## Legal
- **Privacy policy:** COPPA 2025 + CCPA compliant, 10 sections, live at brushquest.app/privacy-policy.html
- **Contact phone:** (510) 214-6383
```

- [ ] **Step 6: Update user_profile.md**

Read the existing file, update with current information, add proper frontmatter:

```markdown
---
name: Jim's Profile
description: Jim's role, goals, technical background, development environment
type: user
last_verified: 2026-03-20
---
```

- [ ] **Step 7: Verify cross-project memory loads correctly**

Start a session in `~/Projects/` and verify:
- MEMORY.md index is under 80 lines
- All linked files exist and are readable
- The routing rules from `~/Projects/CLAUDE.md` are available

---

## Task 4: Migrate Brush Quest Memory to Tiered Structure

This is the largest task. Brush Quest has 33 memory files that need to be categorized into hot/warm/cold.

**Files:**
- Rewrite: `~/.claude/projects/-Users-jimchabas-Projects-brush-quest/memory/MEMORY.md`
- Create: `~/.claude/projects/-Users-jimchabas-Projects-brush-quest/memory/archive/` directory
- Move: Multiple files to archive
- Update: Frontmatter on all warm files

- [ ] **Step 1: Create the archive directory**

```bash
mkdir -p ~/.claude/projects/-Users-jimchabas-Projects-brush-quest/memory/archive
```

- [ ] **Step 2: Move cold content to archive**

These files contain historical/completed content that should rarely be accessed:

```bash
MEMORY_DIR=~/.claude/projects/-Users-jimchabas-Projects-brush-quest/memory

# Archive the 496-line changelog (keep recent sessions as warm)
mv "$MEMORY_DIR/changelog.md" "$MEMORY_DIR/archive/2026-03_changelog_full.md"

# Archive completed initiative docs
mv "$MEMORY_DIR/project_victories.md" "$MEMORY_DIR/archive/2026-03_project_victories.md"
mv "$MEMORY_DIR/project_merch_assets.md" "$MEMORY_DIR/archive/2026-03_project_merch_assets.md"

# Archive the old todo (roadmap is better tracked in STATUS.md and STRATEGY.md)
mv "$MEMORY_DIR/todo.md" "$MEMORY_DIR/archive/2026-03_todo.md"
```

- [ ] **Step 3: Rename files to match naming convention**

```bash
MEMORY_DIR=~/.claude/projects/-Users-jimchabas-Projects-brush-quest/memory

# Rename to match convention
mv "$MEMORY_DIR/architecture.md" "$MEMORY_DIR/architecture_overview.md"
mv "$MEMORY_DIR/game-systems.md" "$MEMORY_DIR/architecture_game_systems.md"
mv "$MEMORY_DIR/build-notes.md" "$MEMORY_DIR/reference_build.md"
mv "$MEMORY_DIR/dev_cycle_framework.md" "$MEMORY_DIR/context_dev_cycle.md"
```

- [ ] **Step 3b: Handle cross-project overlaps**

These files have content that moved to cross-project memory. Replace with pointers:

- `llc_details.md` → replace content with pointer to cross-project `business-context.md`
- `accounting_stack.md` → replace content with pointer to cross-project `shared-patterns.md`

Example pointer file:
```markdown
---
name: LLC Details
description: Pointer — LLC details now in cross-project business-context.md
type: reference
last_verified: 2026-03-20
---
See cross-project memory: business-context.md (loaded at ~/Projects/ level)
```

- [ ] **Step 3c: Handle remaining files that aren't in the new index**

These existing files need explicit disposition:

| File | Action | Reason |
|------|--------|--------|
| `user_role.md` | Keep as warm, add to index under "User Context" | Permanent — Jim's goals/role |
| `user_family.md` | Keep as warm, add to index under "User Context" | Permanent — Oliver & Theo details |
| `feedback_playbook_ways.md` | Keep as warm, add to index under "Feedback" | Points to global CLAUDE.md ways |
| `feedback_voice_switch_latency.md` | Keep as warm, add to index under "Feedback" | Distinct from interrupt latency |
| `feedback_accounting_receipts.md` | Keep as warm, add to index under "Feedback" | Receipt handling rules |

- [ ] **Step 3d: Create files referenced in index that don't exist yet**

Some files are referenced in the current MEMORY.md but were never broken out. Check if they exist; if not, create them from content in the current MEMORY.md:

```bash
MEMORY_DIR=~/.claude/projects/-Users-jimchabas-Projects-brush-quest/memory

# Check which referenced files don't exist
for f in feedback_effect_overload.md project_cumulative_stars.md project_graphics_overhaul.md; do
  [ -f "$MEMORY_DIR/$f" ] && echo "EXISTS: $f" || echo "MISSING: $f"
done
```

For each MISSING file: extract the relevant content from the current MEMORY.md (before rewriting it) and create the file with proper frontmatter. If the content is too thin to justify a file, remove the reference from the proposed index instead.

`lesson_voice_arcs.md` — this is a NEW file. Create it from the voice arc lesson content in the current MEMORY.md (the "individual TTS clips sound robotic" lesson).

- [ ] **Step 4: Add frontmatter to all warm files**

For each remaining warm file that lacks frontmatter, add it. Example for `feedback_no_text_for_kids.md`:

```markdown
---
name: No text for kids
description: Kids can't read — use voice/icons instead of text in the app
type: feedback
last_verified: 2026-03-20
---
```

Read each file, determine its type from the naming convention, add frontmatter with today's date as `last_verified`.

- [ ] **Step 5: Create context_recent_changes.md**

Extract the last 3 sessions from the archived changelog into a warm context file:

```markdown
---
name: Recent Changes
description: Last 3 dev sessions — what changed, decisions made
type: context
last_verified: 2026-03-20
---

## Cycle 6 (2026-03-20)
30 findings across 9 streams. Onboarding comic strip, victory PopScope + voice-chained chest,
home nav gating, 4 new voice arcs, milestone voices, legendary badge, settings polish, world map beacon.
APK: 99MB, 651 tests.

## Privacy Policy (2026-03-20)
COPPA 2025 + CCPA overhaul, 10 sections, live at brushquest.app/privacy-policy.html.

## Cycle 5 (2026-03-18)
11 findings across 7 streams. APK: 98MB.
```

- [ ] **Step 6: Rewrite MEMORY.md as ≤150 line hot index**

Read ALL remaining warm files to build the pointer list. Write a new MEMORY.md:

```markdown
# Brush Quest — Memory Index

## What This Is
Kids' toothbrushing app (Android). Space Rangers vs Cavity Monsters. Flutter/Dart.
Solo founder: Jim. Primary testers: Oliver (7), Theo (3).

## Current Status
- **Phase:** v7 — Play Store submission prep (feature-complete)
- **Build:** 99MB APK, 651 tests, clean on `graphics-overhaul` branch
- **Blocked on:** D-U-N-S → Google Play org account
- **LLC:** AnemosGP LLC approved, EIN 41-5007192, Mercury bank open

## Active Decisions
- Distribution: Play Store (blocked) + Amazon Appstore + direct APK
- Buddy voice: BQ Buddy voice for new files (ElevenLabs quota hit — re-run generate_mentor_voices.py when quota resets)

## User Context
- [user_role.md](user_role.md) — Jim's goals: 1M users, $10M ARR, solo founder
- [user_family.md](user_family.md) — Oliver (7, Shadow) and Theo (3, Blaze) — primary testers

## Feedback (permanent behavioral rules)
- [feedback_no_text_for_kids.md](feedback_no_text_for_kids.md) — use voice/icons, not text
- [feedback_voice_quality.md](feedback_voice_quality.md) — picker voices must describe the character
- [feedback_test_before_ship.md](feedback_test_before_ship.md) — run analyze + tests + build before shipping
- [feedback_collaborate_before_diving.md](feedback_collaborate_before_diving.md) — discuss first when Jim says "let's work on it together"
- [feedback_verify_visual_work.md](feedback_verify_visual_work.md) — create visual verification for image processing
- [feedback_voice_interrupt_latency.md](feedback_voice_interrupt_latency.md) — detect PlayerState.stopped for fast interrupt
- [feedback_voice_switch_latency.md](feedback_voice_switch_latency.md) — voice switching latency fix
- [feedback_home_screen_clean.md](feedback_home_screen_clean.md) — no greeting text, brush count, or boss meter
- [feedback_shop_world_voice_behavior.md](feedback_shop_world_voice_behavior.md) — describe items on tap, no entry voices
- [feedback_voice_arcs.md](feedback_voice_arcs.md) — connected multi-beat arcs, not random pool picks
- [feedback_landing_page_review.md](feedback_landing_page_review.md) — parent CUJ + factual/visual review
- [feedback_effect_overload.md](feedback_effect_overload.md) — don't stack too many visual effects
- [feedback_playbook_ways.md](feedback_playbook_ways.md) — global playbook "ways" in ~/.claude/CLAUDE.md
- [feedback_accounting_receipts.md](feedback_accounting_receipts.md) — use real PDFs, Stripe URLs expire in 30 days

## Architecture & Systems
- [architecture_overview.md](architecture_overview.md) — file tree, screen flow, services
- [architecture_game_systems.md](architecture_game_systems.md) — heroes, worlds, progression, rewards

## Lessons
- [lesson_voice_arcs.md](lesson_voice_arcs.md) — individual TTS clips sound robotic; use connected arcs

## Project Initiatives (active)
- [project_play_store_plan.md](project_play_store_plan.md) — LLC org account path
- [project_go_to_market.md](project_go_to_market.md) — local-first GTM, distribution toolkit
- [project_email_capture.md](project_email_capture.md) — Buttondown, platform-aware forms, QR code
- [project_app_icon_v2.md](project_app_icon_v2.md) — 3D battle scene icon + favicon
- [project_graphics_overhaul.md](project_graphics_overhaul.md) — transparent PNGs, shaders, effects
- [project_cumulative_stars.md](project_cumulative_stars.md) — star economy thresholds

## References
- [reference_build.md](reference_build.md) — build commands, JDK 17, gotchas
- [reference_landing_page_deploy.md](reference_landing_page_deploy.md) — merge to main, push, DNS
- [reference_dashboard.md](reference_dashboard.md) — dashboard server, STATUS.md parsing
- [reference_hook_error.md](reference_hook_error.md) — dart analyze hook on non-.dart files (harmless)

## Context (current work)
- [context_recent_changes.md](context_recent_changes.md) — last 3 sessions
- [context_dev_cycle.md](context_dev_cycle.md) — dev cycle framework, agent structure

## Cross-Project (loaded at ~/Projects/ level)
- LLC details → business-context.md
- Accounting workflow → shared-patterns.md
- User profile → user_profile.md

## Archive
Historical content in `archive/` subdirectory. Only accessed when asking about past sessions.
```

Verify this is under 150 lines. Adjust by removing any pointers to files that don't exist.

- [ ] **Step 7: Verify file count and sizes**

```bash
MEMORY_DIR=~/.claude/projects/-Users-jimchabas-Projects-brush-quest/memory
echo "=== Warm files ==="
ls -la "$MEMORY_DIR"/*.md | wc -l    # Should be ≤25
wc -l "$MEMORY_DIR/MEMORY.md"        # Should be ≤150
echo "=== Archive files ==="
ls -la "$MEMORY_DIR/archive/"
```

- [ ] **Step 8: Fix stale data**

Search all warm files for "593 tests" and replace with "651 tests". Remove any references to stale git commit lists or session-by-session notes.

---

## Task 5: Migrate Other Project Memories

Apply the tiered structure to Alameda_T, AnemosGP Business, Change App, and Mercury.

**Files:**
- Modify: Memory files in each project's auto-memory directory
- Create: Archive directories where needed

- [ ] **Step 1: Migrate Alameda_T**

Path: `~/.claude/projects/-Users-jimchabas-Projects-Alameda_T/memory/`

Current state: 4 files (MEMORY.md at ~193 lines, design_learnings.md, pipeline_learnings.md, mercury_project.md).

Actions:
- Rewrite MEMORY.md as ≤150 line index with pointers
- Rename files to match convention: `lesson_design.md`, `lesson_pipeline.md`, `context_mercury_project.md`
- Add frontmatter to all files
- If MEMORY.md has historical content, move to `archive/`

- [ ] **Step 2: Migrate AnemosGP Business**

Path: `~/.claude/projects/-Users-jimchabas-Projects-anemosgp-business/memory/`

Current state: 5 files (MEMORY.md, project_llc_formation.md, feedback_resourcefulness.md, reference_brother_printer.md, reference_gdrive_rclone.md).

Actions:
- Rewrite MEMORY.md as ≤150 line index
- LLC formation details → moved to cross-project `business-context.md`. Replace with pointer.
- rclone reference → moved to cross-project `shared-patterns.md`. Replace with pointer.
- Add frontmatter to remaining files

- [ ] **Step 3: Migrate Change App**

Path: `~/.claude/projects/-Users-jimchabas-Projects-Change-app/memory/`

Current state: 1 file (MEMORY.md, ~5 lines — very minimal).

Actions:
- Add frontmatter if missing
- Already well under 150 lines — no trimming needed
- Add to project registry

- [ ] **Step 4: Create Mercury memory**

Path: `~/.claude/projects/-Users-jimchabas-Projects-Mercury/memory/`

Current state: No memory directory exists.

Actions:
```bash
mkdir -p ~/.claude/projects/-Users-jimchabas-Projects-Mercury/memory
```

Create minimal MEMORY.md:
```markdown
# Mercury — Memory Index

## What This Is
Mercury business banking integration for AnemosGP LLC.

## Current Status
- Checking account 2545 open and active
- QuickBooks connection TBD

## Cross-Project
- Banking details → business-context.md (cross-project level)
- Accounting workflow → shared-patterns.md (cross-project level)
```

- [ ] **Step 5: Verify all projects**

For each project, verify:
- MEMORY.md exists and is under 150 lines
- All warm files have frontmatter
- No file exceeds 200 lines
- Archive directory exists if cold content was moved

---

## Task 6: Update Global ~/.claude/CLAUDE.md

**Files:**
- Modify: `~/.claude/CLAUDE.md`

- [ ] **Step 1: Read current global CLAUDE.md**

Read `~/.claude/CLAUDE.md` to understand the current "3 Ways" structure.

- [ ] **Step 2: Replace the auto-memory instructions**

The current global CLAUDE.md has behavioral rules (the 3 Ways). These stay. But the auto-memory system instructions (which are injected by Claude Code itself into the system prompt) need to be overridden.

Add a new section to `~/.claude/CLAUDE.md` AFTER the existing 3 Ways:

```markdown
## Way 4: Memory Management

The memory tier system is defined in `~/Projects/CLAUDE.md`. Follow those rules for all memory operations.

Key overrides to default auto-memory behavior:
- Do NOT write memory content directly into MEMORY.md — it's an index with pointers only
- Do NOT save anything that fails the write gate (see ~/Projects/CLAUDE.md)
- MEMORY.md hard cap: 150 lines per project, 80 lines cross-project
- Always add frontmatter (name, description, type, last_verified) to new warm files
- When a warm file is read and confirmed accurate, update its last_verified date
- Cross-project entities (people, patterns, blockers) go in the knowledge graph, not markdown
```

- [ ] **Step 3: Verify the update**

Read back `~/.claude/CLAUDE.md` and confirm:
- The 3 Ways are preserved
- Way 4 is added
- No other content was lost

---

## Task 7: Seed the Knowledge Graph

**Files:**
- Modify: `~/.aim/memory.jsonl` (via MCP tools)

This task requires the MCP server to be running (Task 1 must be complete).

- [ ] **Step 1: Create Project entities**

Use the `create_entities` MCP tool to create nodes for each project:

```
create_entities([
  { name: "Brush Quest", entityType: "Project", observations: [
    "Kids toothbrushing app (Android)", "Flutter/Dart", "v7 — Play Store prep",
    "Path: ~/Projects/brush-quest", "Category: Product"
  ]},
  { name: "AnemosGP Business", entityType: "Project", observations: [
    "Business operations for AnemosGP LLC", "LLC formation, banking, accounting",
    "Path: ~/Projects/anemosgp-business", "Category: Business ops"
  ]},
  { name: "Alameda_T", entityType: "Project", observations: [
    "E-commerce merch automation", "Shopify + Printful",
    "Path: ~/Projects/Alameda_T", "Category: E-commerce"
  ]},
  { name: "Change App", entityType: "Project", observations: [
    "Utility app", "Early/paused",
    "Path: ~/Projects/Change-app", "Category: Product"
  ]},
  { name: "Mercury", entityType: "Project", observations: [
    "Business banking integration", "Mercury bank accounts",
    "Path: ~/Projects/Mercury", "Category: Business banking"
  ]}
])
```

- [ ] **Step 2: Create Person entities**

```
create_entities([
  { name: "Oliver", entityType: "Person", observations: [
    "Jim's son, age 7", "Primary tester for Brush Quest",
    "Loves Shadow (hero character)", "Tall for age"
  ]},
  { name: "Theo", entityType: "Person", observations: [
    "Jim's son, age 3", "Secondary tester for Brush Quest",
    "Loves Blaze (hero character)", "Tall for age"
  ]}
])
```

- [ ] **Step 3: Create Blocker entities**

```
create_entities([
  { name: "D-U-N-S Number", entityType: "Blocker", observations: [
    "Need to apply at dnb.com", "NOT STARTED as of 2026-03-20",
    "Required for Google Play organization account",
    "Blocks Play Store submission for Brush Quest"
  ]}
])
```

- [ ] **Step 4: Create Pattern entities**

```
create_entities([
  { name: "Accounting Pipeline", entityType: "Pattern", observations: [
    "Mercury + QuickBooks Simple Start + receipt workflow",
    "Scan Gmail → extract → deduplicate → record",
    "Used by Brush Quest, Alameda_T, AnemosGP Business"
  ]},
  { name: "Dev Cycle Framework", entityType: "Pattern", observations: [
    "4-agent audit framework",
    "Agents: UX Design Critic, Code Health, Voice & Audio, Kid Experience + Parent Trust",
    "Repo: ~/Projects/dev-cycle (private)",
    "Used by Brush Quest, extensible to other projects"
  ]}
])
```

- [ ] **Step 5: Create relationships**

```
create_relations([
  { from: "AnemosGP Business", to: "Brush Quest", relationType: "owns" },
  { from: "AnemosGP Business", to: "Alameda_T", relationType: "owns" },
  { from: "Mercury", to: "AnemosGP Business", relationType: "relates_to" },
  { from: "D-U-N-S Number", to: "Brush Quest", relationType: "blocks" },
  { from: "D-U-N-S Number", to: "AnemosGP Business", relationType: "blocks" },
  { from: "Oliver", to: "Brush Quest", relationType: "relates_to" },
  { from: "Theo", to: "Brush Quest", relationType: "relates_to" },
  { from: "Brush Quest", to: "Accounting Pipeline", relationType: "uses_pattern" },
  { from: "Alameda_T", to: "Accounting Pipeline", relationType: "uses_pattern" },
  { from: "Brush Quest", to: "Dev Cycle Framework", relationType: "uses_pattern" }
])
```

- [ ] **Step 6: Verify the graph**

```
search_nodes("Brush Quest")   # Should return entity with all relationships
search_nodes("Blocker")       # Should return D-U-N-S Number
read_graph()                  # Should show full graph structure
```

- [ ] **Step 7: Back up the graph**

```bash
mkdir -p ~/Projects/anemosgp-business/backups
cp ~/.aim/memory.jsonl ~/Projects/anemosgp-business/backups/memory-$(date +%Y%m%d).jsonl
```

---

## Task 8: Final Verification & Cleanup

- [ ] **Step 1: Verify the three-layer hierarchy**

Start a session in `~/Projects/brush-quest/` and verify:
- Global CLAUDE.md loads (check for "3 Ways" + "Way 4")
- Cross-project CLAUDE.md loads (check for routing rules)
- Brush Quest MEMORY.md loads (check it's the new ≤150 line version)
- Knowledge graph tools are available

- [ ] **Step 2: Verify cross-project routing**

From `~/Projects/`, test:
- "What projects am I working on?" → should read project-registry.md
- "What's blocking Brush Quest?" → should query knowledge graph for blockers
- "Tell me about the accounting workflow" → should read shared-patterns.md

- [ ] **Step 3: Verify per-project tiers**

From `~/Projects/brush-quest/`:
- MEMORY.md is under 150 lines
- All warm files have frontmatter with `last_verified`
- Archive directory has cold content
- `.remember/remember.md` exists (cache tier)

- [ ] **Step 4: Clean up orphaned references**

Check all MEMORY.md files for broken links (pointers to files that don't exist).
Check `docs/victories.html` for references to deleted `/accounting` command — these are historical and should stay.

- [ ] **Step 5: Update .remember/remember.md with final state**

Write the session handoff noting the migration is complete.

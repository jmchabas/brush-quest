# Cyclepro — Autonomous Development Cycle with Foundation Principles

**Date:** 2026-04-08
**Status:** Design approved, pending implementation

## Overview

Cyclepro is the next evolution of `/cycle`. It adds a Foundation Principles layer, a dedicated Principles Reviewer agent, automated fitness gates, an autonomous iteration mode, and principle-violation tracking across cycles.

Cyclepro runs everything `/cycle` does and more. Once validated, it replaces `/cycle` entirely.

## Foundation Principles

11 design philosophies that every agent evaluates against. These are lenses, not checklists — each one is a question an agent holds up to any screen.

| # | Principle |
|---|-----------|
| 1 | **A child who can't read uses every feature without help** |
| 2 | **There's always something exciting just out of reach** |
| 3 | **Every touch produces an immediate, satisfying response** |
| 4 | **Voice is how the app talks to the child** |
| 5 | **The app never makes the child feel bad** |
| 6 | **Parents trust it instantly — safe, honest, no tricks** |
| 7 | **Same patterns behave the same way everywhere** |
| 8 | **If it doesn't help the screen, it hurts it — every element earns its place** |
| 9 | **The child is the hero of a story, not a user completing tasks** |
| 10 | **The child feels in control — actions are chosen, never forced** |
| 11 | **What the child sees is what's real — no abstractions, no metaphors, no shorthand** |

These are documented in `docs/foundation-principles.md` and loaded by the Principles Reviewer agent.

### Origin

These principles were derived from:
- Jim's feedback across 10+ development cycles (recurring corrections that kept resurfacing)
- Nielsen Norman Group kids' UX research (literal-mindedness, touch targets, pre-reader design)
- Octalysis gamification framework (White Hat vs Black Hat drives)
- Self-Determination Theory (autonomy, competence, relatedness)
- Fogg Behavior Model (trigger→action simplicity)
- Hook Model (trigger→action→variable reward→investment)

## Modes

| Command | What it does |
|---------|-------------|
| `/cyclepro` | Full cycle — 9 agents (8 existing + Principles Reviewer), synthesizer, same PLAN→SHIP flow |
| `/cyclepro auto` | Autonomous Tier 1 cleanup (max 3 iterations), then surfaces findings |
| `/cyclepro auto max=N` | Auto mode with custom iteration cap |
| `/cyclepro quick` | Lightweight — 5 existing agents + Principles Reviewer, no emulator |
| `/cyclepro principles <screen>` | Principles Reviewer only against a specific screen file name, e.g. `home_screen` (fast check) |
| `/cyclepro ship` | No analysis — VERIFY + SHIP for already-implemented changes |
| `/cyclepro resume` | Load deferred findings from last cycle, jump to PLAN |

## Phases

Cyclepro uses the same 6-phase structure as `/cycle`. All existing phases carry over unchanged. Additions are noted below.

### Phase 0: CONTEXT (unchanged)

Reads STATUS.md, checks blockers, CI status, CodeRabbit findings, Crashlytics.

### Phase 1: ANALYZE

Everything from `/cycle` Phase 1, plus:

#### Agents: 9 + Synthesizer

The existing 8 agents are unchanged:

| # | Agent | Focus |
|---|-------|-------|
| 1 | UX Design Critic | Visual design, hierarchy, delight |
| 2 | Code Health | Audio safety, asset integrity, regressions, test gaps |
| 3 | Voice & Audio | Audio events, emotional arc, pacing |
| 4 | Economy Simulator | Day-by-day simulation, dead zones, price mismatches |
| 5 | Parent Trust + Kid Feedback | Settings UX, privacy, kid-feedback.md cross-reference |
| 6 | CUJ Evaluator | 6 journeys × 6 dimensions |
| 7 | State & Interaction Tracer | Tap inventory, purchase flow, dead-ends |
| 8 | Child's Eye Reviewer | 7-year-old perspective |

New agent:

| # | Agent | Focus |
|---|-------|-------|
| 9 | **Principles Reviewer** | All 11 principles × every screen |

#### Principles Reviewer — Detailed Spec

**Input:** Screenshots (both CUJs) + code for each screen.

**Process:** For each screen, evaluate all 11 principles:

| Principle | Evaluation method |
|-----------|------------------|
| P1: Can't read | Every Text widget — voice/icon alternative? Every nav path — discoverable without reading? |
| P2: Exciting just out of reach | Next unlock/reward/progression visible or teased? |
| P3: Every touch responds | Trace each interactive element: sound? animation? haptic? delay? |
| P4: Voice talks to child | For each screen state: what voice plays? Any silent dead zones? |
| P5: Never feels bad | Failure states, loss messaging, punishment visuals, negative sounds? |
| P6: Parents trust | Anything a parent would question? Data safety, honesty, hidden costs? |
| P7: Same patterns everywhere | Compare patterns (tap behavior, voice timing, nav, stat display) against other screens |
| P8: Every element earns its place | For each element: remove it — does screen get worse? If not, flag. |
| P9: Hero of a story | Narrative reinforcement? Child feels like Space Ranger or app user? |
| P10: Child in control | Forced actions? Undismissable auto-plays? Nags? Pressure? |
| P11: What you see is real | Icons literal? Numbers real data? Abstractions a child would misread? |

**Output:** Per-screen principle table (pass/flag/fail per principle), then cross-screen summary.

**Minimum findings:** 8 (at least 1 must be a cross-screen consistency issue).

**Key rule:** This agent identifies violations only. It does NOT propose code fixes. Fix proposals come from specialized agents or the implementation phase.

#### Synthesizer (enhanced)

Same as `/cycle` synthesizer, plus:
- Includes Principles Reviewer findings in the merged table
- Cross-references principle violations against cycle-history.md — a principle violated in consecutive cycles gets severity bumped
- Tags findings with which principle(s) they violate

### Phase 2: PLAN (unchanged)

Present findings ranked by impact. Jim selects which to implement. Group into parallel streams.

### Phase 3: IMPLEMENT (unchanged)

Execute approved streams. `dart analyze` on each edit, `flutter test` between streams.

### Phase 4: VERIFY (enhanced)

Existing gates carry over:

1. `dart analyze`
2. `dart run dart_code_linter:metrics analyze lib`
3. `flutter test` + test count regression guard
4. `flutter build apk` + APK size regression guard
5. `semgrep` / `gitleaks` (if installed)

New — **Hard Fitness Gates** (run after existing gates):

| # | Gate | Check | Method |
|---|------|-------|--------|
| 6 | Voice coverage | Every kid-facing screen has ≥1 voice path | Grep screens for `playVoice` calls. Kid-facing = all screens except `settings_screen.dart`. |
| 7 | Voice asset integrity | Every referenced audio file exists, non-zero bytes | Parse `playVoice`/`playSfx` args, verify in `assets/audio/` |
| 8 | Interactive feedback | Every `onTap`/`onPressed` triggers audio or haptic | Grep interactive widgets, check handlers |
| 9 | COPPA dependency scan | No non-allowlisted SDKs | Parse `pubspec.lock` against allowlist |
| 10 | Economy guard | Economy values unchanged in auto mode | Diff specific files against branch base |

All gates block shipping on failure.

### Phase 5: SHIP (unchanged)

Git diff review → APK upload → commit → push → optional Play Store deploy.

### Phase 6: LEARN (enhanced)

Everything from `/cycle` LEARN, plus **principle violation tracking**:

```markdown
## Cycle N — Principle Violations
| Principle | Screens | Status | Consecutive Cycles |
|-----------|---------|--------|--------------------|
| P2 | Home | Deferred | 3 ← CHRONIC |
| P7 | Shop, World Map | Fixed | 0 |
| P11 | Home | Deferred | 2 |
```

**Chronic escalation:** If a principle is violated for 3+ consecutive cycles and deferred each time, the synthesizer flags it as chronic in the next cycle. It appears at the top of findings with a note: "Violated for N cycles. Prioritize or accept as known limitation."

## Auto Mode (`/cyclepro auto`)

Autonomous Tier 1 iteration loop. Runs without human input, fixes what it can, surfaces the rest.

### Per-iteration flow

1. Run hard fitness gates → list violations
2. Run `dart analyze` → list warnings
3. Fix what's fixable:
   - Dart analyze warnings (unused imports, missing const, dead code)
   - Add `playSfx`/`HapticFeedback` to interactive handlers missing feedback
   - Fix broken asset references
   - Add test files for untested code paths
   - Voice references with missing files → add TODO comment + flag
4. Run `flutter test` → fix test failures
5. Run `flutter build apk` → verify build
6. Git commit on branch (`cyclepro/auto-N`)
7. Report iteration results

### Stopping conditions (first one wins)

- **Max iterations reached** (default 3)
- **Zero fixable violations remain**
- **Oscillation:** iteration N touches a file that iteration N-1 touched
- **Regression:** test count drops or APK size jumps unexpectedly → revert iteration, stop

### Scope boundaries

**CAN touch (Tier 1):**
- Dart analyze fixes
- Adding SFX/haptic to handlers missing feedback
- Adding tests for untested paths
- Fixing broken asset references

**CANNOT touch (Tier 2+3):**
- UI layout, colors, sizing, visual design
- Economy values (prices, earning rates, thresholds)
- Voice content (which file plays, what it says)
- Game logic (brushing, monsters, progression)
- Any feature addition

### Anti-gaming rules

- `// ignore` directives count as a finding, not a fix
- Deleting or weakening test assertions is forbidden
- Every fix must make the code strictly better, not just move a metric

### Output

```
Cyclepro Auto — 3 iterations on branch cyclepro/auto-1
├── Fixed: 14 dart analyze warnings, 2 missing SFX, 3 new tests
├── Fitness gates: 5/5 passing
├── Remaining: 4 findings need human judgment
│   ├── P2: No forward tease on home screen (Tier 3)
│   ├── P8: Rank pill vs wallet pill confusion (Tier 3)
│   ├── P11: Diamond icon abstract (Tier 3)
│   └── P7: Shop vs World Map voice divergence (Tier 2)
└── Ready for: /cyclepro (full 9-agent analysis on clean codebase)
```

### Integration with full cycle

Auto mode is designed to run FIRST as cleanup, then the full human-in-the-loop cycle runs on a clean codebase. Typical workflow:

1. `/cyclepro auto` — autonomous cleanup
2. Jim reviews auto output, merges branch
3. `/cyclepro` — full 9-agent analysis on clean code
4. Jim selects findings → IMPLEMENT → VERIFY → SHIP → LEARN

## File Locations

| What | Where |
|------|-------|
| Foundation Principles | `docs/foundation-principles.md` |
| Cyclepro skill definition | Superpowers skill (TBD during implementation) |
| Cycle history | `~/Projects/dev-cycle/projects/brush-quest/cycle-history.md` |
| Kid feedback | `~/Projects/dev-cycle/projects/brush-quest/kid-feedback.md` |
| COPPA allowlist | `docs/coppa-allowlist.txt` |
| Screenshots (temp) | `/tmp/cycle-screens/` |

## Relationship to `/cycle`

Cyclepro is a superset of `/cycle`. During the validation period, both coexist. Once cyclepro is proven reliable, `/cycle` is retired and `/cyclepro` becomes the standard development loop.

## Design Decisions

1. **Dedicated Principles Agent over injecting into existing agents** — guarantees coverage; principles are the agent's only job, so they never get diluted by competing analysis tasks.
2. **No composite "App Health Score"** — binary pass/fail for fitness gates + severity-ranked findings list. No averaging of incommensurable dimensions.
3. **Auto mode capped at 3 iterations** — prevents compounding error drift (at 85% accuracy per step, long chains degrade rapidly). Hard stop, not "iterate until plateau."
4. **Auto mode Tier 1 only** — respects existing autonomy tiers. Everything user-facing requires Jim's approval.
5. **Anti-gaming rules** — suppression comments and weakened assertions are explicitly forbidden. Prevents the metric-gaming failure mode documented in autonomous agent research.
6. **Chronic escalation in LEARN** — prevents deferred findings from silently accumulating across cycles without anyone noticing the pattern.

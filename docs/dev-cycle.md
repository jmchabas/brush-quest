# Dev Cycle — How `/cycle` Works

The dev cycle is a structured, human-in-the-loop development loop for Brush Quest. It audits the app from 8 perspectives, plans fixes with your approval, implements them, verifies quality, and ships.

## Modes

| Command | What it does |
|---------|-------------|
| `/cycle` or `/cycle audit` | Full cycle — emulator screenshots, 8 agents, synthesizer |
| `/cycle quick` | Lightweight — 5 agents, no emulator, same PLAN→SHIP flow |
| `/cycle ship` | No analysis — just VERIFY + SHIP for already-implemented changes |
| `/cycle visual` | Emulator screenshot walkthrough + visual audit only, no code changes |
| `/cycle resume` | Load deferred findings from last cycle, jump straight to PLAN |

---

## Full Cycle Phases

### Phase 0: CONTEXT

Reads STATUS.md and checks:
- Active blockers and decisions
- CI status (`gh run list --limit 3`)
- CodeRabbit review findings on open PRs
- Firebase Crashlytics crash clusters (if configured)

Produces a 2-3 line scope summary before anything else runs.

### Phase 1: ANALYZE

Three steps that feed into each other:

#### Step 1 — Build + Emulator

Builds the APK, boots the Android emulator, installs the app.

#### Step 1b — Screenshot Library

Takes screenshots of every screen across **two user journeys**, saved to `/tmp/cycle-screens/`:

- **CUJ 1 (New User):** Fresh install, 0 stars — onboarding → home → hero tap → world intro → brushing start → shop → world map → trophy wall → settings
- **CUJ 2 (Experienced User):** Day 7, 14 stars, streak 7 — seeded via SharedPreferences. Same screens plus victory sequence (star rain, chest, card reveal)

All agents read from this shared library. No agent touches the emulator directly.

#### Step 1c — SharedPreferences Pre-Gate

Mechanical diff: every key written in code vs. keys in the reset list. Missing keys become automatic High findings.

```bash
# Keys written but not in keysToReset → finding
grep -rn 'setString\|setInt\|setBool\|setStringList' lib/ | grep -oP "'[a-z_]+'" | sort -u > /tmp/cycle-prefs-written.txt
grep -A 200 'keysToReset' lib/screens/settings_screen.dart | grep -oP "'[a-z_]+'" | sort -u > /tmp/cycle-prefs-reset.txt
comm -23 /tmp/cycle-prefs-written.txt /tmp/cycle-prefs-reset.txt > /tmp/cycle-prefs-missing.txt
```

#### Step 2 — 8 Parallel Analysis Agents

| # | Agent | Focus | Input | Min Findings |
|---|-------|-------|-------|-------------|
| 1 | UX Design Critic | Visual design, hierarchy, delight, value clarity | Screenshots | 10-20 |
| 2 | Code Health | Audio safety, asset integrity, regressions, test gaps, negative space | Code only | 12 |
| 3 | Voice & Audio | Every audio event per screen, emotional arc, pacing, silence gaps | Screenshots + code | 8 |
| 4 | Economy Simulator | Day-by-day star simulation (Day 1→50), dead zones, price mismatches | Code only | 8 |
| 5 | Parent Trust + Kid Feedback | Settings UX, privacy, kid-feedback.md cross-reference | Code only | 6 |
| 6 | CUJ Evaluator | 6 journeys × 6 dimensions (state, navigation, pacing, hooks, failure, time) | Screenshots + code | 10 |
| 7 | State & Interaction Tracer | Tap inventory, purchase flow, dead-end detection, navigation graph | Code only | 8 |
| 8 | Child's Eye Reviewer | "I'm a 7-year-old who can't read" perspective | Screenshots + code | 12 |

Each agent ends with a **numbered findings table**:
```
| # | Severity | Screen/Area | Finding | Proposed Fix |
```

#### Step 3 — Synthesizer Agent

Merges all 8 outputs + pre-gate findings into one ranked table:
- Tags duplicates (multi-agent convergence bumps severity)
- Cross-validates economy findings between agents 4 and 7
- Cross-references kid-feedback.md (confirmed feedback bumps severity)
- Checks against cycle-history.md (re-reported finding = regression → High)
- Minimum: **25 findings** for full cycle

### Phase 2: PLAN

Presents findings ranked by impact. You choose which to implement:
> "Enter numbers, or 'all', or 'top N'"

Then groups approved findings into parallel implementation streams with file lists and dependencies. Asks for plan approval before proceeding.

### Phase 3: IMPLEMENT

Executes approved streams using parallel agents. Key rules:
- `dart analyze` runs automatically via hook on each edit
- `flutter test` runs between streams to catch regressions early
- Audio patterns are NEVER changed (verify only)
- Reports milestone status per stream completion

### Phase 4: VERIFY

Sequential quality gates — stop on first failure, fix, re-run:

1. `dart analyze` — static analysis
2. `dart run dart_code_linter:metrics analyze lib` — DCM lint rules
3. `flutter test` — all tests pass + test count regression guard
4. `flutter build apk` — release build + APK size regression guard
5. `semgrep` / `gitleaks` — security scanning (if installed)

Regression guards compare test count and APK size against the last cycle-history entry.

### Phase 5: SHIP

1. Shows `git diff --stat` for review
2. Uploads APK to Google Drive via `rclone`
3. Commits with explicit file staging (never `git add -A`)
4. Pushes only after separate confirmation
5. **Play Store deployment** via `/deploy` skill or after push:
   - Bumps version code in `pubspec.yaml` (e.g. `+5` → `+6`)
   - Runs quality gates (`dart analyze` + `flutter test`)
   - Builds release AAB (`flutter build appbundle --release`)
   - Writes fastlane changelog to `android/fastlane/metadata/android/en-US/changelogs/{version_code}.txt`
   - Uploads via `cd android && fastlane internal`
   - Note: `release_status: "draft"` in Fastfile because the app is still in draft state on Play Console. After upload, go to Play Console → Internal testing → Edit release → Next → Save and publish to make it available to testers.
   - Available to internal testers within ~1 hour of publishing

### Phase 6: LEARN

Records everything to `~/Projects/dev-cycle/projects/brush-quest/cycle-history.md`:
- All findings (approved + deferred)
- What was implemented, test count, APK size
- Three learning prompts: wrong assumption, what took longer, what to watch next
- Deferred findings carry forward to next cycle
- Updates STATUS.md and commits the dev-cycle repo

---

## Quick Cycle Differences

| Aspect | Full | Quick |
|--------|------|-------|
| Emulator | Yes — screenshots of all screens | No |
| Agents | 8 + synthesizer | 5 (code-only), no synthesizer |
| Min findings | 25 | 12 |
| Build during analysis | Yes (APK for emulator) | No (builds in VERIFY) |
| Phases 2-6 | Identical | Identical |

Quick cycle agents: Code Health, Voice & Audio Review, Diff Focus + Kid Feedback, Economy & State Consistency, Child's Eye Quick Review.

---

## Continuous Quality (Between Cycles)

These tools run automatically and feed INTO the next cycle's Phase 0:

| Tool | What it catches | How |
|------|----------------|-----|
| GitHub Actions CI | Build breaks, lint errors, test failures | Every push to main |
| CodeRabbit | Code review findings | Every PR |
| claude-code-action | PR review, @claude mentions | Every PR |
| Firebase Crashlytics | Production crashes | Automatic |
| DCM (dart_code_linter) | Widget perf, unused code, complexity | CI pipeline |

---

## Key Design Principles

- **Human-in-the-loop:** You approve findings AND the implementation plan before any code changes
- **Shared screenshot library:** All agents read from `/tmp/cycle-screens/` — no agent navigates the emulator independently
- **Pre-gates catch mechanical bugs:** SharedPreferences key diff runs before agents launch
- **Deferred findings persist:** Anything you skip carries forward and gets re-checked next cycle
- **Regression guards:** Test count and APK size are tracked cycle-over-cycle — drops are flagged
- **Audio safety:** Agents verify audio invariants but NEVER change audio patterns

---

## File Locations

| What | Where |
|------|-------|
| Cycle framework | `~/Projects/dev-cycle/framework/loop.md` |
| Project config | `~/Projects/dev-cycle/projects/brush-quest/config.md` |
| Cycle history | `~/Projects/dev-cycle/projects/brush-quest/cycle-history.md` |
| Kid feedback | `~/Projects/dev-cycle/projects/brush-quest/kid-feedback.md` |
| Screenshots (temp) | `/tmp/cycle-screens/` |
| PrefsGate output (temp) | `/tmp/cycle-prefs-*.txt` |

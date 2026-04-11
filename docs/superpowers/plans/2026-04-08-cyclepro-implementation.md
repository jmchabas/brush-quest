# Cyclepro Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the `/cyclepro` skill — an autonomous development cycle with 11 Foundation Principles, a Principles Reviewer agent, fitness gates, and auto mode.

**Architecture:** Cyclepro is a standalone skill file (`cyclepro.md`) that extends the existing `cycle.md`. It copies cycle.md as its base and adds: a 9th agent (Principles Reviewer), 5 fitness gates in VERIFY, an auto mode, principle-violation tracking in LEARN, and a `principles <screen>` quick-check mode. Supporting files: `docs/foundation-principles.md`, `docs/coppa-allowlist.txt`, `scripts/fitness-gates.sh`.

**Tech Stack:** Bash (fitness gates), Markdown (skill file, principles doc), Dart/Flutter (existing project tooling)

**Spec:** `docs/superpowers/specs/2026-04-08-cyclepro-design.md`

---

### Task 1: Create Foundation Principles Document

**Files:**
- Create: `docs/foundation-principles.md`

This is the reference document that the Principles Reviewer agent loads. It defines each principle with a one-line description and the evaluation lens.

- [ ] **Step 1: Create the principles document**

```markdown
# Brush Quest — Foundation Principles

11 design philosophies. Each is a lens an agent holds up to any screen and asks: "does this pass?"

These principles were derived from user feedback across 10+ development cycles, Nielsen Norman Group kids' UX research, Octalysis gamification framework, Self-Determination Theory, Fogg Behavior Model, and the Hook Model.

## The Principles

### P1: A child who can't read uses every feature without help

**Lens:** Walk the screen as a 6-year-old who cannot read a single word. Every Text widget — is there a voice or icon that communicates the same thing? Every navigation path — discoverable through visuals and sound alone? Every important state change — announced by voice?

### P2: There's always something exciting just out of reach

**Lens:** On this screen, can the child SEE what they're working toward? Is the next unlock, next reward, or next progression step visible or teased? If the child has nothing to want, the screen fails this principle. The economy should always have forward momentum.

### P3: Every touch produces an immediate, satisfying response

**Lens:** Trace each interactive element. On tap: does it produce sound? Animation? Haptic feedback? All three? Is there any perceptible delay between tap and response? A child who taps and gets silence assumes the app is broken.

### P4: Voice is how the app talks to the child

**Lens:** For each state this screen can be in: what voice plays? Are there silent states where the child is left without guidance? Does the voice tell the child what to DO next, or just narrate? Voice should guide action, not just acknowledge presence.

### P5: The app never makes the child feel bad

**Lens:** Check every "negative" state: streak broken, can't afford an item, lost a brushing session, made a mistake. How is it framed? Positive reframe ("New adventure!") or punishment ("You lost your streak")? Any negative sounds, red colors, or frowning icons? The emotional floor must always be safe.

### P6: Parents trust it instantly — safe, honest, no tricks

**Lens:** Would a skeptical parent, seeing this screen for the first time, feel comfortable handing the phone to their child? Any data collection beyond what's needed? Any dark patterns (nags, guilt, fake urgency)? Any claims that aren't true? Is parent access clearly available?

### P7: Same patterns behave the same way everywhere

**Lens:** Compare this screen's patterns against every other screen. Tap behavior: does tapping a locked item behave the same in the shop, world map, and trophy wall? Voice timing: do voices play at the same moments across similar screens? Navigation: are back/forward patterns consistent? Flag any divergence.

### P8: If it doesn't help the screen, it hurts it — every element earns its place

**Lens:** For each element on screen: mentally remove it. Does the screen get worse? If not, it shouldn't be there. A 6-year-old's attention is zero-sum — every element competes with every other element. Labels, decorations, stats, effects — each must earn its pixels.

### P9: The child is the hero of a story, not a user completing tasks

**Lens:** Does this screen make the child feel like a Space Ranger defending the galaxy, or like someone operating an app? Is the narrative present — character, world, mission? Is the language (voice, icons, animation) storytelling or UI? "Tap to brush" is an app instruction. "Let's fight the Cavity Monsters!" is a story.

### P10: The child feels in control — actions are chosen, never forced

**Lens:** Can the child walk away from this screen without feeling punished? Are there forced interactions (undismissable popups, mandatory tutorials, guilt-based prompts)? Does the child CHOOSE to engage, or are they pushed? Autonomy builds intrinsic motivation; pressure builds resentment.

### P11: What the child sees is what's real — no abstractions, no metaphors, no shorthand

**Lens:** Every icon: does it literally look like the thing it represents? A 6-year-old reads a hamburger icon as an actual hamburger. Every number: is it real tracked data, or derived/calculated? Every visual: would a child who takes everything at face value understand it correctly? Abstract symbols (diamonds for "rank", shields for "settings") fail this principle.
```

- [ ] **Step 2: Verify the file was created correctly**

Run: `head -5 docs/foundation-principles.md`
Expected: Shows the title and first line of the document.

- [ ] **Step 3: Commit**

```bash
git add docs/foundation-principles.md
git commit -m "docs: add 11 Foundation Principles for cyclepro agents"
```

---

### Task 2: Create COPPA Dependency Allowlist

**Files:**
- Create: `docs/coppa-allowlist.txt`

A list of known-safe Flutter dependencies for a kids' app. The fitness gate checks `pubspec.lock` against this list.

- [ ] **Step 1: Generate the allowlist from current dependencies**

Read `pubspec.yaml` to get all direct dependencies, then create the allowlist with annotations:

```txt
# COPPA-Safe Dependency Allowlist for Brush Quest
# Format: package_name  # reason
# Any dependency in pubspec.lock NOT on this list triggers a fitness gate failure.
#
# Last reviewed: 2026-04-08

# Core Flutter
flutter  # framework
flutter_test  # testing

# Direct dependencies (from pubspec.yaml)
audioplayers  # local audio playback, no network
shared_preferences  # local key-value storage, no network
google_fonts  # font loading (caches locally)
wakelock_plus  # screen wake lock, no data collection
camera  # local camera access, no upload
permission_handler  # permission requests, no data collection
firebase_core  # Firebase initialization (required for auth)
firebase_auth  # authentication only (parent-initiated)
cloud_firestore  # data sync (parent-initiated, user's own doc only)
google_sign_in  # authentication (parent-initiated)
path_provider  # local file paths, no network
collection  # Dart collections utility, no network
intl  # internationalization, no network

# Dev/build dependencies (not in release APK)
flutter_lints  # lint rules
dart_code_linter  # static analysis
flutter_launcher_icons  # build-time icon generation
integration_test  # testing

# Transitive dependencies that are safe
# (These come in via the direct deps above — no separate review needed,
# but if a NEW transitive dep appears that's not pulled by one of the
# above direct deps, investigate it.)

# BLOCKED packages (never add these):
# - google_mobile_ads  # behavioral advertising, COPPA violation
# - firebase_analytics  # child data collection without consent
# - facebook_sdk  # tracking
# - appsflyer  # attribution tracking
# - adjust  # attribution tracking
# - onesignal  # push notifications with user profiling
```

- [ ] **Step 2: Verify the file**

Run: `wc -l docs/coppa-allowlist.txt`
Expected: Shows line count (~40 lines).

- [ ] **Step 3: Commit**

```bash
git add docs/coppa-allowlist.txt
git commit -m "docs: add COPPA dependency allowlist for fitness gate"
```

---

### Task 3: Create Fitness Gates Script

**Files:**
- Create: `scripts/fitness-gates.sh`

5 automated checks that run during VERIFY. Each gate outputs PASS or FAIL with details.

- [ ] **Step 1: Write the fitness gates script**

```bash
#!/usr/bin/env bash
# Cyclepro Fitness Gates
# Run: bash scripts/fitness-gates.sh [--economy-guard]
# --economy-guard: also check economy values against branch base (auto mode only)
#
# Exit code: 0 if all gates pass, 1 if any gate fails.

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

PASS=0
FAIL=0
WARN=0

gate_pass() { echo -e "${GREEN}PASS${NC} — $1"; ((PASS++)); }
gate_fail() { echo -e "${RED}FAIL${NC} — $1"; ((FAIL++)); }
gate_warn() { echo -e "${YELLOW}WARN${NC} — $1"; ((WARN++)); }

echo "═══════════════════════════════════════"
echo "  Cyclepro Fitness Gates"
echo "═══════════════════════════════════════"
echo ""

# ─── Gate 1: Voice Coverage ───────────────────────────────────
# Every kid-facing screen must have at least one playVoice call.
# Kid-facing = all screens except settings_screen.dart
echo "▸ Gate 1: Voice Coverage"

SCREENS_DIR="lib/screens"
MISSING_VOICE=()

for screen in "$SCREENS_DIR"/*.dart; do
  basename=$(basename "$screen")
  # Skip non-kid-facing screens
  if [[ "$basename" == "settings_screen.dart" ]]; then
    continue
  fi
  if ! grep -q 'playVoice' "$screen"; then
    MISSING_VOICE+=("$basename")
  fi
done

if [ ${#MISSING_VOICE[@]} -eq 0 ]; then
  gate_pass "All kid-facing screens have voice coverage"
else
  gate_fail "Screens missing voice: ${MISSING_VOICE[*]}"
fi

# ─── Gate 2: Voice Asset Integrity ────────────────────────────
# Every audio file referenced in code must exist and be non-zero bytes.
echo "▸ Gate 2: Voice Asset Integrity"

MISSING_ASSETS=()
EMPTY_ASSETS=()

# Extract all quoted audio filenames from playVoice/playSfx calls
AUDIO_REFS=$(grep -roh "play\(Voice\|Sfx\)('[^']*'" lib/ | grep -o "'[^']*'" | tr -d "'" | sort -u)

for ref in $AUDIO_REFS; do
  # Voice files may be in a subdirectory (voices/buddy/, voices/classic/)
  # Check all possible locations
  found=false
  for path in "assets/audio/$ref" "assets/audio/voices/buddy/$ref" "assets/audio/voices/classic/$ref" "assets/audio/sfx/$ref"; do
    if [ -f "$path" ]; then
      found=true
      size=$(stat -f %z "$path" 2>/dev/null || stat -c %s "$path" 2>/dev/null)
      if [ "$size" -eq 0 ]; then
        EMPTY_ASSETS+=("$path")
      fi
      break
    fi
  done
  # Some refs include subdirectory already (e.g., 'voices/buddy/file.mp3')
  if [ "$found" = false ] && [ -f "assets/audio/$ref" ]; then
    found=true
  fi
  if [ "$found" = false ]; then
    MISSING_ASSETS+=("$ref")
  fi
done

if [ ${#MISSING_ASSETS[@]} -eq 0 ] && [ ${#EMPTY_ASSETS[@]} -eq 0 ]; then
  gate_pass "All referenced audio files exist and are non-empty"
else
  [ ${#MISSING_ASSETS[@]} -gt 0 ] && gate_fail "Missing audio files: ${MISSING_ASSETS[*]}"
  [ ${#EMPTY_ASSETS[@]} -gt 0 ] && gate_fail "Empty audio files: ${EMPTY_ASSETS[*]}"
fi

# ─── Gate 3: Interactive Feedback ─────────────────────────────
# Every onTap/onPressed handler should trigger audio or haptic feedback.
echo "▸ Gate 3: Interactive Feedback"

# Find all files with interactive handlers
INTERACTIVE_FILES=$(grep -rl 'onTap\|onPressed\|onTapDown\|onTapUp' lib/screens/ lib/widgets/ 2>/dev/null || true)
SILENT_HANDLERS=()

for file in $INTERACTIVE_FILES; do
  basename=$(basename "$file")
  # Skip settings (parent-facing)
  if [[ "$basename" == "settings_screen.dart" ]]; then
    continue
  fi
  # Count interactive handlers vs audio/haptic calls
  handler_count=$(grep -c 'onTap\|onPressed\|onTapDown\|onTapUp' "$file" || true)
  feedback_count=$(grep -c 'playSfx\|playVoice\|HapticFeedback' "$file" || true)
  # If there are handlers but zero feedback calls, flag it
  if [ "$handler_count" -gt 0 ] && [ "$feedback_count" -eq 0 ]; then
    SILENT_HANDLERS+=("$basename (${handler_count} handlers, 0 feedback)")
  fi
done

if [ ${#SILENT_HANDLERS[@]} -eq 0 ]; then
  gate_pass "All interactive files have audio/haptic feedback"
else
  gate_fail "Files with silent handlers: ${SILENT_HANDLERS[*]}"
fi

# ─── Gate 4: COPPA Dependency Scan ────────────────────────────
# Check pubspec.lock for packages not on the allowlist.
echo "▸ Gate 4: COPPA Dependency Scan"

ALLOWLIST="docs/coppa-allowlist.txt"
if [ ! -f "$ALLOWLIST" ]; then
  gate_warn "COPPA allowlist not found at $ALLOWLIST — skipping"
else
  # Extract package names from allowlist (ignore comments and blank lines)
  ALLOWED=$(grep -v '^#' "$ALLOWLIST" | grep -v '^$' | awk '{print $1}' | sort -u)

  # Extract direct dependency names from pubspec.yaml (more relevant than all transitive)
  DEPS=$(grep -E '^\s+\w+:' pubspec.yaml | grep -v '#' | awk '{print $1}' | tr -d ':' | sort -u)

  UNKNOWN_DEPS=()
  for dep in $DEPS; do
    if ! echo "$ALLOWED" | grep -qx "$dep"; then
      # Skip flutter SDK entries and dev_dependencies section markers
      if [[ "$dep" != "sdk" && "$dep" != "flutter" && "$dep" != "dev_dependencies" && "$dep" != "dependencies" ]]; then
        UNKNOWN_DEPS+=("$dep")
      fi
    fi
  done

  if [ ${#UNKNOWN_DEPS[@]} -eq 0 ]; then
    gate_pass "All dependencies on COPPA allowlist"
  else
    gate_fail "Dependencies not on allowlist (review for COPPA safety): ${UNKNOWN_DEPS[*]}"
  fi
fi

# ─── Gate 5: Economy Guard (auto mode only) ───────────────────
# Check that economy values haven't changed vs branch base.
if [[ "${1:-}" == "--economy-guard" ]]; then
  echo "▸ Gate 5: Economy Guard"

  ECONOMY_FILES=(
    "lib/services/hero_service.dart"
    "lib/services/weapon_service.dart"
    "lib/services/streak_service.dart"
    "lib/services/world_service.dart"
  )
  CHANGED_ECONOMY=()

  BASE_BRANCH=$(git merge-base HEAD main 2>/dev/null || echo "main")
  for efile in "${ECONOMY_FILES[@]}"; do
    if git diff "$BASE_BRANCH" --name-only | grep -q "$efile"; then
      # Check specifically for price/threshold changes
      if git diff "$BASE_BRANCH" -- "$efile" | grep -qE 'unlockAt|earnRate|starCost|bonusStars|dailyBonus'; then
        CHANGED_ECONOMY+=("$efile")
      fi
    fi
  done

  if [ ${#CHANGED_ECONOMY[@]} -eq 0 ]; then
    gate_pass "Economy values unchanged"
  else
    gate_fail "Economy values modified (requires manual approval): ${CHANGED_ECONOMY[*]}"
  fi
else
  echo "▸ Gate 5: Economy Guard — skipped (not auto mode)"
fi

# ─── Summary ──────────────────────────────────────────────────
echo ""
echo "═══════════════════════════════════════"
echo -e "  Results: ${GREEN}${PASS} passed${NC}, ${RED}${FAIL} failed${NC}, ${YELLOW}${WARN} warnings${NC}"
echo "═══════════════════════════════════════"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
```

- [ ] **Step 2: Make the script executable**

Run: `chmod +x scripts/fitness-gates.sh`

- [ ] **Step 3: Run the fitness gates against current codebase**

Run: `bash scripts/fitness-gates.sh`
Expected: All gates PASS (or flag known issues to investigate). This validates the script works before wiring it into the skill.

- [ ] **Step 4: Fix any issues found by the gates**

If gates fail on legitimate issues, fix them. If gates produce false positives, adjust the script logic. The gates must pass cleanly on the current codebase before proceeding.

- [ ] **Step 5: Commit**

```bash
git add scripts/fitness-gates.sh
git commit -m "feat: add cyclepro fitness gates script (5 automated checks)"
```

---

### Task 4: Create the Cyclepro Skill File

**Files:**
- Create: `/Users/jimchabas/Projects/dev-cycle/commands/cyclepro.md`
- Create: `/Users/jimchabas/Projects/brush-quest/.claude/commands/cyclepro.md` (symlink)

This is the main deliverable. The skill file is based on `cycle.md` (911 lines) with additions for:
- New argument routing (auto, principles modes)
- Principles Reviewer agent (Agent 9)
- Fitness gates in VERIFY
- Enhanced LEARN with principle tracking
- Auto mode section

The approach: copy `cycle.md` as the base, then apply targeted modifications.

- [ ] **Step 1: Copy cycle.md as the base**

```bash
cp ~/Projects/dev-cycle/commands/cycle.md ~/Projects/dev-cycle/commands/cyclepro.md
```

- [ ] **Step 2: Update the role statement (line 1)**

Replace the opening line:

Old:
```
You are running the **Dev Cycle** — a structured, human-in-the-loop development loop.
```

New:
```
You are running **Cyclepro** — an autonomous development cycle with Foundation Principles.

Cyclepro extends the Dev Cycle with 11 Foundation Principles, a dedicated Principles Reviewer agent, automated fitness gates, and an autonomous iteration mode.
```

- [ ] **Step 3: Add foundation-principles.md to Setup reads**

In the Setup section, add after the existing 6 reads:

```markdown
7. `docs/foundation-principles.md` — the 11 Foundation Principles (Principles Reviewer agent loads these)
```

- [ ] **Step 4: Update argument routing**

Replace the existing routing block with:

```markdown
## Route on arguments:

Parse `$ARGUMENTS`:
- **No args** or **`audit`** → Run the **full cycle** (all phases below)
- **`quick`** → Run the **QUICK CYCLE** (lightweight analysis, no emulator)
- **`ship`** → Skip to **VERIFY + SHIP** phases only
- **`visual`** → Run **VISUAL TEST** workflow only
- **`resume`** → Run **RESUME** (pick up deferred findings from last cycle)
- **`auto`** → Run **AUTO MODE** (autonomous Tier 1 iteration loop)
- **`auto max=N`** → Auto mode with custom iteration cap (default 3)
- **`principles <screen>`** → Run **PRINCIPLES CHECK** on a specific screen
```

- [ ] **Step 5: Add Agent 9 (Principles Reviewer) to the analysis agents section**

After the Agent 8 block and before the Synthesizer block, insert:

```markdown
---

**Agent 9 — Principles Reviewer (screenshots + code)**

You evaluate every screen against the 11 Foundation Principles. Read `docs/foundation-principles.md` first — it defines each principle and its evaluation lens.

**Your process:** For each screen in the app (read both CUJ 1 and CUJ 2 screenshots + screen code), apply ALL 11 principles:

| Principle | How to evaluate |
|-----------|----------------|
| P1: Can't read | Walk the screen as a 6-year-old who cannot read. Every Text widget — is there a voice/icon alternative? Every nav path — discoverable without reading? |
| P2: Exciting just out of reach | Is the next unlock/reward/progression visible or teased on this screen? |
| P3: Every touch responds | Trace each interactive element: sound? animation? haptic? any delay? |
| P4: Voice talks to child | For each screen state: what voice plays? Any silent states? Does voice guide the next action? |
| P5: Never feels bad | Failure states, loss messaging, punishment visuals, negative sounds — how are "bad" states framed? |
| P6: Parents trust | Anything a parent would question? Data safety, honesty, hidden costs? |
| P7: Same patterns everywhere | Compare this screen's tap behavior, voice timing, nav structure, stat display against OTHER screens. Flag divergences. |
| P8: Every element earns its place | For each element: remove it mentally — does screen get worse? If not, flag it. |
| P9: Hero of a story | Does this screen reinforce the Space Ranger narrative? Or feel like a generic app? |
| P10: Child in control | Forced actions? Undismissable auto-plays? Nags? Pressure? Could the child walk away without feeling punished? |
| P11: What you see is real | Every icon: literal representation? Every number: real tracked data? Any abstractions a child would misread? |

**Output format:** For each screen, produce a principle verdict table:

```
| Principle | Verdict | Finding (if not Pass) |
```

Verdicts: **Pass**, **Flag** (minor concern), **Fail** (clear violation).

After all per-screen tables, write a **Cross-Screen Summary** highlighting:
1. Which principles are consistently strong across all screens
2. Which principles are consistently violated
3. The single most impactful cross-screen issue (a pattern that breaks P7)

**Key rule:** You identify violations ONLY. Do NOT propose code fixes — that's other agents' job. State what's wrong and which principle it violates.

**Coverage requirement:** You MUST evaluate EVERY screen against ALL 11 principles. If you skip a screen or principle, explain why.

**Finding minimum:** 8 findings minimum (at least 1 must be a cross-screen consistency issue from P7).
```

- [ ] **Step 6: Update the synthesizer section**

Find the existing synthesizer description and add these bullets to its responsibilities:

```markdown
- Include Principles Reviewer (Agent 9) findings in the merged table
- Tag every finding with which Foundation Principle(s) it violates (e.g., `[P1, P4]`)
- Cross-reference principle violations against `cycle-history.md` — if the same principle was violated in the previous cycle and deferred, bump severity by one level
- After the main findings table, add a **Principle Health Summary**:
  ```
  | Principle | This Cycle | Previous Cycle | Status |
  ```
  Mark chronic violations (3+ consecutive cycles) at the top with a ⚠ prefix.
```

Also update the agent count references: change "8 agents" to "9 agents" and update the minimum findings from 25 to 28 (25 + 3 from the new agent's minimum cross-screen findings).

- [ ] **Step 7: Add fitness gates to VERIFY phase**

After the existing security scanning step in Phase 4 VERIFY (after the semgrep/gitleaks/dcm block), add:

```markdown
# 6. Cyclepro Fitness Gates
bash scripts/fitness-gates.sh
# In auto mode, add economy guard:
# bash scripts/fitness-gates.sh --economy-guard
```

- [ ] **Step 8: Enhance LEARN phase with principle tracking**

In Phase 6 LEARN, after the existing "Include:" list, add:

```markdown
- **Principle violation tracking:** Add a section to the cycle-history entry:
  ```markdown
  ### Principle Violations
  | Principle | Screens | Status | Consecutive Cycles |
  |-----------|---------|--------|--------------------|
  ```
  For each principle violated in this cycle:
  - Check the previous cycle entry's principle violations table
  - Increment "Consecutive Cycles" counter if the same principle was violated and deferred
  - If a principle reaches 3+ consecutive deferred cycles, mark it as **CHRONIC** — it must appear at the top of the next cycle's findings
```

Also update the learning prompts to add:

```markdown
- **Which Foundation Principles were violated this cycle, and why did agents miss them initially?**
```

- [ ] **Step 9: Add AUTO MODE section**

After the RESUME section (at the end of the file, before any closing), add the full auto mode:

```markdown
---

## AUTO MODE (`/cyclepro auto`)

Autonomous Tier 1 iteration loop. Fixes what it can without human input, surfaces the rest.

### Parse auto arguments

- Default: `max=3` (maximum 3 iterations)
- Custom: `/cyclepro auto max=5` for up to 5 iterations

### Per-iteration flow

**Iteration N:**

1. **Run fitness gates:**
   ```bash
   bash scripts/fitness-gates.sh --economy-guard
   ```
   Record which gates fail.

2. **Run dart analyze:**
   ```bash
   dart analyze
   ```
   Record warning count.

3. **Fix what's fixable (Tier 1 only):**
   - Dart analyze warnings: unused imports, missing const, dead code — fix directly
   - Interactive handlers missing feedback (Gate 3 failures): add `AudioService().playSfx('whoosh.mp3')` and `HapticFeedback.lightImpact()` to bare handlers
   - Broken asset references (Gate 2 failures): fix path if file exists elsewhere, or add `// TODO: missing audio file — needs generation` and flag
   - Missing test files: for screens with zero test coverage, generate a basic widget test following existing patterns in `test/screens/`
   
   **DO NOT touch:**
   - UI layout, colors, sizing, visual design
   - Economy values (prices, earning rates, thresholds, unlock costs)
   - Voice content (which file plays, what it says, voice line text)
   - Game logic (brushing flow, monster behavior, progression)
   - Any feature addition or user-facing behavior change

4. **Run tests:**
   ```bash
   flutter test
   ```
   If tests fail, fix the failures. If a fix requires Tier 2+ changes, revert and flag.

5. **Build:**
   ```bash
   export JAVA_HOME="/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home"
   export PATH="$JAVA_HOME/bin:$PATH"
   flutter build apk
   ```

6. **Commit iteration:**
   ```bash
   git add [specific changed files]
   git commit -m "cyclepro auto: iteration N — [summary of fixes]"
   ```

7. **Check stopping conditions:**
   - ✋ **Max iterations reached** → stop
   - ✋ **Zero fixable violations remain** → stop
   - ✋ **Oscillation:** this iteration modified a file that the previous iteration also modified → revert this iteration's commit and stop
   - ✋ **Regression:** test count dropped or APK grew >10% vs iteration start → revert this iteration's commit and stop
   - ✅ **Fixable violations remain and no stopping condition hit** → continue to iteration N+1

### Anti-gaming rules

Enforce these strictly:
- Adding `// ignore:` directives to suppress warnings counts as a **finding**, not a fix. The underlying issue must be fixed.
- Deleting or weakening test assertions is **forbidden**. If a test is wrong, fix the test to be correct, not weaker.
- Removing test files is **forbidden**.
- Every change must make the code strictly better. If unsure, flag it instead of changing it.

### Output when done

Present a summary:

```
Cyclepro Auto — N iterations on branch cyclepro/auto-[timestamp]
├── Fixed: [count] dart analyze warnings, [count] missing feedback handlers, [count] new tests
├── Fitness gates: [X/5] passing
├── Tests: [count] passing (was [count])
├── APK: [size] MB (was [size] MB)
├── Remaining: [count] findings need human judgment
│   ├── [list each with principle tag and tier]
│   └── ...
└── Recommended next: /cyclepro (full analysis on clean codebase)
```

---

## PRINCIPLES CHECK (`/cyclepro principles <screen>`)

Quick single-screen principles evaluation. No full cycle — just the Principles Reviewer agent against one screen.

### Step 1: Identify the screen

Parse `<screen>` argument. Match against files in `lib/screens/`:
- `home` or `home_screen` → `lib/screens/home_screen.dart`
- `brushing` or `brushing_screen` → `lib/screens/brushing_screen.dart`
- `victory` or `victory_screen` → `lib/screens/victory_screen.dart`
- etc.

If no match found, list available screens and ask.

### Step 2: Run Principles Reviewer

Read the screen file and run the Agent 9 (Principles Reviewer) prompt against it — code-only, no screenshots needed for this mode.

### Step 3: Present findings

Show the per-screen principle table:

```
| Principle | Verdict | Finding |
|-----------|---------|---------|
| P1: Can't read | Pass | — |
| P2: Exciting just out of reach | Fail | No forward tease... |
| ... | ... | ... |
```

No implementation — just the evaluation. Jim decides what to act on.
```

- [ ] **Step 10: Update Quick Cycle to include Principles Reviewer**

Find the Quick Cycle section. Add a 6th agent to the quick cycle agent list:

```markdown
**Agent F — Principles Quick Check (code only)**

Lightweight version of the full cycle's Principles Reviewer. Code reading only, no screenshots:
- Read each screen file in `lib/screens/` that was modified in the last 5 commits
- For each changed screen: evaluate all 11 principles from `docs/foundation-principles.md`
- Focus on principles most likely violated by code changes: P1 (text without voice), P3 (tap feedback), P7 (pattern consistency), P8 (element necessity)
- For unchanged screens, skip — the full cycle covers them

Minimum: 4 findings.
```

Update minimum findings for quick cycle from 12 to 15.

- [ ] **Step 11: Create symlink**

```bash
ln -sf ~/Projects/dev-cycle/commands/cyclepro.md ~/Projects/brush-quest/.claude/commands/cyclepro.md
```

- [ ] **Step 12: Verify symlink works**

Run: `ls -la ~/Projects/brush-quest/.claude/commands/cyclepro.md`
Expected: Shows symlink pointing to `~/Projects/dev-cycle/commands/cyclepro.md`

- [ ] **Step 13: Commit the skill file**

```bash
cd ~/Projects/dev-cycle
git add commands/cyclepro.md
git commit -m "feat: add cyclepro skill — cycle + principles + fitness gates + auto mode"
cd ~/Projects/brush-quest
git add .claude/commands/cyclepro.md
git commit -m "feat: symlink cyclepro skill"
```

---

### Task 5: Test Run — Principles Check Mode

**Files:**
- No new files — validation of Task 4

Run the simplest mode first to verify the skill works end-to-end.

- [ ] **Step 1: Run principles check on home screen**

Invoke: `/cyclepro principles home_screen`

Expected behavior:
- Reads `docs/foundation-principles.md`
- Reads `lib/screens/home_screen.dart`
- Produces a principle-by-principle verdict table
- Identifies known issues (P2: no forward tease, P11: diamond icon)

- [ ] **Step 2: Run principles check on victory screen**

Invoke: `/cyclepro principles victory_screen`

Expected: Similar table for the victory screen.

- [ ] **Step 3: Verify fitness gates run cleanly**

Run: `bash scripts/fitness-gates.sh`

Expected: All 4 non-economy gates pass (Gate 5 skipped without `--economy-guard`).

- [ ] **Step 4: Verify fitness gates catch real issues**

Temporarily break something and verify the gate catches it:

```bash
# Test Gate 2 — create a reference to a non-existent file
# (Don't commit this — just verify the gate catches it)
grep -n "playSfx" lib/screens/home_screen.dart | head -1
# Note the line, then check the gate would catch a bad reference
echo "TEST: manually verify Gate 2 would catch missing audio"
```

---

### Task 6: Update Memory and Documentation

**Files:**
- Modify: `/Users/jimchabas/.claude/projects/-Users-jimchabas-Projects-brush-quest/memory/project_cycle_plus.md`
- Modify: `docs/dev-cycle.md` (add reference to cyclepro)

- [ ] **Step 1: Create/update memory file for cyclepro**

Write to the project memory file referenced in MEMORY.md:

```markdown
---
name: Cyclepro Design
description: Autonomous dev cycle with 11 Foundation Principles, Principles Reviewer agent, fitness gates, auto mode
type: project
last_verified: 2026-04-08
---

## What It Is
Cyclepro = cycle + Foundation Principles + fitness gates + auto mode. Superset of /cycle.

## Key Components
- **11 Foundation Principles** in `docs/foundation-principles.md` — design lenses, not checklists
- **Principles Reviewer (Agent 9)** — evaluates every screen against all 11 principles
- **5 Fitness Gates** in `scripts/fitness-gates.sh` — voice coverage, asset integrity, interactive feedback, COPPA deps, economy guard
- **Auto mode** (`/cyclepro auto`) — Tier 1 autonomous fixes, max 3 iterations, surfaces rest for human
- **Principle violation tracking** in LEARN — chronic violations (3+ cycles) get escalated

## Design Decisions
- Dedicated agent for principles (not injected into existing agents) — guarantees coverage
- No composite health score — binary gates + severity-ranked findings
- Auto mode Tier 1 only — respects autonomy tiers
- Anti-gaming rules: no // ignore, no deleted tests, no weakened assertions

## Files
- Skill: `~/Projects/dev-cycle/commands/cyclepro.md` (symlinked to `.claude/commands/cyclepro.md`)
- Principles: `docs/foundation-principles.md`
- COPPA allowlist: `docs/coppa-allowlist.txt`
- Fitness gates: `scripts/fitness-gates.sh`
- Spec: `docs/superpowers/specs/2026-04-08-cyclepro-design.md`
```

- [ ] **Step 2: Add cyclepro reference to dev-cycle.md**

At the bottom of `docs/dev-cycle.md`, add:

```markdown
---

## Cyclepro (`/cyclepro`)

An evolution of `/cycle` with Foundation Principles, fitness gates, and auto mode. See `docs/superpowers/specs/2026-04-08-cyclepro-design.md` for the full design.

Cyclepro runs everything `/cycle` does plus:
- **11 Foundation Principles** evaluated by a dedicated Principles Reviewer agent
- **5 automated fitness gates** that block shipping
- **Auto mode** for autonomous Tier 1 cleanup
- **Principle violation tracking** across cycles
```

- [ ] **Step 3: Commit documentation**

```bash
git add docs/dev-cycle.md
git commit -m "docs: add cyclepro reference to dev-cycle.md"
```

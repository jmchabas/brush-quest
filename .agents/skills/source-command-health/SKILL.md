---
name: "source-command-health"
description: "Migrated source command `health`"
---

# source-command-health

Use this skill when the user asks to run the migrated source command `health`.

## Command Template

You are running the **Daily Health Check** — an autonomous build verification for Brush Quest.

## SCOPE: This is a READ-ONLY + TEST-ONLY check. You may NOT change any user-facing behavior, UI, economy values, or app logic.

## What you may fix autonomously (Tier 1):
- Dart analyze warnings/errors (lint fixes, type annotations, unused imports)
- Broken tests caused by test infrastructure (not app logic changes)
- Missing test coverage: you may ADD new tests for untested code paths

## What you may NOT do:
- Change ANY user-facing behavior, UI, economy values, unlock thresholds
- Modify audio, voice, onboarding, or visual elements
- Refactor app logic even if you think it's "better"
- Change economy/star/hero/weapon values

## Steps:

1. **Read context** (parallel):
   - `STATUS.md` — current status, blockers
   - `git log --oneline -5` — recent commits
   - `git status` — any uncommitted changes

2. **Run quality gates** (parallel):
   - `dart analyze` — static analysis
   - `flutter test` — all tests

3. **Evaluate results**:
   - If everything passes: update the `### HEALTH` section in STATUS.md with timestamp and "All clear — N tests passing, analyze clean"
   - If analyze has issues: fix if Tier 1 (lint/import fixes only), commit with message "fix: dart analyze [description]", re-run to verify
   - If tests fail: diagnose root cause. If it's a test infrastructure issue, fix and commit. If it's an app logic issue, log it in STATUS.md under HEALTH with details and do NOT attempt to fix

4. **Economy simulation** (read-only):
   - Read `lib/services/hero_service.dart` and `lib/services/weapon_service.dart`
   - Calculate: at 1.8 brushes/day, what's the unlock timeline? List each unlock and the day it occurs
   - Flag any gap > 5 consecutive days with no unlock
   - Report findings in STATUS.md HEALTH section (never change the values)

5. **Report** (always):
   - Print a summary: tests passed/failed, analyze clean/issues, economy gaps found, any fixes applied
   - If you made any commits, list them
   - End with: "Health check complete. No user-facing changes made."

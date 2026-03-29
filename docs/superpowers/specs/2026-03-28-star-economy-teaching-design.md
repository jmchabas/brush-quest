# Star Economy Teaching Design

**Date:** 2026-03-28
**Status:** Approved
**Goal:** Make the star/streak economy understandable to kids (through celebration) and parents (through text), driving retention behavior.

## Problem

The star economy has rich mechanics (streak bonuses, daily pair bonus, comeback bonus, wallet vs rank) but none of them are explained. Oliver races past the StarRain animation to tap the chest — bonus breakdowns play in a moment he ignores. The parent has no way to understand the system either, so can't nudge effectively.

## Design Principles

1. **Celebrate, don't lecture.** No tutorial screens. Teaching happens through amplified moments the child already pays attention to (the chest).
2. **Cause-and-effect in every voice line.** Say what the child DID to earn the bonus, not just label it. "You brushed your teeth 3 days in a row — bonus star!" not "Streak bonus!"
3. **Split audiences.** Oliver learns through voice + visuals. Parents learn through text in settings.
4. **Count up, never down.** Voice lines celebrate streaks, never threaten their loss. No streak anxiety.
5. **Comeback is warm.** Returning after a break feels welcoming, not guilt-inducing.

## Components

### Component A: Shop Nudge

**When:** Oliver can't afford a hero/weapon in the shop.
**Current:** Generic "You don't have enough stars yet. Keep brushing!"
**New:** Context-aware voice line based on Oliver's current state, naming the specific item he wants.

| State | Voice Script |
|-------|-------------|
| AM done, PM not yet | "Brush tonight too and you'll earn a bonus star! That gets you closer to [hero name]!" |
| Streak 1-2 (approaching 3-day) | "Keep brushing every day! Something special happens at 3 days!" |
| Streak 5-6 (approaching 7-day) | "Almost at 7 days! That means DOUBLE bonus stars every time you brush!" |
| Default | "Every brush earns you stars! You're getting closer to [hero name]!" |

**Files changed:** `hero_shop_screen.dart`
**New voice files:** 4 (~13 seconds total)
**Data needed:** Current streak from `StreakService`, today's slot status, target item name

### Component B: The Chest Teaches

**Insight:** Oliver's attention is on the chest, not the StarRain. Move bonus star teaching into the post-chest moment.

**Current flow:**
1. Victory SFX + confetti
2. Voice: "AWESOME!"
3. StarRain: base stars + bonus waves (with text labels Oliver can't read) ← **he's ignoring this**
4. Chest bounces in ← **his eyes are here**
5. Chest opens — random reward

**New flow:**
1. Victory SFX + confetti
2. Voice: "AWESOME! You earned 2 stars!"
3. StarRain: base stars only (simplified, no bonus waves)
4. Chest bounces in (slightly earlier)
5. Chest opens — random reward (same as before)
6. **NEW: Bonus reveal** — after chest reward settles, bonus stars burst FROM the chest one by one, each with a distinct visual identity and voiced cause-and-effect label

**Bonus types and their chest reveals:**

| Bonus | Visual | Voice (recurring) | Duration |
|-------|--------|-------------------|----------|
| Streak 3-6 | Fire-colored star with flame trail | "You brushed your teeth every day this week — bonus star!" | ~3s |
| Streak 7+ | Two blue-flame stars with electric trail | "More than a week of brushing every day — 2 extra stars! Keep going and you get the same bonus tomorrow!" | ~5s |
| Daily pair | Sun+moon merge, purple star | "Morning AND night — full power!" | ~2s |
| Comeback | Three green stars with shield effect | "Welcome back, Ranger! 3 bonus stars!" | ~2s |

**Files changed:** `victory_screen.dart`, `star_rain.dart` (or equivalent widget)
**New voice files:** 4 recurring clips (~12 seconds total)
**Key change:** Remove bonus waves from StarRain, add post-chest bonus reveal sequence

### Component C: First-Time Celebrations

**When:** The FIRST time each bonus type fires, play a longer, more excited voice line with bigger animations. After the first time, Component B's shorter recurring lines take over.

**Tracking:** 4 SharedPreferences booleans (`has_seen_first_streak_3`, `_7`, `_daily`, `_comeback`). Reset on "Reset all progress."

| First-Time Event | Visual Enhancement | Voice Script | ~Duration |
|-----------------|-------------------|-------------|-----------|
| Streak hits 3 | Chest glows orange, extra-large flame trail, screen flash | "WHOA! You brushed your teeth three days in a row! That's a STREAK! And streaks give you BONUS STARS every time! Keep it going!" | 5s |
| Streak hits 7 | Chest glows blue, electric sparks, two stars with lightning | "SEVEN DAYS! You're a streak CHAMPION! Now you get TWO bonus stars every time you brush! You're UNSTOPPABLE!" | 5s |
| Both AM+PM done | Chest glows purple, sun+moon orbit then merge | "You brushed this morning AND tonight! That's a full day of power! Here's a bonus star — try it again tomorrow!" | 4s |
| Comeback bonus | Chest glows green, shield effect, three stars burst together | "Hey, welcome back Space Ranger! It's been a while, but that's OK! Here are THREE bonus stars to get you going again!" | 4s |

**Files changed:** `victory_screen.dart`, `streak_service.dart` (flag management)
**New voice files:** 4 first-time clips (~18 seconds total)

### Component D: Parent Star Guide

**Where:** Settings screen, new "How Stars Work" section.
**Format:** Text-only, for parents who can read. Includes parenting tips for each bonus type.

**Content:**

- **Every brush:** Earns 2 stars
- **Streak Bonus (fire icon):** 3+ days in a row: +1 bonus star per brush. 7+ days: +2 bonus stars per brush. *Tip: "Brush tonight so you keep your streak going!"*
- **Daily Pair Bonus (sun+moon):** Brush morning AND evening: +1 bonus star. *Tip: "You already brushed this morning — brush tonight for a bonus star!"*
- **Comeback Bonus (green heart):** First brush after a break: +3 welcome-back stars. *Note: The app welcomes them back warmly. No guilt!*
- **Chest Rewards:** Random bonus after each brush (0-5 stars). Longer streaks give better odds!
- **Wallet vs Rank:** Wallet = spendable (goes down on purchase). Ranger Rank = lifetime total (never decreases).
- **Example day:** Morning brush (2 base + 1 streak = 3) + evening brush (2 base + 1 streak + 1 daily = 4) + chest rewards. Total: 7+ stars with a 3-day streak!

**Files changed:** `settings_screen.dart`
**New voice files:** 0 (text only)

## Voice File Summary

| File | Script | Trigger | ~Sec |
|------|--------|---------|------|
| **Component A — Shop Nudges** | | | |
| shop_nudge_tonight | "Brush tonight too and you'll earn a bonus star! That gets you closer to [hero]!" | AM done, PM not | 4 |
| shop_nudge_streak3 | "Keep brushing every day! Something special happens at 3 days!" | Streak 1-2 | 3 |
| shop_nudge_streak7 | "Almost at 7 days! That means DOUBLE bonus stars every time you brush!" | Streak 5-6 | 3 |
| shop_nudge_default | "Every brush earns you stars! You're getting closer to [hero]!" | Default | 3 |
| **Component B — Chest Reveals (recurring)** | | | |
| chest_streak_bonus | "You brushed your teeth every day this week — bonus star!" | Streak 3-6 | 3 |
| chest_mega_streak | "More than a week of brushing every day — 2 extra stars! Keep going and you get the same bonus tomorrow!" | Streak 7+ | 5 |
| chest_daily_pair | "Morning AND night — full power!" | Both slots done | 2 |
| chest_comeback | "Welcome back, Ranger! 3 bonus stars!" | After 2+ day gap | 2 |
| **Component C — First-Time Celebrations** | | | |
| first_streak_3 | "WHOA! You brushed your teeth three days in a row! That's a STREAK! And streaks give you BONUS STARS every time! Keep it going!" | Once (streak=3) | 5 |
| first_streak_7 | "SEVEN DAYS! You're a streak CHAMPION! Now you get TWO bonus stars every time you brush! You're UNSTOPPABLE!" | Once (streak=7) | 5 |
| first_daily_pair | "You brushed this morning AND tonight! That's a full day of power! Here's a bonus star — try it again tomorrow!" | Once (both slots) | 4 |
| first_comeback | "Hey, welcome back Space Ranger! It's been a while, but that's OK! Here are THREE bonus stars to get you going again!" | Once (comeback) | 4 |

**Total: 12 new voice files, ~44 seconds of audio**

## What NOT to Build

- **Tutorial/onboarding pages for the economy** — creates information overload and anticipatory streak anxiety
- **Home screen multiplier badge** — streak anxiety vector, violates "home screen clean" rule
- **Explicit numeric promises in kid voice lines** — never say "+1 star" with exact numbers in labels; use cause-and-effect language instead
- **Countdown language** — never "don't break your streak!", always "keep it going!"

## Implementation Priority

1. **Component D (Parent Star Guide)** — simplest, zero risk, text-only, lets Jim start nudging immediately
2. **Component B (Chest Teaches)** — highest impact, restructures victory screen bonus delivery
3. **Component C (First-Time Celebrations)** — builds on B, adds the memorable teaching moments
4. **Component A (Shop Nudge)** — independent of B/C, can be built in parallel

## Risks & Mitigations

| Risk | Mitigation |
|------|-----------|
| Victory screen timing breaks | Test each bonus type with Oliver before shipping |
| Voice line queue collision | Bonus reveals play sequentially after chest reward settles, not during |
| Streak anxiety | Voice lines count UP, never threaten loss. Comeback is warm. |
| Balance rigidity | Voice lines describe behavior ("you brushed X days"), not exact star amounts where possible |
| State tracking complexity | Only 4 SharedPreferences booleans, reset on progress reset |

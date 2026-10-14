# Brush flow (Hero → Weapon → World) and visible hooks — design

- **Date:** 2026-10-05 · **Status:** approved in conversation by Jim (all four parts), awaiting spec review
- **Target:** v1.1 (after v29 is live on both stores) · **Branch:** `feat/v1.1-brush-flow` (cut from `release/v29`)
- **User:** a 7-year-old who can't read. Every piece of information is a picture, an animation or a Buddy (George) voice line.

## 1. Why

1. The collection loop is hidden. Choosing a hero, a weapon and a world means visiting the shop and the world map from the bottom bar. Nothing before a brush shows what the child is saving for, even though kids do unlock heroes and weapons regularly (Android analytics).
2. The return hooks are invisible. "See you tonight" is a voice line with nothing on screen (`victory_screen.dart` `_showForwardHookSequence`). The daily streak bonus is added to the wallet silently on Home (`home_screen.dart` `_claimAndAnimateDailyBonus`). The child never sees a promise, or the payoff when he returns, so he never learns the link between the two.

**Success:** before every brush the child sees what he is brushing toward and how close he is. After every brush he sees the reward land and the next step promised. Starting a brush stays quick and can't become a bedtime stall. Measures: brushing retention at D7 and D14, and unlocks per child (Android GA4).

## 2. Decisions (Jim, 2026-10-05)

| # | Decision |
|---|---|
| D1 | Tapping the hero on Home still starts everything. Nothing is added to Home except the streak-pill change in D7. |
| D2 | Before brushing come three steps: **Hero → Weapon → World**. Each auto-advances after about 3 s. **Superseded 2026-10-13 (R2 in `2026-10-13-brush-steps-on-real-pages-design.md`):** a GO button, and the page moves on by itself after about 8 s without a touch. |
| D3 | On every step the child can switch to anything already unlocked in that category (heroes, weapons, worlds). |
| D4 | Each step shows the **closest next unlock**. On the hero step that is whichever is cheapest: the next upgrade (evolution) of the current hero or the next new hero. |
| D5 | When a goal is affordable, the child **unlocks it right after brushing**, on the victory screen, with one tap. **Amended 2026-10-13 (R3):** he can also unlock it during the steps, exactly as in the shop. |
| D6 | The very first brush after install skips the three steps, since there is nothing to choose yet. |
| D7 | Home changes only the streak pill: its flame grows in steps. There are no sun/moon slots on Home. |
| D8 | Hooks approach "A": make the existing rewards visible (growing flame, chest tiers, bonus stars that come out of the flame, goal fill). No economy change and no new screens. |
| D9 | Morning/evening is background, because many children brush once a day. The main hook is the daily streak flame. |
| D10 | The voice explains the flame and the bonus star as cause and effect ("you brushed every day → your flame grew → it gives you a star"). |
| D11 | A brush always adds world progress to the **furthest unfinished planet**, whichever world the child is playing in. |

Unchanged: prices, earning rules, existing saves, the hero portrait as the brush button, the bottom bar (shop, world map, trophies), the brushing screen itself.

## 3. Flow

```
Home ──tap hero──► [first-ever brush?] ──yes──► Brushing (with its world intro, as today) ──► Victory ──► Home
                          │no
                          ▼
                   Pre-brush: HERO (≈3 s) → WEAPON (≈3 s) → WORLD (≈3 s)
                          │
                          ▼
                   Brushing (world intro skipped, starts at the 3-2-1 countdown) ──► Victory ──► Home
```

**First-ever brush:** `total_brushes == 0`. **Failure rule:** if any data the pre-brush screen needs fails to load, it is skipped and brushing starts as today. Brushing is never blocked.

## 4. Pre-brush screen

> **Superseded 2026-10-13** by `2026-10-13-brush-steps-on-real-pages-design.md`: the steps are now the real Heroes & Weapons and Map pages in brush mode. This section is kept for history.

### 4.1 Layout (each step)
- **Center, big:** the item he will brush with, shown as a carousel of everything unlocked in that category. The current choice is centered; neighbours peek in from the sides. There are ‹ › arrows and swipe.
  - Hero: the selected hero at its selected evolution stage (same image as the shop).
  - Weapon: the selected weapon.
  - World: the selected world's planet.
- **Beside it, smaller:** the **closest next unlock** (§5) as a dark silhouette, generated in code from the existing image. Under it sits a **meter**:
  - stars, up to 10 needed: one slot per star, filled up to the wallet (e.g. ★★★★★☆☆☆);
  - stars, more than 10 needed: a bar with a star at its end, filled by wallet ÷ price;
  - worlds: rocket slots, one per mission of the furthest unfinished planet, filled with missions done.
- **Category complete:** the item gets a crown and there is no silhouette.
- **Locked items** sit at the end of the carousel as silhouettes with their meter. Tapping one plays the "need more" line (§4.3) and nothing else.

### 4.2 Timing
- Each step plays its voice (§4.3) on entry. It advances when the voice has finished **and** 3 s have passed, whichever is later, capped at 5 s.
- **Any touch** on the carousel pauses auto-advance and shows a big ✓. Changing the item plays that item's existing picker line (`voice_picker_hero_*`, `voice_picker_evo_*`, `voice_picker_weapon_*`, `voice_world_*`) and saves the choice through the existing services.
- After a touch, **4 s without touches** advances with the current choice. ✓ advances at once.
- Back or X returns to Home, as the brushing screen's exit does today.
- All delays are `Timer?` fields cancelled in `dispose()` (standing rule).

### 4.3 Voice per step (one voice at a time, through the existing queue)
- **Hero:** the selected hero's picker line (`voice_picker_evo_<hero>_stage<n>` when evolved, else `voice_picker_hero_<hero>`), then the progress clip for the hero goal: "Three more stars!" (§9), "Lots more stars to go!" (more than 10), or "You have them all!".
- **Weapon:** the same pattern with the weapon goal.
- **World:** `voice_world_<id>`, then "Two more brushes!" (§9), or "You have them all!" once the last planet is finished.
- **Locked tap:** heroes and weapons play `voice_need_stars.mp3`. Worlds play the new `voice_need_more_brushes.mp3`, replacing today's wrong "need stars" line for worlds.

## 5. Goal rules (pure code, unit tested)

- **Wallet** = spendable stars (`StreakService.getWallet`). Meters show the wallet against the price, so a meter can go down after a purchase in another category. That is accepted: it is a shared wallet.
- **Hero goal:** the candidates are the next evolution stage of the **selected** hero (if not fully evolved) and the cheapest locked hero. The goal is the cheaper of the two; on a tie, the evolution wins. If neither exists, the category is complete.
- **Weapon goal:** the cheapest locked weapon, or complete.
- **World goal:** the furthest unfinished planet (§8.4): `missionsRequired − progress` brushes left. Complete when all 10 are finished.
- **Overall goal (victory screen):** of the hero and weapon goals, the one with the fewest stars left; on a tie, the hero. Worlds are excluded, because they unlock by brushing.

## 6. Victory screen (new order)

1. Stars fly in, as today.
2. **Bonus stars come out of their source.** Streak bonus stars burst out of the flame. The morning-plus-evening bonus pops out with them as a small extra, with no emphasis. The comeback bonus works as today.
3. **Chest** (tap to open, as today), now drawn by streak tier: **wooden** under 3 days, **silver** 3–6, **gold** 7+. These are exactly the existing odds steps in `victory_screen.dart` `_rollChestReward`, so a fancier chest is honest.
4. **Goal fill:** the new stars fly into the overall goal's silhouette (§5).
   - If it fills: it glows and bounces, Buddy says "Tap to unlock it!", and one tap runs the existing shop purchase path (spend, then select the item), then a celebration with "It's yours! Great job, Ranger!". The new item is selected for the next brush.
   - If he doesn't tap before DONE, the item stays affordable and is offered again next time.
   - At most one unlock per victory.
5. Trophy reveal and world progress, as today. The world rockets fill toward the next planet.
6. **Flame hook strip:** the flame and its next step, drawn as small flame icons to fill (days left), e.g. "2 more days → bigger flame and silver chest". Buddy plays a flame line (§7.3).
7. DONE.

Steps 4 and 6 replace existing beats (the voice-only forward hook), so the screen grows by about 2–3 s on an unlock day and is roughly unchanged otherwise.

## 7. Streak flame

### 7.1 Steps
| Streak days | Flame | Chest | Bonus stars per brush (existing rule) |
|---|---|---|---|
| 1–2 | small, orange | wooden | 0 |
| 3–6 | big, orange | silver | +1 |
| 7–13 | super hot, blue | gold | +2 |
| 14+ | golden (visual only) | gold | +2 |

"Days to next step" = (3, 7 or 14) − streak. At 14+ there is no next step, and the strip shows the golden flame alone. The streak rules, grace day and comeback bonus are unchanged (`streak_service.dart`).

### 7.2 Home
- The **streak pill** shows the flame for the current step, plus the number. Nothing on Home pulses or bounces (Jim's permanent "no start affordance" rule).
- **Welcome-back payoff:** on the first open of the day with a streak of 3 or more, the existing daily bonus (`claimDailyBonus`, +1 or +2) visibly flies as stars from the flame into the star counter, with `star_chime.mp3`, while the welcome line plays (§7.3). This replaces the streak-teaching voices that follow the Home greeting (`voice_streak_teach_*`).
- **New step reached** on the last brush: a one-time flame "whoosh" on the next open, with "Your flame got bigger!". This needs one new prefs key, `last_seen_flame_tier`.
- **Streak broken:** the flame goes back to small. No sad animation and no voice.

### 7.3 Voice lines (Buddy/George, ElevenLabs)
| File | Plays when | Line |
|---|---|---|
| `voice_flame_grow.mp3` | victory; streak continued, same step | "You brushed again! Your flame keeps growing!" |
| `voice_flame_tier_3.mp3` | victory; just reached 3 days | "Three days of brushing in a row — your flame got bigger! A big flame gives you a bonus star every time you brush!" |
| `voice_flame_tier_7.mp3` | victory; just reached 7 days | "A whole week of brushing! Your flame is super hot — now it gives you two bonus stars!" |
| `voice_flame_tier_14.mp3` | victory; just reached 14 days | "Two weeks of brushing every day — you have the golden flame!" |
| `voice_flame_bonus_1.mp3` | victory; +1 bonus bursts from the flame (3–6) | "Your flame gave you a bonus star for brushing every day!" |
| `voice_flame_bonus_2.mp3` | victory; +2 bonus (7+) | "Your super flame gave you two bonus stars!" |
| `voice_flame_new.mp3` | victory; first brush after a break (streak 1, had a streak before) | "A new flame! Brush tomorrow to make it grow!" |
| `voice_flame_see_you_next.mp3` | victory closing; 1 day to the next step | "See you tomorrow! One more day for a bigger flame!" |
| `voice_flame_see_you_keep.mp3` | victory closing; 2+ days to the next step, or at 14+ | "See you tomorrow! Keep your flame growing!" |
| `voice_flame_welcome_1.mp3` | Home; daily bonus +1 | "Welcome back! You brush every day, so your flame gives you a star!" |
| `voice_flame_welcome_2.mp3` | Home; daily bonus +2 | "Welcome back! Your super flame gives you two stars!" |
| `voice_flame_got_bigger.mp3` | Home; new step since last open | "Your flame got bigger!" |

They replace `voice_first_streak_3`, `voice_first_streak_7`, `voice_chest_streak_bonus` (whose "every day this week" is wrong at 3 days) and `voice_chest_mega_streak`, plus the `voice_streak_teach_*` lines after the Home greeting.

**When they play on the victory screen:** exactly two flame lines per victory.
1. **At §6 step 2,** as the flame animates (and any bonus stars burst out of it), one line in this priority: tier-up (`_tier_3/_7/_14`), then bonus (`_bonus_1/_2`), then new (`_new`), then grow (`_grow`). The cause is spoken at the moment the effect is seen.
2. **At §6 step 6,** the closing line: `_see_you_next` or `_see_you_keep`.

**Twice-a-day children:** if this brush is a morning brush (before 12:00) and yesterday had both a morning and an evening brush, the closing line is the existing `voice_forward_tonight.mp3` instead of a flame closing line. In every other case the flame closing line plays.

## 8. Architecture

### 8.1 New units
| Unit | Purpose | Depends on |
|---|---|---|
| `lib/services/goal_service.dart` | `heroGoal()`, `weaponGoal()`, `worldGoal()`, `overallGoal()` → `Goal{item, price or missions, have, left, complete}` | Hero/Weapon/World/Streak services; logic in pure functions over plain data for tests |
| `lib/services/flame_tier.dart` | `flameTierFor(streak)`, `chestTierFor(streak)`, `daysToNextTier(streak)` | none (pure) |
| `lib/screens/pre_brush_screen.dart` | the three steps, timing, voice, then pushes `BrushingScreen(showWorldIntro: false)` | GoalService, services, AudioService |
| `lib/widgets/loadout_carousel.dart` | carousel of unlocked items + locked silhouettes, ‹ › and swipe | — |
| `lib/widgets/goal_meter.dart` | star slots / bar / rockets / crown | — |
| `lib/widgets/flame_pill.dart` | Home pill flame + number; victory hook strip variant | flame_tier |

### 8.2 Changed
- `home_screen.dart`: the hero tap launches `PreBrushScreen`, or `BrushingScreen` on the first-ever brush. The streak pill becomes `FlamePill`. The welcome-back payoff animation replaces the silent wallet bump. Streak-teach voices are swapped for flame lines.
- `brushing_screen.dart`: a `showWorldIntro` parameter (default `true`). `false` starts at the countdown. Analytics `logBrushSessionStart` gets the real `worldId`.
- `victory_screen.dart`: beats §6.2–6.6; the streak voice lines swap; the forward hook becomes the flame strip; the goal fill and unlock reuse the shop's purchase code.
- `world_service.dart`: `recordMission()` adds progress to the **furthest unfinished planet** (§8.4).
- `hero_shop_screen.dart` / services: extract the purchase-and-select step into a shared function used by both the shop and the victory unlock. Behaviour unchanged.

### 8.3 Data and saves
No migration. The only new prefs key is `last_seen_flame_tier`. Prices, earn rates and existing progress keys are untouched.

### 8.4 World progress rule
- `frontierWorld` = the first world, in order, that is unlocked and not completed. If every world is completed, there is none.
- `recordMission()` increments `world_progress_<frontierWorld>`. When that world completes, the current world becomes the next world in order. The child's selected (scenery) world doesn't change progress.
- Today's behaviour, where a revisited finished world absorbs the brush and the jump goes to the world after it, is removed.
- `isWorldUnlocked` is unchanged, so no saved world becomes locked again.

### 8.5 Error handling
Any exception while loading pre-brush data skips the steps and opens brushing directly. Asset or voice failures fall back silently, as the audio service already does. The unlock tap uses the existing purchase guards (no double spend).

## 9. Assets
- **Voice (about 37 clips, Buddy/George):**
  - the 12 flame lines in §7.3;
  - `voice_stars_left_1..10` ("One more star!" … "Ten more stars!") and `voice_stars_left_many` ("Lots more stars to go!");
  - `voice_brushes_left_1..10` ("One more brush!" … "Ten more brushes!");
  - `voice_tap_to_unlock` ("Tap to unlock it!");
  - `voice_unlocked_yours` ("It's yours! Great job, Ranger!");
  - `voice_have_them_all` ("You have them all!");
  - `voice_need_more_brushes` ("Keep brushing to reach this planet!").

  All are added to `test/audio/audio_assets_test.dart`.
- **Art:** 4 flame icons (small/big/blue/gold); silver and gold chest variants of the existing chest; a rocket icon (filled/empty); a crown. Silhouettes are code-tinted from existing hero, evolution, weapon and planet images.

## 10. Analytics (Android only; the iPhone build keeps no analytics)
`pre_brush_change {category}`, `pre_brush_skipped {reason: first_brush | error}`, `goal_unlocked {category, item, source: victory}`, `flame_tier_reached {tier}`.

## 11. Testing
- **Unit:** GoalService (ties, all owned, shared wallet, evolution vs new hero, world goal), flame_tier (boundaries 2/3, 6/7, 13/14), `recordMission` frontier rule (revisiting an old world, last world, all complete).
- **Widget:** pre-brush auto-advance (voice-end vs 3 s vs 5 s cap), pause on touch, 4 s idle, ✓, back to Home, first-brush skip, error skip, locked tap voices; victory beat order, unlock tap spends once and selects the item, no tap means it is offered again; Home flame pill steps, welcome payoff only once per day, tier-up whoosh once.
- **Audio timeline:** with `FakeAudioService`, no two voices overlap on the pre-brush screen, the victory screen or the Home greeting; SFX are suppressed during voice (existing rule).
- **Gates:** `dart format`, `dart analyze`, DCM, `flutter test`, semgrep, gitleaks; iOS Kids binary check on the IPA.
- **Real device:** Jim and Oliver play through brush 1 (no steps), brush 2 (steps), switching hero/weapon/world, an unlock on victory, and a streak day (Hard Block: physical test with a child).

## 12. Release
v1.1 after v29 is live on both stores: Play internal → Oliver test → 20% staged rollout → 100%; TestFlight → App Store. Changes in the v29 branch are merged into this branch before release.

## 13. Out of scope
Prices and earn rules; other Home elements; sun/moon slots; the sticker calendar; a hero "pet"; the bedtime reminder (separate approved v1.1 item); the world finale; the shared grown-up check (separate v1.1 item).

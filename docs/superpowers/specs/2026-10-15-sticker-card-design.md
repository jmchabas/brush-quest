# Sticker card, step fixes and brushing cleanup — design (v1.1 rework 2)

**Status:** direction approved by Jim in chat, 2026-10-15 (sticker card, gifts 5 and 20, prototype first, step and brushing changes). Amends `2026-10-05-brush-flow-and-hooks-design.md` (replaces its §6 steps 2, 3 and 6 and its §7 streak flame) and `2026-10-13-brush-steps-on-real-pages-design.md` (§4.3 entry lines and the way back). Everything else in those specs stands.

Three parts, built in this order:
- **Part A — steps and brushing screen** (§3). Approved; can start now.
- **Part B — the sticker card** (§4–§9). Its app code starts only after gate G1 (§10): Oliver understands the prototype.
- **Part C — the parent bedtime reminder.** Approved on 2026-09-28; ships in the same v1.1 work, specified in `2026-10-15-bedtime-reminder-design.md`. This spec only fixes what it says about the card (§4.7).

## 1. Why
Jim, testing build 41 with Oliver (7), 2026-10-15:
- The greeting on opening the app "disappeared extremely quickly", was "really hard to understand", and "there is no voice explaining why I'm getting extra stars". On day 2 it showed "🔥 2 ⭐" although no bonus exists before day 3.
- The flame strip under the chest is "very hard to understand … as an adult. It must be very hard as well for a child", and nothing says to come back tomorrow.
- "Nothing tells me that silver is not as good as gold."
- "Really think hard of the way we can drive repeat usage via this system of streak." **Oliver was lost too.**
- The steps don't say what to do ("select the hero that I want to use for brushing my teeth"), the Map step has no way back, and the three steps don't look alike.
- On the brushing screen he asked what the counter at the top and the signs under the timer are for.

The root cause: one habit, brushing every day, was rewarded in six places with six pictures (flame size, streak bonus stars, chest colour, welcome-back stars, comeback stars, Treasure Boost), and each was explained once, quickly, or not at all.

## 2. Decisions (Jim, 2026-10-15)

| # | Decision |
|---|---|
| S1 | A **sticker card** replaces the flame tiers, the streak bonus stars, the chest tiers, the welcome-back stars, the comeback bonus and the Treasure Boost chest star. It counts **brushing days**, not days in a row: a missed day costs nothing. |
| S2 | **Sticker 3 pays 5 stars; sticker 7 pays 20**, and the next brushing day starts a new card. |
| S3 | Every brush still pays **2 stars and one chest** (one look, the middle odds table). Morning plus evening pays **+2, once a day**. |
| S4 | **Prototype first:** no card code in the app until Oliver can say what the third sticker does (gate G1). The sticker look (space stickers or neon badges) is his pick. |
| S5 | The **bedtime reminder** ships in the same v1.1 work (Part C). |
| S6 | Steps: **one HEROES · WEAPONS · WORLD header** on all three steps; each step opens with **an instruction line**; the **back gesture goes to the previous step**; the X still goes Home. |
| S7 | Brushing screen: **remove the monster counter and the sign under the timer.** |

Unchanged: the hero tap as the only start; Home apart from the pill's content; shop prices; the goal fill and one-tap unlock; trophies, worlds and achievements; the 8 s idle advance and GO in the steps (Jim kept d1); the parent Pause and Dashboard. The streak counter and best streak are still recorded for the parent Dashboard, achievements and analytics, but no child-facing screen shows or rewards them.

This supersedes the March 2026 "no weekly goals" reasoning: today's silent grace day already keeps a streak alive for every-other-day brushing, and the card's line and the reminder both say "every day".

## 3. Part A — steps and brushing screen

### 3.1 One header for the three steps
- In brush mode, the coordinator (`PreBrushScreen`) draws one tab bar above the page: **HEROES · WEAPONS · WORLD**, each with its icon. The current step is highlighted.
- The Heroes & Weapons page hides its own HEROES/WEAPONS tab bar in brush mode; the Map gets the same header. The X stays at the top left.
- Tapping a tab goes to that step and plays its entry lines, as a tab tap does today.
- Pages opened from Home are unchanged (R6 of the 2026-10-13 spec).

### 3.2 What each step says first
| Step | Instruction line (new) | Then (existing) |
|---|---|---|
| Hero | "Pick the hero who'll brush with you!" | how far the glowing next unlock is ("Three more stars!", "Tap to unlock it!", "You have them all!") |
| Weapon | "Now pick your weapon!" | the same, for weapons |
| World | "Pick the world where you'll fight!" | brushes left to the next planet |

The current item's own description no longer plays on entry; it still plays when he taps an item. Each step's entry gets shorter (the descriptions ran up to 5 s).

### 3.3 Going back
- The back gesture goes to the previous step: World → Weapons → Heroes → Home.
- The X goes Home from any step.
- During "Let's fight!" the back gesture still goes Home (ruling 2 of the rebuilt steps stands).

### 3.4 Brushing screen
Remove the monster counter (the starburst and number at the top left, next to the mouth guide) and the phase sign under the timer (crossed swords, shield, hourglass, target). The mouth guide, the seconds and everything else stay.

## 4. Part B — the sticker card

### 4.1 The rule
Buddy says it in one sentence: **"Every day you brush, you get a sticker. Three stickers open the little gift. Seven open the big gift."**

- The **first finished brush of a calendar day** places one sticker. Later brushes that day place none.
- **Sticker 3** pays 5 stars. **Sticker 7** pays 20 and fills the card. The **next brushing day** starts a new card.
- Gift stars are credited **when the brush is recorded**, so an early DONE or a crash never loses them. The gift's animation plays on the victory screen; if it was never shown, the next greeting opens it.
- **Morning plus evening:** +2 once a day, on the brush that completes both slots (morning before noon, evening after, as today).
- **Chest:** one look and one odds table (today's 3–6 day table, about 1.55 stars on average) on every brush.
- **Missed days:** nothing changes, nothing is said, and there is no comeback bonus.

### 4.2 The card
- Seven spots in one row. Filled spots show the stickers in order; empty spots are dashed circles; the **next spot has a cyan ring**.
- A **small gift box** sits over spot 3 and a **big gift box** over spot 7. An opened gift shows its open box.
- Sizes: spots at least 40 px on a 360 dp phone. The card appears big (full width) in its moments and small (about 78%) in its closing place.
- Art: seven stickers in the look Oliver picks (G1), two gift boxes, closed and open. The prototype's art (`.remember/v1.1/sticker-proto/`, local) is the starting point.

### 4.3 App open, first time today: the greeting window
- Shows the card, no star symbols.
- Buddy: "Hi Ranger!" (or "Welcome back, Ranger!" after 2 or more days without a brush), then the count line (§6).
- It stays until 2 s after the last line, 4 s at least. A tap on it closes it; a tap beside it closes it and starts brushing, as today.
- A full card: "Your card is full! Brush to start a new one!"
- First open after this update, for a player with brushes in the last 7 days: the seeded card (§7) and "Look, Ranger! Your brushing made stickers! Every day you brush, you get a sticker!"
- First-ever open, before any brush: no window; "tap the hero" as today.
- **Later the same day:** no window; the home-return line as today.

### 4.4 Home
The streak pill shows a **sticker icon and the card's count** (0–7) instead of the flame. Nothing on Home moves: no tier-up whoosh, no pulse.

### 4.5 Victory, in its new order
1. Stars fly in (2), as today.
2. **Sticker beat** (first brush of the day), in the flame beat's slot. The card slides in big; Buddy: "You brushed today, so you get a sticker!"; the sticker lands on the next spot. Then:
   - **Sticker 3:** the little gift shakes and opens, 5 stars fly to the wallet: "Three stickers! You open the little gift! Five stars!"
   - **Sticker 7:** the big gift opens, 20 stars fly: "Seven stickers! Your card is full! Here's the big gift! Twenty stars!"
   - **Otherwise:** the count line.
   - **A new card:** the full card flies off, an empty one slides in, "A new card!", then the beat as above.
   - **First brush ever:** "This is your sticker card! Every day you brush, you get a sticker!", the sticker lands, then "Three stickers open the little gift. Seven open the big gift!" while both gift boxes bounce.
   - The beat holds 1.5 s after its last line, then the card shrinks to its closing place.
   - **Second brush of the day:** no sticker beat. "You brushed two times today! Two bonus stars!" when it completes both slots; a second brush in the same slot gets no extra line and no bonus.
3. **Chest:** one look, tap to open, as today.
4. **Goal fill** and one-tap unlock, as today.
5. **Trophy and world rockets**, as today.
6. **Closing:** the small card with the next spot ringed, and one line:
   - "See you tomorrow! Your next sticker is waiting."
   - Full card: "See you tomorrow for a new card!"
   - A morning brush with the evening still open: "See you tonight! Brush again for two bonus stars!"
   - Second brush of the day: "Great job! See you tomorrow for a new sticker!"
   Then DONE.

Removed from the victory screen: the flame beat, the flame strip and the comeback line. That is about 5 s less voice, and the end of the screen loses the tiny flame icons.

### 4.6 The next day, a missed day, a missed week
The card waits as he left it. The greeting says how many stickers he has and how far the next gift is. Nothing is lost or reset; "Welcome back, Ranger!" replaces "Hi Ranger!" after 2 or more days away.

### 4.7 What the reminder says about the card (Part C)
The reminder's approved rules stand: parent-facing, offered once after the first finished brush behind the parent gate, 7:30 pm by default, only if that slot isn't brushed, one per evening, silent after 7 days without an app open. Its copy rotates "Brushing time! Tonight's cavity monsters are waiting." and "Bedtime brush: 2 minutes, one monster battle." On a gift night (the next sticker is 3 or 7): "Brushing time! Tonight's brush opens a gift on the sticker card." It never mentions lost stickers or streaks, and it is rescheduled after each brush so the gift line stays true.

## 5. What is removed
1. Flame tiers: `flame_tier.dart`, `flame_view.dart` (FlameIcon, FlameStrip), the Home tier-up whoosh and "Your flame got bigger!", the `last_seen_flame_tier` key and the `flame_tier_reached` event. These exist only in the v1.1 test builds.
2. The flame beat, the flame strip and their 12 `voice_flame_*` clips.
3. Streak bonus stars (+1 at 3–6 days, +2 at 7+).
4. The welcome-back daily bonus (`claimDailyBonus`) and its star flight.
5. The comeback +3, its badge and its lines.
6. Chest tiers: the silver and gold looks and two of the three odds tables.
7. The Treasure Boost chest star (+1 on one day in four, never shown: the chest showed one star fewer than it paid) and its Parent Guide copy. The daily damage modifiers stay.
8. The greeting's "🔥 N ⭐" row, its caption and badges, and the streak-band greeting voice pools.
9. The unused `has_seen_first_streak_3`, `has_seen_first_streak_7` and `has_seen_first_daily_pair` flags.

The Parent Guide's star and chest copy is rewritten to match (with `settings_copy_test.dart`).

## 6. Voice lines (Buddy/George, house format)
New clips in `assets/audio/voices/buddy/`: mp3, 22 050 Hz, mono, 64 kbps, about −24 LUFS (the 2026-10-05 recipe). The 19 marked ✓ were recorded for the prototype and are reused after G1; the rest are new.

| File | Line | |
|---|---|---|
| `voice_card_hi` | "Hi Ranger!" | ✓ |
| `voice_card_welcome_back` | "Welcome back, Ranger!" | ✓ |
| `voice_card_count_1` … `_6` | "One sticker! Two more open the little gift!", "Two stickers! One more opens the little gift!", "Three stickers! Four more open the big gift!", "Four stickers! Three more open the big gift!", "Five stickers! Two more open the big gift!", "Six stickers! One more opens the big gift!" | ✓ |
| `voice_card_full` | "Your card is full! Brush to start a new one!" | ✓ |
| `voice_card_got_sticker` | "You brushed today, so you get a sticker!" | ✓ |
| `voice_card_gift_little` | "Three stickers! You open the little gift! Five stars!" | ✓ |
| `voice_card_gift_big` | "Seven stickers! Your card is full! Here's the big gift! Twenty stars!" | ✓ |
| `voice_card_new` | "A new card!" | ✓ |
| `voice_card_second_brush` | "You brushed two times today! Two bonus stars!" | ✓ |
| `voice_card_bye_tomorrow` | "See you tomorrow! Your next sticker is waiting." | ✓ |
| `voice_card_bye_new_card` | "See you tomorrow for a new card!" | ✓ |
| `voice_card_bye_second` | "Great job! See you tomorrow for a new sticker!" | ✓ |
| `voice_card_intro_1` | "This is your sticker card! Every day you brush, you get a sticker!" | ✓ |
| `voice_card_intro_2` | "Three stickers open the little gift. Seven open the big gift!" | ✓ |
| `voice_card_bye_tonight` | "See you tonight! Brush again for two bonus stars!" | new |
| `voice_card_seeded` | "Look, Ranger! Your brushing made stickers! Every day you brush, you get a sticker!" | new |
| `voice_step_pick_hero` | "Pick the hero who'll brush with you!" | new (Part A) |
| `voice_step_pick_weapon` | "Now pick your weapon!" | new (Part A) |
| `voice_step_pick_world` | "Pick the world where you'll fight!" | new (Part A) |

## 7. Existing players
Saves are a Hard Block: Jim and Oliver sign off on this section before release.
- **Nothing saved is rewritten or taken away:** stars, wallet, rank, unlocks, evolutions, trophies, worlds, achievements.
- `current_streak`, `best_streak`, `last_brush_date`, `streak_pause_until` and `brush_history` keep being written as today, so older builds keep working after a downgrade.
- **New keys:** `card_stickers` (0–7), `card_last_sticker_date`, `card_gifts_paid`, `cards_completed`, `card_intro_seen`. They join `SyncService._syncKeys`; sync keeps the side with more total progress, as today, and the card follows that side.
- **Seeding** on the first run of this version: one sticker per brushing day in the last 7 days (from `brush_history`), at most 6. Gifts at or below the seed show as opened but are not paid, because those days were paid under the old rules. A child who stopped weeks ago starts with an empty card.
- Production players never saw the tiered flame (it is only in v1.1 test builds), so nothing visible is taken from them.

## 8. Stars per day
Every brush 2 + chest ≈ 1.55; pair +2 once a day; gifts 25 per 7 stickers. Compared with today's build-41 rules, from the synthesis simulation (local notes):
- First 4 weeks: once a day 203 → 199 stars (−2%), twice a day 387 → 355 (−8%).
- Children who keep brushing for months: 10–15% fewer stars a day. A steady twice-a-day child empties the shop in about 32 days instead of 28.
- The first week pays more (the big gift lands on day 7), and a child who misses weekends earns more than today, because today's rules reset his streak every week.

## 9. Architecture
- **`StickerCardService`** (`lib/services/sticker_card_service.dart`): the card rules and their keys. `recordBrushDay(DateTime)` returns what happened (sticker placed, new count, gift stars, new card, card full); `seedFromHistory(...)`; `state()`. `StreakService.recordBrush` calls it, so all stars of a brush are credited together.
- **`StreakService`:** drops the streak bonus, the comeback bonus and `claimDailyBonus`; the pair bonus becomes +2 once a day. The chest uses one odds table; the Treasure Boost chest star goes (`world_service.dart` keeps the other daily modifiers).
- **`StickerCard` widget** (`lib/widgets/sticker_card.dart`): big and small sizes, the ringed next spot, the gift boxes, the landing and opening animations. It replaces FlameStrip and FlameIcon in the greeting, the victory screen and the Home pill.
- **Victory:** the sticker beat replaces the flame beat; the closing card replaces the flame strip.
- **Home:** the greeting dialog shows the card and holds as in §4.3; the pill shows the sticker icon and count; the daily-bonus flight goes.
- **Part A:** the step header lives in `PreBrushScreen`; `HeroShopScreen` hides its own tab bar in brush mode; entry lines become instruction plus progress; `PopScope` steps back. `brushing_screen.dart` loses the monster counter and `_PhaseProgressIconPainter`.

## 10. Testing
- **Gate G1 (prototype, before any card code):** after sticker 3, Oliver says what the third sticker does; after a skipped day, he says nothing is lost (or close); he picks a look. Answers land in the prototype's `results/oliver`.
- **Unit:**
  - the card rules: first brush of the day only; gifts at 3 and 7; a new card after 7; missed days; every seeding case;
  - the earn table for each case in §8;
  - sync of the new keys.
- **Widget:** use `TimedFakeAudioService`, since the instant fake hides voice-queue timing.
  - The greeting hold.
  - The victory order and lines for: first brush ever, a normal sticker, gift 3, gift 7, a new card, the second brush, a morning brush.
  - The step header, the instruction lines and the back gesture.
  - The brushing screen without the counter and the sign.
- **Device:** Jim and Oliver on a test build. Check a signed-in restore and a downgrade to v29.

## 11. Analytics (Android only)
- New events:
  - `sticker_placed {count, card_number, gap_days, seeded}`
  - `card_gift_opened {gift, stars}`
  - `card_greeting_shown {count, closed_by}`
  - `victory_exit {last_beat}`
- `brush_session_complete` gains `slot` and `sticker`.
- User properties: `reward_design`, `cards_completed`, `reminder_on`.
- `flame_tier_reached` is retired.
- Before release, register the new parameters as custom dimensions and save the v29 baseline.
- Read results by `app_version`, pooled over at least 4 weeks:
  - day-3 and day-7 brushing retention against v29;
  - the share of new players reaching sticker 3 and sticker 7 within 10 days;
  - the share of victories that reach the closing beat (at least 70%).
- Guardrails: stars per active day within ±10% of v29; the twice-a-day share does not fall.

## 12. Risks
1. **Still a row of spots he doesn't get.** Big spots, one voiced line per beat, held after the voice; G1 before code.
2. **Babyish at 7–8.** Space art; Oliver picks the look.
3. **Drift to every other day.** The first gift on day 3, the nightly "See you tomorrow", the reminder's gift line. If brushing days per active week fall below v29 by week 6, test a third gift at sticker 5, not a calendar.
4. **Economy shift.** The ±10% guardrail above; the goal fill still moves on every brush.
5. **v1.1 load.** One voice batch, timed-audio tests, and a 20% staged rollout first.

## 13. Out of scope
The world-finish celebration (Jim's note on d13; the product plan's "finale for every world"); multi-profile; seasonal sticker sets; a third gift at sticker 5 (only per risk 3).

# Brush steps on the real pages — design (v1.1 rework)

**Status:** approved by Jim in chat, 2026-10-13. Amends `2026-10-05-brush-flow-and-hooks-design.md`: replaces its §4 (pre-brush screen) and decision D2, and amends D5, §10 and §11. Everything else in that spec stands.

## 1. Why
Jim, after trying v1.1 (1.1.0+40) on his phone: "I really don't like the screens to select the hero or weapon or world. There is no magic. It should probably much more look like the existing screens of how you choose each of them. And when you click on them, you can hear the description just like it is on the pages."

The v1.1 steps were new carousels with silhouettes and meters. They had none of the art, glow and voices of the pages Oliver already uses to pick a hero, a weapon and a world.

## 2. Decisions (Jim, 2026-10-13)

| # | Decision |
|---|---|
| R1 | The three steps are the **real pages** in a "brush mode": Hero = the Heroes & Weapons page on its HEROES tab; Weapon = the same page on its WEAPONS tab; World = the Map page. |
| R2 | Each page has a big glowing **GO** button. If he doesn't touch anything for about **8 s**, the page moves on by itself. (Replaces D2's auto-advance after about 3 s.) |
| R3 | Tapping something locked works **exactly as on the page**, including unlocking on the spot with the page's dialogs and celebration when he has enough stars. (Amends D5: the victory screen still offers the goal he didn't buy.) |
| R4 | Tapping anything plays the page's own description voice, as it does today. |
| R5 | The **closest next unlock glows**, and the page scrolls to it when it is below the screen. Otherwise "Three more stars!" points at nothing a non-reader can see. |
| R6 | The pages opened from Home look and sound exactly as today. |

Unchanged from the 2026-10-05 spec: the first-ever brush skips the steps (D6); the step order; "Let's fight!" before brushing; the brushing screen starts at the 3-2-1 countdown (no world intro); the goal rules (§5); the victory screen; Home; prices and earning.

## 3. Flow

```
Home ──tap hero──► [first-ever brush?] ──yes──► Brushing (with its world intro) ──► Victory ──► Home
                          │no
                          ▼
   HEROES tab ──GO / 8 s──► WEAPONS tab (same page, slides over) ──GO / 8 s──► Map ──GO / 8 s──► "Let's fight!" ──► Brushing
        ▲                                │
        └──── tapping the HEROES or WEAPONS tab switches step ────┘
   X (or system back) on any step ──► Home, keeping his choices
```

## 4. Brush mode

### 4.1 What each page shows
The page is exactly what Home opens: header with title and star wallet, tabs, featured hero or weapon, hero rows with evolutions, weapon cards, price tags, the planet path. Brush mode changes only:
- **X instead of the back arrow.** Same 56 × 56 rounded button style as the Map's back button, with a close icon. It goes back to Home.
- **GO button**, bottom centre, floating above the page: the onboarding NEXT button's purple gradient and glow, about 76 px tall, a gentle pulse. Label "GO!" with an arrow on the HEROES and WEAPONS tabs, a rocket on the Map. Both the label and the icon are there, so a non-reader still knows it.
- **Bottom padding**, so the last row, card or planet can scroll above the GO button.
- **Glow on the closest next unlock** (the hero, weapon or world goal of 2026-10-05 §5): a pulsing gold ring on that cell, card or planet. No glow when the category is complete. Once the step's entry lines have finished, if the glowing item is not fully on screen, the page scrolls it into view (once per step entry, never while he is touching).

### 4.2 Moving on
- **GO** goes to the next step at once, with the whoosh SFX and a medium haptic, like other buttons.
- **Idle advance:** about 8 s with no touch. The count starts once the voice pipeline is idle (the step's lines, or a description he triggered, have finished). A finger down or a scroll stops it; lifting the finger or the scroll ending starts it again from zero.
- **Never while something is on top:** while a dialog (purchase confirmation, unlock celebration) is open, nothing advances and the count restarts once the dialog closes.
- **Tabs:** tapping the WEAPONS or HEROES tab (or swiping between them) is a step change, with that step's entry lines.
- **App in the background:** the count stops; on return it starts again from zero.
- **Map → brushing:** GO, or the idle count, plays "Let's fight!", then brushing opens the way it does now (400 ms launch delay, then it waits for the line to end, at most 3 s).

### 4.3 What he hears
One voice at a time, through the existing queue.
- **Entering the HEROES tab:** the selected hero's picker line (`voice_picker_evo_<hero>_stage<n>` when evolved, else `voice_picker_hero_<hero>`), then the progress line for the hero goal.
- **Entering the WEAPONS tab:** the selected weapon's picker line, then the progress line for the weapon goal.
- **Entering the Map:** `voice_world_<current>`, then the progress line for the world goal.
- **Progress line:**
  - goal affordable → `voice_tap_to_unlock` ("Tap to unlock it!"); in the steps this replaces "Brush to unlock it!", because he can now unlock right there;
  - stars left → `voice_stars_left_<n>` / `voice_stars_left_many`;
  - brushes left (Map) → `voice_brushes_left_<n>`;
  - category complete → `voice_have_them_all`.
- **Taps:** the page's own behaviour, untouched: descriptions, the "need stars" nudge, purchase confirmation, unlock celebration, and "Keep brushing to reach this planet!" on locked planets.
- **Not in brush mode:** the page entry voices (`voice_entry_hero_hq`, the Map intro and world line on load), the tab voices (`voice_tab_heroes`, `voice_tab_weapons`), and the pages' music changes. Home's music keeps playing under the steps, as now.
- **Step change:** stops whatever is still playing (`clearQueue` + `interrupt`) and clears the page's snackbars.

### 4.4 After an unlock in the steps
The page plays its own celebration. The new item is equipped (the shop already selects a bought hero or weapon, and a bought evolution of the selected hero). The goals are recomputed, so the glow moves to the next closest unlock; no extra line plays.

### 4.5 Errors
If the step data fails to load (3 s timeout), brushing starts directly, as today. A voice that never ends cannot hold a step: the 8 s count also starts after a 6 s cap on waiting for the voice.

## 5. Architecture
- **`PreBrushScreen`** stays the flow coordinator: step state, entry lines, GO, idle count, dialog and lifecycle checks, the launch into brushing, the error fallback and PopScope. It renders one `HeroShopScreen` in brush mode for the HEROES and WEAPONS steps (the same instance, so switching steps is the page's own tab slide) and a `WorldMapScreen` in brush mode for the Map step, switched with a slide transition, plus the GO overlay.
- **`BrushMode`** (new, small, in `lib/screens/brush_mode.dart`): what a page needs to run inside the steps.
  - `onClose`.
  - `tab` (a listenable index the page follows) and `onTabChanged`.
  - `highlightId` (the goal to glow) and `reveal` (pinged when the page should scroll the glow into view).
  - `onChanged` (after a selection or an unlock, so goals are recomputed).
- **`HeroShopScreen` and `WorldMapScreen`** take an optional `BrushMode? brushMode`. When it is null they behave exactly as today (R6). When set: X instead of back, no entry voice, tab voice, music or `shop_visit`, bottom padding, the glow, and the callbacks above.
- **`GoButton`** (new widget, `lib/widgets/go_button.dart`).
- **Removed:** `LoadoutCarousel` (used only by the steps) and the carousel, silhouette and meter UI inside `pre_brush_screen.dart`. `GoalMeter`, `ItemSilhouette` and `GoalArt` stay; the victory screen uses them.
- **Standing rules:** every delay is a `Timer?` field cancelled in `dispose()`; kid-facing dialogs keep `barrierDismissible: false`.

## 6. Analytics (Android only)
- `pre_brush_change {category}` when he changes hero, evolution, weapon or world during the steps (as now).
- `goal_unlocked {category, item, source: pre_brush}` for every unlock during the steps; `hero_unlock` / `weapon_unlock` still fire from `UnlockService`.
- No `shop_visit` from the steps.

## 7. Testing
- `PreBrushScreen` (tests rewritten for the new flow):
  - the entry lines per step, including "Tap to unlock it!" when affordable;
  - GO through all three steps;
  - the idle count: start after the voice, reset on touch and on scroll, no advance while a dialog is open, restart after the app returns;
  - tab taps as step changes;
  - X and back to Home with choices kept;
  - the load-failure fallback;
  - "Let's fight!" into brushing without the world intro.
- `HeroShopScreen` and `WorldMapScreen` in brush mode:
  - X instead of back;
  - no entry, tab or map-intro voice and no music change;
  - the glow on the goal item and the reveal scroll;
  - an unlock during the steps equips the item, reports it and logs `goal_unlocked` with `source: pre_brush`.
- R6: the existing shop and map tests pass unchanged, and a test pins that without brush mode the entry voices, music and `shop_visit` happen as before.
- Voice timelines (`TimedFakeAudioService`): step lines never overlap, and the idle count waits for a long description.
- **Visual parity check before Jim sees it:** on the emulator, screenshot each page opened from Home and the same page in brush mode at phone size. The only differences must be the X, the GO button, the bottom padding and the glow.

## 8. Out of scope
Changes to the pages when opened from Home; new voice lines or art (every line above already exists); the victory screen and Home; prices and earning.

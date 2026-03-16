# Brush Quest -- Manual Audio Testing Checklist

> **Run before every APK upload to Google Play.**
> Audio IS the UI for this app. The target user is a 7-year-old who cannot read.
> If any voice line is missing, plays at the wrong time, or overlaps another voice,
> the child will not know what to do. Every checkbox below must pass.

**Device:** ________________________
**Build:** ________________________
**Tester:** ________________________
**Date:** ________________________

---

## 1. First Launch / Onboarding

Precondition: clear app data or fresh install so `onboarding_completed` is false.

- [ ] Page 1 (Welcome): `voice_onboarding_1.mp3` plays automatically ~450ms after screen loads
- [ ] Page 1: voice content matches the Welcome Space Ranger page (not generic)
- [ ] Swipe to Page 2 (How To Play): `voice_onboarding_2.mp3` plays, previous voice is interrupted (`clearQueue: true, interrupt: true`)
- [ ] Page 2: voice content describes how brushing works
- [ ] Swipe to Page 3 (Mouth Guide): `voice_onboarding_3.mp3` plays, previous voice is interrupted
- [ ] Page 3: voice content describes the tooth-guide concept
- [ ] Swipe back to Page 1: voice replays for that page (narration tracks `_lastNarratedPage`)
- [ ] Tap the speaker icon (top-right): current page narration replays with `force: true`
- [ ] Tap NEXT button: `whoosh.mp3` SFX plays on each page advance
- [ ] Tap LET'S GO on Page 3: `victory.mp3` SFX + `voice_lets_fight.mp3` voice play
- [ ] No voice overlap at any point -- each page voice interrupts the previous one

---

## 2. Home Screen

### 2a. Returning User (has brushed before, first open of the day)
- [ ] Ambient music starts: `battle_music_loop.mp3` at very low volume (0.06)
- [ ] Greeting popup appears (if not already greeted today): plays state-appropriate voice
  - New user (1-2 brushes): `voice_greet_just_started_{1,2,3}.mp3`
  - Streak 2-4: `voice_greet_streak_low_{1,2}.mp3`
  - Streak 5-9: `voice_greet_streak_mid_{1,2}.mp3`
  - Streak 10-19: `voice_greet_streak_high_{1,2}.mp3`
  - Streak 20+: `voice_greet_streak_legend_{1,2}.mp3`
  - Returning (broken streak): `voice_greet_returning_{1,2}.mp3`
- [ ] If already greeted today, `voice_welcome_back.mp3` plays after ~800ms delay

### 2b. First Launch (0 total brushes)
- [ ] No welcome-back voice plays (user hasn't brushed yet)
- [ ] No greeting popup (total brushes == 0)

### 2c. Returning from Victory Screen (`skipGreeting: true`)
- [ ] No greeting popup plays
- [ ] No welcome-back voice plays

### 2d. Mute Button
- [ ] Tap mute: all audio stops immediately (SFX, voice, music)
- [ ] Mute icon visually updates
- [ ] Tap unmute: mute state clears; ambient music resumes on next screen load
- [ ] Mute state persists across app restarts (stored in SharedPreferences)

### 2e. Navigation SFX
- [ ] Tap BRUSH button: `whoosh.mp3` SFX plays
- [ ] Navigate to Hero Shop: `whoosh.mp3` SFX plays on button tap
- [ ] Navigate to World Map: `whoosh.mp3` SFX plays on button tap
- [ ] Navigate to Card Album: `whoosh.mp3` SFX plays on button tap

### 2f. Locked Items on Home Screen
- [ ] Tap a locked hero in the home quick-picker: `voice_need_stars.mp3` plays with interrupt
- [ ] Tap a locked weapon in the home quick-picker: `voice_need_stars.mp3` plays with interrupt

---

## 3. Full Brushing Session

### 3a. World Intro
- [ ] World mission briefing voice plays: `voice_world_{worldId}.mp3` (normal session) or `voice_unstoppable.mp3` (boss session)
- [ ] Voice content matches the current world name

### 3b. Countdown (3, 2, 1, GO!)
- [ ] `voice_countdown.mp3` plays with `clearQueue: true, interrupt: true`
- [ ] `countdown_beep.mp3` SFX plays on each tick (3, 2, 1)
- [ ] Countdown voice does not overlap with beep SFX (voice is on voice player, beep is on SFX pool)
- [ ] Heavy haptic on GO

### 3c. Battle Music
- [ ] `battle_music_loop.mp3` starts when brushing begins
- [ ] Music volume is 0.18 (normal) -- noticeably quieter than voice
- [ ] Music loops continuously for full 2-minute session
- [ ] Music health check fires every 5 seconds (`ensureMusicPlaying`) -- if music somehow stops, it restarts

### 3d. Phase Transitions (4 phases: TL, TR, BL, BR)
- [ ] Phase 1 start (Top Left): `whoosh.mp3` SFX + `voice_top_left.mp3` after 300ms delay
- [ ] Phase 2 start (Top Right): `whoosh.mp3` SFX + `voice_top_right.mp3` after 300ms delay
- [ ] Phase 3 start (Bottom Left): `whoosh.mp3` SFX + `voice_bottom_left.mp3` after 300ms delay
- [ ] Phase 4 start (Bottom Right): `whoosh.mp3` SFX + `voice_bottom_right.mp3` after 300ms delay
- [ ] Each phase direction voice is correct (says "top left" not "bottom right", etc.)
- [ ] Monster defeat SFX (`monster_defeat.mp3`) plays when phase timer expires and monster is killed

### 3e. Encouragement Voices During Each Phase
With default 30s phases, encouragements fire at ~80%, ~50%, and ~20% of each phase timer.

- [ ] Energizing voice (~80%): one of `voice_go_go_go.mp3`, `voice_super.mp3`, `voice_unstoppable.mp3`, `voice_nice_combo.mp3`
- [ ] Supportive voice (~50%): one of `voice_youre_doing_great.mp3`, `voice_keep_it_up.mp3`, `voice_keep_going.mp3`, `voice_so_strong.mp3`
- [ ] Almost-there voice (~20%): one of `voice_almost_there.mp3`, `voice_awesome.mp3`, `voice_wow_amazing.mp3`
- [ ] Each encouragement plays only once per phase (flags reset on phase change)
- [ ] Encouragements do not overlap with phase-transition voices (voice queue serializes them)

### 3f. Music Ducking During Voice
- [ ] When any voice line plays, music volume drops to 0.08 (ducked)
- [ ] When voice line finishes, music volume restores to 0.18
- [ ] SFX volume drops to 0.24 during voice playback (vs 0.7 normally)
- [ ] Ducking transitions are smooth -- no jarring cuts

### 3g. Attack / Hit SFX
- [ ] Each tap/motion-triggered attack plays a hit sound: alternating `zap.mp3` and `whoosh.mp3`
- [ ] Hit SFX plays from the 3-player SFX pool (can overlap with itself)
- [ ] Rapid tapping does not cause audio errors (pool round-robins)

### 3h. Monster Kill by Damage (mid-phase)
- [ ] `monster_defeat.mp3` plays when monster HP reaches 0 mid-phase
- [ ] A new monster spawns in the same phase (brushing continues)
- [ ] No crash or audio glitch from rapid monster kills

### 3i. Session Completion
- [ ] Music stops cleanly when last phase ends (`stopMusic()`)
- [ ] No lingering audio after navigating to Victory Screen
- [ ] Voice queue is not carrying over stale entries to Victory Screen

---

## 4. Victory Screen

### 4a. Victory Celebration
- [ ] `victory.mp3` SFX plays immediately
- [ ] Time-appropriate victory voice plays after 300ms:
  - Morning (5:00-11:59): `voice_great_job_morning.mp3`
  - Afternoon (12:00-17:59): `voice_you_did_it.mp3`
  - Evening/Night (18:00-4:59): `voice_great_job_tonight.mp3`
- [ ] `voice_earned_star.mp3` is queued after the victory voice (plays sequentially, no overlap)
- [ ] Victory voice content matches the time of day

### 4b. Treasure Chest
- [ ] `voice_open_chest.mp3` plays ~1.5s after victory animation starts ("Open the chest!")
- [ ] Tap chest: `star_chime.mp3` SFX plays
- [ ] Chest reward voice plays after 500ms:
  - Confetti: `voice_chest_wow.mp3`
  - Dance: `voice_chest_dance.mp3`
  - Bonus Star: `voice_chest_bonus_star.mp3`
  - Double Power: `voice_chest_double.mp3`
  - Jackpot / Mega Jackpot: `voice_chest_jackpot.mp3`
- [ ] Reward voice uses `await playVoice()` -- blocks until complete before continuing

### 4c. Card Drop (if rolled)
- [ ] `star_chime.mp3` SFX plays when card appears
- [ ] New card: `voice_card_new.mp3` plays first, then `voice_card_{cardId}.mp3` is queued
- [ ] Duplicate card: `voice_card_fragment.mp3` plays first, then `voice_card_{cardId}.mp3` is queued
- [ ] Card description voice matches the specific card that dropped
- [ ] Full sequence (new + description) plays without overlap thanks to voice queue

### 4d. Achievements
- [ ] `whoosh.mp3` SFX plays when achievement popup appears
- [ ] Multiple achievements stagger at 1200ms intervals (no pile-up)

---

## 5. Hero & Weapon Shop

### 5a. Entry
- [ ] `voice_entry_hero_shop.mp3` plays ~400ms after screen loads (with `clearQueue: true, interrupt: true`)
- [ ] Entry voice describes the shop concept, not just a generic greeting

### 5b. Hero Selection (already unlocked)
- [ ] Tap an unlocked hero: picker voice plays for that hero (`voice_picker_hero_{id}.mp3`)
- [ ] Picker voice describes the character (not just the name)
- [ ] Voice uses `clearQueue: true, interrupt: true` -- tapping another hero immediately interrupts

### 5c. Hero Unlock (enough stars)
- [ ] Tap a locked hero you can afford: hero is unlocked
- [ ] Intro voice plays: `voice_intro_hero_{id}.mp3` (longer, more dramatic than picker voice)
- [ ] Unlock dialog appears with hero image and name

### 5d. Hero Locked (not enough stars)
- [ ] Tap a locked hero you cannot afford: `voice_need_stars.mp3` plays with interrupt
- [ ] Snackbar shows how many more stars are needed

### 5e. Weapon Selection (already unlocked)
- [ ] Tap an unlocked weapon: picker voice plays for that weapon (`voice_picker_weapon_{id}.mp3`)
- [ ] Picker voice describes the weapon (not just the name)

### 5f. Weapon Unlock (enough stars)
- [ ] Tap a locked weapon you can afford: weapon is unlocked
- [ ] Intro voice plays: `voice_intro_weapon_{id}.mp3`
- [ ] Unlock dialog appears with weapon image and name

### 5g. Weapon Locked (not enough stars)
- [ ] Tap a locked weapon you cannot afford: `voice_need_stars.mp3` plays with interrupt

### 5h. Rapid Tapping
- [ ] Rapidly tap different heroes: each tap interrupts the previous voice cleanly (no pile-up)
- [ ] Rapidly tap different weapons: same behavior

---

## 6. World Map

- [ ] `voice_entry_world_map.mp3` plays on entry (~400ms delay)
- [ ] Tap a world node: `voice_world_{worldId}.mp3` plays with interrupt
- [ ] World voice describes that specific world
- [ ] Tap a locked world: `voice_need_stars.mp3` plays

---

## 7. Card Album

### 7a. Entry
- [ ] `voice_entry_card_album.mp3` plays on entry (~400ms delay)

### 7b. Card Tap (collected card)
- [ ] Tap a collected card: `voice_card_{cardId}.mp3` plays with `clearQueue: true, interrupt: true`
- [ ] Voice describes the monster ("[Name], the [Title]! [flavor]")
- [ ] Card detail dialog appears

### 7c. Card Tap (uncollected card)
- [ ] Tap an uncollected/mystery card: `voice_card_mystery.mp3` plays with interrupt

### 7d. Fragment Tutorial
- [ ] First time viewing album with fragments > 0: `voice_fragment_explain.mp3` plays after 3s delay
- [ ] Tutorial voice does not play on subsequent visits (stored in SharedPreferences)

### 7e. Fragments Ready
- [ ] When fragments >= 3 and were previously < 3: `voice_fragments_ready.mp3` plays after 2s delay

### 7f. Redeem Fragments
- [ ] Tap fragment redemption: `star_chime.mp3` SFX plays
- [ ] New card reveal dialog opens with card voice playing

---

## 8. Settings Screen

- [ ] `voice_entry_settings.mp3` plays on entry (~400ms delay)

---

## 9. Edge Cases

### 9a. Mute During Brushing Session
- [ ] Toggle mute mid-session: all audio stops immediately (music, voice, SFX)
- [ ] Voice queue is cleared on mute (`_clearVoiceQueue`)
- [ ] All 3 SFX pool players are stopped
- [ ] Voice player is stopped
- [ ] Music player is stopped (unless transitioning)
- [ ] `_musicPlaying` and `_voicePlaying` flags reset to false

### 9b. Unmute During Brushing Session
- [ ] Toggle unmute mid-session: mute flag clears
- [ ] Music does NOT immediately resume (relies on health check or next `playMusic` call)
- [ ] Music health check (`ensureMusicPlaying` every 5s) detects music stopped and restarts it
- [ ] Next voice/SFX trigger plays normally

### 9c. Background / Resume (Android)
- [ ] Send app to background during brushing: music may pause (OS behavior)
- [ ] Return to app: music health check restarts music within 5 seconds
- [ ] Timer continues correctly (wakelock is enabled during brushing)
- [ ] Voice queue resumes without duplicate entries

### 9d. Rapid Screen Navigation
- [ ] Open Hero Shop, immediately press back, open World Map: no voice pile-up (each entry voice uses `clearQueue: true, interrupt: true`)
- [ ] Open Card Album, immediately press back: entry voice stops cleanly
- [ ] Navigate Home > Shop > Home > Shop rapidly: no orphaned audio players

### 9e. Three Consecutive Brushing Sessions
- [ ] Complete session 1: all audio plays correctly
- [ ] Tap BRUSH again for session 2: music starts fresh (new AudioPlayer created), no leftover state
- [ ] Complete session 2: victory audio plays correctly, no drift in timing
- [ ] Session 3: same -- verify no audio degradation or stuck players after multiple sessions
- [ ] Voice queue is empty between sessions (no stale encouragements carrying over)

### 9f. Voice Timeout Recovery
- [ ] If a voice file fails to play (corrupt/missing), the 5-second timeout fires
- [ ] Voice queue continues processing the next item (does not deadlock)
- [ ] Audio issue is logged to debug console: `voice_timeout`

### 9g. Mute Persistence
- [ ] Mute the app, force-kill, relaunch: app starts muted
- [ ] Unmute, force-kill, relaunch: app starts unmuted

---

## 10. Volume Balance

Listen with device volume at ~50% in a quiet room.

- [ ] Voice lines are clearly audible over music (voice at 1.0, music at 0.18)
- [ ] Music ducking is noticeable but not jarring (0.18 -> 0.08 during voice)
- [ ] SFX (zap, whoosh) are punchy but not louder than voice (0.7 normal, 0.24 during voice)
- [ ] `star_chime.mp3` is satisfying and not ear-piercing
- [ ] `victory.mp3` is celebratory but does not clip
- [ ] `countdown_beep.mp3` is crisp and rhythmic
- [ ] `monster_defeat.mp3` is dramatic but proportionate
- [ ] Home screen ambient music (volume 0.06) is barely perceptible -- sets mood without distraction
- [ ] No audio clipping or distortion at any point during a full session

---

## Sign-Off

All items checked:  [ ] YES  [ ] NO (list failures below)

Failures / Notes:
_________________________________________________________
_________________________________________________________
_________________________________________________________
_________________________________________________________

Approved for upload:  [ ] YES  [ ] NO

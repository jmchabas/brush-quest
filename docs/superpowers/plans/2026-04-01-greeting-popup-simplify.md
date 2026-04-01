# Greeting Popup Simplification

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Simplify the home screen greeting popup: shorter voices, icon-only bonus badge, remove unlock tease section and "Let's Go!" button.

**Architecture:** Four changes to the greeting popup in `home_screen.dart`: (1) re-record two voice files with shorter, teaching-focused scripts, (2) replace the wordy bonus badge with an icon+number visual, (3) remove the unlock tease section (hero icon + progress bar), (4) remove the "Let's Go!" button since tap-anywhere and auto-dismiss already work. Also remove dead code (`_unlockVoices` map) and add the voice files to the preload list.

**Tech Stack:** Flutter/Dart, ElevenLabs TTS MCP tool

**Context — what the popup currently does (for a 14-day streak):**
- Voice pipeline plays 3 sequential lines: greeting (~4s) + streak bonus explain (~6s) + unlock tease (~4s) = ~14s total
- UI shows: title, streak badge, wordy bonus text, hero icon + progress bar, "Let's Go!" button
- Target user (age 7) cannot read

**What we're changing:**
- Voice: 2 lines instead of 3 (drop unlock tease voice). Re-record bonus explain with new scripts.
- UI: icon-only bonus badge, remove tease section, remove button

---

### Task 1: Generate new voice files via ElevenLabs TTS

**Files:**
- Replace: `assets/audio/voices/classic/voice_streak_bonus_explain_high.mp3`
- Replace: `assets/audio/voices/classic/voice_streak_bonus_explain_low.mp3`

**Voice:** Classic (Jessica), voice ID `cgSgspJ2msm6clMCkdW9`

- [ ] **Step 1: Generate high streak voice**

Use ElevenLabs `text_to_speech` MCP tool:
- Voice ID: `cgSgspJ2msm6clMCkdW9`
- Text: `"You've been brushing for more than seven days in a row — what a streak! You're now earning two bonus stars every brush! Keep brushing every day to keep earning them!"`
- Save to: `assets/audio/voices/classic/voice_streak_bonus_explain_high.mp3`

- [ ] **Step 2: Generate low streak voice**

Use ElevenLabs `text_to_speech` MCP tool:
- Voice ID: `cgSgspJ2msm6clMCkdW9`
- Text: `"You've been brushing for three days in a row — what a streak! You're now earning one bonus star every brush! Keep brushing every day and you'll earn even more!"`
- Save to: `assets/audio/voices/classic/voice_streak_bonus_explain_low.mp3`

- [ ] **Step 3: Verify files exist and have reasonable duration**

Run:
```bash
ffprobe -v quiet -show_entries format=duration -of csv=p=0 assets/audio/voices/classic/voice_streak_bonus_explain_high.mp3
ffprobe -v quiet -show_entries format=duration -of csv=p=0 assets/audio/voices/classic/voice_streak_bonus_explain_low.mp3
```
Expected: Both files exist, duration ~5-7 seconds each.

---

### Task 2: Add voice files to audio preload list

**Files:**
- Modify: `lib/services/audio_service.dart:183` (after `voice_streak_bonus.mp3`)

- [ ] **Step 1: Add the two files to `_allAudioFiles`**

In `lib/services/audio_service.dart`, after line 183 (`'voice_streak_bonus.mp3',`), add:

```dart
    'voice_streak_bonus_explain_high.mp3',
    'voice_streak_bonus_explain_low.mp3',
```

- [ ] **Step 2: Run dart analyze**

Run: `dart analyze lib/services/audio_service.dart`
Expected: No issues.

---

### Task 3: Simplify greeting popup UI and voice pipeline

**Files:**
- Modify: `lib/screens/home_screen.dart:69-80` (remove `_unlockVoices` map)
- Modify: `lib/screens/home_screen.dart:292-298` (remove unlock tease voice)
- Modify: `lib/screens/home_screen.dart:366-407` (replace bonus badge with icon-only)
- Modify: `lib/screens/home_screen.dart:408-512` (remove tease section + button)

- [ ] **Step 1: Remove `_unlockVoices` map**

Delete lines 69-80 in `home_screen.dart`:

```dart
  // DELETE THIS ENTIRE BLOCK:
  static const Map<String, String> _unlockVoices = {
    'frost': 'voice_unlock_next_frost.mp3',
    'bolt': 'voice_unlock_next_bolt.mp3',
    'shadow': 'voice_unlock_next_shadow.mp3',
    'leaf': 'voice_unlock_next_leaf.mp3',
    'nova': 'voice_unlock_next_nova.mp3',
    'flame_sword': 'voice_unlock_next_flame_sword.mp3',
    'ice_hammer': 'voice_unlock_next_ice_hammer.mp3',
    'lightning_wand': 'voice_unlock_next_lightning_wand.mp3',
    'vine_whip': 'voice_unlock_next_vine_whip.mp3',
    'cosmic_burst': 'voice_unlock_next_cosmic_shield.mp3',
  };
```

- [ ] **Step 2: Remove unlock tease voice from pipeline**

In `_showGreetingPopup()`, delete lines 292-298 (the unlock tease voice queuing):

```dart
    // DELETE THIS ENTIRE BLOCK:
    // Queue unlock tease voice AFTER the greeting + bonus voice
    if (greeting.teaseItemId != null) {
      final unlockVoice = _unlockVoices[greeting.teaseItemId];
      if (unlockVoice != null) {
        AudioService().playVoice(unlockVoice);
      }
    }
```

- [ ] **Step 3: Replace wordy bonus badge with icon-only visual**

Replace lines 366-407 (the bonus star badge section). The current code shows text like "+2 BONUS STARS PER BRUSH!". Replace with a larger, icon-driven badge that shows just the number and star icon — no words.

Replace:
```dart
                // Bonus star badge — explain the reward for streaks
                if (greeting.brushStreak >= 3) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFFFFD54F).withValues(alpha: 0.25),
                          const Color(0xFFFF6D00).withValues(alpha: 0.25),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFFFFD54F).withValues(alpha: 0.5),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.star,
                          color: Color(0xFFFFD54F),
                          size: 18,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '+${greeting.brushStreak >= 7 ? 2 : 1} BONUS STAR${greeting.brushStreak >= 7 ? "S" : ""} PER BRUSH!',
                          style: const TextStyle(
                            color: Color(0xFFFFD54F),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
```

With:
```dart
                // Bonus star badge — icon-only, no text (kid can't read)
                if (greeting.brushStreak >= 3) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFFFFD54F).withValues(alpha: 0.25),
                          const Color(0xFFFF6D00).withValues(alpha: 0.25),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFFFFD54F).withValues(alpha: 0.5),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '+${greeting.brushStreak >= 7 ? 2 : 1}',
                          style: const TextStyle(
                            color: Color(0xFFFFD54F),
                            fontWeight: FontWeight.bold,
                            fontSize: 22,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.star,
                          color: Color(0xFFFFD54F),
                          size: 24,
                        ),
                      ],
                    ),
                  ),
                ],
```

- [ ] **Step 4: Remove unlock tease section (hero icon + progress bar)**

Delete lines 408-486 (the entire tease section):

```dart
                // DELETE THIS ENTIRE BLOCK:
                if (greeting.teaseItemImagePath != null &&
                    greeting.teaseItemUnlockAt != null &&
                    greeting.teaseStarsAway != null &&
                    greeting.teaseStarsAway! > 0) ...[
                  const SizedBox(height: 16),
                  // Next unlock item icon
                  Container(
                    ... (entire hero icon widget)
                  ),
                  const SizedBox(height: 8),
                  // Progress bar toward unlock
                  SizedBox(
                    ... (entire progress bar widget)
                  ),
                ],
```

- [ ] **Step 5: Remove "Let's Go!" button**

Delete lines 487-512 (the button and its spacer). The `const SizedBox(height: 20)` spacer above it should also be removed. The popup is already dismissible via:
- Tapping outside (`barrierDismissible: true`)
- Auto-dismiss when voice finishes

```dart
                // DELETE THIS ENTIRE BLOCK:
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () => Navigator.of(dialogContext).pop(),
                  child: Container(
                    ... (entire button widget)
                  ),
                ),
```

- [ ] **Step 6: Run dart analyze**

Run: `dart analyze lib/screens/home_screen.dart`
Expected: No issues. If there are unused import warnings (e.g., from removed tease code), fix them.

---

### Task 4: Run quality gates and verify

- [ ] **Step 1: Run full dart analyze**

Run: `dart analyze`
Expected: No issues.

- [ ] **Step 2: Run flutter test**

Run: `flutter test`
Expected: All tests pass. The greeting popup is skipped in home screen tests (`skipGreeting: true`), so no test changes needed.

---

### Task 5: Commit

- [ ] **Step 1: Stage and commit**

```bash
git add assets/audio/voices/classic/voice_streak_bonus_explain_high.mp3 \
       assets/audio/voices/classic/voice_streak_bonus_explain_low.mp3 \
       lib/services/audio_service.dart \
       lib/screens/home_screen.dart
git commit -m "feat: simplify greeting popup — icon-only badge, shorter voices, remove tease & button"
```

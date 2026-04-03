# Buddy-Only Voice Launch Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship with a single voice narrator (Buddy/George) to eliminate voice-switching bugs, cut build size by ~35MB, and focus quality on one consistent experience.

**Architecture:** Hardcode AudioService to buddy voice style, remove classic/boy asset declarations from the build, remove the narrator picker from settings, generate 2 missing Buddy voice files, add missing preload entries, and wire up the unused `voice_entry_hero_shop.mp3` entry voice (generating it for Buddy via ElevenLabs).

**Tech Stack:** Flutter/Dart, ElevenLabs MCP (TTS generation), audioplayers

**Context:** The app has 3 voice narrators — Jessica (classic), George (buddy), Liam (boy). Oliver's favorite is Buddy. Going single-voice eliminates a bug where missing files cause fallback to a different narrator's voice mid-session. The classic/ and boy/ asset directories stay on disk (git-tracked) but are excluded from the Flutter build.

---

## Task 1: Remove classic/boy voice assets from the Flutter build

**Files:**
- Modify: `pubspec.yaml:44-46`

This removes ~500 voice files from the APK. The files stay in the repo but Flutter won't bundle them.

- [ ] **Step 1: Edit pubspec.yaml — remove classic and boy asset declarations**

Remove lines 44 and 46, keeping only the buddy line:

```yaml
# BEFORE (lines 43-46):
    - assets/audio/voices/classic/
    - assets/audio/voices/buddy/
    - assets/audio/voices/boy/

# AFTER:
    - assets/audio/voices/buddy/
```

- [ ] **Step 2: Verify no build errors**

Run: `cd /Users/jimchabas/Projects/brush-quest && flutter build apk --debug 2>&1 | tail -5`

Expected: Build succeeds (the code already falls back to classic which will now just silently fail — we'll hardcode buddy in the next task).

- [ ] **Step 3: Commit**

```bash
git add pubspec.yaml
git commit -m "build: exclude classic/boy voice assets from APK — buddy only for launch"
```

---

## Task 2: Hardcode AudioService to buddy voice style

**Files:**
- Modify: `lib/services/audio_service.dart:47,61-65,75-81,479`
- Modify: `test/audio/fake_audio_service.dart:76-77`

- [ ] **Step 1: Change default voice style from 'classic' to 'buddy'**

In `lib/services/audio_service.dart`, line 47:

```dart
// BEFORE:
  String _voiceStyle = 'classic';

// AFTER:
  String _voiceStyle = 'buddy';
```

- [ ] **Step 2: Simplify voiceStyles to single entry**

In `lib/services/audio_service.dart`, lines 61-65:

```dart
// BEFORE:
  static const voiceStyles = {
    'classic': 'Jessica — warm & clear',
    'buddy': 'George — friendly guide',
    'boy': 'Liam — excited adventurer',
  };

// AFTER:
  static const voiceStyles = {
    'buddy': 'George — friendly guide',
  };
```

- [ ] **Step 3: Make setVoiceStyle a no-op (keep method for API compatibility)**

In `lib/services/audio_service.dart`, lines 75-81:

```dart
// BEFORE:
  Future<void> setVoiceStyle(String style) async {
    _voiceStyle = style;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('voice_style', style);
    // Fire-and-forget: preload in background so the UI stays responsive.
    unawaited(preloadAll());
  }

// AFTER:
  /// Voice style is locked to 'buddy' for launch.
  /// Kept as a no-op so callers (tests, settings reset) don't break.
  Future<void> setVoiceStyle(String style) async {
    // Locked to buddy for v1 launch — other styles remain on disk.
  }
```

- [ ] **Step 4: Hardcode preloadAll to always use buddy**

In `lib/services/audio_service.dart`, line 479:

```dart
// BEFORE:
    _voiceStyle = prefs.getString('voice_style') ?? 'classic';

// AFTER:
    _voiceStyle = 'buddy';
```

- [ ] **Step 5: Remove the fallback-to-classic logic in voice playback**

Find the fallback block in the `_pumpVoiceQueue` method (around line 603-614) that retries with 'classic' style. Since we're buddy-only, this fallback is no longer needed and would try to load unbundled assets. Remove or simplify:

Read the exact lines first, then change the catch block that attempts classic fallback to just skip the voice:

```dart
// BEFORE (approx lines 603-614):
      if (_voiceStyle != 'classic') {
        try {
          await _voicePlayer.play(AssetSource('audio/voices/classic/${request.fileName}'));
          // ... wait for completion
        } catch (_) {
          // Both styles failed — skip this voice
        }
      }

// AFTER:
      // Voice file missing — skip silently.
```

- [ ] **Step 6: Run tests**

Run: `cd /Users/jimchabas/Projects/brush-quest && flutter test`

Expected: All 664 tests pass. The FakeAudioService still has `setVoiceStyle` (it's a no-op in production now but the fake records the call — that's fine).

- [ ] **Step 7: Run dart analyze**

Run: `dart analyze lib/`

Expected: No issues.

- [ ] **Step 8: Commit**

```bash
git add lib/services/audio_service.dart
git commit -m "feat: lock voice narrator to buddy (George) for v1 launch"
```

---

## Task 3: Remove narrator voice selector from settings

**Files:**
- Modify: `lib/screens/settings_screen.dart:31,108,1194-1251`

- [ ] **Step 1: Remove the _voiceStyle state field**

In `lib/screens/settings_screen.dart`, line 31:

```dart
// BEFORE:
  String _voiceStyle = 'classic';

// AFTER: (delete this line entirely)
```

- [ ] **Step 2: Remove the _voiceStyle initialization in _loadSettings**

In `lib/screens/settings_screen.dart`, line 108:

```dart
// BEFORE:
        _voiceStyle = AudioService().voiceStyle;

// AFTER: (delete this line entirely)
```

- [ ] **Step 3: Remove the entire narrator voice _SettingCard widget**

In `lib/screens/settings_screen.dart`, remove lines 1193-1251 (the `SizedBox(height: 8)` before it through the closing `)` of the `_SettingCard`):

```dart
// DELETE this entire block (lines ~1193-1251):
        const SizedBox(height: 8),
        _SettingCard(
          icon: Icons.record_voice_over,
          title: 'Narrator voice',
          // ... entire SegmentedButton widget ...
        ),
```

- [ ] **Step 4: Keep voice_style in the reset keys list**

The reset keys list at line 641 includes `'voice_style'` — keep it so reset still clears any legacy preference. No change needed.

- [ ] **Step 5: Run dart analyze**

Run: `dart analyze lib/screens/settings_screen.dart`

Expected: No issues (no unused import, no dead code).

- [ ] **Step 6: Run tests**

Run: `cd /Users/jimchabas/Projects/brush-quest && flutter test`

Expected: All tests pass.

- [ ] **Step 7: Commit**

```bash
git add lib/screens/settings_screen.dart
git commit -m "feat: remove narrator voice picker from settings — buddy only for launch"
```

---

## Task 4: Fix preload gap — add voice_card_album_intro to preload list

**Files:**
- Modify: `lib/services/audio_service.dart` (_allAudioFiles list)

The trophy wall plays `voice_card_album_intro.mp3` but it's not in the preload list, so it may fail silently on first play.

- [ ] **Step 1: Add the missing entry to _allAudioFiles**

In `lib/services/audio_service.dart`, add after line 233 (after `'voice_card_new.mp3'`):

```dart
    'voice_card_new.mp3',
    'voice_card_album_intro.mp3',   // ← ADD THIS LINE
    'voice_world_map_intro.mp3',
```

- [ ] **Step 2: Verify the file exists for buddy**

Run: `ls /Users/jimchabas/Projects/brush-quest/assets/audio/voices/buddy/voice_card_album_intro.mp3`

Expected: File exists.

- [ ] **Step 3: Run tests**

Run: `cd /Users/jimchabas/Projects/brush-quest && flutter test`

Expected: All tests pass.

- [ ] **Step 4: Commit**

```bash
git add lib/services/audio_service.dart
git commit -m "fix: add voice_card_album_intro to preload list — was missing"
```

---

## Task 5: Generate 2 missing Buddy voice files via ElevenLabs

**Files:**
- Create: `assets/audio/voices/buddy/voice_streak_pair_bonus_high.mp3`
- Create: `assets/audio/voices/buddy/voice_streak_pair_bonus_low.mp3`

These files exist for classic/Jessica but are missing for buddy/George. They play on the home screen when a user has both morning+evening brushes done the previous day AND has a streak.

- [ ] **Step 1: Generate voice_streak_pair_bonus_high.mp3**

Use ElevenLabs MCP `text_to_speech` tool:
- Voice: George (ElevenLabs ID `JBFqnCBsd6RMkjVDRZzb`)
- Text: `"Nice work brushing twice yesterday. That's a double bonus on top of your streak. Keep it going, ranger."`
- Save to: `assets/audio/voices/buddy/voice_streak_pair_bonus_high.mp3`

The text matches George's calm mentor tone from MASTER_SCRIPT_V2.md. "High" variant is for streaks of 7+ days.

- [ ] **Step 2: Generate voice_streak_pair_bonus_low.mp3**

Use ElevenLabs MCP `text_to_speech` tool:
- Voice: George (same voice ID)
- Text: `"You brushed twice yesterday. That earns a bonus. Pair that with your streak and you're really building something."`
- Save to: `assets/audio/voices/buddy/voice_streak_pair_bonus_low.mp3`

"Low" variant is for streaks of 3-6 days.

- [ ] **Step 3: Verify both files exist and are valid MP3s**

Run: `file /Users/jimchabas/Projects/brush-quest/assets/audio/voices/buddy/voice_streak_pair_bonus_*.mp3`

Expected: Both show as "Audio file with ID3" or "MPEG audio".

- [ ] **Step 4: Commit**

```bash
git add assets/audio/voices/buddy/voice_streak_pair_bonus_high.mp3 assets/audio/voices/buddy/voice_streak_pair_bonus_low.mp3
git commit -m "feat: generate missing buddy streak pair bonus voices (George via ElevenLabs)"
```

---

## Task 6: Generate and wire hero shop entry voice for Buddy

**Files:**
- Create: `assets/audio/voices/buddy/voice_entry_hero_shop.mp3` (if missing)
- Modify: `lib/screens/hero_shop_screen.dart:51` (add entry voice call)
- Modify: `lib/services/audio_service.dart` (_allAudioFiles list)

The voice audit found `voice_entry_hero_shop.mp3` exists for Liam but is never called in code. The shop opens silently — a non-reading child doesn't know what it is.

- [ ] **Step 1: Check if buddy already has this file**

Run: `ls /Users/jimchabas/Projects/brush-quest/assets/audio/voices/buddy/voice_entry_hero_shop.mp3 2>&1`

If it exists, skip to Step 3. If not, generate it.

- [ ] **Step 2: Generate voice_entry_hero_shop.mp3 for Buddy**

Use ElevenLabs MCP `text_to_speech` tool:
- Voice: George (ElevenLabs ID `JBFqnCBsd6RMkjVDRZzb`)
- Text: `"Welcome to the hero shop. Pick your hero and your weapon. Use your stars to unlock new ones."`
- Save to: `assets/audio/voices/buddy/voice_entry_hero_shop.mp3`

- [ ] **Step 3: Add to preload list in audio_service.dart**

Add `'voice_entry_hero_shop.mp3'` to the `_allAudioFiles` list, after the shop nudge entries (around line 437):

```dart
    'voice_shop_nudge_tonight.mp3',
    'voice_entry_hero_shop.mp3',   // ← ADD THIS LINE
  ];
```

- [ ] **Step 4: Wire the entry voice in hero_shop_screen.dart**

In `lib/screens/hero_shop_screen.dart`, add after `_loadData();` (line 50), before `AnalyticsService().logShopVisit();`:

```dart
    _loadData();
    // Play entry voice on first visit (shop entry)
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        AudioService().playVoice(
          'voice_entry_hero_shop.mp3',
          clearQueue: true,
          interrupt: true,
        );
      }
    });
    AnalyticsService().logShopVisit();
```

- [ ] **Step 5: Run dart analyze**

Run: `dart analyze lib/screens/hero_shop_screen.dart`

- [ ] **Step 6: Run tests**

Run: `cd /Users/jimchabas/Projects/brush-quest && flutter test`

Expected: All tests pass.

- [ ] **Step 7: Commit**

```bash
git add assets/audio/voices/buddy/voice_entry_hero_shop.mp3 lib/screens/hero_shop_screen.dart lib/services/audio_service.dart
git commit -m "feat: play shop entry voice when hero shop opens (George/Buddy)"
```

---

## Task 7: Final verification

**Files:** None (read-only)

- [ ] **Step 1: Run full test suite**

Run: `cd /Users/jimchabas/Projects/brush-quest && flutter test`

Expected: All tests pass.

- [ ] **Step 2: Run dart analyze on full codebase**

Run: `dart analyze lib/`

Expected: No issues.

- [ ] **Step 3: Verify only buddy voice files are bundled**

Run: `grep -n 'voices/' /Users/jimchabas/Projects/brush-quest/pubspec.yaml`

Expected: Only `- assets/audio/voices/buddy/` appears.

- [ ] **Step 4: Verify no code references voiceStyles with multiple entries**

Run: `grep -rn "classic\|'boy'" lib/services/audio_service.dart | grep -v '//'`

Expected: No active code references to 'classic' or 'boy' (only comments).

- [ ] **Step 5: Build APK and check size reduction**

Run:
```bash
export JAVA_HOME="/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home"
flutter build apk 2>&1 | tail -3
ls -lh build/app/outputs/flutter-apk/app-release.apk
```

Expected: APK size reduced by ~30-40MB (from 139.8MB baseline).

---

## Summary of changes

| Task | Type | What |
|------|------|------|
| 1 | Build | Remove classic/boy from pubspec.yaml assets |
| 2 | Code | Hardcode AudioService to buddy, remove fallback |
| 3 | UI | Remove narrator picker from settings |
| 4 | Bug fix | Add voice_card_album_intro to preload list |
| 5 | Voice gen | Generate 2 missing buddy streak pair bonus files |
| 6 | Feature | Generate + wire hero shop entry voice |
| 7 | QA | Full verification pass |

**Files not touched (preserved for future multi-voice):**
- `assets/audio/voices/classic/` — 256 files stay in git
- `assets/audio/voices/boy/` — 256 files stay in git
- `test/audio/fake_audio_service.dart` — keeps `setVoiceStyle` method
- `test/services/sync_service_test.dart` — still tests `voice_style` sync key

**Deferred improvements (post-launch, when adding voices back):**
- Generate unique George script (distinct from Jessica's words)
- Generate 12 evolution picker voices for Liam
- Generate 2 streak pair bonus voices for Liam
- Wire remaining unused voices (great_job_morning/tonight, card_fragment, etc.)
- Add first-visit nav button voices (MAP/HEROES/MONSTERS)
- Add world unlock celebration voice

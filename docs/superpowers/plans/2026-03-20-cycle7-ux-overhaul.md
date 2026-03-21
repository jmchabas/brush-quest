# Cycle 7 UX Overhaul Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix 6 UX issues: remove pre-brush picker, add world intro auto-advance + better voice, add text encouragement variety, fix brushing performance, improve victory progress bar + voice, and redesign card reveal UX.

**Architecture:** Each stream modifies 1-2 files in `lib/screens/` or `lib/services/`. Voice generation uses ElevenLabs TTS via existing Python scripts. Performance work is isolated to `brushing_screen.dart` custom painters and particle systems.

**Tech Stack:** Flutter/Dart, ElevenLabs TTS API, SharedPreferences

---

## File Map

| Stream | Files Modified | Files Created |
|--------|---------------|---------------|
| 1. Kill Picker | `lib/screens/home_screen.dart` | — |
| 2. World Intro | `lib/screens/brushing_screen.dart` | `tmp/generate_world_voices.py` |
| 3. Text Variety | `lib/screens/brushing_screen.dart` | — |
| 4. Performance | `lib/screens/brushing_screen.dart` | — |
| 5. Progress Bar | `lib/screens/victory_screen.dart` | `tmp/generate_unlock_voices.py` |
| 6. Card UX | `lib/screens/victory_screen.dart`, `lib/screens/card_album_screen.dart` | — |

---

### Task 1: Remove Pre-Brush Picker Screen

**Files:**
- Modify: `lib/screens/home_screen.dart` (lines 408-470 `_showPreBrushPicker`, lines 1010-1331 `_PreBrushPicker` + `_PreBrushLoadoutScreen`)

- [ ] **Step 1: Modify `_startBrushingFlow` to skip picker entirely**

In `home_screen.dart`, replace `_showPreBrushPicker()` call in `_startBrushingFlow()` (line 372) with direct launch:

```dart
Future<void> _startBrushingFlow() async {
  final prefs = await SharedPreferences.getInstance();
  if (!mounted) return;
  if (!prefs.containsKey('camera_mode_configured')) {
    if (!prefs.containsKey('camera_enabled')) {
      await prefs.setBool('camera_enabled', false);
    }
    await prefs.setBool('camera_mode_configured', true);
  }

  AudioService().playVoice(
    'voice_lets_fight.mp3',
    clearQueue: true,
    interrupt: true,
  );
  Future.delayed(const Duration(milliseconds: 600), () {
    if (mounted) _launchBrushingScreen();
  });
}
```

- [ ] **Step 2: Make hero circle tap open Hero Shop instead of starting brushing**

Currently the hero circle (GestureDetector at line 711-716) calls `_startBrushing()`. Change it to open the Hero Shop. The BRUSH button tap area needs to be separated from the hero image tap.

Look at the existing build method around lines 695-760. The hero image and the "tap to brush" functionality are combined. Separate them:
- Tapping the hero **image** (inner circle, ~290px) → opens shop
- Add a separate explicit BRUSH button below the hero circle

Replace lines 711-716:
```dart
onTapDown: (_) => setState(() => _buttonPressed = true),
onTapUp: (_) {
  setState(() => _buttonPressed = false);
  _openShop();
},
onTapCancel: () => setState(() => _buttonPressed = false),
```

Then add a visible BRUSH button below the hero circle (after the hero Column widget, before the bottom nav). Use a simple styled button:

```dart
const SizedBox(height: 16),
GestureDetector(
  onTap: _startBrushing,
  child: AnimatedBuilder(
    animation: _tapPulseAnimation,
    builder: (context, child) {
      return Transform.scale(
        scale: 1.0 + _tapPulseAnimation.value * 0.03,
        child: child,
      );
    },
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _selectedHero.primaryColor,
            _selectedHero.primaryColor.withValues(alpha: 0.7),
          ],
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: _selectedHero.primaryColor.withValues(alpha: 0.5),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: const Text(
        'BRUSH!',
        style: TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.bold,
          letterSpacing: 4,
        ),
      ),
    ),
  ),
),
```

- [ ] **Step 3: Delete dead code**

Remove:
- `_showPreBrushPicker()` method (lines 408-464)
- `_playPickerVoice()` method (lines 466-470)
- `_lastPickerVoice` field (line 56)
- `_PreBrushPicker` class (lines 1010-1035)
- `_PreBrushLoadoutScreen` class (lines 1037-1089)
- `_PreBrushPickerState` class (lines 1091-1331)

- [ ] **Step 4: Run quality gates**

```bash
cd /Users/jimchabas/Projects/brush-quest && dart analyze lib/screens/home_screen.dart
flutter test
```

- [ ] **Step 5: Commit**

```bash
git add lib/screens/home_screen.dart
git commit -m "Remove pre-brush picker — hero tap opens shop, BRUSH button goes straight to battle"
```

---

### Task 2: World Intro — Auto-advance Timer + Voice Scripts

**Files:**
- Modify: `lib/screens/brushing_screen.dart` (lines 880-913 `_startWorldIntro` / `_dismissWorldIntro` / `_playWorldMissionBriefing`, lines 1825-1906 `_buildWorldIntro`)
- Create: `tmp/generate_world_voices.py`

- [ ] **Step 1: Add 10-second auto-advance timer to world intro**

In `_startWorldIntro()` (line 880), add a 10-second timer:

```dart
void _startWorldIntro() {
  _worldIntroTimer?.cancel();
  setState(() {
    _showWorldIntro = true;
    _sessionStage = SessionStage.worldIntro;
  });
  _playWorldMissionBriefing();

  // Auto-advance after 10 seconds
  _worldIntroTimer = Timer(const Duration(seconds: 10), () {
    if (mounted && _showWorldIntro) {
      _dismissWorldIntro();
    }
  });
}
```

Note: `_worldIntroTimer` already exists as a field and is cancelled in `_dismissWorldIntro()` and `dispose()`.

- [ ] **Step 2: Add countdown ring to world intro UI**

In `_buildWorldIntro()` (line 1825), add a circular countdown indicator around the planet image. Add a local `_worldIntroStartTime` field and use it to calculate progress.

Add field near line 334:
```dart
DateTime? _worldIntroStartTime;
```

Set it in `_startWorldIntro`:
```dart
_worldIntroStartTime = DateTime.now();
```

In `_buildWorldIntro`, wrap the planet Container (lines 1860-1876) with a `TweenAnimationBuilder` for the countdown ring:

```dart
TweenAnimationBuilder<double>(
  tween: Tween(begin: 1.0, end: 0.0),
  duration: const Duration(seconds: 10),
  builder: (context, value, child) {
    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          width: 156,
          height: 156,
          child: CircularProgressIndicator(
            value: value,
            strokeWidth: 3,
            backgroundColor: Colors.white.withValues(alpha: 0.1),
            valueColor: AlwaysStoppedAnimation(
              _world.themeColor.withValues(alpha: 0.6),
            ),
          ),
        ),
        child!,
      ],
    );
  },
  child: /* existing planet Container */,
),
```

- [ ] **Step 3: Remove redundant text from world intro UI**

Remove the description text lines (currently "Cavity monsters are hiding in FROZEN TUNDRA" + description + "Brush your teeth to defeat them!"). Keep only the world name and the pulsing tap-to-fight button. The voice now covers all the context.

Delete the text widgets between the world name and the `_PulsingTapToFight` button (approximately the area between lines 1894-1896 — check for any Text widgets showing `_world.description` or "Cavity monsters" text).

- [ ] **Step 4: Write voice generation script for mission briefings**

Create `tmp/generate_world_voices.py` that generates 10 world-specific mission briefing voices using the ElevenLabs API. Each voice should follow this pattern:

"Space Ranger! Cavity monsters are hiding in [World Name] — [contextual description]. Get your toothbrush ready!"

World scripts:
1. **candy_crater**: "Space Ranger! Cavity monsters are hiding in the Candy Crater — a sweet planet covered in candy and sugar crystals! Get your toothbrush ready and fight them off!"
2. **slime_swamp**: "Space Ranger! Cavity monsters are hiding in the Slime Swamp — a gooey planet full of slimy creatures! Get your toothbrush ready and fight them off!"
3. **sugar_volcano**: "Space Ranger! Cavity monsters are hiding in the Sugar Volcano — a fiery planet with erupting volcanoes! Get your toothbrush ready and fight them off!"
4. **shadow_nebula**: "Space Ranger! You're heading into the Shadow Nebula — a mysterious dark planet full of spooky surprises! Get your toothbrush ready and fight them off!"
5. **cavity_fortress**: "Space Ranger! You've reached the Cavity Fortress — the Cavity King's stronghold! This is a big challenge! Get your toothbrush ready!"
6. **frozen_tundra**: "Space Ranger! Cavity monsters are hiding in the Frozen Tundra — an icy planet with blizzards and frozen monsters! Get your toothbrush ready and fight them off!"
7. **toxic_jungle**: "Space Ranger! You're entering the Toxic Jungle — a poisonous jungle with venomous creatures! Get your toothbrush ready and fight them off!"
8. **crystal_cave**: "Space Ranger! You're exploring the Crystal Cave — underground caverns filled with glowing crystals! Get your toothbrush ready and fight them off!"
9. **storm_citadel**: "Space Ranger! You're approaching the Storm Citadel — a floating fortress in a lightning storm! Get your toothbrush ready and fight them off!"
10. **dark_dimension**: "Space Ranger! You're entering the Dark Dimension — the final dark realm beyond space and time! This is the ultimate challenge! Get your toothbrush ready!"

Use the same ElevenLabs voice settings as existing voice files:
- Voice: `cgSgspJ2msm6clMCkdW9` (Jessica) OR current `voiceStyle` buddy voice
- Stability: 0.35, Style: 0.2, Speed: 0.95
- Output: `assets/audio/voices/classic/voice_world_[id].mp3` and `assets/audio/voices/buddy/voice_world_[id].mp3`

- [ ] **Step 5: Generate the voice files**

```bash
cd /Users/jimchabas/Projects/brush-quest
python3 tmp/generate_world_voices.py
```

- [ ] **Step 6: Run quality gates**

```bash
dart analyze lib/screens/brushing_screen.dart
flutter test
```

- [ ] **Step 7: Commit**

```bash
git add lib/screens/brushing_screen.dart tmp/generate_world_voices.py assets/audio/voices/
git commit -m "World intro: auto-advance timer, countdown ring, mission briefing voices"
```

---

### Task 3: Text Encouragement Variety

**Files:**
- Modify: `lib/screens/brushing_screen.dart` (lines 1655-1662 `_getEncouragementText`)

- [ ] **Step 1: Add text variant pools and per-phase selection**

Add a field to track the selected text variant index per phase, near the existing `_playedEncouragement` fields (line 416):

```dart
int _encouragementTextVariant = 0;
```

Add text pools as a static const:

```dart
static const _encouragementTextPools = {
  'attack': ['BRUSH TO ATTACK!', 'FIGHT THAT MONSTER!', 'KEEP GOING!', 'ATTACK!'],
  'mid': ['KEEP BRUSHING!', "DON'T STOP!", "YOU'VE GOT THIS!", 'POWER UP!'],
  'almost': ['ALMOST THERE!', 'NEARLY DONE!', 'SO CLOSE!', 'FINAL PUSH!'],
  'finish': ['FINISH IT OFF!', 'ONE MORE HIT!', 'TAKE IT DOWN!', 'LAST STRIKE!'],
};
```

- [ ] **Step 2: Select variant per phase, not per second**

In `_pickNextArc()` (line 1475), also pick the text variant:

```dart
void _pickNextArc() {
  int next = _random.nextInt(_encouragementArcs.length);
  while (next == _lastArcIndex && _encouragementArcs.length > 1) {
    next = _random.nextInt(_encouragementArcs.length);
  }
  _lastArcIndex = next;
  _currentArcIndex = next;
  _encouragementTextVariant = _random.nextInt(4); // pick text variant for this phase
}
```

- [ ] **Step 3: Update `_getEncouragementText` to use pools**

Replace lines 1655-1662:

```dart
String _getEncouragementText() {
  final v = _encouragementTextVariant;
  if (_phaseSecondsLeft > 20) {
    return _encouragementTextPools['attack']![v];
  }
  if (_phaseSecondsLeft > 10) return _encouragementTextPools['mid']![v];
  if (_phaseSecondsLeft > 5) return _encouragementTextPools['almost']![v];
  return _encouragementTextPools['finish']![v];
}
```

- [ ] **Step 4: Run quality gates**

```bash
dart analyze lib/screens/brushing_screen.dart
flutter test
```

- [ ] **Step 5: Commit**

```bash
git add lib/screens/brushing_screen.dart
git commit -m "Add text encouragement variety: 4 variants per time bucket, selected per phase"
```

---

### Task 4: Brushing Screen Performance Optimization

**Files:**
- Modify: `lib/screens/brushing_screen.dart`

- [ ] **Step 1: Cap damage popups at 15**

In `_spawnDamagePopup` and `_triggerMicroReward` (lines ~1516 and ~1446), add a cap after adding new popups:

```dart
// After adding to _damagePopups:
while (_damagePopups.length > 15) {
  _damagePopups.removeAt(0); // drop oldest
}
```

Add this cap in both `_spawnDamagePopup()` and `_triggerMicroReward()` and the finisher popup in `_triggerFinisher()`.

- [ ] **Step 2: Fix `shouldRepaint` on particle and spark painters**

Replace `shouldRepaint` in `_WorldParticlePainter` (line 3336):

```dart
@override
bool shouldRepaint(_WorldParticlePainter oldDelegate) =>
    particles.length != oldDelegate.particles.length;
```

Replace `shouldRepaint` in `_HitSparkPainter` (line 3378):

```dart
@override
bool shouldRepaint(_HitSparkPainter oldDelegate) =>
    sparks.length != oldDelegate.sparks.length || sparks.isNotEmpty;
```

Note: Since sparks move every frame, we still need to repaint when there ARE sparks. But when the list is empty (most of the time between attacks), we skip repainting.

- [ ] **Step 3: Reduce particle counts**

In particle initialization (search for `_particles` list creation, approximately around `_prepareSession` or initialization), reduce ambient world particles from 30 → 20:

Find where particles are initialized (search for a loop creating 30 particles) and change to 20.

Reduce regular hit sparks from 8 → 5 in the attack handler (search for `for (int i = 0; i < 8;` in the attack/hit code around line 1548):

```dart
for (int i = 0; i < 5; i++) {
```

Reduce finisher sparks from 30 → 18 (line 1143):
```dart
for (int i = 0; i < 18; i++) {
```

Reduce defeat sparks from 20 → 12 (search for the defeat spark spawn):
```dart
// Reduce from 20 to 12
```

- [ ] **Step 4: Reduce blur filter usage in hit spark painter**

In `_HitSparkPainter.paint()` (line 3343), remove the double-blur (both paint and glowPaint have MaskFilter). Keep only one:

```dart
void paint(Canvas canvas, Size size) {
  final cx = size.width / 2;
  final cy = size.height * 0.35;
  for (final s in sparks) {
    if (s.life <= 0) continue;
    final paint = Paint()
      ..color = s.color.withValues(alpha: s.life.clamp(0, 1))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    final px = cx + s.x;
    final py = cy + s.y;
    final r = s.size * s.life;

    final path = Path();
    for (int i = 0; i < 4; i++) {
      final outerAngle = i * pi / 2;
      final innerAngle = outerAngle + pi / 4;
      if (i == 0) {
        path.moveTo(px + cos(outerAngle) * r, py + sin(outerAngle) * r);
      } else {
        path.lineTo(px + cos(outerAngle) * r, py + sin(outerAngle) * r);
      }
      path.lineTo(px + cos(innerAngle) * r * 0.4, py + sin(innerAngle) * r * 0.4);
    }
    path.close();
    canvas.drawPath(path, paint);
  }
}
```

- [ ] **Step 5: Stagger finisher effects**

In `_triggerFinisher()` (around line 1125), add slight delays between effects instead of firing all at once:

```dart
// Existing: all fire simultaneously
// New: stagger with small delays
_attackSequenceController.forward(from: 0);
_flashController.forward(from: 0).then((_) { if (mounted) _flashController.reverse(); });
HapticFeedback.heavyImpact();
_audio.playSfx('zap.mp3');

// Delay screen shake slightly
Future.delayed(const Duration(milliseconds: 50), () {
  if (mounted) _screenShakeController.forward(from: 0);
});

// Delay shockwave a bit more
Future.delayed(const Duration(milliseconds: 100), () {
  if (mounted) _shockwaveController.forward(from: 0);
});

// Delay spark burst
Future.delayed(const Duration(milliseconds: 80), () {
  if (!mounted) return;
  for (int i = 0; i < 18; i++) {
    // ... spark creation
  }
});
```

- [ ] **Step 6: Fix slow-motion frame skip determinism**

In `_updateParticlesAndSparks()` (line 637), replace random skip with deterministic frame counter:

Add field:
```dart
int _slowMotionFrame = 0;
```

Replace line 637:
```dart
if (_slowMotion) {
  _slowMotionFrame++;
  if (_slowMotionFrame % 2 == 0) return;
}
```

- [ ] **Step 7: Run quality gates**

```bash
dart analyze lib/screens/brushing_screen.dart
flutter test
```

- [ ] **Step 8: Commit**

```bash
git add lib/screens/brushing_screen.dart
git commit -m "Performance: cap popups, fix shouldRepaint, reduce particles, stagger finisher, fix slow-mo"
```

---

### Task 5: Victory Progress Bar — Show What's Next + Voice

**Files:**
- Modify: `lib/screens/victory_screen.dart` (lines 1011-1129 progress bar widget, lines 521-528 next-unlock voice)
- Create: `tmp/generate_unlock_voices.py`

- [ ] **Step 1: Add name label to progress bar**

In the progress bar widget (lines 1011-1129), add the unlock name below the progress bar. After the existing Row with icon + progress + stars, add:

```dart
// After the progress bar Row (line 1129), add:
if (_nextUnlockName != null && _starsToNextUnlock > 0)
  Padding(
    padding: const EdgeInsets.only(top: 6, left: 54, right: 40),
    child: Text(
      '$_starsToNextUnlock more to unlock $_nextUnlockName!',
      style: TextStyle(
        color: _nextUnlockColor.withValues(alpha: 0.9),
        fontSize: 13,
        fontWeight: FontWeight.w600,
        shadows: [
          Shadow(
            color: _nextUnlockColor.withValues(alpha: 0.5),
            blurRadius: 6,
          ),
        ],
      ),
    ),
  ),
```

- [ ] **Step 2: Make the unlock icon larger and clearer**

In the progress bar icon Container (lines 1023-1071), increase from 44x44 to 56x56 and remove the desaturation + lock overlay so the kid can see what they're working toward:

```dart
Container(
  width: 56,
  height: 56,
  decoration: BoxDecoration(
    shape: _nextUnlockIsHero ? BoxShape.circle : BoxShape.rectangle,
    borderRadius: _nextUnlockIsHero ? null : BorderRadius.circular(12),
    border: Border.all(color: _nextUnlockColor, width: 2.5),
    boxShadow: [
      BoxShadow(
        color: _nextUnlockColor.withValues(alpha: 0.5),
        blurRadius: 12,
        spreadRadius: 2,
      ),
    ],
  ),
  child: ClipRRect(
    borderRadius: BorderRadius.circular(_nextUnlockIsHero ? 28 : 10),
    child: Image.asset(
      _nextUnlockImagePath!,
      width: 52,
      height: 52,
      fit: BoxFit.cover,
    ),
  ),
),
```

- [ ] **Step 3: Replace generic encouragement voice with per-unlock voice**

In victory_screen.dart, add a static map of unlock voice files:

```dart
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
  'cosmic_shield': 'voice_unlock_next_cosmic_shield.mp3',
};
```

Add a field to track the next unlock ID:
```dart
String? _nextUnlockId;
```

Set `_nextUnlockId` in `_computeNextUnlock()` alongside `_nextUnlockName`:
```dart
_nextUnlockId = pickHero ? nextHero!.id : nextWeapon!.id;
```

Replace lines 524-527 (the generic encouragement) with specific unlock voice:

```dart
} else if (_nextUnlockName != null && _starsToNextUnlock > 0 && mounted) {
  final unlockVoice = _unlockVoices[_nextUnlockId];
  if (unlockVoice != null) {
    _audio.playVoice(unlockVoice);
  } else {
    _audio.playVoice(
      _chestEncouragements[_random.nextInt(_chestEncouragements.length)],
    );
  }
}
```

- [ ] **Step 4: Write voice generation script**

Create `tmp/generate_unlock_voices.py` that generates per-hero and per-weapon unlock encouragement voices:

Scripts (10 total — skip defaults blaze + star_blaster since they're unlocked at 0):
- **frost**: "Keep brushing to unlock Frost the Ice Wolf! You're getting closer!"
- **bolt**: "Keep brushing to unlock Bolt the Lightning Robot! You're almost there!"
- **shadow**: "Keep brushing to unlock Shadow the Ninja Cat! So close!"
- **leaf**: "Keep brushing to unlock Leaf the Nature Guardian! You're getting closer!"
- **nova**: "Keep brushing to unlock Nova the Cosmic Phoenix! The ultimate hero!"
- **flame_sword**: "Keep brushing to unlock the Flame Sword! Fiery power awaits!"
- **ice_hammer**: "Keep brushing to unlock the Ice Hammer! Freezing power awaits!"
- **lightning_wand**: "Keep brushing to unlock the Lightning Wand! Electric power awaits!"
- **vine_whip**: "Keep brushing to unlock the Vine Whip! Nature power awaits!"
- **cosmic_shield**: "Keep brushing to unlock the Cosmic Shield! Ultimate defense awaits!"

Same ElevenLabs settings as other voices.

- [ ] **Step 5: Generate the voice files**

```bash
python3 tmp/generate_unlock_voices.py
```

- [ ] **Step 6: Run quality gates**

```bash
dart analyze lib/screens/victory_screen.dart
flutter test
```

- [ ] **Step 7: Commit**

```bash
git add lib/screens/victory_screen.dart tmp/generate_unlock_voices.py assets/audio/voices/
git commit -m "Victory: show next unlock name + icon, play per-unlock encouragement voice"
```

---

### Task 6: Card UX — Full Reveal on Victory + Album Navigation

**Files:**
- Modify: `lib/screens/victory_screen.dart` (lines 553-590 `_buildCardDropReveal`, line 540-543 `_openCardAlbum`)
- Modify: `lib/screens/card_album_screen.dart` (constructor, `_loadData`, card tile highlighting)

- [ ] **Step 1: Add full-screen card detail overlay on victory**

Replace the current small card thumbnail reveal in `_buildCardDropReveal()` (lines 553-590+) with a larger full-screen card detail view:

The card reveal should show:
- Large monster image (140x140) with rarity glow
- Card name in bold
- Rarity badge (COMMON / RARE / EPIC with appropriate color)
- Flavor text
- "NEW!" or "POWER UP!" badge

```dart
Widget _buildCardDropReveal() {
  final drop = _cardDrop!;
  final card = drop.card;
  final glowColor = _rarityGlowColor(card.rarity);
  final rarityLabel = card.rarity.name.toUpperCase();

  return AnimatedBuilder(
    animation: Listenable.merge([_cardFlyController, _cardGlowController]),
    builder: (context, _) {
      final flyProgress = Curves.easeOutBack.transform(
        _cardFlyController.value.clamp(0.0, 1.0),
      );
      final glowPulse = _cardGlowController.value;
      final cardScale = flyProgress;
      final cardOpacity = flyProgress.clamp(0.0, 1.0);

      return Opacity(
        opacity: cardOpacity,
        child: Transform.scale(
          scale: cardScale,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Column(
              children: [
                // Full card reveal
                Container(
                  width: 200,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A0A3E),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: glowColor.withValues(alpha: 0.6 + glowPulse * 0.4),
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: glowColor.withValues(alpha: 0.3 + glowPulse * 0.3),
                        blurRadius: 20 + glowPulse * 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // NEW! / POWER UP! badge
                      if (_newBadgeController.value > 0)
                        ScaleTransition(
                          scale: CurvedAnimation(
                            parent: _newBadgeController,
                            curve: Curves.elasticOut,
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: drop.isNew
                                  ? const Color(0xFF00E676)
                                  : const Color(0xFFFFD740),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              drop.isNew ? 'NEW!' : 'POWER UP!',
                              style: const TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                      // Monster image
                      Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: glowColor.withValues(alpha: 0.3),
                              blurRadius: 12,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.asset(
                            'assets/images/monster_${card.baseImageIndex + 1}.png',
                            fit: BoxFit.cover,
                            color: card.tintColor.withValues(alpha: 0.3),
                            colorBlendMode: BlendMode.overlay,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Card name
                      Text(
                        card.name,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Rarity
                      Text(
                        rarityLabel,
                        style: TextStyle(
                          color: glowColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // World progress
                if (_showWorldProgress) ...[
                  Text(
                    _worldJustCompleted
                        ? 'WORLD COMPLETE!'
                        : '${_cardDrop!.worldCollected}/${_cardDrop!.worldTotal} ${_world.name} monsters found!',
                    style: TextStyle(
                      color: _worldJustCompleted
                          ? Colors.yellowAccent
                          : Colors.white70,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: () => _openCardAlbum(highlightCardId: drop.card.id),
                  child: const Text(
                    'Tap to see album >',
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
```

- [ ] **Step 2: Pass card ID to album screen**

Update `_openCardAlbum` to accept and pass the card ID:

```dart
void _openCardAlbum({String? highlightCardId}) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => CardAlbumScreen(highlightCardId: highlightCardId),
    ),
  );
}
```

- [ ] **Step 3: Update CardAlbumScreen to accept and highlight a card**

In `card_album_screen.dart`, add `highlightCardId` parameter:

```dart
class CardAlbumScreen extends StatefulWidget {
  final String? highlightCardId;
  const CardAlbumScreen({super.key, this.highlightCardId});

  @override
  State<CardAlbumScreen> createState() => _CardAlbumScreenState();
}
```

Add highlight state:
```dart
String? _highlightCardId;
late AnimationController _highlightController;
```

Initialize in `initState`:
```dart
_highlightCardId = widget.highlightCardId;
```

If a `highlightCardId` is provided, find which world page it belongs to and jump there:

In `_loadData()`, after existing page jump logic:

```dart
// If a specific card should be highlighted, find its world page
if (widget.highlightCardId != null) {
  final card = CardService.allCards.firstWhere(
    (c) => c.id == widget.highlightCardId,
    orElse: () => CardService.allCards.first,
  );
  final worldIdx = unlocked.indexOf(card.worldId);
  if (worldIdx >= 0) {
    _pageController.jumpToPage(worldIdx);
    _currentPage = worldIdx;
  }
}
```

- [ ] **Step 4: Add highlight glow animation on the target card**

In the card tile builder, add a glow effect when card ID matches `_highlightCardId`:

Add an `AnimationController` for the highlight glow in `initState`:
```dart
_highlightController = AnimationController(
  duration: const Duration(milliseconds: 800),
  vsync: this,
)..repeat(reverse: true);
```

Dispose in `dispose()`:
```dart
_highlightController.dispose();
```

In the card tile widget, wrap the card in an `AnimatedBuilder` when it matches the highlight:

```dart
final isHighlighted = card.id == _highlightCardId;
// In the card tile decoration, add conditional glow:
if (isHighlighted)
  BoxShadow(
    color: _rarityGlowColor(card.rarity).withValues(
      alpha: 0.4 + _highlightController.value * 0.4,
    ),
    blurRadius: 12 + _highlightController.value * 8,
    spreadRadius: 2,
  ),
```

Clear the highlight after 3 seconds:
```dart
if (widget.highlightCardId != null) {
  Future.delayed(const Duration(seconds: 3), () {
    if (mounted) setState(() => _highlightCardId = null);
  });
}
```

- [ ] **Step 5: Run quality gates**

```bash
dart analyze lib/screens/victory_screen.dart lib/screens/card_album_screen.dart
flutter test
```

- [ ] **Step 6: Commit**

```bash
git add lib/screens/victory_screen.dart lib/screens/card_album_screen.dart
git commit -m "Card UX: full reveal on victory, album opens to exact card with highlight"
```

---

### Task 7: Build, Upload & Release

- [ ] **Step 1: Run full test suite**

```bash
cd /Users/jimchabas/Projects/brush-quest
flutter test
```

- [ ] **Step 2: Build release APK**

```bash
export JAVA_HOME="/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home"
export PATH="$JAVA_HOME/bin:$PATH"
flutter build apk
```

- [ ] **Step 3: Upload APK to Google Drive**

```bash
rclone copy build/app/outputs/flutter-apk/app-release.apk "gdrive:Projects/Brush-quest/"
```

- [ ] **Step 4: Create GitHub Release**

```bash
gh release create v1.1.0 build/app/outputs/flutter-apk/app-release.apk \
  --title "v1.1.0 — Cycle 7 UX Overhaul" \
  --notes "Removed pre-brush picker, world intro auto-advance, text variety, performance optimizations, improved victory progress, card UX redesign"
```

- [ ] **Step 5: Update landing page download link if needed**

Check that `brushquest.app/get` points to the latest GitHub Release (it should auto-resolve to latest).

- [ ] **Step 6: Commit any remaining changes**

```bash
git add -A
git commit -m "Cycle 7: UX overhaul — 6 streams shipped"
```

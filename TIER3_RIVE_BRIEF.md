# Tier 3: Rive Animations & Advanced Effects — Session Brief

> Use this file to run a parallel Claude Code session for Tier 3 graphics work.
> Prompt: "Read TIER3_RIVE_BRIEF.md and implement Tier 3 of the graphics overhaul"

---

## Context

The battle screen (`lib/screens/brushing_screen.dart`) currently uses static PNG images with procedural transforms (squash/stretch, wobble, recoil) for both monsters and heroes. Tier 1 & 2 improvements (hit flash, hit stop, ghost health bar, combo counter, Lottie overlays, star particles, eye blink) have been implemented in the current session.

The goal of Tier 3 is to **replace static PNGs with real animated characters** for a dramatic visual leap.

---

## Option A: Rive Animations (Recommended)

### What is Rive?
[Rive](https://rive.app/) is an interactive animation engine with excellent Flutter support. It lets you create characters with **state machine-driven** animations in a single `.riv` file, controlled from Dart code.

### What to build in the Rive Editor (rive.app)
For each monster (start with 1 prototype, then scale to 4 base monsters):

1. **Idle state**: Breathing loop — chest expansion, slight bob, eye blinks every 3-5s
2. **Hit state**: Recoil + flash + squash, triggered from Dart on attack
3. **Angry state**: Faster breathing, red glow, shake — triggered when HP < 30%
4. **Death state**: Explosion/dissolve sequence — triggered on defeat

For each hero (start with 1 prototype):
1. **Idle state**: Breathing + subtle bob
2. **Attack state**: Lunge forward with weapon swing
3. **Power-up state**: Glow intensifies (triggered by motion detection)

### Flutter Integration
```dart
// pubspec.yaml
dependencies:
  rive: ^0.13.0

// In brushing_screen.dart, replace _buildBigMonster():
RiveAnimation.asset(
  'assets/rive/monster_base.riv',
  fit: BoxFit.contain,
  stateMachines: ['MonsterStateMachine'],
  onInit: (artboard) {
    final controller = StateMachineController.fromArtboard(artboard);
    artboard.addController(controller!);
    _monsterHitTrigger = controller.findInput<bool>('hit') as SMITrigger;
    _monsterHealthInput = controller.findInput<double>('health') as SMINumber;
    _monsterDeathTrigger = controller.findInput<bool>('death') as SMITrigger;
  },
);

// On attack:
_monsterHitTrigger.fire();
_monsterHealthInput.value = currentHealthPercent;

// On defeat:
_monsterDeathTrigger.fire();
```

### Rive State Machine Design
```
MonsterStateMachine:
  Inputs:
    - health (Number, 0-100)
    - hit (Trigger)
    - death (Trigger)

  States:
    - Idle (default) → plays breathing loop
    - Hit (on hit trigger) → plays recoil, returns to Idle
    - Angry (when health < 30) → faster breathing, red overlay
    - Death (on death trigger) → explosion sequence, stays

  Transitions:
    - Idle → Hit: on "hit" trigger
    - Idle → Angry: when "health" < 30
    - Angry → Hit: on "hit" trigger
    - Any → Death: on "death" trigger
```

### Asset Organization
```
assets/
  rive/
    monster_purple.riv
    monster_green.riv
    monster_orange.riv
    monster_red.riv
    hero_shadow.riv
    hero_blaze.riv
    ... (one per character)
```

### What to Remove When Rive is Added
These procedural systems in brushing_screen.dart become unnecessary:
- `_monsterBreathController` and its AnimatedBuilder
- `_MonsterEyeGlowPainter`
- `_MonsterDripPainter`
- `_DamageCrackPainter`
- `_MonsterOverlayPainter` (dizzy eyes)
- `_MonsterDeathPainter` (debris explosion)
- The squash/stretch/wobble math in `_buildBigMonster()`
- `_heroIdleController` and its AnimatedBuilder
- The attack lunge transform in `_buildHero()`

Keep these (they layer on top):
- `_HitSparkPainter` (particle effects around the character)
- `_EnergyRingPainter` (orbiting particles)
- `_WeaponBattleEffectPainter` (weapon slash/beam effects)
- `_flashController` (screen flash)
- `_screenShakeController` (screen shake)
- Lottie overlays (hit_pow, explosion, etc.)
- Damage popup text

---

## Option B: Sprite Sheet Animations (Simpler Alternative)

If Rive feels like too much, sprite sheets are a lighter approach:

### Generate Sprite Sheets
Use DALL-E/gpt-image-1 to create 3-4 frames per monster in the existing art style:
1. Frame 1: Normal pose (existing image)
2. Frame 2: Slightly compressed (breathing in)
3. Frame 3: Slightly expanded (breathing out)
4. Frame 4: Hit reaction (leaning back, eyes squeezed)

Arrange in a horizontal strip PNG (e.g., 2048x512 for 4x 512px frames).

### Flutter Implementation
```dart
class SpriteSheetAnimation extends StatefulWidget {
  final String assetPath;
  final int frameCount;
  final Duration frameDuration;
  final int currentFrame; // controlled externally

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: Align(
        alignment: Alignment(-1.0 + (2.0 * currentFrame / (frameCount - 1)), 0),
        widthFactor: 1.0 / frameCount,
        child: Image.asset(assetPath),
      ),
    );
  }
}
```

### Frame Cycling Logic
```dart
// Idle: cycle frames 0→1→2→1→0 at 200ms per frame
// Hit: jump to frame 3 for 150ms, then back to idle
// Death: play all frames rapidly + overlay effects
```

---

## Option C: Fragment Shaders (Additive, pairs with A or B)

### Dissolve Death Effect
```glsl
// assets/shaders/dissolve.frag
#version 460 core
precision mediump float;

#include <flutter/runtime_effect.glsl>

uniform float progress;    // 0.0 = fully visible, 1.0 = fully dissolved
uniform vec2 resolution;
uniform sampler2D image;

// Simple noise function
float hash(vec2 p) {
  return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

out vec4 fragColor;

void main() {
  vec2 uv = FlutterFragCoord().xy / resolution;
  vec4 color = texture(image, uv);
  float noise = hash(uv * 20.0);

  // Dissolve from edges inward
  float edge = smoothstep(progress - 0.1, progress, noise);

  // Glow at dissolve edge
  float glow = smoothstep(progress - 0.15, progress - 0.05, noise)
             - smoothstep(progress - 0.05, progress, noise);

  color.rgb += vec3(1.0, 0.5, 0.0) * glow * 3.0; // Orange glow at edge
  color.a *= edge;

  fragColor = color;
}
```

### Flutter Integration
```dart
// Load shader
final program = await FragmentProgram.fromAsset('assets/shaders/dissolve.frag');
final shader = program.fragmentShader();

// In CustomPainter:
shader.setFloat(0, dissolveProgress); // 0.0 → 1.0
shader.setFloat(1, size.width);
shader.setFloat(2, size.height);
shader.setImageSampler(0, monsterImage);
canvas.drawRect(rect, Paint()..shader = shader);
```

---

## Recommended Order for Tier 3 Session

1. **Start with 1 Rive monster prototype** — design in rive.app editor, export .riv, integrate in Flutter
2. **Test the state machine** — verify hit/death triggers work from Dart
3. **If Rive works well**, create the remaining 3 monster base files + 1 hero
4. **Add dissolve shader** as the death effect (pairs beautifully with Rive)
5. **Scale to all 6 heroes** last (heroes are simpler — fewer states)

## Current Monster Assets (for reference when recreating in Rive)
- `assets/images/monster_purple.png` — 47KB, purple base
- `assets/images/monster_green.png` — 106KB, green base
- `assets/images/monster_orange.png` — 90KB, orange base
- `assets/images/monster_red.png` — 74KB, red base

Each monster gets procedurally tinted with one of 9 personality colors at runtime. The Rive version should accept a color tint input to maintain this variety.

## Current Hero Assets
- `hero_blaze.png`, `hero_shadow.png`, `hero_bolt.png`, `hero_leaf.png`, `hero_frost.png`, `hero_nova.png`
- Each ~50-130KB, rendered at 120px in battle

## Key Files to Modify
- `lib/screens/brushing_screen.dart` — main battle screen (~2800 lines)
- `pubspec.yaml` — add rive dependency
- `assets/` — add rive/ and shaders/ directories

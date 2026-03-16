import 'package:flutter/material.dart';

/// Displays a single frame from a horizontal sprite strip.
///
/// The sprite strip is a horizontal PNG containing [frameCount] frames
/// side by side, each [frameSize] x [frameSize] pixels.
class SpriteFrame extends StatelessWidget {
  final String assetPath;
  final int frameCount;
  final int currentFrame;
  final double width;
  final double height;

  const SpriteFrame({
    super.key,
    required this.assetPath,
    required this.frameCount,
    required this.currentFrame,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final clampedFrame = currentFrame.clamp(0, frameCount - 1);
    // Use FittedBox + Alignment to show only the current frame
    return SizedBox(
      width: width,
      height: height,
      child: ClipRect(
        child: Align(
          alignment: Alignment(
            // Map frame index to -1.0 ... 1.0 range
            frameCount <= 1
                ? 0.0
                : -1.0 + (2.0 * clampedFrame / (frameCount - 1)),
            0.0,
          ),
          widthFactor: 1.0 / frameCount,
          child: Image.asset(
            assetPath,
            fit: BoxFit.fitHeight,
            height: height,
          ),
        ),
      ),
    );
  }
}

/// Sprite sheet paths for monsters and heroes.
///
/// Each sprite strip has 4 frames:
/// - Monsters: [0] idle, [1] breathe in, [2] breathe out, [3] hit reaction
/// - Heroes: [0] idle, [1] ready stance, [2] power pose, [3] attack lunge
class SpriteSheets {
  static const int frameCount = 4;

  // Monster sprite strips (indexed same as _monsterImages)
  static const monsterSheets = [
    'assets/images/sprites/monster_purple_sheet.png',
    'assets/images/sprites/monster_green_sheet.png',
    'assets/images/sprites/monster_orange_sheet.png',
    'assets/images/sprites/monster_red_sheet.png',
  ];

  // Hero sprite strips (keyed by hero ID)
  static const heroSheets = {
    'shadow': 'assets/images/sprites/hero_shadow_sheet.png',
    'blaze': 'assets/images/sprites/hero_blaze_sheet.png',
    'bolt': 'assets/images/sprites/hero_bolt_sheet.png',
    'leaf': 'assets/images/sprites/hero_leaf_sheet.png',
    'frost': 'assets/images/sprites/hero_frost_sheet.png',
    'nova': 'assets/images/sprites/hero_nova_sheet.png',
  };

  /// Get monster frame based on breath animation and hit state.
  ///
  /// - hitRecoil > 0.5 → frame 3 (hit reaction)
  /// - breathT < 0.33 → frame 0 (idle/neutral)
  /// - breathT < 0.67 → frame 1 (breathe in)
  /// - breathT >= 0.67 → frame 2 (breathe out)
  static int getMonsterFrame(double breathT, double hitRecoil) {
    if (hitRecoil > 0.5) return 3; // Hit reaction
    if (breathT < 0.33) return 0; // Idle
    if (breathT < 0.67) return 1; // Breathe in
    return 2; // Breathe out
  }

  /// Get hero frame based on idle animation and attack state.
  ///
  /// - isAttacking → frame 3 (attack lunge)
  /// - motionGlow → frame 2 (power pose)
  /// - idleT < 0.5 → frame 0 (idle)
  /// - idleT >= 0.5 → frame 1 (ready stance)
  static int getHeroFrame(double idleT, bool isAttacking, bool motionGlow) {
    if (isAttacking) return 3; // Attack lunge
    if (motionGlow) return 2; // Power pose (brushing detected)
    if (idleT < 0.5) return 0; // Idle
    return 1; // Ready stance
  }
}

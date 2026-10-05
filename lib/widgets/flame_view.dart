// lib/widgets/flame_view.dart
import 'package:flutter/material.dart';

import '../services/flame_tier.dart';

/// The streak flame in four steps (spec §7.1), drawn with the same Material
/// icon the Home streak pill already uses.
class FlameIcon extends StatelessWidget {
  final FlameTier tier;
  const FlameIcon({super.key, required this.tier});

  static double sizeFor(FlameTier tier) => switch (tier) {
    FlameTier.none => 22,
    FlameTier.small => 26,
    FlameTier.big => 30,
    FlameTier.hot => 32,
    FlameTier.golden => 34,
  };

  static Color colorFor(FlameTier tier) => switch (tier) {
    FlameTier.none => Colors.white30,
    FlameTier.small => Colors.orangeAccent,
    FlameTier.big => Colors.deepOrangeAccent,
    FlameTier.hot => Colors.lightBlueAccent,
    FlameTier.golden => Colors.amber,
  };

  @override
  Widget build(BuildContext context) {
    final glow = tier == FlameTier.hot || tier == FlameTier.golden;
    return Icon(
      Icons.local_fire_department,
      size: sizeFor(tier),
      color: colorFor(tier),
      shadows: glow ? [Shadow(color: colorFor(tier), blurRadius: 12)] : null,
    );
  }
}

/// Today's flame, the days still to brush (empty small flames), then the
/// next flame and its chest tier. At the golden flame: the flame alone.
class FlameStrip extends StatelessWidget {
  final int streak;
  const FlameStrip({super.key, required this.streak});

  @override
  Widget build(BuildContext context) {
    final current = flameTierFor(streak);
    final days = daysToNextFlameTier(streak);
    final nextAt = nextFlameTierAt(streak);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FlameIcon(tier: current),
        if (days != null && nextAt != null) ...[
          const SizedBox(width: 8),
          for (var i = 0; i < days; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Icon(
                Icons.local_fire_department,
                key: const ValueKey('flame_day_empty'),
                size: 18,
                color: Colors.white.withValues(alpha: 0.25),
              ),
            ),
          const SizedBox(width: 4),
          const Icon(Icons.arrow_forward, size: 18, color: Colors.white54),
          const SizedBox(width: 4),
          FlameIcon(tier: flameTierFor(nextAt)),
          const SizedBox(width: 6),
          _ChestBadge(tier: chestTierFor(nextAt)),
        ],
      ],
    );
  }
}

class _ChestBadge extends StatelessWidget {
  final ChestTier tier;
  const _ChestBadge({required this.tier});

  @override
  Widget build(BuildContext context) {
    final color = switch (tier) {
      ChestTier.wooden => const Color(0xFF8D5A33),
      ChestTier.silver => const Color(0xFFB0BEC5),
      ChestTier.gold => const Color(0xFFFFD54F),
    };
    return Icon(Icons.inventory_2, size: 22, color: color);
  }
}

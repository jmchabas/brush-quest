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

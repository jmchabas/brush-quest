import 'package:flutter/material.dart';

import '../services/goal_service.dart';
import '../services/hero_service.dart';
import '../services/weapon_service.dart';
import '../services/world_service.dart';

/// Weapon art is an opaque square on a dark background. Shown the way the
/// shop does it: as a rounded square. Without a [size] it takes the largest
/// square that fits, so a carousel page doesn't stretch the art into a
/// rectangle.
class WeaponArt extends StatelessWidget {
  final String weaponId;
  final double? size;

  const WeaponArt({super.key, required this.weaponId, this.size});

  @override
  Widget build(BuildContext context) => _SquareArt(
    path: WeaponService.getWeaponById(weaponId).imagePath,
    round: false,
    size: size,
  );
}

/// Planet art is an opaque square on a dark background. Shown the way the
/// world map does it: as a circle. Without a [size] it takes the largest
/// square that fits (so a circle, never an oval).
class PlanetArt extends StatelessWidget {
  final String worldId;
  final double? size;

  const PlanetArt({super.key, required this.worldId, this.size});

  @override
  Widget build(BuildContext context) => _SquareArt(
    path: WorldService.getWorldById(worldId).imagePath,
    round: true,
    size: size,
  );
}

class _SquareArt extends StatelessWidget {
  final String path;
  final bool round;
  final double? size;

  const _SquareArt({required this.path, required this.round, this.size});

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      path,
      width: size,
      height: size,
      fit: BoxFit.cover,
    );
    final clipped = round
        ? ClipOval(child: image)
        : ClipRRect(borderRadius: BorderRadius.circular(16), child: image);
    if (size != null) return clipped;
    return Center(child: AspectRatio(aspectRatio: 1, child: clipped));
  }
}

/// The art for a [Goal], drawn the same way on the pre-brush steps and the
/// victory screen: a hero (or an evolution stage of one) holding
/// [heroWeaponId], a weapon as a rounded square, a planet as a circle. Hero
/// art has a transparent background; weapon and planet art does not (see
/// `ItemSilhouette.opaqueArt`).
class GoalArt extends StatelessWidget {
  final Goal goal;

  /// The weapon a hero goal's hero is drawn holding (the selected one).
  final String heroWeaponId;
  final double size;

  const GoalArt({
    super.key,
    required this.goal,
    required this.heroWeaponId,
    required this.size,
  });

  @override
  Widget build(BuildContext context) => switch (goal.category) {
    GoalCategory.hero => HeroService.buildHeroImage(
      goal.heroId,
      stage: goal.stage,
      weaponId: heroWeaponId,
      size: size,
    ),
    GoalCategory.weapon => WeaponArt(weaponId: goal.itemId, size: size),
    GoalCategory.world => PlanetArt(worldId: goal.itemId, size: size),
  };
}

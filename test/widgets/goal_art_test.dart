// test/widgets/goal_art_test.dart
import 'package:brush_quest/services/goal_service.dart';
import 'package:brush_quest/widgets/goal_art.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: child)),
);

/// The asset a given [Image] widget draws.
String _asset(Image image) => (image.image as AssetImage).assetName;

void main() {
  group('WeaponArt: an opaque square, shown as a rounded square', () {
    testWidgets('with a size: a 16 px rounded square of that size', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const WeaponArt(weaponId: 'flame_sword', size: 90)),
      );
      final clip = tester.widget<ClipRRect>(find.byType(ClipRRect));
      expect(clip.borderRadius, BorderRadius.circular(16));
      final image = tester.widget<Image>(find.byType(Image));
      expect(_asset(image), 'assets/images/weapon_flame_sword.png');
      expect(image.width, 90);
      expect(image.height, 90);
      expect(image.fit, BoxFit.cover);
      expect(find.byType(AspectRatio), findsNothing);
    });

    testWidgets('without a size: the largest square that fits, centred', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const SizedBox(
            width: 300,
            height: 200,
            child: WeaponArt(weaponId: 'flame_sword'),
          ),
        ),
      );
      final box = tester.getRect(find.byType(ClipRRect));
      expect(box.width, 200); // limited by the height, not stretched
      expect(box.height, 200);
      expect(box.center, const Offset(400, 300)); // the 800x600 test surface
      expect(
        tester.widget<AspectRatio>(find.byType(AspectRatio)).aspectRatio,
        1,
      );
    });
  });

  group('PlanetArt: an opaque square, shown as a circle', () {
    testWidgets('with a size: a circle of that size', (tester) async {
      await tester.pumpWidget(
        _wrap(const PlanetArt(worldId: 'slime_swamp', size: 90)),
      );
      expect(find.byType(ClipOval), findsOneWidget);
      expect(find.byType(ClipRRect), findsNothing);
      final image = tester.widget<Image>(find.byType(Image));
      expect(_asset(image), 'assets/images/planet_slime.png');
      expect(tester.getSize(find.byType(ClipOval)), const Size(90, 90));
    });

    testWidgets('without a size: a circle, not an oval', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const SizedBox(
            width: 300,
            height: 200,
            child: PlanetArt(worldId: 'slime_swamp'),
          ),
        ),
      );
      expect(tester.getSize(find.byType(ClipOval)), const Size(200, 200));
    });
  });

  group('GoalArt: the art of a goal', () {
    Future<void> pumpGoal(WidgetTester tester, Goal goal) => tester.pumpWidget(
      _wrap(GoalArt(goal: goal, heroWeaponId: 'ice_hammer', size: 96)),
    );

    testWidgets('a new hero: the hero holding the selected weapon, unclipped', (
      tester,
    ) async {
      await pumpGoal(
        tester,
        const Goal(
          category: GoalCategory.hero,
          itemId: 'frost',
          cost: 5,
          have: 0,
        ),
      );
      final image = tester.widget<Image>(find.byType(Image));
      expect(
        _asset(image),
        'assets/images/heroes/hero_frost_stage1_ice_hammer.png',
      );
      expect(image.width, 96);
      expect(find.byType(ClipRRect), findsNothing);
      expect(find.byType(ClipOval), findsNothing);
    });

    testWidgets('an evolution: the upgraded hero at its stage', (tester) async {
      await pumpGoal(
        tester,
        const Goal(
          category: GoalCategory.hero,
          itemId: 'blaze_stage2',
          evolutionHeroId: 'blaze',
          stage: 2,
          cost: 10,
          have: 0,
        ),
      );
      expect(
        _asset(tester.widget<Image>(find.byType(Image))),
        'assets/images/heroes/hero_blaze_stage2_ice_hammer.png',
      );
    });

    testWidgets('a weapon: the rounded square', (tester) async {
      await pumpGoal(
        tester,
        const Goal(
          category: GoalCategory.weapon,
          itemId: 'flame_sword',
          cost: 5,
          have: 0,
        ),
      );
      expect(find.byType(ClipRRect), findsOneWidget);
      expect(
        _asset(tester.widget<Image>(find.byType(Image))),
        'assets/images/weapon_flame_sword.png',
      );
      expect(tester.getSize(find.byType(ClipRRect)), const Size(96, 96));
    });

    testWidgets('a world: the planet that unlocks next, as a circle', (
      tester,
    ) async {
      await pumpGoal(
        tester,
        const Goal(
          category: GoalCategory.world,
          itemId: 'slime_swamp',
          cost: 5,
          have: 2,
        ),
      );
      expect(find.byType(ClipOval), findsOneWidget);
      expect(
        _asset(tester.widget<Image>(find.byType(Image))),
        'assets/images/planet_slime.png',
      );
    });
  });
}

// test/widgets/brush_flow_widgets_test.dart
import 'package:brush_quest/services/flame_tier.dart';
import 'package:brush_quest/widgets/flame_view.dart';
import 'package:brush_quest/widgets/goal_meter.dart';
import 'package:brush_quest/widgets/item_silhouette.dart';
import 'package:brush_quest/widgets/loadout_carousel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: child)),
);

void main() {
  group('GoalMeter', () {
    testWidgets('up to 10 stars: one slot per star', (tester) async {
      await tester.pumpWidget(_wrap(const GoalMeter(have: 5, cost: 8)));
      expect(find.byKey(const ValueKey('meter_filled')), findsNWidgets(5));
      expect(find.byKey(const ValueKey('meter_empty')), findsNWidgets(3));
      expect(find.byKey(const ValueKey('meter_bar')), findsNothing);
    });
    testWidgets('wallet above the price fills every slot', (tester) async {
      await tester.pumpWidget(_wrap(const GoalMeter(have: 12, cost: 8)));
      expect(find.byKey(const ValueKey('meter_filled')), findsNWidgets(8));
      expect(find.byKey(const ValueKey('meter_empty')), findsNothing);
    });
    testWidgets('above 10 stars: a bar', (tester) async {
      await tester.pumpWidget(_wrap(const GoalMeter(have: 7, cost: 25)));
      expect(find.byKey(const ValueKey('meter_bar')), findsOneWidget);
      expect(find.byKey(const ValueKey('meter_filled')), findsNothing);
    });
    testWidgets('rockets: one per mission', (tester) async {
      await tester.pumpWidget(
        _wrap(const GoalMeter(have: 2, cost: 5, style: GoalMeterStyle.rockets)),
      );
      expect(find.byKey(const ValueKey('meter_filled')), findsNWidgets(2));
      expect(find.byKey(const ValueKey('meter_empty')), findsNWidgets(3));
    });
    testWidgets('complete shows the crown only', (tester) async {
      await tester.pumpWidget(
        _wrap(const GoalMeter(have: 0, cost: 0, complete: true)),
      );
      expect(find.byKey(const ValueKey('meter_crown')), findsOneWidget);
      expect(find.byKey(const ValueKey('meter_empty')), findsNothing);
    });
  });

  testWidgets('ItemSilhouette wraps its child in a black color filter', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const ItemSilhouette(
          child: SizedBox(width: 10, height: 10, key: ValueKey('child')),
        ),
      ),
    );
    expect(find.byKey(const ValueKey('child')), findsOneWidget);
    expect(find.byType(ColorFiltered), findsOneWidget);
  });

  group('LoadoutCarousel', () {
    final items = [
      for (final id in ['a', 'b', 'c'])
        LoadoutItem(
          id: id,
          image: SizedBox(key: ValueKey('img_$id'), width: 50, height: 50),
        ),
    ];
    testWidgets('arrows move the choice and report a touch', (tester) async {
      String? selected;
      var touches = 0;
      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: 360,
            height: 300,
            child: LoadoutCarousel(
              items: items,
              selectedId: 'a',
              onSelected: (id) => selected = id,
              onInteraction: () => touches++,
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('carousel_next')));
      await tester.pumpAndSettle();
      expect(selected, 'b');
      expect(touches, greaterThanOrEqualTo(1));
      await tester.tap(find.byKey(const ValueKey('carousel_prev')));
      await tester.pumpAndSettle();
      expect(selected, 'a');
    });
    testWidgets('a single item hides the arrows', (tester) async {
      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: 360,
            height: 300,
            child: LoadoutCarousel(
              items: [items.first],
              selectedId: 'a',
              onSelected: (_) {},
              onInteraction: () {},
            ),
          ),
        ),
      );
      expect(find.byKey(const ValueKey('carousel_next')), findsNothing);
      expect(find.byKey(const ValueKey('carousel_prev')), findsNothing);
    });
  });

  group('Flame', () {
    testWidgets('FlameIcon grows with the tier', (tester) async {
      double sizeFor(FlameTier t) {
        return (tester.widget(find.byType(Icon).last) as Icon).size!;
      }

      await tester.pumpWidget(_wrap(const FlameIcon(tier: FlameTier.small)));
      final small = sizeFor(FlameTier.small);
      await tester.pumpWidget(_wrap(const FlameIcon(tier: FlameTier.golden)));
      expect(sizeFor(FlameTier.golden), greaterThan(small));
    });
    testWidgets('FlameStrip shows days left to the next step', (tester) async {
      await tester.pumpWidget(_wrap(const FlameStrip(streak: 1)));
      expect(find.byKey(const ValueKey('flame_day_empty')), findsNWidgets(2));
      await tester.pumpWidget(_wrap(const FlameStrip(streak: 13)));
      expect(find.byKey(const ValueKey('flame_day_empty')), findsNWidgets(1));
      await tester.pumpWidget(_wrap(const FlameStrip(streak: 20)));
      expect(find.byKey(const ValueKey('flame_day_empty')), findsNothing);
    });
  });

  // ---- Added in the Task 6 self-review: requirements the brief's tests
  // above don't pin (spec §4.1, §7.1) and the rebuild path of GoalMeter.
  group('Task 6 additions', () {
    Widget carousel({
      String selectedId = 'a',
      ValueChanged<String>? onSelected,
      VoidCallback? onInteraction,
    }) => _wrap(
      SizedBox(
        width: 360,
        height: 300,
        child: LoadoutCarousel(
          items: [
            for (final id in ['a', 'b', 'c'])
              LoadoutItem(
                id: id,
                image: SizedBox.expand(key: ValueKey('img_$id')),
              ),
          ],
          selectedId: selectedId,
          onSelected: onSelected ?? (_) {},
          onInteraction: onInteraction ?? () {},
        ),
      ),
    );

    testWidgets('GoalMeter: 10 stars is still slots, 11 is a bar', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const GoalMeter(have: 4, cost: 10)));
      expect(find.byKey(const ValueKey('meter_filled')), findsNWidgets(4));
      expect(find.byKey(const ValueKey('meter_empty')), findsNWidgets(6));
      expect(find.byKey(const ValueKey('meter_bar')), findsNothing);
      await tester.pumpWidget(_wrap(const GoalMeter(have: 4, cost: 11)));
      expect(find.byKey(const ValueKey('meter_bar')), findsOneWidget);
      expect(find.byKey(const ValueKey('meter_filled')), findsNothing);
    });

    testWidgets('GoalMeter rebuilds as the wallet grows', (tester) async {
      // Task 9 rebuilds the same meter while the wallet moves up to the
      // price; slot keys repeat, so the rebuild path needs its own check.
      for (var have = 0; have <= 9; have++) {
        await tester.pumpWidget(_wrap(GoalMeter(have: have, cost: 8)));
        final filled = have.clamp(0, 8);
        expect(
          find.byKey(const ValueKey('meter_filled')),
          findsNWidgets(filled),
        );
        expect(
          find.byKey(const ValueKey('meter_empty')),
          findsNWidgets(8 - filled),
        );
      }
      // Slots, bar, rockets and crown swap in one tree without errors.
      await tester.pumpWidget(_wrap(const GoalMeter(have: 3, cost: 25)));
      expect(find.byKey(const ValueKey('meter_bar')), findsOneWidget);
      await tester.pumpWidget(
        _wrap(const GoalMeter(have: 3, cost: 5, style: GoalMeterStyle.rockets)),
      );
      expect(find.byKey(const ValueKey('meter_filled')), findsNWidgets(3));
      await tester.pumpWidget(
        _wrap(const GoalMeter(have: 0, cost: 0, complete: true)),
      );
      expect(find.byKey(const ValueKey('meter_crown')), findsOneWidget);
      await tester.pumpWidget(_wrap(const GoalMeter(have: 1, cost: 8)));
      expect(find.byKey(const ValueKey('meter_filled')), findsNWidgets(1));
    });

    testWidgets('ItemSilhouette paints black at the given opacity', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const ItemSilhouette(opacity: 0.5, child: SizedBox())),
      );
      expect(
        tester.widget<ColorFiltered>(find.byType(ColorFiltered)).colorFilter,
        ColorFilter.mode(
          Colors.black.withValues(alpha: 0.5),
          BlendMode.srcATop,
        ),
      );
    });

    testWidgets('carousel opens on the selected item', (tester) async {
      await tester.pumpWidget(carousel(selectedId: 'c'));
      await tester.pumpAndSettle();
      final page = tester.getRect(find.byType(PageView));
      final chosen = tester.getCenter(find.byKey(const ValueKey('img_c')));
      expect((chosen.dx - page.center.dx).abs(), lessThan(1));
    });

    testWidgets('a swipe moves the choice and reports a touch', (tester) async {
      String? selected;
      var touches = 0;
      await tester.pumpWidget(
        carousel(
          onSelected: (id) => selected = id,
          onInteraction: () => touches++,
        ),
      );
      await tester.drag(find.byType(PageView), const Offset(-150, 0));
      await tester.pumpAndSettle();
      expect(selected, 'b');
      expect(touches, greaterThanOrEqualTo(1));
    });

    testWidgets('carousel arrows are at least 48 px (small fingers)', (
      tester,
    ) async {
      await tester.pumpWidget(carousel(selectedId: 'b'));
      for (final key in ['carousel_prev', 'carousel_next']) {
        final size = tester.getSize(find.byKey(ValueKey(key)));
        expect(size.width, greaterThanOrEqualTo(48), reason: key);
        expect(size.height, greaterThanOrEqualTo(48), reason: key);
      }
    });

    testWidgets('FlameStrip shows the next flame and its chest tier', (
      tester,
    ) async {
      Future<(List<FlameTier>, Color?)> strip(int streak) async {
        await tester.pumpWidget(_wrap(FlameStrip(streak: streak)));
        final tiers = [
          for (final f in tester.widgetList<FlameIcon>(find.byType(FlameIcon)))
            f.tier,
        ];
        final chest = tester.widget<Icon>(find.byIcon(Icons.inventory_2));
        return (tiers, chest.color);
      }

      final (tiers1, chest1) = await strip(1);
      expect(tiers1, [FlameTier.small, FlameTier.big]);
      final (tiers5, chest5) = await strip(5);
      expect(tiers5, [FlameTier.big, FlameTier.hot]);
      final (tiers9, chest9) = await strip(9);
      expect(tiers9, [FlameTier.hot, FlameTier.golden]);
      // Chest steps: silver at the 3-day step, gold from the 7-day step on.
      expect(chest1, isNot(chest5));
      expect(chest5, chest9);
    });

    testWidgets('at the golden flame the strip is the flame alone', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const FlameStrip(streak: 14)));
      expect(find.byType(FlameIcon), findsOneWidget);
      expect(
        tester.widget<FlameIcon>(find.byType(FlameIcon)).tier,
        FlameTier.golden,
      );
      expect(find.byIcon(Icons.arrow_forward), findsNothing);
      expect(find.byIcon(Icons.inventory_2), findsNothing);
    });
  });
}

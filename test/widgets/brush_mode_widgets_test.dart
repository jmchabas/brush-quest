// test/widgets/brush_mode_widgets_test.dart
import 'dart:async';

import 'package:brush_quest/screens/brush_mode.dart';
import 'package:brush_quest/services/goal_service.dart';
import 'package:brush_quest/widgets/go_button.dart';
import 'package:brush_quest/widgets/goal_glow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: child)),
);

/// The Container GoalGlow paints with: its glow behind, its ring in front.
Finder _glowBox() => find
    .descendant(of: find.byType(GoalGlow), matching: find.byType(Container))
    .first;

void main() {
  group('GoButton', () {
    testWidgets('says GO! with an arrow, or with a rocket on the Map', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(GoButton(onPressed: () {})));
      expect(find.text('GO!'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_forward), findsOneWidget);
      expect(find.byIcon(Icons.rocket_launch), findsNothing);
      await tester.pumpWidget(_wrap(GoButton(onPressed: () {}, rocket: true)));
      expect(find.text('GO!'), findsOneWidget);
      expect(find.byIcon(Icons.rocket_launch), findsOneWidget);
      expect(find.byIcon(Icons.arrow_forward), findsNothing);
    });

    testWidgets('is 200 x 76', (tester) async {
      await tester.pumpWidget(_wrap(GoButton(onPressed: () {})));
      expect(tester.getSize(find.byType(GoButton)), const Size(200, 76));
    });

    testWidgets('a tap presses it; without onPressed it does nothing', (
      tester,
    ) async {
      var presses = 0;
      await tester.pumpWidget(_wrap(GoButton(onPressed: () => presses++)));
      await tester.tap(find.byType(GoButton));
      expect(presses, 1);
      await tester.pumpWidget(_wrap(const GoButton(onPressed: null)));
      await tester.tap(find.byType(GoButton));
      expect(presses, 1);
    });

    testWidgets('pulses gently while it can be pressed', (tester) async {
      await tester.pumpWidget(_wrap(GoButton(onPressed: () {})));
      double scale() => tester
          .widget<Transform>(
            find
                .descendant(
                  of: find.byType(GoButton),
                  matching: find.byType(Transform),
                )
                .first,
          )
          .transform
          .getMaxScaleOnAxis();
      expect(scale(), closeTo(1.0, 1e-6));
      await tester.pump(const Duration(milliseconds: 600));
      expect(scale(), greaterThan(1.0));
      expect(scale(), lessThanOrEqualTo(1.04 + 1e-6));
    });

    testWidgets('is still while it cannot be pressed', (tester) async {
      await tester.pumpWidget(_wrap(const GoButton(onPressed: null)));
      await tester.pumpAndSettle(); // nothing keeps animating
      final transform = tester.widget<Transform>(
        find
            .descendant(
              of: find.byType(GoButton),
              matching: find.byType(Transform),
            )
            .first,
      );
      expect(transform.transform.getMaxScaleOnAxis(), closeTo(1.0, 1e-6));
    });
  });

  group('GoalGlow', () {
    testWidgets('rings its child in gold without changing its size', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const GoalGlow(child: SizedBox(width: 100, height: 80))),
      );
      expect(tester.getSize(find.byType(GoalGlow)), const Size(100, 80));
      final box = tester.widget<Container>(_glowBox());
      final ring = box.foregroundDecoration! as BoxDecoration;
      final edge = (ring.border! as Border).top;
      expect(edge.width, 3);
      expect(edge.color.withValues(alpha: 1), GoalGlow.color);
      expect(ring.shape, BoxShape.rectangle);
      expect(ring.borderRadius, BorderRadius.circular(12));
    });

    testWidgets('a round ring for planets', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const GoalGlow(
            circle: true,
            child: SizedBox(width: 100, height: 100),
          ),
        ),
      );
      final box = tester.widget<Container>(_glowBox());
      final ring = box.foregroundDecoration! as BoxDecoration;
      expect(ring.shape, BoxShape.circle);
      expect(ring.borderRadius, isNull);
    });

    testWidgets('its glow pulses', (tester) async {
      await tester.pumpWidget(
        _wrap(const GoalGlow(child: SizedBox(width: 50, height: 50))),
      );
      double blur() {
        final glow = tester.widget<Container>(_glowBox()).decoration!;
        return (glow as BoxDecoration).boxShadow!.single.blurRadius;
      }

      final start = blur();
      await tester.pump(const Duration(milliseconds: 600));
      expect(blur(), greaterThan(start));
    });
  });

  testWidgets('BrushCloseButton is a 56 px X that calls onTap', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_wrap(BrushCloseButton(onTap: () => taps++)));
    expect(
      tester.getSize(find.byKey(const ValueKey('brush_close'))),
      const Size(56, 56),
    );
    expect(find.byIcon(Icons.close), findsOneWidget);
    await tester.tap(find.byType(BrushCloseButton));
    expect(taps, 1);
  });

  test('BrushChange is a selection or an unlock', () {
    const pick = BrushChange.selected(GoalCategory.weapon);
    const buy = BrushChange.unlocked(GoalCategory.hero, 'frost');
    expect(pick.category, GoalCategory.weapon);
    expect(pick.unlockedId, isNull);
    expect(buy.unlockedId, 'frost');
    expect(buy, const BrushChange.unlocked(GoalCategory.hero, 'frost'));
    expect(buy, isNot(pick));
    expect(
      buy.hashCode,
      const BrushChange.unlocked(GoalCategory.hero, 'frost').hashCode,
    );
  });

  test('BrushPing tells its listeners once per ping', () {
    final ping = BrushPing();
    var heard = 0;
    ping
      ..addListener(() => heard++)
      ..ping()
      ..ping();
    expect(heard, 2);
    ping.dispose();
  });

  group('revealIfHidden', () {
    /// Twenty 100 px rows in a 600 px list (the test surface is 800 x 600),
    /// every row built, [key] on row [target].
    Future<ScrollPosition> pumpList(
      WidgetTester tester,
      GlobalKey key,
      int target,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              cacheExtent: 3000,
              children: [
                for (var i = 0; i < 20; i++)
                  SizedBox(
                    key: i == target ? key : null,
                    height: 100,
                    child: Text('row $i'),
                  ),
              ],
            ),
          ),
        ),
      );
      return tester.state<ScrollableState>(find.byType(Scrollable)).position;
    }

    testWidgets('scrolls a row below the screen into view, above GO', (
      tester,
    ) async {
      final key = GlobalKey();
      final position = await pumpList(tester, key, 12);
      unawaited(revealIfHidden(key.currentContext!));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      final row = tester.getRect(find.byKey(key));
      final view = tester.getRect(find.byType(ListView));
      expect(position.pixels, greaterThan(0));
      expect(row.top, greaterThanOrEqualTo(view.top));
      expect(row.bottom, lessThanOrEqualTo(view.bottom - kBrushGoClearance));
    });

    testWidgets('scrolls in 400 ms', (tester) async {
      final key = GlobalKey();
      final position = await pumpList(tester, key, 12);
      var done = false;
      unawaited(revealIfHidden(key.currentContext!).then((_) => done = true));
      await tester.pump(); // the scroll starts
      await tester.pump(const Duration(milliseconds: 350));
      expect(position.pixels, greaterThan(0));
      expect(done, isFalse);
      await tester.pump(const Duration(milliseconds: 60));
      expect(done, isTrue);
    });

    testWidgets('a row behind the GO zone counts as hidden', (tester) async {
      final key = GlobalKey();
      final position = await pumpList(tester, key, 5); // 500..600 of 600
      unawaited(revealIfHidden(key.currentContext!));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      expect(position.pixels, greaterThan(0));
      final view = tester.getRect(find.byType(ListView));
      expect(
        tester.getRect(find.byKey(key)).bottom,
        lessThanOrEqualTo(view.bottom - kBrushGoClearance),
      );
    });

    testWidgets('scrolls a row above the screen back into view', (
      tester,
    ) async {
      final key = GlobalKey();
      final position = await pumpList(tester, key, 2);
      position.jumpTo(800);
      await tester.pump(); // row 2 (200..300) is now above the top edge
      unawaited(revealIfHidden(key.currentContext!));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      // First, so a missed reveal reads "800 is not less than 800" and not
      // "the finder cannot find a row that is off screen".
      expect(position.pixels, lessThan(800));
      final row = tester.getRect(find.byKey(key));
      final view = tester.getRect(find.byType(ListView));
      expect(row.top, greaterThanOrEqualTo(view.top));
      expect(row.bottom, lessThanOrEqualTo(view.bottom - kBrushGoClearance));
    });

    testWidgets('leaves a row that is fully visible alone', (tester) async {
      final key = GlobalKey();
      final position = await pumpList(tester, key, 1);
      unawaited(revealIfHidden(key.currentContext!));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      expect(position.pixels, 0);
    });

    testWidgets('moves only the nearest scroll view, not the ones around it', (
      tester,
    ) async {
      final key = GlobalKey();
      final outer = ScrollController();
      addTearDown(outer.dispose);
      // A 300 px list, 300 px down a page that scrolls too.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              controller: outer,
              child: Column(
                children: [
                  const SizedBox(height: 300),
                  SizedBox(
                    height: 300,
                    child: ListView(
                      cacheExtent: 3000,
                      children: [
                        for (var i = 0; i < 20; i++)
                          SizedBox(
                            key: i == 12 ? key : null,
                            height: 100,
                            child: Text('row $i'),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 1500),
                ],
              ),
            ),
          ),
        ),
      );
      unawaited(revealIfHidden(key.currentContext!));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      expect(outer.position.pixels, 0);
      final row = tester.getRect(find.byKey(key));
      final list = tester.getRect(find.byType(ListView));
      expect(row.top, greaterThanOrEqualTo(list.top));
      expect(row.bottom, lessThanOrEqualTo(list.bottom - kBrushGoClearance));
    });
  });
}

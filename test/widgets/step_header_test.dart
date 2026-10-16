// test/widgets/step_header_test.dart
//
// The steps' HEROES · WEAPONS · WORLD header (spec
// docs/superpowers/specs/2026-10-15-sticker-card-design.md §3.1).
import 'package:brush_quest/widgets/step_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // The app's font, so widths are a phone's (the test font is about twice
    // as wide).
    final fredoka = FontLoader('Fredoka')
      ..addFont(
        rootBundle.load(
          'assets/fonts/Fredoka/Fredoka-VariableFont_wdth_wght.ttf',
        ),
      );
    await fredoka.load();
  });

  const lit = Color(0xFF7C4DFF);

  /// The header across a phone [width] wide, in the app's theme.
  Future<ValueNotifier<int>> pumpHeader(
    WidgetTester tester, {
    double width = 430,
    ValueChanged<int>? onTap,
  }) async {
    final current = ValueNotifier<int>(0);
    addTearDown(current.dispose);
    await tester.binding.setSurfaceSize(Size(width, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          textTheme: ThemeData.dark().textTheme.apply(fontFamily: 'Fredoka'),
        ),
        home: Scaffold(
          body: Center(
            child: StepHeader(current: current, onTap: onTap ?? (_) {}),
          ),
        ),
      ),
    );
    return current;
  }

  Finder tab(int index) => find.byKey(ValueKey('step_tab_$index'));

  Color labelColor(WidgetTester tester, String label) =>
      tester.widget<Text>(find.text(label)).style!.color!;

  Color? fill(WidgetTester tester, int index) {
    final box = tester.widget<AnimatedContainer>(
      find.descendant(of: tab(index), matching: find.byType(AnimatedContainer)),
    );
    return (box.decoration! as BoxDecoration).color;
  }

  testWidgets('HEROES, WEAPONS and WORLD, each with its icon', (tester) async {
    await pumpHeader(tester);
    expect(find.text('HEROES'), findsOneWidget);
    expect(find.text('WEAPONS'), findsOneWidget);
    expect(find.text('WORLD'), findsOneWidget);
    expect(find.byIcon(Icons.shield), findsOneWidget);
    expect(find.byIcon(Icons.bolt), findsOneWidget);
    expect(find.byIcon(Icons.public), findsOneWidget);
  });

  testWidgets('the size and place of the page tab bar: 48 px, 16 px in', (
    tester,
  ) async {
    await pumpHeader(tester);
    expect(StepHeader.height, 48);
    expect(tester.getSize(find.byType(StepHeader)).height, 48);
    expect(tester.getRect(tab(0)).left, 16);
    expect(tester.getRect(tab(2)).right, 430 - 16);
    for (var i = 0; i < 3; i++) {
      final rect = tester.getRect(tab(i));
      expect(rect.height, 48, reason: 'tab $i');
      expect(rect.width, closeTo((430 - 32) / 3, 0.01), reason: 'tab $i');
    }
  });

  testWidgets('lights the step he is on, and follows it', (tester) async {
    final current = await pumpHeader(tester);
    expect(labelColor(tester, 'HEROES'), Colors.white);
    expect(labelColor(tester, 'WEAPONS'), Colors.white54);
    expect(labelColor(tester, 'WORLD'), Colors.white54);
    expect(fill(tester, 0), lit.withValues(alpha: 0.4));
    expect(fill(tester, 1), Colors.transparent);
    expect(fill(tester, 2), Colors.transparent);
    current.value = 2;
    await tester.pump();
    expect(labelColor(tester, 'WORLD'), Colors.white);
    expect(labelColor(tester, 'HEROES'), Colors.white54);
    expect(fill(tester, 2), lit.withValues(alpha: 0.4));
    expect(fill(tester, 0), Colors.transparent);
  });

  testWidgets('reports every tap, on the lit tab too', (tester) async {
    final taps = <int>[];
    await pumpHeader(tester, onTap: taps.add);
    await tester.tap(tab(2));
    await tester.tap(find.text('WEAPONS'));
    await tester.tap(find.byIcon(Icons.shield)); // the lit one
    expect(taps, [2, 1, 0]);
  });

  for (final phone in const [
    (width: 320.0, textScale: 1.0),
    (width: 360.0, textScale: 1.0),
    (width: 360.0, textScale: 2.0),
  ]) {
    testWidgets('fits a ${phone.width.toInt()} dp phone at text size '
        '${phone.textScale}x', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = phone.textScale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpHeader(tester, width: phone.width);
      expect(tester.takeException(), isNull);
      for (final (index, label) in ['HEROES', 'WEAPONS', 'WORLD'].indexed) {
        final box = tester.getRect(tab(index));
        final text = tester.getRect(find.text(label));
        expect(box.height, 48, reason: label);
        expect(
          box.contains(text.topLeft) && box.contains(text.bottomRight),
          isTrue,
          reason: '$label: $text in $box',
        );
      }
    });
  }
}

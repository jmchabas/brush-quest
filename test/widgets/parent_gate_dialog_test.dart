// test/widgets/parent_gate_dialog_test.dart
import 'dart:math';

import 'package:brush_quest/widgets/parent_gate_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The shared GROWN-UP CHECK (moved unchanged from onboarding): onboarding's
/// camera page and the bedtime-reminder hand-off both open it.
void main() {
  /// A page with one button that opens the gate and keeps its answers.
  Future<List<bool?>> pumpOpener(WidgetTester tester, {Random? random}) async {
    final answers = <bool?>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async =>
                    answers.add(await showParentGate(context, random: random)),
                child: const Text('OPEN'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('OPEN'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    return answers;
  }

  ({int a, int b}) problem(WidgetTester tester) {
    final text = tester.widget<Text>(find.textContaining('×')).data!;
    final m = RegExp(r'^(\d+) × (\d+) = \?$').firstMatch(text)!;
    return (a: int.parse(m.group(1)!), b: int.parse(m.group(2)!));
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('a right answer closes it with true', (tester) async {
    final answers = await pumpOpener(tester);
    expect(find.text('GROWN-UP CHECK'), findsOneWidget);
    final p = problem(tester);
    await tester.enterText(find.byType(TextField), '${p.a * p.b}');
    await tester.tap(find.text('CONTINUE'));
    await settle(tester);
    expect(find.text('GROWN-UP CHECK'), findsNothing);
    expect(answers, [true]);
  });

  testWidgets('CANCEL closes it with false', (tester) async {
    final answers = await pumpOpener(tester);
    await tester.tap(find.text('CANCEL'));
    await settle(tester);
    expect(find.text('GROWN-UP CHECK'), findsNothing);
    expect(answers, [false]);
  });

  testWidgets('a tap outside does not close it', (tester) async {
    final answers = await pumpOpener(tester);
    await tester.tapAt(const Offset(4, 4));
    await settle(tester);
    expect(find.text('GROWN-UP CHECK'), findsOneWidget);
    expect(answers, isEmpty);
  });

  testWidgets('a wrong answer deals a new problem from the given Random', (
    tester,
  ) async {
    final expected = Random(8);
    final first = (a: 4 + expected.nextInt(6), b: 3 + expected.nextInt(5));
    final second = (a: 4 + expected.nextInt(6), b: 3 + expected.nextInt(5));
    final answers = await pumpOpener(tester, random: Random(8));
    expect(problem(tester), first);
    await tester.enterText(find.byType(TextField), '1');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester);
    expect(find.text('Try again!'), findsOneWidget);
    expect(problem(tester), second);
    expect(answers, isEmpty);
  });
}

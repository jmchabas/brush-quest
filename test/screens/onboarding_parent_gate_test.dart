import 'dart:math';

import 'package:brush_quest/screens/onboarding_screen.dart';
import 'package:brush_quest/services/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../audio/fake_audio_service.dart';

/// Apple Guideline 1.3 (Kids Category) tests for the GROWN-UP CHECK on the
/// onboarding camera page (`_ParentGateDialog` in onboarding_screen.dart).
///
/// The old gate was a fixed "7 × 8" with three tap targets (48 / 56 / 64): a
/// child could memorise 56 or brute-force it in three taps. It is now a typed,
/// random multiplication like the Settings Parent Check (A in 4..9, B in
/// 3..7), and a wrong answer deals a new problem.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const permissionChannel = MethodChannel(
    'flutter.baseflow.com/permissions/methods',
  );

  /// Seed whose first problems all differ (4 × 5, 9 × 4, 6 × 7, ...); the
  /// tests that rely on that assert it.
  const seed = 8;

  late List<MethodCall> permissionCalls;

  setUpAll(() {
    // tearDown restores the real AudioService, which builds AudioPlayers:
    // mock the audioplayers channels so that doesn't throw.
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers.global'),
      (call) async => 1,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers'),
      (call) async => 1,
    );
  });

  setUp(() {
    AudioService.testInstance = FakeAudioService();
    permissionCalls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(permissionChannel, (call) async {
          permissionCalls.add(call);
          return null;
        });
  });

  tearDown(() {
    AudioService.testInstance = null;
    OnboardingScreen.debugGateRandom = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(permissionChannel, null);
  });

  /// What a gate drawing from `Random(seed)` must show, in order: A first
  /// (4..9), then B (3..7).
  List<Problem> seededProblems(int count) {
    final rng = Random(seed);
    final problems = <Problem>[];
    for (var i = 0; i < count; i++) {
      final a = 4 + rng.nextInt(6);
      final b = 3 + rng.nextInt(5);
      problems.add((a: a, b: b));
    }
    return problems;
  }

  /// Pumps onboarding, walks to the camera page and taps TURN ON CAMERA, so
  /// the GROWN-UP CHECK is on screen.
  Future<void> openGate(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: OnboardingScreen()));
    // Allow async init + animation controllers to settle
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('NEXT'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    }
    await tester.tap(find.text('TURN ON CAMERA'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  /// Reads the "A × B = ?" problem out of the open gate.
  Problem shownProblem(WidgetTester tester) {
    final finder = find.textContaining('×');
    expect(finder, findsOneWidget);
    final text = tester.widget<Text>(finder).data!;
    final match = RegExp(r'^(\d+) × (\d+) = \?$').firstMatch(text);
    expect(match, isNotNull, reason: 'expected "A × B = ?", got "$text"');
    return (a: int.parse(match!.group(1)!), b: int.parse(match.group(2)!));
  }

  String fieldText(WidgetTester tester) =>
      tester.widget<TextField>(find.byType(TextField)).controller!.text;

  /// Types [answer] and taps CONTINUE.
  Future<void> answerWithButton(WidgetTester tester, String answer) async {
    await tester.enterText(find.byType(TextField), answer);
    await tester.tap(find.text('CONTINUE'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  /// Types [answer] and presses the keypad's Done key.
  Future<void> answerWithKeypad(WidgetTester tester, String answer) async {
    await tester.enterText(find.byType(TextField), answer);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  /// Nothing the camera ask writes on success may be written yet.
  Future<void> expectCameraPrefsUntouched() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in const [
      'camera_enabled',
      'camera_mode_configured',
      'camera_prompt_shown',
      'home_camera_nudge_shown',
      'onboarding_completed',
    ]) {
      expect(prefs.containsKey(key), isFalse, reason: '$key must stay unset');
    }
  }

  // ── What the gate looks like ─────────────────────────────────

  testWidgets('asks a typed question, not three tap targets', (tester) async {
    OnboardingScreen.debugGateRandom = Random(seed);
    await openGate(tester);

    expect(find.text('GROWN-UP CHECK'), findsOneWidget);
    expect(find.text('Type the answer:'), findsOneWidget);
    expect(find.text('CANCEL'), findsOneWidget);
    expect(find.text('CONTINUE'), findsOneWidget);
    shownProblem(tester); // asserts the "A × B = ?" format

    // One number field: number keypad, hint "?", keypad up straight away.
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.keyboardType, TextInputType.number);
    expect(field.autofocus, isTrue);
    expect(field.decoration!.hintText, '?');
    expect(tester.testTextInput.isVisible, isTrue);

    // The fixed "7 × 8" tap-the-answer gate is gone.
    expect(find.text('Tap the answer:'), findsNothing);
    expect(find.text('What is 7 × 8?'), findsNothing);
    for (final choice in const ['48', '56', '64']) {
      expect(find.text(choice), findsNothing);
    }

    // The keypad must not overflow the dialog.
    final dialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
    expect(dialog.scrollable, isTrue);
  });

  testWidgets('problem factors follow the Settings ranges: A 4..9, B 3..7', (
    tester,
  ) async {
    OnboardingScreen.debugGateRandom = Random(seed);
    await openGate(tester);

    final seenA = <int>{};
    final seenB = <int>{};
    for (var i = 0; i < 60; i++) {
      final problem = shownProblem(tester);
      expect(problem.a, inInclusiveRange(4, 9));
      expect(problem.b, inInclusiveRange(3, 7));
      seenA.add(problem.a);
      seenB.add(problem.b);
      // Off by one is always wrong, so the gate deals the next problem.
      await answerWithButton(tester, '${problem.answer + 1}');
      expect(find.text('Try again!'), findsOneWidget);
    }
    expect(seenA, {4, 5, 6, 7, 8, 9}, reason: 'A must reach both ends');
    expect(seenB, {3, 4, 5, 6, 7}, reason: 'B must reach both ends');
  });

  testWidgets('without the test seed the gate draws its own problem', (
    tester,
  ) async {
    expect(OnboardingScreen.debugGateRandom, isNull);
    await openGate(tester);

    final problem = shownProblem(tester);
    expect(problem.a, inInclusiveRange(4, 9));
    expect(problem.b, inInclusiveRange(3, 7));
    await answerWithButton(tester, '${problem.answer}');
    expect(find.text('Brushing Detection'), findsOneWidget);
  });

  // ── Wrong, empty and malformed answers ───────────────────────

  testWidgets('wrong answer: Try again!, field cleared, a new problem', (
    tester,
  ) async {
    final expected = seededProblems(3);
    // This test could not tell "regenerated" from "unchanged" if the seed
    // dealt the same problem twice in a row.
    expect(expected[1], isNot(expected[0]));
    expect(expected[2], isNot(expected[1]));
    OnboardingScreen.debugGateRandom = Random(seed);
    await openGate(tester);

    expect(shownProblem(tester), expected[0]);
    expect(find.text('Try again!'), findsNothing);

    await answerWithButton(tester, '${expected[0].answer + 1}');
    expect(find.text('Try again!'), findsOneWidget);
    expect(find.text('GROWN-UP CHECK'), findsOneWidget);
    expect(fieldText(tester), isEmpty);
    expect(shownProblem(tester), expected[1]);

    // And again: every miss deals the next problem.
    await answerWithButton(tester, '${expected[1].answer + 1}');
    expect(find.text('Try again!'), findsOneWidget);
    expect(fieldText(tester), isEmpty);
    expect(shownProblem(tester), expected[2]);

    // Nothing past the gate happened.
    expect(find.text('Brushing Detection'), findsNothing);
    expect(permissionCalls, isEmpty);
    await expectCameraPrefsUntouched();

    // The newest problem is the one that counts.
    await answerWithButton(tester, '${expected[2].answer}');
    expect(find.text('Brushing Detection'), findsOneWidget);
  });

  testWidgets('empty answer is wrong too: Try again! and a new problem', (
    tester,
  ) async {
    final expected = seededProblems(2);
    expect(expected[1], isNot(expected[0]));
    OnboardingScreen.debugGateRandom = Random(seed);
    await openGate(tester);

    await tester.tap(find.text('CONTINUE'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Try again!'), findsOneWidget);
    expect(find.text('GROWN-UP CHECK'), findsOneWidget);
    expect(shownProblem(tester), expected[1]);
    expect(find.text('Brushing Detection'), findsNothing);
    expect(permissionCalls, isEmpty);
    await expectCameraPrefsUntouched();
  });

  testWidgets('the field only accepts digits', (tester) async {
    OnboardingScreen.debugGateRandom = Random(seed);
    await openGate(tester);

    await tester.enterText(find.byType(TextField), 'abc');
    await tester.pump();
    expect(fieldText(tester), isEmpty);

    await tester.enterText(find.byType(TextField), '1a2b');
    await tester.pump();
    expect(fieldText(tester), '12');
  });

  // ── Correct answer ───────────────────────────────────────────

  testWidgets('correct answer opens the Brushing Detection consent', (
    tester,
  ) async {
    OnboardingScreen.debugGateRandom = Random(seed);
    await openGate(tester);

    await answerWithButton(tester, '${shownProblem(tester).answer}');

    // Gate step 1 passed -> step 2 (consent), unchanged.
    expect(find.text('Brushing Detection'), findsOneWidget);
    expect(find.text('GROWN-UP CHECK'), findsNothing);
    expect(find.text('Try again!'), findsNothing);
    // Passing the gate alone enables nothing and asks the OS for nothing.
    expect(permissionCalls, isEmpty);
    await expectCameraPrefsUntouched();

    // Declining the consent lands back on the camera page, still untouched.
    await tester.tap(find.text('CANCEL'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Brushing Detection'), findsNothing);
    expect(find.text('TURN ON CAMERA'), findsOneWidget);
    expect(permissionCalls, isEmpty);
    await expectCameraPrefsUntouched();
  });

  testWidgets('the keypad Done key submits the answer', (tester) async {
    final expected = seededProblems(2);
    expect(expected[1], isNot(expected[0]));
    OnboardingScreen.debugGateRandom = Random(seed);
    await openGate(tester);

    await answerWithKeypad(tester, '${expected[0].answer + 1}');
    expect(find.text('Try again!'), findsOneWidget);
    expect(shownProblem(tester), expected[1]);
    expect(find.text('Brushing Detection'), findsNothing);

    await answerWithKeypad(tester, '${expected[1].answer}');
    expect(find.text('Brushing Detection'), findsOneWidget);
    expect(find.text('GROWN-UP CHECK'), findsNothing);
  });

  // ── Leaving the gate ─────────────────────────────────────────

  testWidgets('CANCEL returns to the camera page, camera prefs untouched', (
    tester,
  ) async {
    OnboardingScreen.debugGateRandom = Random(seed);
    await openGate(tester);

    await tester.tap(find.text('CANCEL'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('GROWN-UP CHECK'), findsNothing);
    expect(find.text('Brushing Detection'), findsNothing);
    expect(find.text('TURN ON CAMERA'), findsOneWidget);
    expect(find.text('Maybe later'), findsOneWidget);
    expect(permissionCalls, isEmpty);
    await expectCameraPrefsUntouched();
  });

  testWidgets('tapping outside the dialog does not dismiss it', (tester) async {
    OnboardingScreen.debugGateRandom = Random(seed);
    await openGate(tester);

    // Top-left corner: on the barrier, nowhere near the dialog.
    await tester.tapAt(const Offset(10, 10));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('GROWN-UP CHECK'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(permissionCalls, isEmpty);
    await expectCameraPrefsUntouched();
  });
}

/// One multiplication problem, shown as "A × B = ?".
typedef Problem = ({int a, int b});

extension on Problem {
  int get answer => a * b;
}

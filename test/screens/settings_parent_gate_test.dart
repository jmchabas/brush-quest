import 'package:brush_quest/screens/settings_screen.dart';
import 'package:brush_quest/services/audio_service.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../audio/fake_audio_service.dart';

/// Apple Guideline 1.3 (Kids Category) compliance tests for the math
/// parental gate at lib/screens/settings_screen.dart:_buildParentGate.
///
/// The gate guards every external surface (sign-in, cloud sync, reset,
/// privacy/terms links) per docs/ios-port/parental-gate-audit.md.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeAudioService fakeAudio;

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('xyz.luan/audioplayers.global'),
          (call) async => 1,
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('xyz.luan/audioplayers'),
          (call) async => 1,
        );
  });

  setUp(() {
    fakeAudio = FakeAudioService();
    AudioService.testInstance = fakeAudio;
  });

  tearDown(() {
    AudioService.testInstance = null;
  });

  Future<void> pumpSettings(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.binding.setSurfaceSize(const Size(430, 932));
    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  /// Reads the "A × B = ?" challenge text and returns the product.
  int extractCorrectAnswer(WidgetTester tester) {
    final challengeFinder = find.textContaining('×');
    expect(challengeFinder, findsOneWidget);
    final challenge = tester.widget<Text>(challengeFinder).data!;
    // Format: "A × B = ?"
    final match = RegExp(r'(\d+)\s*×\s*(\d+)').firstMatch(challenge);
    expect(
      match,
      isNotNull,
      reason: 'expected challenge string in form "A × B = ?", got "$challenge"',
    );
    final a = int.parse(match!.group(1)!);
    final b = int.parse(match.group(2)!);
    return a * b;
  }

  testWidgets('shows math challenge before settings content', (tester) async {
    await pumpSettings(tester);

    expect(find.text('Parent Check'), findsOneWidget);
    expect(find.textContaining('×'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);

    // None of the settings content is visible yet.
    expect(find.text('ACCOUNT'), findsNothing);
    expect(find.text('BRUSHING'), findsNothing);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('wrong answer rejects + regenerates challenge', (tester) async {
    await pumpSettings(tester);

    final correct = extractCorrectAnswer(tester);
    final wrong = correct + 1; // off-by-one is always wrong

    // Submit wrong answer.
    await tester.enterText(find.byType(TextField), '$wrong');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    // Error appears, gate still shown.
    expect(find.text('Try again!'), findsOneWidget);
    expect(find.text('Parent Check'), findsOneWidget);
    expect(find.text('ACCOUNT'), findsNothing);

    // Field cleared (input is empty after rejection).
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, isEmpty);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('correct answer unlocks settings content', (tester) async {
    await pumpSettings(tester);

    final correct = extractCorrectAnswer(tester);

    await tester.enterText(find.byType(TextField), '$correct');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Gate is gone; the unlocked Settings UI renders the TabBar.
    expect(find.text('Parent Check'), findsNothing);
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Stars'), findsOneWidget);
    expect(find.text('Guide'), findsOneWidget);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('input field rejects non-digit characters', (tester) async {
    await pumpSettings(tester);

    // Try typing letters — should be filtered by FilteringTextInputFormatter.digitsOnly.
    await tester.enterText(find.byType(TextField), 'abc');
    await tester.pump();

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(
      field.controller!.text,
      isEmpty,
      reason: 'digitsOnly formatter should strip letters',
    );

    await tester.binding.setSurfaceSize(null);
  });
}

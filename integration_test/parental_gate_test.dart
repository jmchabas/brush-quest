// Integration test for the parental math gate at
// lib/screens/settings_screen.dart:_buildParentGate.
//
// Mirrors the cases in test/screens/settings_parent_gate_test.dart but runs
// on a real iOS Simulator (or device) via integration_test, so it exercises
// the actual platform keyboard, FilteringTextInputFormatter on the iOS text
// channel, and the iOS-specific Material widget surface.
//
// Run: flutter test integration_test/parental_gate_test.dart -d "iPhone 15"
// CI: codemagic.yaml workflow `ios_tests` runs the whole integration_test/ dir.

import 'package:brush_quest/screens/settings_screen.dart';
import 'package:brush_quest/services/audio_service.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/audio/fake_audio_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

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

  /// Reads the "A × B = ?" challenge and returns the product the user must enter.
  int extractCorrectAnswer(WidgetTester tester) {
    final challengeFinder = find.textContaining('×');
    expect(challengeFinder, findsOneWidget);
    final challenge = tester.widget<Text>(challengeFinder).data!;
    final match = RegExp(r'(\d+)\s*×\s*(\d+)').firstMatch(challenge);
    expect(match, isNotNull, reason: 'expected "A × B = ?", got "$challenge"');
    return int.parse(match!.group(1)!) * int.parse(match.group(2)!);
  }

  testWidgets('iOS: gate renders math challenge and hides Settings content', (
    tester,
  ) async {
    await pumpSettings(tester);

    expect(find.text('Parent Check'), findsOneWidget);
    expect(find.textContaining('×'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);

    // None of the post-unlock TabBar tabs are present yet.
    expect(find.text('Dashboard'), findsNothing);
    expect(find.text('Settings'), findsNothing);
    expect(find.text('Stars'), findsNothing);
    expect(find.text('Guide'), findsNothing);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('iOS: wrong answer rejects, regenerates challenge, clears field', (
    tester,
  ) async {
    await pumpSettings(tester);

    final correct = extractCorrectAnswer(tester);
    final wrong = correct + 1;

    await tester.enterText(find.byType(TextField), '$wrong');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(find.text('Try again!'), findsOneWidget);
    expect(find.text('Parent Check'), findsOneWidget);
    expect(find.text('Dashboard'), findsNothing);

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, isEmpty);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('iOS: correct answer unlocks the Settings TabBar', (tester) async {
    await pumpSettings(tester);

    final correct = extractCorrectAnswer(tester);

    await tester.enterText(find.byType(TextField), '$correct');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Parent Check'), findsNothing);
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Stars'), findsOneWidget);
    expect(find.text('Guide'), findsOneWidget);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets(
    'iOS: digitsOnly formatter strips letters from the math input',
    (tester) async {
      await pumpSettings(tester);

      await tester.enterText(find.byType(TextField), 'abc123def');
      await tester.pump();

      final field = tester.widget<TextField>(find.byType(TextField));
      // Letters dropped, digits remain.
      expect(field.controller!.text, '123');

      await tester.binding.setSurfaceSize(null);
    },
  );
}

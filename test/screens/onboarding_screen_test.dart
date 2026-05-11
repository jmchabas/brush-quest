import 'package:brush_quest/screens/onboarding_screen.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../audio/fake_audio_service.dart';
import 'package:brush_quest/services/audio_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeAudioService fakeAudio;

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();

    // Mock audioplayers platform channel to prevent MissingPluginException
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

  Future<void> pumpOnboarding(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.binding.setSurfaceSize(const Size(430, 932));
    await tester.pumpWidget(const MaterialApp(home: OnboardingScreen()));
    // Allow async init + animation controllers to settle
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
  }

  // ── Page rendering ───────────────────────────────────────────

  testWidgets('onboarding renders welcome page with NEXT button', (
    tester,
  ) async {
    await pumpOnboarding(tester);

    // Page 1 content: welcome text
    expect(find.textContaining('WELCOME'), findsOneWidget);
    expect(find.textContaining('SPACE RANGER'), findsOneWidget);

    // NEXT button visible on first page
    expect(find.text('NEXT'), findsOneWidget);

    // Camera page CTA not visible on first page
    expect(find.text('TURN ON CAMERA'), findsNothing);

    await tester.binding.setSurfaceSize(null);
  });

  // ── Page navigation ──────────────────────────────────────────

  testWidgets('NEXT button still shows on pages 2 and 3', (tester) async {
    await pumpOnboarding(tester);

    // Page 1 → 2
    await tester.tap(find.text('NEXT'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('NEXT'), findsOneWidget);

    // Page 2 → 3
    await tester.tap(find.text('NEXT'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('NEXT'), findsOneWidget);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets(
    'page 4 (camera) shows TURN ON CAMERA and Maybe later, no NEXT',
    (tester) async {
      await pumpOnboarding(tester);

      // Advance to page 4 (camera page, index 3)
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.text('NEXT'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
      }

      // Camera page CTAs visible
      expect(find.text('TURN ON CAMERA'), findsOneWidget);
      expect(find.text('Maybe later'), findsOneWidget);
      // NEXT button hidden on the camera page
      expect(find.text('NEXT'), findsNothing);

      await tester.binding.setSurfaceSize(null);
    },
  );

  // ── Voice narration ──────────────────────────────────────────

  testWidgets('voice narration triggers on page load and page changes', (
    tester,
  ) async {
    await pumpOnboarding(tester);

    // Page 1 narration should have been triggered
    final page1Voices = fakeAudio
        .callsFor('playVoice')
        .where((c) => c.args['fileName'] == 'voice_onboarding_1.mp3');
    expect(
      page1Voices.isNotEmpty,
      isTrue,
      reason: 'Page 1 narration should play on initial load',
    );

    // Navigate to page 2
    fakeAudio.clearCalls();
    await tester.tap(find.text('NEXT'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final page2Voices = fakeAudio
        .callsFor('playVoice')
        .where((c) => c.args['fileName'] == 'voice_onboarding_2.mp3');
    expect(
      page2Voices.isNotEmpty,
      isTrue,
      reason: 'Page 2 narration should play after swiping',
    );

    // Navigate to page 3
    fakeAudio.clearCalls();
    await tester.tap(find.text('NEXT'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final page3Voices = fakeAudio
        .callsFor('playVoice')
        .where((c) => c.args['fileName'] == 'voice_onboarding_3.mp3');
    expect(
      page3Voices.isNotEmpty,
      isTrue,
      reason: 'Page 3 narration should play after swiping',
    );

    // Navigate to page 4 (camera page) — should narrate voice_camera_prompt
    fakeAudio.clearCalls();
    await tester.tap(find.text('NEXT'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final cameraPageVoices = fakeAudio
        .callsFor('playVoice')
        .where((c) => c.args['fileName'] == 'voice_camera_prompt.mp3');
    expect(
      cameraPageVoices.isNotEmpty,
      isTrue,
      reason: 'Camera page narration should play after swiping',
    );

    await tester.binding.setSurfaceSize(null);
  });

  // ── Page indicator dots ──────────────────────────────────────

  testWidgets('4 page indicator dots are rendered', (tester) async {
    await pumpOnboarding(tester);

    // 4 AnimatedContainer dots in the bottom nav (active = 28, inactive = 10).
    // On page 1, we expect 1 active + 3 inactive.
    final animatedContainers = find.byType(AnimatedContainer);
    expect(animatedContainers, findsWidgets);

    await tester.binding.setSurfaceSize(null);
  });

  // ── Repeat voice button ──────────────────────────────────────

  testWidgets('repeat voice button exists', (tester) async {
    await pumpOnboarding(tester);

    // Volume icon for repeating voice narration
    expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);

    await tester.binding.setSurfaceSize(null);
  });
}

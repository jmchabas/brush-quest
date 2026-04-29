// Full brush-session end-to-end integration test (plan task 1V-6).
//
// Drives the real production widget tree from HomeScreen → BrushingScreen
// → VictoryScreen and asserts a star was awarded by reading SharedPreferences
// after the session completes.
//
// A real session is 6 phases × 20s = 120s, far too slow for CI. The test
// relies on the test-only fast-brush hook in brushing_screen.dart that lets
// `--dart-define=BRUSHING_PHASE_SECONDS=N` override the per-phase duration.
// Production runs (no dart-define) are byte-identical.
//
// Run on an iOS Simulator with phases compressed to 1 second each:
//   flutter test integration_test/brush_session_e2e_test.dart \
//     --dart-define=BRUSHING_PHASE_SECONDS=1 -d "iPhone 15"
//
// CI: codemagic.yaml workflow `ios_tests` runs the whole integration_test/
// directory; pass the same --dart-define in that step when this test is
// enabled in CI.

import 'package:brush_quest/screens/brushing_screen.dart';
import 'package:brush_quest/screens/home_screen.dart';
import 'package:brush_quest/screens/victory_screen.dart';
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
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('dev.fluttercommunity.plus/wakelock_plus'),
          (call) async => true,
        );
  });

  setUp(() {
    fakeAudio = FakeAudioService();
    AudioService.testInstance = fakeAudio;
  });

  tearDown(() {
    AudioService.testInstance = null;
  });

  testWidgets('full brush session: HomeScreen → BrushingScreen → VictoryScreen awards a star', (
    tester,
  ) async {
    // Skip onboarding so HomeScreen renders directly. Set phase_duration = 1
    // for belt-and-suspenders speed when run without the dart-define flag —
    // the real fast path is BRUSHING_PHASE_SECONDS=1, which overrides this.
    SharedPreferences.setMockInitialValues(<String, Object>{
      'onboarding_completed': true,
      'phase_duration': 1,
      'camera_enabled': false,
      'camera_mode_configured': true,
      'muted': true,
    });

    await tester.binding.setSurfaceSize(const Size(430, 932));

    // Suppress benign overflow errors that the dense game UI can throw at
    // simulator dimensions; let any other error fail the test.
    final origOnError = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      if (details.toString().contains('overflowed')) return;
      origOnError?.call(details);
    };

    final prefsBefore = await SharedPreferences.getInstance();
    final brushesBefore = prefsBefore.getInt('total_brushes') ?? 0;
    final walletBefore = prefsBefore.getInt('star_wallet') ?? 0;

    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // The hero portrait IS the BRUSH button (see home_screen.dart) — match it
    // by the GestureDetector that calls _startBrushing() on tap-up. We pick
    // the GestureDetector that has both onTapDown and onTapUp wired.
    final heroTap = find.byWidgetPredicate(
      (w) => w is GestureDetector && w.onTapUp != null && w.onTapDown != null,
    );
    expect(heroTap, findsWidgets, reason: 'Hero BRUSH button not found');
    await tester.tap(heroTap.first);
    await tester.pump();

    // _startBrushingFlow() waits 400ms before pushing BrushingScreen. Pump
    // generously to land on the brushing screen and clear its world intro.
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(seconds: 2));
    expect(find.byType(BrushingScreen), findsOneWidget);

    // The world intro auto-dismisses after a short delay — pump until either
    // the countdown or first phase appears, with a generous ceiling.
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 500));
      if (find.byType(VictoryScreen).evaluate().isNotEmpty) break;
    }

    // Drive past countdown (3 → 2 → 1 → GO, ~3s) plus 6 phases at the
    // overridden duration. With BRUSHING_PHASE_SECONDS=1 the floor is
    // 3s + 6s = 9s; we pump 25s to absorb transition padding.
    for (var i = 0; i < 50; i++) {
      if (find.byType(VictoryScreen).evaluate().isNotEmpty) break;
      await tester.pump(const Duration(milliseconds: 500));
    }

    expect(
      find.byType(VictoryScreen),
      findsOneWidget,
      reason: 'Brushing did not transition to VictoryScreen within the budget',
    );

    // VictoryScreen calls StreakService.recordBrush() in its initState
    // animation chain. Pump to let the async chain land before reading prefs.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }

    final prefsAfter = await SharedPreferences.getInstance();
    final brushesAfter = prefsAfter.getInt('total_brushes') ?? 0;
    final walletAfter = prefsAfter.getInt('star_wallet') ?? 0;

    expect(
      brushesAfter,
      brushesBefore + 1,
      reason: 'total_brushes did not increment',
    );
    expect(
      walletAfter,
      greaterThan(walletBefore),
      reason: 'star_wallet should have increased by at least 1 star',
    );

    FlutterError.onError = origOnError;
    await tester.binding.setSurfaceSize(null);
  });
}

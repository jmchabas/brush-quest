import 'package:brush_quest/screens/brushing_screen.dart';
import 'package:brush_quest/widgets/mouth_guide.dart';
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

    // Mock audioplayers platform channel
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
    // Mock wakelock channel
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

  testWidgets('world intro has a close button', (tester) async {
    SharedPreferences.setMockInitialValues({
      'phase_duration': 20,
      'camera_enabled': false,
      'selected_hero': 'blaze',
      'selected_weapon': 'star_blaster',
      'current_world': 'candy_crater',
      'muted': false,
    });

    await tester.binding.setSurfaceSize(const Size(430, 932));

    // Suppress overflow errors in this test (complex game screen)
    final origOnError = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      if (details.toString().contains('overflowed')) return;
      origOnError?.call(details);
    };

    await tester.pumpWidget(const MaterialApp(home: BrushingScreen()));
    // Pump past all internal timers (1.5s Future.delayed in initState)
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    // The world intro stage should show a close button (for exiting)
    expect(find.byIcon(Icons.close), findsWidgets);

    FlutterError.onError = origOnError;
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('brushing: the mouth guide and the seconds, no monster counter '
      'and no sign under the timer', (tester) async {
    // A fresh checkpoint: the screen opens mid-brush, 20 s into a zone.
    SharedPreferences.setMockInitialValues({
      'phase_duration': 30,
      'camera_enabled': false,
      'camera_mode_configured': true,
      'selected_hero': 'blaze',
      'selected_weapon': 'star_blaster',
      'current_world': 'candy_crater',
      'muted': false,
      'total_brushes': 5,
      'session_checkpoint_ts': DateTime.now().millisecondsSinceEpoch,
      'session_checkpoint_phase': 'topLeft',
      'session_checkpoint_seconds': 20,
      'session_checkpoint_world': 'candy_crater',
    });
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    // The game screen's own layout is not under test here.
    final origOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.toString().contains('overflowed')) return;
      origOnError?.call(details);
    };
    addTearDown(() => FlutterError.onError = origOnError);

    await tester.pumpWidget(const MaterialApp(home: BrushingScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // The painters are private: match them by name.
    Finder painted(String painter) => find.byWidgetPredicate(
      (widget) =>
          widget is CustomPaint && '${widget.painter.runtimeType}' == painter,
      description: 'CustomPaint with a $painter',
    );
    expect(find.byType(MouthGuide), findsOneWidget);
    expect(find.text('20'), findsOneWidget); // the zone's seconds
    // The counter: its starburst and its number (0 monsters so far).
    expect(painted('_SmallBurstPainter'), findsNothing);
    expect(find.text('0'), findsNothing);
    // The sign under the timer (crossed swords, shield, hourglass, target).
    expect(painted('_PhaseProgressIconPainter'), findsNothing);

    // Past initState's delays, so no timer outlives the test.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('brushing, a normal start: once the HUD has slid in, the mouth '
      'guide stays at the left and the timer where it was (R-A6)', (
    tester,
  ) async {
    // No checkpoint: the screen counts down, and the HUD slides in as the
    // first zone starts (a resume from a checkpoint never slides it in).
    SharedPreferences.setMockInitialValues({
      'phase_duration': 30,
      'camera_enabled': false,
      'camera_mode_configured': true,
      'selected_hero': 'blaze',
      'selected_weapon': 'star_blaster',
      'current_world': 'candy_crater',
      'muted': false,
      'total_brushes': 5,
    });
    // The layout below is measured at this surface size.
    const surface = Size(430, 932);
    await tester.binding.setSurfaceSize(surface);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    // The game screen's own layout is not under test here.
    final origOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.toString().contains('overflowed')) return;
      origOnError?.call(details);
    };
    addTearDown(() => FlutterError.onError = origOnError);

    await tester.pumpWidget(
      const MaterialApp(home: BrushingScreen(showWorldIntro: false)),
    );
    // The countdown (3 s) and "GO!" (0.8 s), in frames, until the brushing
    // screen is up.
    for (var waited = 0; find.byType(MouthGuide).evaluate().isEmpty; waited++) {
      if (waited > 200) fail('the brushing screen never came up');
      await tester.pump(const Duration(milliseconds: 50));
    }
    // The HUD slides in over 500 ms; the first second has not ticked yet.
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    // The HUD's own guide (the zone's big overlay holds another one).
    final guide = find.descendant(
      of: find.byKey(const ValueKey('mission-hud-topLeft')),
      matching: find.byType(MouthGuide),
    );
    final guideTopLeft = tester.getTopLeft(guide);
    expect(guideTopLeft.dy, 12.0, reason: 'the HUD has slid in');
    expect(guideTopLeft.dx, 12.0, reason: 'the guide stays at the left');
    // The zone's seconds (not ticked yet), where they were when the sign
    // under them was still there: the box that replaced it keeps its room.
    // Measured at 430 x 932, the same as before the sign went (R-A6).
    final timer = find.text('30');
    expect(timer, findsOneWidget);
    expect(
      tester.getRect(timer),
      rectMoreOrLessEquals(
        const Rect.fromLTRB(179, 703.65, 251, 748.65),
        epsilon: 0.01,
      ),
    );

    // Past the zone's delays, so no timer outlives the test.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 4));
  });
}

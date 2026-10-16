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
}

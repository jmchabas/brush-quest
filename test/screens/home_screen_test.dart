import 'package:brush_quest/screens/home_screen.dart';
import 'package:brush_quest/services/audio_service.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../audio/fake_audio_service.dart';

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
  });

  setUp(() {
    fakeAudio = FakeAudioService();
    AudioService.testInstance = fakeAudio;
  });

  tearDown(() {
    AudioService.testInstance = null;
  });

  String todayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> pumpHome(WidgetTester tester) async {
    final today = todayString();
    SharedPreferences.setMockInitialValues({
      'selected_hero': 'blaze',
      'selected_weapon': 'star_blaster',
      'total_stars': 7,
      'current_streak': 2,
      'last_brush_date': today,
      'morning_done_date': today,
      'total_brushes': 5,
      'today_brush_count': 1,
      'today_date': today,
      'muted': false,
    });

    await tester.binding.setSurfaceSize(const Size(430, 932));
    await tester.pumpWidget(
      const MaterialApp(home: HomeScreen(skipGreeting: true)),
    );
    // Allow async _loadStats to complete and rebuild
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('BRUSH QUEST title is visible', (tester) async {
    await pumpHome(tester);

    // The title "BRUSH QUEST" appears twice (stroke outline + fill)
    expect(find.text('BRUSH QUEST'), findsWidgets);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('settings gear icon is present', (tester) async {
    await pumpHome(tester);

    expect(
      find.ancestor(
        of: find.byIcon(Icons.settings),
        matching: find.byType(IconButton),
      ),
      findsOneWidget,
    );

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('star counter renders with correct value', (tester) async {
    await pumpHome(tester);

    // Star icon is present (may be multiple: stats bar + SunMoonTracker center star)
    expect(find.byIcon(Icons.star), findsWidgets);
    // Star count value "7" is rendered
    expect(find.text('7'), findsOneWidget);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('streak counter renders with correct value', (tester) async {
    await pumpHome(tester);

    // Fire icon for streak is present
    expect(find.byIcon(Icons.local_fire_department), findsOneWidget);
    // Streak count value "2" is rendered
    expect(find.text('2'), findsOneWidget);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('BRUSH button is removed (hero tap starts brushing)', (tester) async {
    await pumpHome(tester);

    expect(find.text('BRUSH!'), findsNothing);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('first launch plays voice_tap_hero voice', (tester) async {
    // First launch: totalBrushes = 0, skipGreeting = false
    SharedPreferences.setMockInitialValues({
      'selected_hero': 'blaze',
      'selected_weapon': 'star_blaster',
      'total_stars': 0,
      'current_streak': 0,
      'total_brushes': 0,
      'today_brush_count': 0,
      'muted': false,
    });

    await tester.binding.setSurfaceSize(const Size(430, 932));
    await tester.pumpWidget(
      const MaterialApp(home: HomeScreen()),
    );
    // Allow _loadStats + _checkGreeting to complete
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    // Verify voice_tap_hero.mp3 was played
    final voiceCalls = fakeAudio.callsFor('playVoice');
    final tapHeroPlayed = voiceCalls.any(
      (c) => c.args['fileName'] == 'voice_tap_hero.mp3',
    );
    expect(tapHeroPlayed, isTrue,
        reason: 'First launch should play voice_tap_hero.mp3');

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('mute button shows volume_up when not muted', (tester) async {
    await pumpHome(tester);

    expect(find.byIcon(Icons.volume_up), findsOneWidget);

    await tester.binding.setSurfaceSize(null);
  });
}

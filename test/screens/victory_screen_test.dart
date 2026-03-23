import 'package:brush_quest/screens/victory_screen.dart';
import 'package:brush_quest/widgets/star_rain.dart';
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
    // from AudioPlayer construction during AudioService static initialization.
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

  Future<void> pumpVictory(WidgetTester tester) async {
    final today = todayString();
    SharedPreferences.setMockInitialValues({
      'total_stars': 5,
      'current_streak': 2,
      'best_streak': 3,
      'last_brush_date': today,
      'today_brush_count': 1,
      'today_date': today,
      'total_brushes': 5,
      'selected_hero': 'blaze',
      'selected_weapon': 'star_blaster',
      'unlocked_heroes': ['blaze'],
      'unlocked_weapons': ['star_blaster'],
      'current_world': 'candy_crater',
      'collected_cards': [],
      'muted': false,
    });

    await tester.binding.setSurfaceSize(const Size(430, 932));
    await tester.pumpWidget(
      const MaterialApp(
        home: VictoryScreen(
          starsCollected: 1,
          totalHits: 10,
          monstersDefeated: 4,
        ),
      ),
    );
    // Pump past all internal timers (4s Future.delayed in _recordAndAnimate)
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));
  }

  testWidgets('victory screen shows GREAT JOB text', (tester) async {
    await pumpVictory(tester);
    expect(find.text('GREAT JOB!'), findsOneWidget);
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('victory screen shows StarRain widget', (tester) async {
    await pumpVictory(tester);
    expect(find.byType(StarRain), findsOneWidget);
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('victory screen shows star icons', (tester) async {
    await pumpVictory(tester);
    expect(find.byIcon(Icons.star), findsWidgets);
    await tester.binding.setSurfaceSize(null);
  });
}

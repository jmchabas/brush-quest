import 'package:brush_quest/screens/world_map_screen.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../audio/fake_audio_service.dart';
import 'package:brush_quest/services/audio_service.dart';
import 'package:brush_quest/services/world_service.dart';

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

  Future<void> pumpWorldMap(
    WidgetTester tester, {
    String currentWorld = 'candy_crater',
    Map<String, int> worldProgress = const {},
  }) async {
    // Build SharedPreferences values for world service.
    // World unlock is derived from the *previous* world's progress
    // (isWorldUnlocked checks prevWorld.missionsRequired), so we only
    // need to set progress values.
    final prefs = <String, Object>{
      'current_world': currentWorld,
      'muted': false,
    };
    for (final world in WorldService.allWorlds) {
      prefs['world_progress_${world.id}'] =
          worldProgress[world.id] ?? 0;
    }
    SharedPreferences.setMockInitialValues(prefs);

    await tester.binding.setSurfaceSize(const Size(430, 932));
    await tester.pumpWidget(
      const MaterialApp(home: WorldMapScreen()),
    );
    // Allow async _loadData to complete
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  // ── Voice playback (first test — static _introPlayedThisSession) ───

  testWidgets('intro voice plays on screen load', (tester) async {
    await pumpWorldMap(tester);

    // The intro voice uses a static flag (_introPlayedThisSession) so it
    // only plays once per app session. This test must run first.
    final introVoices = fakeAudio.callsFor('playVoice').where(
          (c) => c.args['fileName'] == 'voice_world_map_intro.mp3',
        );
    expect(introVoices.isNotEmpty, isTrue,
        reason: 'World map intro voice should play on first load');

    await tester.binding.setSurfaceSize(null);
  });

  // ── Screen rendering ─────────────────────────────────────────

  testWidgets('world map screen shows WORLD MAP title', (tester) async {
    await pumpWorldMap(tester);

    expect(find.text('WORLD MAP'), findsOneWidget);

    await tester.binding.setSurfaceSize(null);
  });

  // ── Back button ──────────────────────────────────────────────

  testWidgets('back button is present with arrow_back icon', (tester) async {
    await pumpWorldMap(tester);

    expect(find.byIcon(Icons.arrow_back), findsOneWidget);

    await tester.binding.setSurfaceSize(null);
  });

  // ── Planet nodes ─────────────────────────────────────────────

  testWidgets('planet nodes render for all worlds', (tester) async {
    await pumpWorldMap(tester);

    // Each world should show its name in uppercase. Check the first world
    // which is always visible without scrolling.
    final firstWorld = WorldService.allWorlds.first;
    expect(
      find.text(firstWorld.name.toUpperCase()),
      findsOneWidget,
      reason: '${firstWorld.name} should be visible on the map',
    );

    await tester.binding.setSurfaceSize(null);
  });

  // ── Lock indicator ───────────────────────────────────────────

  testWidgets('locked worlds show lock icon', (tester) async {
    // Only candy_crater is unlocked — the rest should show lock icons
    await pumpWorldMap(tester);

    // Lock icons should be present for locked worlds
    expect(find.byIcon(Icons.lock), findsWidgets);

    await tester.binding.setSurfaceSize(null);
  });

  // ── Current world indicator ──────────────────────────────────

  testWidgets('current world shows rocket launch icon', (tester) async {
    await pumpWorldMap(tester);

    // The current world has a rocket_launch icon as a beacon
    expect(find.byIcon(Icons.rocket_launch), findsOneWidget);

    await tester.binding.setSurfaceSize(null);
  });

  // ── Completed world ──────────────────────────────────────────

  testWidgets('completed world shows COMPLETE label', (tester) async {
    // Candy Crater requires a certain number of missions — complete it
    final candyCrater = WorldService.allWorlds.first;
    await pumpWorldMap(
      tester,
      worldProgress: {'candy_crater': candyCrater.missionsRequired},
    );

    expect(find.text('COMPLETE'), findsOneWidget);

    await tester.binding.setSurfaceSize(null);
  });
}

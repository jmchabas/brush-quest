import 'package:brush_quest/screens/trophy_wall_screen.dart';
import 'package:brush_quest/services/trophy_service.dart';
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
  });

  setUp(() {
    fakeAudio = FakeAudioService();
    AudioService.testInstance = fakeAudio;
  });

  tearDown(() {
    AudioService.testInstance = null;
  });

  Future<void> pumpTrophyWall(
    WidgetTester tester, {
    List<String> capturedIds = const [],
    String currentWorld = 'candy_crater',
  }) async {
    // Seed shared preferences with trophy data
    final prefs = <String, Object>{
      'current_world': currentWorld,
      'trophy_captured': capturedIds,
      'muted': false,
    };
    // Set defeat counts for captured trophies to their required value
    for (final id in capturedIds) {
      final trophy = TrophyService.allTrophies.firstWhere(
        (t) => t.id == id,
        orElse: () => TrophyService.allTrophies.first,
      );
      prefs['trophy_defeats_$id'] = trophy.defeatsRequired;
    }
    SharedPreferences.setMockInitialValues(prefs);

    await tester.binding.setSurfaceSize(const Size(430, 932));
    await tester.pumpWidget(const MaterialApp(home: TrophyWallScreen()));
    // Let async _loadData complete
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  // ── World tabs render ────────────────────────────────────────

  testWidgets('world tabs render with first world visible', (tester) async {
    await pumpTrophyWall(tester);
    // The first world is Candy Crater. The world selector shows
    // abbreviated world names — first word uppercased.
    // Candy Crater -> "CANDY"
    expect(find.text('CANDY'), findsOneWidget);
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('selected world name appears below selector', (tester) async {
    await pumpTrophyWall(tester);
    // The world name is displayed in uppercase below the world selector
    expect(find.text('CANDY CRATER'), findsOneWidget);
    await tester.binding.setSurfaceSize(null);
  });

  // ── Trophy grid renders ──────────────────────────────────────

  testWidgets('trophy grid shows correct number of tiles for Candy Crater', (
    tester,
  ) async {
    await pumpTrophyWall(tester);
    // C15: "???" text removed per Jim's call — uncaptured tiles now show
    // grayed silhouettes with no name text (icon-only for non-readers).
    // So the assertion is: zero trophy-slot Text widgets with "???" text,
    // AND zero captured-name Text widgets (since capturedIds is empty).
    expect(find.text('???'), findsNothing);
    // Captured names aren't present yet — verify the world name header is.
    expect(find.text('CANDY CRATER'), findsWidgets);
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('world progress counter shows for current world', (tester) async {
    await pumpTrophyWall(tester);
    // With 0 captured in Candy Crater (5 trophies), shows "0 / 5"
    expect(find.text('0 / 5'), findsOneWidget);
    await tester.binding.setSurfaceSize(null);
  });

  // ── Captured vs uncaptured display ───────────────────────────

  testWidgets('captured trophies show monster name, uncaptured show no text', (
    tester,
  ) async {
    // Capture the first two Candy Crater trophies
    await pumpTrophyWall(tester, capturedIds: ['cc_t1', 'cc_t2']);
    // Captured trophies show their actual names
    expect(find.text('Gummy Grub'), findsOneWidget);
    expect(find.text('Lollipop Lurker'), findsOneWidget);
    // C15: uncaptured tiles no longer render "???" — they show silhouette
    // only. Verify zero "???" Text widgets anywhere on screen.
    expect(find.text('???'), findsNothing);
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('captured trophies update world progress counter', (
    tester,
  ) async {
    await pumpTrophyWall(tester, capturedIds: ['cc_t1', 'cc_t2']);
    expect(find.text('2 / 5'), findsOneWidget);
    await tester.binding.setSurfaceSize(null);
  });

  // ── Counter display (total) ──────────────────────────────────

  testWidgets('total counter shows captured count out of 50', (tester) async {
    await pumpTrophyWall(tester);
    // Header shows total captured: "0" and "/ 50"
    expect(find.text('0'), findsOneWidget);
    expect(find.text(' / ${TrophyService.allTrophies.length}'), findsOneWidget);
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('total counter reflects captured trophies', (tester) async {
    await pumpTrophyWall(tester, capturedIds: ['cc_t1', 'cc_t3', 'ss_t1']);
    // 3 captured total
    expect(find.text('3'), findsOneWidget);
    await tester.binding.setSurfaceSize(null);
  });

  // ── Uncaptured trophies show lock icon ───────────────────────

  testWidgets('uncaptured trophies with no defeats show lock icon', (
    tester,
  ) async {
    await pumpTrophyWall(tester);
    // Each uncaptured trophy with 0 defeats shows a lock_rounded icon
    expect(find.byIcon(Icons.lock_rounded), findsWidgets);
    await tester.binding.setSurfaceSize(null);
  });

  // ── MONSTERS CAUGHT label ────────────────────────────────────

  testWidgets('header shows MONSTERS CAUGHT label', (tester) async {
    await pumpTrophyWall(tester);
    expect(find.text('MONSTERS CAUGHT'), findsOneWidget);
    await tester.binding.setSurfaceSize(null);
  });
}

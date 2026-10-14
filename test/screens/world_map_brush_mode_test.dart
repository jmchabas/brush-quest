// test/screens/world_map_brush_mode_test.dart
//
// The Map in brush mode (spec 2026-10-13 §4, §5) and the pins that it is
// unchanged when opened from Home (R6). Test order matters: the first test
// opens the Map in brush mode, and the second checks that this did not use
// up the once-a-session intro (a static flag).
import 'package:brush_quest/screens/brush_mode.dart';
import 'package:brush_quest/screens/world_map_screen.dart';
import 'package:brush_quest/services/audio_service.dart';
import 'package:brush_quest/services/goal_service.dart';
import 'package:brush_quest/services/world_service.dart';
import 'package:brush_quest/widgets/goal_glow.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../audio/fake_audio_service.dart';

/// Stands in for the brush steps: owns what the page follows and records
/// what it reports.
class _Steps {
  final tab = ValueNotifier<int>(0);
  final highlight = ValueNotifier<String?>(null);
  final reveal = BrushPing();
  final changes = <BrushChange>[];
  int closes = 0;

  late final mode = BrushMode(
    onClose: () => closes++,
    tab: tab,
    onTabChanged: (_) {},
    highlightId: highlight,
    reveal: reveal,
    onChanged: changes.add,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeAudioService fakeAudio;

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    for (final name in [
      'xyz.luan/audioplayers.global',
      'xyz.luan/audioplayers',
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannel(name), (call) async => 1);
    }
  });

  setUp(() {
    fakeAudio = FakeAudioService();
    AudioService.testInstance = fakeAudio;
  });

  tearDown(() => AudioService.testInstance = null);

  Future<_Steps> pumpMap(
    WidgetTester tester, {
    bool brush = true,
    String? highlight,
    Map<String, int> progress = const {},
  }) async {
    final prefs = <String, Object>{
      'current_world': 'candy_crater',
      'muted': false,
    };
    for (final world in WorldService.allWorlds) {
      prefs['world_progress_${world.id}'] = progress[world.id] ?? 0;
    }
    SharedPreferences.setMockInitialValues(prefs);
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final steps = _Steps()..highlight.value = highlight;
    await tester.pumpWidget(
      MaterialApp(
        home: brush
            ? WorldMapScreen(brushMode: steps.mode)
            : const WorldMapScreen(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    return steps;
  }

  Rect scrollView(WidgetTester tester) =>
      tester.getRect(find.byType(SingleChildScrollView));

  /// The locked look: a locked planet is dimmed to this opacity.
  Finder lockedDim() => find.byWidgetPredicate(
    (widget) => widget is Opacity && widget.opacity == 0.65,
    description: 'Opacity 0.65',
  );

  testWidgets('brush mode: no intro, world line or music when it opens', (
    tester,
  ) async {
    await pumpMap(tester);
    expect(fakeAudio.playedVoiceLines, isEmpty);
    expect(fakeAudio.callsFor('playMusic'), isEmpty);
    expect(fakeAudio.callsFor('setMusicVolume'), isEmpty);
  });

  testWidgets('from Home: its intro once a session, world line and music', (
    tester,
  ) async {
    await pumpMap(tester, brush: false);
    expect(fakeAudio.playedVoiceLines, [
      'voice_world_map_intro.mp3',
      'voice_world_candy_crater.mp3',
    ]);
    expect(
      fakeAudio.calls,
      contains(const AudioCall('setMusicVolume', {'volume': 0.04})),
    );
    expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    expect(find.byType(GoalGlow), findsNothing);
    expect(
      tester
          .widget<SingleChildScrollView>(find.byType(SingleChildScrollView))
          .padding,
      const EdgeInsets.only(bottom: 40, top: 8),
    );
  });

  testWidgets('an X instead of the back arrow; it asks the steps to close', (
    tester,
  ) async {
    final steps = await pumpMap(tester);
    expect(find.byIcon(Icons.arrow_back), findsNothing);
    await tester.tap(find.byKey(const ValueKey('brush_close')));
    await tester.pump();
    expect(steps.closes, 1);
    expect(fakeAudio.callsFor('stopVoice'), isEmpty);
  });

  testWidgets('the highlighted planet glows in a circle', (tester) async {
    await pumpMap(tester, highlight: 'slime_swamp');
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('planet_slime_swamp')),
        matching: find.byType(GoalGlow),
      ),
      findsOneWidget,
    );
    expect(find.byType(GoalGlow), findsOneWidget);
    expect(tester.widget<GoalGlow>(find.byType(GoalGlow)).circle, isTrue);
  });

  testWidgets('the glow on a locked planet is at full strength; the planet '
      'keeps its locked look', (tester) async {
    await pumpMap(tester, highlight: 'slime_swamp');
    final glow = find.byType(GoalGlow);
    // Nothing dims the glow: no Opacity above it is below 1.0.
    final above = tester.widgetList<Opacity>(
      find.ancestor(of: glow, matching: find.byType(Opacity)),
    );
    expect(above.where((opacity) => opacity.opacity < 1.0), isEmpty);
    // The parts of the planet are dimmed one by one instead: its image
    // (inside the glow), its name and its lock.
    expect(find.descendant(of: glow, matching: lockedDim()), findsOneWidget);
    expect(
      find.ancestor(of: find.text('SLIME SWAMP'), matching: lockedDim()),
      findsOneWidget,
    );
    expect(
      find.ancestor(
        of: find.descendant(
          of: find.byKey(const ValueKey('planet_slime_swamp')),
          matching: find.byIcon(Icons.lock),
        ),
        matching: lockedDim(),
      ),
      findsOneWidget,
    );
  });

  testWidgets('a locked planet that is not glowing is dimmed as a whole, as '
      'before', (tester) async {
    await pumpMap(tester, highlight: 'slime_swamp');
    final node = find.byKey(const ValueKey('planet_sugar_volcano'));
    // One Opacity in the whole node: its own, around everything.
    expect(
      find.descendant(of: node, matching: find.byType(Opacity)),
      findsOneWidget,
    );
    expect(find.descendant(of: node, matching: lockedDim()), findsOneWidget);
    expect(
      find.ancestor(of: find.text('SUGAR VOLCANO'), matching: lockedDim()),
      findsOneWidget,
    );
  });

  testWidgets('a reveal scrolls a far planet above GO', (tester) async {
    final steps = await pumpMap(tester, highlight: 'dark_dimension');
    expect(
      tester.getRect(find.byType(GoalGlow)).top,
      greaterThan(scrollView(tester).bottom),
      reason: 'the last planet starts off screen',
    );
    steps.reveal.ping();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    final glow = tester.getRect(find.byType(GoalGlow));
    expect(glow.top, greaterThanOrEqualTo(scrollView(tester).top));
    expect(
      glow.bottom,
      lessThanOrEqualTo(scrollView(tester).bottom - kBrushGoClearance),
    );
  });

  testWidgets('the last planet can scroll above GO', (tester) async {
    await pumpMap(tester);
    expect(
      tester
          .widget<SingleChildScrollView>(find.byType(SingleChildScrollView))
          .padding,
      const EdgeInsets.only(bottom: 40 + kBrushGoClearance, top: 8),
    );
    final position = tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position;
    position.jumpTo(position.maxScrollExtent);
    await tester.pump();
    expect(
      tester
          .getRect(find.byKey(const ValueKey('planet_dark_dimension')))
          .bottom,
      lessThanOrEqualTo(scrollView(tester).bottom - kBrushGoClearance),
    );
  });

  testWidgets('picking an open planet: its line once, saved, reported', (
    tester,
  ) async {
    final steps = await pumpMap(tester, progress: {'candy_crater': 5});
    await tester.tap(find.byKey(const ValueKey('planet_slime_swamp')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    // The page's own line from the tap; the reload does not say it again.
    expect(fakeAudio.playedVoiceLines, ['voice_world_slime_swamp.mp3']);
    expect(fakeAudio.callsFor('playMusic'), isEmpty);
    expect(steps.changes, [const BrushChange.selected(GoalCategory.world)]);
    final saved = await SharedPreferences.getInstance();
    expect(saved.getString('current_world'), 'slime_swamp');
  });

  testWidgets('a locked planet: its line and "Keep brushing", no change', (
    tester,
  ) async {
    final steps = await pumpMap(tester);
    await tester.tap(find.byKey(const ValueKey('planet_slime_swamp')));
    await tester.pump();
    expect(fakeAudio.playedVoiceLines, [
      'voice_world_slime_swamp.mp3',
      'voice_need_more_brushes.mp3',
    ]);
    expect(steps.changes, isEmpty);
  });

  testWidgets('leaving the Map leaves the voice to brushing', (tester) async {
    await pumpMap(tester);
    await tester.pumpWidget(const SizedBox());
    expect(fakeAudio.callsFor('stopVoice'), isEmpty);
  });

  testWidgets('from Home, leaving the Map stops the voice, as before', (
    tester,
  ) async {
    await pumpMap(tester, brush: false);
    await tester.pumpWidget(const SizedBox());
    expect(fakeAudio.callsFor('stopVoice'), isNotEmpty);
  });
}

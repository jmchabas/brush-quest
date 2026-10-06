import 'package:brush_quest/screens/brushing_screen.dart';
import 'package:brush_quest/screens/pre_brush_screen.dart';
import 'package:brush_quest/services/audio_service.dart';
import 'package:brush_quest/widgets/item_silhouette.dart';
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
  late FakeAudioService audio;
  bool? launchedWithIntro;

  setUpAll(() async {
    // The hand-off group builds the real BrushingScreen (Firebase, audio
    // players, wakelock), and tearDown's `testInstance = null` builds a real
    // AudioService, whose players talk to the audioplayers channels.
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      ..setMockMethodCallHandler(
        const MethodChannel('xyz.luan/audioplayers.global'),
        (call) async => 1,
      )
      ..setMockMethodCallHandler(
        const MethodChannel('xyz.luan/audioplayers'),
        (call) async => 1,
      )
      ..setMockMethodCallHandler(
        const MethodChannel('dev.fluttercommunity.plus/wakelock_plus'),
        (call) async => true,
      );
  });

  setUp(() {
    audio = FakeAudioService();
    AudioService.testInstance = audio;
    launchedWithIntro = null;
    PreBrushScreen.minStep = const Duration(milliseconds: 300);
    PreBrushScreen.maxStep = const Duration(milliseconds: 500);
    PreBrushScreen.maxBriefingStep = const Duration(milliseconds: 800);
    PreBrushScreen.idleAfterTouch = const Duration(milliseconds: 400);
    PreBrushScreen.launchDelay = const Duration(milliseconds: 50);
    PreBrushScreen.debugBrushingBuilder = ({required showWorldIntro}) {
      launchedWithIntro = showWorldIntro;
      return const Scaffold(body: Text('BRUSHING'));
    };
  });

  tearDown(() {
    AudioService.testInstance = null;
    PreBrushScreen.debugBrushingBuilder = null;
  });

  Future<void> pumpScreen(
    WidgetTester tester,
    Map<String, Object> prefs,
  ) async {
    SharedPreferences.setMockInitialValues(prefs);
    await tester.pumpWidget(const MaterialApp(home: PreBrushScreen()));
    await tester.pump(); // load
    await tester.pump();
  }

  List<String> voices() => audio.playedVoiceLines;

  /// Runs [body] with debugPrint collected, so expected error logs are
  /// checked rather than printed. It is restored before the test ends, as
  /// flutter_test requires.
  Future<List<String?>> collectDebugPrint(Future<void> Function() body) async {
    final printed = <String?>[];
    final original = debugPrint;
    debugPrint = (message, {wrapWidth}) => printed.add(message);
    try {
      await body();
    } finally {
      debugPrint = original;
    }
    return printed;
  }

  final returningKid = <String, Object>{
    'total_brushes': 4,
    'star_wallet': 3,
    'unlocked_heroes': ['blaze'],
    'selected_hero': 'blaze',
    'unlocked_weapons': ['star_blaster'],
    'selected_weapon': 'star_blaster',
    'current_world': 'candy_crater',
    'world_progress_candy_crater': 2,
    'brush_history': [
      '{"date":"2026-10-04","time":"19:30","heroId":"blaze","worldId":"candy_crater"}',
    ],
  };

  // The fake never raises voicePipelineActiveNotifier, so each step advances
  // at minStep (300 ms). Pump 350 ms per step: long enough for one step,
  // short enough not to run into the next step's timer (which starts later).
  const oneStep = Duration(milliseconds: 350);

  testWidgets(
    'three steps auto-advance, then brushing without its world intro',
    (tester) async {
      await pumpScreen(tester, returningKid);
      expect(find.byKey(const ValueKey('prebrush_step_hero')), findsOneWidget);
      expect(voices().first, 'voice_stars_left_2.mp3'); // frost 5 - wallet 3
      await tester.pump(oneStep); // hero -> weapon
      expect(
        find.byKey(const ValueKey('prebrush_step_weapon')),
        findsOneWidget,
      );
      expect(voices().last, 'voice_stars_left_2.mp3'); // flame sword 5 - 3
      await tester.pump(oneStep); // weapon -> world
      expect(find.byKey(const ValueKey('prebrush_step_world')), findsOneWidget);
      expect(voices().last, 'voice_brushes_left_3.mp3'); // 5 - 2, same planet
      await tester.pump(oneStep); // world -> fight
      expect(voices().last, 'voice_lets_fight.mp3');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();
      expect(find.text('BRUSHING'), findsOneWidget);
      expect(launchedWithIntro, isFalse);
      expect(voices(), [
        'voice_stars_left_2.mp3',
        'voice_stars_left_2.mp3',
        'voice_brushes_left_3.mp3',
        'voice_lets_fight.mp3',
      ]);
    },
  );

  testWidgets('a new planet plays its full briefing', (tester) async {
    final prefs = Map<String, Object>.from(returningKid)
      ..['current_world'] = 'slime_swamp'
      ..['world_progress_candy_crater'] = 5;
    await pumpScreen(tester, prefs);
    await tester.pump(oneStep);
    await tester.pump(oneStep);
    expect(voices(), contains('voice_world_slime_swamp.mp3'));
    expect(voices().last, 'voice_brushes_left_5.mp3'); // slime_swamp 0 of 5
  });

  testWidgets('a touch pauses auto-advance; idle continues', (tester) async {
    PreBrushScreen.idleAfterTouch = const Duration(seconds: 1);
    final prefs = Map<String, Object>.from(returningKid)
      ..['unlocked_heroes'] = ['blaze', 'frost'];
    await pumpScreen(tester, prefs);
    await tester.tap(find.byKey(const ValueKey('carousel_next')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300)); // page animation
    expect(find.byKey(const ValueKey('prebrush_go')), findsOneWidget);
    // The choice is saved and spoken once the carousel has settled (~300 ms).
    await tester.pump(const Duration(milliseconds: 350));
    expect(voices(), contains('voice_picker_hero_frost.mp3'));
    // Past minStep and maxStep, but still on the hero step: the touch paused it.
    expect(find.byKey(const ValueKey('prebrush_step_hero')), findsOneWidget);
    // 1 s with no touch, counted from when the carousel came to rest (250 ms).
    await tester.pump(const Duration(milliseconds: 650));
    expect(find.byKey(const ValueKey('prebrush_step_weapon')), findsOneWidget);
    final p = await SharedPreferences.getInstance();
    expect(p.getString('selected_hero'), 'frost');
  });

  testWidgets('GO advances at once', (tester) async {
    PreBrushScreen.idleAfterTouch = const Duration(seconds: 1);
    final prefs = Map<String, Object>.from(returningKid)
      ..['unlocked_heroes'] = ['blaze', 'frost'];
    await pumpScreen(tester, prefs);
    await tester.tap(find.byKey(const ValueKey('carousel_next')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const ValueKey('prebrush_go')));
    await tester.pump();
    expect(find.byKey(const ValueKey('prebrush_step_weapon')), findsOneWidget);
  });

  testWidgets('goal panel tap plays the need-more line for its category', (
    tester,
  ) async {
    await pumpScreen(tester, returningKid);
    await tester.tap(find.byKey(const ValueKey('prebrush_goal')));
    await tester.pump();
    expect(voices().last, 'voice_need_stars.mp3');
  });

  testWidgets('everything owned: crowns and "you have them all"', (
    tester,
  ) async {
    final all = <String, Object>{
      'total_brushes': 400,
      'star_wallet': 0,
      'unlocked_heroes': ['blaze', 'frost', 'bolt', 'shadow', 'leaf', 'nova'],
      'selected_hero': 'nova',
      'unlocked_evolutions': ['nova_stage2', 'nova_stage3'],
      'evolution_stage_nova': 3,
      'unlocked_weapons': [
        'star_blaster',
        'flame_sword',
        'ice_hammer',
        'lightning_wand',
        'vine_whip',
        'cosmic_burst',
      ],
      'current_world': 'dark_dimension',
    };
    for (final w in ['candy_crater', 'slime_swamp']) {
      all['world_progress_$w'] = 5;
    }
    all.addAll({
      'world_progress_sugar_volcano': 6,
      'world_progress_shadow_nebula': 6,
      'world_progress_cavity_fortress': 7,
      'world_progress_frozen_tundra': 7,
      'world_progress_toxic_jungle': 7,
      'world_progress_crystal_cave': 8,
      'world_progress_storm_citadel': 8,
      'world_progress_dark_dimension': 10,
    });
    await pumpScreen(tester, all);
    expect(find.byKey(const ValueKey('meter_crown')), findsOneWidget);
    expect(voices().first, 'voice_have_them_all.mp3');
  });

  testWidgets('advances at the cap when the voice never ends', (tester) async {
    await pumpScreen(tester, returningKid);
    audio.voicePipelineActiveNotifier.value = true; // stuck voice
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byKey(const ValueKey('prebrush_step_weapon')), findsOneWidget);
  });

  testWidgets('pause stops auto-advance; resume restarts the step', (
    tester,
  ) async {
    await pumpScreen(tester, returningKid);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 2));
    expect(find.byKey(const ValueKey('prebrush_step_hero')), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(oneStep);
    expect(find.byKey(const ValueKey('prebrush_step_weapon')), findsOneWidget);
  });

  testWidgets('a load error skips to brushing with its world intro', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'total_brushes': 3,
      'brush_history': ['not json'], // getHistory() throws FormatException
    });
    final printed = await collectDebugPrint(() async {
      await tester.pumpWidget(const MaterialApp(home: PreBrushScreen()));
      await tester.pumpAndSettle();
    });
    expect(find.text('BRUSHING'), findsOneWidget);
    expect(launchedWithIntro, isTrue);
    expect(printed.single, startsWith('PreBrush load failed: FormatException'));
  });

  // ── Added beyond the brief: spec §4.2/§4.3/§11, rulings R1/R3 and the
  // controller rulings for this task (debounce, opaque art, small phones).

  testWidgets(
    'waits for a voice longer than minStep, then advances when it ends',
    (tester) async {
      await pumpScreen(tester, returningKid);
      audio.voicePipelineActiveNotifier.value = true; // still speaking
      await tester.pump(const Duration(milliseconds: 400)); // past minStep
      expect(find.byKey(const ValueKey('prebrush_step_hero')), findsOneWidget);
      audio.voicePipelineActiveNotifier.value = false; // the line ends
      await tester.pump();
      expect(
        find.byKey(const ValueKey('prebrush_step_weapon')),
        findsOneWidget,
      );
    },
  );

  testWidgets('the latest brush decides whether the planet is new', (
    tester,
  ) async {
    // brush_history is stored oldest first. The latest brush was on Slime
    // Swamp, the current planet, so there is no briefing.
    final prefs = Map<String, Object>.from(returningKid)
      ..['current_world'] = 'slime_swamp'
      ..['world_progress_candy_crater'] = 5
      ..['world_progress_slime_swamp'] = 2
      ..['brush_history'] = [
        '{"date":"2026-10-03","time":"19:30","heroId":"blaze","worldId":"candy_crater"}',
        '{"date":"2026-10-04","time":"19:30","heroId":"blaze","worldId":"slime_swamp"}',
      ];
    await pumpScreen(tester, prefs);
    await tester.pump(oneStep);
    await tester.pump(oneStep);
    expect(find.byKey(const ValueKey('prebrush_step_world')), findsOneWidget);
    expect(voices(), isNot(contains('voice_world_slime_swamp.mp3')));
    expect(voices().last, 'voice_brushes_left_3.mp3'); // slime_swamp 2 of 5
  });

  testWidgets('a choice is saved and spoken only once the carousel settles', (
    tester,
  ) async {
    PreBrushScreen.idleAfterTouch = const Duration(seconds: 5);
    final prefs = Map<String, Object>.from(returningKid)
      ..['unlocked_heroes'] = ['blaze', 'frost'];
    await pumpScreen(tester, prefs);
    final saved = await SharedPreferences.getInstance();

    // Arrow to Frost and straight back: the carousel passes Frost but settles
    // on Blaze, so nothing is saved or said.
    await tester.tap(find.byKey(const ValueKey('carousel_next')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150)); // Frost centred
    await tester.tap(find.byKey(const ValueKey('carousel_prev')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150)); // Blaze centred
    await tester.pump(const Duration(milliseconds: 350));
    expect(saved.getString('selected_hero'), 'blaze');
    expect(voices().where((v) => v.startsWith('voice_picker_')), isEmpty);

    // Arrow to Frost and stay: saved and spoken once, ~300 ms after it settles.
    await tester.tap(find.byKey(const ValueKey('carousel_next')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300)); // animation done
    expect(saved.getString('selected_hero'), 'blaze'); // not yet
    expect(voices(), isNot(contains('voice_picker_hero_frost.mp3')));
    await tester.pump(const Duration(milliseconds: 350));
    expect(saved.getString('selected_hero'), 'frost');
    expect(
      voices().where((v) => v == 'voice_picker_hero_frost.mp3'),
      hasLength(1),
    );
  });

  testWidgets('GO right after a swipe saves the centred item', (tester) async {
    PreBrushScreen.idleAfterTouch = const Duration(seconds: 5);
    final prefs = Map<String, Object>.from(returningKid)
      ..['unlocked_heroes'] = ['blaze', 'frost'];
    await pumpScreen(tester, prefs);
    await tester.tap(find.byKey(const ValueKey('carousel_next')));
    await tester.pump();
    // Frost is centred but not saved yet.
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const ValueKey('prebrush_go')));
    await tester.pump();
    expect(find.byKey(const ValueKey('prebrush_step_weapon')), findsOneWidget);
    final saved = await SharedPreferences.getInstance();
    expect(saved.getString('selected_hero'), 'frost');
    // The weapon step speaks now; Frost's picker line would only be cut off.
    expect(voices(), isNot(contains('voice_picker_hero_frost.mp3')));
    expect(voices().last, 'voice_stars_left_2.mp3');
  });

  /// Opens the screen from a stand-in Home, so X has somewhere to go back to.
  Future<void> openFromHome(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: IconButton(
                key: const ValueKey('open'),
                icon: const Icon(Icons.play_arrow),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const PreBrushScreen(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('open')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500)); // route transition
  }

  testWidgets('X goes back; nothing plays or launches afterwards', (
    tester,
  ) async {
    PreBrushScreen.minStep = const Duration(seconds: 10);
    PreBrushScreen.maxStep = const Duration(seconds: 10);
    SharedPreferences.setMockInitialValues(returningKid);
    await openFromHome(tester);
    expect(find.byKey(const ValueKey('prebrush_step_hero')), findsOneWidget);
    final heard = voices().length;
    await tester.tap(find.byKey(const ValueKey('prebrush_back')));
    await tester.pumpAndSettle();
    expect(find.byType(PreBrushScreen), findsNothing);
    expect(find.byKey(const ValueKey('open')), findsOneWidget);
    expect(audio.callsFor('stopVoice'), isNotEmpty);
    await tester.pump(const Duration(seconds: 15)); // past every step timer
    expect(voices(), hasLength(heard));
    expect(launchedWithIntro, isNull);
  });

  testWidgets('X while a line is still playing: the next step never speaks', (
    tester,
  ) async {
    PreBrushScreen.maxStep = const Duration(seconds: 10);
    SharedPreferences.setMockInitialValues(returningKid);
    audio.voicePipelineActiveNotifier.value = true; // the step line runs long
    await openFromHome(tester); // past minStep, still on the hero step
    expect(find.byKey(const ValueKey('prebrush_step_hero')), findsOneWidget);
    final heard = voices().length;
    await tester.tap(find.byKey(const ValueKey('prebrush_back')));
    await tester.pump();
    audio.voicePipelineActiveNotifier.value = false; // stopVoice ends the line
    await tester.pumpAndSettle();
    expect(find.byType(PreBrushScreen), findsNothing);
    expect(voices(), hasLength(heard));
  });

  testWidgets('X right after a swipe keeps the centred item, silently', (
    tester,
  ) async {
    PreBrushScreen.minStep = const Duration(seconds: 10);
    PreBrushScreen.maxStep = const Duration(seconds: 10);
    PreBrushScreen.idleAfterTouch = const Duration(seconds: 5);
    SharedPreferences.setMockInitialValues(
      Map<String, Object>.from(returningKid)
        ..['unlocked_heroes'] = ['blaze', 'frost'],
    );
    await openFromHome(tester);
    expect(find.byKey(const ValueKey('prebrush_step_hero')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('carousel_next')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250)); // Frost centred
    await tester.tap(find.byKey(const ValueKey('prebrush_back')));
    await tester.pumpAndSettle();
    final saved = await SharedPreferences.getInstance();
    expect(saved.getString('selected_hero'), 'frost');
    expect(voices(), isNot(contains('voice_picker_hero_frost.mp3')));
  });

  // ── Pause, exit and launch paths; voice gates (task review fixes). The
  // fake's stopVoice() ends the voice pipeline at once, like the real one.

  Future<void> pumpUntilLetsFight(WidgetTester tester) async {
    for (var i = 0; i < 100; i++) {
      if (voices().isNotEmpty && voices().last == 'voice_lets_fight.mp3') {
        return;
      }
      await tester.pump(const Duration(milliseconds: 10));
    }
    fail('the steps never finished');
  }

  testWidgets('a pause while a line plays runs nothing in the background', (
    tester,
  ) async {
    await pumpScreen(tester, returningKid);
    audio.voicePipelineActiveNotifier.value = true; // the step line runs long
    await tester.pump(const Duration(milliseconds: 400)); // past minStep
    final heard = voices().length;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 3)); // past every cap
    expect(find.byKey(const ValueKey('prebrush_step_hero')), findsOneWidget);
    expect(voices(), hasLength(heard));
    expect(launchedWithIntro, isNull);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.byKey(const ValueKey('prebrush_step_hero')), findsOneWidget);
    expect(voices().last, 'voice_stars_left_2.mp3'); // the step starts again
    expect(launchedWithIntro, isNull);
  });

  testWidgets('a resume with no pause before it does not restart the step', (
    tester,
  ) async {
    await pumpScreen(tester, returningKid);
    final heard = voices().length;
    // The notification shade or a system dialog: inactive, then resumed.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(voices(), hasLength(heard));
    await tester.pump(oneStep); // the original step timers still run
    expect(find.byKey(const ValueKey('prebrush_step_weapon')), findsOneWidget);
  });

  testWidgets('a pause after "Let\'s fight!" launches brushing on resume', (
    tester,
  ) async {
    // Frames stop while paused, so a route pushed in the background can't be
    // seen with a finder: watch the navigator instead.
    final routes = _ReplaceLog();
    SharedPreferences.setMockInitialValues(returningKid);
    await tester.pumpWidget(
      MaterialApp(home: const PreBrushScreen(), navigatorObservers: [routes]),
    );
    await tester.pump();
    await tester.pump();
    await pumpUntilLetsFight(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 5)); // past every launch timer
    expect(routes.replaced, isEmpty); // nothing launched in the background
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(routes.replaced, hasLength(1));
    expect(find.text('BRUSHING'), findsOneWidget);
    expect(launchedWithIntro, isFalse);
  });

  testWidgets('a goal press released after "Let\'s fight!" says nothing', (
    tester,
  ) async {
    await pumpScreen(tester, returningKid);
    await tester.pump(oneStep); // weapon
    await tester.pump(oneStep); // world
    final press = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('prebrush_goal'))),
    );
    await pumpUntilLetsFight(tester); // the step ends under the finger
    final heard = voices().length;
    await press.up();
    await tester.pump();
    expect(voices().sublist(heard), isEmpty);
  });

  testWidgets('a finger resting on the carousel holds the step until lifted', (
    tester,
  ) async {
    final prefs = Map<String, Object>.from(returningKid)
      ..['unlocked_heroes'] = ['blaze', 'frost']; // a carousel that can scroll
    await pumpScreen(tester, prefs);
    final finger = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('carousel_hero'))),
    );
    await tester.pump(const Duration(seconds: 2)); // never moves
    expect(find.byKey(const ValueKey('prebrush_step_hero')), findsOneWidget);
    await finger.up();
    final weaponStep = find.byKey(const ValueKey('prebrush_step_weapon'));
    var waited = Duration.zero;
    while (weaponStep.evaluate().isEmpty &&
        waited < const Duration(seconds: 2)) {
      await tester.pump(const Duration(milliseconds: 50));
      waited += const Duration(milliseconds: 50);
    }
    expect(weaponStep, findsOneWidget);
    expect(waited, greaterThanOrEqualTo(PreBrushScreen.idleAfterTouch));
  });

  testWidgets('"Let\'s fight!" plays out before brushing starts', (
    tester,
  ) async {
    await pumpScreen(tester, returningKid);
    await pumpUntilLetsFight(tester);
    audio.voicePipelineActiveNotifier.value = true; // "Let's fight!" playing
    await tester.pump(const Duration(milliseconds: 500)); // past launchDelay
    expect(find.text('BRUSHING'), findsNothing);
    expect(audio.callsFor('stopVoice'), isEmpty);
    audio.voicePipelineActiveNotifier.value = false; // the line ends
    await tester.pumpAndSettle();
    expect(find.text('BRUSHING'), findsOneWidget);
  });

  testWidgets('a "Let\'s fight!" that never ends still launches at the cap', (
    tester,
  ) async {
    PreBrushScreen.maxLaunchWait = const Duration(milliseconds: 500);
    addTearDown(
      () => PreBrushScreen.maxLaunchWait = const Duration(seconds: 3),
    );
    await pumpScreen(tester, returningKid);
    await pumpUntilLetsFight(tester);
    audio.voicePipelineActiveNotifier.value = true; // stuck
    await tester.pump(const Duration(milliseconds: 400)); // delay + part of cap
    expect(find.text('BRUSHING'), findsNothing);
    await tester.pump(const Duration(milliseconds: 300)); // cap reached
    await tester.pumpAndSettle();
    expect(find.text('BRUSHING'), findsOneWidget);
  });

  testWidgets('X after "Let\'s fight!" goes Home; brushing never starts', (
    tester,
  ) async {
    PreBrushScreen.launchDelay = const Duration(
      milliseconds: 400,
    ); // as shipped
    SharedPreferences.setMockInitialValues(returningKid);
    await openFromHome(tester);
    await pumpUntilLetsFight(tester);
    // Inside the launch delay, while this screen would still be mounted
    // during its own exit animation when the delay ends.
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.byKey(const ValueKey('prebrush_back')));
    await tester.pumpAndSettle();
    expect(find.text('BRUSHING'), findsNothing);
    expect(find.byKey(const ValueKey('open')), findsOneWidget);
    expect(
      tester.state<NavigatorState>(find.byType(Navigator)).canPop(),
      false,
    );
    expect(launchedWithIntro, isNull);
  });

  testWidgets('X while "Let\'s fight!" plays (after the delay) goes Home', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(returningKid);
    await openFromHome(tester);
    await pumpUntilLetsFight(tester);
    audio.voicePipelineActiveNotifier.value = true; // waiting for the line
    await tester.pump(const Duration(milliseconds: 200)); // past launchDelay
    await tester.tap(find.byKey(const ValueKey('prebrush_back')));
    await tester.pumpAndSettle();
    expect(find.text('BRUSHING'), findsNothing);
    expect(find.byKey(const ValueKey('open')), findsOneWidget);
    expect(launchedWithIntro, isNull);
  });

  testWidgets('after "Let\'s fight!" the carousel no longer changes anything', (
    tester,
  ) async {
    final prefs = Map<String, Object>.from(returningKid)
      ..['world_progress_candy_crater'] = 5; // slime_swamp unlocked too
    await pumpScreen(tester, prefs);
    await pumpUntilLetsFight(tester);
    audio.voicePipelineActiveNotifier.value = true; // hold the launch
    final heard = voices().length;
    await tester.tap(
      find.byKey(const ValueKey('carousel_next')),
      warnIfMissed: false, // ignored on purpose
    );
    await tester.pump(const Duration(seconds: 1));
    audio.voicePipelineActiveNotifier.value = false;
    await tester.pumpAndSettle();
    final saved = await SharedPreferences.getInstance();
    expect(voices().sublist(heard), isEmpty);
    expect(saved.getString('current_world'), 'candy_crater');
    expect(find.text('BRUSHING'), findsOneWidget);
  });

  testWidgets('a malformed history record still goes straight to brushing', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'total_brushes': 3,
      // No "time": BrushRecord.fromJson throws a TypeError, not an Exception.
      'brush_history': ['{"date":"2026-10-04"}'],
    });
    final printed = await collectDebugPrint(() async {
      await tester.pumpWidget(const MaterialApp(home: PreBrushScreen()));
      await tester.pumpAndSettle();
    });
    expect(find.text('BRUSHING'), findsOneWidget);
    expect(launchedWithIntro, isTrue);
    expect(printed.single, startsWith('PreBrush load failed'));
  });

  testWidgets('after a switch the idle wait lets the picker line finish', (
    tester,
  ) async {
    final prefs = Map<String, Object>.from(returningKid)
      ..['unlocked_heroes'] = ['blaze', 'frost'];
    await pumpScreen(tester, prefs);
    await tester.tap(find.byKey(const ValueKey('carousel_next')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300)); // at rest
    await tester.pump(const Duration(milliseconds: 350)); // settled, spoken
    expect(voices().last, 'voice_picker_hero_frost.mp3');
    audio.voicePipelineActiveNotifier.value = true; // the picker line plays on
    await tester.pump(const Duration(milliseconds: 300)); // idle is over
    expect(find.byKey(const ValueKey('prebrush_step_hero')), findsOneWidget);
    audio.voicePipelineActiveNotifier.value = false; // the line ends
    await tester.pump();
    expect(find.byKey(const ValueKey('prebrush_step_weapon')), findsOneWidget);
  });

  testWidgets('after a switch a picker line that never ends is capped', (
    tester,
  ) async {
    final prefs = Map<String, Object>.from(returningKid)
      ..['unlocked_heroes'] = ['blaze', 'frost'];
    await pumpScreen(tester, prefs);
    await tester.tap(find.byKey(const ValueKey('carousel_next')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300)); // at rest
    await tester.pump(const Duration(milliseconds: 350)); // settled, spoken
    audio.voicePipelineActiveNotifier.value = true; // stuck
    await tester.pump(const Duration(milliseconds: 300)); // idle is over
    expect(find.byKey(const ValueKey('prebrush_step_hero')), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 300)); // maxStep after idle
    expect(find.byKey(const ValueKey('prebrush_step_weapon')), findsOneWidget);
  });

  testWidgets('a drag held past the idle time does not advance', (
    tester,
  ) async {
    final prefs = Map<String, Object>.from(returningKid)
      ..['unlocked_heroes'] = ['blaze', 'frost'];
    await pumpScreen(tester, prefs);
    final drag = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('carousel_hero'))),
    );
    for (var i = 0; i < 5; i++) {
      await drag.moveBy(const Offset(-20, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pump(const Duration(seconds: 1)); // finger still down
    expect(find.byKey(const ValueKey('prebrush_step_hero')), findsOneWidget);
    await drag.up();
    // It springs back over a few frames; the idle wait starts once it rests.
    final weaponStep = find.byKey(const ValueKey('prebrush_step_weapon'));
    var waited = Duration.zero;
    while (weaponStep.evaluate().isEmpty &&
        waited < const Duration(seconds: 2)) {
      await tester.pump(const Duration(milliseconds: 50));
      waited += const Duration(milliseconds: 50);
    }
    expect(weaponStep, findsOneWidget);
    expect(waited, greaterThanOrEqualTo(PreBrushScreen.idleAfterTouch));
  });

  testWidgets('on the world step the goal tap says "keep brushing"', (
    tester,
  ) async {
    await pumpScreen(tester, returningKid);
    await tester.pump(oneStep);
    await tester.pump(oneStep);
    expect(find.byKey(const ValueKey('prebrush_step_world')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('prebrush_goal')));
    await tester.pump();
    expect(voices().last, 'voice_need_more_brushes.mp3');
  });

  testWidgets(
    'an affordable goal shows a full meter and "brush to unlock it"',
    (tester) async {
      final prefs = Map<String, Object>.from(returningKid)..['star_wallet'] = 6;
      await pumpScreen(tester, prefs);
      expect(voices().first, 'voice_ready_to_unlock.mp3'); // Frost costs 5
      expect(find.byKey(const ValueKey('meter_filled')), findsNWidgets(5));
      expect(find.byKey(const ValueKey('meter_empty')), findsNothing);
      // Tapping it says the same thing, not "you need more stars".
      await tester.tap(find.byKey(const ValueKey('prebrush_goal')));
      await tester.pump();
      expect(voices().last, 'voice_ready_to_unlock.mp3');
    },
  );

  testWidgets(
    'goal art: black hero silhouette; weapon and planet dimmed, clipped',
    (tester) async {
      await pumpScreen(tester, returningKid);
      ItemSilhouette goalArt() =>
          tester.widget<ItemSilhouette>(find.byType(ItemSilhouette));
      Finder inGoalArt(Type type) => find.descendant(
        of: find.byType(ItemSilhouette),
        matching: find.byType(type),
      );
      expect(goalArt().opaqueArt, isFalse); // Frost
      await tester.pump(oneStep);
      expect(goalArt().opaqueArt, isTrue); // Flame Sword
      expect(inGoalArt(ClipRRect), findsOneWidget);
      await tester.pump(oneStep);
      expect(goalArt().opaqueArt, isTrue); // Slime Swamp, the next planet
      expect(inGoalArt(ClipOval), findsOneWidget);
    },
  );

  for (final phone in const [
    (size: Size(360, 640), top: 24.0, bottom: 48.0),
    (size: Size(430, 932), top: 59.0, bottom: 34.0),
  ]) {
    final name = '${phone.size.width.toInt()}x${phone.size.height.toInt()}';
    testWidgets('fits a $name phone on every step', (tester) async {
      await tester.binding.setSurfaceSize(phone.size);
      final ratio = tester.view.devicePixelRatio;
      final insets = FakeViewPadding(
        top: phone.top * ratio,
        bottom: phone.bottom * ratio,
      );
      tester.view
        ..padding = insets
        ..viewPadding = insets;
      addTearDown(() async {
        tester.view
          ..resetPadding()
          ..resetViewPadding();
        await tester.binding.setSurfaceSize(null);
      });
      // Widest meters: 10 star slots (Blaze's upgrade), a star bar (Ice
      // Hammer, 14) and 10 rockets (Dark Dimension); arrows on every step.
      final prefs = <String, Object>{
        'total_brushes': 70,
        'star_wallet': 0,
        'unlocked_heroes': ['blaze', 'frost', 'bolt'],
        'selected_hero': 'blaze',
        'unlocked_weapons': ['star_blaster', 'flame_sword'],
        'selected_weapon': 'flame_sword',
        'current_world': 'dark_dimension',
        'world_progress_candy_crater': 5,
        'world_progress_slime_swamp': 5,
        'world_progress_sugar_volcano': 6,
        'world_progress_shadow_nebula': 6,
        'world_progress_cavity_fortress': 7,
        'world_progress_frozen_tundra': 7,
        'world_progress_toxic_jungle': 7,
        'world_progress_crystal_cave': 8,
        'world_progress_storm_citadel': 8,
      };
      await pumpScreen(tester, prefs);
      expect(find.byKey(const ValueKey('prebrush_step_hero')), findsOneWidget);
      expect(find.byKey(const ValueKey('meter_empty')), findsNWidgets(10));
      expect(tester.takeException(), isNull);
      await tester.pump(oneStep);
      expect(
        find.byKey(const ValueKey('prebrush_step_weapon')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('meter_bar')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pump(oneStep);
      expect(find.byKey(const ValueKey('prebrush_step_world')), findsOneWidget);
      expect(find.byKey(const ValueKey('meter_empty')), findsNWidgets(10));
      expect(tester.takeException(), isNull);
    });
  }

  group('brushing hand-off', () {
    Future<void> pumpBrushing(
      WidgetTester tester, {
      required bool showWorldIntro,
    }) async {
      SharedPreferences.setMockInitialValues({
        'phase_duration': 20,
        'camera_enabled': false,
        'selected_hero': 'blaze',
        'selected_weapon': 'star_blaster',
        'current_world': 'candy_crater',
        'total_brushes': 4,
        'muted': false,
      });
      await tester.binding.setSurfaceSize(const Size(430, 932));
      // The game screen's own layout is not under test here.
      final onError = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.toString().contains('overflowed')) return;
        onError?.call(details);
      };
      addTearDown(() => FlutterError.onError = onError);
      await tester.pumpWidget(
        MaterialApp(home: BrushingScreen(showWorldIntro: showWorldIntro)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }

    Future<void> disposeBrushing(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2)); // initState's 1.5 s delay
      await tester.binding.setSurfaceSize(null);
    }

    testWidgets('after the pre-brush steps brushing starts at the countdown', (
      tester,
    ) async {
      await pumpBrushing(tester, showWorldIntro: false);
      expect(voices(), isNot(contains('voice_world_candy_crater.mp3')));
      expect(voices(), contains('voice_three.mp3'));
      expect(find.text('3'), findsWidgets);
      await disposeBrushing(tester);
    });

    testWidgets('by default brushing still opens with the world intro', (
      tester,
    ) async {
      await pumpBrushing(tester, showWorldIntro: true);
      expect(voices(), contains('voice_world_candy_crater.mp3'));
      expect(voices(), isNot(contains('voice_three.mp3')));
      await disposeBrushing(tester);
    });
  });
}

/// Records route replacements (brushing replaces the pre-brush screen).
class _ReplaceLog extends NavigatorObserver {
  final replaced = <Route<dynamic>?>[];

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    replaced.add(newRoute);
  }
}

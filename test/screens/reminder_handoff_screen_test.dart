// test/screens/reminder_handoff_screen_test.dart
import 'dart:async';

import 'package:brush_quest/screens/after_brush_home.dart';
import 'package:brush_quest/screens/reminder_handoff_screen.dart';
import 'package:brush_quest/screens/reminder_parent_screen.dart';
import 'package:brush_quest/services/audio_service.dart';
import 'package:brush_quest/services/reminder_plan.dart';
import 'package:brush_quest/services/reminder_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../audio/timed_fake_audio_service.dart';
import '../services/reminder_fakes.dart';

/// Screen A of the bedtime reminder (spec
/// docs/superpowers/specs/2026-10-15-bedtime-reminder-design.md §3.1): no
/// words, Buddy's line once, the lock into the GROWN-UP CHECK, and Home after
/// the arrow, the back gesture or 15 s without a touch.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeReminderPlatform platform;
  late RecordingAnalytics recorder;
  late TimedFakeAudioService audio;

  setUpAll(() {
    // tearDown's `testInstance = null` builds a real AudioService, whose
    // players talk to the audioplayers channels.
    for (final name in [
      'xyz.luan/audioplayers.global',
      'xyz.luan/audioplayers',
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannel(name), (call) async => 1);
    }
  });

  setUp(() {
    platform = FakeReminderPlatform();
    recorder = RecordingAnalytics();
    AfterBrushHome.debugBuilder = (_) => const Scaffold(body: Text('HOME'));
  });

  tearDown(() {
    AudioService.testInstance = null;
    ReminderService.testInstance = null;
    AfterBrushHome.debugBuilder = null;
  });

  Finder key(String name) => find.byKey(ValueKey(name));
  List<Object?> results() => [
    for (final e in recorder.named('reminder_offer_result')) e['result'],
  ];

  /// Screen A on screen. With [viaFade] it arrives as it does from the
  /// victory screen: pushed over another page, fading in. [withAudio] is the
  /// voice channel to use instead of the plain timed fake.
  Future<void> pumpScreen(
    WidgetTester tester, {
    ReminderOffer offer = ReminderOffer.first,
    Size size = const Size(430, 932),
    List<NavigatorObserver> observers = const [],
    bool viaFade = false,
    TimedFakeAudioService? withAudio,
  }) async {
    SharedPreferences.setMockInitialValues({
      'total_brushes': 1,
      'selected_hero': 'frost',
      'unlocked_heroes': ['blaze', 'frost'],
      'muted': false,
    });
    audio =
        withAudio ??
        TimedFakeAudioService(
          lengths: const {
            ReminderHandoffScreen.voiceLine: Duration(milliseconds: 3900),
          },
        );
    final start = tester.binding.clock.now();
    audio.clock = () => tester.binding.clock.now().difference(start);
    AudioService.testInstance = audio;
    await installReminderService(
      platform: platform,
      recorder: recorder,
      now: () => DateTime(2026, 10, 15, 20),
    );
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: observers,
        home: viaFade ? const SizedBox() : ReminderHandoffScreen(offer: offer),
      ),
    );
    await tester.pump();
    if (viaFade) {
      unawaited(
        tester
            .state<NavigatorState>(find.byType(Navigator))
            .pushAndRemoveUntil(
              AfterBrushHome.fadeTo((_) => ReminderHandoffScreen(offer: offer)),
              (route) => false,
            ),
      );
      await tester.pump();
    }
  }

  /// Lets Buddy's line end, then drops the screen. A Timer still pending at
  /// the end of a test fails it, so this also checks that dispose cancels
  /// the 15 s.
  Future<void> leave(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpWidget(const SizedBox());
  }

  Future<void> openLock(WidgetTester tester) async {
    await tester.tap(key('handoff_lock'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  /// Answers the open GROWN-UP CHECK and taps CONTINUE.
  Future<void> passGate(WidgetTester tester) async {
    final text = tester.widget<Text>(find.textContaining('×')).data!;
    final m = RegExp(r'(\d+) × (\d+)').firstMatch(text)!;
    final answer = int.parse(m.group(1)!) * int.parse(m.group(2)!);
    await tester.enterText(find.byType(TextField), '$answer');
    await tester.tap(find.text('CONTINUE'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
  }

  Future<void> fadeHome(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets("Buddy's line, once; one line of text, for grown-ups", (
    tester,
  ) async {
    await pumpScreen(tester);
    expect(audio.playedVoiceLines, [ReminderHandoffScreen.voiceLine]);
    // A parent who missed Buddy can read what it is (Jim, 2026-10-19). It is
    // the only text, it sits under the lock, and it is not a button.
    expect(find.byType(Text), findsOneWidget);
    final caption = find.text(ReminderHandoffScreen.grownUpCaption);
    expect(caption, findsOneWidget);
    expect(
      ReminderHandoffScreen.grownUpCaption,
      'Grown-ups: set a bedtime brushing reminder',
    );
    expect(
      tester.getRect(caption).top,
      greaterThan(tester.getRect(key('handoff_lock')).bottom),
    );
    expect(
      find.ancestor(of: caption, matching: find.byType(InkWell)),
      findsNothing,
    );
    expect(
      find.ancestor(of: caption, matching: find.byType(GestureDetector)),
      findsNothing,
    );
    expect(
      tester.widget<Text>(caption).style!.fontSize,
      greaterThanOrEqualTo(16),
    );
    // The picture says "reminder": the grown-up with a bell, not a phone.
    final picture = key('handoff_picture');
    expect(
      find.descendant(
        of: picture,
        matching: find.byIcon(Icons.notifications_active_rounded),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: picture,
        matching: find.byIcon(Icons.smartphone_rounded),
      ),
      findsNothing,
    );
    expect(key('handoff_picture'), findsOneWidget);
    expect(key('handoff_lock'), findsOneWidget);
    expect(key('handoff_skip'), findsOneWidget);
    await leave(tester);
  });

  testWidgets('arriving with the fade: Buddy waits for it to end', (
    tester,
  ) async {
    // The page before this one stays under it until the fade ends, and its
    // dispose then stops the voice channel: a line started on entry is cut.
    await pumpScreen(tester, viaFade: true);
    await tester.pump(const Duration(milliseconds: 100));
    expect(audio.playedVoiceLines, isEmpty, reason: 'still fading in');
    await tester.pump(const Duration(milliseconds: 400));
    expect(audio.playedVoiceLines, [ReminderHandoffScreen.voiceLine]);
    expect(audio.voiceNamed(ReminderHandoffScreen.voiceLine)!.cut, isFalse);
    await leave(tester);
  });

  testWidgets('the arrow while it fades in: Home, and Buddy never starts', (
    tester,
  ) async {
    await pumpScreen(tester, viaFade: true);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(key('handoff_skip'));
    // In frames, not one jump: this page finishes fading in while Home is
    // still fading in over it, and is still mounted when its fade ends.
    for (var i = 0; i < 14; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('HOME'), findsOneWidget);
    expect(audio.playedVoiceLines, isEmpty);
    expect(results(), ['skipped']);
  });

  testWidgets('the lock while it fades in: Buddy never starts over the '
      'GROWN-UP CHECK', (tester) async {
    await pumpScreen(tester, viaFade: true);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(key('handoff_lock'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('GROWN-UP CHECK'), findsOneWidget);
    expect(audio.playedVoiceLines, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('notes the offer: its number, today, the shown event', (
    tester,
  ) async {
    await pumpScreen(tester, offer: ReminderOffer.second);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt(ReminderService.keyOfferCount), 2);
    expect(prefs.getString(ReminderService.keyOfferLastDate), '2026-10-15');
    expect(recorder.named('reminder_offer_shown'), [
      {'name': 'reminder_offer_shown', 'offer': '2'},
    ]);
    await leave(tester);
  });

  testWidgets('the arrow: Buddy stops, Home as usual, offer 2 stays possible', (
    tester,
  ) async {
    await pumpScreen(tester);
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(key('handoff_skip'));
    await fadeHome(tester);
    expect(find.text('HOME'), findsOneWidget);
    expect(audio.voiceNamed(ReminderHandoffScreen.voiceLine)!.cut, isTrue);
    expect(results(), ['skipped']);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey(ReminderService.keyDecided), isFalse);
  });

  testWidgets('15 s without a tap: Home', (tester) async {
    await pumpScreen(tester);
    await tester.pump(const Duration(milliseconds: 14900));
    expect(find.text('HOME'), findsNothing);
    await tester.pump(const Duration(milliseconds: 200));
    await fadeHome(tester);
    expect(find.text('HOME'), findsOneWidget);
    expect(results(), ['timeout']);
  });

  testWidgets('a touch anywhere starts the 15 s again', (tester) async {
    await pumpScreen(tester);
    await tester.pump(const Duration(seconds: 10));
    await tester.tapAt(const Offset(20, 120)); // the background, no button
    await tester.pump(const Duration(milliseconds: 14800));
    expect(find.text('HOME'), findsNothing);
    await tester.pump(const Duration(milliseconds: 300));
    await fadeHome(tester);
    expect(find.text('HOME'), findsOneWidget);
  });

  testWidgets('the back button goes Home, never out of the app', (
    tester,
  ) async {
    await pumpScreen(tester);
    unawaited(tester.state<NavigatorState>(find.byType(Navigator)).maybePop());
    await fadeHome(tester);
    expect(find.text('HOME'), findsOneWidget);
    expect(results(), ['skipped']);
  });

  // AudioService.stopVoice catches only Exception. An Error from it, or a stop
  // that never reports back, must not keep a child on this route: the arrow,
  // the back gesture and the 15 s are his only ways out. Nothing waits for it.
  for (final stop in <_StopCase>[
    (name: 'never reports back', audio: _StuckStopAudio.new, fails: false),
    (name: 'fails with an Error', audio: _FailingStopAudio.new, fails: true),
  ]) {
    for (final exit in <_ExitCase>[
      (
        name: 'the arrow',
        result: 'skipped',
        go: (tester) => tester.tap(key('handoff_skip')),
      ),
      (
        name: 'the back button',
        result: 'skipped',
        go: (tester) async => unawaited(
          tester.state<NavigatorState>(find.byType(Navigator)).maybePop(),
        ),
      ),
      (
        name: 'the 15 s',
        result: 'timeout',
        go: (tester) => tester.pump(
          ReminderHandoffScreen.idleTimeout + const Duration(milliseconds: 100),
        ),
      ),
    ]) {
      testWidgets('${exit.name}: Home even if the voice stop ${stop.name}', (
        tester,
      ) async {
        // An Error in a call nobody awaits is an uncaught error, as for any
        // unawaited call (the app reports it); flutter_test would fail the
        // test for it, so the zone collects it here. The expectations stay
        // outside the zone: a failure thrown inside it hangs the test.
        final uncaught = <Object>[];
        await runZonedGuarded(() async {
          await pumpScreen(tester, withAudio: stop.audio());
          await tester.pump(const Duration(seconds: 1));
          await exit.go(tester);
          await fadeHome(tester);
        }, (error, _) => uncaught.add(error));
        expect(find.text('HOME'), findsOneWidget);
        expect(results(), [exit.result]);
        expect(uncaught, stop.fails ? [isStateError] : isEmpty);
      });
    }
  }

  testWidgets('the lock: Buddy stops, the GROWN-UP CHECK, then the parent '
      'screen; no timeout behind it', (tester) async {
    await pumpScreen(tester);
    await tester.pump(const Duration(seconds: 1));
    await openLock(tester);
    expect(audio.voiceNamed(ReminderHandoffScreen.voiceLine)!.cut, isTrue);
    expect(find.text('GROWN-UP CHECK'), findsOneWidget);
    expect(results(), ['gate_opened']);
    await passGate(tester);
    expect(find.byType(ReminderParentScreen), findsOneWidget);
    expect(find.text('Want a bedtime brushing reminder?'), findsOneWidget);
    await tester.pump(const Duration(seconds: 20));
    expect(find.text('HOME'), findsNothing);
    expect(results(), ['gate_opened']);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('CANCEL on the check: back here, and the 15 s start again', (
    tester,
  ) async {
    await pumpScreen(tester);
    await tester.pump(const Duration(seconds: 12));
    await openLock(tester);
    // A grown-up working out the sum: nothing times out behind the check.
    await tester.pump(const Duration(seconds: 10));
    expect(find.text('GROWN-UP CHECK'), findsOneWidget);
    await tester.tap(find.text('CANCEL'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('GROWN-UP CHECK'), findsNothing);
    expect(key('handoff_lock'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 14500));
    expect(find.text('HOME'), findsNothing);
    await tester.pump(const Duration(milliseconds: 600));
    await fadeHome(tester);
    expect(find.text('HOME'), findsOneWidget);
    expect(results(), ['gate_opened', 'timeout']);
  });

  testWidgets('backing out of the parent screen comes back here', (
    tester,
  ) async {
    await pumpScreen(tester);
    await openLock(tester);
    await passGate(tester);
    expect(find.byType(ReminderParentScreen), findsOneWidget);
    unawaited(tester.state<NavigatorState>(find.byType(Navigator)).maybePop());
    await tester.pump();
    // The page's exit transition outlasts 400 ms on the test's Android theme.
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(ReminderParentScreen), findsNothing);
    expect(key('handoff_lock'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 14500));
    await fadeHome(tester);
    expect(find.text('HOME'), findsOneWidget);
  });

  testWidgets('backing out while "Reminder set" shows: a reminder is on, so '
      'Home, not this screen again', (tester) async {
    await pumpScreen(tester);
    await openLock(tester);
    await passGate(tester);
    await tester.tap(key('parent_turn_on'));
    await tester.pump();
    await tester.pump();
    expect(key('parent_confirmation'), findsOneWidget);
    // One second into the 2.5 s hold, the parent uses the system back.
    await tester.pump(const Duration(seconds: 1));
    unawaited(tester.state<NavigatorState>(find.byType(Navigator)).maybePop());
    await tester.pump();
    // The page's exit transition outlasts 400 ms on the test's Android theme.
    await tester.pump(const Duration(seconds: 1));
    await fadeHome(tester);
    expect(find.text('HOME'), findsOneWidget);
    expect(find.byType(ReminderParentScreen), findsNothing);
    expect(key('handoff_lock'), findsNothing);
    // TURN ON said "enabled"; no 15 s count starts again behind Home.
    await tester.pump(const Duration(seconds: 20));
    expect(results(), ['gate_opened', 'enabled']);
  });

  testWidgets('backing out in the last moments of "Reminder set": Home once, '
      'not again when its hold runs out', (tester) async {
    final routes = _PushedRoutes();
    await pumpScreen(tester, observers: [routes]);
    await openLock(tester);
    await passGate(tester);
    await tester.tap(key('parent_turn_on'));
    await tester.pump();
    await tester.pump();
    expect(key('parent_confirmation'), findsOneWidget);
    // 300 ms before the hold ends, the parent uses the system back. The
    // popped page stays mounted through its exit transition, so its own hold
    // timer still fires then, and must not send Home a second time.
    await tester.pump(
      ReminderParentScreen.confirmationHold - const Duration(milliseconds: 300),
    );
    unawaited(tester.state<NavigatorState>(find.byType(Navigator)).maybePop());
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await fadeHome(tester);
    expect(find.text('HOME'), findsOneWidget);
    expect(routes.pushed.whereType<PageRouteBuilder<void>>(), hasLength(1));
    await tester.pump(const Duration(seconds: 20));
    expect(results(), ['gate_opened', 'enabled']);
  });

  testWidgets('TURN ON and the 2.5 s: the parent screen takes Home, and this '
      'screen does not take it again', (tester) async {
    final routes = _PushedRoutes();
    await pumpScreen(tester, observers: [routes]);
    await openLock(tester);
    await passGate(tester);
    await tester.tap(key('parent_turn_on'));
    await tester.pump();
    await tester.pump();
    await tester.pump(ReminderParentScreen.confirmationHold);
    await fadeHome(tester);
    expect(find.text('HOME'), findsOneWidget);
    // Home is the app's only fading page: one push is one trip Home.
    expect(routes.pushed.whereType<PageRouteBuilder<void>>(), hasLength(1));
    await tester.pump(const Duration(seconds: 20));
    expect(results(), ['gate_opened', 'enabled']);
  });

  for (final size in const [Size(360, 640), Size(320, 568), Size(412, 915)]) {
    testWidgets('${size.width.toInt()}x${size.height.toInt()}: it all fits, '
        'the arrow big enough for small fingers', (tester) async {
      await pumpScreen(tester, size: size);
      expect(tester.takeException(), isNull);
      final lock = tester.getRect(key('handoff_lock'));
      final skip = tester.getRect(key('handoff_skip'));
      expect(lock.bottom, lessThanOrEqualTo(size.height));
      expect(skip.bottom, lessThanOrEqualTo(size.height));
      expect(skip.width, greaterThanOrEqualTo(48));
      expect(lock.overlaps(skip), isFalse);
      final caption = tester.getRect(
        find.text(ReminderHandoffScreen.grownUpCaption),
      );
      expect(caption.overlaps(skip), isFalse);
      expect(caption.overlaps(lock), isFalse);
      expect(caption.left, greaterThanOrEqualTo(0));
      expect(caption.right, lessThanOrEqualTo(size.width));
      await leave(tester);
    });
  }

  testWidgets("the lock's glow is drawn outside its Ink, not cut off flat", (
    tester,
  ) async {
    await pumpScreen(tester);
    // A Material clips whatever its Ink paints to the Ink's own box, so a
    // shadow painted by the Ink is cut off flat on four sides.
    final ink = tester.widget<Ink>(
      find.descendant(of: key('handoff_lock'), matching: find.byType(Ink)),
    );
    expect((ink.decoration! as BoxDecoration).boxShadow, isNull);
    final glows = tester
        .widgetList<DecoratedBox>(
          find.ancestor(
            of: key('handoff_lock'),
            matching: find.byType(DecoratedBox),
          ),
        )
        .where((box) {
          final decoration = box.decoration;
          return decoration is BoxDecoration &&
              (decoration.boxShadow?.isNotEmpty ?? false);
        });
    expect(glows, hasLength(1));
    await leave(tester);
  });

  testWidgets('leaving the screen leaves no timer behind', (tester) async {
    await pumpScreen(tester);
    await leave(tester);
  });
}

/// A way the voice stop can go wrong, for the exits that must not wait on it.
typedef _StopCase = ({
  String name,
  TimedFakeAudioService Function() audio,
  bool fails,
});

/// A way off this screen, and the offer result it records.
typedef _ExitCase = ({
  String name,
  String result,
  Future<void> Function(WidgetTester) go,
});

/// The routes pushed on the navigator, in order.
class _PushedRoutes extends NavigatorObserver {
  final List<Route<dynamic>> pushed = [];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      pushed.add(route);
}

/// A voice channel whose stop is sent but never reports back, as a stuck
/// platform call would.
class _StuckStopAudio extends TimedFakeAudioService {
  _StuckStopAudio()
    : super(
        lengths: const {
          ReminderHandoffScreen.voiceLine: Duration(milliseconds: 3900),
        },
      );

  @override
  Future<void> stopVoice() async {
    await super.stopVoice();
    await Completer<void>().future;
  }
}

/// A voice channel whose stop fails with an Error, which the real
/// AudioService.stopVoice (it catches only Exception) would let through.
class _FailingStopAudio extends TimedFakeAudioService {
  _FailingStopAudio()
    : super(
        lengths: const {
          ReminderHandoffScreen.voiceLine: Duration(milliseconds: 3900),
        },
      );

  @override
  Future<void> stopVoice() async {
    await super.stopVoice();
    throw StateError('the voice player is gone');
  }
}

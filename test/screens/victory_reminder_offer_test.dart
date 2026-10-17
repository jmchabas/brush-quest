// test/screens/victory_reminder_offer_test.dart
import 'package:brush_quest/screens/after_brush_home.dart';
import 'package:brush_quest/screens/reminder_handoff_screen.dart';
import 'package:brush_quest/screens/victory_screen.dart';
import 'package:brush_quest/services/audio_service.dart';
import 'package:brush_quest/services/reminder_plan.dart';
import 'package:brush_quest/services/reminder_service.dart';
import 'package:brush_quest/services/streak_service.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../audio/fake_audio_service.dart';
import '../audio/timed_fake_audio_service.dart';
import '../services/reminder_fakes.dart';

/// DONE on the victory screen: when an offer is due, the bedtime-reminder
/// hand-off comes before Home (spec 2026-10-15-bedtime-reminder-design §2),
/// and every recorded brush plans the reminders again (§5).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeReminderPlatform platform;
  late RecordingAnalytics recorder;

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
    AudioService.testInstance = FakeAudioService();
    platform = FakeReminderPlatform();
    recorder = RecordingAnalytics();
    AfterBrushHome.debugBuilder = (_) => const Scaffold(body: Text('HOME'));
  });

  tearDown(() {
    AudioService.testInstance = null;
    ReminderService.testInstance = null;
    AfterBrushHome.debugBuilder = null;
    StreakService.isPurchasing = false;
  });

  Map<String, Object> kid({
    required int brushesBefore,
    Map<String, Object> extra = const {},
  }) => {
    'total_brushes': brushesBefore,
    'selected_hero': 'blaze',
    'selected_weapon': 'star_blaster',
    'unlocked_heroes': ['blaze'],
    'unlocked_weapons': ['star_blaster'],
    'current_world': 'candy_crater',
    'collected_cards': <String>[],
    'trophy_captured': <String>[],
    'muted': false,
    ...extra,
  };

  Future<void> pumpVictory(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(
        home: VictoryScreen(totalHits: 10, monstersDefeated: 4),
      ),
    );
    await tester.pump();
  }

  /// Waits for the 60 s safety DONE (no chest tap needed), taps it, and runs
  /// until the victory screen has gone.
  Future<void> finishWithDone(WidgetTester tester) async {
    await pumpVictory(tester);
    await tester.pump(const Duration(seconds: 61));
    expect(find.text('DONE'), findsOneWidget);
    await tester.tap(find.text('DONE'), warnIfMissed: false);
    for (var i = 0; i < 50; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.byType(VictoryScreen).evaluate().isEmpty) break;
    }
    expect(find.byType(VictoryScreen), findsNothing);
  }

  /// Lets the popups' and the hand-off's timers run out, then drops the tree.
  Future<void> drain(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  }

  ReminderOffer? offerShown(WidgetTester tester) {
    final handoff = find.byType(ReminderHandoffScreen);
    if (handoff.evaluate().isEmpty) return null;
    return tester.widget<ReminderHandoffScreen>(handoff).offer;
  }

  testWidgets('the first brush ever: DONE opens the hand-off, offer 1', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(kid(brushesBefore: 0));
    await installReminderService(platform: platform, recorder: recorder);
    await finishWithDone(tester);
    expect(offerShown(tester), ReminderOffer.first);
    expect(find.text('HOME'), findsNothing);
    await drain(tester);
  });

  testWidgets('offer 2: from the 3rd brush, on a later day than offer 1', (
    tester,
  ) async {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    SharedPreferences.setMockInitialValues(
      kid(
        brushesBefore: 2,
        extra: {
          ReminderService.keyOfferCount: 1,
          ReminderService.keyOfferLastDate: StreakService.dateKey(yesterday),
        },
      ),
    );
    await installReminderService(platform: platform, recorder: recorder);
    await finishWithDone(tester);
    expect(offerShown(tester), ReminderOffer.second);
    await drain(tester);
  });

  testWidgets('once the parent decided, DONE goes straight Home', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(
      kid(brushesBefore: 4, extra: {ReminderService.keyDecided: true}),
    );
    await installReminderService(platform: platform, recorder: recorder);
    await finishWithDone(tester);
    expect(find.text('HOME'), findsOneWidget);
    expect(find.byType(ReminderHandoffScreen), findsNothing);
    await drain(tester);
  });

  testWidgets('with a reminder on, DONE goes straight Home', (tester) async {
    SharedPreferences.setMockInitialValues(
      kid(
        brushesBefore: 4,
        extra: {
          ReminderService.keyEveningEnabled: true,
          ReminderService.keyEveningTime: 19 * 60 + 30,
        },
      ),
    );
    await installReminderService(platform: platform, recorder: recorder);
    await finishWithDone(tester);
    expect(find.text('HOME'), findsOneWidget);
    await drain(tester);
  });

  testWidgets('every recorded brush plans the reminders again', (tester) async {
    SharedPreferences.setMockInitialValues(
      kid(brushesBefore: 4, extra: {ReminderService.keyDecided: true}),
    );
    await installReminderService(platform: platform, recorder: recorder);
    final plansBefore = platform.calls.where((c) => c == 'pendingIds').length;
    await pumpVictory(tester);
    await tester.pump(const Duration(seconds: 1));
    expect(
      platform.calls.where((c) => c == 'pendingIds').length,
      greaterThan(plansBefore),
    );
    await tester.pump(const Duration(seconds: 61));
    await drain(tester);
  });

  /// Pumps [total] in 50 ms frames, so timers and animations run as on a
  /// device (pre_brush_screen_test.dart does the same).
  Future<void> pumpFor(WidgetTester tester, Duration total) async {
    const frame = Duration(milliseconds: 50);
    var left = total;
    while (left > Duration.zero) {
      final next = left < frame ? left : frame;
      await tester.pump(next);
      left -= next;
    }
  }

  testWidgets('Buddy\'s hand-off line plays to its end: the victory screen '
      'leaving does not cut it', (tester) async {
    // A voice channel that takes time, like the real one, on the test's fake
    // clock. The victory screen's dispose() calls stopVoice() in the very
    // frame the hand-off's initState starts the line.
    final timed = TimedFakeAudioService(
      lengths: {
        ReminderHandoffScreen.voiceLine: const Duration(milliseconds: 3900),
      },
    );
    final start = tester.binding.clock.now();
    timed.clock = () => tester.binding.clock.now().difference(start);
    AudioService.testInstance = timed;
    SharedPreferences.setMockInitialValues(kid(brushesBefore: 0));
    await installReminderService(platform: platform, recorder: recorder);
    await finishWithDone(tester);
    expect(offerShown(tester), ReminderOffer.first);
    // Well past the line's 3.9 s, well short of the hand-off's 15 s idle
    // timeout (which would stop it by going Home).
    await pumpFor(tester, const Duration(seconds: 6));
    expect(find.byType(ReminderHandoffScreen), findsOneWidget);
    final line = timed.voiceNamed(ReminderHandoffScreen.voiceLine);
    expect(line, isNotNull, reason: '${timed.voices}');
    expect(line!.startedAt, isNotNull, reason: '${timed.voices}');
    expect(line.cut, isFalse, reason: 'cut: ${timed.voices}');
    expect(line.dropped, isFalse, reason: 'dropped: ${timed.voices}');
    expect(
      line.endedAt! - line.startedAt!,
      const Duration(milliseconds: 3900),
      reason: 'it played its whole length: ${timed.voices}',
    );
    await drain(tester);
  });
}

// test/screens/settings_reminders_test.dart
import 'dart:io';

import 'package:brush_quest/screens/settings_screen.dart';
import 'package:brush_quest/services/audio_service.dart';
import 'package:brush_quest/services/reminder_service.dart';
import 'package:brush_quest/widgets/reminder_settings_card.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../audio/fake_audio_service.dart';
import '../services/reminder_fakes.dart';

/// Parents > Settings > Reminders (spec
/// docs/superpowers/specs/2026-10-15-bedtime-reminder-design.md §3.3, §4):
/// where the card sits, and what the Pause and Start fresh do to reminders.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers.global'),
      (call) async => 1,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers'),
      (call) async => 1,
    );
  });

  setUp(() {
    AudioService.testInstance = FakeAudioService();
  });

  tearDown(() {
    AudioService.testInstance = null;
    ReminderService.testInstance = null;
  });

  testWidgets('the REMINDERS card sits between BRUSHING and OTHER', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await installReminderService(
      platform: FakeReminderPlatform(),
      recorder: RecordingAnalytics(),
    );
    await tester.binding.setSurfaceSize(const Size(430, 3200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    // The Parent Check.
    final challenge = tester.widget<Text>(find.textContaining('×')).data!;
    final m = RegExp(r'(\d+)\s*×\s*(\d+)').firstMatch(challenge)!;
    await tester.enterText(
      find.byType(TextField),
      '${int.parse(m.group(1)!) * int.parse(m.group(2)!)}',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Settings'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    // The card reads its settings once its tab is built.
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('REMINDERS'), findsOneWidget);
    expect(find.byType(ReminderSettingsCard), findsOneWidget);
    expect(find.text('Bedtime reminder'), findsOneWidget);
    double top(String label) => tester.getTopLeft(find.text(label)).dy;
    expect(top('REMINDERS'), greaterThan(top('BRUSHING')));
    expect(top('REMINDERS'), lessThan(top('OTHER')));
  });

  test('the Pause plans the reminders again; Start fresh clears them before '
      'the cloud copy goes', () {
    final settings = File(
      'lib/screens/settings_screen.dart',
    ).readAsStringSync();
    final pause = settings.substring(
      settings.indexOf('Widget _buildPauseStreakCard()'),
      settings.indexOf('Widget _buildSettingsTab('),
    );
    expect(
      RegExp(
        r'setStreakPause\(picked\);\s+unawaited\(ReminderService\(\)\.reschedule\(\)\);',
      ).hasMatch(pause),
      isTrue,
    );
    expect(
      RegExp(
        r'clearStreakPause\(\);\s+unawaited\(ReminderService\(\)\.reschedule\(\)\);',
      ).hasMatch(pause),
      isTrue,
    );
    final reset = settings.substring(
      settings.indexOf('Future<void> _resetProgress()'),
      settings.indexOf('Future<void> _openPrivacyPolicy()'),
    );
    final clear = reset.indexOf('ReminderService().resetAll()');
    expect(clear, isNonNegative);
    expect(clear, lessThan(reset.indexOf('deleteCloudData()')));
  });
}

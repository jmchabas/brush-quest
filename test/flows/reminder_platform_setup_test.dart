// test/flows/reminder_platform_setup_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The bedtime reminder's platform setup (spec
/// docs/superpowers/specs/2026-10-15-bedtime-reminder-design.md §5). None of
/// it runs in a widget test, so the files themselves are pinned.
void main() {
  String read(String path) => File(path).readAsStringSync();

  test('the plugin, pinned; no push messaging', () {
    final pubspec = read('pubspec.yaml');
    expect(pubspec, contains('flutter_local_notifications: 22.3.2'));
    expect(pubspec, contains('timezone: 0.11.2'));
    expect(pubspec, isNot(contains('firebase_messaging')));
    expect(pubspec, isNot(contains('flutter_timezone')));
  });

  test('Android: re-armed after a reboot, receivers not exported, no exact '
      'alarms', () {
    final manifest = read('android/app/src/main/AndroidManifest.xml');
    expect(manifest, contains('android.permission.RECEIVE_BOOT_COMPLETED'));
    for (final receiver in [
      'ScheduledNotificationReceiver',
      'ScheduledNotificationBootReceiver',
    ]) {
      expect(
        RegExp(
          r'android:exported="false"\s+android:name="com\.dexterous\.'
          r'flutterlocalnotifications\.'
          '$receiver"',
        ).hasMatch(manifest),
        isTrue,
        reason: receiver,
      );
    }
    // Play allows exact alarms only for alarm and calendar apps.
    for (final banned in [
      'SCHEDULE_EXACT_ALARM',
      'USE_EXACT_ALARM',
      'USE_FULL_SCREEN_INTENT',
    ]) {
      expect(manifest, isNot(contains(banned)), reason: banned);
    }
  });

  test('Android: desugaring, the two icons and their keep rule', () {
    final gradle = read('android/app/build.gradle.kts');
    expect(gradle, contains('isCoreLibraryDesugaringEnabled = true'));
    expect(
      gradle,
      contains(
        'coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")',
      ),
    );
    const res = 'android/app/src/main/res';
    final small = read('$res/drawable/ic_stat_brush_reminder.xml');
    expect(small, contains('android:fillType="evenOdd"'));
    expect(small, contains('android:fillColor="#FFFFFFFF"'));
    expect(
      File('$res/drawable-nodpi/ic_reminder_large.png').existsSync(),
      isTrue,
    );
    final keep = read('$res/raw/keep.xml');
    expect(keep, contains('@drawable/ic_stat_brush_reminder'));
    expect(keep, contains('@drawable/ic_reminder_large'));
  });

  test('the plugin asks nothing at start-up, schedules one-shots (exact only '
      'where Android needs no permission for it), never badges', () {
    final platform = read('lib/services/reminder_platform.dart');
    for (final flag in [
      'requestAlertPermission: false',
      'requestBadgePermission: false',
      'requestSoundPermission: false',
      'badge: false',
      'provisional: false',
      'presentBadge: false',
      'channelShowBadge: false',
      'presentBanner: false',
      'presentList: false',
      'presentAlert: false',
      'presentSound: true',
    ]) {
      expect(platform, contains(flag), reason: flag);
    }
    // Inexact is the mode wherever exact alarms would need a permission
    // (Android 12 and up). Exact appears only behind the plugin's own check,
    // which is true below Android 12, where exact alarms need no permission;
    // reminder_platform_test.dart pins what each answer does.
    expect(platform, contains('AndroidScheduleMode.inexactAllowWhileIdle'));
    expect(platform, contains('canScheduleExactNotifications()'));
    expect(platform, contains('AndroidScheduleMode.exactAllowWhileIdle'));
    // No other exact mode: the plain one is not allowed while idle, and the
    // alarm clock one needs the exact-alarm permission.
    expect(
      RegExp(r'AndroidScheduleMode\.exact\b').hasMatch(platform),
      isFalse,
      reason: 'AndroidScheduleMode.exact',
    );
    expect(platform, isNot(contains('alarmClock')));
    expect(platform, isNot(contains('matchDateTimeComponents')));
    expect(platform, contains("channelId = 'brush_reminders'"));
    expect(platform, contains("channelName = 'Brushing reminders'"));
  });

  test('only the platform file talks to the plugin', () {
    final users = [
      for (final f in Directory('lib').listSync(recursive: true))
        if (f is File &&
            f.path.endsWith('.dart') &&
            f.readAsStringSync().contains(
              'package:flutter_local_notifications/',
            ))
          f.path,
    ];
    expect(users, ['lib/services/reminder_platform.dart']);
  });

  test('iOS: the notification-centre delegate, apart from the audio '
      'observers, and no permission asked there', () {
    final delegate = read('ios/Runner/AppDelegate.swift');
    expect(
      delegate,
      contains(
        'UNUserNotificationCenter.current().delegate = '
        'self as UNUserNotificationCenterDelegate',
      ),
    );
    expect(delegate, contains('setupAudioSessionObservers()'));
    expect(delegate, isNot(contains('requestAuthorization')));
  });

  test('the live privacy policy says the reminders stay on the device', () {
    // docs/ is what GitHub Pages serves at brushquest.app.
    final policy = read('docs/privacy-policy.html');
    expect(
      policy,
      contains('<h3>Bedtime reminders (optional, off by default)</h3>'),
    );
    expect(
      policy,
      contains(
        'Optional bedtime reminders are scheduled and shown entirely on your '
        'device; no information is sent to us.',
      ),
    );
  });
}

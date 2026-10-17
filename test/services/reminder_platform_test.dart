// test/services/reminder_platform_test.dart
import 'package:brush_quest/services/reminder_plan.dart';
import 'package:brush_quest/services/reminder_platform.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

/// [PluginReminderPlatform] on the plugin's own method channel, with the phone
/// mocked: what it asks the phone, and what it makes of the answers (spec
/// docs/superpowers/specs/2026-10-15-bedtime-reminder-design.md §1 no badges,
/// §3.3 the Parent Zone's "off in your phone settings" line, §4 the Android
/// channel as an off switch). The plugin's Dart classes run for real.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const pluginChannel = MethodChannel(
    'dexterous.com/flutter/local_notifications',
  );

  // The phone's answers, and every call it received.
  var appAllowed = true;
  var iosAllowed = true;
  Object? listedChannels = <Map<String, Object?>>[];
  // What canScheduleExactNotifications answers: true below Android 12, where
  // exact alarms need no permission; false from Android 12 without the
  // exact-alarm permission, which the app does not declare.
  Object? exactAlarmsAllowed = false;
  var exactAlarmCheckFails = false;
  final calls = <MethodCall>[];

  /// A notification channel as the Android side reports it.
  Map<String, Object?> channelReport(String id, Importance importance) => {
    'id': id,
    'name': id,
    'description': null,
    'groupId': null,
    'showBadge': false,
    'importance': importance.value,
    'bypassDnd': false,
    'playSound': true,
    'enableVibration': true,
    'vibrationPattern': null,
    'enableLights': false,
    'ledColor': 0,
    'audioAttributesUsage': 5,
  };

  Map<String, Object?> reminderChannel(Importance importance) =>
      channelReport(PluginReminderPlatform.channelId, importance);

  setUp(() {
    appAllowed = true;
    iosAllowed = true;
    listedChannels = <Map<String, Object?>>[];
    exactAlarmsAllowed = false;
    exactAlarmCheckFails = false;
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pluginChannel, (call) async {
          calls.add(call);
          return switch (call.method) {
            'areNotificationsEnabled' => appAllowed,
            'getNotificationChannels' => listedChannels,
            'checkPermissions' => {'isEnabled': iosAllowed},
            'canScheduleExactNotifications' =>
              exactAlarmCheckFails
                  ? throw PlatformException(code: 'unavailable')
                  : exactAlarmsAllowed,
            _ => null,
          };
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pluginChannel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  void onAndroid() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    AndroidFlutterLocalNotificationsPlugin.registerWith();
  }

  PlannedReminder tonight() => PlannedReminder(
    id: 101,
    slot: ReminderSlot.evening,
    at: DateTime(2099, 1, 2, 19, 30),
    title: 'Brushing time!',
    body: "Tonight's cavity monsters are waiting.",
  );

  /// The zonedSchedule calls the phone received.
  List<MethodCall> scheduleCalls() => [
    for (final call in calls)
      if (call.method == 'zonedSchedule') call,
  ];

  /// The schedule mode the Android side was asked to use.
  String? modeOf(MethodCall call) =>
      ((call.arguments as Map)['platformSpecifics'] as Map)['scheduleMode']
          as String?;

  group('notificationsAllowed on Android', () {
    setUp(onAndroid);

    Future<bool> allowed() => PluginReminderPlatform().notificationsAllowed();

    test('is true while the reminder channel does not exist yet', () async {
      // Android creates the channel when its first reminder shows.
      listedChannels = <Map<String, Object?>>[];
      expect(await allowed(), isTrue);
    });

    test('is true while the reminder channel is on', () async {
      listedChannels = [reminderChannel(Importance.defaultImportance)];
      expect(await allowed(), isTrue);
    });

    test('is false when the reminder channel is switched off in the '
        "phone's settings", () async {
      listedChannels = [
        channelReport('other', Importance.defaultImportance),
        reminderChannel(Importance.none),
      ];
      expect(await allowed(), isFalse);
    });

    test('is true when only some other channel is switched off', () async {
      listedChannels = [
        channelReport('other', Importance.none),
        reminderChannel(Importance.defaultImportance),
      ];
      expect(await allowed(), isTrue);
    });

    test('is false when notifications are off for the whole app', () async {
      appAllowed = false;
      listedChannels = [reminderChannel(Importance.defaultImportance)];
      expect(await allowed(), isFalse);
    });

    test('is true when the phone lists no channels at all', () async {
      listedChannels = null;
      expect(await allowed(), isTrue);
    });
  });

  test('notificationsAllowed on iOS is the permission check alone', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    IOSFlutterLocalNotificationsPlugin.registerWith();
    final platform = PluginReminderPlatform();
    expect(await platform.notificationsAllowed(), isTrue);
    iosAllowed = false;
    expect(await platform.notificationsAllowed(), isFalse);
    expect(
      calls.map((call) => call.method),
      everyElement('checkPermissions'),
      reason: 'no channels on iOS',
    );
  });

  test('the reminder channel shows no launcher badge (spec §1)', () async {
    onAndroid();
    await PluginReminderPlatform().schedule(tonight());
    final arguments = scheduleCalls().single.arguments as Map;
    final specifics = arguments['platformSpecifics'] as Map;
    expect(specifics['channelId'], PluginReminderPlatform.channelId);
    expect(specifics['channelShowBadge'], isFalse);
  });

  group('the Android alarm mode', () {
    setUp(onAndroid);

    // Inexact alarms are held to about an hour only from Android 12; on
    // Android 7 to 11 a 20-hour-ahead reminder can come near midnight. Exact
    // alarms need no permission below Android 12, so there (and only there)
    // the reminder is exact. The app never declares an exact-alarm permission.
    Future<String?> scheduledMode() async {
      await PluginReminderPlatform().schedule(tonight());
      return modeOf(scheduleCalls().single);
    }

    test('exact alarms need no permission here (below Android 12): exact, '
        'allowed while idle', () async {
      exactAlarmsAllowed = true;
      expect(await scheduledMode(), 'exactAllowWhileIdle');
    });

    test('exact alarms are not allowed (Android 12 and up, no exact-alarm '
        'permission): inexact, allowed while idle', () async {
      exactAlarmsAllowed = false;
      expect(await scheduledMode(), 'inexactAllowWhileIdle');
    });

    test('the check fails: inexact', () async {
      exactAlarmCheckFails = true;
      expect(await scheduledMode(), 'inexactAllowWhileIdle');
    });

    test('the phone gives no answer: inexact', () async {
      exactAlarmsAllowed = null;
      expect(await scheduledMode(), 'inexactAllowWhileIdle');
    });

    test(
      'the phone is asked once for all the reminders of a process',
      () async {
        exactAlarmsAllowed = true;
        final platform = PluginReminderPlatform();
        for (var i = 0; i < 3; i++) {
          await platform.schedule(tonight());
        }
        expect(
          calls.where((call) => call.method == 'canScheduleExactNotifications'),
          hasLength(1),
        );
        expect(
          scheduleCalls().map(modeOf),
          everyElement('exactAllowWhileIdle'),
        );
        expect(scheduleCalls(), hasLength(3));
      },
    );
  });

  test('iOS schedules as before and never asks about exact alarms', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    IOSFlutterLocalNotificationsPlugin.registerWith();
    exactAlarmsAllowed = true;
    await PluginReminderPlatform().schedule(tonight());
    expect(scheduleCalls(), hasLength(1));
    expect(
      calls.map((call) => call.method),
      isNot(contains('canScheduleExactNotifications')),
    );
  });
}

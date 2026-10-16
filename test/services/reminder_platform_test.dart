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
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pluginChannel, (call) async {
          calls.add(call);
          return switch (call.method) {
            'areNotificationsEnabled' => appAllowed,
            'getNotificationChannels' => listedChannels,
            'checkPermissions' => {'isEnabled': iosAllowed},
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
    await PluginReminderPlatform().schedule(
      PlannedReminder(
        id: 101,
        slot: ReminderSlot.evening,
        at: DateTime(2099, 1, 2, 19, 30),
        title: 'Brushing time!',
        body: "Tonight's cavity monsters are waiting.",
      ),
    );
    final arguments = calls.single.arguments as Map;
    final specifics = arguments['platformSpecifics'] as Map;
    expect(specifics['channelId'], PluginReminderPlatform.channelId);
    expect(specifics['channelShowBadge'], isFalse);
  });
}

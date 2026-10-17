// test/flows/reminder_offer_flow_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The bedtime reminder's parent gate, in the camera-flow pattern
/// (camera_mode_flow_test.dart; memory decision_camera_parent_gate.md): the
/// GROWN-UP CHECK, then the parent's own explanation (Screen B), then the OS
/// prompt, then the reminder saved only if the OS allows it. Behaviour is
/// pinned by reminder_handoff_screen_test, reminder_parent_screen_test and
/// reminder_service_test; this pins the order in the code and the wiring.
void main() {
  String read(String path) => File(path).readAsStringSync();

  /// The text of [source] from [from] up to the next [to].
  String section(String source, String from, String to) {
    final start = source.indexOf(from);
    expect(start, isNonNegative, reason: from);
    final end = source.indexOf(to, start + from.length);
    expect(end, isNonNegative, reason: to);
    return source.substring(start, end);
  }

  test('the hand-off reaches the reminder screen only through the GROWN-UP '
      'CHECK', () {
    final handoff = read('lib/screens/reminder_handoff_screen.dart');
    final lock = section(handoff, 'Future<void> _openLock()', 'Widget build(');
    final gate = lock.indexOf('showParentGate(context)');
    final passed = lock.indexOf('if (passed ?? false)');
    final screen = lock.indexOf('ReminderParentScreen()');
    expect(gate, isNonNegative);
    expect(passed, greaterThan(gate));
    expect(screen, greaterThan(passed));
    expect(
      'ReminderParentScreen('.allMatches(handoff),
      hasLength(1),
      reason: 'no other way into the reminder screen',
    );
  });

  test(
    'TURN ON asks the OS first; the reminder is saved only if it allows',
    () {
      final service = read('lib/services/reminder_service.dart');
      final turnOn = section(
        service,
        'Future<bool> turnOn(',
        'Future<void> saveSettings(',
      );
      final ask = turnOn.indexOf('requestPermission');
      final guard = turnOn.indexOf('if (!granted) return false;');
      final save = turnOn.indexOf('_writeSettings(');
      expect(ask, isNonNegative);
      expect(guard, greaterThan(ask));
      expect(save, greaterThan(guard));
      final saveSettings = section(
        service,
        'Future<void> saveSettings(',
        'Future<ReminderOffer?> offerDue(',
      );
      expect(saveSettings, contains('changed.eveningOn && current.eveningOn'));
      expect(saveSettings, contains('changed.morningOn && current.morningOn'));
      final parent = read('lib/screens/reminder_parent_screen.dart');
      expect(parent, contains('ReminderService().turnOn('));
      expect(parent, isNot(contains('saveSettings(')));
    },
  );

  test('nothing else asks for notification permission', () {
    final askers = [
      for (final f in Directory('lib').listSync(recursive: true))
        if (f is File &&
            f.path.endsWith('.dart') &&
            f.readAsStringSync().contains('requestPermission'))
          f.path,
    ]..sort();
    expect(askers, [
      'lib/services/reminder_platform.dart',
      'lib/services/reminder_service.dart',
    ]);
    final service = read('lib/services/reminder_service.dart');
    expect(
      'requestPermission'.allMatches(service),
      hasLength(1),
      reason: 'only turnOn asks',
    );
  });

  test('main sets reminders up and follows the app in and out', () {
    final main = read('lib/main.dart');
    expect(main, contains('unawaited(ReminderService().init());'));
    final paused = section(
      main,
      'if (state == AppLifecycleState.paused)',
      '} else if (state == AppLifecycleState.inactive',
    );
    expect(paused, contains('ReminderService().onAppPaused()'));
    final resumed = section(
      main,
      '} else if (state == AppLifecycleState.resumed)',
      'Widget build(',
    );
    expect(resumed, contains('ReminderService().onAppResumed()'));
  });

  test('the victory screen: every brush replans; DONE offers before Home', () {
    final victory = read('lib/screens/victory_screen.dart');
    final record = victory.indexOf('_streakService.recordBrush(');
    final replan = victory.indexOf('ReminderService().reschedule()');
    expect(record, isNonNegative);
    expect(replan, greaterThan(record));
    final goHome = section(
      victory,
      'Future<void> _goHome() async {',
      'Widget build(BuildContext context)',
    );
    expect(
      goHome.indexOf('ReminderService().offerDue()'),
      greaterThan(goHome.lastIndexOf('stopVoice()')),
    );
    expect(goHome, contains('ReminderHandoffScreen(offer: offer)'));
    expect(goHome, contains('AfterBrushHome.route()'));
  });

  test('Home is not changed', () {
    final home = read('lib/screens/home_screen.dart');
    expect(home, isNot(contains('Reminder')));
  });
}

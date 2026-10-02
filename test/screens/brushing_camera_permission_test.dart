import 'package:brush_quest/screens/brushing_screen.dart';
import 'package:brush_quest/services/audio_service.dart';
import 'package:brush_quest/services/camera_service.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../audio/fake_audio_service.dart';

/// Brushing must never show the OS camera dialog: the child holds the phone,
/// and only a parent behind the math gate (onboarding camera page, Settings)
/// may ever see it (COPPA / Apple Kids).
///
/// `camera_enabled` can be ON while the OS access is gone: Android "Only this
/// time", Android's auto-reset after months unused, or progress restored onto
/// a new phone. Brushing then only CHECKS the permission, turns the setting
/// OFF (so the parent's Settings switch tells the truth) and runs the normal
/// timer-mode brush.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const permissionChannel = MethodChannel(
    'flutter.baseflow.com/permissions/methods',
  );
  const cameraChannel = MethodChannel('plugins.flutter.io/camera');
  // permission_handler wire values.
  const cameraPermission = 1; // Permission.camera
  const denied = 0;
  const granted = 1;
  const permanentlyDenied = 4;

  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late FakeAudioService fakeAudio;
  late List<MethodCall> permissionCalls;
  late int statusResult;

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    messenger
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
    fakeAudio = FakeAudioService();
    AudioService.testInstance = fakeAudio;
    permissionCalls = <MethodCall>[];
    statusResult = denied;
    messenger
      ..setMockMethodCallHandler(permissionChannel, (call) async {
        permissionCalls.add(call);
        switch (call.method) {
          case 'checkPermissionStatus':
            return statusResult;
          case 'requestPermissions':
            // What the OS dialog would answer if it were (wrongly) shown.
            return <int, int>{cameraPermission: statusResult};
        }
        return null;
      })
      // The test host has no camera.
      ..setMockMethodCallHandler(
        cameraChannel,
        (call) async => call.method == 'availableCameras' ? <Object>[] : null,
      );
  });

  tearDown(() {
    AudioService.testInstance = FakeAudioService();
    messenger
      ..setMockMethodCallHandler(permissionChannel, null)
      ..setMockMethodCallHandler(cameraChannel, null);
    CameraService().dispose();
  });

  List<MethodCall> cameraRequests() =>
      permissionCalls.where((c) => c.method == 'requestPermissions').toList();

  List<MethodCall> cameraChecks() => permissionCalls
      .where(
        (c) =>
            c.method == 'checkPermissionStatus' &&
            c.arguments == cameraPermission,
      )
      .toList();

  void ignoreOverflow() {
    final orig = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.toString().contains('overflowed')) return;
      orig?.call(details);
    };
    addTearDown(() => FlutterError.onError = orig);
  }

  /// A parent turned the camera on earlier (here: restored from the cloud,
  /// where `home_camera_nudge_shown` isn't synced). Home always sets
  /// `camera_mode_configured` before it opens the brushing screen.
  Map<String, Object> cameraOnPrefs({bool midBrush = false}) => {
    'phase_duration': 20,
    'camera_enabled': true,
    'camera_mode_configured': true,
    'camera_prompt_shown': true,
    'onboarding_completed': true,
    'selected_hero': 'blaze',
    'selected_weapon': 'star_blaster',
    'current_world': 'candy_crater',
    'muted': false,
    'total_brushes': 5,
    if (midBrush) ...{
      'session_checkpoint_ts': DateTime.now().millisecondsSinceEpoch,
      'session_checkpoint_phase': 'topLeft',
      'session_checkpoint_seconds': 15,
      'session_checkpoint_world': 'candy_crater',
    },
  };

  Future<void> pumpBrushingScreen(
    WidgetTester tester,
    Map<String, Object> prefs,
  ) async {
    SharedPreferences.setMockInitialValues(prefs);
    await tester.binding.setSurfaceSize(const Size(430, 932));
    await tester.pumpWidget(const MaterialApp(home: BrushingScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> tearDownScreen(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
    await tester.binding.setSurfaceSize(null);
  }

  Future<void> expectOnlyCameraSettingTurnedOff() async {
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getBool('camera_enabled'),
      isFalse,
      reason: "Settings must show OFF: the camera can't work without access",
    );
    // The parent turns it back on behind the gate; no other flag changes.
    expect(prefs.getBool('camera_mode_configured'), isTrue);
    expect(prefs.getBool('camera_prompt_shown'), isTrue);
    expect(prefs.containsKey('home_camera_nudge_shown'), isFalse);
  }

  /// Timer mode: with no camera the hero attacks on his own every 2.5 s.
  Future<void> expectTimerModeAttacks(WidgetTester tester) async {
    expect(find.byIcon(Icons.pause), findsWidgets); // brushing screen is up
    expect(find.byIcon(Icons.videocam), findsNothing); // no camera indicator
    fakeAudio.clearCalls();
    await tester.pump(const Duration(seconds: 3));
    expect(fakeAudio.callsFor('nextHitSound'), isNotEmpty);
  }

  for (final (name, status) in [
    ('denied', denied),
    ('permanentlyDenied', permanentlyDenied),
  ]) {
    testWidgets(
      'camera on, access $name: no OS dialog, setting turned OFF, the brush '
      'runs in timer mode',
      (tester) async {
        ignoreOverflow();
        statusResult = status;
        await pumpBrushingScreen(tester, cameraOnPrefs());

        expect(
          cameraRequests(),
          isEmpty,
          reason: 'the child must never see the OS camera dialog',
        );
        expect(cameraChecks(), hasLength(1));
        await expectOnlyCameraSettingTurnedOff();

        // The session goes on: tap to fight -> 3-2-1-GO -> brushing.
        await tester.tap(find.byType(BrushingScreen));
        await tester.pump();
        expect(find.text('3'), findsOneWidget);
        await tester.pump(const Duration(seconds: 4));
        await expectTimerModeAttacks(tester);

        expect(cameraRequests(), isEmpty);
        await tearDownScreen(tester);
      },
    );
  }

  testWidgets(
    'resumed mid-brush with access gone: no OS dialog, setting OFF, timer mode',
    (tester) async {
      ignoreOverflow();
      await pumpBrushingScreen(tester, cameraOnPrefs(midBrush: true));

      expect(cameraRequests(), isEmpty);
      expect(cameraChecks(), hasLength(1));
      await expectOnlyCameraSettingTurnedOff();
      await expectTimerModeAttacks(tester);

      await tearDownScreen(tester);
    },
  );

  for (final (name, availableCameras) in <(String, Future<Object?> Function())>[
    ('no camera on the device', () async => <Object>[]),
    (
      'camera fails to start',
      () async => throw PlatformException(code: 'CameraAccessDenied'),
    ),
  ]) {
    testWidgets('access granted but $name: setting left ON', (tester) async {
      ignoreOverflow();
      statusResult = granted;
      messenger.setMockMethodCallHandler(
        cameraChannel,
        (call) => call.method == 'availableCameras'
            ? availableCameras()
            : Future<Object?>.value(),
      );
      await pumpBrushingScreen(tester, cameraOnPrefs());

      expect(cameraRequests(), isEmpty);
      expect(cameraChecks(), hasLength(1));
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getBool('camera_enabled'),
        isTrue,
        reason: 'only a missing permission turns the setting off',
      );

      await tearDownScreen(tester);
    });
  }
}

import 'package:brush_quest/screens/settings_screen.dart';
import 'package:brush_quest/services/audio_service.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../audio/fake_audio_service.dart';

/// Settings -> Brushing detection must follow the canonical 4-step COPPA
/// parent gate (memory: decision_camera_parent_gate.md): math gate (the
/// Settings entry gate) -> consent dialog -> OS permission request INSIDE
/// the parent flow -> `camera_enabled` written only when the OS grants.
///
/// Before the fix, ENABLE wrote camera_enabled=true without asking the OS,
/// so the iOS camera prompt fired later inside the child's brushing session
/// (and a child's "Don't Allow" is permanent on iOS while Settings kept
/// showing ON).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const permissionChannel = MethodChannel(
    'flutter.baseflow.com/permissions/methods',
  );
  // permission_handler wire values.
  const cameraPermission = 1; // Permission.camera
  const denied = 0;
  const granted = 1;
  const permanentlyDenied = 4;

  late FakeAudioService fakeAudio;
  late List<MethodCall> permissionCalls;
  late int requestResult;

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
    fakeAudio = FakeAudioService();
    AudioService.testInstance = fakeAudio;
    permissionCalls = <MethodCall>[];
    requestResult = granted;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(permissionChannel, (call) async {
          permissionCalls.add(call);
          switch (call.method) {
            case 'requestPermissions':
              return <int, int>{cameraPermission: requestResult};
            case 'checkPermissionStatus':
              return denied;
          }
          return null;
        });
  });

  tearDown(() {
    AudioService.testInstance = null;
    AudioService.debugIsIOSOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(permissionChannel, null);
  });

  List<MethodCall> cameraRequests() => permissionCalls
      .where(
        (c) =>
            c.method == 'requestPermissions' &&
            (c.arguments as List).contains(cameraPermission),
      )
      .toList();

  /// Pumps Settings, passes the Parent Check and opens the Settings tab with
  /// the Brushing detection card on screen.
  Future<void> openBrushingDetection(
    WidgetTester tester, {
    bool cameraEnabled = false,
  }) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'camera_enabled': cameraEnabled,
    });
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final challenge = tester.widget<Text>(find.textContaining('×')).data!;
    final m = RegExp(r'(\d+)\s*×\s*(\d+)').firstMatch(challenge)!;
    final answer = int.parse(m.group(1)!) * int.parse(m.group(2)!);
    await tester.enterText(find.byType(TextField), '$answer');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Settings'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    await tester.scrollUntilVisible(
      find.text('Brushing detection'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pump();
  }

  Finder cameraSwitch() => find.descendant(
    of: find.ancestor(
      of: find.text('Brushing detection'),
      matching: find.byType(Row),
    ),
    matching: find.byType(Switch),
  );

  Future<void> tapSwitchAndAnswerConsent(
    WidgetTester tester, {
    required String action,
  }) async {
    await tester.tap(cameraSwitch());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Brushing Detection'), findsOneWidget);
    await tester.tap(find.text(action));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<bool?> storedCameraEnabled() async =>
      (await SharedPreferences.getInstance()).getBool('camera_enabled');

  group('iOS: OS camera prompt fires inside the parent flow', () {
    setUp(() => AudioService.debugIsIOSOverride = true);

    testWidgets('granted -> camera_enabled=true, switch ON', (tester) async {
      requestResult = granted;
      await openBrushingDetection(tester);

      await tapSwitchAndAnswerConsent(tester, action: 'ENABLE');

      expect(cameraRequests(), hasLength(1));
      expect(await storedCameraEnabled(), isTrue);
      expect(tester.widget<Switch>(cameraSwitch()).value, isTrue);
    });

    testWidgets('denied -> flag stays false, switch stays OFF', (tester) async {
      requestResult = denied;
      await openBrushingDetection(tester);

      await tapSwitchAndAnswerConsent(tester, action: 'ENABLE');

      expect(cameraRequests(), hasLength(1));
      expect(await storedCameraEnabled(), isFalse);
      expect(tester.widget<Switch>(cameraSwitch()).value, isFalse);
      // Parent made an informed choice: suppression flag set regardless.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('camera_mode_configured'), isTrue);
    });

    testWidgets('permanentlyDenied -> flag stays false, switch stays OFF', (
      tester,
    ) async {
      requestResult = permanentlyDenied;
      await openBrushingDetection(tester);

      await tapSwitchAndAnswerConsent(tester, action: 'ENABLE');

      expect(cameraRequests(), hasLength(1));
      expect(await storedCameraEnabled(), isFalse);
      expect(tester.widget<Switch>(cameraSwitch()).value, isFalse);
    });

    testWidgets('CANCEL on consent -> no OS request, nothing written', (
      tester,
    ) async {
      await openBrushingDetection(tester);

      await tapSwitchAndAnswerConsent(tester, action: 'CANCEL');

      expect(cameraRequests(), isEmpty);
      expect(await storedCameraEnabled(), isFalse);
      expect(tester.widget<Switch>(cameraSwitch()).value, isFalse);
    });

    testWidgets('turning OFF never asks the OS', (tester) async {
      await openBrushingDetection(tester, cameraEnabled: true);
      expect(tester.widget<Switch>(cameraSwitch()).value, isTrue);

      await tester.tap(cameraSwitch());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(cameraRequests(), isEmpty);
      expect(await storedCameraEnabled(), isFalse);
    });
  });

  group('Android (v28 baseline): unchanged', () {
    setUp(() => AudioService.debugIsIOSOverride = false);

    testWidgets('ENABLE writes camera_enabled without an OS request', (
      tester,
    ) async {
      await openBrushingDetection(tester);

      await tapSwitchAndAnswerConsent(tester, action: 'ENABLE');

      expect(cameraRequests(), isEmpty);
      expect(await storedCameraEnabled(), isTrue);
    });
  });
}

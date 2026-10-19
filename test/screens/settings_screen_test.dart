import 'package:brush_quest/screens/settings_screen.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../audio/fake_audio_service.dart';
import 'package:brush_quest/services/audio_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeAudioService fakeAudio;

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();

    // Mock audioplayers platform channel
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('xyz.luan/audioplayers.global'),
          (call) async => 1,
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('xyz.luan/audioplayers'),
          (call) async => 1,
        );
  });

  setUp(() {
    fakeAudio = FakeAudioService();
    AudioService.testInstance = fakeAudio;
  });

  tearDown(() {
    AudioService.testInstance = null;
  });

  Future<void> pumpSettings(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'phase_duration': 20,
      'camera_enabled': false,
      'total_brushes': 10,
      'best_streak': 5,
      'muted': false,
    });

    await tester.binding.setSurfaceSize(const Size(430, 932));
    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('parent gate blocks settings until math is answered', (
    tester,
  ) async {
    await pumpSettings(tester);

    // Parent gate shows the math challenge
    expect(find.byType(TextField), findsOneWidget);

    // Settings content behind the gate should NOT be rendered
    expect(find.text('ACCOUNT'), findsNothing);
    expect(find.text('BRUSHING'), findsNothing);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('camera defaults to OFF', (tester) async {
    await pumpSettings(tester);

    // Verify camera_enabled is false in SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('camera_enabled'), false);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('the Dashboard shows Ranger Rank, the lifetime stars', (
    tester,
  ) async {
    // Kids see only the wallet pill now; Ranger Rank lives here, for parents.
    SharedPreferences.setMockInitialValues({
      'total_brushes': 10,
      'best_streak': 5,
      'total_stars': 715,
      'star_wallet': 358,
      'muted': false,
    });
    await tester.binding.setSurfaceSize(const Size(430, 3200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final challenge = tester.widget<Text>(find.textContaining('×')).data!;
    final m = RegExp(r'(\d+)\s*×\s*(\d+)').firstMatch(challenge)!;
    await tester.enterText(
      find.byType(TextField),
      '${int.parse(m.group(1)!) * int.parse(m.group(2)!)}',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final row = find.byKey(const ValueKey('dashboard_ranger_rank'));
    expect(row, findsOneWidget);
    expect(
      find.descendant(of: row, matching: find.text('715')),
      findsOneWidget,
    );
  });
}

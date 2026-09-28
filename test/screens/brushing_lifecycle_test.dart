import 'package:brush_quest/screens/brushing_screen.dart';
import 'package:brush_quest/services/audio_service.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../audio/fake_audio_service.dart';

/// BrushingScreen's app-lifecycle audio handling, run for both platform
/// branches via AudioService.debugIsIOSOverride.
///
/// The session is started mid-brush through the checkpoint-restore path
/// (a fresh checkpoint for the current world), which calls
/// `_startBrushing(resumeFromCheckpoint: true)` and so puts the screen in
/// SessionStage.brushing with battle music started.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeAudioService fakeAudio;

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
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
  });

  tearDown(() {
    AudioService.debugIsIOSOverride = null;
    AudioService.testInstance = FakeAudioService();
  });

  Future<void> pumpMidBrush(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'phase_duration': 30,
      'camera_enabled': false,
      'camera_mode_configured': true,
      'selected_hero': 'blaze',
      'selected_weapon': 'star_blaster',
      'current_world': 'candy_crater',
      'muted': false,
      'total_brushes': 5,
      'session_checkpoint_ts': DateTime.now().millisecondsSinceEpoch,
      'session_checkpoint_phase': 'topLeft',
      'session_checkpoint_seconds': 20,
      'session_checkpoint_world': 'candy_crater',
    });
    await tester.binding.setSurfaceSize(const Size(430, 932));
    await tester.pumpWidget(const MaterialApp(home: BrushingScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(
      fakeAudio.callsFor('playMusic'),
      isNotEmpty,
      reason: 'checkpoint restore should have started battle music',
    );
    expect(fakeAudio.isMusicPlaying, isTrue);
    fakeAudio.clearCalls();
  }

  Future<void> tearDownScreen(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
    await tester.binding.setSurfaceSize(null);
  }

  void ignoreOverflow() {
    final orig = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.toString().contains('overflowed')) return;
      orig?.call(details);
    };
    addTearDown(() => FlutterError.onError = orig);
  }

  List<String> methods() => fakeAudio.calls.map((c) => c.method).toList();

  testWidgets('Android: inactive stops all audio and auto-pauses', (
    tester,
  ) async {
    ignoreOverflow();
    AudioService.debugIsIOSOverride = false;
    await pumpMidBrush(tester);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();

    expect(methods(), containsAllInOrder(['stopAllAudio', 'pauseMusic']));
    expect(fakeAudio.isMusicPlaying, isFalse);
    expect(find.byIcon(Icons.play_arrow), findsWidgets);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tearDownScreen(tester);
  });

  testWidgets('iOS: transient inactive auto-pauses but keeps the music', (
    tester,
  ) async {
    ignoreOverflow();
    AudioService.debugIsIOSOverride = true;
    await pumpMidBrush(tester);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();

    expect(methods(), contains('pauseMusic'));
    expect(methods(), isNot(contains('stopAllAudio')));
    expect(fakeAudio.isMusicPlaying, isTrue);
    expect(fakeAudio.isMusicPaused, isTrue);
    expect(find.byIcon(Icons.play_arrow), findsWidgets);

    // Back from Control Center: stays paused until the kid taps RESUME.
    fakeAudio.clearCalls();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(methods(), isNot(contains('playMusic')));
    expect(fakeAudio.isMusicPaused, isTrue);

    // RESUME tap -> resumeMusic works because the player was kept.
    await tester.tap(find.byIcon(Icons.play_arrow).first);
    await tester.pump();
    expect(methods(), contains('resumeMusic'));
    expect(fakeAudio.isMusicPaused, isFalse);
    expect(fakeAudio.isMusicPlaying, isTrue);

    await tearDownScreen(tester);
  });

  testWidgets('iOS: a real background (paused) still stops all audio', (
    tester,
  ) async {
    ignoreOverflow();
    AudioService.debugIsIOSOverride = true;
    await pumpMidBrush(tester);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();

    expect(methods(), containsAllInOrder(['pauseMusic', 'stopAllAudio']));
    expect(
      methods().where((m) => m == 'pauseMusic'),
      hasLength(1),
      reason: 'already paused on inactive; paused must not toggle it back',
    );

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.byIcon(Icons.play_arrow), findsWidgets);
    await tearDownScreen(tester);
  });
}

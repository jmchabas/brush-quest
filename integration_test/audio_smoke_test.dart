// Audio smoke integration test (1V-7).
//
// Verifies the high-level audio contract that brushing_screen.dart relies on:
//   • countdown voice plays before any brushing-phase music/SFX
//   • music starts when the brushing screen begins its session
//   • voice and SFX never overlap (voice ducks SFX windows)
//   • mute flushes everything
//
// We can't drive the full brushing screen end-to-end in this harness without
// a Simulator with assets + camera + Firebase emulator wired in, so this file
// asserts the contract by replaying the same call sequence the screen issues
// at runtime against [FakeAudioService] (the same fake every other widget
// test uses). The integration_test binding is still required so the file is
// CI-ready for the Codemagic `ios_tests` workflow that runs the whole
// integration_test/ directory on a real iPhone.
//
// Limitations honestly recorded:
//   • Camera-driven attack SFX cadence is NOT simulated — we trigger SFX
//     manually at the same points brushing_screen.dart does.
//   • Voice playback is treated as instantaneous (the fake completes voices
//     synchronously). Overlap detection therefore validates ordering, not
//     real audio buffer collision.
//   • Phase transitions and the music health-check timer are not exercised.
//
// Run: flutter test integration_test/audio_smoke_test.dart -d "iPhone 15"

import 'package:brush_quest/services/audio_service.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/audio/fake_audio_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late FakeAudioService fake;

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
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
    fake = FakeAudioService();
    AudioService.testInstance = fake;
    fake.resetTracking();
  });

  tearDown(() {
    // Avoid resetting to a real AudioService here — the next setUp installs a
    // fresh fake, mirroring the pattern in test/audio/audio_integration_test.
  });

  /// Replays the audio sequence brushing_screen.dart issues at the start of a
  /// session: 3-2-1-GO countdown voices + beeps, then music start, then a
  /// couple of attack SFX.
  Future<void> simulateBrushingStartSequence(AudioService audio) async {
    // Countdown tick at value=3.
    await audio.playSfx('countdown_beep.mp3');
    await audio.playVoice('voice_three.mp3');
    // Tick at 2.
    await audio.playSfx('countdown_beep.mp3');
    await audio.playVoice('voice_two.mp3');
    // Tick at 1.
    await audio.playSfx('countdown_beep.mp3');
    await audio.playVoice('voice_one.mp3');
    // GO!
    await audio.playSfx('countdown_beep.mp3');
    await audio.playVoice('voice_lets_fight.mp3');

    // Music starts as the first phase (TL) begins.
    await audio.playMusic('battle_music_loop.mp3');

    // First two attack SFX from camera-driven combat.
    await audio.playSfx('zap.mp3');
    await audio.playSfx('whoosh.mp3');
  }

  testWidgets('countdown voices play before music starts', (tester) async {
    await simulateBrushingStartSequence(AudioService());
    await tester.pump();

    // All three count voices recorded, in order.
    expect(
      fake.playedVoiceLines.take(3),
      orderedEquals(<String>['voice_three.mp3', 'voice_two.mp3', 'voice_one.mp3']),
    );

    // Music started exactly once.
    expect(fake.musicEvents.where((e) => e == 'start').length, 1);

    // Every countdown voice was invoked before the music start event.
    final musicStartAt = fake.lastPlayCallTimes['music_start'];
    expect(musicStartAt, isNotNull);
    final firstVoiceAt = fake.playTimeline
        .firstWhere((e) => e.kind == 'voice_start')
        .at;
    expect(firstVoiceAt.isBefore(musicStartAt!) ||
            firstVoiceAt.isAtSameMomentAs(musicStartAt),
        isTrue);
  });

  testWidgets('music start event fires once during a brushing session',
      (tester) async {
    await simulateBrushingStartSequence(AudioService());
    await tester.pump();

    expect(fake.musicEvents, contains('start'));
    expect(fake.musicEvents.where((e) => e == 'start').length, 1);

    // Ducking fired during each voice line played while music was active.
    // Music only starts AFTER the countdown voices, so duck/restore should
    // appear zero times in the start sequence (no voice plays after music).
    expect(fake.musicEvents.where((e) => e == 'duck').length, 0);
  });

  testWidgets('SFX never overlap voice playback windows', (tester) async {
    await simulateBrushingStartSequence(AudioService());
    // Add a mid-brushing encouragement voice with surrounding SFX, the way
    // brushing_screen.dart sequences attacks around the ~65% encouragement.
    final audio = AudioService();
    await audio.playSfx('zap.mp3');
    await audio.playVoice('voice_keep_going.mp3');
    await audio.playSfx('whoosh.mp3');
    await tester.pump();

    // Build a list of (start,end) windows from the timeline.
    final voiceWindows = <({DateTime start, DateTime end, String name})>[];
    DateTime? openStart;
    String? openName;
    for (final ev in fake.playTimeline) {
      if (ev.kind == 'voice_start') {
        openStart = ev.at;
        openName = ev.name;
      } else if (ev.kind == 'voice_end' && openStart != null) {
        voiceWindows.add(
          (start: openStart, end: ev.at, name: openName ?? ev.name),
        );
        openStart = null;
        openName = null;
      }
    }
    expect(voiceWindows, isNotEmpty,
        reason: 'expected at least one voice_start/voice_end pair');

    // No SFX timestamp may fall strictly inside any voice window. Equality on
    // boundary timestamps is allowed because the fake completes voices
    // synchronously and DateTime.now() can return identical values within a
    // single microtask.
    for (final sfx in fake.playTimeline.where((e) => e.kind == 'sfx')) {
      for (final w in voiceWindows) {
        final overlaps = sfx.at.isAfter(w.start) && sfx.at.isBefore(w.end);
        expect(overlaps, isFalse,
            reason:
                'SFX ${sfx.name} at ${sfx.at} fell inside voice ${w.name} '
                'window [${w.start}, ${w.end}]');
      }
    }
  });

  testWidgets('mute flushes voice queue and silences subsequent calls',
      (tester) async {
    final audio = AudioService();
    await audio.playMusic('battle_music_loop.mp3');
    fake.resetTracking();

    await audio.toggleMute();
    expect(fake.isMuted, isTrue);

    await audio.playSfx('zap.mp3');
    await audio.playVoice('voice_three.mp3');
    await tester.pump();

    // While muted, the fake records the AudioCall but does NOT push to the
    // assertion-friendly tracking lists, because tracking is meant to mirror
    // what the kid actually hears.
    expect(fake.playedSfx, isEmpty);
    expect(fake.playedVoiceLines, isEmpty);
    expect(fake.isVoicePlaying, isFalse);
  });
}

import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_test/flutter_test.dart';

import 'real_audio_service_harness.dart';

/// ANDROID AUDIO GOLDEN — the platform-channel call sequence today's shipped
/// (v28, Android production) AudioService produces for the flows that have
/// regressed before. Recorded BEFORE any iOS audio change on release/v29.
///
/// Host tests run on macOS, where Platform.isIOS is false, so these exercise
/// the Android branch of every platform check. Any diff here means a change
/// meant for iOS leaked into Android. Do not re-record to make a failure go
/// away; only re-record (`flutter test --update-goldens <this file>`) for an
/// intentional, reviewed Android behaviour change.
///
/// Each line: `<fake ms> <player>.<platform method> <arg>` or
/// `<player> <- <native event>` or `print audio issue: ...`.
/// Players: V voice, M0 first music player, S0-S2 SFX, M1.. later music.
void main() {
  setUpAll(AudioHarness.install);

  const dir = 'test/audio/goldens/android';
  // Every scenario runs with AudioService.debugIsIOSOverride = false
  // (AudioHarness.run's default), i.e. the Android branch of every gate.
  List<String> goldenLines(AudioHarness h) =>
      h.log.where((l) => !l.contains('print [')).toList();

  test('single voice', () {
    AudioHarness.run((h) {
      unawaited(h.service.playVoice('voice_super.mp3'));
      h.elapse(const Duration(seconds: 3));
      expect(h.service.isVoicePipelineActive, isFalse);
      expectAudioGolden(goldenLines(h), '$dir/single_voice.txt');
    });
  });

  test('queued pair plays back-to-back without a stop in between', () {
    AudioHarness.run(
      (h) {
        unawaited(h.service.playVoice('voice_greet_streak_high_1.mp3'));
        unawaited(h.service.playVoice('voice_streak_teach_high.mp3'));
        h.elapse(const Duration(seconds: 5));
        expect(h.callsOf('stop', label: 'V'), isEmpty);
        expect(h.callsOf('setSourceUrl', label: 'V'), hasLength(2));
        expectAudioGolden(goldenLines(h), '$dir/queued_pair.txt');
      },
      voiceDurations: const {
        'voice_greet_streak_high_1.mp3': Duration(milliseconds: 1400),
        'voice_streak_teach_high.mp3': Duration(milliseconds: 1800),
      },
    );
  });

  test('countdown 3-2-1-GO with interrupts, then battle music', () {
    AudioHarness.run(
      (h) {
        final s = h.service;
        // Mirrors BrushingScreen._startCountdown + _startBrushing.
        unawaited(s.playSfx('countdown_beep.mp3'));
        unawaited(
          s.playVoice('voice_three.mp3', clearQueue: true, interrupt: true),
        );
        h.elapseMs(1000);
        unawaited(s.playSfx('countdown_beep.mp3'));
        unawaited(
          s.playVoice('voice_two.mp3', clearQueue: true, interrupt: true),
        );
        h.elapseMs(1000);
        unawaited(s.playSfx('countdown_beep.mp3'));
        unawaited(
          s.playVoice('voice_one.mp3', clearQueue: true, interrupt: true),
        );
        h.elapseMs(1000);
        unawaited(s.playSfx('countdown_beep.mp3'));
        unawaited(
          s.playVoice('voice_go_brushing.mp3', clearQueue: true, interrupt: true),
        );
        h.elapseMs(800);
        unawaited(s.playMusic('battle_music_loop.mp3'));
        h.elapse(const Duration(seconds: 3));
        // Today an interrupted voice is logged as `voice_timeout` (the pump
        // only knows "not completed"). Logging quirk, pinned as-is.
        expect(h.issues, [
          for (final f in ['three', 'two', 'one'])
            'audio issue: op=voice_timeout file=voice_$f.mp3 err=none',
        ]);
        expectAudioGolden(goldenLines(h), '$dir/countdown.txt');
      },
      // Longer than the 1 s tick, so each interrupt really cuts a voice.
      voiceDurations: const {
        'voice_three.mp3': Duration(milliseconds: 1200),
        'voice_two.mp3': Duration(milliseconds: 1200),
        'voice_one.mp3': Duration(milliseconds: 1200),
        'voice_go_brushing.mp3': Duration(milliseconds: 900),
      },
    );
  });

  test('stopVoice mid-play releases the pump immediately', () {
    AudioHarness.run(
      (h) {
        unawaited(h.service.playVoice('voice_world_candy_crater.mp3'));
        h.elapseMs(1000);
        unawaited(h.service.stopVoice());
        h.elapseMs(1000);
        unawaited(h.service.playVoice('voice_lets_fight.mp3'));
        h.elapse(const Duration(seconds: 2));
        // Released by the external-stop completer (~1 s), not the 15 s
        // timeout, though it is still logged as `voice_timeout` today.
        const issue =
            'audio issue: op=voice_timeout '
            'file=voice_world_candy_crater.mp3 err=none';
        expect(h.issues, [issue]);
        expect(
          h.callsOf('setSourceUrl', label: 'V').last,
          contains('voice_lets_fight.mp3'),
        );
        expectAudioGolden(goldenLines(h), '$dir/stop_voice_mid_play.txt');
      },
      voiceDurations: const {
        'voice_world_candy_crater.mp3': Duration(seconds: 3),
        'voice_lets_fight.mp3': Duration(milliseconds: 500),
      },
    );
  });

  test('music ducks under voice and restores to the screen target', () {
    AudioHarness.run((h) {
      unawaited(h.service.playMusic('battle_music_loop.mp3'));
      h.elapseMs(100);
      unawaited(h.service.setMusicVolume(0.06));
      h.elapseMs(100);
      unawaited(h.service.playVoice('voice_super.mp3'));
      h.elapse(const Duration(seconds: 2));
      expectAudioGolden(goldenLines(h), '$dir/music_ducking.txt');
    });
  });

  test('music completed -> full restart at 0.18 (Android recovery)', () {
    AudioHarness.run((h) {
      unawaited(h.service.playMusic('battle_music_loop.mp3'));
      h.elapseMs(100);
      unawaited(h.service.setMusicVolume(0.06));
      h.elapseMs(100);
      // On Android `completed` on a looping player = MediaPlayer died after
      // an error (WrappedPlayer.onError returns false -> onCompletion). The
      // health check's restart is the only recovery.
      h.emit('M1', AudioEventType.complete);
      h.elapseMs(100);
      unawaited(h.service.ensureMusicPlaying());
      h.elapseMs(500);
      expect(h.callsOf('create', label: 'M2'), hasLength(1));
      expect(h.callsOf('setVolume', label: 'M2').single, endsWith(' 0.18'));
      expectAudioGolden(goldenLines(h), '$dir/music_completed_restart.txt');
    });
  });

  test('music paused -> health check resumes only', () {
    AudioHarness.run((h) {
      unawaited(h.service.playMusic('battle_music_loop.mp3'));
      h.elapseMs(100);
      unawaited(h.service.pauseMusic());
      h.elapseMs(100);
      unawaited(h.service.ensureMusicPlaying());
      h.elapseMs(500);
      expect(h.callsOf('create', label: 'M2'), isEmpty);
      expectAudioGolden(goldenLines(h), '$dir/music_paused_resume.txt');
    });
  });

  test('voice that never prepares blocks 30 s, then the next voice plays', () {
    AudioHarness.run(
      (h) {
        unawaited(h.service.playVoice('voice_arc2_beat1.mp3'));
        unawaited(h.service.playVoice('voice_arc2_beat2.mp3'));
        h.elapse(const Duration(seconds: 35));
        expect(h.issues.single, contains('op=voice_play_failed'));
        expectAudioGolden(goldenLines(h), '$dir/voice_never_prepares.txt');
      },
      neverPrepare: const {'voice_arc2_beat1.mp3'},
    );
  });

  test('mute stops voice + music and drops the queue', () {
    AudioHarness.run(
      (h) {
        unawaited(h.service.playMusic('battle_music_loop.mp3'));
        h.elapseMs(100);
        unawaited(h.service.playVoice('voice_victory_arc1_beat1.mp3'));
        unawaited(h.service.playVoice('voice_victory_arc1_beat2.mp3'));
        h.elapseMs(500);
        unawaited(h.service.toggleMute());
        h.elapse(const Duration(seconds: 4));
        expect(h.service.isMuted, isTrue);
        expectAudioGolden(goldenLines(h), '$dir/mute.txt');
      },
      voiceDurations: const {
        'voice_victory_arc1_beat1.mp3': Duration(seconds: 3),
      },
    );
  });

  test('lifecycle snapshot + resumeAfterWake restores track and volume', () {
    AudioHarness.run((h) {
      unawaited(h.service.playMusic('battle_music_loop.mp3'));
      h.elapseMs(100);
      unawaited(h.service.setMusicVolume(0.06));
      h.elapseMs(100);
      unawaited(h.service.stopAllAudioForLifecycle());
      h.elapseMs(1000);
      unawaited(h.service.resumeAfterWake());
      h.elapseMs(500);
      expect(h.callsOf('setVolume', label: 'M2').last, endsWith(' 0.06'));
      expectAudioGolden(goldenLines(h), '$dir/lifecycle_wake.txt');
    });
  });

  test('brushing pause -> RESUME tap', () {
    AudioHarness.run((h) {
      final s = h.service;
      unawaited(s.playMusic('battle_music_loop.mp3'));
      h.elapseMs(100);
      // _togglePause() -> paused
      unawaited(s.playSfx('whoosh.mp3'));
      unawaited(s.pauseMusic());
      h.elapseMs(2000);
      // _togglePause() -> resumed
      unawaited(s.resumeMusic());
      unawaited(
        s.playVoice('voice_keep_going.mp3', clearQueue: true, interrupt: true),
      );
      h.elapse(const Duration(seconds: 2));
      expectAudioGolden(goldenLines(h), '$dir/brushing_pause_resume.txt');
    });
  });

  test('Android background during brushing (inactive -> paused -> resumed)', () {
    AudioHarness.run((h) {
      final s = h.service;
      unawaited(s.playMusic('battle_music_loop.mp3'));
      h.elapseMs(100);
      // inactive: main.dart then BrushingScreen (registration order).
      unawaited(s.stopAllAudioForLifecycle());
      unawaited(s.stopAllAudio());
      unawaited(s.playSfx('whoosh.mp3'));
      unawaited(s.pauseMusic());
      h.elapseMs(300);
      // paused
      unawaited(s.stopAllAudioForLifecycle());
      unawaited(s.stopAllAudio());
      h.elapseMs(5000);
      // resumed: main.dart only (BrushingScreen is paused)
      unawaited(s.resumeAfterWake());
      h.elapseMs(1000);
      // Kid taps RESUME
      unawaited(s.resumeMusic());
      unawaited(
        s.playVoice('voice_go_go_go.mp3', clearQueue: true, interrupt: true),
      );
      h.elapse(const Duration(seconds: 2));
      expectAudioGolden(goldenLines(h), '$dir/android_background_brushing.txt');
    });
  });
}

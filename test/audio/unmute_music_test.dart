import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'real_audio_service_harness.dart';

/// Unmute brings the music back (Jim's device test of 1.1.0+42, 2026-10-19).
/// Muting stops the music; unmuting used to only save the setting, so the
/// screen stayed silent until a screen called playMusic again (and the music
/// health check skips a track it believes is stopped).
void main() {
  setUpAll(AudioHarness.install);

  test('unmute starts the current track again', () {
    AudioHarness.run((h) {
      final s = h.service;
      unawaited(s.playMusic('battle_music_loop.mp3'));
      h.elapseMs(100);
      unawaited(s.toggleMute());
      h.elapseMs(500);
      expect(s.isMusicPlaying, isFalse);
      final playersBefore = h.platform.createdCount;

      unawaited(s.toggleMute());
      h.elapseMs(500);
      expect(s.isMuted, isFalse);
      expect(s.isMusicPlaying, isTrue);
      expect(h.platform.createdCount, playersBefore + 1);
      final m = 'M${h.platform.createdCount - 5}';
      expect(
        h.callsOf('setSourceUrl', label: m).single,
        endsWith('battle_music_loop.mp3'),
      );
      expect(h.callsOf('resume', label: m), hasLength(1));
    });
  });

  test("unmute keeps the screen's own music volume", () {
    AudioHarness.run((h) {
      final s = h.service;
      unawaited(s.playMusic('battle_music_loop.mp3'));
      h.elapseMs(100);
      unawaited(s.setMusicVolume(0.06)); // Home's level
      h.elapseMs(100);
      unawaited(s.toggleMute());
      h.elapseMs(500);
      unawaited(s.toggleMute());
      h.elapseMs(500);
      final m = 'M${h.platform.createdCount - 5}';
      expect(h.callsOf('setVolume', label: m).last, endsWith(' 0.06'));
    });
  });

  test('a track asked for while muted plays on unmute', () {
    AudioHarness.run((h) {
      final s = h.service;
      unawaited(s.toggleMute());
      h.elapseMs(100);
      unawaited(s.playMusic('battle_music_loop.mp3'));
      h.elapseMs(100);
      expect(s.isMusicPlaying, isFalse);
      unawaited(s.toggleMute());
      h.elapseMs(500);
      expect(s.isMusicPlaying, isTrue);
    });
  });

  test('no music on unmute when the screen had stopped it', () {
    AudioHarness.run((h) {
      final s = h.service;
      unawaited(s.playMusic('battle_music_loop.mp3'));
      h.elapseMs(100);
      unawaited(s.stopMusic());
      h.elapseMs(100);
      unawaited(s.toggleMute());
      h.elapseMs(100);
      final playersBefore = h.platform.createdCount;
      unawaited(s.toggleMute());
      h.elapseMs(500);
      expect(s.isMusicPlaying, isFalse);
      expect(h.platform.createdCount, playersBefore);
    });
  });

  test('unmute after muting in silence plays no music', () {
    AudioHarness.run((h) {
      final s = h.service;
      unawaited(s.toggleMute());
      h.elapseMs(100);
      unawaited(s.toggleMute());
      h.elapseMs(500);
      expect(s.isMusicPlaying, isFalse);
      expect(h.callsOf('setSourceUrl'), isEmpty);
    });
  });

  test('a voice after mute + unmute plays at once, not after the cut voice '
      'times out', () {
    // Muting stopped the player but not the pump's wait on that line, so the
    // next line waited out the 15 s voice timeout (found while tracing Jim's
    // unheard hand-off line, 2026-10-19).
    AudioHarness.run((h) {
      final s = h.service;
      unawaited(s.playVoice('voice_super.mp3'));
      h.elapseMs(500);
      unawaited(s.toggleMute());
      h.elapseMs(1000);
      unawaited(s.toggleMute());
      h.elapseMs(500);
      unawaited(s.playVoice('voice_reminder_handoff.mp3'));
      h.elapseMs(1000);
      expect(
        h.callsOf('setSourceUrl', label: 'V').last,
        endsWith('voice_reminder_handoff.mp3'),
      );
    }, voiceDurations: const {'voice_super.mp3': Duration(seconds: 3)});
  });
}

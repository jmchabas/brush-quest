import 'dart:async';
import 'dart:io' show Platform;

import 'package:brush_quest/services/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'real_audio_service_harness.dart';

/// iOS-branch behaviour of the REAL AudioService, run on the host with
/// `AudioService.debugIsIOSOverride = true` (see real_audio_service_harness).
/// These are HYBRID runs: code that reads Platform.isIOS directly still takes
/// the host branch, so they prove the Dart logic of each iOS gate, not iOS
/// itself. Device verification is still required.
void main() {
  setUpAll(AudioHarness.install);
  tearDown(() => AudioService.debugIsIOSOverride = null);

  group('platform gate', () {
    test('isIOS defaults to the host platform and follows the override', () {
      AudioService.debugIsIOSOverride = null;
      expect(AudioService.isIOS, Platform.isIOS);
      AudioService.debugIsIOSOverride = true;
      expect(AudioService.isIOS, isTrue);
      AudioService.debugIsIOSOverride = false;
      expect(AudioService.isIOS, isFalse);
    });

    test('trace is compiled out of normal builds (no [AUD] output)', () {
      expect(AudioService.traceEnabled, isFalse);
      AudioHarness.run((h) {
        unawaited(h.service.playVoice('voice_super.mp3'));
        h.elapse(const Duration(seconds: 2));
        expect(h.prints.where((p) => p.startsWith('[')), isEmpty);
      }, ios: true);
    });
  });

  group('lifecycle: wake while the brushing session is paused', () {
    // iOS sequence for a real background during brushing:
    //   inactive -> BrushingScreen auto-pause -> pauseMusic()
    //   paused   -> main.dart stopAllAudioForLifecycle() + brushing stopAll
    //   resumed  -> main.dart resumeAfterWake()   (PAUSE overlay still up)
    //   RESUME   -> resumeMusic()
    void backgroundWhilePaused(AudioHarness h) {
      final s = h.service;
      unawaited(s.playMusic('battle_music_loop.mp3'));
      h.elapseMs(100);
      unawaited(s.setMusicVolume(0.1));
      unawaited(s.pauseMusic());
      h.elapseMs(300);
      unawaited(s.stopAllAudioForLifecycle());
      unawaited(s.stopAllAudio());
      h.elapseMs(2000);
      unawaited(s.resumeAfterWake());
      h.elapseMs(1000);
    }

    test('iOS: resumeAfterWake does not start music under the PAUSE overlay; '
        'RESUME restarts it at the saved volume', () {
      AudioHarness.run((h) {
        backgroundWhilePaused(h);
        expect(
          h.callsOf('create', label: 'M2'),
          isEmpty,
          reason: 'no music restart while the session is paused',
        );
        expect(h.service.isMusicPlaying, isFalse);

        unawaited(h.service.resumeMusic());
        h.elapseMs(500);
        expect(h.callsOf('setSourceUrl', label: 'M2'), hasLength(1));
        expect(h.callsOf('resume', label: 'M2'), hasLength(1));
        expect(h.callsOf('setVolume', label: 'M2').last, endsWith(' 0.1'));
        expect(h.service.isMusicPlaying, isTrue);
      }, ios: true);
    });

    test('Android: unchanged - resumeAfterWake restarts right away', () {
      AudioHarness.run((h) {
        backgroundWhilePaused(h);
        // The brushing stopAllAudio races main.dart's snapshot; the wake
        // restart still happens immediately (see the Android goldens).
        expect(h.callsOf('create', label: 'M2'), hasLength(1));
      });
    });

    test('iOS: transient inactive (no paused) - RESUME resumes the same '
        'player', () {
      AudioHarness.run((h) {
        final s = h.service;
        unawaited(s.playMusic('battle_music_loop.mp3'));
        h.elapseMs(100);
        unawaited(s.pauseMusic());
        h.elapseMs(300);
        unawaited(s.resumeAfterWake()); // no snapshot -> no-op
        h.elapseMs(300);
        unawaited(s.resumeMusic());
        h.elapseMs(300);
        expect(h.callsOf('create', label: 'M2'), isEmpty);
        expect(h.callsOf('resume', label: 'M1'), hasLength(2));
      }, ios: true);
    });

    test('iOS: the hold cannot go stale - quitting a paused session and '
        'starting Home music clears it', () {
      AudioHarness.run((h) {
        final s = h.service;
        unawaited(s.playMusic('battle_music_loop.mp3'));
        h.elapseMs(100);
        unawaited(s.pauseMusic()); // paused ...
        h.elapseMs(100);
        unawaited(s.stopMusic()); // ... then quit (X)
        h.elapseMs(100);
        unawaited(s.playMusic('battle_music_loop.mp3')); // Home
        h.elapseMs(100);
        unawaited(s.setMusicVolume(0.06));
        h.elapseMs(100);
        // Home backgrounded + woken: must restart immediately.
        unawaited(s.stopAllAudioForLifecycle());
        h.elapseMs(1000);
        unawaited(s.resumeAfterWake());
        h.elapseMs(500);
        expect(h.callsOf('create', label: 'M3'), hasLength(1));
        expect(h.callsOf('setVolume', label: 'M3').last, endsWith(' 0.06'));
      }, ios: true);
    });
  });
}

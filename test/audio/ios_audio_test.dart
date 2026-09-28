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

  group('voice pump: iOS pre-play stop (N1)', () {
    /// Index of the first log line matching [pattern] at or after [from].
    int indexOf(List<String> log, Pattern pattern, [int from = 0]) {
      for (var i = from; i < log.length; i++) {
        if (log[i].contains(pattern)) return i;
      }
      return -1;
    }

    test('iOS: stop() between a natural completion and the next item', () {
      AudioHarness.run(
        (h) {
          unawaited(h.service.playVoice('voice_card_new.mp3'));
          unawaited(h.service.playVoice('voice_card_cc_01.mp3'));
          h.elapse(const Duration(seconds: 5));
          final log = h.log;
          final complete = indexOf(log, 'V <- complete');
          final stop = indexOf(log, 'V.stop', complete);
          final nextSource = indexOf(log, 'voice_card_cc_01.mp3');
          expect(complete, isNot(-1));
          expect(stop, greaterThan(complete));
          expect(nextSource, greaterThan(stop));
          expect(h.callsOf('stop', label: 'V'), hasLength(1));
          expect(h.issues, isEmpty);
        },
        ios: true,
        voiceDurations: const {
          'voice_card_new.mp3': Duration(milliseconds: 1500),
          'voice_card_cc_01.mp3': Duration(milliseconds: 1200),
        },
      );
    });

    test('iOS: no pre-play stop on a fresh (already stopped) player', () {
      AudioHarness.run((h) {
        unawaited(h.service.playVoice('voice_super.mp3'));
        h.elapse(const Duration(seconds: 2));
        expect(h.callsOf('stop', label: 'V'), isEmpty);
      }, ios: true);
    });

    test('iOS: an interrupt with a slow native stop reply gets exactly one '
        'stop (the pump awaits it instead of reading the lagging state)', () {
      AudioHarness.run(
        (h) {
          final s = h.service;
          unawaited(
            s.playVoice('voice_three.mp3', clearQueue: true, interrupt: true),
          );
          h.elapseMs(1000);
          unawaited(
            s.playVoice('voice_two.mp3', clearQueue: true, interrupt: true),
          );
          h.elapseMs(1000);
          unawaited(
            s.playVoice('voice_one.mp3', clearQueue: true, interrupt: true),
          );
          h.elapse(const Duration(seconds: 3));
          final log = h.log;
          // Between each voice's resume and the next voice's source there is
          // exactly one stop (the interrupt's).
          for (final pair in [
            ['voice_three.mp3', 'voice_two.mp3'],
            ['voice_two.mp3', 'voice_one.mp3'],
          ]) {
            final from = indexOf(log, pair[0]);
            final to = indexOf(log, pair[1], from);
            final stops = log
                .sublist(from, to)
                .where((l) => l.contains('V.stop'))
                .length;
            expect(stops, 1, reason: '${pair[0]} -> ${pair[1]}\n$log');
          }
          // The next source is only sent after the stop's (slow) reply.
          final twoAt = indexOf(log, 'setSourceUrl voice_two.mp3');
          expect(log[twoAt].trim(), startsWith('1050ms'));
          expect(
            h.callsOf('setSourceUrl', label: 'V').last,
            contains('voice_one.mp3'),
          );
        },
        ios: true,
        replyDelays: const {'stop': Duration(milliseconds: 50)},
        voiceDurations: const {
          'voice_three.mp3': Duration(milliseconds: 1200),
          'voice_two.mp3': Duration(milliseconds: 1200),
          'voice_one.mp3': Duration(milliseconds: 800),
        },
      );
    });

    test('Android: still no stop between queued items', () {
      AudioHarness.run((h) {
        unawaited(h.service.playVoice('voice_card_new.mp3'));
        unawaited(h.service.playVoice('voice_card_cc_01.mp3'));
        h.elapse(const Duration(seconds: 5));
        expect(h.callsOf('stop', label: 'V'), isEmpty);
        expect(h.callsOf('setSourceUrl', label: 'V'), hasLength(2));
      });
    });
  });
}

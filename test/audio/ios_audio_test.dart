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

  group('voice pump: iOS 4 s start cap (N2)', () {
    int firstAt(List<String> log, String needle) {
      final line = log.firstWhere((l) => l.contains(needle));
      return int.parse(line.trim().split('ms').first);
    }

    test('iOS: a voice that never prepares is skipped after 4 s, not 30 s', () {
      AudioHarness.run(
        (h) {
          unawaited(h.service.playVoice('voice_arc2_beat1.mp3'));
          unawaited(h.service.playVoice('voice_arc2_beat2.mp3'));
          h.elapse(const Duration(seconds: 8));
          const timeout =
              'audio issue: op=voice_prepare_timeout '
              'file=voice_arc2_beat1.mp3 err=none';
          expect(h.issues, [timeout]);
          final nextAt = firstAt(h.log, 'setSourceUrl voice_arc2_beat2.mp3');
          expect(nextAt, inInclusiveRange(4000, 4100));
          // The abandoned play() is still waiting for `prepared`; the next
          // item's `prepared` releases it too, so it resumes the NEW item a
          // second time (idempotent). Nothing plays before the next source.
          expect(
            h.callsOf('resume', label: 'V').map((l) => firstAt([l], 'ms')),
            everyElement(greaterThan(nextAt)),
          );
          expect(h.service.isVoicePipelineActive, isFalse);
          // The abandoned play() must not surface its 30 s TimeoutException.
          h.elapse(const Duration(seconds: 40));
          expect(h.issues, hasLength(1));
        },
        ios: true,
        neverPrepare: const {'voice_arc2_beat1.mp3'},
      );
    });

    test('iOS: a slow asset load that lands AFTER the next voice started '
        'never replaces it', () {
      AudioHarness.run(
        (h) {
          unawaited(h.service.playVoice('voice_world_candy_crater.mp3'));
          unawaited(h.service.playVoice('voice_lets_fight.mp3'));
          h.elapse(const Duration(seconds: 15));
          expect(
            h.log.where((l) => l.contains('voice_world_candy_crater.mp3')),
            everyElement(contains('print audio issue')),
            reason: 'the abandoned load must never reach setSourceUrl',
          );
          expect(
            h.callsOf('setSourceUrl', label: 'V').single,
            contains('voice_lets_fight.mp3'),
          );
          expect(firstAt(h.log, 'setSourceUrl voice_lets_fight'), 4000);
        },
        ios: true,
        loadDelays: const {
          'voice_world_candy_crater.mp3': Duration(seconds: 10),
        },
      );
    });

    test('iOS: an interrupt ends a stuck start immediately', () {
      AudioHarness.run(
        (h) {
          unawaited(h.service.playVoice('voice_arc2_beat1.mp3'));
          h.elapseMs(1000);
          unawaited(
            h.service.playVoice(
              'voice_go_brushing.mp3',
              clearQueue: true,
              interrupt: true,
            ),
          );
          h.elapse(const Duration(seconds: 3));
          expect(firstAt(h.log, 'setSourceUrl voice_go_brushing'), 1000);
          expect(h.issues, isEmpty);
          // Only the new voice's item is ever resumed (see above re: the
          // abandoned play() resuming it a second time).
          expect(
            h.callsOf('resume', label: 'V').map((l) => firstAt([l], 'ms')),
            everyElement(greaterThan(1000)),
          );
        },
        ios: true,
        neverPrepare: const {'voice_arc2_beat1.mp3'},
      );
    });

    test('iOS: stopVoice during a stuck start frees the pipeline at once', () {
      AudioHarness.run(
        (h) {
          unawaited(h.service.playVoice('voice_arc2_beat1.mp3'));
          h.elapseMs(500);
          expect(h.service.isVoicePipelineActive, isTrue);
          unawaited(h.service.stopVoice());
          h.elapseMs(10);
          expect(h.service.isVoicePipelineActive, isFalse);
          expect(h.issues, isEmpty);
        },
        ios: true,
        neverPrepare: const {'voice_arc2_beat1.mp3'},
      );
    });

    test('iOS: sends the same native source call as Android', () {
      String sourceCall({required bool ios}) {
        late String call;
        AudioHarness.run((h) {
          unawaited(h.service.playVoice('voice_super.mp3'));
          h.elapse(const Duration(seconds: 2));
          call = h.callsOf('setSourceUrl', label: 'V').single;
        }, ios: ios);
        return call;
      }

      expect(sourceCall(ios: true), sourceCall(ios: false));
    });
  });

  group('music: iOS serialized playMusic', () {
    test('iOS: overlapping starts run one after another, nothing is '
        'disposed mid-prepare', () {
      AudioHarness.run((h) {
        final s = h.service;
        unawaited(s.playMusic('battle_music_loop.mp3')); // M1, preparing
        h.elapseMs(5);
        // e.g. main.dart resumeAfterWake landing on a screen's own start.
        unawaited(s.playMusic('battle_music_loop.mp3'));
        h.elapseMs(500);
        expect(h.issues, isEmpty);
        // M1 finished (resume) before M2 was even created.
        final m1Resume = h.log.indexOf(h.callsOf('resume', label: 'M1').single);
        final m2Create = h.log.indexOf(h.callsOf('create', label: 'M2').single);
        expect(m2Create, greaterThan(m1Resume));
        expect(h.callsOf('resume', label: 'M2'), hasLength(1));
        expect(h.callsOf('create', label: 'M3'), isEmpty);
        expect(h.service.isMusicPlaying, isTrue);
      }, ios: true);
    });

    test('Android: the same overlap is left as-is (see goldens)', () {
      AudioHarness.run((h) {
        final s = h.service;
        unawaited(s.playMusic('battle_music_loop.mp3'));
        h.elapseMs(5);
        unawaited(s.playMusic('battle_music_loop.mp3'));
        h.elapseMs(500);
        expect(h.issues.single, contains('op=music_play_failed'));
      });
    });

    test('iOS: a start still waiting is dropped when a newer one arrives', () {
      AudioHarness.run((h) {
        final s = h.service;
        // Same instant: the first runs; the second is still waiting for its
        // turn when the third arrives, so only the first and last start.
        unawaited(s.playMusic('battle_music_loop.mp3')); // runs (M1)
        unawaited(s.playMusic('battle_music_loop.mp3')); // superseded
        unawaited(s.playMusic('battle_music_loop.mp3')); // runs (M2)
        h.elapseMs(500);
        expect(h.callsOf('create', label: 'M2'), hasLength(1));
        expect(h.callsOf('create', label: 'M3'), isEmpty);
        expect(h.issues, isEmpty);
      }, ios: true);
    });

    test('iOS: stopMusic drops a start that is still waiting its turn', () {
      AudioHarness.run((h) {
        final s = h.service;
        unawaited(s.playMusic('battle_music_loop.mp3')); // in flight (M1)
        unawaited(s.playMusic('battle_music_loop.mp3')); // waiting
        unawaited(s.stopMusic());
        h.elapseMs(500);
        expect(h.callsOf('create', label: 'M2'), isEmpty);
      }, ios: true);
    });

    test('iOS: the guarded retry runs inside the turn (no deadlock) and a '
        'queued start runs after it', () {
      AudioHarness.run(
        (h) {
          final s = h.service;
          unawaited(s.playMusic('battle_music_loop.mp3')); // never prepares
          h.elapseMs(100);
          unawaited(s.playMusic('battle_music_loop.mp3')); // queued
          // First attempt times out at 30 s, retry 300 ms later.
          h.elapse(const Duration(seconds: 31));
          expect(h.callsOf('create', label: 'M2'), hasLength(1)); // retry
          expect(h.callsOf('create', label: 'M3'), isEmpty); // still queued
          h.platform.neverPrepare.clear();
          h.elapse(const Duration(seconds: 31)); // retry fails -> turn freed
          h.elapseMs(200);
          expect(h.callsOf('resume', label: 'M3'), hasLength(1));
          expect(h.service.isMusicPlaying, isTrue);
        },
        ios: true,
        neverPrepare: const {'battle_music_loop.mp3'},
      );
    });
  });
}

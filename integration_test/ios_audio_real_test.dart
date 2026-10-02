// iOS real-native audio smoke (release/v29 iOS audio work).
//
// Drives the REAL AudioService against the REAL audioplayers_darwin plugin
// (the vendored, patched 6.3.0 in packages/audioplayers_darwin) on an iOS
// Simulator or device. No fakes, no mocked channels. Covers what host tests
// cannot: native completion/seek/stop timing.
//
// Run (needs the trace build for the music checks):
//   flutter test integration_test/ios_audio_real_test.dart \
//     -d <simulator-udid> --dart-define=AUDIO_TRACE=true
//
// Scenarios:
//   R1  50 back-to-back queued voice pairs (natural completion -> next item
//       on the same player, the N1 race) + realistic long pairs: zero voice
//       timeouts / prepare timeouts / play failures.
//   R2  interrupt storm (20 interrupts 30-80 ms apart, many landing while
//       the item is still loading): no crash, queue drains, last voice done.
//   R3  battle music for 130 s (past the 120 s loop wrap) with the 5 s
//       health tick: no restart, never `completed`, position keeps moving
//       and wraps.
//   R4  countdown 3-2-1-GO (clearQueue + interrupt, 1 s apart): all four
//       voices complete naturally, in order.
//   R5  music start/stop churn: every playMusic/stopMusic returns (a lost
//       native stop reply would hang playMusic).
//
// Not covered here (need a real iPhone): calls, Siri, alarms, AirPods, the
// ring/silent switch, device latency, iOS 15-16.

import 'dart:async';

import 'package:brush_quest/services/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final lines = <String>[];
  late DebugPrintCallback originalDebugPrint;

  /// Record every debugPrint line (audio issues + AUDIO_TRACE lines) while
  /// still printing it. flutter_test requires debugPrint restored per test.
  Future<void> capturing(Future<void> Function() body) async {
    originalDebugPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message == null) return;
      lines.add(message);
      originalDebugPrint(message, wrapWidth: wrapWidth);
    };
    try {
      await body();
    } finally {
      debugPrint = originalDebugPrint;
    }
  }

  List<String> issues() =>
      lines.where((l) => l.startsWith('audio issue:')).toList();

  List<String> issuesOf(Set<String> ops) =>
      issues().where((l) => ops.any((op) => l.contains('op=$op '))).toList();

  const failureOps = {
    'voice_timeout',
    'voice_prepare_timeout',
    'voice_play_failed',
  };

  final audio = AudioService();

  setUpAll(() async {
    await audio.preloadAll();
  });

  setUp(lines.clear);

  testWidgets(
    'R1: 50 back-to-back voice pairs, zero timeouts',
    (_) async {
      await capturing(() async {
        // (A, B) pairs queued the way screens queue them: A then B, no
        // interrupt, so B starts right after A's natural completion.
        const shortPairs = [
          ['voice_three.mp3', 'voice_two.mp3'],
          ['voice_one.mp3', 'voice_go_brushing.mp3'],
          ['voice_two.mp3', 'voice_three.mp3'],
        ];
        final slowest = <String, int>{};
        for (var i = 0; i < 50; i++) {
          final pair = shortPairs[i % shortPairs.length];
          final sw = Stopwatch()..start();
          final a = audio.playVoice(pair[0]);
          final b = audio.playVoice(pair[1]);
          await Future.wait([a, b]).timeout(const Duration(seconds: 20));
          final ms = sw.elapsedMilliseconds;
          final key = pair.join('+');
          if (ms > (slowest[key] ?? 0)) slowest[key] = ms;
        }
        // Realistic pairs from the app (Home greeting -> streak teach, hero
        // tap -> world briefing, victory card reveal).
        const realPairs = [
          ['voice_greet_streak_high_1.mp3', 'voice_streak_teach_high.mp3'],
          ['voice_lets_fight.mp3', 'voice_world_candy_crater.mp3'],
          ['voice_card_new.mp3', 'voice_card_cc_01.mp3'],
        ];
        for (final pair in realPairs) {
          final sw = Stopwatch()..start();
          await Future.wait([
            audio.playVoice(pair[0]),
            audio.playVoice(pair[1]),
          ]).timeout(const Duration(seconds: 40));
          slowest[pair.join('+')] = sw.elapsedMilliseconds;
        }
        debugPrint('R1 slowest pair ms: $slowest');
        expect(issuesOf(failureOps), isEmpty);
        // Short pairs are ~1.4 s of audio; a 15 s timeout would show here.
        for (final pair in shortPairs) {
          expect(slowest[pair.join('+')], lessThan(5000));
        }
        expect(audio.isVoicePipelineActive, isFalse);
      });
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );

  testWidgets(
    'R2: interrupt storm - no crash, no stuck queue',
    (_) async {
      await capturing(() async {
        const files = [
          'voice_three.mp3',
          'voice_two.mp3',
          'voice_one.mp3',
          'voice_lets_fight.mp3',
          'voice_card_new.mp3',
        ];
        final spacing = [30, 55, 80, 40, 65];
        final futures = <Future<void>>[];
        for (var i = 0; i < 20; i++) {
          futures.add(
            audio.playVoice(files[i % files.length], interrupt: true),
          );
          await Future<void>.delayed(
            Duration(milliseconds: spacing[i % spacing.length]),
          );
        }
        const last = 'voice_go_brushing.mp3';
        final sw = Stopwatch()..start();
        futures.add(audio.playVoice(last, interrupt: true));
        await Future.wait(futures).timeout(const Duration(seconds: 20));
        final lastMs = sw.elapsedMilliseconds;
        debugPrint('R2 last voice done after ${lastMs}ms');
        expect(lastMs, lessThan(4000), reason: 'last voice must not stall');
        expect(audio.isVoicePipelineActive, isFalse);
        // Interrupted items are reported as voice_timeout (pre-existing
        // label for any externally ended item); the last one must not be.
        expect(
          issuesOf(failureOps).where((l) => l.contains('file=$last ')),
          isEmpty,
        );
        expect(issuesOf({'voice_play_failed'}), isEmpty);
        if (AudioService.traceEnabled) {
          expect(
            lines.any(
              (l) => l.contains('VOICE done $last completedNormally=true'),
            ),
            isTrue,
          );
        }
        // The process survived and still plays audio.
        await audio
            .playVoice('voice_awesome.mp3')
            .timeout(const Duration(seconds: 10));
        expect(
          issuesOf(failureOps).where((l) => l.contains('voice_awesome')),
          isEmpty,
        );
      });
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  testWidgets(
    'R3: 130 s music loop - no restart, position keeps moving',
    (_) async {
      expect(
        AudioService.traceEnabled,
        isTrue,
        reason: 'run with --dart-define=AUDIO_TRACE=true (R3 reads traces)',
      );
      await capturing(() async {
        await audio.playMusic('battle_music_loop.mp3');
        await audio.setMusicVolume(0.06);
        // BrushingScreen's 5 s health tick.
        final end = DateTime.now().add(const Duration(seconds: 130));
        while (DateTime.now().isBefore(end)) {
          await Future<void>.delayed(const Duration(seconds: 5));
          await audio.ensureMusicPlaying();
        }
        final starts = lines
            .where((l) => l.startsWith('[AUD] MUSIC play '))
            .toList();
        final states = [
          for (final l in lines)
            if (l.startsWith('[AUD] MUSIC health(iOS) state='))
              l.split('state=')[1].split(' ')[0],
        ];
        final positions = [
          for (final l in lines)
            if (l.startsWith('[AUD] MUSIC health(iOS) position='))
              int.tryParse(l.split('position=')[1].split(' ')[0]),
        ];
        debugPrint('R3 states: ${states.toSet()} positions(ms): $positions');
        expect(starts, hasLength(1), reason: 'music restarted: $starts');
        expect(
          issuesOf({'music_stall_restart', 'music_health_restart'}),
          isEmpty,
        );
        expect(states, isNotEmpty);
        expect(states.toSet(), {'PlayerState.playing'});
        expect(positions, everyElement(isNotNull));
        for (var i = 1; i < positions.length; i++) {
          expect(
            positions[i],
            isNot(positions[i - 1]),
            reason: 'position stalled at sample $i: $positions',
          );
        }
        final wrapped = [
          for (var i = 1; i < positions.length; i++)
            if (positions[i]! < positions[i - 1]!) i,
        ];
        expect(wrapped, hasLength(1), reason: 'expected one loop wrap');
        await audio.stopMusic();
      });
    },
    timeout: const Timeout(Duration(minutes: 4)),
  );

  testWidgets(
    'R4: countdown 3-2-1-GO voices all complete',
    (_) async {
      await capturing(() async {
        const countdown = [
          'voice_three.mp3',
          'voice_two.mp3',
          'voice_one.mp3',
          'voice_go_brushing.mp3',
        ];
        final futures = <Future<void>>[];
        for (final f in countdown) {
          unawaited(audio.playSfx('countdown_beep.mp3'));
          futures.add(audio.playVoice(f, clearQueue: true, interrupt: true));
          await Future<void>.delayed(const Duration(seconds: 1));
        }
        await Future.wait(futures).timeout(const Duration(seconds: 10));
        // Three/Two/One are each cut by the next tick BY DESIGN
        // (interrupt: true, 1 s apart), and an interrupted voice is still
        // reported as op=voice_timeout (pre-existing label). What matters to
        // the kid is that the spoken word finishes before the cut: speech ends
        // at <= 0.44 s in every countdown file (ffmpeg silencedetect, -40 dB);
        // the rest is trailing silence. So only non-interrupt failures count.
        expect(
          issuesOf(failureOps).where((l) => !l.contains('op=voice_timeout')),
          isEmpty,
        );
        if (AudioService.traceEnabled) {
          DateTime at(String l) => DateTime.parse(l.split('@').last.trim());
          final done = [
            for (final l in lines)
              if (l.startsWith('[AUD] VOICE done ')) l.split(' ')[3],
          ];
          debugPrint('R4 done order: $done');
          expect(done, countdown, reason: 'every countdown voice started');
          // GO is never interrupted: it must complete naturally, and its
          // start latency (done - play - 0.60 s file length) bounds the
          // latency of Three/Two/One. latency + 0.44 s speech < 1 s tick
          // means the audible word always finishes before the next tick.
          final goPlay = lines.lastWhere(
            (l) => l.startsWith('[AUD] VOICE play voice_go_brushing.mp3'),
          );
          final goDone = lines.lastWhere(
            (l) => l.startsWith('[AUD] VOICE done voice_go_brushing.mp3'),
          );
          expect(goDone, contains('completedNormally=true'));
          final latencyMs =
              at(goDone).difference(at(goPlay)).inMilliseconds - 601;
          debugPrint('R4 GO start latency ~${latencyMs}ms');
          expect(
            latencyMs,
            lessThan(1000 - 440),
            reason: 'spoken countdown word would be clipped by the next tick',
          );
        }
      });
    },
    timeout: const Timeout(Duration(minutes: 1)),
  );

  testWidgets(
    'R5: music start/stop churn never hangs',
    (_) async {
      await capturing(() async {
        for (var i = 0; i < 10; i++) {
          final starts = [
            audio.playMusic('battle_music_loop.mp3'),
            if (i.isEven) audio.playMusic('battle_music_loop.mp3'),
          ];
          await Future<void>.delayed(Duration(milliseconds: 40 * (i % 4)));
          await Future.wait(starts).timeout(const Duration(seconds: 10));
          await audio.stopMusic().timeout(const Duration(seconds: 5));
        }
        await audio
            .playMusic('battle_music_loop.mp3')
            .timeout(const Duration(seconds: 10));
        await Future<void>.delayed(const Duration(seconds: 2));
        expect(audio.isMusicPlaying, isTrue);
        await audio.stopMusic().timeout(const Duration(seconds: 5));
        expect(issuesOf({'music_play_failed', 'music_reset_failed'}), isEmpty);
      });
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

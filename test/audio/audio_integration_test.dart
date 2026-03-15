import 'package:flutter_test/flutter_test.dart';
import 'package:brush_quest/services/audio_service.dart';

import 'fake_audio_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeAudioService fake;

  setUp(() {
    fake = FakeAudioService();
    AudioService.testInstance = fake;
  });

  // No tearDown needed — each setUp replaces the singleton with a fresh fake.
  // Avoid setting testInstance = null as that creates a real AudioService
  // which requires platform plugins unavailable in unit tests.

  // ── Singleton injection ───────────────────────────────────────

  group('Singleton injection', () {
    test('AudioService() returns the injected fake instance', () {
      final instance = AudioService();
      expect(identical(instance, fake), isTrue);
    });

    // Note: testInstance = null creates a real AudioService._internal()
    // which requires platform channel plugins (AudioPlayer). That path
    // is only testable in integration tests on a real device, so we skip
    // it here and trust the singleton reset mechanism.
  });

  // ── Mute respects all channels ────────────────────────────────

  group('Mute respects all channels', () {
    test('playSfx records call when not muted', () async {
      await fake.playSfx('zap.mp3');
      expect(fake.callsFor('playSfx').length, 1);
      expect(fake.callsFor('playSfx').first.args['fileName'], 'zap.mp3');
    });

    test('playVoice records call when not muted', () async {
      await fake.playVoice('voice_welcome.mp3');
      expect(fake.callsFor('playVoice').length, 1);
    });

    test('playMusic records call when not muted', () async {
      await fake.playMusic('battle_music_loop.mp3');
      expect(fake.callsFor('playMusic').length, 1);
      expect(fake.isMusicPlaying, isTrue);
    });

    test('all channels no-op after muting', () async {
      await fake.toggleMute(); // now muted
      expect(fake.isMuted, isTrue);

      fake.clearCalls();

      await fake.playSfx('zap.mp3');
      await fake.playVoice('voice_welcome.mp3');
      await fake.playMusic('battle_music_loop.mp3');

      // Calls are still recorded (so we can verify they were attempted),
      // but the internal state should show nothing playing.
      expect(fake.isMusicPlaying, isFalse);
      expect(fake.isVoicePlaying, isFalse);
    });

    test('toggle mute twice restores unmuted state', () async {
      await fake.toggleMute(); // muted
      await fake.toggleMute(); // unmuted
      expect(fake.isMuted, isFalse);

      await fake.playMusic('battle_music_loop.mp3');
      expect(fake.isMusicPlaying, isTrue);
    });

    test('muting while voice queued clears the queue', () {
      fake.simulateQueueVoice('voice_a.mp3');
      fake.simulateQueueVoice('voice_b.mp3');
      expect(fake.voiceQueueLength, 2);

      fake.toggleMute(); // clears queue
      expect(fake.voiceQueueLength, 0);
    });
  });

  // ── Voice interrupt behavior ──────────────────────────────────

  group('Voice interrupt behavior', () {
    test('playVoice with interrupt:true records interrupt', () async {
      // Simulate a voice already playing.
      await fake.playVoice('voice_countdown.mp3');
      fake.clearCalls();

      // Now interrupt with a new voice.
      // To test the interrupt path, we need voice to be "playing".
      // The fake completes instantly, so we set the state manually.
      fake.calls.clear();
      // We call with interrupt — the fake records _voiceInterrupted only
      // when _voicePlaying is true at the moment of call. Since fake
      // completes instantly, let's verify the flag is passed through.
      await fake.playVoice('voice_top_left.mp3',
          clearQueue: true, interrupt: true);

      final voiceCall = fake.callsFor('playVoice').first;
      expect(voiceCall.args['interrupt'], isTrue);
      expect(voiceCall.args['clearQueue'], isTrue);
      expect(voiceCall.args['fileName'], 'voice_top_left.mp3');
    });

    test('playVoice without interrupt does not record interrupt', () async {
      await fake.playVoice('voice_welcome.mp3');

      final voiceCall = fake.callsFor('playVoice').first;
      expect(voiceCall.args['interrupt'], isFalse);
    });

    test('sequential voice calls are recorded in order', () async {
      await fake.playVoice('voice_countdown.mp3');
      await fake.playVoice('voice_top_left.mp3');
      await fake.playVoice('voice_top_right.mp3');

      final voiceCalls = fake.callsFor('playVoice');
      expect(voiceCalls.length, 3);
      expect(voiceCalls[0].args['fileName'], 'voice_countdown.mp3');
      expect(voiceCalls[1].args['fileName'], 'voice_top_left.mp3');
      expect(voiceCalls[2].args['fileName'], 'voice_top_right.mp3');
    });
  });

  // ── Voice clearQueue behavior ─────────────────────────────────

  group('Voice clearQueue behavior', () {
    test('clearQueue empties pending queue entries', () {
      fake.simulateQueueVoice('voice_a.mp3');
      fake.simulateQueueVoice('voice_b.mp3');
      fake.simulateQueueVoice('voice_c.mp3');
      expect(fake.voiceQueueLength, 3);

      fake.playVoice('voice_new.mp3', clearQueue: true);
      expect(fake.voiceQueueLength, 0);

      // Verify the queue-cleared event was recorded.
      final clearEvents = fake.callsFor('_voiceQueueCleared');
      expect(clearEvents.length, 1);
      expect(clearEvents.first.args['count'], 3);
    });

    test('clearQueue on empty queue is a no-op', () async {
      expect(fake.voiceQueueLength, 0);
      await fake.playVoice('voice_new.mp3', clearQueue: true);

      // No queue-cleared event since queue was already empty.
      expect(fake.callsFor('_voiceQueueCleared'), isEmpty);
    });
  });

  // ── Music ducking during voice ────────────────────────────────

  group('Music ducking during voice', () {
    test('music volume ducks when voice plays and restores after', () async {
      // Start music.
      await fake.playMusic('battle_music_loop.mp3');
      expect(fake.musicVolume, 0.18);
      expect(fake.isMusicPlaying, isTrue);

      fake.clearCalls();

      // Play a voice line — should duck and restore.
      await fake.playVoice('voice_welcome.mp3');

      final duckEvents = fake.callsFor('_musicDucked');
      final restoreEvents = fake.callsFor('_musicRestored');

      expect(duckEvents.length, 1);
      expect(duckEvents.first.args['volume'], 0.08);

      expect(restoreEvents.length, 1);
      expect(restoreEvents.first.args['volume'], 0.18);

      // Final volume should be restored.
      expect(fake.musicVolume, 0.18);
    });

    test('no ducking when no music is playing', () async {
      // No music started.
      expect(fake.isMusicPlaying, isFalse);

      await fake.playVoice('voice_welcome.mp3');

      expect(fake.callsFor('_musicDucked'), isEmpty);
      expect(fake.callsFor('_musicRestored'), isEmpty);
    });

    test('duck-restore sequence is correct across multiple voices', () async {
      await fake.playMusic('battle_music_loop.mp3');
      fake.clearCalls();

      await fake.playVoice('voice_top_left.mp3');
      await fake.playVoice('voice_top_right.mp3');

      final ducks = fake.callsFor('_musicDucked');
      final restores = fake.callsFor('_musicRestored');
      expect(ducks.length, 2);
      expect(restores.length, 2);

      // Verify interleaving: duck, restore, duck, restore.
      final allEvents = fake.calls
          .where((c) =>
              c.method == '_musicDucked' || c.method == '_musicRestored')
          .toList();
      expect(allEvents.length, 4);
      expect(allEvents[0].method, '_musicDucked');
      expect(allEvents[1].method, '_musicRestored');
      expect(allEvents[2].method, '_musicDucked');
      expect(allEvents[3].method, '_musicRestored');
    });

    test('no ducking after music is stopped', () async {
      await fake.playMusic('battle_music_loop.mp3');
      await fake.stopMusic();
      fake.clearCalls();

      await fake.playVoice('voice_welcome.mp3');

      expect(fake.callsFor('_musicDucked'), isEmpty);
    });
  });

  // ── Brushing session sequence ─────────────────────────────────

  group('Brushing session audio sequence', () {
    test('typical brushing flow records expected call sequence', () async {
      // Simulate what brushing_screen.dart does:
      // 1. Countdown voice
      await fake.playVoice('voice_countdown.mp3',
          clearQueue: true, interrupt: true);
      // 2. Countdown beeps
      await fake.playSfx('countdown_beep.mp3');
      await fake.playSfx('countdown_beep.mp3');
      // 3. Start battle music
      await fake.playMusic('battle_music_loop.mp3');
      // 4. Phase voice
      await fake.playVoice('voice_top_left.mp3');
      // 5. Hit sounds during brushing
      await fake.playSfx('zap.mp3');
      await fake.playSfx('whoosh.mp3');
      // 6. Encouragement
      await fake.playVoice('voice_keep_going.mp3');
      // 7. Monster defeat
      await fake.playSfx('monster_defeat.mp3');
      // 8. Phase transition
      await fake.playVoice('voice_top_right.mp3');
      // 9. End: stop music
      await fake.stopMusic();

      // Verify the sequence.
      final methods = fake.calls
          .where((c) => !c.method.startsWith('_'))
          .map((c) => c.method)
          .toList();

      expect(methods, [
        'playVoice', // countdown
        'playSfx', // beep
        'playSfx', // beep
        'playMusic', // battle music
        'playVoice', // phase voice
        'playSfx', // zap
        'playSfx', // whoosh
        'playVoice', // encouragement
        'playSfx', // monster defeat
        'playVoice', // phase transition
        'stopMusic', // end
      ]);
    });

    test('stopMusic at end clears music state', () async {
      await fake.playMusic('battle_music_loop.mp3');
      expect(fake.isMusicPlaying, isTrue);
      expect(fake.currentMusicFile, 'battle_music_loop.mp3');

      await fake.stopMusic();
      expect(fake.isMusicPlaying, isFalse);
      expect(fake.currentMusicFile, isNull);
    });
  });

  // ── Victory screen audio ──────────────────────────────────────

  group('Victory screen audio', () {
    test('victory sequence: sfx then voice', () async {
      // Simulates victory_screen.dart flow.
      await fake.playSfx('victory.mp3');
      await fake.playSfx('star_chime.mp3');
      await fake.playVoice('voice_great_job.mp3');

      final methods = fake.calls
          .where((c) => !c.method.startsWith('_'))
          .map((c) => c.method)
          .toList();

      expect(methods, ['playSfx', 'playSfx', 'playVoice']);
      expect(fake.callsFor('playSfx')[0].args['fileName'], 'victory.mp3');
      expect(fake.callsFor('playSfx')[1].args['fileName'], 'star_chime.mp3');
      expect(
          fake.callsFor('playVoice').first.args['fileName'], 'voice_great_job.mp3');
    });
  });

  // ── Music health check ────────────────────────────────────────

  group('Music health check', () {
    test('ensureMusicPlaying is recorded', () async {
      await fake.playMusic('battle_music_loop.mp3');
      fake.clearCalls();

      await fake.ensureMusicPlaying();
      expect(fake.callsFor('ensureMusicPlaying').length, 1);
    });
  });

  // ── setMusicVolume ────────────────────────────────────────────

  group('setMusicVolume', () {
    test('setMusicVolume updates internal volume when playing', () async {
      await fake.playMusic('battle_music_loop.mp3');
      expect(fake.musicVolume, 0.18);

      await fake.setMusicVolume(0.5);
      expect(fake.musicVolume, 0.5);
    });

    test('setMusicVolume no-ops when not playing', () async {
      await fake.setMusicVolume(0.5);
      expect(fake.musicVolume, 0.18); // unchanged default
    });
  });

  // ── encouragementVoices ───────────────────────────────────────

  group('encouragementVoices', () {
    test('returns a non-empty list', () {
      expect(fake.encouragementVoices, isNotEmpty);
    });

    test('all entries end with .mp3', () {
      for (final v in fake.encouragementVoices) {
        expect(v, endsWith('.mp3'));
      }
    });
  });

  // ── dispose ───────────────────────────────────────────────────

  group('dispose', () {
    test('dispose is recorded', () {
      fake.dispose();
      expect(fake.callsFor('dispose').length, 1);
    });
  });
}

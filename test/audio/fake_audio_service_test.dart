import 'package:flutter_test/flutter_test.dart';

import 'fake_audio_service.dart';

/// Pins the lifecycle/pause surface of [FakeAudioService]. Before these
/// overrides existed, calling `stopAllAudio()` (or pause/resume) on the fake
/// fell through to the real implementation and hit the never-assigned
/// `late final _voicePlayer` (LateInitializationError), so no widget test
/// could exercise BrushingScreen's app-lifecycle handling.
void main() {
  late FakeAudioService fake;

  setUp(() => fake = FakeAudioService());

  test('stopAllAudio is recorded and clears music playing', () async {
    await fake.playMusic('battle_music_loop.mp3');
    expect(fake.isMusicPlaying, isTrue);

    await fake.stopAllAudio();

    expect(fake.callsFor('stopAllAudio'), hasLength(1));
    expect(fake.isMusicPlaying, isFalse);
  });

  test('pauseMusic keeps music "playing" (player kept alive)', () async {
    await fake.playMusic('battle_music_loop.mp3');

    await fake.pauseMusic();
    expect(fake.callsFor('pauseMusic'), hasLength(1));
    expect(fake.isMusicPlaying, isTrue);
    expect(fake.isMusicPaused, isTrue);

    await fake.resumeMusic();
    expect(fake.callsFor('resumeMusic'), hasLength(1));
    expect(fake.isMusicPaused, isFalse);
    expect(fake.musicEvents, ['start', 'pause', 'resume']);
  });

  test(
    'lifecycle snapshot + resumeAfterWake restarts the same track',
    () async {
      await fake.playMusic('battle_music_loop.mp3');
      await fake.setMusicVolume(0.06);

      await fake.stopAllAudioForLifecycle();
      expect(fake.callsFor('stopAllAudioForLifecycle'), hasLength(1));
      expect(fake.callsFor('stopAllAudio'), hasLength(1));
      expect(fake.isMusicPlaying, isFalse);

      fake.clearCalls();
      await fake.resumeAfterWake();

      expect(fake.calls.map((c) => c.method).toList(), [
        'resumeAfterWake',
        'playMusic',
        'setMusicVolume',
      ]);
      expect(fake.currentMusicFile, 'battle_music_loop.mp3');
      expect(fake.musicVolume, 0.06);
    },
  );

  test('resumeAfterWake is a no-op when nothing was playing', () async {
    await fake.stopAllAudioForLifecycle();
    fake.clearCalls();

    await fake.resumeAfterWake();

    expect(fake.calls.map((c) => c.method).toList(), ['resumeAfterWake']);
    expect(fake.isMusicPlaying, isFalse);
  });
}

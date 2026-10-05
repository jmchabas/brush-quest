import 'package:flutter_test/flutter_test.dart';

import 'fake_audio_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // The helpers live on AudioService; the fake inherits them without
  // touching the audioplayers platform channels.
  final audio = FakeAudioService();
  test('stars-left clips 1..10, then "lots more"', () {
    expect(audio.starsLeftVoiceFor(1), 'voice_stars_left_1.mp3');
    expect(audio.starsLeftVoiceFor(10), 'voice_stars_left_10.mp3');
    expect(audio.starsLeftVoiceFor(11), 'voice_stars_left_many.mp3');
    expect(audio.starsLeftVoiceFor(35), 'voice_stars_left_many.mp3');
  });
  test('brushes-left clips are clamped to 1..10', () {
    expect(audio.brushesLeftVoiceFor(1), 'voice_brushes_left_1.mp3');
    expect(audio.brushesLeftVoiceFor(10), 'voice_brushes_left_10.mp3');
    expect(audio.brushesLeftVoiceFor(0), 'voice_brushes_left_1.mp3');
    expect(audio.brushesLeftVoiceFor(12), 'voice_brushes_left_10.mp3');
  });
}

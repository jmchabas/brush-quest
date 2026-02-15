import 'package:audioplayers/audioplayers.dart';

class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  final AudioPlayer _sfxPlayer = AudioPlayer();
  final AudioPlayer _voicePlayer = AudioPlayer();

  Future<void> playSfx(String fileName) async {
    await _sfxPlayer.stop();
    await _sfxPlayer.play(AssetSource('audio/$fileName'));
  }

  Future<void> playVoice(String fileName) async {
    await _voicePlayer.stop();
    await _voicePlayer.play(AssetSource('audio/$fileName'));
  }

  void dispose() {
    _sfxPlayer.dispose();
    _voicePlayer.dispose();
  }
}

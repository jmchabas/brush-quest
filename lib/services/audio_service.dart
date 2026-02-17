import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  final AudioPlayer _sfxPlayer = AudioPlayer();
  final AudioPlayer _voicePlayer = AudioPlayer();
  final AudioPlayer _musicPlayer = AudioPlayer();
  bool _muted = false;
  bool _voicePlaying = false;
  bool _musicPlaying = false;

  bool get isMuted => _muted;

  static const _allAudioFiles = [
    'countdown_beep.mp3',
    'monster_defeat.mp3',
    'victory.mp3',
    'voice_bottom_left.mp3',
    'voice_bottom_right.mp3',
    'voice_countdown.mp3',
    'voice_great_job.mp3',
    'voice_top_left.mp3',
    'voice_top_right.mp3',
    'voice_keep_going.mp3',
    'voice_youre_doing_great.mp3',
    'voice_almost_there.mp3',
    'whoosh.mp3',
    'zap.mp3',
    'voice_stars_unlock.mp3',
    'voice_star_collected.mp3',
    'battle_music.mp3',
  ];

  Future<void> preloadAll() async {
    // Load mute preference
    final prefs = await SharedPreferences.getInstance();
    _muted = prefs.getBool('muted') ?? false;

    // Pre-warm audio players by setting sources
    // audioplayers caches assets after first load
    for (final file in _allAudioFiles) {
      try {
        final player = AudioPlayer();
        await player.setSource(AssetSource('audio/$file'));
        player.dispose();
      } catch (_) {
        // File may not exist yet (e.g. new voice files)
      }
    }
  }

  Future<void> toggleMute() async {
    _muted = !_muted;
    if (_muted) {
      await _sfxPlayer.stop();
      await _voicePlayer.stop();
      await _musicPlayer.stop();
      _musicPlaying = false;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('muted', _muted);
  }

  Future<void> playSfx(String fileName) async {
    if (_muted) return;
    await _sfxPlayer.stop();
    await _sfxPlayer.play(AssetSource('audio/$fileName'));
  }

  Future<void> playVoice(String fileName) async {
    if (_muted) return;
    if (_voicePlaying) return; // Prevent overlap
    _voicePlaying = true;
    await _voicePlayer.stop();
    await _voicePlayer.play(AssetSource('audio/$fileName'));
    _voicePlayer.onPlayerComplete.first.then((_) {
      _voicePlaying = false;
    });
    // Safety timeout in case onPlayerComplete doesn't fire
    Future.delayed(const Duration(seconds: 5), () {
      _voicePlaying = false;
    });
  }

  Future<void> playMusic(String fileName) async {
    if (_muted) return;
    if (_musicPlaying) return;
    _musicPlaying = true;
    await _musicPlayer.setReleaseMode(ReleaseMode.loop);
    await _musicPlayer.setVolume(0.4);
    try {
      await _musicPlayer.play(AssetSource('audio/$fileName'));
    } catch (_) {
      // Music file may not exist
      _musicPlaying = false;
    }
  }

  Future<void> stopMusic() async {
    _musicPlaying = false;
    await _musicPlayer.stop();
  }

  void dispose() {
    _sfxPlayer.dispose();
    _voicePlayer.dispose();
    _musicPlayer.dispose();
  }
}

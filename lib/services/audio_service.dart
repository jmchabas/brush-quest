import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal() {
    for (int i = 0; i < _sfxPoolSize; i++) {
      _sfxPool.add(AudioPlayer());
    }
  }

  static const _sfxPoolSize = 5;
  final List<AudioPlayer> _sfxPool = [];
  int _sfxIndex = 0;

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
    'star_chime.mp3',
    'battle_music_v2.mp3',
  ];

  Future<void> preloadAll() async {
    final prefs = await SharedPreferences.getInstance();
    _muted = prefs.getBool('muted') ?? false;

    for (final file in _allAudioFiles) {
      try {
        final player = AudioPlayer();
        await player.setSource(AssetSource('audio/$file'));
        player.dispose();
      } catch (_) {}
    }
  }

  Future<void> toggleMute() async {
    _muted = !_muted;
    if (_muted) {
      for (final p in _sfxPool) {
        await p.stop();
      }
      await _voicePlayer.stop();
      await _musicPlayer.stop();
      _musicPlaying = false;
      _voicePlaying = false;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('muted', _muted);
  }

  Future<void> playSfx(String fileName) async {
    if (_muted) return;
    final player = _sfxPool[_sfxIndex % _sfxPoolSize];
    _sfxIndex++;
    try {
      await player.stop();
      await player.setVolume(0.8);
      await player.play(AssetSource('audio/$fileName'));
    } catch (_) {}
  }

  Future<void> playVoice(String fileName) async {
    if (_muted) return;
    if (_voicePlaying) return;
    _voicePlaying = true;

    if (_musicPlaying) {
      try { await _musicPlayer.setVolume(0.15); } catch (_) {}
    }

    try {
      await _voicePlayer.stop();
      await _voicePlayer.setVolume(1.0);
      await _voicePlayer.play(AssetSource('audio/$fileName'));
      await Future.any([
        _voicePlayer.onPlayerComplete.first,
        Future.delayed(const Duration(seconds: 5)),
      ]);
    } catch (_) {
    } finally {
      _voicePlaying = false;
      if (_musicPlaying) {
        try { await _musicPlayer.setVolume(0.5); } catch (_) {}
      }
    }
  }

  Future<void> playMusic(String fileName) async {
    if (_muted) return;
    if (_musicPlaying) return;
    _musicPlaying = true;
    try {
      await _musicPlayer.setReleaseMode(ReleaseMode.loop);
      await _musicPlayer.setVolume(0.5);
      await _musicPlayer.play(AssetSource('audio/$fileName'));
    } catch (_) {
      _musicPlaying = false;
    }
  }

  Future<void> stopMusic() async {
    _musicPlaying = false;
    try { await _musicPlayer.stop(); } catch (_) {}
  }

  void dispose() {
    for (final p in _sfxPool) {
      p.dispose();
    }
    _voicePlayer.dispose();
    _musicPlayer.dispose();
  }
}

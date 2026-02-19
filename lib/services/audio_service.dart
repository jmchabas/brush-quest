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

  static const _sfxPoolSize = 3;
  final List<AudioPlayer> _sfxPool = [];
  int _sfxIndex = 0;

  final AudioPlayer _voicePlayer = AudioPlayer();
  AudioPlayer _musicPlayer = AudioPlayer();
  bool _muted = false;
  bool _voicePlaying = false;
  bool _musicPlaying = false;

  bool get isMuted => _muted;
  bool get isVoicePlaying => _voicePlaying;

  static const _hitSounds = ['zap.mp3', 'whoosh.mp3'];

  static const _encouragementVoices = [
    'voice_keep_going.mp3',
    'voice_youre_doing_great.mp3',
    'voice_almost_there.mp3',
    'voice_nice_combo.mp3',
    'voice_keep_it_up.mp3',
    'voice_so_strong.mp3',
    'voice_super.mp3',
    'voice_go_go_go.mp3',
    'voice_awesome.mp3',
    'voice_wow_amazing.mp3',
    'voice_unstoppable.mp3',
  ];

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
    'voice_nice_combo.mp3',
    'voice_keep_it_up.mp3',
    'voice_so_strong.mp3',
    'voice_super.mp3',
    'voice_go_go_go.mp3',
    'voice_awesome.mp3',
    'voice_wow_amazing.mp3',
    'voice_unstoppable.mp3',
    'voice_stars_unlock.mp3',
    'whoosh.mp3',
    'zap.mp3',
    'star_chime.mp3',
    'battle_music_loop.mp3',
  ];

  List<String> get encouragementVoices => List.unmodifiable(_encouragementVoices);

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
        try { await p.stop(); } catch (_) {}
      }
      try { await _voicePlayer.stop(); } catch (_) {}
      try { await _musicPlayer.stop(); } catch (_) {}
      _musicPlaying = false;
      _voicePlaying = false;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('muted', _muted);
  }

  Future<void> playSfx(String fileName) async {
    if (_muted || _voicePlaying) return;
    final player = _sfxPool[_sfxIndex % _sfxPoolSize];
    _sfxIndex++;
    try {
      await player.setVolume(0.7);
      await player.play(AssetSource('audio/$fileName'));
    } catch (_) {}
  }

  String nextHitSound() {
    return _hitSounds[_sfxIndex % _hitSounds.length];
  }

  Future<void> playVoice(String fileName) async {
    if (_muted) return;
    if (_voicePlaying) return;
    _voicePlaying = true;

    if (_musicPlaying) {
      try { await _musicPlayer.setVolume(0.12); } catch (_) {}
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

  /// Start looping background music using a fresh player and the 2-minute
  /// pre-concatenated loop file so Android doesn't need to handle short-file looping.
  Future<void> playMusic(String fileName) async {
    if (_muted) return;
    try {
      await _musicPlayer.stop();
      _musicPlayer.dispose();
    } catch (_) {}
    try {
      _musicPlayer = AudioPlayer();
      _musicPlaying = true;
      await _musicPlayer.setSource(AssetSource('audio/$fileName'));
      await _musicPlayer.setReleaseMode(ReleaseMode.loop);
      await _musicPlayer.setVolume(0.5);
      await _musicPlayer.resume();
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

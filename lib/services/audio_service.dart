import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Kept for API compatibility with callers — internally simplified.
enum VoicePolicy { queue, skipIfBusy, interrupt }
enum VoicePriority { low, encouragement, guidance, critical }

class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  // Single SFX player — the original working architecture.
  // A 3-player pool caused audio contention on Android that silenced the
  // voice player mid-playback.
  final AudioPlayer _sfxPlayer = AudioPlayer();
  final AudioPlayer _voicePlayer = AudioPlayer();
  AudioPlayer _musicPlayer = AudioPlayer();

  bool _muted = false;
  bool _voicePlaying = false;
  int _voiceGeneration = 0; // prevents stale safety timeouts
  bool _musicPlaying = false;
  String? _currentMusicFile;

  static const double _musicVolume = 0.18;
  static const double _musicDuckedVolume = 0.08;

  static const int _maxDebugTrace = 120;
  static const String _audioTraceKey = 'audio_debug_trace';
  final List<String> _debugTrace = [];
  int _tracePersistCounter = 0;

  bool get isMuted => _muted;
  bool get isVoicePlaying => _voicePlaying;

  static const _hitSounds = ['zap.mp3', 'whoosh.mp3'];
  int _hitIndex = 0;

  static const _encouragementVoices = [
    'voice_keep_going.mp3',
    'voice_youre_doing_great.mp3',
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
    'voice_welcome.mp3',
    'voice_welcome_back.mp3',
    'voice_hero_blaze.mp3',
    'voice_hero_frost.mp3',
    'voice_hero_bolt.mp3',
    'voice_hero_shadow.mp3',
    'voice_hero_leaf.mp3',
    'voice_hero_nova.mp3',
    'voice_great_choice.mp3',
    'voice_great_job_tonight.mp3',
    'voice_great_job_morning.mp3',
    'voice_you_did_it.mp3',
    'voice_victory_star_and_chest.wav',
    'voice_see_you_soon.wav',
    'voice_lets_fight.mp3',
    'voice_chest_wow.mp3',
    'voice_chest_dance.mp3',
    'voice_chest_bonus_star.mp3',
    'voice_chest_double.mp3',
    'voice_chest_jackpot.mp3',
    'voice_open_chest.mp3',
    'whoosh.mp3',
    'zap.mp3',
    'star_chime.mp3',
    'battle_music_loop.mp3',
  ];

  List<String> get encouragementVoices =>
      List.unmodifiable(_encouragementVoices);

  Future<List<String>> getDebugTrace() async {
    if (_debugTrace.isNotEmpty) return List.unmodifiable(_debugTrace);
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_audioTraceKey) ?? const [];
  }

  Future<void> clearDebugTrace() async {
    _debugTrace.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_audioTraceKey);
  }

  Future<void> preloadAll() async {
    final prefs = await SharedPreferences.getInstance();
    _muted = prefs.getBool('muted') ?? false;

    for (final file in _allAudioFiles) {
      final player = AudioPlayer();
      try {
        await player
            .setSource(AssetSource('audio/$file'))
            .timeout(const Duration(milliseconds: 350));
      } catch (_) {}
      player.dispose();
    }
  }

  Future<void> toggleMute() async {
    _muted = !_muted;
    if (_muted) {
      try { await _sfxPlayer.stop(); } catch (_) {}
      try { await _voicePlayer.stop(); } catch (_) {}
      try { await _musicPlayer.stop(); } catch (_) {}
      _musicPlaying = false;
      _voicePlaying = false;
      _voiceGeneration++;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('muted', _muted);
  }

  /// Play a sound effect. Single player — stop + play each time.
  /// Suppresses SFX while a voice is playing to prevent Android audio
  /// contention (MediaPlayer focus fights kill the voice mid-playback).
  Future<void> playSfx(
    String fileName, {
    bool allowDuringVoice = false,
    double volume = 0.7,
  }) async {
    if (_muted) return;
    if (_voicePlaying && !allowDuringVoice) {
      _trace('sfx_suppressed:$fileName (voice playing)');
      return;
    }
    try {
      await _sfxPlayer.stop();
      await _sfxPlayer.setVolume(volume);
      await _sfxPlayer.play(AssetSource('audio/$fileName'));
      _trace('sfx_play:$fileName');
    } catch (_) {}
  }

  String nextHitSound() {
    final sound = _hitSounds[_hitIndex % _hitSounds.length];
    _hitIndex++;
    return sound;
  }

  /// Fire-and-forget voice playback.
  ///
  /// If a voice is already playing:
  /// - `interrupt` policy: stop current and play new
  /// - `skipIfBusy` / `queue` policy: skip silently
  ///
  /// Priority and policy params are accepted for API compatibility.
  /// Internally, only `interrupt` vs skip matters.
  Future<void> playVoice(
    String fileName, {
    VoicePolicy policy = VoicePolicy.queue,
    VoicePriority priority = VoicePriority.low,
  }) async {
    if (_muted) return;

    _trace('voice_req:$fileName pol=${policy.name} busy=$_voicePlaying');

    if (_voicePlaying) {
      if (policy == VoicePolicy.interrupt) {
        _trace('voice_interrupt:$fileName');
        try { await _voicePlayer.stop(); } catch (_) {}
        _voicePlaying = false;
      } else {
        _trace('voice_skip:$fileName');
        return;
      }
    }

    final gen = ++_voiceGeneration;
    _voicePlaying = true;
    _trace('voice_start:$fileName gen=$gen');

    // Duck music while voice plays
    try { await _musicPlayer.setVolume(_musicDuckedVolume); } catch (_) {}

    try {
      await _voicePlayer.stop();
      await _voicePlayer.setVolume(1.0);
      await _voicePlayer.play(AssetSource('audio/$fileName'));
    } catch (_) {
      _trace('voice_error:$fileName');
      if (_voiceGeneration == gen) {
        _voicePlaying = false;
        _restoreMusicVolume();
      }
      return;
    }

    // Non-blocking completion detection
    _voicePlayer.onPlayerComplete.first.then((_) {
      if (_voiceGeneration == gen) {
        _trace('voice_complete:$fileName gen=$gen');
        _voicePlaying = false;
        _restoreMusicVolume();
      }
    });

    // Safety timeout — only resets if this is still the active voice
    Future.delayed(const Duration(seconds: 5), () {
      if (_voiceGeneration == gen && _voicePlaying) {
        _trace('voice_safety_timeout:$fileName gen=$gen');
        _voicePlaying = false;
        _restoreMusicVolume();
      }
    });
  }

  void _restoreMusicVolume() {
    if (!_musicPlaying) return;
    try { _musicPlayer.setVolume(_musicVolume); } catch (_) {}
  }

  Future<void> playMusic(String fileName) async {
    if (_muted) return;
    _currentMusicFile = fileName;
    try {
      await _musicPlayer.stop();
      _musicPlayer.dispose();
    } catch (_) {}
    try {
      _musicPlayer = AudioPlayer();
      _musicPlaying = true;
      await _musicPlayer.setSource(AssetSource('audio/$fileName'));
      await _musicPlayer.setReleaseMode(ReleaseMode.loop);
      await _musicPlayer.setVolume(_musicVolume);
      await _musicPlayer.resume();
    } catch (_) {
      _musicPlaying = false;
    }
  }

  Future<void> ensureMusicPlaying() async {
    if (_muted || !_musicPlaying || _currentMusicFile == null) return;
    try {
      final state = _musicPlayer.state;
      if (state == PlayerState.paused) {
        await _musicPlayer.resume();
        return;
      }
      if (state != PlayerState.playing) {
        await playMusic(_currentMusicFile!);
      }
    } catch (_) {
      await playMusic(_currentMusicFile!);
    }
  }

  Future<void> stopMusic() async {
    _musicPlaying = false;
    _currentMusicFile = null;
    try { await _musicPlayer.stop(); } catch (_) {}
  }

  void dispose() {
    _sfxPlayer.dispose();
    _voicePlayer.dispose();
    _musicPlayer.dispose();
  }

  void _trace(String message) {
    final now = DateTime.now();
    final ts =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}.${(now.millisecond ~/ 10).toString().padLeft(2, '0')}';
    _debugTrace.add('$ts|$message');
    if (_debugTrace.length > _maxDebugTrace) {
      _debugTrace.removeRange(0, _debugTrace.length - _maxDebugTrace);
    }
    _tracePersistCounter++;
    if (_tracePersistCounter % 6 != 0) return;
    unawaited(_persistTrace());
  }

  Future<void> _persistTrace() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_audioTraceKey, List.unmodifiable(_debugTrace));
    } catch (_) {}
  }
}

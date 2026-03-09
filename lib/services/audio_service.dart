import 'dart:async';
import 'dart:collection';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'telemetry_service.dart';

class _QueuedVoiceRequest {
  final String fileName;
  final Completer<void> completer = Completer<void>();
  _QueuedVoiceRequest(this.fileName);
}

// Kept for API compatibility with callers — internally simplified.
enum VoicePolicy { queue, skipIfBusy, interrupt }
enum VoicePriority { low, encouragement, guidance, critical }

class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  static const int _sfxPoolSize = 3;
  final List<AudioPlayer> _sfxPool = List.generate(
    _sfxPoolSize,
    (_) => AudioPlayer(),
  );
  int _sfxIndex = 0;
  final AudioPlayer _voicePlayer = AudioPlayer();
  AudioPlayer _musicPlayer = AudioPlayer();

  bool _muted = false;
  bool _voicePlaying = false;
  int _voiceGeneration = 0; // prevents stale safety timeouts
  bool _voiceQueueProcessing = false;
  Completer<void>? _interruptSignal; // signals the pump to abort current wait
  bool _musicPlaying = false;
  String? _currentMusicFile;
  final Queue<_QueuedVoiceRequest> _voiceQueue = Queue<_QueuedVoiceRequest>();
  final ValueNotifier<bool> voicePipelineActiveNotifier = ValueNotifier<bool>(
    false,
  );
  final Map<String, DateTime> _audioIssueDebounce = {};
  static const double _musicVolume = 0.18;
  static const double _musicDuckedVolume = 0.08;

  static const int _maxDebugTrace = 120;
  static const String _audioTraceKey = 'audio_debug_trace';
  final List<String> _debugTrace = [];
  int _tracePersistCounter = 0;

  bool get isMuted => _muted;
  bool get isVoicePlaying => _voicePlaying;
  bool get isVoicePipelineActive => voicePipelineActiveNotifier.value;

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

  static const Map<String, String> heroPickerVoices = {
    'blaze': 'voice_picker_hero_blaze.mp3',
    'frost': 'voice_picker_hero_frost.mp3',
    'bolt': 'voice_picker_hero_bolt.mp3',
    'shadow': 'voice_picker_hero_shadow.mp3',
    'leaf': 'voice_picker_hero_leaf.mp3',
    'nova': 'voice_picker_hero_nova.mp3',
  };

  static const Map<String, String> weaponPickerVoices = {
    'star_blaster': 'voice_picker_weapon_star_blaster.mp3',
    'flame_sword': 'voice_picker_weapon_flame_sword.mp3',
    'ice_hammer': 'voice_picker_weapon_ice_hammer.mp3',
    'lightning_wand': 'voice_picker_weapon_lightning_wand.mp3',
    'vine_whip': 'voice_picker_weapon_vine_whip.mp3',
    'cosmic_burst': 'voice_picker_weapon_cosmic_burst.mp3',
  };

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
    'voice_picker_hero_blaze.mp3',
    'voice_picker_hero_frost.mp3',
    'voice_picker_hero_bolt.mp3',
    'voice_picker_hero_shadow.mp3',
    'voice_picker_hero_leaf.mp3',
    'voice_picker_hero_nova.mp3',
    'voice_picker_weapon_star_blaster.mp3',
    'voice_picker_weapon_flame_sword.mp3',
    'voice_picker_weapon_ice_hammer.mp3',
    'voice_picker_weapon_lightning_wand.mp3',
    'voice_picker_weapon_vine_whip.mp3',
    'voice_picker_weapon_cosmic_burst.mp3',
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

  String heroPickerVoiceFor(String heroId) {
    return heroPickerVoices[heroId] ?? 'voice_great_choice.mp3';
  }

  String weaponPickerVoiceFor(String weaponId) {
    return weaponPickerVoices[weaponId] ?? 'voice_awesome.mp3';
  }

  Future<void> preloadAll() async {
    final prefs = await SharedPreferences.getInstance();
    _muted = prefs.getBool('muted') ?? false;
    int failures = 0;

    for (final file in _allAudioFiles) {
      final player = AudioPlayer();
      try {
        await player
            .setSource(AssetSource('audio/$file'))
            .timeout(const Duration(milliseconds: 350));
      } catch (_) {
        failures++;
      }
      player.dispose();
    }
    if (failures > 0) {
      _reportAudioIssue(
        operation: 'preload_partial',
        error: 'failed_files_$failures',
      );
    }
  }

  Future<void> toggleMute() async {
    _muted = !_muted;
    if (_muted) {
      _clearVoiceQueue();
      _voiceGeneration++;
      // Signal the pump to abort its current wait so it exits cleanly
      final sig = _interruptSignal;
      if (sig != null && !sig.isCompleted) sig.complete();
      for (final p in _sfxPool) {
        try {
          await p.stop();
        } catch (_) {}
      }
      try {
        await _voicePlayer.stop();
      } catch (e) {
        _reportAudioIssue(operation: 'mute_stop_voice_failed', error: e);
      }
      try {
        await _musicPlayer.stop();
      } catch (e) {
        _reportAudioIssue(operation: 'mute_stop_music_failed', error: e);
      }
      _musicPlaying = false;
      _voicePlaying = false;
      _updateVoicePipelineState();
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('muted', _muted);
  }

  Future<void> playSfx(String fileName) async {
    if (_muted) return;
    final player = _sfxPool[_sfxIndex % _sfxPoolSize];
    _sfxIndex++;
    try {
      // Keep SFX audible during narrator lines, but quieter while voice plays.
      await player.setVolume(_voicePlaying ? 0.24 : 0.7);
      await player.play(AssetSource('audio/$fileName'));
      _trace('sfx_play:$fileName');
    } catch (e) {
      _reportAudioIssue(
        operation: 'sfx_play_failed',
        fileName: fileName,
        error: e,
      );
    }
  }

  String nextHitSound() {
    final sound = _hitSounds[_hitIndex % _hitSounds.length];
    _hitIndex++;
    return sound;
  }

  Future<void> playVoice(
    String fileName, {
    bool clearQueue = false,
    bool interrupt = false,
  }) async {
    if (_muted) return;
    _trace('voice_req:$fileName clearQueue=$clearQueue interrupt=$interrupt');
    if (clearQueue) {
      _clearVoiceQueue();
    }
    if (interrupt && _voiceQueueProcessing) {
      // Signal the pump loop to abort its current Future.any wait,
      // then stop the player. Without this signal, _voicePlayer.stop()
      // does NOT fire onPlayerComplete, so the pump would hang for up to
      // 5 seconds on its safety timeout before processing the next voice.
      final oldSignal = _interruptSignal;
      if (oldSignal != null && !oldSignal.isCompleted) {
        oldSignal.complete();
      }
      try {
        await _voicePlayer.stop();
      } catch (e) {
        _reportAudioIssue(
          operation: 'voice_interrupt_stop_failed',
          fileName: fileName,
          error: e,
        );
      }
      _voicePlaying = false;
    } else if (interrupt) {
      // Pump not running — just stop the player
      try {
        await _voicePlayer.stop();
      } catch (e) {
        _reportAudioIssue(
          operation: 'voice_interrupt_stop_failed',
          fileName: fileName,
          error: e,
        );
      }
      _voicePlaying = false;
    }

    final request = _QueuedVoiceRequest(fileName);
    _voiceQueue.add(request);
    _updateVoicePipelineState();
    unawaited(_pumpVoiceQueue());
    await request.completer.future;
  }

  Future<void> _pumpVoiceQueue() async {
    if (_voiceQueueProcessing) return;
    _voiceQueueProcessing = true;
    try {
      while (!_muted && _voiceQueue.isNotEmpty) {
        final request = _voiceQueue.removeFirst();
        final gen = ++_voiceGeneration;
        _voicePlaying = true;
        _updateVoicePipelineState();
        try {
          await _musicPlayer.setVolume(_musicDuckedVolume);
        } catch (_) {}

        try {
          // Create a fresh interrupt signal for this voice
          _interruptSignal = Completer<void>();
          final myInterrupt = _interruptSignal!;

          await _voicePlayer.stop();
          await _voicePlayer.setVolume(1.0);
          await _voicePlayer.play(AssetSource('audio/${request.fileName}'));
          _trace('voice_start:${request.fileName} gen=$gen');

          // Wait for: natural completion, 5s safety timeout, or interrupt signal
          final result = await Future.any<String>([
            _voicePlayer.onPlayerComplete.first.then((_) => 'complete'),
            Future.delayed(const Duration(seconds: 5), () => 'timeout'),
            myInterrupt.future.then((_) => 'interrupted'),
          ]);
          if (result == 'timeout') {
            _trace('voice_timeout:${request.fileName} gen=$gen');
            _reportAudioIssue(
              operation: 'voice_timeout',
              fileName: request.fileName,
            );
          } else if (result == 'interrupted') {
            _trace('voice_interrupted:${request.fileName} gen=$gen');
          } else {
            _trace('voice_complete:${request.fileName} gen=$gen');
          }
        } catch (e) {
          _trace('voice_error:${request.fileName} gen=$gen');
          _reportAudioIssue(
            operation: 'voice_play_failed',
            fileName: request.fileName,
            error: e,
          );
        } finally {
          _voicePlaying = false;
          _restoreMusicVolume();
          if (!request.completer.isCompleted) {
            request.completer.complete();
          }
          _updateVoicePipelineState();
        }
      }
    } finally {
      _voiceQueueProcessing = false;
      _voicePlaying = false;
      _updateVoicePipelineState();
    }
  }

  void _clearVoiceQueue() {
    while (_voiceQueue.isNotEmpty) {
      final request = _voiceQueue.removeFirst();
      if (!request.completer.isCompleted) {
        request.completer.complete();
      }
    }
  }

  void _updateVoicePipelineState() {
    final active = _voicePlaying || _voiceQueue.isNotEmpty;
    if (voicePipelineActiveNotifier.value != active) {
      voicePipelineActiveNotifier.value = active;
    }
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
    } catch (e) {
      _reportAudioIssue(
        operation: 'music_reset_failed',
        fileName: fileName,
        error: e,
      );
    }
    try {
      _musicPlayer = AudioPlayer();
      _musicPlaying = true;
      await _musicPlayer.setSource(AssetSource('audio/$fileName'));
      await _musicPlayer.setReleaseMode(ReleaseMode.loop);
      await _musicPlayer.setVolume(_musicVolume);
      await _musicPlayer.resume();
    } catch (e) {
      _musicPlaying = false;
      _reportAudioIssue(
        operation: 'music_play_failed',
        fileName: fileName,
        error: e,
      );
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
    } catch (e) {
      _reportAudioIssue(
        operation: 'music_health_restart',
        fileName: _currentMusicFile,
        error: e,
      );
      await playMusic(_currentMusicFile!);
    }
  }

  Future<void> stopMusic() async {
    _musicPlaying = false;
    _currentMusicFile = null;
    try {
      await _musicPlayer.stop();
    } catch (e) {
      _reportAudioIssue(operation: 'music_stop_failed', error: e);
    }
  }

  void _reportAudioIssue({
    required String operation,
    String? fileName,
    Object? error,
  }) {
    final key = '$operation|${fileName ?? 'none'}|${error.runtimeType}';
    final now = DateTime.now();
    final last = _audioIssueDebounce[key];
    if (last != null && now.difference(last) < const Duration(seconds: 15)) {
      return;
    }
    _audioIssueDebounce[key] = now;
    debugPrint(
      'audio issue: op=$operation file=${fileName ?? 'n/a'} err=${error ?? 'none'}',
    );
    unawaited(
      TelemetryService().logEvent(
        'audio_issue',
        params: {
          'op': operation,
          'file': fileName ?? 'none',
          'err': error?.runtimeType.toString() ?? 'unknown',
        },
      ),
    );
  }

  void dispose() {
    for (final p in _sfxPool) {
      p.dispose();
    }
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

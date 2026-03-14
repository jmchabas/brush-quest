import 'dart:async';
import 'dart:collection';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _QueuedVoiceRequest {
  final String fileName;
  final Completer<void> completer = Completer<void>();
  _QueuedVoiceRequest(this.fileName);
}

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
  bool _voiceQueueProcessing = false;
  bool _musicPlaying = false;
  bool _musicTransitioning = false;
  String? _currentMusicFile;
  final Queue<_QueuedVoiceRequest> _voiceQueue = Queue<_QueuedVoiceRequest>();
  final ValueNotifier<bool> voicePipelineActiveNotifier = ValueNotifier<bool>(
    false,
  );
  final Map<String, DateTime> _audioIssueDebounce = {};
  static const double _musicVolume = 0.18;
  static const double _musicDuckedVolume = 0.08;

  bool get isMuted => _muted;
  bool get isVoicePlaying => _voicePlaying;
  bool get isVoicePipelineActive => voicePipelineActiveNotifier.value;

  static const _hitSounds = ['zap.mp3', 'whoosh.mp3'];

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

  static const Map<String, String> heroIntroVoices = {
    'blaze': 'voice_intro_hero_blaze.mp3',
    'frost': 'voice_intro_hero_frost.mp3',
    'bolt': 'voice_intro_hero_bolt.mp3',
    'shadow': 'voice_intro_hero_shadow.mp3',
    'leaf': 'voice_intro_hero_leaf.mp3',
    'nova': 'voice_intro_hero_nova.mp3',
  };

  static const Map<String, String> weaponPickerVoices = {
    'star_blaster': 'voice_picker_weapon_star_blaster.mp3',
    'flame_sword': 'voice_picker_weapon_flame_sword.mp3',
    'ice_hammer': 'voice_picker_weapon_ice_hammer.mp3',
    'lightning_wand': 'voice_picker_weapon_lightning_wand.mp3',
    'vine_whip': 'voice_picker_weapon_vine_whip.mp3',
    'cosmic_burst': 'voice_picker_weapon_cosmic_burst.mp3',
  };

  static const Map<String, String> weaponIntroVoices = {
    'star_blaster': 'voice_intro_weapon_star_blaster.mp3',
    'flame_sword': 'voice_intro_weapon_flame_sword.mp3',
    'ice_hammer': 'voice_intro_weapon_ice_hammer.mp3',
    'lightning_wand': 'voice_intro_weapon_lightning_wand.mp3',
    'vine_whip': 'voice_intro_weapon_vine_whip.mp3',
    'cosmic_burst': 'voice_intro_weapon_cosmic_burst.mp3',
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
    'voice_great_job_tonight.mp3',
    'voice_great_job_morning.mp3',
    'voice_you_did_it.mp3',
    'voice_great_choice.mp3',
    'voice_lets_fight.mp3',
    'voice_chest_wow.mp3',
    'voice_chest_dance.mp3',
    'voice_chest_bonus_star.mp3',
    'voice_chest_double.mp3',
    'voice_chest_jackpot.mp3',
    'voice_open_chest.mp3',
    'voice_intro_hero_blaze.mp3',
    'voice_intro_hero_frost.mp3',
    'voice_intro_hero_bolt.mp3',
    'voice_intro_hero_shadow.mp3',
    'voice_intro_hero_leaf.mp3',
    'voice_intro_hero_nova.mp3',
    'voice_intro_weapon_star_blaster.mp3',
    'voice_intro_weapon_flame_sword.mp3',
    'voice_intro_weapon_ice_hammer.mp3',
    'voice_intro_weapon_lightning_wand.mp3',
    'voice_intro_weapon_vine_whip.mp3',
    'voice_intro_weapon_cosmic_burst.mp3',
    'whoosh.mp3',
    'zap.mp3',
    'star_chime.mp3',
    'battle_music_loop.mp3',
    'voice_card_new.mp3',
    'voice_card_fragment.mp3',
    'voice_daily_login.mp3',
    'voice_onboarding_1.mp3',
    'voice_onboarding_2.mp3',
    'voice_onboarding_3.mp3',
    'voice_entry_hero_shop.mp3',
    'voice_entry_world_map.mp3',
    'voice_entry_card_album.mp3',
    'voice_entry_settings.mp3',
    'voice_need_stars.mp3',
    'voice_earned_star.mp3',
    'voice_tomorrow_preview.mp3',
    'voice_fragments_ready.mp3',
    'voice_card_mystery.mp3',
    'voice_fragment_explain.mp3',
    // Per-world description voices
    'voice_world_candy_crater.mp3',
    'voice_world_slime_swamp.mp3',
    'voice_world_sugar_volcano.mp3',
    'voice_world_shadow_nebula.mp3',
    'voice_world_cavity_fortress.mp3',
    'voice_world_frozen_tundra.mp3',
    'voice_world_toxic_jungle.mp3',
    'voice_world_crystal_cave.mp3',
    'voice_world_storm_citadel.mp3',
    'voice_world_dark_dimension.mp3',
    // Monster card voice-overs (World 1: Candy Crater)
    'voice_card_cc_01.mp3',
    'voice_card_cc_02.mp3',
    'voice_card_cc_03.mp3',
    'voice_card_cc_04.mp3',
    'voice_card_cc_05.mp3',
    'voice_card_cc_06.mp3',
    'voice_card_cc_07.mp3',
    // World 2: Slime Swamp
    'voice_card_ss_01.mp3',
    'voice_card_ss_02.mp3',
    'voice_card_ss_03.mp3',
    'voice_card_ss_04.mp3',
    'voice_card_ss_05.mp3',
    'voice_card_ss_06.mp3',
    'voice_card_ss_07.mp3',
    // World 3: Sugar Volcano
    'voice_card_sv_01.mp3',
    'voice_card_sv_02.mp3',
    'voice_card_sv_03.mp3',
    'voice_card_sv_04.mp3',
    'voice_card_sv_05.mp3',
    'voice_card_sv_06.mp3',
    'voice_card_sv_07.mp3',
    // World 4: Shadow Nebula
    'voice_card_sn_01.mp3',
    'voice_card_sn_02.mp3',
    'voice_card_sn_03.mp3',
    'voice_card_sn_04.mp3',
    'voice_card_sn_05.mp3',
    'voice_card_sn_06.mp3',
    'voice_card_sn_07.mp3',
    // World 5: Cavity Fortress
    'voice_card_cf_01.mp3',
    'voice_card_cf_02.mp3',
    'voice_card_cf_03.mp3',
    'voice_card_cf_04.mp3',
    'voice_card_cf_05.mp3',
    'voice_card_cf_06.mp3',
    'voice_card_cf_07.mp3',
    // World 6: Frozen Tundra
    'voice_card_ft_01.mp3',
    'voice_card_ft_02.mp3',
    'voice_card_ft_03.mp3',
    'voice_card_ft_04.mp3',
    'voice_card_ft_05.mp3',
    'voice_card_ft_06.mp3',
    'voice_card_ft_07.mp3',
    // World 7: Toxic Jungle
    'voice_card_tj_01.mp3',
    'voice_card_tj_02.mp3',
    'voice_card_tj_03.mp3',
    'voice_card_tj_04.mp3',
    'voice_card_tj_05.mp3',
    'voice_card_tj_06.mp3',
    'voice_card_tj_07.mp3',
    // World 8: Crystal Cave
    'voice_card_cr_01.mp3',
    'voice_card_cr_02.mp3',
    'voice_card_cr_03.mp3',
    'voice_card_cr_04.mp3',
    'voice_card_cr_05.mp3',
    'voice_card_cr_06.mp3',
    'voice_card_cr_07.mp3',
    // World 9: Storm Citadel
    'voice_card_sc_01.mp3',
    'voice_card_sc_02.mp3',
    'voice_card_sc_03.mp3',
    'voice_card_sc_04.mp3',
    'voice_card_sc_05.mp3',
    'voice_card_sc_06.mp3',
    'voice_card_sc_07.mp3',
    // World 10: Dark Dimension
    'voice_card_dd_01.mp3',
    'voice_card_dd_02.mp3',
    'voice_card_dd_03.mp3',
    'voice_card_dd_04.mp3',
    'voice_card_dd_05.mp3',
    'voice_card_dd_06.mp3',
    'voice_card_dd_07.mp3',
  ];

  List<String> get encouragementVoices =>
      List.unmodifiable(_encouragementVoices);

  String heroPickerVoiceFor(String heroId) {
    return heroPickerVoices[heroId] ?? 'voice_great_choice.mp3';
  }

  String weaponPickerVoiceFor(String weaponId) {
    return weaponPickerVoices[weaponId] ?? 'voice_awesome.mp3';
  }

  String heroIntroVoiceFor(String heroId) {
    return heroIntroVoices[heroId] ?? heroPickerVoiceFor(heroId);
  }

  String weaponIntroVoiceFor(String weaponId) {
    return weaponIntroVoices[weaponId] ?? weaponPickerVoiceFor(weaponId);
  }

  Future<void> preloadAll() async {
    // Disable Android audio focus for all players so they can play
    // simultaneously without stealing focus from each other.
    // We manage volume ducking manually instead.
    await AudioPlayer.global.setAudioContext(
      AudioContext(
        android: const AudioContextAndroid(
          audioFocus: AndroidAudioFocus.none,
        ),
      ),
    );

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
      if (!_musicTransitioning) {
        try {
          await _musicPlayer.stop();
        } catch (e) {
          _reportAudioIssue(operation: 'mute_stop_music_failed', error: e);
        }
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
    } catch (e) {
      _reportAudioIssue(
        operation: 'sfx_play_failed',
        fileName: fileName,
        error: e,
      );
    }
  }

  String nextHitSound() {
    return _hitSounds[_sfxIndex % _hitSounds.length];
  }

  Future<void> playVoice(
    String fileName, {
    bool clearQueue = false,
    bool interrupt = false,
  }) async {
    if (_muted) return;
    if (clearQueue) {
      _clearVoiceQueue();
    }
    if (interrupt) {
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
        _voicePlaying = true;
        _updateVoicePipelineState();
        if (!_musicTransitioning) {
          try {
            await _musicPlayer.setVolume(_musicDuckedVolume);
          } catch (_) {}
        }

        try {
          await _voicePlayer.stop();
          await _voicePlayer.setVolume(1.0);
          await _voicePlayer.play(AssetSource('audio/${request.fileName}'));
          final completed = await Future.any<bool>([
            _voicePlayer.onPlayerComplete.first.then((_) => true),
            Future.delayed(const Duration(seconds: 5), () => false),
          ]);
          if (!completed) {
            _reportAudioIssue(
              operation: 'voice_timeout',
              fileName: request.fileName,
            );
          }
        } catch (e) {
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
    if (!_musicPlaying || _musicTransitioning) return;
    try {
      _musicPlayer.setVolume(_musicVolume);
    } catch (_) {}
  }

  Future<void> playMusic(String fileName) async {
    if (_muted) return;
    _currentMusicFile = fileName;
    _musicTransitioning = true;
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
      _musicTransitioning = false;
    } catch (e) {
      _musicTransitioning = false;
      _musicPlaying = false;
      _reportAudioIssue(
        operation: 'music_play_failed',
        fileName: fileName,
        error: e,
      );
    }
  }

  /// Call periodically during brushing to recover music if it stopped.
  /// Checks the player state and restarts if needed.
  Future<void> ensureMusicPlaying() async {
    if (_musicTransitioning) return;
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

  Future<void> setMusicVolume(double volume) async {
    if (_musicTransitioning || !_musicPlaying) return;
    try {
      await _musicPlayer.setVolume(volume.clamp(0.0, 1.0));
    } catch (_) {}
  }

  Future<void> stopMusic() async {
    if (_musicTransitioning) return;
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
  }

  void dispose() {
    for (final p in _sfxPool) {
      p.dispose();
    }
    _voicePlayer.dispose();
    _musicPlayer.dispose();
  }
}

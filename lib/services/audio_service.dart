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
  static AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;

  /// Replace the singleton for testing. Pass null to restore the default.
  @visibleForTesting
  static AudioService get testInstance => _instance;

  @visibleForTesting
  static set testInstance(AudioService? instance) {
    _instance = instance ?? AudioService._internal();
  }

  AudioService._internal() {
    _voicePlayer = AudioPlayer();
    _musicPlayer = AudioPlayer();
    for (int i = 0; i < _sfxPoolSize; i++) {
      _sfxPool.add(AudioPlayer());
    }
  }

  /// Protected constructor for subclasses (e.g. FakeAudioService in tests).
  @visibleForTesting
  AudioService.forTesting();

  static const _sfxPoolSize = 3;
  final List<AudioPlayer> _sfxPool = [];
  int _sfxIndex = 0;

  late final AudioPlayer _voicePlayer;
  late AudioPlayer _musicPlayer;
  bool _muted = false;
  bool _voicePlaying = false;
  bool _voiceQueueProcessing = false;
  bool _musicPlaying = false;
  bool _musicTransitioning = false;
  String? _currentMusicFile;
  String _voiceStyle = 'buddy';
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

  /// Available voice styles.
  static const voiceStyles = {'buddy': 'George — friendly guide'};

  /// Current voice narrator style ('classic', 'buddy', or 'boy').
  String get voiceStyle => _voiceStyle;

  /// Base path for voice files under assets/audio/.
  String get voiceBasePath => 'voices/$_voiceStyle';

  /// Voice style is locked to 'buddy' for launch.
  Future<void> setVoiceStyle(String style) async {
    // Locked to buddy for v1 launch — other styles remain on disk.
  }

  /// Returns the asset path for a voice file, routing through the active
  /// voice style subdirectory.  Non-voice files (SFX, music) should NOT
  /// use this — they live directly under audio/.
  String _voiceAssetPath(String fileName) {
    return 'audio/voices/$_voiceStyle/$fileName';
  }

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
  ];

  static const Map<String, String> heroPickerVoices = {
    'blaze': 'voice_picker_hero_blaze.mp3',
    'frost': 'voice_picker_hero_frost.mp3',
    'bolt': 'voice_picker_hero_bolt.mp3',
    'shadow': 'voice_picker_hero_shadow.mp3',
    'leaf': 'voice_picker_hero_leaf.mp3',
    'nova': 'voice_picker_hero_nova.mp3',
  };

  static const Map<String, String> evolutionPickerVoices = {
    'blaze_stage2': 'voice_picker_evo_blaze_stage2.mp3',
    'blaze_stage3': 'voice_picker_evo_blaze_stage3.mp3',
    'frost_stage2': 'voice_picker_evo_frost_stage2.mp3',
    'frost_stage3': 'voice_picker_evo_frost_stage3.mp3',
    'bolt_stage2': 'voice_picker_evo_bolt_stage2.mp3',
    'bolt_stage3': 'voice_picker_evo_bolt_stage3.mp3',
    'shadow_stage2': 'voice_picker_evo_shadow_stage2.mp3',
    'shadow_stage3': 'voice_picker_evo_shadow_stage3.mp3',
    'leaf_stage2': 'voice_picker_evo_leaf_stage2.mp3',
    'leaf_stage3': 'voice_picker_evo_leaf_stage3.mp3',
    'nova_stage2': 'voice_picker_evo_nova_stage2.mp3',
    'nova_stage3': 'voice_picker_evo_nova_stage3.mp3',
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

  // Core audio files that are NOT already listed in named const lists above.
  // Named lists (_encouragementVoices, heroPickerVoices, evolutionPickerVoices,
  // weaponPickerVoices, heroIntroVoices, weaponIntroVoices) are merged in at
  // preload time via _allPreloadFiles to avoid duplication.
  static const _audioFilesCore = [
    'countdown_beep.mp3',
    'monster_defeat.mp3',
    'victory.mp3',
    'voice_bottom_front.mp3',
    'voice_bottom_left.mp3',
    'voice_bottom_right.mp3',
    'voice_countdown.mp3',
    'voice_top_front.mp3',
    'voice_top_left.mp3',
    'voice_top_right.mp3',
    'voice_welcome_back.mp3',
    'voice_lets_fight.mp3',
    'voice_chest_wow.mp3',
    'voice_chest_dance_v2.mp3',
    'voice_chest_bonus_star.mp3',
    'voice_chest_double.mp3',
    'voice_chest_jackpot.mp3',
    // Bonus communication voice lines
    'voice_full_charge.mp3',
    'voice_super_power.mp3',
    'voice_mega_power.mp3',
    // Streak teach voices (shorter replacements for old explain voices)
    'voice_streak_teach_high.mp3',
    'voice_streak_teach_high_pair.mp3',
    'voice_streak_teach_low.mp3',
    'voice_streak_teach_low_pair.mp3',
    // Comeback greeting voices (fresh start / streak breaker)
    'voice_greet_comeback_1.mp3',
    'voice_greet_comeback_2.mp3',
    'voice_greet_comeback_3.mp3',
    'voice_great_choice.mp3',
    'whoosh.mp3',
    'zap.mp3',
    'star_chime.mp3',
    'battle_music_loop.mp3',
    'voice_card_new.mp3',
    'voice_card_album_intro.mp3',
    'voice_world_map_intro.mp3',
    'voice_greet_just_started_1.mp3',
    'voice_greet_just_started_2.mp3',
    'voice_greet_just_started_3.mp3',
    'voice_greet_streak_low_1.mp3',
    'voice_greet_streak_low_2.mp3',
    'voice_greet_streak_mid_1.mp3',
    'voice_greet_streak_mid_2.mp3',
    'voice_greet_streak_high_1.mp3',
    'voice_greet_streak_high_2.mp3',
    'voice_greet_streak_legend_1.mp3',
    'voice_greet_streak_legend_2.mp3',
    'voice_greet_returning_1.mp3',
    'voice_greet_returning_2.mp3',
    'voice_greet_returning_excited_1.mp3',
    'voice_greet_returning_excited_2.mp3',
    'voice_onboarding_1.mp3',
    'voice_onboarding_2.mp3',
    'voice_onboarding_3.mp3',
    'voice_need_stars.mp3',
    'voice_world_complete.mp3',
    'voice_tab_heroes.mp3',
    'voice_tab_weapons.mp3',
    'voice_greet_fresh_start.mp3',
    'voice_card_mystery.mp3',
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
    // Monster card voice-overs (5 per world — World 1: Candy Crater)
    'voice_card_cc_01.mp3',
    'voice_card_cc_02.mp3',
    'voice_card_cc_03.mp3',
    'voice_card_cc_04.mp3',
    'voice_card_cc_05.mp3',
    // World 2: Slime Swamp
    'voice_card_ss_01.mp3',
    'voice_card_ss_02.mp3',
    'voice_card_ss_03.mp3',
    'voice_card_ss_04.mp3',
    'voice_card_ss_05.mp3',
    // World 3: Sugar Volcano
    'voice_card_sv_01.mp3',
    'voice_card_sv_02.mp3',
    'voice_card_sv_03.mp3',
    'voice_card_sv_04.mp3',
    'voice_card_sv_05.mp3',
    // World 4: Shadow Nebula
    'voice_card_sn_01.mp3',
    'voice_card_sn_02.mp3',
    'voice_card_sn_03.mp3',
    'voice_card_sn_04.mp3',
    'voice_card_sn_05.mp3',
    // World 5: Cavity Fortress
    'voice_card_cf_01.mp3',
    'voice_card_cf_02.mp3',
    'voice_card_cf_03.mp3',
    'voice_card_cf_04.mp3',
    'voice_card_cf_05.mp3',
    // World 6: Frozen Tundra
    'voice_card_ft_01.mp3',
    'voice_card_ft_02.mp3',
    'voice_card_ft_03.mp3',
    'voice_card_ft_04.mp3',
    'voice_card_ft_05.mp3',
    // World 7: Toxic Jungle
    'voice_card_tj_01.mp3',
    'voice_card_tj_02.mp3',
    'voice_card_tj_03.mp3',
    'voice_card_tj_04.mp3',
    'voice_card_tj_05.mp3',
    // World 8: Crystal Cave
    'voice_card_cc2_01.mp3',
    'voice_card_cc2_02.mp3',
    'voice_card_cc2_03.mp3',
    'voice_card_cc2_04.mp3',
    'voice_card_cc2_05.mp3',
    // World 9: Storm Citadel
    'voice_card_sc_01.mp3',
    'voice_card_sc_02.mp3',
    'voice_card_sc_03.mp3',
    'voice_card_sc_04.mp3',
    'voice_card_sc_05.mp3',
    // World 10: Dark Dimension
    'voice_card_dd_01.mp3',
    'voice_card_dd_02.mp3',
    'voice_card_dd_03.mp3',
    'voice_card_dd_04.mp3',
    'voice_card_dd_05.mp3',
    // Encouragement arc voice lines (10 arcs x 3 beats)
    'voice_arc1_beat1.mp3',
    'voice_arc1_beat2.mp3',
    'voice_arc1_beat3.mp3',
    'voice_arc2_beat1.mp3',
    'voice_arc2_beat2.mp3',
    'voice_arc2_beat3.mp3',
    'voice_arc3_beat1.mp3',
    'voice_arc3_beat2.mp3',
    'voice_arc3_beat3.mp3',
    'voice_arc4_beat1.mp3',
    'voice_arc4_beat2.mp3',
    'voice_arc4_beat3.mp3',
    'voice_arc5_beat1.mp3',
    'voice_arc5_beat2.mp3',
    'voice_arc5_beat3.mp3',
    'voice_arc6_beat1.mp3',
    'voice_arc6_beat2.mp3',
    'voice_arc6_beat3.mp3',
    'voice_arc7_beat1.mp3',
    'voice_arc7_beat2.mp3',
    'voice_arc7_beat3.mp3',
    'voice_arc8_beat1.mp3',
    'voice_arc8_beat2.mp3',
    'voice_arc8_beat3.mp3',
    'voice_arc9_beat1.mp3',
    'voice_arc9_beat2.mp3',
    'voice_arc9_beat3.mp3',
    'voice_arc10_beat1.mp3',
    'voice_arc10_beat2.mp3',
    'voice_arc10_beat3.mp3',
    // Victory celebration arc voice lines (8 arcs x 3 beats)
    'voice_victory_arc1_beat1.mp3',
    'voice_victory_arc1_beat2.mp3',
    'voice_victory_arc1_beat3.mp3',
    'voice_victory_arc2_beat1.mp3',
    'voice_victory_arc2_beat2.mp3',
    'voice_victory_arc2_beat3.mp3',
    'voice_victory_arc3_beat1.mp3',
    'voice_victory_arc3_beat2.mp3',
    'voice_victory_arc3_beat3.mp3',
    'voice_victory_arc4_beat1.mp3',
    'voice_victory_arc4_beat2.mp3',
    'voice_victory_arc4_beat3.mp3',
    'voice_victory_arc5_beat1.mp3',
    'voice_victory_arc5_beat2.mp3',
    'voice_victory_arc5_beat3.mp3',
    'voice_victory_arc6_beat1.mp3',
    'voice_victory_arc6_beat2.mp3',
    'voice_victory_arc6_beat3.mp3',
    'voice_victory_arc7_beat1.mp3',
    'voice_victory_arc7_beat2.mp3',
    'voice_victory_arc7_beat3.mp3',
    'voice_victory_arc8_beat1.mp3',
    'voice_victory_arc8_beat2.mp3',
    'voice_victory_arc8_beat3.mp3',
    // Post-chest encouragement variants
    'voice_chest_encourage_1.mp3',
    'voice_chest_encourage_2.mp3',
    'voice_chest_encourage_3.mp3',
    // Milestones and special voices
    'voice_tap_hero.mp3',
    'voice_card_power_up.mp3',
    'voice_milestone_70.mp3',
    'voice_milestone_80.mp3',
    'voice_milestone_90.mp3',
    'voice_legend.mp3',
    // Streak & comeback voice lines (Cycle 9)
    'voice_first_streak_3.mp3',
    'voice_first_streak_7.mp3',
    'voice_first_daily_pair.mp3',
    'voice_first_comeback.mp3',
    'voice_chest_mega_streak.mp3',
    'voice_chest_streak_bonus.mp3',
    'voice_chest_daily_pair.mp3',
    'voice_chest_comeback.mp3',
    'voice_shop_nudge_default.mp3',
    'voice_shop_nudge_streak3.mp3',
    'voice_shop_nudge_streak7.mp3',
    'voice_shop_nudge_tonight.mp3',
    'voice_entry_hero_hq.mp3',
    'voice_camera_prompt.mp3',
    // Forward hook voices (session-end encouragement)
    'voice_forward_tonight.mp3',
    'voice_forward_morning.mp3',
    'voice_full_power.mp3',
  ];

  /// Complete list of files to preload, built once from core list + named
  /// const lists so each file appears exactly once.
  static List<String> get _allPreloadFiles => [
    ..._audioFilesCore,
    ..._encouragementVoices,
    ...heroPickerVoices.values,
    ...evolutionPickerVoices.values,
    ...weaponPickerVoices.values,
    ...heroIntroVoices.values,
    ...weaponIntroVoices.values,
  ];

  List<String> get encouragementVoices =>
      List.unmodifiable(_encouragementVoices);

  String heroPickerVoiceFor(String heroId) {
    return heroPickerVoices[heroId] ?? 'voice_great_choice.mp3';
  }

  String evolutionPickerVoiceFor(String heroId, int stage) {
    if (stage <= 1) return heroPickerVoiceFor(heroId);
    final key = '${heroId}_stage$stage';
    return evolutionPickerVoices[key] ?? heroPickerVoiceFor(heroId);
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
        android: const AudioContextAndroid(audioFocus: AndroidAudioFocus.none),
      ),
    );

    final prefs = await SharedPreferences.getInstance();
    _muted = prefs.getBool('muted') ?? false;
    _voiceStyle = 'buddy';
    int failures = 0;

    for (final file in _allPreloadFiles) {
      final player = AudioPlayer();
      final isVoice = file.startsWith('voice_');
      final assetPath = isVoice ? _voiceAssetPath(file) : 'audio/$file';
      try {
        await player
            .setSource(AssetSource(assetPath))
            .timeout(const Duration(milliseconds: 350));
      } on Exception catch (_) {
        failures++;
      }
      unawaited(player.dispose());
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
        } on Exception catch (_) {}
      }
      try {
        await _voicePlayer.stop();
      } on Exception catch (e) {
        _reportAudioIssue(operation: 'mute_stop_voice_failed', error: e);
      }
      if (!_musicTransitioning) {
        try {
          await _musicPlayer.stop();
        } on Exception catch (e) {
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
    } on Exception catch (e) {
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

    // Add request to queue BEFORE any await, so sequential calls
    // preserve their order even when interrupt yields to the event loop.
    final request = _QueuedVoiceRequest(fileName);
    _voiceQueue.add(request);
    _updateVoicePipelineState();

    if (interrupt) {
      try {
        await _voicePlayer.stop();
      } on Exception catch (e) {
        _reportAudioIssue(
          operation: 'voice_interrupt_stop_failed',
          fileName: fileName,
          error: e,
        );
      }
      _voicePlaying = false;
    }

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
          } on Exception catch (_) {}
        }

        try {
          await _voicePlayer.stop();
          await _voicePlayer.setVolume(1.0);
          await _voicePlayer.play(
            AssetSource(_voiceAssetPath(request.fileName)),
          );
          final completed = await Future.any<bool>([
            _voicePlayer.onPlayerComplete.first.then((_) => true),
            _voicePlayer.onPlayerStateChanged
                .where((s) => s == PlayerState.stopped)
                .first
                .then((_) => false),
            Future.delayed(const Duration(seconds: 15), () => false),
          ]);
          if (!completed) {
            _reportAudioIssue(
              operation: 'voice_timeout',
              fileName: request.fileName,
            );
          }
        } on Exception catch (e) {
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

  /// Stop any currently playing voice and clear the voice queue.
  /// Call this before screen transitions to prevent orphaned voice playback.
  Future<void> stopVoice() async {
    _clearVoiceQueue();
    _voicePlaying = false;
    _updateVoicePipelineState();
    try {
      await _voicePlayer.stop();
    } on Exception catch (e) {
      _reportAudioIssue(operation: 'stop_voice_failed', error: e);
    }
    _restoreMusicVolume();
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
    } on Exception catch (_) {}
  }

  Future<void> playMusic(String fileName) async {
    if (_muted) return;
    _currentMusicFile = fileName;
    _musicTransitioning = true;
    try {
      await _musicPlayer.stop();
      unawaited(_musicPlayer.dispose());
    } on Exception catch (e) {
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
    } on Exception catch (e) {
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
    } on Exception catch (e) {
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
    } on Exception catch (_) {}
  }

  /// Pause music playback (keeps player state so it can resume).
  Future<void> pauseMusic() async {
    if (_musicTransitioning || !_musicPlaying) return;
    try {
      await _musicPlayer.pause();
    } on Exception catch (e) {
      _reportAudioIssue(operation: 'music_pause_failed', error: e);
    }
  }

  /// Resume music after a pause. Does nothing if music was not playing.
  Future<void> resumeMusic() async {
    if (_musicTransitioning || !_musicPlaying || _muted) return;
    try {
      final vol = _voicePlaying ? _musicDuckedVolume : _musicVolume;
      await _musicPlayer.setVolume(vol);
      await _musicPlayer.resume();
    } on Exception catch (e) {
      _reportAudioIssue(operation: 'music_resume_failed', error: e);
    }
  }

  Future<void> stopMusic() async {
    if (_musicTransitioning) return;
    _musicPlaying = false;
    _currentMusicFile = null;
    try {
      await _musicPlayer.stop();
    } on Exception catch (e) {
      _reportAudioIssue(operation: 'music_stop_failed', error: e);
    }
  }

  /// Stop ALL audio: music, voice, and SFX. Used for app lifecycle events.
  Future<void> stopAllAudio() async {
    _clearVoiceQueue();
    _voicePlaying = false;
    _updateVoicePipelineState();
    try {
      await _voicePlayer.stop();
    } on Exception catch (_) {}
    for (final p in _sfxPool) {
      try {
        await p.stop();
      } on Exception catch (_) {}
    }
    if (!_musicTransitioning) {
      try {
        await _musicPlayer.stop();
      } on Exception catch (_) {}
    }
    _musicPlaying = false;
  }

  /// Whether music was actively playing (for lifecycle save/restore).
  bool get isMusicPlaying => _musicPlaying;

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

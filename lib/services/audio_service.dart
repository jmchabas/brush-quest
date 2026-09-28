import 'dart:async';
import 'dart:collection';
import 'dart:io' show Platform;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show MethodCall, MethodChannel;
import 'package:shared_preferences/shared_preferences.dart';

/// How an iOS voice start attempt ended (see AudioService._iosStartVoice).
enum _VoiceStart { started, stopped, timedOut }

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
    if (!isIOS) {
      // Android crash fix — Crashlytics v28 #1: OutOfMemoryError
      // "pthread_create failed" thrown from MediaPlayer.setSubtitleAnchor.
      // With the default ReleaseMode.release, audioplayers_android releases
      // the native MediaPlayer when a sound completes, so the NEXT play() on
      // that player builds a brand-new android.media.MediaPlayer, and every
      // new MediaPlayer starts (and joins, on the main thread) a
      // "SetSubtitleAnchorThread" on its first MEDIA_PREPARED. That is one
      // thread start per SFX, several per second while brushing.
      // ReleaseMode.stop keeps each pool player's MediaPlayer (paused at 0)
      // and reuses it via reset(), which keeps its SubtitleController, so no
      // new thread is started. Music keeps its own ReleaseMode.loop (see
      // playMusic). iOS is deliberately untouched.
      for (final player in _sfxPool) {
        unawaited(
          player.setReleaseMode(ReleaseMode.stop).catchError((Object _) {}),
        );
      }
    }
  }

  /// Protected constructor for subclasses (e.g. FakeAudioService in tests).
  @visibleForTesting
  AudioService.forTesting();

  /// Host-test override for [isIOS]. Tests set it to exercise the iOS
  /// branches on macOS (where Platform.isIOS is false) and reset it to null
  /// in tearDown. NEVER assign it from lib/ (audio_regression_test guards).
  @visibleForTesting
  static bool? debugIsIOSOverride;

  /// Gate for every iOS-only audio behaviour. Production reads
  /// [Platform.isIOS], the same as main.dart's lifecycle check. Android
  /// (the shipped v28 baseline) must never enter an `isIOS` branch; the
  /// Android call-sequence golden (test/audio/android_audio_golden_test.dart)
  /// pins that.
  static bool get isIOS => debugIsIOSOverride ?? Platform.isIOS;

  /// Host-test override for the clock the iOS music watchdog reads (FakeAsync
  /// does not fake DateTime.now()). NEVER assign it from lib/.
  @visibleForTesting
  static DateTime Function()? debugNowOverride;

  static DateTime _now() => debugNowOverride?.call() ?? DateTime.now();

  /// Verbose audio tracing, compiled in only with
  /// `--dart-define=AUDIO_TRACE=true` (device diagnosis builds). It is a
  /// const, so a normal build drops every guarded statement. Rule: every
  /// trace statement sits inside an `if (traceEnabled)` / `if (_trace)`
  /// block, including any work done only for the trace (e.g. an awaited
  /// getCurrentPosition) - never build trace arguments outside the guard.
  static const bool traceEnabled = bool.fromEnvironment('AUDIO_TRACE');
  static const bool _trace = traceEnabled;

  /// Print one trace line. Call only under `if (AudioService.traceEnabled)`.
  static void trace(String message) =>
      debugPrint('$message @${DateTime.now().toIso8601String()}');

  static void _t(String message) => trace('[AUD] $message');

  static const _sfxPoolSize = 3;
  final List<AudioPlayer> _sfxPool = [];
  int _sfxIndex = 0;

  late final AudioPlayer _voicePlayer;
  late AudioPlayer _musicPlayer;
  bool _muted = false;
  bool _voicePlaying = false;
  bool _voiceQueueProcessing = false;
  // Per-item external-stop signal for the voice pump. The pump creates a fresh
  // Completer before each play() and races it in Future.any. stopVoice() and
  // playVoice(interrupt:) complete it so a genuine external stop recovers
  // instantly (no 15s wait). This REPLACES the old Android onPlayerStateChanged
  // (PlayerState.stopped) listener, which could not tell a real external stop
  // from the transient `stopped` blip emitted during a normal source-swap when
  // the queue advances — that false-positive cut every queued voice that
  // followed another (v25 trophy-voice-not-played + voice-cut bugs).
  Completer<void>? _activeVoiceStop;
  // iOS only: the voice-player stop() issued by the latest stopVoice() /
  // playVoice(interrupt:), until it completes. The pump awaits it before
  // deciding whether a pre-play stop() is needed, because AudioPlayer.state
  // only flips to `stopped` after the native reply (reading it early would
  // send a second stop right behind the interrupt's).
  Future<void>? _iosVoiceStopInFlight;
  bool _musicPlaying = false;
  bool _musicTransitioning = false;
  String? _currentMusicFile;
  // Snapshot of what music to restore after an app-lifecycle pause (phone
  // sleep, backgrounding). stopAllAudio clears _musicPlaying, so we capture
  // the file + volume BEFORE stopping and replay them on resume.
  String? _musicFileBeforePause;
  double? _musicVolumeBeforePause;
  // iOS only: a screen paused the music on purpose (the brushing PAUSE
  // overlay, incl. its auto-pause on 'inactive'). While held, resumeAfterWake
  // must not restart the track under the overlay; it parks the snapshot in
  // _iosWakeDeferred* and the next resumeMusic() (the kid's RESUME tap)
  // restarts it instead. Cleared by resumeMusic/playMusic/stopMusic so it
  // can't go stale. Never written on Android.
  bool _iosMusicHeld = false;
  String? _iosWakeDeferredFile;
  double? _iosWakeDeferredVolume;
  // iOS only: playMusic starts run one at a time. _iosMusicTurn is the tail
  // of that chain; _iosMusicGeneration is bumped by every playMusic and
  // stopMusic so a start still waiting its turn is dropped once a newer
  // request exists (see _iosTakeMusicTurn).
  Future<void>? _iosMusicTurn;
  int _iosMusicGeneration = 0;
  // iOS only: music position watchdog (see _iosEnsureMusicPlaying). The
  // last position sampled on _iosWatchPlayer and when it was first seen.
  AudioPlayer? _iosWatchPlayer;
  int? _iosWatchPositionMs;
  DateTime? _iosWatchSince;
  bool _iosWatchBusy = false;
  static const _iosMusicStallLimit = Duration(seconds: 6);
  String _voiceStyle = 'buddy';
  final Queue<_QueuedVoiceRequest> _voiceQueue = Queue<_QueuedVoiceRequest>();
  final ValueNotifier<bool> voicePipelineActiveNotifier = ValueNotifier<bool>(
    false,
  );
  final Map<String, DateTime> _audioIssueDebounce = {};
  static const double _musicVolume = 0.18;
  static const double _musicDuckedVolume = 0.08;

  /// Active music target volume. Tracks the most recent caller-set level
  /// (via [setMusicVolume] or the default in [playMusic]) so ducking can
  /// restore to the correct per-screen ambient level instead of clobbering
  /// it with a hardcoded constant.
  double _musicTargetVolume = _musicVolume;

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

  /// Pool of voices played when the kid taps a locked item (hero card,
  /// locked trophy, locked world chip). C15 T3-33: rotating a pool instead of
  /// hammering `voice_keep_going.mp3` every tap keeps the experience fresh
  /// when a kid rapidly taps several locked cells in a row.
  static const _lockedTapVoices = [
    'voice_keep_going.mp3',
    'voice_locked_soon.mp3',
    'voice_locked_save_stars.mp3',
  ];
  DateTime? _lastLockedTapAt;
  int _lockedTapIndex = 0;

  /// Play a locked-tap nudge, cycling through [_lockedTapVoices]. Debounced
  /// at 2s — if the kid taps 4 locked items in a row, they hear 1 voice
  /// followed by 3 quiet taps, not an overlapping wall of sound.
  void playLockedTapVoice() {
    final now = DateTime.now();
    if (_lastLockedTapAt != null &&
        now.difference(_lastLockedTapAt!) < const Duration(seconds: 2)) {
      return;
    }
    _lastLockedTapAt = now;
    final file = _lockedTapVoices[_lockedTapIndex];
    _lockedTapIndex = (_lockedTapIndex + 1) % _lockedTapVoices.length;
    playVoice(file, clearQueue: true, interrupt: true);
  }

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
    // C15 T3-30 home-return pool (dedicated greetings, not exertion reruns)
    'voice_home_return_1.mp3',
    'voice_home_return_2.mp3',
    'voice_home_return_3.mp3',
    'voice_home_return_4.mp3',
    'voice_locked_soon.mp3',
    'voice_locked_save_stars.mp3',
    'voice_go_brushing.mp3',
    // C16 SS2: per-tick countdown voices aligned to the beep cadence —
    // replaces the silent beeps-only countdown shipped in v19. Kids (and
    // Oliver's retest) expect to hear someone count.
    'voice_three.mp3',
    'voice_two.mp3',
    'voice_one.mp3',
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
      final sourceFuture = player.setSource(AssetSource(assetPath));
      try {
        await sourceFuture.timeout(const Duration(milliseconds: 350));
      } on Object catch (_) {
        // Catches TimeoutException and StateError from a late firstWhere
        // on a closed event stream after the timeout + dispose race.
        failures++;
      }
      // Swallow any late result/error from setSource so disposing the
      // player mid-flight doesn't surface an unhandled StateError.
      sourceFuture.ignore();
      unawaited(player.dispose().catchError((Object _) {}));
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
    if (_trace) {
      _t(
        'VOICE request $fileName clear=$clearQueue interrupt=$interrupt '
        'muted=$_muted',
      );
    }
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
      // Genuine external stop of the in-flight voice — signal the pump so it
      // doesn't wait out the 15s timeout, then stop the player.
      _fireVoiceStop();
      try {
        await _stopVoicePlayer();
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
        if (_trace) _t('VOICE play ${request.fileName}');
        _voicePlaying = true;
        _updateVoicePipelineState();
        if (!_musicTransitioning) {
          try {
            await _musicPlayer.setVolume(_musicDuckedVolume);
          } on Exception catch (_) {}
        }

        // Fresh per-item external-stop signal. stopVoice()/interrupt complete
        // this to end the wait immediately on a genuine external stop.
        final stopSignal = Completer<void>();
        _activeVoiceStop = stopSignal;
        try {
          // Android (v28 baseline): no stop() before play(); audioplayers
          // replaces the source. The pump only advances after the previous
          // item completed, was stopped externally, or timed out, so nothing
          // is cut either way.
          if (isIOS) await _iosResetVoicePlayer();
          await _voicePlayer.setVolume(1.0);
          if (isIOS) {
            if (!await _iosStartVoice(request.fileName, stopSignal)) continue;
          } else {
            await _voicePlayer.play(
              AssetSource(_voiceAssetPath(request.fileName)),
            );
          }
          // Resolve on natural completion, an explicit external stop, or the
          // 15s safety timeout. The external-stop completer recovers instantly
          // without depending on a PlayerState.stopped event — on Android that
          // event ALSO fires during normal source-swaps when the queue
          // advances, which falsely cut the next queued voice (v25 bug).
          final completed = await Future.any<bool>(<Future<bool>>[
            _voicePlayer.onPlayerComplete.first.then((_) => true),
            stopSignal.future.then((_) => false),
            Future.delayed(const Duration(seconds: 15), () => false),
          ]);
          if (_trace) {
            _t('VOICE done ${request.fileName} completedNormally=$completed');
          }
          if (!completed) {
            _reportAudioIssue(
              operation: 'voice_timeout',
              fileName: request.fileName,
            );
          }
        } on Object catch (e) {
          // Object (not Exception): catches StateError "Bad state: No element"
          // from `_voicePlayer.onPlayerComplete.first` when the stream closes
          // before emitting (player disposed/stopped mid-await).
          _reportAudioIssue(
            operation: 'voice_play_failed',
            fileName: request.fileName,
            error: e,
          );
        } finally {
          if (identical(_activeVoiceStop, stopSignal)) _activeVoiceStop = null;
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
    if (_trace) _t('VOICE stop');
    _clearVoiceQueue();
    _voicePlaying = false;
    _updateVoicePipelineState();
    // Signal the in-flight pump item so it ends its wait immediately rather
    // than blocking on the 15s timeout.
    _fireVoiceStop();
    try {
      await _stopVoicePlayer();
    } on Exception catch (e) {
      _reportAudioIssue(operation: 'stop_voice_failed', error: e);
    }
    _restoreMusicVolume();
  }

  /// External stop of the voice player (stopVoice / interrupt). Android:
  /// exactly `_voicePlayer.stop()`. iOS: also remembered in
  /// [_iosVoiceStopInFlight] until it completes.
  Future<void> _stopVoicePlayer() {
    final stop = _voicePlayer.stop();
    if (isIOS) {
      _iosVoiceStopInFlight = stop;
      unawaited(
        stop.then<void>((_) {}, onError: (Object _) {}).whenComplete(() {
          if (identical(_iosVoiceStopInFlight, stop)) {
            _iosVoiceStopInFlight = null;
          }
        }),
      );
    }
    return stop;
  }

  /// iOS: longest the pump waits for a voice to load + prepare + resume
  /// before skipping it. audioplayers' own prepare timeout is 30 s, during
  /// which even an interrupt could not unblock the pump (N2).
  static const _iosVoiceStartTimeout = Duration(seconds: 4);

  /// iOS only: start [fileName] on the voice player. Gives up after
  /// [_iosVoiceStartTimeout] or as soon as [stopSignal] fires (stopVoice /
  /// interrupt), and returns whether the voice started (play() returned).
  ///
  /// The asset path is resolved here (the same AudioCache.loadPath call
  /// AssetSource makes) and then played as a DeviceFileSource, which sends
  /// the identical native setSourceUrl(path, isLocal: true). Splitting it
  /// means an abandoned slow load never reaches the player, so it cannot
  /// land its setSourceUrl later and replace a newer voice. An abandoned
  /// play() (source sent, `prepared` never came) is harmless: the next
  /// item's setSourceUrl replaces the native item.
  Future<bool> _iosStartVoice(
    String fileName,
    Completer<void> stopSignal,
  ) async {
    if (stopSignal.isCompleted) return false;
    final deadline = Completer<_VoiceStart>();
    final timer = Timer(
      _iosVoiceStartTimeout,
      () => deadline.complete(_VoiceStart.timedOut),
    );
    final stopped = stopSignal.future.then((_) => _VoiceStart.stopped);
    try {
      String? path;
      final load = _voicePlayer.audioCache.loadPath(_voiceAssetPath(fileName));
      final loaded = await Future.any<_VoiceStart>([
        load.then((p) {
          path = p;
          return _VoiceStart.started;
        }),
        stopped,
        deadline.future,
      ]);
      if (loaded != _VoiceStart.started) {
        load.ignore();
        return _iosVoiceNotStarted(fileName, loaded);
      }
      final play = _voicePlayer.play(DeviceFileSource(path!));
      final played = await Future.any<_VoiceStart>([
        play.then((_) => _VoiceStart.started),
        stopped,
        deadline.future,
      ]);
      if (played != _VoiceStart.started) {
        play.ignore();
        return _iosVoiceNotStarted(fileName, played);
      }
      return true;
    } finally {
      timer.cancel();
    }
  }

  bool _iosVoiceNotStarted(String fileName, _VoiceStart outcome) {
    if (_trace) _t('VOICE not started $fileName outcome=$outcome');
    if (outcome == _VoiceStart.timedOut) {
      _reportAudioIssue(operation: 'voice_prepare_timeout', fileName: fileName);
    }
    return false;
  }

  /// iOS only, called by the pump before each play(). audioplayers_darwin
  /// 6.3.0 answers a natural completion with onComplete AND a deferred
  /// `seek(0) { release() }` on the same player (WrappedMediaPlayer.swift
  /// onSoundComplete). If that release lands after the next item is
  /// installed it pauses/removes it: a silent or cut voice, then a 15-30 s
  /// pump stall (N1, ios-audio-diagnosis.md). A stop() first cancels the
  /// pending seek (its handler fires with finished = NO, so no release).
  /// Skipped when the player is already stopped, e.g. by an interrupt:
  /// await that in-flight stop rather than trusting `state`, which lags the
  /// native reply. Never a state listener (feedback_audio_behavior.md).
  Future<void> _iosResetVoicePlayer() async {
    try {
      final inFlight = _iosVoiceStopInFlight;
      if (inFlight != null) await inFlight;
    } on Object catch (_) {
      // The interrupt path already reported its own stop failure.
    }
    if (_voicePlayer.state == PlayerState.stopped) return;
    try {
      await _voicePlayer.stop();
    } on Object catch (e) {
      _reportAudioIssue(operation: 'voice_prestop_failed', error: e);
    }
  }

  /// Complete the active voice-pump external-stop signal, if any. Lets a
  /// genuine external stop (stopVoice / interrupt) end the pump's per-item
  /// wait instantly without relying on a PlayerState.stopped event.
  void _fireVoiceStop() {
    final s = _activeVoiceStop;
    if (s != null && !s.isCompleted) s.complete();
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
      _musicPlayer.setVolume(_musicTargetVolume);
    } on Exception catch (_) {}
  }

  Future<void> playMusic(String fileName, {bool isRetry = false}) async {
    if (_trace) _t('MUSIC play $fileName retry=$isRetry muted=$_muted');
    if (isIOS) _iosReleaseMusicHold();
    if (_muted) return;
    // iOS: serialize starts. Overlapping calls (main.dart resumeAfterWake vs
    // a screen's own playMusic vs a health-check restart) each stop and
    // dispose the same _musicPlayer and create their own, disposing one
    // mid-prepare or orphaning one. The guarded retry at the bottom runs
    // inside the current turn (isRetry), so it never waits on itself.
    // Android: iosTurn stays null; the body below is unchanged.
    Completer<void>? iosTurn;
    if (isIOS && !isRetry) {
      iosTurn = await _iosTakeMusicTurn();
      if (iosTurn == null) return; // superseded while waiting its turn
      if (_muted) {
        iosTurn.complete();
        return;
      }
    }
    try {
      _currentMusicFile = fileName;
      _musicTransitioning = true;
      try {
        await _musicPlayer.stop();
        if (Platform.isIOS) {
          // iOS: await dispose so AVPlayer KVO teardown completes before we
          // assign a new player + setSource. Fire-and-forget dispose lets the
          // new player attach to a half-torn-down session, causing silent or
          // stuck music on iOS. Android v22 baseline is fire-and-forget and
          // works — keep that path unchanged.
          await _musicPlayer.dispose();
        } else {
          unawaited(_musicPlayer.dispose());
        }
      } on Object catch (e) {
        // on Object (not Exception): audioplayers can throw StateError (an Error,
        // not an Exception) when stop()/dispose() races a teardown.
        _reportAudioIssue(
          operation: 'music_reset_failed',
          fileName: fileName,
          error: e,
        );
      }
      try {
        _musicPlayer = AudioPlayer();
        _musicPlaying = true;
        _musicTargetVolume = _musicVolume;
        await _musicPlayer.setSource(AssetSource('audio/$fileName'));
        await _musicPlayer.setReleaseMode(ReleaseMode.loop);
        await _musicPlayer.setVolume(_musicTargetVolume);
        await _musicPlayer.resume();
        _musicTransitioning = false;
      } on Object catch (e) {
        // on Object (not Exception): setSource() -> _completePrepared throws a
        // StateError ("Bad state: No element") when the player is disposed mid-
        // prepare. StateError is an Error, not an Exception, so `on Exception`
        // let it escape to Crashlytics (dominant Android crash through v25).
        _musicTransitioning = false;
        _musicPlaying = false;
        _reportAudioIssue(
          operation: 'music_play_failed',
          fileName: fileName,
          error: e,
        );
        // One guarded retry: the failed attempt left no playing player, so the
        // screen would be silent. Retry once with a fresh player, but only if
        // this same track is still the desired one (a newer playMusic for a
        // different file must win) and we're not already a retry (no loops).
        if (!isRetry && !_muted && _currentMusicFile == fileName) {
          await Future<void>.delayed(const Duration(milliseconds: 300));
          if (!_muted &&
              _currentMusicFile == fileName &&
              !_musicTransitioning) {
            await playMusic(fileName, isRetry: true);
          }
        }
      }
    } finally {
      iosTurn?.complete();
    }
  }

  /// Call periodically during brushing to recover music if it stopped.
  /// Checks the player state and restarts if needed.
  Future<void> ensureMusicPlaying() async {
    if (_musicTransitioning) return;
    if (_muted || !_musicPlaying || _currentMusicFile == null) return;
    if (isIOS) {
      await _iosEnsureMusicPlaying();
      return;
    }
    // Android (v28 baseline): `completed` on a natively looping player means
    // the MediaPlayer died after an error; restarting is the only recovery.
    try {
      final state = _musicPlayer.state;
      if (_trace) _t('MUSIC health state=$state target=$_musicTargetVolume');
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
    final clamped = volume.clamp(0.0, 1.0);
    _musicTargetVolume = clamped;
    if (_musicTransitioning || !_musicPlaying) return;
    try {
      await _musicPlayer.setVolume(clamped);
    } on Exception catch (_) {}
  }

  /// Pause music playback (keeps player state so it can resume).
  Future<void> pauseMusic() async {
    if (_trace) _t('MUSIC pause playing=$_musicPlaying');
    if (isIOS) {
      _iosMusicHeld = true;
      _iosWatchPlayer = null; // a paused track legitimately stops moving
    }
    if (_musicTransitioning || !_musicPlaying) return;
    try {
      await _musicPlayer.pause();
    } on Exception catch (e) {
      _reportAudioIssue(operation: 'music_pause_failed', error: e);
    }
  }

  /// Resume music after a pause. Does nothing if music was not playing.
  Future<void> resumeMusic() async {
    if (_trace) _t('MUSIC resume playing=$_musicPlaying');
    if (isIOS) {
      final deferredFile = _iosWakeDeferredFile;
      final deferredVolume = _iosWakeDeferredVolume;
      _iosReleaseMusicHold();
      _iosWatchPlayer = null; // restart the stall window from the resume
      // The app was backgrounded while paused: the lifecycle stop killed
      // the player, so restart the parked track now that the kid resumed.
      if (deferredFile != null && !_musicPlaying && !_muted) {
        await playMusic(deferredFile);
        if (deferredVolume != null) await setMusicVolume(deferredVolume);
        return;
      }
    }
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
    if (_trace) _t('MUSIC stop transitioning=$_musicTransitioning');
    if (isIOS) {
      _iosReleaseMusicHold();
      _iosMusicGeneration++; // drop any start still waiting its turn
    }
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
    if (_trace) _t('ALL stop musicPlaying=$_musicPlaying');
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

  /// Stop all audio for an app-lifecycle pause (phone sleep / background),
  /// snapshotting the current music file + volume so [resumeAfterWake] can
  /// restore them. Use this instead of [stopAllAudio] on lifecycle events.
  Future<void> stopAllAudioForLifecycle() async {
    if (_trace) {
      _t(
        'ALL lifecycle-stop musicPlaying=$_musicPlaying '
        'file=$_currentMusicFile',
      );
    }
    if (_musicPlaying && _currentMusicFile != null) {
      _musicFileBeforePause = _currentMusicFile;
      _musicVolumeBeforePause = _musicTargetVolume;
    } else {
      _musicFileBeforePause = null;
      _musicVolumeBeforePause = null;
    }
    await stopAllAudio();
  }

  /// Restart the music that was playing before the last lifecycle pause.
  /// No-op if nothing was playing or the user muted while backgrounded.
  /// Screens don't rebuild on app-resume, so without this music stays dead
  /// after the phone wakes (Jim's v24 Android feedback).
  Future<void> resumeAfterWake() async {
    final file = _musicFileBeforePause;
    final vol = _musicVolumeBeforePause;
    _musicFileBeforePause = null;
    _musicVolumeBeforePause = null;
    if (_trace) {
      _t('ALL wake file=$file vol=$vol muted=$_muted held=$_iosMusicHeld');
    }
    if (_muted || file == null) return;
    if (isIOS && _iosMusicHeld) {
      // iOS: the brushing session is paused (PAUSE overlay up). Don't start
      // battle music under it; the RESUME tap's resumeMusic() restarts it.
      _iosWakeDeferredFile = file;
      _iosWakeDeferredVolume = vol;
      return;
    }
    await playMusic(file);
    if (vol != null) await setMusicVolume(vol);
  }

  /// iOS only: listen for the AVAudioSession events AppDelegate.swift
  /// forwards (interruptions, headphones lost, media-services reset). Call
  /// once at startup. A no-op off iOS: Android never registers the handler,
  /// and no Dart code ever invokes a method on this channel.
  static void listenForIosAudioSessionEvents() {
    if (isIOS) {
      _iosSessionChannel.setMethodCallHandler(
        (call) => AudioService()._iosOnAudioSessionEvent(call),
      );
    }
  }

  static const _iosSessionChannel = MethodChannel('brushquest/audio_session');

  /// iOS: one AVAudioSession event from AppDelegate.swift. In every case the
  /// system has paused our players, so the voice in flight will never send
  /// onComplete and the pump would sit out its 15 s timeout.
  /// - interruptionBegan (call, alarm, Siri): end that voice and drop the
  ///   queue; lines queued now would only play into a dead session.
  /// - interruptionEnded / mediaServicesReset: end any voice still stuck,
  ///   then restart the music on a fresh player at the screen's volume,
  ///   unless the kid paused it (brushing PAUSE overlay, incl. the iOS
  ///   auto-pause on 'inactive') - RESUME restarts it then.
  /// - routeLost (headphones / AirPods gone): end the stuck voice so the
  ///   queue carries on. Music is left paused (Apple's default).
  Future<void> _iosOnAudioSessionEvent(MethodCall call) async {
    if (_trace) _t('SESSION ${call.method} ${call.arguments}');
    try {
      switch (call.method) {
        case 'interruptionBegan':
          await stopVoice();
        case 'interruptionEnded':
        case 'mediaServicesReset':
          await _iosEndStuckVoice();
          final file = _currentMusicFile;
          if (_muted || !_musicPlaying || _iosMusicHeld || file == null) {
            return;
          }
          await _iosRestartMusic(file);
        case 'routeLost':
          await _iosEndStuckVoice();
      }
    } on Object catch (e) {
      _reportAudioIssue(operation: 'session_${call.method}_failed', error: e);
    }
  }

  /// iOS: end the voice the system paused mid-line. Ends the pump's wait
  /// (like an interrupt) and stops the player; queued voices then play.
  Future<void> _iosEndStuckVoice() async {
    _fireVoiceStop();
    try {
      await _stopVoicePlayer();
    } on Object catch (e) {
      _reportAudioIssue(operation: 'voice_session_stop_failed', error: e);
    }
  }

  /// iOS only: music health check. audioplayers_darwin reports `completed`
  /// on EVERY loop wrap of the looping music player while the native loop
  /// keeps playing (WrappedMediaPlayer.onSoundComplete), so Android's
  /// "completed -> restart at 0.18" caused a restart glitch every ~2 min and
  /// clobbered the screen's volume (H3). Here playing/completed are judged
  /// by position instead: if it has not moved for longer than
  /// [_iosMusicStallLimit] (e.g. the loop's seek was cancelled, or AVPlayer
  /// was silently paused) the track is restarted at the screen's current
  /// target volume. Paused -> resume, as on Android. Anything else
  /// (stopped) -> restart at the current target volume.
  Future<void> _iosEnsureMusicPlaying() async {
    if (_iosWatchBusy) return;
    _iosWatchBusy = true;
    final player = _musicPlayer;
    final file = _currentMusicFile!;
    try {
      final state = player.state;
      if (_trace) {
        _t('MUSIC health(iOS) state=$state target=$_musicTargetVolume');
      }
      if (state == PlayerState.paused) {
        _iosWatchPlayer = null;
        await player.resume();
        return;
      }
      if (state == PlayerState.playing || state == PlayerState.completed) {
        final position = (await player.getCurrentPosition())?.inMilliseconds;
        if (_trace) _t('MUSIC health(iOS) position=$position');
        if (!_iosMusicStillCurrent(player)) return;
        if (!_iosMusicStalled(player, position)) return;
        _reportAudioIssue(operation: 'music_stall_restart', fileName: file);
      }
      await _iosRestartMusic(file);
    } on Object catch (e) {
      if (!_iosMusicStillCurrent(player)) return;
      _reportAudioIssue(
        operation: 'music_health_restart',
        fileName: file,
        error: e,
      );
      await _iosRestartMusic(file);
    } finally {
      _iosWatchBusy = false;
    }
  }

  /// iOS: [player] is still the live, wanted music player.
  bool _iosMusicStillCurrent(AudioPlayer player) =>
      identical(player, _musicPlayer) &&
      _musicPlaying &&
      !_musicTransitioning &&
      !_muted;

  /// iOS: record [positionMs] for [player]; true once the position has not
  /// changed for longer than [_iosMusicStallLimit].
  bool _iosMusicStalled(AudioPlayer player, int? positionMs) {
    final now = _now();
    final since = _iosWatchSince;
    if (!identical(_iosWatchPlayer, player) ||
        positionMs != _iosWatchPositionMs ||
        since == null) {
      _iosWatchPlayer = player;
      _iosWatchPositionMs = positionMs;
      _iosWatchSince = now;
      return false;
    }
    return now.difference(since) > _iosMusicStallLimit;
  }

  /// iOS: restart [file] and keep the screen's current level. playMusic()
  /// itself resets the target to 0.18 (callers like brushing rely on that),
  /// so the keep-volume step lives here, not in playMusic.
  Future<void> _iosRestartMusic(String file) async {
    final keep = _musicTargetVolume;
    _iosWatchPlayer = null;
    await playMusic(file);
    await setMusicVolume(keep);
  }

  /// iOS only: wait until no other playMusic start is in flight, then take
  /// the turn. Returns the completer the caller completes when its start is
  /// done, or null if a newer playMusic/stopMusic arrived while waiting (the
  /// caller must drop its start; the turn is already passed on).
  Future<Completer<void>?> _iosTakeMusicTurn() async {
    final generation = ++_iosMusicGeneration;
    final previous = _iosMusicTurn;
    final mine = Completer<void>();
    _iosMusicTurn = mine.future;
    if (previous != null) await previous;
    if (generation != _iosMusicGeneration) {
      mine.complete();
      if (_trace) _t('MUSIC start dropped (superseded)');
      return null;
    }
    return mine;
  }

  /// iOS: drop the music hold and any wake restart parked behind it.
  void _iosReleaseMusicHold() {
    _iosMusicHeld = false;
    _iosWakeDeferredFile = null;
    _iosWakeDeferredVolume = null;
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

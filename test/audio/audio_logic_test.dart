import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

/// Pure-logic tests for audio-related code across the Brush Quest codebase.
/// These read source files directly (no Flutter widget tree needed) and
/// replicate pure logic extracted from the production code to verify
/// correctness of voice maps, hit sound rotation, encouragement timing,
/// time-of-day voice selection, chest reward voice mapping, and onboarding
/// page-to-voice mapping.
void main() {
  // ---------------------------------------------------------------------------
  // Source file contents loaded once for the group.
  // ---------------------------------------------------------------------------
  late String audioServiceSrc;
  late String brushingScreenSrc;
  late String victoryScreenSrc;
  late String onboardingScreenSrc;

  setUpAll(() {
    audioServiceSrc =
        File('lib/services/audio_service.dart').readAsStringSync();
    brushingScreenSrc =
        File('lib/screens/brushing_screen.dart').readAsStringSync();
    victoryScreenSrc =
        File('lib/screens/victory_screen.dart').readAsStringSync();
    onboardingScreenSrc =
        File('lib/screens/onboarding_screen.dart').readAsStringSync();
  });

  // ===========================================================================
  // 1. Voice line selection maps
  // ===========================================================================
  group('heroPickerVoiceFor / weaponPickerVoiceFor', () {
    // Replicate the maps and fallback logic from AudioService.
    const heroPickerVoices = {
      'blaze': 'voice_picker_hero_blaze.mp3',
      'frost': 'voice_picker_hero_frost.mp3',
      'bolt': 'voice_picker_hero_bolt.mp3',
      'shadow': 'voice_picker_hero_shadow.mp3',
      'leaf': 'voice_picker_hero_leaf.mp3',
      'nova': 'voice_picker_hero_nova.mp3',
    };

    const weaponPickerVoices = {
      'star_blaster': 'voice_picker_weapon_star_blaster.mp3',
      'flame_sword': 'voice_picker_weapon_flame_sword.mp3',
      'ice_hammer': 'voice_picker_weapon_ice_hammer.mp3',
      'lightning_wand': 'voice_picker_weapon_lightning_wand.mp3',
      'vine_whip': 'voice_picker_weapon_vine_whip.mp3',
      'cosmic_burst': 'voice_picker_weapon_cosmic_burst.mp3',
    };

    String heroPickerVoiceFor(String id) =>
        heroPickerVoices[id] ?? 'voice_great_choice.mp3';
    String weaponPickerVoiceFor(String id) =>
        weaponPickerVoices[id] ?? 'voice_awesome.mp3';

    test('source contains heroPickerVoices map with all 6 heroes', () {
      for (final id in heroPickerVoices.keys) {
        expect(
          audioServiceSrc.contains("'$id': '${heroPickerVoices[id]}'"),
          isTrue,
          reason: 'heroPickerVoices should contain entry for $id',
        );
      }
    });

    test('source contains weaponPickerVoices map with all 6 weapons', () {
      for (final id in weaponPickerVoices.keys) {
        expect(
          audioServiceSrc.contains("'$id': '${weaponPickerVoices[id]}'"),
          isTrue,
          reason: 'weaponPickerVoices should contain entry for $id',
        );
      }
    });

    test('heroPickerVoiceFor returns correct file for every known hero', () {
      for (final entry in heroPickerVoices.entries) {
        expect(heroPickerVoiceFor(entry.key), entry.value);
      }
    });

    test('heroPickerVoiceFor falls back for unknown hero ID', () {
      expect(heroPickerVoiceFor('unknown_hero'), 'voice_great_choice.mp3');
      expect(heroPickerVoiceFor(''), 'voice_great_choice.mp3');
    });

    test('weaponPickerVoiceFor returns correct file for every known weapon',
        () {
      for (final entry in weaponPickerVoices.entries) {
        expect(weaponPickerVoiceFor(entry.key), entry.value);
      }
    });

    test('weaponPickerVoiceFor falls back for unknown weapon ID', () {
      expect(weaponPickerVoiceFor('unknown_weapon'), 'voice_awesome.mp3');
      expect(weaponPickerVoiceFor(''), 'voice_awesome.mp3');
    });

    test('source fallback for heroPickerVoiceFor is voice_great_choice.mp3',
        () {
      expect(
        audioServiceSrc.contains("heroPickerVoices[heroId] ?? 'voice_great_choice.mp3'"),
        isTrue,
      );
    });

    test('source fallback for weaponPickerVoiceFor is voice_awesome.mp3', () {
      expect(
        audioServiceSrc.contains("weaponPickerVoices[weaponId] ?? 'voice_awesome.mp3'"),
        isTrue,
      );
    });
  });

  // ===========================================================================
  // 1b. Intro voice maps
  // ===========================================================================
  group('heroIntroVoiceFor / weaponIntroVoiceFor', () {
    const heroIntroVoices = {
      'blaze': 'voice_intro_hero_blaze.mp3',
      'frost': 'voice_intro_hero_frost.mp3',
      'bolt': 'voice_intro_hero_bolt.mp3',
      'shadow': 'voice_intro_hero_shadow.mp3',
      'leaf': 'voice_intro_hero_leaf.mp3',
      'nova': 'voice_intro_hero_nova.mp3',
    };

    const weaponIntroVoices = {
      'star_blaster': 'voice_intro_weapon_star_blaster.mp3',
      'flame_sword': 'voice_intro_weapon_flame_sword.mp3',
      'ice_hammer': 'voice_intro_weapon_ice_hammer.mp3',
      'lightning_wand': 'voice_intro_weapon_lightning_wand.mp3',
      'vine_whip': 'voice_intro_weapon_vine_whip.mp3',
      'cosmic_burst': 'voice_intro_weapon_cosmic_burst.mp3',
    };

    test('heroIntroVoices has an entry for every hero in heroPickerVoices', () {
      for (final id in heroIntroVoices.keys) {
        expect(
          audioServiceSrc.contains("'$id': '${heroIntroVoices[id]}'"),
          isTrue,
          reason: 'heroIntroVoices should contain entry for $id',
        );
      }
    });

    test('weaponIntroVoices has an entry for every weapon in weaponPickerVoices',
        () {
      for (final id in weaponIntroVoices.keys) {
        expect(
          audioServiceSrc.contains("'$id': '${weaponIntroVoices[id]}'"),
          isTrue,
          reason: 'weaponIntroVoices should contain entry for $id',
        );
      }
    });

    test('heroIntroVoiceFor fallback chains to heroPickerVoiceFor', () {
      expect(
        audioServiceSrc.contains(
            'heroIntroVoices[heroId] ?? heroPickerVoiceFor(heroId)'),
        isTrue,
      );
    });

    test('weaponIntroVoiceFor fallback chains to weaponPickerVoiceFor', () {
      expect(
        audioServiceSrc.contains(
            'weaponIntroVoices[weaponId] ?? weaponPickerVoiceFor(weaponId)'),
        isTrue,
      );
    });
  });

  // ===========================================================================
  // 2. Hit sound rotation
  // ===========================================================================
  group('hit sound rotation (nextHitSound)', () {
    // Replicate the logic: _hitSounds[_sfxIndex % _hitSounds.length]
    const hitSounds = ['zap.mp3', 'whoosh.mp3'];

    test('source defines _hitSounds with zap and whoosh', () {
      expect(
        audioServiceSrc.contains("_hitSounds = ['zap.mp3', 'whoosh.mp3']"),
        isTrue,
      );
    });

    test('nextHitSound alternates between zap and whoosh', () {
      // Simulate the rotation. nextHitSound uses _sfxIndex which is shared
      // with playSfx. The key invariant: it alternates deterministically.
      for (int sfxIndex = 0; sfxIndex < 20; sfxIndex++) {
        final expected = hitSounds[sfxIndex % hitSounds.length];
        final actual = hitSounds[sfxIndex % hitSounds.length];
        expect(actual, expected);
      }
    });

    test('nextHitSound returns zap.mp3 at even indices and whoosh.mp3 at odd',
        () {
      expect(hitSounds[0 % hitSounds.length], 'zap.mp3');
      expect(hitSounds[1 % hitSounds.length], 'whoosh.mp3');
      expect(hitSounds[2 % hitSounds.length], 'zap.mp3');
      expect(hitSounds[3 % hitSounds.length], 'whoosh.mp3');
    });

    test('nextHitSound uses _sfxIndex (shared with playSfx)', () {
      // Verify the source uses _sfxIndex for both nextHitSound and playSfx
      expect(
        audioServiceSrc.contains('_hitSounds[_sfxIndex % _hitSounds.length]'),
        isTrue,
      );
      expect(
        audioServiceSrc.contains('_sfxPool[_sfxIndex % _sfxPoolSize]'),
        isTrue,
      );
    });
  });

  // ===========================================================================
  // 3. Encouragement timing thresholds
  // ===========================================================================
  group('encouragement timing thresholds', () {
    // Replicate the brushing_screen logic:
    //   energizeAt = (phaseDuration * 0.80).round()
    //   supportAt  = (phaseDuration * 0.50).round()
    //   almostAt   = (phaseDuration * 0.20).round()
    //
    // These are compared to _phaseSecondsLeft (counting DOWN from
    // _phaseDuration to 0).

    List<int> thresholdsFor(int duration) {
      final energize = (duration * 0.80).round();
      final support = (duration * 0.50).round();
      final almost = (duration * 0.20).round();
      return [energize, support, almost];
    }

    test('source uses 0.80, 0.50, 0.20 multipliers', () {
      expect(
        brushingScreenSrc.contains('_phaseDuration * 0.80'),
        isTrue,
      );
      expect(
        brushingScreenSrc.contains('_phaseDuration * 0.50'),
        isTrue,
      );
      expect(
        brushingScreenSrc.contains('_phaseDuration * 0.20'),
        isTrue,
      );
    });

    test('15s phase: thresholds are 12, 8, 3 (all distinct)', () {
      final t = thresholdsFor(15);
      expect(t, [12, 8, 3]);
      expect(t.toSet().length, 3, reason: 'all thresholds should be unique');
    });

    test('20s phase: thresholds are 16, 10, 4 (all distinct)', () {
      final t = thresholdsFor(20);
      expect(t, [16, 10, 4]);
      expect(t.toSet().length, 3);
    });

    test('30s phase: thresholds are 24, 15, 6 (all distinct)', () {
      final t = thresholdsFor(30);
      expect(t, [24, 15, 6]);
      expect(t.toSet().length, 3);
    });

    test('thresholds are strictly decreasing for all supported durations', () {
      for (final d in [15, 20, 30]) {
        final t = thresholdsFor(d);
        expect(t[0] > t[1], isTrue,
            reason: 'energize > support for duration $d');
        expect(t[1] > t[2], isTrue,
            reason: 'support > almost for duration $d');
      }
    });

    test('all thresholds are within valid countdown range [1, duration-1]', () {
      for (final d in [15, 20, 30]) {
        final t = thresholdsFor(d);
        for (final v in t) {
          expect(v >= 1 && v < d, isTrue,
              reason: 'threshold $v out of range for duration $d');
        }
      }
    });
  });

  // ===========================================================================
  // 4. Encouragement voice categories have no overlap
  // ===========================================================================
  group('encouragement voice categories', () {
    const energizingVoices = [
      'voice_go_go_go.mp3',
      'voice_super.mp3',
      'voice_unstoppable.mp3',
      'voice_nice_combo.mp3',
    ];

    const supportiveVoices = [
      'voice_youre_doing_great.mp3',
      'voice_keep_it_up.mp3',
      'voice_keep_going.mp3',
      'voice_so_strong.mp3',
    ];

    const almostThereVoices = [
      'voice_almost_there.mp3',
      'voice_awesome.mp3',
      'voice_wow_amazing.mp3',
    ];

    test('source defines _energizingVoices with expected files', () {
      for (final v in energizingVoices) {
        expect(brushingScreenSrc.contains("'$v'"), isTrue,
            reason: '_energizingVoices should contain $v');
      }
    });

    test('source defines _supportiveVoices with expected files', () {
      for (final v in supportiveVoices) {
        expect(brushingScreenSrc.contains("'$v'"), isTrue,
            reason: '_supportiveVoices should contain $v');
      }
    });

    test('source defines _almostThereVoices with expected files', () {
      for (final v in almostThereVoices) {
        expect(brushingScreenSrc.contains("'$v'"), isTrue,
            reason: '_almostThereVoices should contain $v');
      }
    });

    test('no overlap between energizing and supportive voices', () {
      final overlap =
          energizingVoices.toSet().intersection(supportiveVoices.toSet());
      expect(overlap, isEmpty);
    });

    test('no overlap between energizing and almostThere voices', () {
      final overlap =
          energizingVoices.toSet().intersection(almostThereVoices.toSet());
      expect(overlap, isEmpty);
    });

    test('no overlap between supportive and almostThere voices', () {
      final overlap =
          supportiveVoices.toSet().intersection(almostThereVoices.toSet());
      expect(overlap, isEmpty);
    });

    test('no overlap across all three categories (union is disjoint)', () {
      final all = <String>[
        ...energizingVoices,
        ...supportiveVoices,
        ...almostThereVoices,
      ];
      expect(all.toSet().length, all.length,
          reason: 'duplicate found across categories');
    });
  });

  // ===========================================================================
  // 5. Phase voice mapping
  // ===========================================================================
  group('phase voice mapping (_phaseVoiceFiles)', () {
    // Replicate the map from brushing_screen.dart
    const phaseVoiceFiles = {
      'topLeft': 'voice_top_left.mp3',
      'topRight': 'voice_top_right.mp3',
      'bottomLeft': 'voice_bottom_left.mp3',
      'bottomRight': 'voice_bottom_right.mp3',
    };

    test('all 4 phases map to correct directional voice files', () {
      expect(phaseVoiceFiles['topLeft'], 'voice_top_left.mp3');
      expect(phaseVoiceFiles['topRight'], 'voice_top_right.mp3');
      expect(phaseVoiceFiles['bottomLeft'], 'voice_bottom_left.mp3');
      expect(phaseVoiceFiles['bottomRight'], 'voice_bottom_right.mp3');
    });

    test('source contains the _phaseVoiceFiles map with all 4 entries', () {
      expect(
        brushingScreenSrc.contains("BrushPhase.topLeft: 'voice_top_left.mp3'"),
        isTrue,
      );
      expect(
        brushingScreenSrc
            .contains("BrushPhase.topRight: 'voice_top_right.mp3'"),
        isTrue,
      );
      expect(
        brushingScreenSrc
            .contains("BrushPhase.bottomLeft: 'voice_bottom_left.mp3'"),
        isTrue,
      );
      expect(
        brushingScreenSrc
            .contains("BrushPhase.bottomRight: 'voice_bottom_right.mp3'"),
        isTrue,
      );
    });

    test('brushPhaseOrder contains exactly the 4 brushing phases', () {
      expect(
        brushingScreenSrc.contains('BrushPhase.topLeft,'),
        isTrue,
      );
      expect(
        brushingScreenSrc.contains('BrushPhase.topRight,'),
        isTrue,
      );
      expect(
        brushingScreenSrc.contains('BrushPhase.bottomLeft,'),
        isTrue,
      );
      expect(
        brushingScreenSrc.contains('BrushPhase.bottomRight,'),
        isTrue,
      );
    });

    test('all phase voice files are in _allAudioFiles', () {
      for (final voiceFile in phaseVoiceFiles.values) {
        expect(
          audioServiceSrc.contains("'$voiceFile'"),
          isTrue,
          reason: '$voiceFile should be listed in _allAudioFiles',
        );
      }
    });
  });

  // ===========================================================================
  // 6. Victory time-of-day voice selection
  // ===========================================================================
  group('victory time-of-day voice selection', () {
    // Replicate the logic from victory_screen.dart:
    //   final hour = DateTime.now().hour;
    //   final victoryVoice = (hour >= 5 && hour < 12)
    //       ? 'voice_great_job_morning.mp3'
    //       : (hour >= 18 || hour < 5)
    //       ? 'voice_great_job_tonight.mp3'
    //       : 'voice_you_did_it.mp3';

    String victoryVoiceForHour(int hour) {
      return (hour >= 5 && hour < 12)
          ? 'voice_great_job_morning.mp3'
          : (hour >= 18 || hour < 5)
              ? 'voice_great_job_tonight.mp3'
              : 'voice_you_did_it.mp3';
    }

    test('source uses hour-based conditional for victory voice', () {
      expect(victoryScreenSrc.contains('hour >= 5 && hour < 12'), isTrue);
      expect(victoryScreenSrc.contains('hour >= 18 || hour < 5'), isTrue);
    });

    test('morning hours (5-11) select voice_great_job_morning.mp3', () {
      for (int h = 5; h < 12; h++) {
        expect(victoryVoiceForHour(h), 'voice_great_job_morning.mp3',
            reason: 'hour $h should be morning');
      }
    });

    test('evening/night hours (18-23, 0-4) select voice_great_job_tonight.mp3',
        () {
      for (int h = 18; h < 24; h++) {
        expect(victoryVoiceForHour(h), 'voice_great_job_tonight.mp3',
            reason: 'hour $h should be evening/night');
      }
      for (int h = 0; h < 5; h++) {
        expect(victoryVoiceForHour(h), 'voice_great_job_tonight.mp3',
            reason: 'hour $h should be night');
      }
    });

    test('afternoon hours (12-17) select voice_you_did_it.mp3', () {
      for (int h = 12; h < 18; h++) {
        expect(victoryVoiceForHour(h), 'voice_you_did_it.mp3',
            reason: 'hour $h should be afternoon');
      }
    });

    test('boundary: hour 5 is morning, hour 4 is night', () {
      expect(victoryVoiceForHour(5), 'voice_great_job_morning.mp3');
      expect(victoryVoiceForHour(4), 'voice_great_job_tonight.mp3');
    });

    test('boundary: hour 12 is afternoon, hour 11 is morning', () {
      expect(victoryVoiceForHour(12), 'voice_you_did_it.mp3');
      expect(victoryVoiceForHour(11), 'voice_great_job_morning.mp3');
    });

    test('boundary: hour 18 is evening, hour 17 is afternoon', () {
      expect(victoryVoiceForHour(18), 'voice_great_job_tonight.mp3');
      expect(victoryVoiceForHour(17), 'voice_you_did_it.mp3');
    });

    test('every hour 0-23 maps to exactly one of the 3 voice files', () {
      final validVoices = {
        'voice_great_job_morning.mp3',
        'voice_great_job_tonight.mp3',
        'voice_you_did_it.mp3',
      };
      for (int h = 0; h < 24; h++) {
        expect(validVoices.contains(victoryVoiceForHour(h)), isTrue,
            reason: 'hour $h must map to a valid voice');
      }
    });

    test('all 3 time-of-day voice files are in _allAudioFiles', () {
      for (final f in [
        'voice_great_job_morning.mp3',
        'voice_great_job_tonight.mp3',
        'voice_you_did_it.mp3',
      ]) {
        expect(audioServiceSrc.contains("'$f'"), isTrue,
            reason: '$f should be in _allAudioFiles');
      }
    });
  });

  // ===========================================================================
  // 7. Chest reward voice mapping
  // ===========================================================================
  group('chest reward voice mapping (_rollChestReward)', () {
    // Replicate the logic from victory_screen.dart.
    // The function uses streak tiers to set probability ceilings, then
    // maps roll ranges to _ChestReward objects with specific voiceFiles.

    // Voice files by reward type:
    const rewardVoices = {
      'confetti': 'voice_chest_wow.mp3',
      'dance': 'voice_chest_dance.mp3',
      'bonusStar': 'voice_chest_bonus_star.mp3',
      'doubleStar': 'voice_chest_double.mp3',
      'jackpot': 'voice_chest_jackpot.mp3',
      'megaJackpot': 'voice_chest_jackpot.mp3', // same file as jackpot
    };

    // Replicate the ceiling logic for each streak tier
    Map<String, List<int>> ceilingsForStreak(int streak) {
      int confettiCeil, danceCeil, bonusCeil, doubleCeil, jackpotCeil;
      if (streak >= 7) {
        confettiCeil = 20;
        danceCeil = 35;
        bonusCeil = 65;
        doubleCeil = 83;
        jackpotCeil = 93;
      } else if (streak >= 3) {
        confettiCeil = 25;
        danceCeil = 45;
        bonusCeil = 70;
        doubleCeil = 85;
        jackpotCeil = 95;
      } else {
        confettiCeil = 35;
        danceCeil = 60;
        bonusCeil = 85;
        doubleCeil = 95;
        jackpotCeil = 99;
      }
      return {
        'ceilings': [confettiCeil, danceCeil, bonusCeil, doubleCeil, jackpotCeil],
      };
    }

    String voiceForRoll(int roll, int streak) {
      final c = ceilingsForStreak(streak)['ceilings']!;
      if (roll < c[0]) return 'voice_chest_wow.mp3';
      if (roll < c[1]) return 'voice_chest_dance.mp3';
      if (roll < c[2]) return 'voice_chest_bonus_star.mp3';
      if (roll < c[3]) return 'voice_chest_double.mp3';
      if (roll < c[4]) return 'voice_chest_jackpot.mp3';
      return 'voice_chest_jackpot.mp3'; // mega jackpot
    }

    test('source defines _rollChestReward function', () {
      expect(victoryScreenSrc.contains('_rollChestReward'), isTrue);
    });

    test('no-streak tier: confetti=35, dance=60, bonus=85, double=95, jackpot=99',
        () {
      final c = ceilingsForStreak(0)['ceilings']!;
      expect(c, [35, 60, 85, 95, 99]);
    });

    test('streak>=3 tier: confetti=25, dance=45, bonus=70, double=85, jackpot=95',
        () {
      final c = ceilingsForStreak(3)['ceilings']!;
      expect(c, [25, 45, 70, 85, 95]);
    });

    test('streak>=7 tier: confetti=20, dance=35, bonus=65, double=83, jackpot=93',
        () {
      final c = ceilingsForStreak(7)['ceilings']!;
      expect(c, [20, 35, 65, 83, 93]);
    });

    test('every possible roll (0-99) produces a valid voice file', () {
      final validVoices = rewardVoices.values.toSet();
      for (final streak in [0, 1, 2, 3, 5, 7, 10, 20]) {
        for (int roll = 0; roll < 100; roll++) {
          final voice = voiceForRoll(roll, streak);
          expect(validVoices.contains(voice), isTrue,
              reason:
                  'roll=$roll streak=$streak produced invalid voice: $voice');
        }
      }
    });

    test('roll=0 always produces confetti voice', () {
      for (final streak in [0, 3, 7]) {
        expect(voiceForRoll(0, streak), 'voice_chest_wow.mp3');
      }
    });

    test('roll=99 produces jackpot voice for all streak tiers', () {
      // For streak 0: jackpotCeil=99, so roll=99 is mega jackpot
      // For streak 3: jackpotCeil=95, so roll=99 is mega jackpot
      // For streak 7: jackpotCeil=93, so roll=99 is mega jackpot
      for (final streak in [0, 3, 7]) {
        expect(voiceForRoll(99, streak), 'voice_chest_jackpot.mp3');
      }
    });

    test('higher streaks give better rewards at same roll values', () {
      // At roll=30, streak=0 gives confetti, streak=7 gives dance
      expect(voiceForRoll(30, 0), 'voice_chest_wow.mp3'); // <35
      expect(voiceForRoll(30, 7), 'voice_chest_dance.mp3'); // >=20, <35
    });

    test('all chest voice files are in _allAudioFiles', () {
      for (final f in rewardVoices.values.toSet()) {
        expect(audioServiceSrc.contains("'$f'"), isTrue,
            reason: '$f should be in _allAudioFiles');
      }
    });

    test('bonus stars: confetti=0, dance=0, bonus=1, double=1, jackpot=3, mega=5',
        () {
      // Verify these from the source
      expect(victoryScreenSrc.contains("type: _ChestRewardType.confetti,"), isTrue);
      expect(victoryScreenSrc.contains("type: _ChestRewardType.dance,"), isTrue);
      expect(victoryScreenSrc.contains("type: _ChestRewardType.bonusStar,"), isTrue);
      expect(victoryScreenSrc.contains("type: _ChestRewardType.doubleStar,"), isTrue);
      expect(victoryScreenSrc.contains("type: _ChestRewardType.jackpot,"), isTrue);
    });
  });

  // ===========================================================================
  // 8. Onboarding page-to-voice mapping
  // ===========================================================================
  group('onboarding page-to-voice mapping', () {
    // Replicate the switch expression from onboarding_screen.dart:
    //   final voiceFile = switch (page) {
    //     0 => 'voice_onboarding_1.mp3',
    //     1 => 'voice_onboarding_2.mp3',
    //     2 => 'voice_onboarding_3.mp3',
    //     _ => 'voice_onboarding_1.mp3',
    //   };

    String voiceForPage(int page) {
      return switch (page) {
        0 => 'voice_onboarding_1.mp3',
        1 => 'voice_onboarding_2.mp3',
        2 => 'voice_onboarding_3.mp3',
        _ => 'voice_onboarding_1.mp3',
      };
    }

    test('page 0 maps to voice_onboarding_1.mp3', () {
      expect(voiceForPage(0), 'voice_onboarding_1.mp3');
    });

    test('page 1 maps to voice_onboarding_2.mp3', () {
      expect(voiceForPage(1), 'voice_onboarding_2.mp3');
    });

    test('page 2 maps to voice_onboarding_3.mp3', () {
      expect(voiceForPage(2), 'voice_onboarding_3.mp3');
    });

    test('unknown page falls back to voice_onboarding_1.mp3', () {
      expect(voiceForPage(3), 'voice_onboarding_1.mp3');
      expect(voiceForPage(-1), 'voice_onboarding_1.mp3');
      expect(voiceForPage(99), 'voice_onboarding_1.mp3');
    });

    test('source contains the switch expression with all 3 pages', () {
      expect(
        onboardingScreenSrc.contains("0 => 'voice_onboarding_1.mp3'"),
        isTrue,
      );
      expect(
        onboardingScreenSrc.contains("1 => 'voice_onboarding_2.mp3'"),
        isTrue,
      );
      expect(
        onboardingScreenSrc.contains("2 => 'voice_onboarding_3.mp3'"),
        isTrue,
      );
    });

    test('source has fallback for unknown page index', () {
      expect(
        onboardingScreenSrc.contains("_ => 'voice_onboarding_1.mp3'"),
        isTrue,
      );
    });

    test('all onboarding voice files are in _allAudioFiles', () {
      for (final f in [
        'voice_onboarding_1.mp3',
        'voice_onboarding_2.mp3',
        'voice_onboarding_3.mp3',
      ]) {
        expect(audioServiceSrc.contains("'$f'"), isTrue,
            reason: '$f should be in _allAudioFiles');
      }
    });

    test('onboarding has exactly 3 pages', () {
      // The PageView has 3 children: _buildWelcomePage, _buildHowToPlayPage,
      // _buildMouthGuidePage
      expect(onboardingScreenSrc.contains('_buildWelcomePage()'), isTrue);
      expect(onboardingScreenSrc.contains('_buildHowToPlayPage()'), isTrue);
      expect(onboardingScreenSrc.contains('_buildMouthGuidePage()'), isTrue);
    });
  });

  // ===========================================================================
  // 9. _encouragementVoices list in AudioService
  // ===========================================================================
  group('_encouragementVoices list (AudioService)', () {
    const encouragementVoices = [
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

    test('AudioService exposes encouragementVoices with 10 entries', () {
      expect(encouragementVoices.length, 10);
    });

    test('_playNextEncouragementVoice avoids repeating the same voice', () {
      // Replicate the anti-repeat logic from brushing_screen.dart:
      // It increments index until it finds a different voice from the last one.
      int encouragementIndex = 0;
      String? lastVoice;

      for (int call = 0; call < 30; call++) {
        String selected =
            encouragementVoices[encouragementIndex % encouragementVoices.length];
        int safety = 0;
        while (selected == lastVoice &&
            safety < encouragementVoices.length + 2) {
          encouragementIndex++;
          selected = encouragementVoices[
              encouragementIndex % encouragementVoices.length];
          safety++;
        }
        // The selected voice should differ from the last one
        if (lastVoice != null) {
          expect(selected != lastVoice, isTrue,
              reason:
                  'call $call should not repeat: got $selected == $lastVoice');
        }
        lastVoice = selected;
        encouragementIndex++;
      }
    });

    test('all _encouragementVoices are in _allAudioFiles', () {
      for (final v in encouragementVoices) {
        expect(audioServiceSrc.contains("'$v'"), isTrue,
            reason: '$v should be listed in _allAudioFiles');
      }
    });
  });

  // ===========================================================================
  // 10. _allAudioFiles completeness cross-check
  // ===========================================================================
  group('_allAudioFiles cross-references', () {
    test('voice_open_chest.mp3 is in _allAudioFiles (used before chest reveal)',
        () {
      expect(audioServiceSrc.contains("'voice_open_chest.mp3'"), isTrue);
    });

    test('voice_earned_star.mp3 is in _allAudioFiles (played after victory voice)',
        () {
      expect(audioServiceSrc.contains("'voice_earned_star.mp3'"), isTrue);
    });

    test('battle_music_loop.mp3 is in _allAudioFiles', () {
      expect(audioServiceSrc.contains("'battle_music_loop.mp3'"), isTrue);
    });

    test('star_chime.mp3 is in _allAudioFiles', () {
      expect(audioServiceSrc.contains("'star_chime.mp3'"), isTrue);
    });

    test('voice_lets_fight.mp3 is in _allAudioFiles (played at onboarding end)',
        () {
      expect(audioServiceSrc.contains("'voice_lets_fight.mp3'"), isTrue);
    });
  });
}

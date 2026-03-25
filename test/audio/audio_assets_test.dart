import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// Audio asset verification tests for Brush Quest.
///
/// These tests run against the actual filesystem (no Flutter widget binding
/// required) to ensure every audio file referenced in code exists, is
/// non-trivially sized, and that the preload list is free of duplicates.

// ---------------------------------------------------------------------------
// Mirror of AudioService._allAudioFiles (lib/services/audio_service.dart:97)
// ---------------------------------------------------------------------------
const _allAudioFiles = [
  'countdown_beep.mp3',
  'monster_defeat.mp3',
  'victory.mp3',
  'voice_bottom_left.mp3',
  'voice_bottom_right.mp3',
  'voice_countdown.mp3',
  'voice_top_left.mp3',
  'voice_top_right.mp3',
  'voice_keep_going.mp3',
  'voice_youre_doing_great.mp3',
  'voice_nice_combo.mp3',
  'voice_keep_it_up.mp3',
  'voice_so_strong.mp3',
  'voice_super.mp3',
  'voice_go_go_go.mp3',
  'voice_awesome.mp3',
  'voice_wow_amazing.mp3',
  'voice_welcome_back.mp3',
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
  'voice_lets_fight.mp3',
  'voice_chest_wow.mp3',
  'voice_chest_dance.mp3',
  'voice_chest_bonus_star.mp3',
  'voice_chest_double.mp3',
  'voice_chest_jackpot.mp3',
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
  'voice_onboarding_1.mp3',
  'voice_onboarding_2.mp3',
  'voice_onboarding_3.mp3',
  'voice_need_stars.mp3',
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
  // Unlock encouragement voices (heroes + weapons)
  'voice_unlock_next_frost.mp3',
  'voice_unlock_next_bolt.mp3',
  'voice_unlock_next_shadow.mp3',
  'voice_unlock_next_leaf.mp3',
  'voice_unlock_next_nova.mp3',
  'voice_unlock_next_flame_sword.mp3',
  'voice_unlock_next_ice_hammer.mp3',
  'voice_unlock_next_lightning_wand.mp3',
  'voice_unlock_next_vine_whip.mp3',
  'voice_unlock_next_cosmic_shield.mp3',
  // Monster card voice-overs (World 1-10)
  'voice_card_cc_01.mp3', 'voice_card_cc_02.mp3', 'voice_card_cc_03.mp3',
  'voice_card_cc_04.mp3', 'voice_card_cc_05.mp3', 'voice_card_cc_06.mp3',
  'voice_card_cc_07.mp3',
  'voice_card_ss_01.mp3', 'voice_card_ss_02.mp3', 'voice_card_ss_03.mp3',
  'voice_card_ss_04.mp3', 'voice_card_ss_05.mp3', 'voice_card_ss_06.mp3',
  'voice_card_ss_07.mp3',
  'voice_card_sv_01.mp3', 'voice_card_sv_02.mp3', 'voice_card_sv_03.mp3',
  'voice_card_sv_04.mp3', 'voice_card_sv_05.mp3', 'voice_card_sv_06.mp3',
  'voice_card_sv_07.mp3',
  'voice_card_sn_01.mp3', 'voice_card_sn_02.mp3', 'voice_card_sn_03.mp3',
  'voice_card_sn_04.mp3', 'voice_card_sn_05.mp3', 'voice_card_sn_06.mp3',
  'voice_card_sn_07.mp3',
  'voice_card_cf_01.mp3', 'voice_card_cf_02.mp3', 'voice_card_cf_03.mp3',
  'voice_card_cf_04.mp3', 'voice_card_cf_05.mp3', 'voice_card_cf_06.mp3',
  'voice_card_cf_07.mp3',
  'voice_card_ft_01.mp3', 'voice_card_ft_02.mp3', 'voice_card_ft_03.mp3',
  'voice_card_ft_04.mp3', 'voice_card_ft_05.mp3', 'voice_card_ft_06.mp3',
  'voice_card_ft_07.mp3',
  'voice_card_tj_01.mp3', 'voice_card_tj_02.mp3', 'voice_card_tj_03.mp3',
  'voice_card_tj_04.mp3', 'voice_card_tj_05.mp3', 'voice_card_tj_06.mp3',
  'voice_card_tj_07.mp3',
  'voice_card_cr_01.mp3', 'voice_card_cr_02.mp3', 'voice_card_cr_03.mp3',
  'voice_card_cr_04.mp3', 'voice_card_cr_05.mp3', 'voice_card_cr_06.mp3',
  'voice_card_cr_07.mp3',
  'voice_card_sc_01.mp3', 'voice_card_sc_02.mp3', 'voice_card_sc_03.mp3',
  'voice_card_sc_04.mp3', 'voice_card_sc_05.mp3', 'voice_card_sc_06.mp3',
  'voice_card_sc_07.mp3',
  'voice_card_dd_01.mp3', 'voice_card_dd_02.mp3', 'voice_card_dd_03.mp3',
  'voice_card_dd_04.mp3', 'voice_card_dd_05.mp3', 'voice_card_dd_06.mp3',
  'voice_card_dd_07.mp3',
];

// ---------------------------------------------------------------------------
// Dynamic voice file expectations derived from service source code.
// ---------------------------------------------------------------------------

/// 70 card IDs from CardService.allCards (card_service.dart).
const _allCardIds = [
  // World 1: Candy Crater
  'cc_01', 'cc_02', 'cc_03', 'cc_04', 'cc_05', 'cc_06', 'cc_07',
  // World 2: Slime Swamp
  'ss_01', 'ss_02', 'ss_03', 'ss_04', 'ss_05', 'ss_06', 'ss_07',
  // World 3: Sugar Volcano
  'sv_01', 'sv_02', 'sv_03', 'sv_04', 'sv_05', 'sv_06', 'sv_07',
  // World 4: Shadow Nebula
  'sn_01', 'sn_02', 'sn_03', 'sn_04', 'sn_05', 'sn_06', 'sn_07',
  // World 5: Cavity Fortress
  'cf_01', 'cf_02', 'cf_03', 'cf_04', 'cf_05', 'cf_06', 'cf_07',
  // World 6: Frozen Tundra
  'ft_01', 'ft_02', 'ft_03', 'ft_04', 'ft_05', 'ft_06', 'ft_07',
  // World 7: Toxic Jungle
  'tj_01', 'tj_02', 'tj_03', 'tj_04', 'tj_05', 'tj_06', 'tj_07',
  // World 8: Crystal Cave
  'cr_01', 'cr_02', 'cr_03', 'cr_04', 'cr_05', 'cr_06', 'cr_07',
  // World 9: Storm Citadel
  'sc_01', 'sc_02', 'sc_03', 'sc_04', 'sc_05', 'sc_06', 'sc_07',
  // World 10: Dark Dimension
  'dd_01', 'dd_02', 'dd_03', 'dd_04', 'dd_05', 'dd_06', 'dd_07',
];

/// 6 hero IDs from HeroService.allHeroes (hero_service.dart).
const _allHeroIds = ['blaze', 'frost', 'bolt', 'shadow', 'leaf', 'nova'];

/// 6 weapon IDs from WeaponService.allWeapons (weapon_service.dart).
const _allWeaponIds = [
  'star_blaster', 'flame_sword', 'ice_hammer',
  'lightning_wand', 'vine_whip', 'cosmic_burst',
];

/// 10 world IDs from WorldService.allWorlds (world_service.dart).
const _allWorldIds = [
  'candy_crater', 'slime_swamp', 'sugar_volcano',
  'shadow_nebula', 'cavity_fortress',
  'frozen_tundra', 'toxic_jungle', 'crystal_cave',
  'storm_citadel', 'dark_dimension',
];

// ---------------------------------------------------------------------------
// Helper: locate the project root (assets/audio/ directory).
// `flutter test` runs from the project root, but we also handle the case
// where cwd is something else by walking up from the test file location.
// ---------------------------------------------------------------------------
String _projectRoot() {
  // flutter test always sets cwd to the project root.
  final candidate = Directory.current.path;
  if (Directory('$candidate/assets/audio').existsSync()) {
    return candidate;
  }
  // Fallback: walk up from current directory.
  var dir = Directory.current;
  while (dir.parent.path != dir.path) {
    if (Directory('${dir.path}/assets/audio').existsSync()) {
      return dir.path;
    }
    dir = dir.parent;
  }
  throw StateError('Could not locate project root with assets/audio/');
}

/// Returns the expected on-disk path for a file in the preload list.
/// Voice files (voice_*) live under voices/classic/; SFX/music stay at root.
String _audioFilePath(String audioDir, String fileName) {
  if (fileName.startsWith('voice_')) {
    return '$audioDir/voices/classic/$fileName';
  }
  return '$audioDir/$fileName';
}

void main() {
  late String root;
  late String audioDir;

  setUpAll(() {
    root = _projectRoot();
    audioDir = '$root/assets/audio';
  });

  // -----------------------------------------------------------------------
  // 1. Every file in the preload list exists on disk.
  // -----------------------------------------------------------------------
  group('Preload list files exist on disk', () {
    for (final file in _allAudioFiles) {
      test('$file exists', () {
        final path = _audioFilePath(audioDir, file);
        expect(
          File(path).existsSync(),
          isTrue,
          reason: 'Missing audio file: $path',
        );
      });
    }
  });

  // -----------------------------------------------------------------------
  // 2. Dynamic voice files exist for all cards, heroes, weapons, and worlds.
  // -----------------------------------------------------------------------
  group('Dynamic voice files exist', () {
    group('Monster card voices (voice_card_{id}.mp3) — 70 cards', () {
      for (final cardId in _allCardIds) {
        final fileName = 'voice_card_$cardId.mp3';
        test(fileName, () {
          final path = _audioFilePath(audioDir, fileName);
          expect(
            File(path).existsSync(),
            isTrue,
            reason: 'Missing card voice: $path',
          );
        });
      }
    });

    group('Hero intro voices (voice_intro_hero_{id}.mp3) — 6 heroes', () {
      for (final heroId in _allHeroIds) {
        final fileName = 'voice_intro_hero_$heroId.mp3';
        test(fileName, () {
          final path = _audioFilePath(audioDir, fileName);
          expect(
            File(path).existsSync(),
            isTrue,
            reason: 'Missing hero intro voice: $path',
          );
        });
      }
    });

    group('Hero picker voices (voice_picker_hero_{id}.mp3) — 6 heroes', () {
      for (final heroId in _allHeroIds) {
        final fileName = 'voice_picker_hero_$heroId.mp3';
        test(fileName, () {
          final path = _audioFilePath(audioDir, fileName);
          expect(
            File(path).existsSync(),
            isTrue,
            reason: 'Missing hero picker voice: $path',
          );
        });
      }
    });

    group('Weapon intro voices (voice_intro_weapon_{id}.mp3) — 6 weapons', () {
      for (final weaponId in _allWeaponIds) {
        final fileName = 'voice_intro_weapon_$weaponId.mp3';
        test(fileName, () {
          final path = _audioFilePath(audioDir, fileName);
          expect(
            File(path).existsSync(),
            isTrue,
            reason: 'Missing weapon intro voice: $path',
          );
        });
      }
    });

    group('Weapon picker voices (voice_picker_weapon_{id}.mp3) — 6 weapons', () {
      for (final weaponId in _allWeaponIds) {
        final fileName = 'voice_picker_weapon_$weaponId.mp3';
        test(fileName, () {
          final path = _audioFilePath(audioDir, fileName);
          expect(
            File(path).existsSync(),
            isTrue,
            reason: 'Missing weapon picker voice: $path',
          );
        });
      }
    });

    group('World voices (voice_world_{id}.mp3) — 10 worlds', () {
      for (final worldId in _allWorldIds) {
        final fileName = 'voice_world_$worldId.mp3';
        test(fileName, () {
          final path = _audioFilePath(audioDir, fileName);
          expect(
            File(path).existsSync(),
            isTrue,
            reason: 'Missing world voice: $path',
          );
        });
      }
    });
  });

  // -----------------------------------------------------------------------
  // 3. No duplicates in the preload list.
  // -----------------------------------------------------------------------
  test('Preload list has no duplicate entries', () {
    final asSet = _allAudioFiles.toSet();
    final duplicates = <String>[];
    final seen = <String>{};
    for (final f in _allAudioFiles) {
      if (!seen.add(f)) {
        duplicates.add(f);
      }
    }
    expect(
      asSet.length,
      equals(_allAudioFiles.length),
      reason: 'Duplicate files in preload list: $duplicates',
    );
  });

  // -----------------------------------------------------------------------
  // 4. All audio files are non-zero size (> 1024 bytes).
  // -----------------------------------------------------------------------
  group('All .mp3 files in assets/audio/ are > 1024 bytes', () {
    test('no tiny or empty audio files', () {
      // Check SFX/music in audio root and voice files in voices/classic/
      final dirsToCheck = [
        Directory(audioDir),
        Directory('$audioDir/voices/classic'),
      ];
      final tooSmall = <String>[];
      for (final dir in dirsToCheck) {
        if (!dir.existsSync()) continue;
        for (final entity in dir.listSync()) {
          if (entity is File && entity.path.endsWith('.mp3')) {
            final size = entity.lengthSync();
            if (size <= 1024) {
              tooSmall.add(
                '${entity.uri.pathSegments.last} (${size}B)',
              );
            }
          }
        }
      }
      expect(
        tooSmall,
        isEmpty,
        reason: 'Audio files <= 1024 bytes (likely corrupt): $tooSmall',
      );
    });
  });

  // -----------------------------------------------------------------------
  // 5. Identify orphaned audio files (on disk but not in the preload list).
  //    This test PRINTS orphans but does NOT fail — they may be intentional
  //    (e.g. legacy files, wav variants, alternate music tracks).
  // -----------------------------------------------------------------------
  test('Report orphaned audio files (informational, does not fail)', () {
    final preloadSet = _allAudioFiles.toSet();
    final orphans = <String>[];
    // Check SFX/music root for non-voice orphans
    final rootDir = Directory(audioDir);
    for (final entity in rootDir.listSync()) {
      if (entity is File) {
        final name = entity.uri.pathSegments.last;
        if (!preloadSet.contains(name)) {
          orphans.add(name);
        }
      }
    }
    // Check voices/classic/ for voice orphans
    final voiceDir = Directory('$audioDir/voices/classic');
    if (voiceDir.existsSync()) {
      for (final entity in voiceDir.listSync()) {
        if (entity is File) {
          final name = entity.uri.pathSegments.last;
          if (!preloadSet.contains(name)) {
            orphans.add('voices/classic/$name');
          }
        }
      }
    }
    if (orphans.isNotEmpty) {
      // ignore: avoid_print
      print('\n--- Orphaned audio files (not in preload list) ---');
      for (final o in orphans..sort()) {
        // ignore: avoid_print
        print('  $o');
      }
      // ignore: avoid_print
      print('--- ${orphans.length} orphaned file(s) total ---\n');
    }
    // Intentionally does not fail — just informational.
    expect(true, isTrue);
  });
}

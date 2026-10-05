// test/services/unlock_service_test.dart
import 'package:brush_quest/services/analytics_service.dart';
import 'package:brush_quest/services/goal_service.dart';
import 'package:brush_quest/services/hero_service.dart';
import 'package:brush_quest/services/unlock_service.dart';
import 'package:brush_quest/services/weapon_service.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Records the events the unlock steps send. AnalyticsService only reaches
/// FirebaseAnalytics on Android (it is a no-op on iOS and on the test host),
/// so the tests below inject an Android-mode service around this fake.
class _RecordingAnalytics extends Fake implements FirebaseAnalytics {
  final List<Map<String, Object?>> events = [];

  @override
  Future<void> setAnalyticsCollectionEnabled(bool enabled) async {}

  @override
  Future<void> setConsent({
    bool? adStorageConsentGranted,
    bool? analyticsStorageConsentGranted,
    bool? adPersonalizationSignalsConsentGranted,
    bool? adUserDataConsentGranted,
    bool? functionalityStorageConsentGranted,
    bool? personalizationStorageConsentGranted,
    bool? securityStorageConsentGranted,
  }) async {}

  @override
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
    AnalyticsCallOptions? callOptions,
  }) async {
    events.add({'name': name, ...?parameters});
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final unlock = UnlockService();

  Future<int> wallet() async =>
      (await SharedPreferences.getInstance()).getInt('star_wallet') ?? 0;

  test('hero: spends, unlocks and selects', () async {
    SharedPreferences.setMockInitialValues({'star_wallet': 7});
    expect(await unlock.unlockHero('frost'), isTrue);
    expect(await wallet(), 2);
    expect(await HeroService().getSelectedHeroId(), 'frost');
    expect(await HeroService().isHeroUnlocked('frost'), isTrue);
  });

  test('hero: not enough stars -> false, nothing changes', () async {
    SharedPreferences.setMockInitialValues({'star_wallet': 4});
    expect(await unlock.unlockHero('frost'), isFalse);
    expect(await wallet(), 4);
    expect(await HeroService().getSelectedHeroId(), 'blaze');
  });

  test('evolution of the selected hero is equipped', () async {
    SharedPreferences.setMockInitialValues({
      'star_wallet': 10,
      'selected_hero': 'blaze',
    });
    expect(await unlock.unlockEvolution('blaze_stage2'), isTrue);
    expect(await wallet(), 0);
    expect(await HeroService().getEvolutionStage('blaze'), 2);
  });

  test(
    'evolution of another hero is bought but not equipped (shop rule)',
    () async {
      SharedPreferences.setMockInitialValues({
        'star_wallet': 12,
        'selected_hero': 'blaze',
        'unlocked_heroes': ['blaze', 'frost'],
      });
      expect(await unlock.unlockEvolution('frost_stage2'), isTrue);
      expect(await HeroService().getEvolutionStage('frost'), 1);
      expect(await HeroService().getSelectedHeroId(), 'blaze');
    },
  );

  test('weapon: spends, unlocks and selects', () async {
    SharedPreferences.setMockInitialValues({'star_wallet': 5});
    expect(await unlock.unlockWeapon('flame_sword'), isTrue);
    expect(await wallet(), 0);
    expect(await WeaponService().getSelectedWeaponId(), 'flame_sword');
  });

  test('unlockGoal routes by category; worlds are never bought', () async {
    SharedPreferences.setMockInitialValues({'star_wallet': 10});
    const evo = Goal(
      category: GoalCategory.hero,
      itemId: 'blaze_stage2',
      evolutionHeroId: 'blaze',
      stage: 2,
      cost: 10,
      have: 10,
    );
    expect(await unlock.unlockGoal(evo), isTrue);
    const world = Goal(
      category: GoalCategory.world,
      itemId: 'slime_swamp',
      cost: 5,
      have: 5,
    );
    expect(await unlock.unlockGoal(world), isFalse);
  });

  test('double unlock spends once', () async {
    SharedPreferences.setMockInitialValues({'star_wallet': 10});
    final results = await Future.wait([
      unlock.unlockHero('frost'),
      unlock.unlockHero('frost'),
    ]);
    expect(results.where((r) => r).length, greaterThanOrEqualTo(1));
    expect(await wallet(), 5); // spent exactly once
  });

  // ── Beyond the brief ────────────────────────────────────────────────

  test(
    'unknown evolution ids give null and false, never a StateError',
    () async {
      // HeroService.getEvolutionById used firstWhere without orElse inside an
      // `on Exception` catch, so an unknown id threw StateError (an Error).
      expect(HeroService.getEvolutionById('blaze_stage4'), isNull);
      expect(await UnlockService().unlockEvolution('nope_stage2'), isFalse);
    },
  );

  test('every known evolution id resolves to itself', () {
    for (final evo in HeroService.allEvolutions) {
      expect(evo.id, '${evo.heroId}_stage${evo.stage}');
      expect(HeroService.getEvolutionById(evo.id), same(evo));
    }
  });

  test('unknown hero and weapon ids are refused', () async {
    SharedPreferences.setMockInitialValues({'star_wallet': 50});
    expect(await unlock.unlockHero('nobody'), isFalse);
    expect(await unlock.unlockWeapon('nothing'), isFalse);
    expect(await wallet(), 50);
  });

  test('weapon: not enough stars -> false, nothing changes', () async {
    SharedPreferences.setMockInitialValues({'star_wallet': 4});
    expect(await unlock.unlockWeapon('flame_sword'), isFalse);
    expect(await wallet(), 4);
    expect(await WeaponService().getSelectedWeaponId(), 'star_blaster');
  });

  test('stage 3 is refused until stage 2 is owned (nothing spent)', () async {
    SharedPreferences.setMockInitialValues({'star_wallet': 50});
    expect(await unlock.unlockEvolution('blaze_stage3'), isFalse);
    expect(await wallet(), 50);
    expect(await HeroService().getEvolutionStage('blaze'), 1);
  });

  test('an unknown saved hero counts as Blaze, as it did in the shop', () async {
    // The shop asked getSelectedHero(), which falls back to Blaze for an id it
    // doesn't know, and Home draws that same Blaze. Keep the same answer so a
    // bought Blaze stage is equipped rather than left off.
    SharedPreferences.setMockInitialValues({
      'star_wallet': 10,
      'selected_hero': 'ghost',
    });
    expect(await unlock.unlockEvolution('blaze_stage2'), isTrue);
    expect(await HeroService().getEvolutionStage('blaze'), 2);
  });

  test('unlockGoal buys hero and weapon goals too', () async {
    SharedPreferences.setMockInitialValues({'star_wallet': 12});
    const hero = Goal(
      category: GoalCategory.hero,
      itemId: 'frost',
      cost: 5,
      have: 12,
    );
    const weapon = Goal(
      category: GoalCategory.weapon,
      itemId: 'flame_sword',
      cost: 5,
      have: 12,
    );
    expect(await unlock.unlockGoal(hero), isTrue);
    expect(await unlock.unlockGoal(weapon), isTrue);
    expect(await wallet(), 2);
    expect(await HeroService().getSelectedHeroId(), 'frost');
    expect(await WeaponService().getSelectedWeaponId(), 'flame_sword');
  });

  group('analytics (same events the shop sent)', () {
    late _RecordingAnalytics recorder;
    late UnlockService tracked;

    setUp(() async {
      recorder = _RecordingAnalytics();
      final analytics = AnalyticsService.forTesting(
        isAndroid: true,
        analytics: recorder,
      );
      await analytics.init();
      tracked = UnlockService(analytics: analytics);
    });

    test('hero_unlock carries the Ranger Rank, not the wallet', () async {
      SharedPreferences.setMockInitialValues({
        'star_wallet': 7,
        'total_stars': 123,
      });
      expect(await tracked.unlockHero('frost'), isTrue);
      expect(recorder.events, [
        {'name': 'hero_unlock', 'hero_id': 'frost', 'stars_at_unlock': 123},
      ]);
    });

    test('weapon_unlock carries the Ranger Rank, not the wallet', () async {
      SharedPreferences.setMockInitialValues({
        'star_wallet': 5,
        'total_stars': 77,
      });
      expect(await tracked.unlockWeapon('flame_sword'), isTrue);
      expect(recorder.events, [
        {
          'name': 'weapon_unlock',
          'weapon_id': 'flame_sword',
          'stars_at_unlock': 77,
        },
      ]);
    });

    test('a refused purchase logs nothing', () async {
      SharedPreferences.setMockInitialValues({
        'star_wallet': 1,
        'total_stars': 50,
      });
      expect(await tracked.unlockHero('frost'), isFalse);
      expect(await tracked.unlockWeapon('flame_sword'), isFalse);
      expect(recorder.events, isEmpty);
    });

    test('evolutions log nothing (the shop never did)', () async {
      SharedPreferences.setMockInitialValues({
        'star_wallet': 10,
        'total_stars': 50,
      });
      expect(await tracked.unlockEvolution('blaze_stage2'), isTrue);
      expect(recorder.events, isEmpty);
    });
  });
}

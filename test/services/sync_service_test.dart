import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tests for the data transformation and merge logic used by SyncService.
///
/// Since SyncService's methods require Firebase (Auth + Firestore), we test
/// the underlying logic patterns directly:
/// - Which SharedPreferences keys are sync-eligible
/// - Writing typed values back to SharedPreferences
/// - Progress score calculation (determines which side "wins" in smart merge)
/// - Round-trip data integrity
///
/// The scoring formula and key filtering are extracted from SyncService source.

// ── Extracted constants matching SyncService._syncKeys ──
const _syncKeys = [
  'total_stars',
  'current_streak',
  'best_streak',
  'last_brush_date',
  'today_brush_count',
  'today_date',
  'total_brushes',
  'unlocked_heroes',
  'selected_hero',
  'unlocked_weapons',
  'selected_weapon',
  'current_world',
  'morning_done_date',
  'evening_done_date',
  'phase_duration',
  'camera_enabled',
  'muted',
  'onboarding_completed',
  'collected_cards',
  'last_greeting_date',
  'voice_style',
  'star_wallet',
  'trophy_captured',
];
const _prefixSyncKeys = ['world_progress_', 'achievement_', 'card_dup_count_', 'trophy_defeats_'];

/// Mirrors SyncService._shouldSyncKey
bool shouldSyncKey(String key) {
  if (_syncKeys.contains(key)) return true;
  if (key == 'brush_history') return true;
  return _prefixSyncKeys.any((prefix) => key.startsWith(prefix));
}

/// Mirrors SyncService._writeValue
Future<void> writeValue(SharedPreferences prefs, String key, dynamic val) async {
  if (val is int) {
    await prefs.setInt(key, val);
  } else if (val is String) {
    await prefs.setString(key, val);
  } else if (val is bool) {
    await prefs.setBool(key, val);
  } else if (val is double) {
    await prefs.setDouble(key, val);
  } else if (val is List) {
    final stringList = val.whereType<String>().toList();
    await prefs.setStringList(key, stringList);
  }
}

/// Mirrors SyncService._progressScoreFromPrefs
int progressScoreFromPrefs(SharedPreferences prefs) {
  final brushes = prefs.getInt('total_brushes') ?? 0;
  final stars = prefs.getInt('total_stars') ?? 0;
  final heroes = (prefs.getStringList('unlocked_heroes') ?? const []).length;
  final weapons = (prefs.getStringList('unlocked_weapons') ?? const []).length;
  final trophies = (prefs.getStringList('trophy_captured') ?? const []).length;
  final keys = prefs.getKeys();
  final achievements = keys
      .where((k) => k.startsWith('achievement_') && (prefs.getBool(k) ?? false))
      .length;
  final worldProgress = keys
      .where((k) => k.startsWith('world_progress_'))
      .fold<int>(0, (acc, key) => acc + (prefs.getInt(key) ?? 0));
  return brushes * 8 + stars * 5 + heroes * 30 + weapons * 20 + achievements * 15 + worldProgress * 3 + trophies * 25;
}

/// Mirrors SyncService._progressScoreFromCloud
int progressScoreFromCloud(Map<String, dynamic> cloudData) {
  int sumWorldProgress = 0;
  int achievements = 0;
  cloudData.forEach((key, value) {
    if (key.startsWith('world_progress_') && value is int) {
      sumWorldProgress += value;
    }
    if (key.startsWith('achievement_') && value == true) {
      achievements++;
    }
  });
  final brushes = (cloudData['total_brushes'] as int?) ?? 0;
  final stars = (cloudData['total_stars'] as int?) ?? 0;
  final heroes =
      (cloudData['unlocked_heroes'] is List) ? (cloudData['unlocked_heroes'] as List).length : 0;
  final weapons =
      (cloudData['unlocked_weapons'] is List) ? (cloudData['unlocked_weapons'] as List).length : 0;
  final trophies =
      (cloudData['trophy_captured'] is List) ? (cloudData['trophy_captured'] as List).length : 0;
  return brushes * 8 + stars * 5 + heroes * 30 + weapons * 20 + achievements * 15 + sumWorldProgress * 3 + trophies * 25;
}

/// Mirrors SyncService's buildLocalData pattern (from uploadProgress)
Map<String, dynamic> buildLocalData(SharedPreferences prefs) {
  final data = <String, dynamic>{};
  final keys = prefs.getKeys();
  for (final key in keys) {
    if (shouldSyncKey(key)) {
      final val = prefs.get(key);
      if (val != null) data[key] = val;
    }
  }
  final historyJson = prefs.getStringList('brush_history') ?? [];
  data['brush_history'] = historyJson;
  return data;
}

/// Mirrors SyncService's applyData pattern (from downloadProgress)
Future<void> applyData(SharedPreferences prefs, Map<String, dynamic> data) async {
  for (final entry in data.entries) {
    if (!shouldSyncKey(entry.key)) continue;
    await writeValue(prefs, entry.key, entry.value);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SyncService key filtering (shouldSyncKey)', () {
    test('recognizes all direct sync keys', () {
      for (final key in _syncKeys) {
        expect(shouldSyncKey(key), isTrue, reason: 'Key "$key" should be synced');
      }
    });

    test('recognizes brush_history', () {
      expect(shouldSyncKey('brush_history'), isTrue);
    });

    test('recognizes prefixed keys', () {
      expect(shouldSyncKey('world_progress_candy_crater'), isTrue);
      expect(shouldSyncKey('world_progress_slime_swamp'), isTrue);
      expect(shouldSyncKey('achievement_first_brush'), isTrue);
      expect(shouldSyncKey('achievement_streak_3'), isTrue);
      expect(shouldSyncKey('card_dup_count_cc_01'), isTrue);
      expect(shouldSyncKey('trophy_defeats_cc_t1'), isTrue);
    });

    test('rejects non-sync keys', () {
      expect(shouldSyncKey('flutter.'), isFalse);
      expect(shouldSyncKey('random_key'), isFalse);
      expect(shouldSyncKey('last_sync'), isFalse);
      expect(shouldSyncKey('sync_version'), isFalse);
    });
  });

  group('SyncService writeValue', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('writes int values', () async {
      final prefs = await SharedPreferences.getInstance();
      await writeValue(prefs, 'total_stars', 42);
      expect(prefs.getInt('total_stars'), 42);
    });

    test('writes string values', () async {
      final prefs = await SharedPreferences.getInstance();
      await writeValue(prefs, 'last_brush_date', '2026-03-14');
      expect(prefs.getString('last_brush_date'), '2026-03-14');
    });

    test('writes bool values', () async {
      final prefs = await SharedPreferences.getInstance();
      await writeValue(prefs, 'muted', true);
      expect(prefs.getBool('muted'), true);
    });

    test('writes double values', () async {
      final prefs = await SharedPreferences.getInstance();
      await writeValue(prefs, 'some_double', 3.14);
      expect(prefs.getDouble('some_double'), closeTo(3.14, 0.001));
    });

    test('writes list values (filters to strings)', () async {
      final prefs = await SharedPreferences.getInstance();
      await writeValue(prefs, 'unlocked_heroes', ['hero_1', 'hero_2']);
      expect(prefs.getStringList('unlocked_heroes'), ['hero_1', 'hero_2']);
    });

    test('list with mixed types only keeps strings', () async {
      final prefs = await SharedPreferences.getInstance();
      // Simulate cloud data that might have mixed types
      await writeValue(prefs, 'unlocked_heroes', ['hero_1', 42, 'hero_2', true]);
      expect(prefs.getStringList('unlocked_heroes'), ['hero_1', 'hero_2']);
    });
  });

  group('SyncService buildLocalData', () {
    test('collects sync keys from prefs', () async {
      SharedPreferences.setMockInitialValues({
        'total_stars': 10,
        'total_brushes': 5,
        'current_streak': 3,
        'best_streak': 3,
        'last_brush_date': '2026-03-14',
        'selected_hero': 'ranger',
        'muted': false,
      });
      final prefs = await SharedPreferences.getInstance();
      final data = buildLocalData(prefs);

      expect(data['total_stars'], 10);
      expect(data['total_brushes'], 5);
      expect(data['current_streak'], 3);
      expect(data['best_streak'], 3);
      expect(data['last_brush_date'], '2026-03-14');
      expect(data['selected_hero'], 'ranger');
      expect(data['muted'], false);
    });

    test('excludes non-sync keys', () async {
      SharedPreferences.setMockInitialValues({
        'total_stars': 10,
        'flutter.some_internal': 'value',
        'random_key': 42,
      });
      final prefs = await SharedPreferences.getInstance();
      final data = buildLocalData(prefs);

      expect(data.containsKey('total_stars'), isTrue);
      expect(data.containsKey('flutter.some_internal'), isFalse);
      expect(data.containsKey('random_key'), isFalse);
    });

    test('includes prefixed keys (achievements, world progress)', () async {
      SharedPreferences.setMockInitialValues({
        'achievement_first_brush': true,
        'achievement_streak_3': true,
        'world_progress_candy_crater': 7,
        'world_progress_slime_swamp': 3,
      });
      final prefs = await SharedPreferences.getInstance();
      final data = buildLocalData(prefs);

      expect(data['achievement_first_brush'], true);
      expect(data['achievement_streak_3'], true);
      expect(data['world_progress_candy_crater'], 7);
      expect(data['world_progress_slime_swamp'], 3);
    });

    test('includes brush_history as list', () async {
      SharedPreferences.setMockInitialValues({
        'brush_history': ['{"date":"2026-03-14","stars":1}'],
      });
      final prefs = await SharedPreferences.getInstance();
      final data = buildLocalData(prefs);

      expect(data['brush_history'], isA<List>());
      expect((data['brush_history'] as List).length, 1);
    });

    test('brush_history defaults to empty list when missing', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final data = buildLocalData(prefs);

      expect(data['brush_history'], isA<List>());
      expect(data['brush_history'] as List, isEmpty);
    });

    test('includes string list values (unlocked_heroes, unlocked_weapons)', () async {
      SharedPreferences.setMockInitialValues({
        'unlocked_heroes': ['ranger', 'ninja'],
        'unlocked_weapons': ['blaster', 'sword'],
        'collected_cards': ['cc_01', 'cc_02'],
      });
      final prefs = await SharedPreferences.getInstance();
      final data = buildLocalData(prefs);

      expect(data['unlocked_heroes'], ['ranger', 'ninja']);
      expect(data['unlocked_weapons'], ['blaster', 'sword']);
      expect(data['collected_cards'], ['cc_01', 'cc_02']);
    });
  });

  group('SyncService applyData', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('writes all sync-eligible data to prefs', () async {
      final prefs = await SharedPreferences.getInstance();
      final data = <String, dynamic>{
        'total_stars': 15,
        'total_brushes': 8,
        'current_streak': 4,
        'muted': true,
        'selected_hero': 'ninja',
        'last_brush_date': '2026-03-14',
      };
      await applyData(prefs, data);

      expect(prefs.getInt('total_stars'), 15);
      expect(prefs.getInt('total_brushes'), 8);
      expect(prefs.getInt('current_streak'), 4);
      expect(prefs.getBool('muted'), true);
      expect(prefs.getString('selected_hero'), 'ninja');
      expect(prefs.getString('last_brush_date'), '2026-03-14');
    });

    test('skips non-sync keys in cloud data', () async {
      final prefs = await SharedPreferences.getInstance();
      final data = <String, dynamic>{
        'total_stars': 10,
        'last_sync': 'some_timestamp',
        'sync_version': 2,
      };
      await applyData(prefs, data);

      expect(prefs.getInt('total_stars'), 10);
      // These should NOT be written
      expect(prefs.getString('last_sync'), isNull);
      expect(prefs.getInt('sync_version'), isNull);
    });

    test('writes list values correctly', () async {
      final prefs = await SharedPreferences.getInstance();
      final data = <String, dynamic>{
        'unlocked_heroes': ['ranger', 'ninja', 'pirate'],
        'collected_cards': ['cc_01', 'ss_01'],
      };
      await applyData(prefs, data);

      expect(prefs.getStringList('unlocked_heroes'), ['ranger', 'ninja', 'pirate']);
      expect(prefs.getStringList('collected_cards'), ['cc_01', 'ss_01']);
    });
  });

  group('SyncService round-trip (buildLocalData -> applyData)', () {
    test('round-trip preserves int values', () async {
      SharedPreferences.setMockInitialValues({
        'total_stars': 42,
        'total_brushes': 20,
        'current_streak': 5,
        'best_streak': 7,
      });
      final prefs = await SharedPreferences.getInstance();
      final data = buildLocalData(prefs);

      // Clear and reapply
      SharedPreferences.setMockInitialValues({});
      final prefs2 = await SharedPreferences.getInstance();
      await applyData(prefs2, data);

      expect(prefs2.getInt('total_stars'), 42);
      expect(prefs2.getInt('total_brushes'), 20);
      expect(prefs2.getInt('current_streak'), 5);
      expect(prefs2.getInt('best_streak'), 7);
    });

    test('round-trip preserves string values', () async {
      SharedPreferences.setMockInitialValues({
        'last_brush_date': '2026-03-14',
        'today_date': '2026-03-14',
        'selected_hero': 'ninja',
        'selected_weapon': 'sword',
        'current_world': 'slime_swamp',
      });
      final prefs = await SharedPreferences.getInstance();
      final data = buildLocalData(prefs);

      SharedPreferences.setMockInitialValues({});
      final prefs2 = await SharedPreferences.getInstance();
      await applyData(prefs2, data);

      expect(prefs2.getString('last_brush_date'), '2026-03-14');
      expect(prefs2.getString('today_date'), '2026-03-14');
      expect(prefs2.getString('selected_hero'), 'ninja');
      expect(prefs2.getString('selected_weapon'), 'sword');
      expect(prefs2.getString('current_world'), 'slime_swamp');
    });

    test('round-trip preserves bool values', () async {
      SharedPreferences.setMockInitialValues({
        'muted': true,
        'camera_enabled': false,
        'onboarding_completed': true,
        'achievement_first_brush': true,
        'achievement_streak_3': false,
      });
      final prefs = await SharedPreferences.getInstance();
      final data = buildLocalData(prefs);

      SharedPreferences.setMockInitialValues({});
      final prefs2 = await SharedPreferences.getInstance();
      await applyData(prefs2, data);

      expect(prefs2.getBool('muted'), true);
      expect(prefs2.getBool('camera_enabled'), false);
      expect(prefs2.getBool('onboarding_completed'), true);
      expect(prefs2.getBool('achievement_first_brush'), true);
      expect(prefs2.getBool('achievement_streak_3'), false);
    });

    test('round-trip preserves list values', () async {
      SharedPreferences.setMockInitialValues({
        'unlocked_heroes': ['ranger', 'ninja'],
        'unlocked_weapons': ['blaster'],
        'collected_cards': ['cc_01', 'cc_02', 'ss_01'],
        'brush_history': ['{"date":"2026-03-14","stars":1}'],
      });
      final prefs = await SharedPreferences.getInstance();
      final data = buildLocalData(prefs);

      SharedPreferences.setMockInitialValues({});
      final prefs2 = await SharedPreferences.getInstance();
      await applyData(prefs2, data);

      expect(prefs2.getStringList('unlocked_heroes'), ['ranger', 'ninja']);
      expect(prefs2.getStringList('unlocked_weapons'), ['blaster']);
      expect(prefs2.getStringList('collected_cards'), ['cc_01', 'cc_02', 'ss_01']);
      expect(prefs2.getStringList('brush_history'), ['{"date":"2026-03-14","stars":1}']);
    });

    test('round-trip preserves prefixed keys (world progress)', () async {
      SharedPreferences.setMockInitialValues({
        'world_progress_candy_crater': 7,
        'world_progress_slime_swamp': 3,
        'world_progress_sugar_volcano': 0,
      });
      final prefs = await SharedPreferences.getInstance();
      final data = buildLocalData(prefs);

      SharedPreferences.setMockInitialValues({});
      final prefs2 = await SharedPreferences.getInstance();
      await applyData(prefs2, data);

      expect(prefs2.getInt('world_progress_candy_crater'), 7);
      expect(prefs2.getInt('world_progress_slime_swamp'), 3);
      expect(prefs2.getInt('world_progress_sugar_volcano'), 0);
    });

    test('round-trip with comprehensive data set', () async {
      SharedPreferences.setMockInitialValues({
        'total_stars': 50,
        'total_brushes': 30,
        'current_streak': 5,
        'best_streak': 10,
        'last_brush_date': '2026-03-14',
        'today_brush_count': 2,
        'today_date': '2026-03-14',
        'unlocked_heroes': ['ranger', 'ninja', 'pirate'],
        'selected_hero': 'pirate',
        'unlocked_weapons': ['blaster', 'sword'],
        'selected_weapon': 'sword',
        'current_world': 'sugar_volcano',
        'phase_duration': 20,
        'camera_enabled': true,
        'muted': false,
        'onboarding_completed': true,
        'collected_cards': ['cc_01', 'cc_02', 'ss_01'],
        'last_greeting_date': '2026-03-14',
        'voice_style': 'cheerful',
        'star_wallet': 25,
        'trophy_captured': ['cc_t1', 'ss_t1'],
        'achievement_first_brush': true,
        'achievement_streak_3': true,
        'world_progress_candy_crater': 7,
        'world_progress_slime_swamp': 4,
        'trophy_defeats_cc_t2': 1,
        'brush_history': ['{"date":"2026-03-13"}', '{"date":"2026-03-14"}'],
      });
      final prefs = await SharedPreferences.getInstance();
      final data = buildLocalData(prefs);

      SharedPreferences.setMockInitialValues({});
      final prefs2 = await SharedPreferences.getInstance();
      await applyData(prefs2, data);

      expect(prefs2.getInt('total_stars'), 50);
      expect(prefs2.getInt('total_brushes'), 30);
      expect(prefs2.getInt('current_streak'), 5);
      expect(prefs2.getInt('best_streak'), 10);
      expect(prefs2.getString('last_brush_date'), '2026-03-14');
      expect(prefs2.getInt('today_brush_count'), 2);
      expect(prefs2.getString('selected_hero'), 'pirate');
      expect(prefs2.getStringList('unlocked_heroes'), ['ranger', 'ninja', 'pirate']);
      expect(prefs2.getStringList('collected_cards'), ['cc_01', 'cc_02', 'ss_01']);
      expect(prefs2.getBool('achievement_first_brush'), true);
      expect(prefs2.getInt('world_progress_candy_crater'), 7);
      expect(prefs2.getInt('star_wallet'), 25);
      expect(prefs2.getStringList('trophy_captured'), ['cc_t1', 'ss_t1']);
      expect(prefs2.getInt('trophy_defeats_cc_t2'), 1);
      expect(prefs2.getStringList('brush_history'), ['{"date":"2026-03-13"}', '{"date":"2026-03-14"}']);
    });
  });

  group('SyncService progress score (smart merge)', () {
    test('empty prefs gives score 0', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      expect(progressScoreFromPrefs(prefs), 0);
    });

    test('empty cloud data gives score 0', () {
      expect(progressScoreFromCloud({}), 0);
    });

    test('score includes brushes at 8x weight', () async {
      SharedPreferences.setMockInitialValues({'total_brushes': 10});
      final prefs = await SharedPreferences.getInstance();
      expect(progressScoreFromPrefs(prefs), 10 * 8);
    });

    test('score includes stars at 5x weight', () async {
      SharedPreferences.setMockInitialValues({'total_stars': 10});
      final prefs = await SharedPreferences.getInstance();
      expect(progressScoreFromPrefs(prefs), 10 * 5);
    });

    test('score includes heroes at 30x weight', () async {
      SharedPreferences.setMockInitialValues({
        'unlocked_heroes': ['ranger', 'ninja'],
      });
      final prefs = await SharedPreferences.getInstance();
      expect(progressScoreFromPrefs(prefs), 2 * 30);
    });

    test('score includes weapons at 20x weight', () async {
      SharedPreferences.setMockInitialValues({
        'unlocked_weapons': ['blaster', 'sword', 'shield'],
      });
      final prefs = await SharedPreferences.getInstance();
      expect(progressScoreFromPrefs(prefs), 3 * 20);
    });

    test('score includes achievements at 15x weight', () async {
      SharedPreferences.setMockInitialValues({
        'achievement_first_brush': true,
        'achievement_streak_3': true,
        'achievement_streak_7': false, // false should not count
      });
      final prefs = await SharedPreferences.getInstance();
      expect(progressScoreFromPrefs(prefs), 2 * 15);
    });

    test('score includes world progress at 3x weight', () async {
      SharedPreferences.setMockInitialValues({
        'world_progress_candy_crater': 7,
        'world_progress_slime_swamp': 3,
      });
      final prefs = await SharedPreferences.getInstance();
      expect(progressScoreFromPrefs(prefs), (7 + 3) * 3);
    });

    test('comprehensive score calculation matches formula', () async {
      SharedPreferences.setMockInitialValues({
        'total_brushes': 20,
        'total_stars': 40,
        'unlocked_heroes': ['ranger', 'ninja'],
        'unlocked_weapons': ['blaster'],
        'achievement_first_brush': true,
        'achievement_streak_3': true,
        'achievement_streak_7': true,
        'world_progress_candy_crater': 7,
        'world_progress_slime_swamp': 5,
      });
      final prefs = await SharedPreferences.getInstance();
      const expected = 20 * 8 + 40 * 5 + 2 * 30 + 1 * 20 + 3 * 15 + 12 * 3;
      expect(progressScoreFromPrefs(prefs), expected);
    });

    test('cloud score matches prefs score for identical data', () async {
      SharedPreferences.setMockInitialValues({
        'total_brushes': 15,
        'total_stars': 30,
        'unlocked_heroes': ['ranger'],
        'unlocked_weapons': ['blaster', 'sword'],
        'achievement_first_brush': true,
        'world_progress_candy_crater': 7,
      });
      final prefs = await SharedPreferences.getInstance();
      final prefsScore = progressScoreFromPrefs(prefs);

      final cloudData = <String, dynamic>{
        'total_brushes': 15,
        'total_stars': 30,
        'unlocked_heroes': ['ranger'],
        'unlocked_weapons': ['blaster', 'sword'],
        'achievement_first_brush': true,
        'world_progress_candy_crater': 7,
      };
      final cloudScore = progressScoreFromCloud(cloudData);

      expect(prefsScore, cloudScore);
    });

    test('smart merge: higher brushes wins (cloud > local)', () async {
      SharedPreferences.setMockInitialValues({
        'total_brushes': 10,
        'total_stars': 10,
      });
      final prefs = await SharedPreferences.getInstance();
      final localScore = progressScoreFromPrefs(prefs);

      final cloudData = <String, dynamic>{
        'total_brushes': 20,
        'total_stars': 10,
      };
      final cloudScore = progressScoreFromCloud(cloudData);

      expect(cloudScore, greaterThan(localScore));
    });

    test('smart merge: higher stars wins (local > cloud)', () async {
      SharedPreferences.setMockInitialValues({
        'total_brushes': 10,
        'total_stars': 50,
      });
      final prefs = await SharedPreferences.getInstance();
      final localScore = progressScoreFromPrefs(prefs);

      final cloudData = <String, dynamic>{
        'total_brushes': 10,
        'total_stars': 20,
      };
      final cloudScore = progressScoreFromCloud(cloudData);

      expect(localScore, greaterThan(cloudScore));
    });

    test('smart merge: more heroes/weapons wins', () async {
      SharedPreferences.setMockInitialValues({
        'total_brushes': 10,
        'total_stars': 10,
        'unlocked_heroes': ['ranger'],
        'unlocked_weapons': ['blaster'],
      });
      final prefs = await SharedPreferences.getInstance();
      final localScore = progressScoreFromPrefs(prefs);

      final cloudData = <String, dynamic>{
        'total_brushes': 10,
        'total_stars': 10,
        'unlocked_heroes': ['ranger', 'ninja', 'pirate'],
        'unlocked_weapons': ['blaster', 'sword', 'shield'],
      };
      final cloudScore = progressScoreFromCloud(cloudData);

      expect(cloudScore, greaterThan(localScore));
    });

    test('smart merge: more achievements wins', () async {
      SharedPreferences.setMockInitialValues({
        'achievement_first_brush': true,
      });
      final prefs = await SharedPreferences.getInstance();
      final localScore = progressScoreFromPrefs(prefs);

      final cloudData = <String, dynamic>{
        'achievement_first_brush': true,
        'achievement_streak_3': true,
        'achievement_streak_7': true,
      };
      final cloudScore = progressScoreFromCloud(cloudData);

      expect(cloudScore, greaterThan(localScore));
    });

    test('smart merge: more world progress wins', () async {
      SharedPreferences.setMockInitialValues({
        'world_progress_candy_crater': 3,
      });
      final prefs = await SharedPreferences.getInstance();
      final localScore = progressScoreFromPrefs(prefs);

      final cloudData = <String, dynamic>{
        'world_progress_candy_crater': 7,
        'world_progress_slime_swamp': 5,
      };
      final cloudScore = progressScoreFromCloud(cloudData);

      expect(cloudScore, greaterThan(localScore));
    });

    test('cloud score handles missing fields gracefully', () {
      final cloudData = <String, dynamic>{
        'last_sync': 'some_timestamp', // not scored
        'sync_version': 2, // not scored
      };
      expect(progressScoreFromCloud(cloudData), 0);
    });

    test('cloud score handles non-list heroes/weapons', () {
      final cloudData = <String, dynamic>{
        'unlocked_heroes': 'not_a_list',
        'unlocked_weapons': 42,
      };
      // Should not crash, heroes/weapons count as 0
      expect(progressScoreFromCloud(cloudData), 0);
    });
  });
}

import 'package:shared_preferences/shared_preferences.dart';
import 'streak_service.dart';

class WeeklyMission {
  final String id;
  final String title;
  final int target;
  final int rewardStars;
  final int progress;
  final bool claimed;

  const WeeklyMission({
    required this.id,
    required this.title,
    required this.target,
    required this.rewardStars,
    required this.progress,
    required this.claimed,
  });

  bool get completed => progress >= target;
}

class MissionService {
  static const _prefix = 'mission_';
  static const _sessionId = 'weekly_sessions';
  static const _chestId = 'weekly_chests';
  static const _monsterId = 'weekly_monsters';

  static const _definitions = [
    (_sessionId, 'COMPLETE 10 BRUSH MISSIONS', 10, 8),
    (_chestId, 'OPEN 8 TREASURE CHESTS', 8, 6),
    (_monsterId, 'DEFEAT 40 MONSTERS', 40, 10),
  ];

  Future<List<WeeklyMission>> getWeeklyMissions() async {
    final prefs = await SharedPreferences.getInstance();
    final weekKey = _weekKey();
    final missions = <WeeklyMission>[];
    for (final def in _definitions) {
      final id = def.$1;
      final progress = prefs.getInt('$_prefix${weekKey}_${id}_progress') ?? 0;
      final claimed =
          prefs.getBool('$_prefix${weekKey}_${id}_claimed') ?? false;
      missions.add(
        WeeklyMission(
          id: id,
          title: def.$2,
          target: def.$3,
          rewardStars: def.$4,
          progress: progress,
          claimed: claimed,
        ),
      );
    }
    return missions;
  }

  Future<void> recordBrushSession({required int monstersDefeated}) async {
    await _increment(_sessionId, 1);
    if (monstersDefeated > 0) {
      await _increment(_monsterId, monstersDefeated);
    }
  }

  Future<void> recordChestOpened() async {
    await _increment(_chestId, 1);
  }

  Future<int> claimMissionReward(String missionId) async {
    final missions = await getWeeklyMissions();
    final mission = missions.where((m) => m.id == missionId).toList();
    if (mission.isEmpty) return 0;
    final m = mission.first;
    if (!m.completed || m.claimed) return 0;

    final prefs = await SharedPreferences.getInstance();
    final weekKey = _weekKey();
    await prefs.setBool('$_prefix${weekKey}_${missionId}_claimed', true);
    await StreakService().addBonusStars(m.rewardStars);
    return m.rewardStars;
  }

  Future<void> _increment(String missionId, int amount) async {
    final prefs = await SharedPreferences.getInstance();
    final weekKey = _weekKey();
    final progressKey = '$_prefix${weekKey}_${missionId}_progress';
    final current = prefs.getInt(progressKey) ?? 0;
    await prefs.setInt(progressKey, current + amount);
  }

  String _weekKey() {
    final now = DateTime.now();
    final monday = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));
    return '${monday.year}-${monday.month.toString().padLeft(2, '0')}-${monday.day.toString().padLeft(2, '0')}';
  }
}

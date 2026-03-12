import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum DailyRewardType { fragment, bonusStar }

class DailyLoginReward {
  final DailyRewardType type;
  final int amount;
  final String label;
  final IconData icon;
  final Color color;

  const DailyLoginReward({
    required this.type,
    required this.amount,
    required this.label,
    required this.icon,
    required this.color,
  });
}

class DailyLoginService {
  static const _lastLoginDateKey = 'daily_login_date';
  static const _loginStreakKey = 'daily_login_streak';
  static const _lastLoginEpochKey = 'last_login_epoch';

  /// Check if the user has already claimed today's login.
  /// Returns a reward if not yet claimed, null if already claimed today.
  Future<DailyLoginReward?> checkAndClaimDailyLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final nowEpoch = now.millisecondsSinceEpoch;
    final today = _dateString(now);
    final lastLogin = prefs.getString(_lastLoginDateKey);

    if (lastLogin == today) return null; // Already claimed

    // Reject if clock went backwards (manipulation attempt)
    final lastEpoch = prefs.getInt(_lastLoginEpochKey) ?? 0;
    if (nowEpoch < lastEpoch) return null;

    // Update streak
    final yesterday = _dateString(
      now.subtract(const Duration(days: 1)),
    );
    int streak = prefs.getInt(_loginStreakKey) ?? 0;
    if (lastLogin == yesterday) {
      streak++;
    } else {
      streak = 1; // Reset, no punishment
    }

    await prefs.setString(_lastLoginDateKey, today);
    await prefs.setInt(_loginStreakKey, streak);
    await prefs.setInt(_lastLoginEpochKey, nowEpoch);

    // Roll reward
    final rng = Random();
    if (rng.nextDouble() < 0.6) {
      // 60% card fragment
      final fragmentCount = prefs.getInt('card_fragments') ?? 0;
      await prefs.setInt('card_fragments', fragmentCount + 1);
      return const DailyLoginReward(
        type: DailyRewardType.fragment,
        amount: 1,
        label: 'CARD FRAGMENT',
        icon: Icons.auto_awesome_mosaic,
        color: Color(0xFFFFD54F),
      );
    } else {
      // 40% bonus star
      final stars = prefs.getInt('total_stars') ?? 0;
      await prefs.setInt('total_stars', stars + 1);
      return const DailyLoginReward(
        type: DailyRewardType.bonusStar,
        amount: 1,
        label: 'BONUS STAR',
        icon: Icons.star,
        color: Color(0xFFFFD54F),
      );
    }
  }

  Future<int> getLoginStreak() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_loginStreakKey) ?? 0;
  }

  String _dateString(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
}

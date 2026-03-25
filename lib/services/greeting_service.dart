import 'package:shared_preferences/shared_preferences.dart';

enum GreetingState {
  justStarted,
  streak2to4,
  streak5to9,
  streak10to19,
  streak20plus,
  returning,
}

class GreetingResult {
  final GreetingState state;
  final String voiceFile;
  final int brushStreak;
  final String? teaseItemName;
  final int? teaseStarsAway;
  final String? teaseItemId;
  final String? teaseItemImagePath;
  final int? teaseItemUnlockAt;
  final int wallet;

  const GreetingResult({
    required this.state,
    required this.voiceFile,
    required this.brushStreak,
    required this.wallet,
    this.teaseItemName,
    this.teaseStarsAway,
    this.teaseItemId,
    this.teaseItemImagePath,
    this.teaseItemUnlockAt,
  });
}

class GreetingService {
  static const _lastGreetingDateKey = 'last_greeting_date';

  static const _voicePools = <GreetingState, List<String>>{
    GreetingState.justStarted: [
      'voice_greet_just_started_1.mp3',
      'voice_greet_just_started_2.mp3',
      'voice_greet_just_started_3.mp3',
    ],
    GreetingState.streak2to4: [
      'voice_greet_streak_low_1.mp3',
      'voice_greet_streak_low_2.mp3',
    ],
    GreetingState.streak5to9: [
      'voice_greet_streak_mid_1.mp3',
      'voice_greet_streak_mid_2.mp3',
    ],
    GreetingState.streak10to19: [
      'voice_greet_streak_high_1.mp3',
      'voice_greet_streak_high_2.mp3',
    ],
    GreetingState.streak20plus: [
      'voice_greet_streak_legend_1.mp3',
      'voice_greet_streak_legend_2.mp3',
    ],
    GreetingState.returning: [
      'voice_greet_returning_1.mp3',
      'voice_greet_returning_2.mp3',
      'voice_greet_returning_excited_1.mp3',
      'voice_greet_returning_excited_2.mp3',
    ],
  };

  /// Check if a greeting should be shown.
  /// Returns null if already greeted today or if user has no brushes.
  /// All data is passed in — this service does no internal fetching.
  GreetingResult? checkGreeting({
    required int totalBrushes,
    required int brushStreak,
    required int wallet,
    required String? nextHeroName,
    required int? nextHeroUnlockAt,
    required String? nextWeaponName,
    required int? nextWeaponUnlockAt,
    required String todayDate,
    required String? lastGreetingDate,
    String? nextHeroId,
    String? nextHeroImagePath,
    String? nextWeaponId,
    String? nextWeaponImagePath,
  }) {
    // Already greeted today
    if (lastGreetingDate == todayDate) return null;
    // No brushes yet — don't greet
    if (totalBrushes == 0) return null;

    final state = _classifyState(totalBrushes, brushStreak);
    final pool = _voicePools[state]!;
    // Pick voice based on day to vary without randomness
    final voiceFile = pool[totalBrushes % pool.length];

    // Tease: show whichever unlock is closer
    String? teaseItemName;
    int? teaseStarsAway;
    String? teaseItemId;
    String? teaseItemImagePath;
    int? teaseItemUnlockAt;
    final heroDistance = (nextHeroUnlockAt != null) ? nextHeroUnlockAt - wallet : null;
    final weaponDistance = (nextWeaponUnlockAt != null) ? nextWeaponUnlockAt - wallet : null;

    if (heroDistance != null && heroDistance > 0 && weaponDistance != null && weaponDistance > 0) {
      if (weaponDistance <= heroDistance) {
        teaseItemName = nextWeaponName;
        teaseStarsAway = weaponDistance;
        teaseItemId = nextWeaponId;
        teaseItemImagePath = nextWeaponImagePath;
        teaseItemUnlockAt = nextWeaponUnlockAt;
      } else {
        teaseItemName = nextHeroName;
        teaseStarsAway = heroDistance;
        teaseItemId = nextHeroId;
        teaseItemImagePath = nextHeroImagePath;
        teaseItemUnlockAt = nextHeroUnlockAt;
      }
    } else if (heroDistance != null && heroDistance > 0) {
      teaseItemName = nextHeroName;
      teaseStarsAway = heroDistance;
      teaseItemId = nextHeroId;
      teaseItemImagePath = nextHeroImagePath;
      teaseItemUnlockAt = nextHeroUnlockAt;
    } else if (weaponDistance != null && weaponDistance > 0) {
      teaseItemName = nextWeaponName;
      teaseStarsAway = weaponDistance;
      teaseItemId = nextWeaponId;
      teaseItemImagePath = nextWeaponImagePath;
      teaseItemUnlockAt = nextWeaponUnlockAt;
    }

    return GreetingResult(
      state: state,
      voiceFile: voiceFile,
      brushStreak: brushStreak,
      wallet: wallet,
      teaseItemName: teaseItemName,
      teaseStarsAway: teaseStarsAway,
      teaseItemId: teaseItemId,
      teaseItemImagePath: teaseItemImagePath,
      teaseItemUnlockAt: teaseItemUnlockAt,
    );
  }

  /// Persist that greeting was shown today.
  Future<void> markGreetingShown(String todayDate) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastGreetingDateKey, todayDate);
  }

  /// Read the last greeting date from prefs.
  Future<String?> getLastGreetingDate() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastGreetingDateKey);
  }

  GreetingState _classifyState(int totalBrushes, int brushStreak) {
    if (brushStreak >= 20) return GreetingState.streak20plus;
    if (brushStreak >= 10) return GreetingState.streak10to19;
    if (brushStreak >= 5) return GreetingState.streak5to9;
    if (brushStreak >= 2) return GreetingState.streak2to4;
    // Streak is 0 or 1
    if (totalBrushes <= 2) return GreetingState.justStarted;
    return GreetingState.returning;
  }
}

import 'package:shared_preferences/shared_preferences.dart';

enum GreetingState {
  justStarted,
  streak2to4,
  streak5to9,
  streak10to19,
  streak20plus,
  returning,
  freshStart,
}

class GreetingResult {
  final GreetingState state;
  final String voiceFile;
  final int brushStreak;
  final int wallet;
  final bool yesterdayBothDone;
  final int totalBrushes;

  const GreetingResult({
    required this.state,
    required this.voiceFile,
    required this.brushStreak,
    required this.wallet,
    required this.yesterdayBothDone,
    required this.totalBrushes,
  });

  /// True when user is returning after a broken streak (eligible for +3 comeback bonus).
  bool get isComeback => brushStreak == 0 && totalBrushes > 2;
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
    GreetingState.freshStart: [
      'voice_greet_fresh_start.mp3',
      'voice_greet_comeback_1.mp3',
      'voice_greet_comeback_2.mp3',
      'voice_greet_comeback_3.mp3',
    ],
  };

  /// Check if a greeting should be shown.
  /// Returns null if already greeted today or if user has no brushes.
  /// All data is passed in — this service does no internal fetching.
  GreetingResult? checkGreeting({
    required int totalBrushes,
    required int brushStreak,
    required int wallet,
    required String todayDate,
    required String? lastGreetingDate,
    required bool yesterdayBothDone,
  }) {
    // Already greeted today
    if (lastGreetingDate == todayDate) return null;
    // No brushes yet — don't greet
    if (totalBrushes == 0) return null;

    final state = _classifyState(totalBrushes, brushStreak);
    final pool = _voicePools[state]!;
    // Pick voice based on day to vary without randomness
    final voiceFile = pool[totalBrushes % pool.length];

    return GreetingResult(
      state: state,
      voiceFile: voiceFile,
      brushStreak: brushStreak,
      wallet: wallet,
      yesterdayBothDone: yesterdayBothDone,
      totalBrushes: totalBrushes,
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
    // Had brushes before but streak broke — reframe as fresh start
    if (brushStreak == 0) return GreetingState.freshStart;
    return GreetingState.returning;
  }
}

import 'package:firebase_analytics/firebase_analytics.dart';

/// COPPA-compliant Firebase Analytics for a child-directed app.
///
/// - Advertising ID collection disabled (AndroidManifest.xml)
/// - Ad-related consent denied at init
/// - No personally identifiable information logged
/// - Only aggregated behavioral events for product improvement
class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._();
  factory AnalyticsService() => _instance;
  AnalyticsService._();

  final _analytics = FirebaseAnalytics.instance;
  bool _initialized = false;

  /// Call once at app startup, after Firebase.initializeApp().
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // COPPA: deny all ad-related consent, allow analytics storage only.
    await _analytics.setConsent(
      analyticsStorageConsentGranted: true,
      adStorageConsentGranted: false,
      adUserDataConsentGranted: false,
      adPersonalizationSignalsConsentGranted: false,
    );

    await _analytics.setAnalyticsCollectionEnabled(true);
  }

  // ── User properties (set after each brush) ──────────────────────────

  Future<void> setUserProperties({
    required int lifetimeBrushes,
    required int currentStreak,
    required int totalStars,
  }) async {
    await _analytics.setUserProperty(
      name: 'lifetime_brushes',
      value: lifetimeBrushes.toString(),
    );
    await _analytics.setUserProperty(
      name: 'current_streak',
      value: currentStreak.toString(),
    );
    await _analytics.setUserProperty(
      name: 'total_stars',
      value: totalStars.toString(),
    );
  }

  // ── Funnel events ───────────────────────────────────────────────────

  Future<void> logOnboardingComplete() async {
    await _analytics.logEvent(name: 'onboarding_complete');
  }

  Future<void> logBrushSessionStart({
    required String heroId,
    required String weaponId,
    required String worldId,
  }) async {
    await _analytics.logEvent(
      name: 'brush_session_start',
      parameters: {
        'hero_id': heroId,
        'weapon_id': weaponId,
        'world_id': worldId,
      },
    );
  }

  Future<void> logBrushSessionComplete({
    required int totalHits,
    required int monstersDefeated,
    required int starsEarned,
    required int newStreak,
    required int totalStars,
  }) async {
    await _analytics.logEvent(
      name: 'brush_session_complete',
      parameters: {
        'total_hits': totalHits,
        'monsters_defeated': monstersDefeated,
        'stars_earned': starsEarned,
        'streak': newStreak,
        'total_stars': totalStars,
      },
    );
  }

  Future<void> logBrushSessionAbandon({
    required String phase,
    required int secondsRemaining,
    required int totalHits,
  }) async {
    await _analytics.logEvent(
      name: 'brush_session_abandon',
      parameters: {
        'phase': phase,
        'seconds_remaining': secondsRemaining,
        'total_hits': totalHits,
      },
    );
  }

  // ── Engagement events ───────────────────────────────────────────────

  Future<void> logDailyLogin({required int streak}) async {
    await _analytics.logEvent(
      name: 'daily_login',
      parameters: {'streak': streak},
    );
  }

  Future<void> logShopVisit() async {
    await _analytics.logEvent(name: 'shop_visit');
  }

  Future<void> logHeroUnlock({
    required String heroId,
    required int starsAtUnlock,
  }) async {
    await _analytics.logEvent(
      name: 'hero_unlock',
      parameters: {
        'hero_id': heroId,
        'stars_at_unlock': starsAtUnlock,
      },
    );
  }

  Future<void> logWeaponUnlock({
    required String weaponId,
    required int starsAtUnlock,
  }) async {
    await _analytics.logEvent(
      name: 'weapon_unlock',
      parameters: {
        'weapon_id': weaponId,
        'stars_at_unlock': starsAtUnlock,
      },
    );
  }

  Future<void> logSignIn() async {
    await _analytics.logEvent(name: 'sign_in_complete');
  }
}

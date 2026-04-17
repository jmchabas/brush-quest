import 'dart:io';

import 'package:firebase_analytics/firebase_analytics.dart';

class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._();
  factory AnalyticsService() => _instance;
  AnalyticsService._();

  final _analytics = FirebaseAnalytics.instance;
  bool _initialized = false;
  bool _enabled = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // Disable analytics on iOS for v1 to reduce Kids Category rejection risk.
    // Re-enable after first App Store approval.
    _enabled = Platform.isAndroid;
    await _analytics.setAnalyticsCollectionEnabled(_enabled);
    if (!_enabled) return;

    await _analytics.setConsent(
      analyticsStorageConsentGranted: true,
      adStorageConsentGranted: false,
      adUserDataConsentGranted: false,
      adPersonalizationSignalsConsentGranted: false,
    );
  }

  // ── User properties (set after each brush) ──────────────────────────

  Future<void> setUserProperties({
    required int lifetimeBrushes,
    required int currentStreak,
    required int totalStars,
  }) async {
    if (!_enabled) return;
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

  Future<void> logOnboardingComplete() async {
    if (!_enabled) return;
    await _analytics.logEvent(name: 'onboarding_complete');
  }

  Future<void> logBrushSessionStart({
    required String heroId,
    required String weaponId,
    required String worldId,
  }) async {
    if (!_enabled) return;
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
    if (!_enabled) return;
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
    if (!_enabled) return;
    await _analytics.logEvent(
      name: 'brush_session_abandon',
      parameters: {
        'phase': phase,
        'seconds_remaining': secondsRemaining,
        'total_hits': totalHits,
      },
    );
  }

  Future<void> logDailyLogin({required int streak}) async {
    if (!_enabled) return;
    await _analytics.logEvent(
      name: 'daily_login',
      parameters: {'streak': streak},
    );
  }

  Future<void> logShopVisit() async {
    if (!_enabled) return;
    await _analytics.logEvent(name: 'shop_visit');
  }

  Future<void> logHeroUnlock({
    required String heroId,
    required int starsAtUnlock,
  }) async {
    if (!_enabled) return;
    await _analytics.logEvent(
      name: 'hero_unlock',
      parameters: {'hero_id': heroId, 'stars_at_unlock': starsAtUnlock},
    );
  }

  Future<void> logWeaponUnlock({
    required String weaponId,
    required int starsAtUnlock,
  }) async {
    if (!_enabled) return;
    await _analytics.logEvent(
      name: 'weapon_unlock',
      parameters: {'weapon_id': weaponId, 'stars_at_unlock': starsAtUnlock},
    );
  }

  Future<void> logSignIn() async {
    if (!_enabled) return;
    await _analytics.logEvent(name: 'sign_in_complete');
  }
}

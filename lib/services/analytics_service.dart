// CYCLE-PROTECT: This file contains iOS-conditional code for Apple Kids
// Category compliance. firebase_analytics is NOT linked into the iOS binary at
// all (vendored plugin in packages/firebase_analytics with the ios platform
// removed), so any FirebaseAnalytics call on iOS would throw
// MissingPluginException. Every entry point must stay a no-op on iOS. Do not
// auto-remove "unused" imports, methods, or branches without verifying the iOS
// build + scripts/check_ios_kids_binary.sh. See decision_ios_kids_category.md.

import 'dart:io';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._(
    isAndroid: Platform.isAndroid,
  );
  factory AnalyticsService() => _instance;

  /// Android binds `FirebaseAnalytics.instance` at construction, exactly as
  /// before. iOS never touches FirebaseAnalytics (the native SDK isn't in the
  /// binary), so [_analytics] stays null and every method is a no-op.
  AnalyticsService._({required bool isAndroid, FirebaseAnalytics? analytics})
    : _analytics = isAndroid ? (analytics ?? FirebaseAnalytics.instance) : null;

  /// Fresh (non-singleton) instance with an explicit platform, for tests.
  @visibleForTesting
  factory AnalyticsService.forTesting({
    required bool isAndroid,
    FirebaseAnalytics? analytics,
  }) => AnalyticsService._(isAndroid: isAndroid, analytics: analytics);

  final FirebaseAnalytics? _analytics;
  bool _initialized = false;
  bool _enabled = false;

  /// True once [init] has enabled collection (Android only; always false on iOS).
  @visibleForTesting
  bool get isEnabled => _enabled;

  // Only reachable after `if (!_enabled) return;`, and _enabled is only ever
  // set when _analytics is non-null (Android).
  FirebaseAnalytics get _fa => _analytics!;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // iOS: permanently off, and the plugin isn't even linked — Apple Kids
    // Category prohibits third-party analytics SDKs. Don't call anything.
    final analytics = _analytics;
    if (analytics == null) return;

    _enabled = true;
    await analytics.setAnalyticsCollectionEnabled(true);

    await analytics.setConsent(
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
    await _fa.setUserProperty(
      name: 'lifetime_brushes',
      value: lifetimeBrushes.toString(),
    );
    await _fa.setUserProperty(
      name: 'current_streak',
      value: currentStreak.toString(),
    );
    await _fa.setUserProperty(
      name: 'total_stars',
      value: totalStars.toString(),
    );
  }

  Future<void> logOnboardingComplete() async {
    if (!_enabled) return;
    await _fa.logEvent(name: 'onboarding_complete');
  }

  Future<void> logBrushSessionStart({
    required String heroId,
    required String weaponId,
    required String worldId,
  }) async {
    if (!_enabled) return;
    await _fa.logEvent(
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
    await _fa.logEvent(
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
    await _fa.logEvent(
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
    await _fa.logEvent(name: 'daily_login', parameters: {'streak': streak});
  }

  Future<void> logShopVisit() async {
    if (!_enabled) return;
    await _fa.logEvent(name: 'shop_visit');
  }

  Future<void> logHeroUnlock({
    required String heroId,
    required int starsAtUnlock,
  }) async {
    if (!_enabled) return;
    await _fa.logEvent(
      name: 'hero_unlock',
      parameters: {'hero_id': heroId, 'stars_at_unlock': starsAtUnlock},
    );
  }

  Future<void> logWeaponUnlock({
    required String weaponId,
    required int starsAtUnlock,
  }) async {
    if (!_enabled) return;
    await _fa.logEvent(
      name: 'weapon_unlock',
      parameters: {'weapon_id': weaponId, 'stars_at_unlock': starsAtUnlock},
    );
  }

  Future<void> logSignIn() async {
    if (!_enabled) return;
    await _fa.logEvent(name: 'sign_in_complete');
  }
}

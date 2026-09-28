// Apple Kids Category guard: firebase_analytics is not linked into the iOS
// binary (vendored plugin with the ios platform removed), so on iOS the
// AnalyticsService must never touch FirebaseAnalytics. Android must keep the
// exact same calls as before (collection on, ad consent off).

import 'package:brush_quest/services/analytics_service.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingAnalytics extends Fake implements FirebaseAnalytics {
  final List<String> calls = [];

  @override
  Future<void> setAnalyticsCollectionEnabled(bool enabled) async {
    calls.add('setAnalyticsCollectionEnabled($enabled)');
  }

  @override
  Future<void> setConsent({
    bool? adStorageConsentGranted,
    bool? analyticsStorageConsentGranted,
    bool? adPersonalizationSignalsConsentGranted,
    bool? adUserDataConsentGranted,
    bool? functionalityStorageConsentGranted,
    bool? personalizationStorageConsentGranted,
    bool? securityStorageConsentGranted,
  }) async {
    calls.add(
      'setConsent(analytics=$analyticsStorageConsentGranted, '
      'ad=$adStorageConsentGranted, adUserData=$adUserDataConsentGranted, '
      'adPersonalization=$adPersonalizationSignalsConsentGranted)',
    );
  }

  @override
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
    AnalyticsCallOptions? callOptions,
  }) async {
    calls.add('logEvent($name)');
  }

  @override
  Future<void> setUserProperty({
    required String name,
    required String? value,
    AnalyticsCallOptions? callOptions,
  }) async {
    calls.add('setUserProperty($name=$value)');
  }
}

Future<void> _exerciseEveryEntryPoint(AnalyticsService service) async {
  await service.init();
  await service.setUserProperties(
    lifetimeBrushes: 3,
    currentStreak: 2,
    totalStars: 7,
  );
  await service.logOnboardingComplete();
  await service.logBrushSessionStart(
    heroId: 'blaze',
    weaponId: 'star_blaster',
    worldId: 'candy_crater',
  );
  await service.logBrushSessionComplete(
    totalHits: 10,
    monstersDefeated: 4,
    starsEarned: 2,
    newStreak: 2,
    totalStars: 7,
  );
  await service.logBrushSessionAbandon(
    phase: 'topLeft',
    secondsRemaining: 12,
    totalHits: 3,
  );
  await service.logDailyLogin(streak: 2);
  await service.logShopVisit();
  await service.logHeroUnlock(heroId: 'frost', starsAtUnlock: 5);
  await service.logWeaponUnlock(weaponId: 'ice_beam', starsAtUnlock: 5);
  await service.logSignIn();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AnalyticsService on iOS (Kids Category: plugin not linked)', () {
    test(
      'never touches FirebaseAnalytics, even without Firebase init',
      () async {
        // Firebase.initializeApp() is deliberately NOT called here: touching
        // FirebaseAnalytics.instance would throw (no default app), just as any
        // real call would throw MissingPluginException on an iOS device.
        final service = AnalyticsService.forTesting(isAndroid: false);

        await expectLater(_exerciseEveryEntryPoint(service), completes);
        expect(service.isEnabled, isFalse);
      },
    );

    test('ignores an injected FirebaseAnalytics entirely', () async {
      final fake = _RecordingAnalytics();
      final service = AnalyticsService.forTesting(
        isAndroid: false,
        analytics: fake,
      );

      await _exerciseEveryEntryPoint(service);

      expect(fake.calls, isEmpty);
      expect(service.isEnabled, isFalse);
    });
  });

  group('AnalyticsService on Android (unchanged behaviour)', () {
    test('enables collection with ad consent denied, then logs', () async {
      final fake = _RecordingAnalytics();
      final service = AnalyticsService.forTesting(
        isAndroid: true,
        analytics: fake,
      );

      await service.init();
      expect(service.isEnabled, isTrue);
      const expectedConsent =
          'setConsent(analytics=true, ad=false, adUserData=false, '
          'adPersonalization=false)';
      expect(fake.calls, [
        'setAnalyticsCollectionEnabled(true)',
        expectedConsent,
      ]);

      fake.calls.clear();
      await service.logShopVisit();
      await service.logSignIn();
      expect(fake.calls, [
        'logEvent(shop_visit)',
        'logEvent(sign_in_complete)',
      ]);
    });

    test('init is idempotent', () async {
      final fake = _RecordingAnalytics();
      final service = AnalyticsService.forTesting(
        isAndroid: true,
        analytics: fake,
      );

      await service.init();
      await service.init();

      expect(
        fake.calls.where((c) => c.startsWith('setAnalyticsCollectionEnabled')),
        hasLength(1),
      );
    });
  });
}

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

class TelemetryService {
  static final TelemetryService _instance = TelemetryService._internal();
  factory TelemetryService() => _instance;
  TelemetryService._internal();

  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  FirebaseAnalyticsObserver get observer =>
      FirebaseAnalyticsObserver(analytics: _analytics);

  Future<void> logEvent(String name, {Map<String, Object>? params}) async {
    try {
      await _analytics.logEvent(name: name, parameters: params);
    } catch (e, st) {
      debugPrint('telemetry error: $e\n$st');
    }
  }
}

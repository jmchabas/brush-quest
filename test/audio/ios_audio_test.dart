import 'dart:async';
import 'dart:io' show Platform;

import 'package:brush_quest/services/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'real_audio_service_harness.dart';

/// iOS-branch behaviour of the REAL AudioService, run on the host with
/// `AudioService.debugIsIOSOverride = true` (see real_audio_service_harness).
/// These are HYBRID runs: code that reads Platform.isIOS directly still takes
/// the host branch, so they prove the Dart logic of each iOS gate, not iOS
/// itself. Device verification is still required.
void main() {
  setUpAll(AudioHarness.install);
  tearDown(() => AudioService.debugIsIOSOverride = null);

  group('platform gate', () {
    test('isIOS defaults to the host platform and follows the override', () {
      AudioService.debugIsIOSOverride = null;
      expect(AudioService.isIOS, Platform.isIOS);
      AudioService.debugIsIOSOverride = true;
      expect(AudioService.isIOS, isTrue);
      AudioService.debugIsIOSOverride = false;
      expect(AudioService.isIOS, isFalse);
    });

    test('trace is compiled out of normal builds (no [AUD] output)', () {
      expect(AudioService.traceEnabled, isFalse);
      AudioHarness.run((h) {
        unawaited(h.service.playVoice('voice_super.mp3'));
        h.elapse(const Duration(seconds: 2));
        expect(h.prints.where((p) => p.startsWith('[')), isEmpty);
      }, ios: true);
    });
  });
}

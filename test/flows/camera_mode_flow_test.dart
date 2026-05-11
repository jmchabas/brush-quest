import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('home screen starts brushing without pre-brush camera modal', () {
    final source = File('lib/screens/home_screen.dart').readAsStringSync();

    expect(source.contains('Camera Motion Mode'), isFalse);
    expect(source.contains('camera_prompt_accept'), isFalse);
    expect(source.contains('camera_prompt_decline'), isFalse);
    expect(
      source.contains("prefs.setBool('camera_mode_configured', true)"),
      isTrue,
    );
    // Picker was removed — brushing flow goes directly to BrushingScreen
    expect(source.contains('_launchBrushingScreen()'), isTrue);
  });

  test('onboarding camera page is parent-gated (COPPA)', () {
    final source = File(
      'lib/screens/onboarding_screen.dart',
    ).readAsStringSync();

    // Camera in onboarding MUST be gated behind both a parental check and
    // the same consent dialog used in Settings. The kid alone cannot consent
    // under COPPA, so the page funnels the parent through:
    //   1. A "GROWN-UP CHECK" parental gate (math problem),
    //   2. The "Brushing Detection" consent dialog (mirrors Settings copy),
    //   3. An OS-level Permission.camera.request() prompt.
    // Setting camera_enabled=true is only legal after the OS grant.
    expect(
      source.contains('GROWN-UP CHECK'),
      isTrue,
      reason: 'Onboarding must show a parental gate before enabling camera',
    );
    expect(
      source.contains('Brushing Detection'),
      isTrue,
      reason: 'Onboarding must show the same consent dialog as Settings',
    );
    expect(
      source.contains('No images are stored'),
      isTrue,
      reason:
          'Consent dialog must include the on-device-only / no-storage disclosure',
    );
    expect(
      source.contains('Permission.camera.request()'),
      isTrue,
      reason: 'Onboarding must trigger an OS permission prompt, not bypass it',
    );
    expect(
      source.contains("if (status.isGranted)"),
      isTrue,
      reason:
          'camera_enabled must only be set when the OS permission was granted',
    );
  });

  test('settings toggling camera marks setup as configured', () {
    final source = File('lib/screens/settings_screen.dart').readAsStringSync();

    expect(source.contains("prefs.setBool('camera_enabled', value)"), isTrue);
    expect(
      source.contains("prefs.setBool('camera_mode_configured', true)"),
      isTrue,
    );
  });
}

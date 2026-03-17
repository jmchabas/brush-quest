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
    expect(source.contains('_showPreBrushPicker();'), isTrue);
  });

  test('onboarding does NOT silently enable camera (COPPA)', () {
    final source = File(
      'lib/screens/onboarding_screen.dart',
    ).readAsStringSync();

    // Camera must not be silently enabled during onboarding (COPPA compliance).
    // Parents opt in via Settings where a consent dialog is shown.
    expect(source.contains('Camera motion mode'), isFalse);
    expect(
      source.contains("prefs.setBool('camera_mode_configured', true)"),
      isFalse,
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

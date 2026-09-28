# integration_test

iOS-focused end-to-end tests that run on a real iPhone Simulator (or device) via `flutter test integration_test/`. These complement the unit/widget tests under `test/` by exercising native platform channels (audio, camera, Firebase, sign-in) that mocks can't fully cover.

## Running

```bash
# All integration tests on default iOS Simulator
flutter test integration_test/

# Specific test on specific simulator
flutter test integration_test/parental_gate_test.dart -d "iPhone 15"
```

## Files

Tracked in `docs/ios-port/PLAN.md` Phase 1V:

- `parental_gate_test.dart` (1V-3) — math gate flow including iOS keyboard
- `sign_in_apple_test.dart` (1V-4) — Sign in with Apple visibility + gate ordering
- `account_deletion_test.dart` (1V-5) — Delete Account flow (depends on 1G-2 / 1G-4)
- `brush_session_e2e_test.dart` (1V-6) — full brushing session
- `audio_smoke_test.dart` (1V-7) — countdown + music + SFX + voice sequencing
- `ios_audio_real_test.dart` — REAL AudioService + the vendored/patched audioplayers_darwin on a Simulator: 50 queued voice pairs, interrupt storm, 130 s music loop, countdown, music start/stop churn. Run with `-d <udid> --dart-define=AUDIO_TRACE=true` (the music check reads trace lines).

## CI

Codemagic workflow `ios_tests` (1V-8) runs `flutter test integration_test/` on every PR — see `codemagic.yaml`.

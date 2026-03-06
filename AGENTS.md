# Brush Quest - Agent Instructions

See `CLAUDE.md` for full project overview, architecture, and build instructions.

## Cursor Cloud specific instructions

### Environment

- **Flutter SDK**: `/opt/flutter` (stable channel)
- **Android SDK**: `/opt/android-sdk`
- **JDK 17**: `/usr/lib/jvm/java-17-openjdk-amd64` (required — JDK 21+ is incompatible with AGP 8.11.1)
- Environment variables (`JAVA_HOME`, `ANDROID_HOME`, `PATH`) are set in `~/.bashrc`
- `android/local.properties` points to the SDK paths and is gitignored

### Key commands

| Task | Command |
|------|---------|
| Install deps | `flutter pub get` |
| Lint | `flutter analyze` |
| Tests | `flutter test` |
| Build debug APK | `flutter build apk --debug` |
| Run on emulator | `flutter run -d emulator-5554` |

### Android emulator (no KVM)

The cloud VM does **not** have KVM. The Android emulator must run with `-no-accel` and `-gpu swiftshader_indirect`. Boot takes ~3-5 minutes. An AVD named `test_device` (Pixel 6, API 35, google_apis/x86_64) is pre-created.

Start the emulator:
```
emulator -avd test_device -no-audio -no-boot-anim -gpu swiftshader_indirect -no-snapshot -memory 2048 -no-accel &
```

Wait for boot:
```
adb wait-for-device
# Then poll: adb shell getprop sys.boot_completed  (returns "1" when ready)
```

**Gotcha**: Flutter's Impeller rendering backend may produce a black screen on SwiftShader. If this happens, use `--no-enable-impeller` flag with `flutter run` or install the APK manually via `adb install -r build/app/outputs/flutter-apk/app-debug.apk`.

**Gotcha**: ADB install is very slow in software emulation (~2-5 minutes). Be patient.

### Firebase

Firebase is configured for Android only (`google-services.json` is committed). Running on Linux desktop or Chrome web will show Firebase initialization errors — this is expected. The core brushing game loop works fully offline without Firebase.

### Linux desktop build (alternative)

If you need a faster visual test than the Android emulator, you can build for Linux desktop:
```
flutter create --platforms=linux .
export CXXFLAGS="-stdlib=libstdc++ -I/usr/include/c++/13 -I/usr/include/x86_64-linux-gnu/c++/13"
flutter build linux --debug
```
Note: Firebase does not support Linux desktop, so the app will throw a non-fatal error at startup but the UI still loads.

// CYCLE-PROTECT: Crashlytics error handlers are gated to Platform.isAndroid
// because the FirebaseCrashlytics native framework is stripped from the iOS
// binary for Apple Kids Category compliance. Don't unwrap the gate without
// verifying the Run Script still strips Crashlytics. See docs/ios-port/PLAN.md.

import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'firebase_options.dart';
import 'route_observer.dart';
import 'services/analytics_service.dart';
import 'services/audio_service.dart';
import 'services/streak_service.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'widgets/asset_preloader.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  unawaited(
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]),
  );

  // Firebase init must never block app startup.
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // Crashlytics native framework is stripped from iOS for Apple Kids Category
    // compliance; calling FirebaseCrashlytics.instance on iOS would throw
    // MissingPluginException from the registered error handlers.
    if (Platform.isAndroid) {
      FlutterError.onError =
          FirebaseCrashlytics.instance.recordFlutterFatalError;
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };
    }
    // COPPA-compliant analytics: no ad IDs, no ad personalization.
    await AnalyticsService().init();
  } on Exception catch (_) {
    // Firebase/Crashlytics/Analytics unavailable — app still launches.
  }

  await StreakService.migrateToWalletEconomy();

  // Belt-and-suspenders: clear the shared purchase mutex on every cold start so
  // a prior crash between the set-true and the finally block can't silently
  // brick all subsequent purchases for the app's lifetime.
  StreakService.isPurchasing = false;

  runApp(const BrushQuestApp());
}

class BrushQuestApp extends StatefulWidget {
  const BrushQuestApp({super.key});

  @override
  State<BrushQuestApp> createState() => _BrushQuestAppState();
}

class _BrushQuestAppState extends State<BrushQuestApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // Backgrounded on both platforms — kill all audio, snapshotting the
      // current track so resume can restore it.
      AudioService().stopAllAudioForLifecycle();
    } else if (state == AppLifecycleState.inactive && !Platform.isIOS) {
      // Android: 'inactive' precedes paused. Kill audio.
      // iOS: 'inactive' is transient (Control Center pull, notification banner,
      // system alert, brief overlays). Killing audio here + stopAllAudio's
      // _musicPlaying=false made audio appear permanently dead after every
      // minor interruption. AVAudioSession interruption recovery in
      // AppDelegate.swift handles real iOS interruptions (calls, Siri).
      AudioService().stopAllAudioForLifecycle();
    } else if (state == AppLifecycleState.resumed) {
      // Screens don't rebuild on resume, so without this the music that was
      // playing before the phone slept never comes back (Jim's v24 feedback).
      AudioService().resumeAfterWake();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Brush Quest',
      debugShowCheckedModeBanner: false,
      navigatorObservers: [routeObserver],
      theme: ThemeData(
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF7C4DFF),
          secondary: Color(0xFF00E5FF),
          surface: Color(0xFF0D0B2E),
        ),
        textTheme: ThemeData.dark().textTheme.apply(fontFamily: 'Fredoka'),
      ),
      home: const AssetPreloader(child: _AppEntry()),
    );
  }
}

class _AppEntry extends StatefulWidget {
  const _AppEntry();

  @override
  State<_AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends State<_AppEntry> {
  bool? _needsOnboarding;

  @override
  void initState() {
    super.initState();
    _checkOnboarding();
  }

  Future<void> _checkOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    final completed = prefs.getBool('onboarding_completed') ?? false;
    if (mounted) setState(() => _needsOnboarding = !completed);
  }

  @override
  Widget build(BuildContext context) {
    if (_needsOnboarding == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF0D0B2E),
        body: SizedBox.shrink(),
      );
    }
    if (_needsOnboarding!) return const OnboardingScreen();
    return const HomeScreen();
  }
}

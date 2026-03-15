import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'firebase_options.dart';
import 'services/analytics_service.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'widgets/asset_preloader.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Firebase init must never block app startup.
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    FlutterError.onError =
        FirebaseCrashlytics.instance.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
    // COPPA-compliant analytics: no ad IDs, no ad personalization.
    await AnalyticsService().init();
  } catch (_) {
    // Firebase/Crashlytics/Analytics unavailable — app still launches.
  }

  runApp(const BrushQuestApp());
}

class BrushQuestApp extends StatelessWidget {
  const BrushQuestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Brush Quest',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFF7C4DFF),
          secondary: const Color(0xFF00E5FF),
          surface: const Color(0xFF0D0B2E),
        ),
        textTheme: GoogleFonts.fredokaTextTheme(ThemeData.dark().textTheme),
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

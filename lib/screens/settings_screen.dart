import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/audio_service.dart';
import '../services/auth_service.dart';
import '../services/streak_service.dart';
import '../services/sync_service.dart';
import '../services/analytics_service.dart';
import '../widgets/glass_card.dart';
import '../widgets/space_background.dart';
import 'home_screen.dart';
import 'onboarding_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with TickerProviderStateMixin {
  int _phaseDuration = 20;
  bool _cameraEnabled = false;
  int _totalBrushes = 0;
  int _bestStreak = 0;
  bool _signingIn = false;
  bool _syncing = false;
  bool _parentUnlocked = false;

  // Brush history stats
  List<BrushRecord> _brushHistory = [];
  bool _historyLoaded = false;

  String? _lastCloudSave;

  // Dashboard state
  bool _streakPaused = false;
  DateTime? _pauseEnd;
  int _currentStreak = 0;
  TodaySlotsStatus? _todaySlots;

  Timer? _inactivityTimer;

  final _auth = AuthService();
  final _sync = SyncService();

  // Tab controller for 3-tab layout
  late TabController _tabController;

  // Math challenge state
  late int _mathA;
  late int _mathB;
  final _mathController = TextEditingController();
  String? _mathError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_resetInactivityTimer);
    _generateMathChallenge();
    _loadSettings();
  }

  @override
  void dispose() {
    _inactivityTimer?.cancel();
    AudioService().stopVoice();
    _tabController.dispose();
    _mathController.dispose();
    super.dispose();
  }

  void _startInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(const Duration(seconds: 60), () {
      if (mounted) {
        setState(() {
          _parentUnlocked = false;
          _mathController.clear();
          _generateMathChallenge();
        });
      }
    });
  }

  void _resetInactivityTimer() {
    if (_parentUnlocked) {
      _startInactivityTimer();
    }
  }

  void _generateMathChallenge() {
    _mathA = 4 + DateTime.now().second % 6;
    _mathB = 3 + DateTime.now().minute % 5;
  }

  void _checkMathAnswer() {
    final answer = int.tryParse(_mathController.text.trim());
    if (answer == (_mathA * _mathB)) {
      setState(() {
        _parentUnlocked = true;
        _mathError = null;
      });
      _startInactivityTimer();
    } else {
      setState(() {
        _mathError = 'Try again!';
        _mathController.clear();
        _generateMathChallenge();
      });
    }
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final streakSvc = StreakService();
    final history = await streakSvc.getHistory();
    final todaySlots = await streakSvc.getTodaySlots();
    final paused = await streakSvc.isStreakPaused();
    final pauseEnd = await streakSvc.getStreakPauseEnd();
    final currentStreak = await streakSvc.getStreak();

    if (mounted) {
      setState(() {
        _phaseDuration = prefs.getInt('phase_duration') ?? 20;
        _cameraEnabled = prefs.getBool('camera_enabled') ?? false;
        _totalBrushes = prefs.getInt('total_brushes') ?? 0;
        _bestStreak = prefs.getInt('best_streak') ?? 0;
        _brushHistory = history;
        _historyLoaded = true;
        _todaySlots = todaySlots;
        _streakPaused = paused;
        _pauseEnd = pauseEnd;
        _currentStreak = currentStreak;
        _lastCloudSave = prefs.getString('last_cloud_save');
      });
    }
  }

  Future<void> _setPhaseDuration(int seconds) async {
    _resetInactivityTimer();
    final clamped = seconds.clamp(5, 120);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('phase_duration', clamped);
    setState(() => _phaseDuration = clamped);
  }

  Future<void> _toggleCamera(bool value) async {
    _resetInactivityTimer();
    // Show consent notice when enabling camera
    if (value) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1A0A3E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Brushing Detection',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          content: const Text(
            'The camera detects brushing motion to drive the game. '
            'No images are stored, recorded, or sent anywhere. '
            'Processing happens entirely on this device.',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text(
                'CANCEL',
                style: TextStyle(color: Colors.white54),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text(
                'ENABLE',
                style: TextStyle(
                  color: Color(0xFF00E5FF),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('camera_enabled', value);
    await prefs.setBool('camera_mode_configured', true);
    setState(() => _cameraEnabled = value);
  }

  Future<bool> _showDataConsentDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A0A3E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Cloud Save — Data Notice',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'By signing in, you consent to storing your child\'s game progress in Google\'s cloud (Firebase). This data includes:',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 12),
            const Text(
              '• Brush counts and streaks\n• Stars and unlocked items\n• Settings preferences',
              style: TextStyle(color: Colors.white60, fontSize: 13),
            ),
            const SizedBox(height: 12),
            const Text(
              'No personal information about your child is collected. You can delete all data, including cloud data, by resetting progress in Settings.',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _openPrivacyPolicy,
              child: const Text(
                'Read our Privacy Policy',
                style: TextStyle(
                  color: Color(0xFF7C4DFF),
                  fontSize: 14,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'CANCEL',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'I CONSENT',
              style: TextStyle(
                color: Color(0xFF00E676),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _handleSignIn() async {
    _resetInactivityTimer();
    final consented = await _showDataConsentDialog();
    if (!consented || !mounted) return;

    setState(() => _signingIn = true);
    try {
      final user = await _auth.signInWithGoogle();
      if (user != null && mounted) {
        unawaited(AnalyticsService().logSignIn());
        await _sync.smartSync();
        await _loadSettings();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Signed in as ${user.displayName ?? user.email}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              backgroundColor: const Color(0xFF00E676),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      }
    } on Exception catch (e) {
      debugPrint('Sign-in failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Sign-in didn\'t work. Please check your internet connection and try again.',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _signingIn = false);
    }
  }

  Future<void> _handleSignOut() async {
    _resetInactivityTimer();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A0A3E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.logout, color: Colors.white70, size: 22),
            SizedBox(width: 10),
            Text(
              'Sign Out?',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: const Text(
          'Cloud sync will stop until you sign in again. Your local data is safe.',
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'CANCEL',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'SIGN OUT',
              style: TextStyle(
                color: Colors.orangeAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await _auth.signOut();
      if (mounted) setState(() {});
    } on Exception catch (e) {
      debugPrint('Sign-out failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Sign-out didn\'t work. Please try again.',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  Future<void> _handleDeleteCloudData() async {
    _resetInactivityTimer();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A0A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Delete Cloud Data?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'This will delete your cloud backup. Your local progress will be kept.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      final success = await SyncService().deleteCloudData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success ? 'Cloud data deleted' : 'Failed to delete cloud data',
            ),
          ),
        );
      }
    }
  }

  Future<void> _handleSyncNow() async {
    _resetInactivityTimer();
    setState(() => _syncing = true);
    try {
      await _sync.uploadProgress();
      if (mounted) {
        setState(() {
          _lastCloudSave = DateTime.now().toIso8601String();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Progress saved to cloud!',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: const Color(0xFF00E5FF),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } on Exception catch (e) {
      debugPrint('Cloud sync failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Save didn\'t work. Please check your connection.',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _handleRestoreFromCloud() async {
    _resetInactivityTimer();
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A0A3E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Restore from Cloud?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'This will replace your local progress with the version saved in the cloud.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'CANCEL',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'RESTORE',
              style: TextStyle(
                color: Color(0xFF00E5FF),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _syncing = true);
    try {
      final restored = await _sync.downloadProgress();
      await _loadSettings();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              restored ? 'Progress restored!' : 'No cloud data found',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: restored
                ? const Color(0xFF00E676)
                : Colors.orangeAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } on Exception catch (e) {
      debugPrint('Cloud restore failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Restore didn\'t work. Please check your connection.',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _resetProgress() async {
    if (!mounted) return;

    // Step 1: Warning dialog
    final wantsContinue = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A0A3E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Start Fresh?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'This will reset all game progress — stars, heroes, weapons, streaks, and achievements. This cannot be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'CANCEL',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'CONTINUE',
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
    if (wantsContinue != true || !mounted) return;

    // Step 2: Math confirmation dialog (different problem from parent gate)
    final deleteA = 3 + DateTime.now().millisecond % 6;
    final deleteB = 3 + DateTime.now().second % 4;
    final deleteController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        String? error;
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            backgroundColor: const Color(0xFF1A0A3E),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text(
              'Are you sure?',
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'To confirm, solve this:',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 16),
                Text(
                  '$deleteA × $deleteB = ?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: 120,
                  child: TextField(
                    controller: deleteController,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    onChanged: (_) => _resetInactivityTimer(),
                    onSubmitted: (_) {
                      final ans = int.tryParse(deleteController.text.trim());
                      if (ans == (deleteA * deleteB)) {
                        Navigator.pop(ctx, true);
                      } else {
                        setDialogState(() {
                          error = 'Wrong answer!';
                          deleteController.clear();
                        });
                      }
                    },
                    decoration: InputDecoration(
                      hintText: '?',
                      hintStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.3),
                        fontSize: 24,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: Colors.white.withValues(alpha: 0.2),
                          width: 2,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(
                          color: Colors.redAccent,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    error!,
                    style: const TextStyle(
                      color: Colors.orangeAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text(
                  'CANCEL',
                  style: TextStyle(color: Colors.white54),
                ),
              ),
              TextButton(
                onPressed: () {
                  final ans = int.tryParse(deleteController.text.trim());
                  if (ans == (deleteA * deleteB)) {
                    Navigator.pop(ctx, true);
                  } else {
                    setDialogState(() {
                      error = 'Wrong answer!';
                      deleteController.clear();
                    });
                  }
                },
                child: const Text(
                  'DELETE',
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
    deleteController.dispose();
    if (confirmed != true || !mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final keysToReset = [
      'total_stars',
      'current_streak',
      'best_streak',
      'last_brush_date',
      'today_brush_count',
      'today_date',
      'total_brushes',
      'brush_history',
      'morning_done_date',
      'evening_done_date',
      'unlocked_heroes',
      'selected_hero',
      'unlocked_weapons',
      'selected_weapon',
      'current_world',
      'collected_cards',
      'card_album_visit_count',
      'last_card_album_visit',
      'last_greeting_date',
      'session_checkpoint_ts',
      'session_checkpoint_phase',
      'session_checkpoint_seconds',
      'session_checkpoint_world',
      'card_dup_bonus_threshold',
      'camera_mode_configured',
      'camera_prompt_shown',
      'voice_style',
      'onboarding_completed',
      'camera_enabled',
      'muted',
      'phase_duration',
      'star_wallet',
      'streak_pause_until',
      'last_daily_bonus_date',
      'unlocked_evolutions',
      'trophy_captured',
      'has_seen_legendary',
    ];
    for (final key in keysToReset) {
      await prefs.remove(key);
    }
    for (final key in prefs.getKeys()) {
      if (key.startsWith('world_progress_') ||
          key.startsWith('achievement_') ||
          key.startsWith('card_dup_count_') ||
          key.startsWith('world_intro_seen_') ||
          key.startsWith('evolution_stage_') ||
          key.startsWith('trophy_defeats_') ||
          key.startsWith('has_seen_first_')) {
        await prefs.remove(key);
      }
    }
    // Also delete cloud data if signed in
    await SyncService().deleteCloudData();

    if (mounted) {
      unawaited(
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (_) => false,
        ),
      );
    }
  }

  Future<void> _openPrivacyPolicy() async {
    final uri = Uri.parse('https://brushquest.app/privacy-policy.html');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  String _formatRelativeTime(String iso8601) {
    final saved = DateTime.tryParse(iso8601);
    if (saved == null) return iso8601;
    final diff = DateTime.now().difference(saved);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) {
      return '${diff.inHours} ${diff.inHours == 1 ? 'hour' : 'hours'} ago';
    }
    if (diff.inDays < 7) {
      return '${diff.inDays} ${diff.inDays == 1 ? 'day' : 'days'} ago';
    }
    return '${saved.month}/${saved.day}/${saved.year}';
  }

  void _resetOnboarding() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      (_) => false,
    );
  }

  // ── Today Status card builder ──────────────────────────────
  Widget _buildTodayStatus() {
    final morningDone = _todaySlots?.morningDone ?? false;
    final eveningDone = _todaySlots?.eveningDone ?? false;

    // Find today's timestamps from brush history
    final now = DateTime.now();
    final todayStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    String? morningTime;
    String? eveningTime;
    for (final record in _brushHistory) {
      if (record.date == todayStr) {
        final parts = record.time.split(':');
        if (parts.length == 2) {
          final hour = int.tryParse(parts[0]) ?? 12;
          if (hour < 12 && morningTime == null) {
            morningTime = record.time;
          } else if (hour >= 12 && eveningTime == null) {
            eveningTime = record.time;
          }
        }
      }
    }

    String formatTime(String time24) {
      final parts = time24.split(':');
      if (parts.length != 2) return time24;
      final hour = int.tryParse(parts[0]) ?? 0;
      final minute = parts[1];
      final period = hour >= 12 ? 'PM' : 'AM';
      final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
      return '$displayHour:$minute $period';
    }

    return GlassCard(
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.wb_sunny, color: Color(0xFFFFD54F), size: 20),
              const SizedBox(width: 10),
              const Text(
                'Morning',
                style: TextStyle(color: Colors.white70, fontSize: 15),
              ),
              const Spacer(),
              Text(
                morningDone
                    ? 'Done${morningTime != null ? ' (${formatTime(morningTime)})' : ''}'
                    : '\u2014',
                style: TextStyle(
                  color: morningDone ? const Color(0xFF00E676) : Colors.white38,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(
                Icons.nightlight_round,
                color: Color(0xFF90CAF9),
                size: 20,
              ),
              const SizedBox(width: 10),
              const Text(
                'Evening',
                style: TextStyle(color: Colors.white70, fontSize: 15),
              ),
              const Spacer(),
              Text(
                eveningDone
                    ? 'Done${eveningTime != null ? ' (${formatTime(eveningTime)})' : ''}'
                    : '\u2014',
                style: TextStyle(
                  color: eveningDone ? const Color(0xFF00E676) : Colors.white38,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Tracked Stats card (real data only, no calculated metrics) ──────
  Widget _buildHabitStrength() {
    return GlassCard(
      child: Column(
        children: [
          // Current Streak
          Row(
            children: [
              const Icon(
                Icons.local_fire_department,
                color: Colors.orangeAccent,
                size: 22,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Current Streak',
                  style: TextStyle(color: Colors.white70, fontSize: 15),
                ),
              ),
              Text(
                '$_currentStreak ${_currentStreak == 1 ? 'day' : 'days'}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Best Streak
          Row(
            children: [
              const Icon(
                Icons.emoji_events,
                color: Color(0xFFFFD54F),
                size: 22,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Best Streak',
                  style: TextStyle(color: Colors.white70, fontSize: 15),
                ),
              ),
              Text(
                '$_bestStreak ${_bestStreak == 1 ? 'day' : 'days'}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Total Brushes
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.asset(
                  'assets/images/icon_toothbrush.png',
                  width: 22,
                  height: 22,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Total Brushes',
                  style: TextStyle(color: Colors.white70, fontSize: 15),
                ),
              ),
              Text(
                '$_totalBrushes',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Dashboard Tab (Tab 1) ──────────────────────────────
  Widget _buildDashboardTab() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      children: [
        // ── STATS (top of dashboard) ────────────────
        const _SectionHeader(
          icon: Icons.bar_chart,
          label: 'STATS',
          color: Color(0xFF00E676),
        ),
        const SizedBox(height: 8),
        _buildHabitStrength(),

        const SizedBox(height: 24),

        // ── THIS WEEK ────────────────────────────────────────
        const _SectionHeader(
          icon: Icons.calendar_view_week,
          label: 'THIS WEEK',
          color: Color(0xFFFFD54F),
        ),
        const SizedBox(height: 8),
        if (_historyLoaded) _WeekActivityCard(history: _brushHistory),

        const SizedBox(height: 24),

        // ── TODAY STATUS ─────────────────────────────────────
        const _SectionHeader(
          icon: Icons.today,
          label: 'TODAY',
          color: Color(0xFF00E5FF),
        ),
        const SizedBox(height: 8),
        _buildTodayStatus(),

        const SizedBox(height: 24),

        // ── PAUSE STREAK ─────────────────────────────────────
        _buildPauseStreakCard(),

        const SizedBox(height: 32),

        Center(
          child: Text(
            'Brush Quest v1.0.0',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.3),
              fontSize: 12,
              letterSpacing: 2,
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  // ── Pause Streak card (extracted from _buildParentTools) ──
  Widget _buildPauseStreakCard() {
    return GlassCard(
      child: Row(
        children: [
          const Icon(
            Icons.pause_circle_outline,
            color: Colors.white54,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pause Streak',
                  style: TextStyle(color: Colors.white, fontSize: 15),
                ),
                const SizedBox(height: 2),
                Text(
                  'Protect streak during vacation or sick days',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _streakPaused && _pauseEnd != null
                      ? 'Protected until ${_pauseEnd!.month}/${_pauseEnd!.day}'
                      : 'No pause scheduled',
                  style: TextStyle(
                    color: _streakPaused
                        ? const Color(0xFFFFD54F)
                        : Colors.white.withValues(alpha: 0.4),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _streakPaused,
            onChanged: (value) async {
              if (value) {
                final now = DateTime.now();
                final picked = await showDatePicker(
                  context: context,
                  initialDate: now.add(const Duration(days: 1)),
                  firstDate: now.add(const Duration(days: 1)),
                  lastDate: now.add(const Duration(days: 7)),
                  builder: (context, child) {
                    return Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: const ColorScheme.dark(
                          primary: Color(0xFF7C4DFF),
                          surface: Color(0xFF1A0A3E),
                        ),
                      ),
                      child: child!,
                    );
                  },
                );
                if (picked != null) {
                  await StreakService().setStreakPause(picked);
                  setState(() {
                    _streakPaused = true;
                    _pauseEnd = picked;
                  });
                }
              } else {
                await StreakService().clearStreakPause();
                setState(() {
                  _streakPaused = false;
                  _pauseEnd = null;
                });
              }
            },
            activeThumbColor: const Color(0xFFFFD54F),
            activeTrackColor: const Color(0xFFFFD54F).withValues(alpha: 0.3),
          ),
        ],
      ),
    );
  }

  // ── Settings Tab (Tab 2) ──────────────────────────────
  Widget _buildSettingsTab(bool signedIn, User? user) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      children: [
        // ── ACCOUNT ──────────────────────────────────────────
        const _SectionHeader(
          icon: Icons.person,
          label: 'ACCOUNT',
          color: Color(0xFF00E676),
        ),
        const SizedBox(height: 8),
        if (!signedIn) ...[
          GestureDetector(
            onTap: _signingIn ? null : _handleSignIn,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1A237E), Color(0xFF283593)],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_signingIn)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  else ...[
                    const Icon(Icons.login, color: Colors.white, size: 22),
                    const SizedBox(width: 12),
                    const Text(
                      'Sign in with Google',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Save your progress to the cloud',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 12,
            ),
          ),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF00E676).withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const CircleAvatar(
                      radius: 20,
                      backgroundColor: Color(0xFF7C4DFF),
                      child: Icon(Icons.person, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.displayName ?? 'Space Ranger',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          if (user?.email != null)
                            Text(
                              user!.email!,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5),
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton(
                          onPressed: _handleSignOut,
                          child: const Text(
                            'Sign out',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: _handleDeleteCloudData,
                          child: const Text(
                            'Delete cloud data',
                            style: TextStyle(
                              color: Colors.redAccent,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.cloud_upload,
                        label: 'SAVE',
                        color: const Color(0xFF00E5FF),
                        loading: _syncing,
                        onTap: _handleSyncNow,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.cloud_download,
                        label: 'RESTORE',
                        color: const Color(0xFF7C4DFF),
                        loading: _syncing,
                        onTap: _handleRestoreFromCloud,
                      ),
                    ),
                  ],
                ),
                if (_lastCloudSave != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Last saved: ${_formatRelativeTime(_lastCloudSave!)}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],

        const SizedBox(height: 24),

        // ── BRUSHING ─────────────────────────────────────────
        const _SectionHeader(
          icon: Icons.cleaning_services,
          customIcon: ImageIcon(
            AssetImage('assets/images/icon_toothbrush.png'),
            size: 20,
          ),
          label: 'BRUSHING',
          color: Color(0xFF00E5FF),
        ),
        const SizedBox(height: 8),
        _SettingCard(
          icon: Icons.timer,
          title: 'Timer per zone',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final sec in [10, 15, 20])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _DurationChip(
                        seconds: sec,
                        selected: _phaseDuration == sec,
                        onTap: () => _setPhaseDuration(sec),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${_phaseDuration}s \u00d7 6 zones = ${_phaseDuration * 6 ~/ 60}:${(_phaseDuration * 6 % 60).toString().padLeft(2, '0')}',
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _SettingCard(
          icon: Icons.sensors,
          title: 'Brushing detection',
          child: Switch(
            value: _cameraEnabled,
            onChanged: _toggleCamera,
            activeThumbColor: const Color(0xFF00E5FF),
          ),
        ),
        const SizedBox(height: 8),
        _SettingCard(
          icon: AudioService().isMuted ? Icons.volume_off : Icons.volume_up,
          title: 'Sound',
          child: Switch(
            value: !AudioService().isMuted,
            onChanged: (_) async {
              await AudioService().toggleMute();
              setState(() {});
            },
            activeThumbColor: const Color(0xFF00E5FF),
          ),
        ),

        const SizedBox(height: 24),

        // ── OTHER ────────────────────────────────────────────
        const _SectionHeader(
          icon: Icons.settings,
          label: 'OTHER',
          color: Color(0xFF7C4DFF),
        ),
        const SizedBox(height: 8),
        _SettingCard(
          icon: Icons.replay,
          title: 'Show tutorial again',
          child: IconButton(
            icon: const Icon(Icons.replay, color: Color(0xFF00E5FF), size: 24),
            onPressed: _resetOnboarding,
          ),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.redAccent.withValues(alpha: 0.2)),
          ),
          child: _SettingCard(
            icon: Icons.delete_forever,
            title: "Start fresh",
            child: IconButton(
              icon: const Icon(
                Icons.delete_outline,
                color: Colors.redAccent,
                size: 24,
              ),
              onPressed: _resetProgress,
            ),
          ),
        ),
        const SizedBox(height: 8),
        _SettingCard(
          icon: Icons.privacy_tip_outlined,
          title: 'Privacy policy',
          child: IconButton(
            icon: const Icon(
              Icons.open_in_new,
              color: Color(0xFF7C4DFF),
              size: 24,
            ),
            onPressed: _openPrivacyPolicy,
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  // ── Stars Tab (Tab 3) — visual summary ────────────────
  Widget _buildStarsTab() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        children: [
          const _SectionHeader(
            icon: Icons.star,
            label: 'EARN STARS',
            color: Color(0xFFFFD54F),
          ),
          const SizedBox(height: 16),
          GlassCard(
            child: Column(
              children: [
                _buildStarRow(
                  icon: Icons.star,
                  iconColor: const Color(0xFFFFD54F),
                  label: 'Brush your teeth',
                  bonus: '+2',
                ),
                const Divider(color: Colors.white12, height: 24),
                _buildStarRow(
                  icon: Icons.local_fire_department,
                  iconColor: Colors.deepOrange,
                  label: 'Keep your streak',
                  bonus: '+1 / +2',
                ),
                const Divider(color: Colors.white12, height: 24),
                _buildStarRow(
                  icon: Icons.wb_twilight,
                  iconColor: Colors.purple,
                  label: 'Morning + evening',
                  bonus: '+1',
                ),
                const Divider(color: Colors.white12, height: 24),
                _buildStarRow(
                  icon: Icons.favorite,
                  iconColor: Colors.green,
                  label: 'Come back after a break',
                  bonus: '+3',
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'See the Guide tab for full details',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStarRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String bonus,
  }) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 24),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 15),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFFFD54F).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            bonus,
            style: const TextStyle(
              color: Color(0xFFFFD54F),
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  // ── Guide Tab (Tab 4) ──────────────────────────────────
  Widget _buildGuideTab() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        _buildGuideSection(
          'Our Promise',
          'Brush Quest is designed to make tooth brushing a habit your '
              'child looks forward to.\n\n'
              'There are no ads. No purchase prompts are shown to children. '
              'Everything is earned through brushing.',
          Icons.favorite,
          Colors.red,
        ),
        _buildGuideSection(
          'Streaks',
          'Brushing every day builds a streak. The longer the streak, '
              'the better the treasure chest rewards.\n\n'
              'If a day is missed, there\'s a one-day grace period \u2014 '
              'your child won\'t lose their streak from a single missed day. '
              'You can also pause the streak from the parent dashboard for '
              'vacations or sick days.\n\n'
              'Their best streak is always remembered and celebrated.',
          Icons.local_fire_department,
          Colors.orange,
        ),
        _buildGuideSection(
          'Morning & Evening',
          'The app supports two brushing sessions per day \u2014 '
              'morning (before noon) and evening (after noon). When your child '
              'brushes both morning and evening, they earn a bonus star.\n\n'
              'Two teeth icons on the home screen show which sessions are complete.',
          Icons.wb_twilight,
          Colors.amber,
        ),
        _buildGuideSection(
          'Treasure Chests',
          'After each session, your child earns a treasure chest. Better '
              'streaks mean better chests \u2014 this is structured, not random. '
              'There are no loot boxes or gambling mechanics.',
          Icons.card_giftcard,
          Colors.green,
        ),
        _buildGuideSection(
          'Daily Bonuses',
          'Each day has a theme that adds variety: extra energy, precision '
              'focus, treasure boost, or boss encounters. These rotate '
              'automatically on a 5-day cycle. Your child doesn\'t need to '
              'track these \u2014 they add variety automatically.',
          Icons.flash_on,
          Colors.yellow,
        ),
        _buildGuideSection(
          'Trophy Collecting',
          'Your child captures monster trophies by brushing. Each trophy '
              'requires defeating a monster 1\u20133 times. Trophies are earned '
              'through brushing \u2014 never randomly, never through purchases.',
          Icons.emoji_events,
          const Color(0xFFFFD54F),
        ),
        _buildGuideSection(
          'Stars & The Shop',
          'Stars are earned by brushing (2 per session, plus streak bonuses). '
              'Stars can be spent in the shop on new heroes and gear.\n\n'
              'Your child\'s Ranger Rank (lifetime total) never goes down \u2014 '
              'only the spendable wallet changes when they buy something.',
          Icons.star,
          Colors.yellow,
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildGuideSection(
    String title,
    String body,
    IconData icon,
    Color iconColor,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: iconColor, size: 22),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              body,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParentGate() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, color: Color(0xFF7C4DFF), size: 64),
            const SizedBox(height: 24),
            const Text(
              'Parent Check',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 24,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Solve this to open settings:',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              '$_mathA × $_mathB = ?',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: 120,
              child: TextField(
                controller: _mathController,
                autofocus: true,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                onChanged: (_) => _resetInactivityTimer(),
                onSubmitted: (_) => _checkMathAnswer(),
                decoration: InputDecoration(
                  hintText: '?',
                  hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.3),
                    fontSize: 24,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.2),
                      width: 2,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                      color: Color(0xFF00E5FF),
                      width: 2,
                    ),
                  ),
                ),
              ),
            ),
            if (_mathError != null) ...[
              const SizedBox(height: 12),
              Text(
                _mathError!,
                style: const TextStyle(
                  color: Colors.orangeAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
            const SizedBox(height: 20),
            GestureDetector(
              onTap: _checkMathAnswer,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF00E5FF).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF00E5FF).withValues(alpha: 0.5),
                    width: 2,
                  ),
                ),
                child: const Text(
                  'UNLOCK',
                  style: TextStyle(
                    color: Color(0xFF00E5FF),
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    letterSpacing: 3,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Text(
                'Go back',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    final signedIn = user != null;

    return Scaffold(
      body: SpaceBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_back,
                        color: Colors.white,
                        size: 28,
                      ),
                      onPressed: () {
                        AudioService().stopVoice();
                        Navigator.pop(context);
                      },
                    ),
                    const Expanded(
                      child: Text(
                        'SETTINGS',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 4,
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),

              if (!_parentUnlocked)
                Expanded(child: _buildParentGate())
              else ...[
                // ── Tab Bar ──────────────────────────────────────
                TabBar(
                  controller: _tabController,
                  indicatorColor: const Color(0xFF00E5FF),
                  indicatorWeight: 3,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white.withValues(alpha: 0.5),
                  tabs: const [
                    Tab(icon: Icon(Icons.dashboard), text: 'Dashboard'),
                    Tab(icon: Icon(Icons.settings), text: 'Settings'),
                    Tab(icon: Icon(Icons.star), text: 'Stars'),
                    Tab(icon: Icon(Icons.menu_book), text: 'Guide'),
                  ],
                ),
                // ── Tab Views ────────────────────────────────────
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // ═══ TAB 1: DASHBOARD ═══
                      _buildDashboardTab(),
                      // ═══ TAB 2: SETTINGS ═══
                      _buildSettingsTab(signedIn, user),
                      // ═══ TAB 3: STARS ═══
                      _buildStarsTab(),
                      // ═══ TAB 4: GUIDE ═══
                      _buildGuideTab(),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final Widget? customIcon;
  final String label;
  final Color color;

  const _SectionHeader({
    required this.icon,
    this.customIcon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        customIcon != null
            ? IconTheme(
                data: IconThemeData(color: color, size: 20),
                child: customIcon!,
              )
            : Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 14,
            letterSpacing: 3,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(height: 1, color: color.withValues(alpha: 0.2)),
        ),
      ],
    );
  }
}

class _SettingCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;

  const _SettingCard({
    required this.icon,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white54, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _DurationChip extends StatelessWidget {
  final int seconds;
  final bool selected;
  final VoidCallback onTap;

  const _DurationChip({
    required this.seconds,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF00E5FF).withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? const Color(0xFF00E5FF)
                : Colors.white.withValues(alpha: 0.15),
            width: selected ? 2 : 1,
          ),
        ),
        child: Text(
          '${seconds}s',
          style: TextStyle(
            color: selected ? const Color(0xFF00E5FF) : Colors.white54,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool loading;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (loading)
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: color),
              )
            else ...[
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 1,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 7-day activity visual — row of circles showing brushing activity per day.
class _WeekActivityCard extends StatelessWidget {
  final List<BrushRecord> history;

  const _WeekActivityCard({required this.history});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Build a map of date string -> brush count for the last 7 days
    final Map<String, int> dayCounts = {};
    for (final record in history) {
      dayCounts[record.date] = (dayCounts[record.date] ?? 0) + 1;
    }

    // Day abbreviations starting from 6 days ago through today
    const dayLabels = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Last 7 days',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(7, (i) {
              final day = today.subtract(Duration(days: 6 - i));
              final dateStr =
                  '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
              final count = dayCounts[dateStr] ?? 0;
              final dayLabel = dayLabels[day.weekday - 1];

              return Column(
                children: [
                  _DayDot(count: count),
                  const SizedBox(height: 6),
                  Text(
                    dayLabel,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              );
            }),
          ),
          const SizedBox(height: 10),
          // Legend row explaining the three dot states
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem(0, 'Missed'),
              const SizedBox(width: 14),
              _buildLegendItem(1, 'Once'),
              const SizedBox(width: 14),
              _buildLegendItem(2, 'Both'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(int count, String label) {
    const size = 12.0;
    Widget dot;
    if (count == 0) {
      dot = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.15),
            width: 1.5,
          ),
        ),
      );
    } else if (count == 1) {
      dot = SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _HalfCirclePainter(
            fillColor: const Color(0xFF00E676),
            borderColor: const Color(0xFF00E676),
          ),
        ),
      );
    } else {
      dot = Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0xFF00E676),
        ),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        dot,
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.54),
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

/// A single day dot: empty (missed), half-filled (brushed once), full (brushed 2+).
class _DayDot extends StatelessWidget {
  final int count;

  const _DayDot({required this.count});

  @override
  Widget build(BuildContext context) {
    const size = 36.0;
    if (count == 0) {
      // Empty circle — missed day
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.15),
            width: 2,
          ),
        ),
      );
    }

    if (count == 1) {
      // Half-filled green circle — brushed once (bottom half filled via arc)
      return SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _HalfCirclePainter(
            fillColor: const Color(0xFF00E676),
            borderColor: const Color(0xFF00E676),
          ),
        ),
      );
    }

    // Full green circle with checkmark — brushed 2+
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFF00E676),
      ),
      child: const Icon(Icons.check, color: Colors.white, size: 20),
    );
  }
}

/// Paints a circle with the bottom half filled and a border around the full circle.
class _HalfCirclePainter extends CustomPainter {
  final Color fillColor;
  final Color borderColor;

  _HalfCirclePainter({required this.fillColor, required this.borderColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 1;

    // Fill the bottom half
    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;

    // Clip to circle, then draw a rect covering bottom half
    canvas.save();
    canvas.clipPath(
      Path()..addOval(Rect.fromCircle(center: center, radius: radius)),
    );
    canvas.drawRect(
      Rect.fromLTRB(0, size.height / 2, size.width, size.height),
      fillPaint,
    );
    canvas.restore();

    // Draw border around full circle
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, radius, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/audio_service.dart';
import '../services/auth_service.dart';
import '../services/sync_service.dart';
import '../widgets/space_background.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _phaseDuration = 30;
  bool _cameraEnabled = true;
  int _totalBrushes = 0;
  int _bestStreak = 0;
  List<int> _weeklyBrushCounts = List<int>.filled(7, 0);
  int _weeklyMorningBrushes = 0;
  int _weeklyEveningBrushes = 0;
  bool _signingIn = false;
  bool _syncing = false;

  final _auth = AuthService();
  final _sync = SyncService();
  DateTime? _parentUnlockedUntil;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _phaseDuration = prefs.getInt('phase_duration') ?? 30;
        _cameraEnabled = prefs.getBool('camera_enabled') ?? true;
        _totalBrushes = prefs.getInt('total_brushes') ?? 0;
        _bestStreak = prefs.getInt('best_streak') ?? 0;
      });
    }
    await _loadWeeklyStats();
  }

  Future<void> _loadWeeklyStats() async {
    final prefs = await SharedPreferences.getInstance();
    final history = prefs.getStringList('brush_history') ?? const [];
    final now = DateTime.now();
    final byDay = List<int>.filled(7, 0);
    int morning = 0;
    int evening = 0;

    for (final raw in history) {
      try {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        final date = DateTime.tryParse(map['date'] as String? ?? '');
        if (date == null) continue;
        final dayDiff = now
            .difference(DateTime(date.year, date.month, date.day))
            .inDays;
        if (dayDiff < 0 || dayDiff > 6) continue;
        byDay[6 - dayDiff] += 1;
        final time = map['time'] as String? ?? '';
        final hour = int.tryParse(time.split(':').first) ?? 12;
        if (hour < 15) {
          morning++;
        } else {
          evening++;
        }
      } catch (_) {
        // Ignore malformed historical entry.
      }
    }

    if (mounted) {
      setState(() {
        _weeklyBrushCounts = byDay;
        _weeklyMorningBrushes = morning;
        _weeklyEveningBrushes = evening;
      });
    }
  }

  Future<void> _setPhaseDuration(int seconds) async {
    final clamped = seconds.clamp(5, 120);
    final allowed = await _ensureParentAccess();
    if (!allowed) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('phase_duration', clamped);
    setState(() => _phaseDuration = clamped);
  }

  Future<void> _toggleCamera(bool value) async {
    final allowed = await _ensureParentAccess();
    if (!allowed) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('camera_enabled', value);
    await prefs.setBool('camera_mode_configured', true);
    setState(() => _cameraEnabled = value);
  }

  Future<void> _handleSignIn() async {
    setState(() => _signingIn = true);
    try {
      final user = await _auth.signInWithGoogle();
      if (user != null && mounted) {
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Sign-in failed: $e',
              style: const TextStyle(fontWeight: FontWeight.bold),
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
    final allowed = await _ensureParentAccess();
    if (!allowed) return;
    await _auth.signOut();
    if (mounted) setState(() {});
  }

  Future<void> _handleSyncNow() async {
    final allowed = await _ensureParentAccess();
    if (!allowed) return;
    setState(() => _syncing = true);
    try {
      await _sync.uploadProgress();
      if (mounted) {
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Sync failed: $e',
              style: const TextStyle(fontWeight: FontWeight.bold),
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
    final allowed = await _ensureParentAccess();
    if (!allowed) return;
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
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _resetProgress() async {
    final allowed = await _ensureParentAccess();
    if (!allowed) return;
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A0A3E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Reset Progress?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'This will reset all stars, heroes, weapons, streaks, and achievements. This cannot be undone.',
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
              'RESET',
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

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
    ];
    for (final key in keysToReset) {
      await prefs.remove(key);
    }
    for (final key in prefs.getKeys()) {
      if (key.startsWith('world_progress_') || key.startsWith('achievement_')) {
        await prefs.remove(key);
      }
    }
    // Also delete cloud data if signed in
    await SyncService().deleteCloudData();

    if (mounted) {
      _loadSettings();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Progress reset!',
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

  Future<bool> _ensureParentAccess() async {
    if (_parentUnlockedUntil != null &&
        DateTime.now().isBefore(_parentUnlockedUntil!)) {
      return true;
    }
    final a = 2 + DateTime.now().second % 7;
    final b = 3 + DateTime.now().minute % 6;
    final controller = TextEditingController();
    final focusNode = FocusNode();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A0A3E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Parent Check',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'For parent settings, solve this:',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 10),
            Text(
              '$a + $b = ?',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              focusNode: focusNode,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                signed: false,
                decimal: false,
              ),
              textInputAction: TextInputAction.done,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Answer',
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                  borderSide: BorderSide(color: Color(0xFF00E5FF)),
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
            onPressed: () {
              final answer = int.tryParse(controller.text.trim());
              Navigator.pop(ctx, answer == (a + b));
            },
            child: const Text(
              'OK',
              style: TextStyle(
                color: Color(0xFF00E5FF),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
    focusNode.dispose();
    if (ok == true) {
      _parentUnlockedUntil = DateTime.now().add(const Duration(minutes: 5));
      return true;
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Parent check failed'),
          backgroundColor: Colors.orangeAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
    return false;
  }

  Future<void> _resetOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Tutorial will show on next launch',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: const Color(0xFF7C4DFF),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
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
                      onPressed: () => Navigator.pop(context),
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

              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  children: [
                    // ACCOUNT section
                    _SectionHeader(
                      icon: Icons.person,
                      label: 'ACCOUNT',
                      color: const Color(0xFF00E676),
                    ),
                    const SizedBox(height: 8),

                    if (!signedIn) ...[
                      GestureDetector(
                        onTap: _signingIn ? null : _handleSignIn,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF1A237E), Color(0xFF283593)],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.15),
                            ),
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
                                const Icon(
                                  Icons.login,
                                  color: Colors.white,
                                  size: 22,
                                ),
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
                            color: const Color(
                              0xFF00E676,
                            ).withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: const Color(0xFF7C4DFF),
                                  child: const Icon(Icons.person, color: Colors.white, size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        user.displayName ?? 'Space Ranger',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                      if (user.email != null)
                                        Text(
                                          user.email!,
                                          style: TextStyle(
                                            color: Colors.white.withValues(
                                              alpha: 0.5,
                                            ),
                                            fontSize: 12,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
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
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // BRUSHING section
                    _SectionHeader(
                      icon: Icons.brush,
                      label: 'BRUSHING',
                      color: const Color(0xFF00E5FF),
                    ),
                    const SizedBox(height: 8),

                    _SettingCard(
                      icon: Icons.timer,
                      title: 'Timer per zone',
                      child: Row(
                        children: [
                          for (final sec in [15, 20, 30])
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
                    ),
                    const SizedBox(height: 8),

                    _SettingCard(
                      icon: Icons.videocam,
                      title: 'Motion camera',
                      child: Switch(
                        value: _cameraEnabled,
                        onChanged: _toggleCamera,
                        activeThumbColor: const Color(0xFF00E5FF),
                      ),
                    ),
                    const SizedBox(height: 8),

                    _SettingCard(
                      icon: AudioService().isMuted
                          ? Icons.volume_off
                          : Icons.volume_up,
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

                    // STATS section
                    _SectionHeader(
                      icon: Icons.bar_chart,
                      label: 'STATS',
                      color: const Color(0xFFFFD54F),
                    ),
                    const SizedBox(height: 8),

                    _SettingCard(
                      icon: Icons.brush,
                      title: 'Total brushes',
                      child: Text(
                        '$_totalBrushes',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _SettingCard(
                      icon: Icons.local_fire_department,
                      title: 'Best streak',
                      child: Text(
                        '$_bestStreak days',
                        style: const TextStyle(
                          color: Colors.orangeAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _SettingCard(
                      icon: Icons.calendar_today,
                      title: 'Last 7 days',
                      child: const SizedBox.shrink(),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: List.generate(7, (i) {
                              final count = _weeklyBrushCounts[i];
                              final active = count > 0;
                              return Column(
                                children: [
                                  Container(
                                    width: 20,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: active
                                          ? const Color(
                                              0xFF00E676,
                                            ).withValues(alpha: 0.8)
                                          : Colors.white.withValues(
                                              alpha: 0.12,
                                            ),
                                      border: Border.all(
                                        color: active
                                            ? const Color(0xFF69F0AE)
                                            : Colors.white24,
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        '$count',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            }),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'AM brushes: $_weeklyMorningBrushes   •   PM brushes: $_weeklyEveningBrushes',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.65),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // OTHER section
                    _SectionHeader(
                      icon: Icons.settings,
                      label: 'OTHER',
                      color: const Color(0xFF7C4DFF),
                    ),
                    const SizedBox(height: 8),

                    _SettingCard(
                      icon: Icons.school,
                      title: 'Show tutorial again',
                      child: IconButton(
                        icon: const Icon(
                          Icons.replay,
                          color: Color(0xFF00E5FF),
                          size: 24,
                        ),
                        onPressed: _resetOnboarding,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _SettingCard(
                      icon: Icons.delete_forever,
                      title: 'Reset all progress',
                      child: IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.redAccent,
                          size: 24,
                        ),
                        onPressed: _resetProgress,
                      ),
                    ),

                    const SizedBox(height: 32),

                    Center(
                      child: Text(
                        'Brush Quest v4',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.3),
                          fontSize: 12,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _SectionHeader({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
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

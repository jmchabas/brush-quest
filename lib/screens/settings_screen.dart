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
  bool _signingIn = false;
  bool _syncing = false;
  bool _parentUnlocked = false;

  final _auth = AuthService();
  final _sync = SyncService();


  // Math challenge state
  late int _mathA;
  late int _mathB;
  final _mathController = TextEditingController();
  String? _mathError;

  @override
  void initState() {
    super.initState();
    _generateMathChallenge();
    _loadSettings();
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) {
        AudioService().playVoice('voice_entry_settings.mp3', clearQueue: true, interrupt: true);
      }
    });
  }

  @override
  void dispose() {
    _mathController.dispose();
    super.dispose();
  }

  void _generateMathChallenge() {
    _mathA = 2 + DateTime.now().second % 7;
    _mathB = 2 + DateTime.now().minute % 5;
  }

  void _checkMathAnswer() {
    final answer = int.tryParse(_mathController.text.trim());
    if (answer == (_mathA * _mathB)) {
      setState(() {
        _parentUnlocked = true;
        _mathError = null;
      });
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
    if (mounted) {
      setState(() {
        _phaseDuration = prefs.getInt('phase_duration') ?? 30;
        _cameraEnabled = prefs.getBool('camera_enabled') ?? true;
        _totalBrushes = prefs.getInt('total_brushes') ?? 0;
        _bestStreak = prefs.getInt('best_streak') ?? 0;
      });
    }
  }

  Future<void> _setPhaseDuration(int seconds) async {
    final clamped = seconds.clamp(5, 120);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('phase_duration', clamped);
    setState(() => _phaseDuration = clamped);
  }

  Future<void> _toggleCamera(bool value) async {
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
    await _auth.signOut();
    if (mounted) setState(() {});
  }

  Future<void> _handleSyncNow() async {
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

  Widget _buildParentGate() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.lock_outline,
              color: Color(0xFF7C4DFF),
              size: 64,
            ),
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
                keyboardType: const TextInputType.numberWithOptions(
                  signed: false,
                  decimal: false,
                ),
                textInputAction: TextInputAction.done,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
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

              if (!_parentUnlocked)
                Expanded(child: _buildParentGate())
              else
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

                    const SizedBox(height: 24),

                    // OTHER section
                    _SectionHeader(
                      icon: Icons.settings,
                      label: 'OTHER',
                      color: const Color(0xFF7C4DFF),
                    ),
                    const SizedBox(height: 8),

                    _SettingCard(
                      icon: Icons.replay,
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
                        'Brush Quest v7',
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

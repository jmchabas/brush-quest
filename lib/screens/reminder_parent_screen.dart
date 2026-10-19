// lib/screens/reminder_parent_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';

import '../services/reminder_plan.dart';
import '../services/reminder_service.dart';
import '../widgets/reminder_time_dropdown.dart';
import '../widgets/space_background.dart';
import 'after_brush_home.dart';

/// Screen B of the bedtime reminder (spec
/// docs/superpowers/specs/2026-10-15-bedtime-reminder-design.md §3.2): the
/// parent's own screen, reached only through the GROWN-UP CHECK on the
/// hand-off. It says what the reminder is before the OS asks anything: TURN
/// ON shows the OS prompt, and the reminder is saved only if the OS allows
/// it. "Not now" is final. The back gesture returns to the hand-off.
class ReminderParentScreen extends StatefulWidget {
  const ReminderParentScreen({super.key});

  /// How long "Reminder set for 7:45 PM" stays before Home.
  static const confirmationHold = Duration(milliseconds: 2500);

  @override
  State<ReminderParentScreen> createState() => _ReminderParentScreenState();
}

class _ReminderParentScreenState extends State<ReminderParentScreen> {
  /// What TURN ON saves: the evening reminder at the time shown, and the
  /// morning one if ticked. Null while loading.
  ReminderSettings? _wanted;
  bool _busy = false;
  String? _confirmation;
  Timer? _homeTimer;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _homeTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final saved = await ReminderService().settings();
    if (!mounted) return;
    setState(() => _wanted = saved.copyWith(eveningOn: true, morningOn: false));
  }

  void _change(ReminderSettings wanted) {
    if (_busy) return;
    setState(() => _wanted = wanted);
  }

  Future<void> _turnOn() async {
    final wanted = _wanted;
    if (wanted == null || _busy) return;
    setState(() => _busy = true);
    final on = await ReminderService().turnOn(wanted);
    if (!mounted) return;
    if (!on) {
      unawaited(AfterBrushHome.go(context));
      return;
    }
    setState(() => _confirmation = reminderConfirmation(wanted));
    _homeTimer = Timer(ReminderParentScreen.confirmationHold, () {
      if (mounted) unawaited(AfterBrushHome.go(context));
    });
  }

  Future<void> _notNow() async {
    if (_busy) return;
    setState(() => _busy = true);
    await ReminderService().noteOfferResult(ReminderOfferResult.notNow);
    if (!mounted) return;
    unawaited(AfterBrushHome.go(context));
  }

  @override
  Widget build(BuildContext context) {
    final wanted = _wanted;
    return Scaffold(
      body: SpaceBackground(
        // A scroll view is only as tall as its content: without this the
        // starry background would end under the text on a tall phone.
        child: SizedBox.expand(
          child: SafeArea(
            child: wanted == null
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF00E5FF)),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _ForGrownUps(),
                        const SizedBox(height: 24),
                        const _MoonAndBrush(),
                        const SizedBox(height: 20),
                        const Text(
                          'Want a bedtime brushing reminder?',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "One reminder on this phone each evening, only if "
                          "brushing hasn't happened yet. Your reminder "
                          'times stay on this phone.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 16,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 28),
                        Row(
                          children: [
                            const Expanded(
                              child: Text('Remind me at', style: _labelStyle),
                            ),
                            ReminderTimeDropdown(
                              key: const ValueKey('parent_evening_time'),
                              value: wanted.evening,
                              choices: eveningReminderChoices,
                              onChanged: _busy
                                  ? null
                                  : (time) =>
                                        _change(wanted.copyWith(evening: time)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Checkbox(
                              key: const ValueKey('parent_morning_check'),
                              value: wanted.morningOn,
                              activeColor: const Color(0xFF00E5FF),
                              onChanged: _busy
                                  ? null
                                  : (on) => _change(
                                      wanted.copyWith(morningOn: on ?? false),
                                    ),
                            ),
                            const Expanded(
                              child: Text(
                                'Morning reminder too',
                                style: _labelStyle,
                              ),
                            ),
                            ReminderTimeDropdown(
                              key: const ValueKey('parent_morning_time'),
                              value: wanted.morning,
                              choices: morningReminderChoices,
                              onChanged: _busy || !wanted.morningOn
                                  ? null
                                  : (time) =>
                                        _change(wanted.copyWith(morning: time)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 28),
                        if (_confirmation case final confirmation?)
                          _Confirmation(text: confirmation)
                        else ...[
                          _TurnOnButton(onPressed: _busy ? null : _turnOn),
                          const SizedBox(height: 8),
                          TextButton(
                            key: const ValueKey('parent_not_now'),
                            onPressed: _busy ? null : _notNow,
                            child: const Text(
                              'Not now',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        Text(
                          'Change or turn off anytime: Parents > Settings > '
                          'Reminders',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.55),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

const _labelStyle = TextStyle(color: Colors.white, fontSize: 16);

class _ForGrownUps extends StatelessWidget {
  const _ForGrownUps();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Icon(Icons.lock_rounded, color: Color(0xFFFFD54F), size: 18),
        SizedBox(width: 8),
        Text(
          'FOR GROWN-UPS',
          style: TextStyle(
            color: Color(0xFFFFD54F),
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 3,
          ),
        ),
      ],
    );
  }
}

/// A moon and a toothbrush: a bedtime brush.
class _MoonAndBrush extends StatelessWidget {
  const _MoonAndBrush();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.bedtime_rounded, color: Color(0xFFFFD54F), size: 64),
        SizedBox(width: 12),
        // The art is an opaque tile (a neon toothbrush on near-black), so it
        // is shown as it is: tinting it, as an ImageIcon does, paints a
        // solid square.
        ClipRRect(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          child: Image(
            image: AssetImage('assets/images/icon_toothbrush.png'),
            width: 64,
            height: 64,
            fit: BoxFit.cover,
            excludeFromSemantics: true,
          ),
        ),
      ],
    );
  }
}

class _TurnOnButton extends StatelessWidget {
  const _TurnOnButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ElevatedButton(
        key: const ValueKey('parent_turn_on'),
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF7C4DFF),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: const Text(
          'TURN ON',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
      ),
    );
  }
}

class _Confirmation extends StatelessWidget {
  const _Confirmation({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      key: const ValueKey('parent_confirmation'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.check_circle_rounded,
          color: Color(0xFF00E676),
          size: 32,
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}

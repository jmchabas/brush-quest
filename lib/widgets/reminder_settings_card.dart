// lib/widgets/reminder_settings_card.dart
import 'dart:async';

import 'package:flutter/material.dart';

import '../services/reminder_plan.dart';
import '../services/reminder_service.dart';
import 'reminder_time_dropdown.dart';

/// The REMINDERS card of Parents > Settings (spec
/// docs/superpowers/specs/2026-10-15-bedtime-reminder-design.md §3.3): the
/// bedtime reminder and the morning one, each with its time. Turning one on
/// asks the OS first (the Parent Zone is behind the parent gate). If the OS
/// has notifications off, the card says so and offers the phone's settings,
/// a link out allowed only here. [onInteraction] keeps the Parent Zone
/// unlocked.
class ReminderSettingsCard extends StatefulWidget {
  const ReminderSettingsCard({super.key, this.onInteraction});

  final VoidCallback? onInteraction;

  @override
  State<ReminderSettingsCard> createState() => _ReminderSettingsCardState();
}

class _ReminderSettingsCardState extends State<ReminderSettingsCard>
    with WidgetsBindingObserver {
  ReminderSettings? _settings;
  bool _blocked = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_load());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Back from the phone's settings (or anywhere): what the OS allows may
  /// have changed.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_busy) unawaited(_load());
  }

  Future<void> _load() async {
    final service = ReminderService();
    final settings = await service.settings();
    final blocked = settings.anyOn && !await service.notificationsAllowed();
    if (!mounted) return;
    setState(() {
      _settings = settings;
      _blocked = blocked;
    });
  }

  /// A switch: on asks the OS through [ReminderService.turnOn]; off saves.
  Future<void> _switch(ReminderSlot slot, {required bool on}) async {
    final current = _settings;
    if (current == null || _busy) return;
    widget.onInteraction?.call();
    final wanted = slot == ReminderSlot.evening
        ? current.copyWith(eveningOn: on)
        : current.copyWith(morningOn: on);
    setState(() => _busy = true);
    final service = ReminderService();
    var saved = wanted;
    var refused = false;
    if (on) {
      service.noteParentZoneOffer();
      if (!await service.turnOn(wanted)) {
        saved = current;
        refused = true;
      }
    } else {
      await service.saveSettings(wanted);
    }
    final blocked =
        refused || (saved.anyOn && !await service.notificationsAllowed());
    if (!mounted) return;
    setState(() {
      _settings = saved;
      _blocked = blocked;
      _busy = false;
    });
  }

  Future<void> _time(ReminderSlot slot, ReminderTime time) async {
    final current = _settings;
    if (current == null || _busy) return;
    widget.onInteraction?.call();
    final changed = slot == ReminderSlot.evening
        ? current.copyWith(evening: time)
        : current.copyWith(morning: time);
    setState(() => _settings = changed);
    await ReminderService().saveSettings(changed);
  }

  @override
  Widget build(BuildContext context) {
    final settings = _settings;
    if (settings == null) return const SizedBox(height: 120);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final slot in ReminderSlot.values) ...[
            if (slot != ReminderSlot.values.first)
              const Divider(color: Colors.white12, height: 20),
            _ReminderRow(
              slot: slot,
              on: slot == ReminderSlot.evening
                  ? settings.eveningOn
                  : settings.morningOn,
              time: slot == ReminderSlot.evening
                  ? settings.evening
                  : settings.morning,
              enabled: !_busy,
              onSwitch: (on) => unawaited(_switch(slot, on: on)),
              onTime: (time) => unawaited(_time(slot, time)),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            "Only if that brush hasn't happened yet. Stays on this phone.",
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 12,
            ),
          ),
          if (_blocked) ...[
            const SizedBox(height: 12),
            _BlockedNote(
              onOpen: () {
                widget.onInteraction?.call();
                unawaited(ReminderService().openPhoneSettings());
              },
            ),
          ],
        ],
      ),
    );
  }
}

/// One reminder: its switch, and its time while it is on.
class _ReminderRow extends StatelessWidget {
  const _ReminderRow({
    required this.slot,
    required this.on,
    required this.time,
    required this.enabled,
    required this.onSwitch,
    required this.onTime,
  });

  final ReminderSlot slot;
  final bool on;
  final ReminderTime time;
  final bool enabled;
  final ValueChanged<bool> onSwitch;
  final ValueChanged<ReminderTime> onTime;

  @override
  Widget build(BuildContext context) {
    final evening = slot == ReminderSlot.evening;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              evening ? Icons.bedtime_rounded : Icons.wb_sunny_rounded,
              color: Colors.white54,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                evening ? 'Bedtime reminder' : 'Morning reminder',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Switch(
              key: ValueKey('reminder_${slot.name}_switch'),
              value: on,
              onChanged: enabled ? onSwitch : null,
              activeThumbColor: const Color(0xFFFFD54F),
            ),
          ],
        ),
        if (on)
          Padding(
            padding: const EdgeInsets.only(left: 34),
            child: ReminderTimeDropdown(
              key: ValueKey('reminder_${slot.name}_time'),
              value: time,
              choices: evening
                  ? eveningReminderChoices
                  : morningReminderChoices,
              onChanged: enabled ? onTime : null,
            ),
          ),
      ],
    );
  }
}

/// Notifications are off in the phone: say so, and offer its settings.
class _BlockedNote extends StatelessWidget {
  const _BlockedNote({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('reminder_blocked'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Notifications for Brush Quest are off in your phone settings.',
          style: TextStyle(
            color: Colors.orangeAccent,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          key: const ValueKey('reminder_open_settings'),
          onPressed: onOpen,
          icon: const Icon(Icons.open_in_new, size: 18),
          label: const Text('Open phone settings'),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF00E5FF),
            side: const BorderSide(color: Color(0xFF00E5FF)),
          ),
        ),
      ],
    );
  }
}

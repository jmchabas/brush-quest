// lib/widgets/reminder_time_dropdown.dart
import 'package:flutter/material.dart';

import '../services/reminder_plan.dart';

/// A reminder time picked from a list of quarter hours (spec §3.2 "Remind
/// me at"; ruling R-5). A saved time that isn't one of [choices] is listed
/// too, so an older or odd value never breaks the list. With [onChanged]
/// null it is greyed out.
class ReminderTimeDropdown extends StatelessWidget {
  const ReminderTimeDropdown({
    super.key,
    required this.value,
    required this.choices,
    required this.onChanged,
  });

  final ReminderTime value;
  final List<ReminderTime> choices;
  final ValueChanged<ReminderTime>? onChanged;

  @override
  Widget build(BuildContext context) {
    final minutes = {
      for (final choice in choices) reminderMinutes(choice),
      reminderMinutes(value),
    }.toList()..sort();
    final changed = onChanged;
    return DropdownButton<int>(
      value: reminderMinutes(value),
      dropdownColor: const Color(0xFF1A0A3E),
      iconEnabledColor: const Color(0xFF00E5FF),
      menuMaxHeight: 320,
      underline: const SizedBox.shrink(),
      // DropdownButton replaces the ambient text style with this one, so it
      // starts from the theme's own (the app font), not a bare TextStyle.
      style: (Theme.of(context).textTheme.titleMedium ?? const TextStyle())
          .copyWith(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
      items: [
        for (final m in minutes)
          DropdownMenuItem(
            value: m,
            child: Text(formatReminderTime(reminderTimeFromMinutes(m))),
          ),
      ],
      onChanged: changed == null
          ? null
          : (m) {
              if (m != null) changed(reminderTimeFromMinutes(m));
            },
    );
  }
}

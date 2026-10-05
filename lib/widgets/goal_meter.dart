// lib/widgets/goal_meter.dart
import 'package:flutter/material.dart';

enum GoalMeterStyle { stars, rockets }

/// How close a goal is, for a child who can't read: star slots (up to 10),
/// a star bar (more than 10), rocket slots (world missions), or a crown
/// when the category is complete (spec §4.1).
class GoalMeter extends StatelessWidget {
  final int have;
  final int cost;
  final GoalMeterStyle style;
  final bool complete;
  final double unit;

  const GoalMeter({
    super.key,
    required this.have,
    required this.cost,
    this.style = GoalMeterStyle.stars,
    this.complete = false,
    this.unit = 22,
  });

  static const _maxSlots = 10;

  @override
  Widget build(BuildContext context) {
    if (complete) {
      return Icon(
        Icons.workspace_premium,
        key: const ValueKey('meter_crown'),
        color: Colors.amberAccent,
        size: unit * 1.8,
      );
    }
    final filled = have.clamp(0, cost);
    final rockets = style == GoalMeterStyle.rockets;
    if (!rockets && cost > _maxSlots) {
      final fraction = cost == 0 ? 1.0 : filled / cost;
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            key: const ValueKey('meter_bar'),
            width: unit * 8,
            height: unit * 0.7,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(unit),
              color: Colors.white.withValues(alpha: 0.15),
            ),
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: fraction,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(unit),
                  color: Colors.amberAccent,
                ),
              ),
            ),
          ),
          SizedBox(width: unit * 0.3),
          Icon(Icons.star, color: Colors.amberAccent, size: unit * 1.2),
        ],
      );
    }
    final icon = rockets ? Icons.rocket_launch : Icons.star;
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: unit * 0.15,
      children: [
        for (var i = 0; i < cost; i++)
          // Siblings in a Wrap can't share a key (Flutter asserts "Duplicate
          // keys found"), so the slot key sits on the icon, one level below
          // an unkeyed box the same size as the icon. Tests find slots by it.
          SizedBox.square(
            dimension: unit,
            child: Icon(
              icon,
              key: ValueKey(i < filled ? 'meter_filled' : 'meter_empty'),
              size: unit,
              color: i < filled
                  ? (rockets ? Colors.cyanAccent : Colors.amberAccent)
                  : Colors.white.withValues(alpha: 0.25),
            ),
          ),
      ],
    );
  }
}

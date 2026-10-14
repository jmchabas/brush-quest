// lib/widgets/goal_glow.dart
import 'package:flutter/material.dart';

/// A pulsing gold ring on the closest next unlock, on a page in brush mode
/// (spec 2026-10-13 §4.1). It paints around [child] without changing its
/// size: the glow behind it, the ring over its edge. [circle] for planets.
class GoalGlow extends StatefulWidget {
  const GoalGlow({
    super.key,
    required this.child,
    this.borderRadius = 12,
    this.circle = false,
  });

  final Widget child;

  /// Corner radius of the ring; unused for a [circle].
  final double borderRadius;
  final bool circle;

  static const color = Color(0xFFFFD54F);

  @override
  State<GoalGlow> createState() => _GoalGlowState();
}

class _GoalGlowState extends State<GoalGlow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    duration: const Duration(milliseconds: 1200),
    vsync: this,
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shape = widget.circle ? BoxShape.circle : BoxShape.rectangle;
    final radius = widget.circle
        ? null
        : BorderRadius.circular(widget.borderRadius);
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        final t = _pulse.value;
        return Container(
          decoration: BoxDecoration(
            shape: shape,
            borderRadius: radius,
            boxShadow: [
              BoxShadow(
                color: GoalGlow.color.withValues(alpha: 0.25 + 0.35 * t),
                blurRadius: 10 + 10 * t,
                spreadRadius: 1 + 2 * t,
              ),
            ],
          ),
          foregroundDecoration: BoxDecoration(
            shape: shape,
            borderRadius: radius,
            border: Border.all(
              color: GoalGlow.color.withValues(alpha: 0.7 + 0.3 * t),
              width: 3,
            ),
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

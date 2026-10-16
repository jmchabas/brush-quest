// lib/widgets/step_header.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// The HEROES · WEAPONS · WORLD bar on each brush step (spec
/// docs/superpowers/specs/2026-10-15-sticker-card-design.md §3.1), in the
/// look of the Heroes & Weapons page's own tab bar. It lights the step in
/// [current] and reports every tap through [onTap]; the steps decide what a
/// tap does.
class StepHeader extends StatelessWidget {
  const StepHeader({super.key, required this.current, required this.onTap});

  /// The step on screen: 0 heroes, 1 weapons, 2 world.
  final ValueListenable<int> current;

  /// He tapped tab 0, 1 or 2 (the lit one too).
  final ValueChanged<int> onTap;

  /// As tall as the page's own tab bar, so what is below it stays put.
  static const double height = 48;

  static const _tabs = [
    (label: 'HEROES', icon: Icons.shield),
    (label: 'WEAPONS', icon: Icons.bolt),
    (label: 'WORLD', icon: Icons.public),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ValueListenableBuilder<int>(
        valueListenable: current,
        builder: (context, lit, _) => Row(
          children: [
            for (var i = 0; i < _tabs.length; i++)
              Expanded(
                child: _StepTab(
                  key: ValueKey('step_tab_$i'),
                  label: _tabs[i].label,
                  icon: _tabs[i].icon,
                  lit: i == lit,
                  onTap: () => onTap(i),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StepTab extends StatelessWidget {
  const _StepTab({
    super.key,
    required this.label,
    required this.icon,
    required this.lit,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool lit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = lit ? Colors.white : Colors.white54;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: lit
                ? const Color(0xFF7C4DFF).withValues(alpha: 0.4)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          // A narrow phone or a large system text size shrinks the label
          // instead of cutting it.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 20, color: color),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

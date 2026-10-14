// lib/widgets/go_button.dart
import 'package:flutter/material.dart';

/// The brush steps' big GO: the tutorial's NEXT gradient and glow, pulsing
/// gently. An arrow on the Heroes & Weapons steps, a rocket on the Map
/// ([rocket]): the label and the icon together, so a child who can't read
/// still knows it.
class GoButton extends StatefulWidget {
  const GoButton({super.key, required this.onPressed, this.rocket = false});

  /// Null disables it (after "Let's fight!").
  final VoidCallback? onPressed;
  final bool rocket;

  @override
  State<GoButton> createState() => _GoButtonState();
}

class _GoButtonState extends State<GoButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _syncPulse();
  }

  @override
  void didUpdateWidget(covariant GoButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncPulse();
  }

  /// It pulses only while it can be pressed.
  void _syncPulse() {
    final enabled = widget.onPressed != null;
    if (enabled && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!enabled && _pulse.isAnimating) {
      _pulse
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) =>
          Transform.scale(scale: 1.0 + _pulse.value * 0.04, child: child),
      child: Semantics(
        button: true,
        child: GestureDetector(
          onTap: widget.onPressed,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: enabled ? 1.0 : 0.5,
            child: Container(
              width: 200,
              height: 76,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF7C4DFF), Color(0xFF9C27B0)],
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF7C4DFF).withValues(alpha: 0.4),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'GO!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Icon(
                    widget.rocket ? Icons.rocket_launch : Icons.arrow_forward,
                    color: Colors.white,
                    size: 32,
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

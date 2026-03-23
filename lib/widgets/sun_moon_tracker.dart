import 'package:flutter/material.dart';

/// Shows daily morning/evening brush completion as sun and moon slot icons.
///
/// Visual states:
/// - Neither done: both slots dimmed, star_outline in center
/// - One done:     filled slot glows, unfilled slot dim, pulsing [Icons.star] center
/// - Both done:    both slots glow, static golden glowing star center
class SunMoonTracker extends StatefulWidget {
  final bool morningDone;
  final bool eveningDone;

  const SunMoonTracker({
    super.key,
    required this.morningDone,
    required this.eveningDone,
  });

  @override
  State<SunMoonTracker> createState() => _SunMoonTrackerState();
}

class _SunMoonTrackerState extends State<SunMoonTracker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _opacityAnim;
  late final Animation<double> _scaleAnim;

  // Sun: gold; Moon: silver-blue
  static const Color _sunColor = Color(0xFFFFD54F);
  static const Color _moonColor = Color(0xFF90CAF9);

  bool get _oneDone =>
      widget.morningDone != widget.eveningDone; // XOR
  bool get _bothDone => widget.morningDone && widget.eveningDone;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _opacityAnim = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _scaleAnim = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _updateAnimation();
  }

  @override
  void didUpdateWidget(SunMoonTracker oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateAnimation();
  }

  void _updateAnimation() {
    if (_oneDone) {
      _pulseController.repeat(reverse: true);
    } else {
      _pulseController.stop();
      _pulseController.value = 1.0;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Widget _buildSlot({
    required IconData icon,
    required bool done,
    required Color activeColor,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: done
            ? activeColor.withValues(alpha: 0.20)
            : Colors.white.withValues(alpha: 0.15),
        border: Border.all(
          color: done
              ? activeColor
              : Colors.white.withValues(alpha: 0.40),
          width: 2,
        ),
        boxShadow: done
            ? [
                BoxShadow(
                  color: activeColor.withValues(alpha: 0.45),
                  blurRadius: 10,
                  spreadRadius: 1,
                )
              ]
            : null,
      ),
      child: Icon(
        icon,
        size: 22,
        color: done
            ? activeColor
            : Colors.white.withValues(alpha: 0.40),
      ),
    );
  }

  Widget _buildCenterStar() {
    if (_bothDone) {
      // Static glowing star
      return Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        child: Icon(
          Icons.star,
          size: 22,
          color: _sunColor,
          shadows: const [
            Shadow(
              color: Color(0xFFFFD54F),
              blurRadius: 16,
            ),
          ],
        ),
      );
    }

    if (_oneDone) {
      // Pulsing star
      return AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          return Opacity(
            opacity: _opacityAnim.value,
            child: Transform.scale(
              scale: _scaleAnim.value,
              child: child,
            ),
          );
        },
        child: const SizedBox(
          width: 28,
          height: 28,
          child: Icon(
            Icons.star,
            size: 22,
            color: Color(0xFFFFD54F),
          ),
        ),
      );
    }

    // Neither done — dimmed outline star
    return SizedBox(
      width: 28,
      height: 28,
      child: Icon(
        Icons.star_outline,
        size: 22,
        color: Colors.white.withValues(alpha: 0.30),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildSlot(
            icon: Icons.wb_sunny,
            done: widget.morningDone,
            activeColor: _sunColor,
          ),
          const SizedBox(width: 10),
          _buildCenterStar(),
          const SizedBox(width: 10),
          _buildSlot(
            icon: Icons.nightlight_round,
            done: widget.eveningDone,
            activeColor: _moonColor,
          ),
        ],
      ),
    );
  }
}

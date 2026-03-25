import 'dart:async';

import 'package:flutter/material.dart';

/// A data class describing one wave of stars in the StarRain animation.
class _StarWave {
  final int count;
  final Color color;
  final Color glowColor;
  final IconData sourceIcon;
  final String? sourceImagePath;
  final String? label;
  final bool hasTrail;

  const _StarWave({
    required this.count,
    required this.color,
    required this.glowColor,
    required this.sourceIcon,
    this.sourceImagePath,
    this.label,
    this.hasTrail = false,
  });
}

/// Displays earned stars in sequential animated waves.
///
/// Shows up to three waves:
///   1. Base stars (brushing, always shown)
///   2. Streak bonus (shown when [streakBonus] > 0)
///   3. Daily bonus (shown when [dailyBonus] > 0)
///
/// Tapping anywhere skips to the grand total and calls [onComplete].
class StarRain extends StatefulWidget {
  final int baseStars;
  final int streakBonus;
  final int dailyBonus;
  final int currentStreak;
  final VoidCallback? onComplete;

  const StarRain({
    super.key,
    required this.baseStars,
    this.streakBonus = 0,
    this.dailyBonus = 0,
    this.currentStreak = 0,
    this.onComplete,
  });

  @override
  State<StarRain> createState() => _StarRainState();
}

class _StarRainState extends State<StarRain> with TickerProviderStateMixin {
  late final List<_StarWave> _waves;
  late final List<AnimationController> _controllers;
  late final List<Animation<double>> _scaleAnims;
  late final List<Animation<double>> _fadeAnims;

  // Running total displayed above the waves.
  int _displayedTotal = 0;

  // Whether the skip has been triggered (prevents double-firing).
  bool _skipped = false;

  // Pending timer so we can cancel it on skip.
  Timer? _sequenceTimer;

  @override
  void initState() {
    super.initState();
    _waves = _buildWaves();
    _controllers = List.generate(
      _waves.length,
      (_) => AnimationController(
        duration: const Duration(milliseconds: 600),
        vsync: this,
      ),
    );

    _scaleAnims = _controllers
        .map(
          (c) => Tween<double>(begin: 0.4, end: 1.0).animate(
            CurvedAnimation(parent: c, curve: Curves.elasticOut),
          ),
        )
        .toList();

    _fadeAnims = _controllers
        .map(
          (c) => Tween<double>(begin: 0.0, end: 1.0).animate(
            CurvedAnimation(parent: c, curve: Curves.easeIn),
          ),
        )
        .toList();

    _startSequence();
  }

  List<_StarWave> _buildWaves() {
    final waves = <_StarWave>[];

    // Wave 1: base brush stars — always present.
    waves.add(_StarWave(
      count: widget.baseStars,
      color: const Color(0xFFFFD54F), // gold
      glowColor: const Color(0xFFFFF176),
      sourceIcon: Icons.cleaning_services,
      sourceImagePath: 'assets/images/icon_toothbrush.png',
    ));

    // Wave 2: streak bonus.
    if (widget.streakBonus > 0) {
      final isMega = widget.currentStreak >= 7;
      waves.add(_StarWave(
        count: widget.streakBonus,
        color: isMega ? const Color(0xFF40C4FF) : const Color(0xFFFF7043),
        glowColor:
            isMega ? const Color(0xFF80D8FF) : const Color(0xFFFFAB91),
        sourceIcon: Icons.local_fire_department,
        label: isMega ? 'MEGA POWER!' : 'STREAK BONUS!',
        hasTrail: true,
      ));
    }

    // Wave 3: daily bonus.
    if (widget.dailyBonus > 0) {
      waves.add(_StarWave(
        count: widget.dailyBonus,
        color: const Color(0xFFE0E0E0), // silver-gold
        glowColor: const Color(0xFFFFEE58),
        sourceIcon: Icons.brightness_6,
        label: 'FULL CHARGE!',
      ));
    }

    return waves;
  }

  void _startSequence() {
    // 200ms initial delay before first wave.
    _scheduleWave(0, const Duration(milliseconds: 200));
  }

  void _scheduleWave(int index, Duration delay) {
    if (_skipped) return;
    _sequenceTimer = Timer(delay, () {
      if (_skipped || !mounted) return;
      _playWave(index);
    });
  }

  void _playWave(int index) {
    if (_skipped || !mounted) return;
    _controllers[index].forward().then((_) {
      if (_skipped || !mounted) return;
      final newTotal =
          _waves.sublist(0, index + 1).fold<int>(0, (s, w) => s + w.count);
      setState(() => _displayedTotal = newTotal);

      if (index + 1 < _waves.length) {
        _scheduleWave(index + 1, const Duration(milliseconds: 500));
      } else {
        // All waves complete.
        widget.onComplete?.call();
      }
    });
  }

  void _skip() {
    if (_skipped) return;
    _skipped = true;
    _sequenceTimer?.cancel();
    _sequenceTimer = null;

    // Snap all controllers to their end state instantly.
    for (final c in _controllers) {
      c.value = 1.0;
    }

    final total = _waves.fold<int>(0, (s, w) => s + w.count);
    setState(() => _displayedTotal = total);
    widget.onComplete?.call();
  }

  @override
  void dispose() {
    _sequenceTimer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _skip,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Running total counter.
          Text(
            '+$_displayedTotal',
            style: const TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              shadows: [
                Shadow(
                  color: Color(0xFFFFD54F),
                  blurRadius: 16,
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'STARS EARNED',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white70,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 24),
          // Wave indicators row.
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(_waves.length, (i) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: _WaveIndicator(
                  wave: _waves[i],
                  scaleAnim: _scaleAnims[i],
                  fadeAnim: _fadeAnims[i],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _WaveIndicator extends StatelessWidget {
  final _StarWave wave;
  final Animation<double> scaleAnim;
  final Animation<double> fadeAnim;

  const _WaveIndicator({
    required this.wave,
    required this.scaleAnim,
    required this.fadeAnim,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: scaleAnim,
      builder: (context, child) {
        final revealed = scaleAnim.value > 0.41;
        return Opacity(
          opacity: revealed ? fadeAnim.value.clamp(0.2, 1.0) : 0.2,
          child: Transform.scale(
            scale: scaleAnim.value.clamp(0.4, 1.0),
            child: child,
          ),
        );
      },
      child: Column(
        children: [
          // Source icon circle.
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: wave.color.withValues(alpha: 0.2),
              border: Border.all(color: wave.color, width: 2),
              boxShadow: [
                BoxShadow(
                  color: wave.glowColor.withValues(alpha: 0.4),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: wave.sourceImagePath != null
                ? ImageIcon(
                    AssetImage(wave.sourceImagePath!),
                    color: wave.color,
                    size: 26,
                  )
                : Icon(wave.sourceIcon, color: wave.color, size: 26),
          ),
          const SizedBox(height: 6),
          // Star icons.
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(
              wave.count,
              (_) => Icon(Icons.star, color: wave.color, size: 18),
            ),
          ),
          // Optional label.
          if (wave.label != null) ...[
            const SizedBox(height: 4),
            Text(
              wave.label!,
              style: TextStyle(
                fontSize: 9,
                color: wave.color,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

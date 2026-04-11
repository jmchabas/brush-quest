import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../services/audio_service.dart';
import '../services/world_service.dart';
import '../widgets/space_background.dart';

class WorldMapScreen extends StatefulWidget {
  const WorldMapScreen({super.key});

  @override
  State<WorldMapScreen> createState() => _WorldMapScreenState();
}

class _WorldMapScreenState extends State<WorldMapScreen> {
  static bool _introPlayedThisSession = false;

  final _worldService = WorldService();
  String _currentWorldId = 'candy_crater';
  final Map<String, int> _progress = {};
  final Map<String, bool> _unlocked = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final currentId = await _worldService.getCurrentWorldId();
    final progress = <String, int>{};
    final unlocked = <String, bool>{};

    for (final world in WorldService.allWorlds) {
      progress[world.id] = await _worldService.getWorldProgress(world.id);
      unlocked[world.id] = await _worldService.isWorldUnlocked(world.id);
    }

    if (mounted) {
      setState(() {
        _currentWorldId = currentId;
        _progress.addAll(progress);
        _unlocked.addAll(unlocked);
      });
      // Ambient music — low volume so voice lines stay clear
      unawaited(AudioService().playMusic('battle_music_loop.mp3'));
      unawaited(AudioService().setMusicVolume(0.04));

      // Play intro voice only once per app session, then world description
      if (!_introPlayedThisSession) {
        _introPlayedThisSession = true;
        unawaited(AudioService().playVoice('voice_world_map_intro.mp3', clearQueue: true, interrupt: true));
        unawaited(AudioService().playVoice('voice_world_$currentId.mp3'));
      } else {
        unawaited(AudioService().playVoice('voice_world_$currentId.mp3', clearQueue: true, interrupt: true));
      }
    }
  }

  @override
  void dispose() {
    AudioService().stopVoice();
    AudioService().stopMusic();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SpaceBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                        AudioService().stopVoice();
                        Navigator.of(context).pop();
                      },
                        borderRadius: BorderRadius.circular(18),
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.18),
                              width: 1.5,
                            ),
                          ),
                          child: const Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'WORLD MAP',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 28,
                            letterSpacing: 3,
                          ),
                    ),
                  ],
                ),
              ),

              // World path — scrollable adventure trail
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 40, top: 8),
                  child: _buildAdventurePath(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAdventurePath(BuildContext context) {
    const worlds = WorldService.allWorlds;
    final screenWidth = MediaQuery.of(context).size.width;
    // Horizontal offset for zigzag: planets alternate left/right
    final zigzagOffset = screenWidth * 0.15;

    final children = <Widget>[];

    for (int i = 0; i < worlds.length; i++) {
      final world = worlds[i];
      final isUnlocked = _unlocked[world.id] ?? false;
      final isCurrent = world.id == _currentWorldId;
      final progress = _progress[world.id] ?? 0;
      final isCompleted = progress >= world.missionsRequired;

      // Determine horizontal alignment: even = left, odd = right
      final isRight = i.isOdd;
      final horizontalPadding = EdgeInsets.only(
        left: isRight ? zigzagOffset * 2 : 24,
        right: isRight ? 24 : zigzagOffset * 2,
      );

      // Draw curved dashed connector line between planets
      if (i > 0) {
        final prevUnlocked = _unlocked[worlds[i - 1].id] ?? false;
        final prevRight = (i - 1).isOdd;
        children.add(
          SizedBox(
            height: 60,
            child: CustomPaint(
              size: Size(screenWidth, 60),
              painter: _CurvedDashPainter(
                fromRight: prevRight,
                toRight: isRight,
                zigzagOffset: zigzagOffset,
                screenWidth: screenWidth,
                isActive: prevUnlocked && isUnlocked,
                color: isUnlocked
                    ? world.themeColor.withValues(alpha: 0.6)
                    : Colors.white.withValues(alpha: 0.12),
              ),
            ),
          ),
        );
      }

      // Planet node
      children.add(
        Padding(
          padding: horizontalPadding,
          child: _PlanetNode(
            world: world,
            isUnlocked: isUnlocked,
            isCurrent: isCurrent,
            isCompleted: isCompleted,
            progress: progress,
            onTap: () {
              // Always play the world description voice
              AudioService().playVoice('voice_world_${world.id}.mp3', clearQueue: true, interrupt: true);
              if (!isUnlocked) {
                // Locked world — describe world, then say needs more brushing
                AudioService().playVoice('voice_need_stars.mp3');
                return;
              }
              if (!isCurrent) {
                // Unlocked but not current — set as current world (completed worlds can be revisited)
                _setCurrentWorld(world);
              }
            },
          ),
        ),
      );
    }

    return Column(children: children);
  }

  Future<void> _setCurrentWorld(WorldData world) async {
    await _worldService.setCurrentWorld(world.id);
    await _loadData();
    if (mounted) {
      // Visual confirmation: brief glow animation on the selected planet
      // (the planet node already shows a check icon when selected)
      // Voice already played by onTap handler — no duplicate here
    }
  }
}

/// Draws a curved dashed line between two planet nodes.
class _CurvedDashPainter extends CustomPainter {
  final bool fromRight;
  final bool toRight;
  final double zigzagOffset;
  final double screenWidth;
  final bool isActive;
  final Color color;

  _CurvedDashPainter({
    required this.fromRight,
    required this.toRight,
    required this.zigzagOffset,
    required this.screenWidth,
    required this.isActive,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Calculate center x positions of from/to planets
    // Planet nodes are centered within their padded containers
    // Even (left-aligned): center is at ~(24 + planetSize/2) from left
    // Odd (right-aligned): center is at ~(screenWidth - 24 - planetSize/2) from left
    const planetSize = 100.0;
    const leftCenter = 24.0 + planetSize / 2;
    final rightCenter = screenWidth - 24.0 - zigzagOffset * 2 + planetSize / 2;

    // Adjust for actual available width
    final fromX = fromRight ? rightCenter : leftCenter;
    final toX = toRight ? rightCenter : leftCenter;

    final startPoint = Offset(fromX, 0);
    final endPoint = Offset(toX, size.height);

    // Create a smooth curve between the two points
    final path = Path();
    path.moveTo(startPoint.dx, startPoint.dy);
    // Use a cubic bezier with control points that create a nice S-curve
    final midY = size.height / 2;
    path.cubicTo(
      fromX, midY,
      toX, midY,
      endPoint.dx, endPoint.dy,
    );

    // Draw as dashed line
    _drawDashedPath(canvas, path, paint, dashLength: 6, gapLength: 5);
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint,
      {double dashLength = 6, double gapLength = 5}) {
    final metrics = path.computeMetrics();
    for (final metric in metrics) {
      double distance = 0;
      while (distance < metric.length) {
        final end = min(distance + dashLength, metric.length);
        final extractPath = metric.extractPath(distance, end);
        canvas.drawPath(extractPath, paint);
        distance += dashLength + gapLength;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CurvedDashPainter oldDelegate) {
    return oldDelegate.isActive != isActive || oldDelegate.color != color;
  }
}

/// A single planet node on the adventure path.
class _PlanetNode extends StatefulWidget {
  final WorldData world;
  final bool isUnlocked;
  final bool isCurrent;
  final bool isCompleted;
  final int progress;
  final VoidCallback onTap;

  const _PlanetNode({
    required this.world,
    required this.isUnlocked,
    required this.isCurrent,
    required this.isCompleted,
    required this.progress,
    required this.onTap,
  });

  @override
  State<_PlanetNode> createState() => _PlanetNodeState();
}

class _PlanetNodeState extends State<_PlanetNode>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    if (widget.isCurrent) {
      _glowController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant _PlanetNode oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isCurrent && !oldWidget.isCurrent) {
      _glowController.repeat(reverse: true);
    } else if (!widget.isCurrent && oldWidget.isCurrent) {
      _glowController.stop();
      _glowController.value = 0;
    }
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final planetSize = widget.isCurrent ? 120.0 : 100.0;
    final opacity = widget.isUnlocked ? 1.0 : 0.65;

    return GestureDetector(
      onTap: widget.onTap,
      child: Opacity(
        opacity: opacity,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Animated pulsing beacon for current world
            if (widget.isCurrent)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: AnimatedBuilder(
                  animation: _glowController,
                  builder: (context, _) {
                    final ringScale = 1.0 + _glowController.value * 0.4;
                    final ringOpacity = 0.6 - _glowController.value * 0.4;
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        // Expanding ring
                        Transform.scale(
                          scale: ringScale,
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: widget.world.themeColor
                                    .withValues(alpha: ringOpacity),
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                        // Rocket icon
                        Icon(
                          Icons.rocket_launch,
                          color: widget.world.themeColor,
                          size: 18,
                        ),
                      ],
                    );
                  },
                ),
              ),

            // Planet image with glow and overlays
            AnimatedBuilder(
              animation: _glowController,
              builder: (context, child) {
                final glowAlpha = widget.isCurrent
                    ? 0.3 + 0.5 * _glowController.value
                    : 0.0;
                final glowBlur = widget.isCurrent
                    ? 16.0 + 20.0 * _glowController.value
                    : 0.0;
                return Container(
                  width: planetSize + 16,
                  height: planetSize + 16,
                  decoration: widget.isCurrent
                      ? BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: widget.world.themeColor.withValues(alpha: glowAlpha),
                              blurRadius: glowBlur,
                              spreadRadius: 4,
                            ),
                          ],
                        )
                      : null,
                  child: child,
                );
              },
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Planet image
                  SizedBox(
                    width: planetSize,
                    height: planetSize,
                    child: ColorFiltered(
                      colorFilter: widget.isUnlocked
                          ? const ColorFilter.mode(Colors.transparent, BlendMode.dst)
                          : ColorFilter.mode(
                              Colors.black.withValues(alpha: 0.35),
                              BlendMode.srcATop,
                            ),
                      child: ClipOval(
                        child: Image.asset(widget.world.imagePath, fit: BoxFit.cover),
                      ),
                    ),
                  ),

                  // Completed checkmark overlay
                  if (widget.isCompleted)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: const Color(0xFF69F0AE),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF69F0AE).withValues(alpha: 0.5),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.check, color: Colors.white, size: 18),
                      ),
                    ),

                  // Lock icon overlay for locked worlds
                  if (!widget.isUnlocked)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3),
                            width: 1.5,
                          ),
                        ),
                        child: Icon(
                          Icons.lock,
                          color: Colors.white.withValues(alpha: 0.7),
                          size: 14,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 6),

            // World name
            Text(
              widget.world.name.toUpperCase(),
              style: TextStyle(
                color: widget.isCurrent
                    ? Colors.white
                    : widget.isUnlocked
                        ? Colors.white.withValues(alpha: 0.85)
                        : Colors.white.withValues(alpha: 0.4),
                fontWeight: FontWeight.bold,
                fontSize: widget.isCurrent ? 15 : 13,
                letterSpacing: 1.5,
              ),
            ),

            const SizedBox(height: 4),

            // Progress indicator: filled/empty star icons
            if (widget.isUnlocked)
              widget.isCompleted
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF69F0AE).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFF69F0AE).withValues(alpha: 0.4),
                          width: 1,
                        ),
                      ),
                      child: const Text(
                        'COMPLETE',
                        style: TextStyle(
                          color: Color(0xFF69F0AE),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(widget.world.missionsRequired, (i) {
                        final filled = i < widget.progress;
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 1),
                          child: Icon(
                            filled ? Icons.star_rounded : Icons.star_outline_rounded,
                            color: filled
                                ? const Color(0xFFFFD54F)
                                : Colors.white.withValues(alpha: 0.3),
                            size: 14,
                          ),
                        );
                      }),
                    ),
          ],
        ),
      ),
    );
  }
}

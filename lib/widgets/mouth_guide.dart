import 'package:flutter/material.dart';

enum MouthQuadrant {
  topLeft,
  topFront,
  topRight,
  bottomLeft,
  bottomFront,
  bottomRight,
}

class MouthGuide extends StatelessWidget {
  final MouthQuadrant activeQuadrant;
  final double glowAnim;
  final Color highlightColor;
  final double size;
  final bool showLabels;

  const MouthGuide({
    super.key,
    required this.activeQuadrant,
    this.glowAnim = 0.0,
    this.highlightColor = const Color(0xFF00E5FF),
    this.size = 200,
    this.showLabels = false,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size * 1.15),
      painter: _MouthGuidePainter(
        activeQuadrant: activeQuadrant,
        glowAnim: glowAnim,
        highlightColor: highlightColor,
        showLabels: showLabels,
      ),
    );
  }
}

class _MouthGuidePainter extends CustomPainter {
  final MouthQuadrant activeQuadrant;
  final double glowAnim;
  final Color highlightColor;
  final bool showLabels;

  _MouthGuidePainter({
    required this.activeQuadrant,
    required this.glowAnim,
    required this.highlightColor,
    required this.showLabels,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final cy = h / 2;

    // Mouth background shape — rounded oval
    final mouthPath = Path();
    final mouthRect = Rect.fromCenter(
      center: Offset(cx, cy),
      width: w * 0.92,
      height: h * 0.88,
    );
    mouthPath.addRRect(RRect.fromRectAndRadius(mouthRect, Radius.circular(w * 0.38)));

    // Dark mouth interior
    canvas.drawPath(mouthPath, Paint()..color = const Color(0xFF1A0808));

    // Lip outline with glow
    canvas.drawPath(
      mouthPath,
      Paint()
        ..color = const Color(0xFFE57373).withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawPath(
      mouthPath,
      Paint()
        ..color = const Color(0xFFFF8A80)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    // Clip to mouth shape
    canvas.save();
    canvas.clipPath(mouthPath);

    // Gum areas
    final gumColor = const Color(0xFFD4737D);
    _drawGums(canvas, w, h, gumColor);

    // Draw teeth
    _drawTeethRow(canvas, w, h, isUpper: true);
    _drawTeethRow(canvas, w, h, isUpper: false);

    // Tongue hint (pinkish oval at bottom-center)
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, h * 0.62), width: w * 0.35, height: h * 0.12),
      Paint()..color = const Color(0xFFE88994).withValues(alpha: 0.5),
    );

    canvas.restore();

    // Zone dividers (subtle) — 3 columns, 2 rows
    final dividerPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..strokeWidth = 1.5;
    // Left vertical divider (1/3 mark)
    canvas.drawLine(Offset(w * 0.33, h * 0.1), Offset(w * 0.33, h * 0.9), dividerPaint);
    // Right vertical divider (2/3 mark)
    canvas.drawLine(Offset(w * 0.67, h * 0.1), Offset(w * 0.67, h * 0.9), dividerPaint);
    // Horizontal center line
    canvas.drawLine(Offset(w * 0.08, cy), Offset(w * 0.92, cy), dividerPaint);

    // Active zone glow overlay
    _drawZoneHighlight(canvas, w, h, cx, cy);

    // Sparkle indicator in active zone
    _drawBrushIndicator(canvas, w, h, cx, cy);
  }

  void _drawGums(Canvas canvas, double w, double h, Color color) {
    // Upper gum (arc)
    final upperGumPath = Path();
    upperGumPath.moveTo(w * 0.06, h * 0.35);
    upperGumPath.quadraticBezierTo(w * 0.5, h * 0.08, w * 0.94, h * 0.35);
    upperGumPath.lineTo(w * 0.94, h * 0.12);
    upperGumPath.quadraticBezierTo(w * 0.5, h * 0.02, w * 0.06, h * 0.12);
    upperGumPath.close();
    canvas.drawPath(upperGumPath, Paint()..color = color);

    // Lower gum (arc)
    final lowerGumPath = Path();
    lowerGumPath.moveTo(w * 0.06, h * 0.65);
    lowerGumPath.quadraticBezierTo(w * 0.5, h * 0.92, w * 0.94, h * 0.65);
    lowerGumPath.lineTo(w * 0.94, h * 0.88);
    lowerGumPath.quadraticBezierTo(w * 0.5, h * 0.98, w * 0.06, h * 0.88);
    lowerGumPath.close();
    canvas.drawPath(lowerGumPath, Paint()..color = color);
  }

  /// Map a tooth index (0-based out of teethCount) to its zone.
  MouthQuadrant _toothZone(int i, int teethCount, bool isUpper) {
    // 10 teeth: indices 0-2 = left, 3-6 = front, 7-9 = right
    // 3 left teeth, 4 front teeth, 3 right teeth
    final leftEnd = (teethCount * 0.3).floor(); // 3
    final rightStart = teethCount - leftEnd;     // 7

    if (i < leftEnd) {
      return isUpper ? MouthQuadrant.topLeft : MouthQuadrant.bottomLeft;
    } else if (i >= rightStart) {
      return isUpper ? MouthQuadrant.topRight : MouthQuadrant.bottomRight;
    } else {
      return isUpper ? MouthQuadrant.topFront : MouthQuadrant.bottomFront;
    }
  }

  void _drawTeethRow(Canvas canvas, double w, double h, {required bool isUpper}) {
    final teethCount = 10;
    final cx = w / 2;
    final toothW = w * 0.072;
    final toothH = h * 0.16;
    final gap = w * 0.012;
    final totalWidth = teethCount * toothW + (teethCount - 1) * gap;
    final startX = cx - totalWidth / 2;

    for (int i = 0; i < teethCount; i++) {
      final x = startX + i * (toothW + gap);

      final quadrant = _toothZone(i, teethCount, isUpper);
      final isActive = activeQuadrant == quadrant;

      // Slight arc: teeth near center are taller
      final distFromCenter = ((i - (teethCount - 1) / 2).abs()) / ((teethCount - 1) / 2);
      final heightMod = 1.0 - distFromCenter * 0.3;
      final widthMod = 1.0 - distFromCenter * 0.15;
      final actualH = toothH * heightMod;
      final actualW = toothW * widthMod;

      // Arc positioning: teeth curve slightly
      final arcOffset = distFromCenter * distFromCenter * h * 0.04;

      double toothY;
      if (isUpper) {
        toothY = h * 0.2 + arcOffset;
      } else {
        toothY = h * 0.64 - arcOffset + (toothH - actualH);
      }

      final toothRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x + (toothW - actualW) / 2, toothY, actualW, actualH),
        Radius.circular(actualW * 0.25),
      );

      if (isActive) {
        // Glow behind active tooth
        final glowIntensity = 0.25 + glowAnim * 0.35;
        canvas.drawRRect(
          toothRect.inflate(3),
          Paint()
            ..color = highlightColor.withValues(alpha: glowIntensity)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
        );
        // Bright tooth
        canvas.drawRRect(toothRect, Paint()..color = Colors.white);
        // Highlight border
        canvas.drawRRect(
          toothRect,
          Paint()
            ..color = highlightColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      } else {
        // Dim tooth
        canvas.drawRRect(
          toothRect,
          Paint()..color = Colors.white.withValues(alpha: 0.25),
        );
        canvas.drawRRect(
          toothRect,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.1)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.5,
        );
      }
    }
  }

  /// Get the bounding rect for a 6-zone layout.
  Rect _zoneRect(MouthQuadrant zone, double w, double h, double cx, double cy) {
    // 3 columns: left=[0.06, 0.33], front=[0.33, 0.67], right=[0.67, 0.94]
    // 2 rows: top=[0.06, cy], bottom=[cy, 0.94]
    switch (zone) {
      case MouthQuadrant.topLeft:
        return Rect.fromLTRB(w * 0.06, h * 0.06, w * 0.33, cy);
      case MouthQuadrant.topFront:
        return Rect.fromLTRB(w * 0.33, h * 0.06, w * 0.67, cy);
      case MouthQuadrant.topRight:
        return Rect.fromLTRB(w * 0.67, h * 0.06, w * 0.94, cy);
      case MouthQuadrant.bottomLeft:
        return Rect.fromLTRB(w * 0.06, cy, w * 0.33, h * 0.94);
      case MouthQuadrant.bottomFront:
        return Rect.fromLTRB(w * 0.33, cy, w * 0.67, h * 0.94);
      case MouthQuadrant.bottomRight:
        return Rect.fromLTRB(w * 0.67, cy, w * 0.94, h * 0.94);
    }
  }

  void _drawZoneHighlight(Canvas canvas, double w, double h, double cx, double cy) {
    final quadRect = _zoneRect(activeQuadrant, w, h, cx, cy);

    final glowAlpha = 0.05 + glowAnim * 0.08;
    canvas.drawRect(
      quadRect,
      Paint()
        ..color = highlightColor.withValues(alpha: glowAlpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );
  }

  void _drawBrushIndicator(Canvas canvas, double w, double h, double cx, double cy) {
    final quadRect = _zoneRect(activeQuadrant, w, h, cx, cy);
    final bx = quadRect.center.dx;
    final by = quadRect.center.dy;

    // Animated sparkle circle
    final sparkleSize = 6.0 + glowAnim * 4.0;
    final sparkleAlpha = 0.5 + glowAnim * 0.5;

    // Outer glow ring
    canvas.drawCircle(
      Offset(bx, by),
      sparkleSize + 6,
      Paint()
        ..color = highlightColor.withValues(alpha: sparkleAlpha * 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    // Sparkle cross
    final sPaint = Paint()
      ..color = Colors.white.withValues(alpha: sparkleAlpha)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(bx - sparkleSize, by),
      Offset(bx + sparkleSize, by),
      sPaint,
    );
    canvas.drawLine(
      Offset(bx, by - sparkleSize),
      Offset(bx, by + sparkleSize),
      sPaint,
    );
    // Diagonal sparkle lines
    final diagSize = sparkleSize * 0.6;
    canvas.drawLine(
      Offset(bx - diagSize, by - diagSize),
      Offset(bx + diagSize, by + diagSize),
      sPaint..strokeWidth = 1.5,
    );
    canvas.drawLine(
      Offset(bx + diagSize, by - diagSize),
      Offset(bx - diagSize, by + diagSize),
      sPaint,
    );
  }

  @override
  bool shouldRepaint(_MouthGuidePainter oldDelegate) =>
      activeQuadrant != oldDelegate.activeQuadrant ||
      glowAnim != oldDelegate.glowAnim ||
      highlightColor != oldDelegate.highlightColor;
}

/// Large mouth guide overlay shown at phase transitions
class MouthGuideOverlay extends StatefulWidget {
  final MouthQuadrant quadrant;
  final Color themeColor;
  final String label;
  final VoidCallback onDismiss;

  const MouthGuideOverlay({
    super.key,
    required this.quadrant,
    required this.themeColor,
    required this.label,
    required this.onDismiss,
  });

  @override
  State<MouthGuideOverlay> createState() => _MouthGuideOverlayState();
}

class _MouthGuideOverlayState extends State<MouthGuideOverlay>
    with TickerProviderStateMixin {
  late AnimationController _entryController;
  late AnimationController _glowController;
  late AnimationController _exitController;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    )..forward();

    _glowController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat(reverse: true);

    _exitController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) {
        _exitController.forward().then((_) {
          widget.onDismiss();
        });
      }
    });
  }

  @override
  void dispose() {
    _entryController.dispose();
    _glowController.dispose();
    _exitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_entryController, _exitController]),
      builder: (context, child) {
        final entryT = CurvedAnimation(parent: _entryController, curve: Curves.easeOutBack).value;
        final exitT = _exitController.value;
        final opacity = entryT * (1.0 - exitT);
        final scale = 0.5 + entryT * 0.5 * (1.0 - exitT * 0.3);

        return Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: Transform.scale(
            scale: scale,
            child: child,
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: widget.themeColor.withValues(alpha: 0.5),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: widget.themeColor.withValues(alpha: 0.3),
              blurRadius: 30,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Label text removed — visual mouth guide is self-explanatory
            AnimatedBuilder(
              animation: _glowController,
              builder: (context, _) => MouthGuide(
                activeQuadrant: widget.quadrant,
                glowAnim: _glowController.value,
                highlightColor: widget.themeColor,
                size: 220,
              ),
            ),
            const SizedBox(height: 12),
            // Pulsing directional arrow — no text (kids can't read)
            AnimatedBuilder(
              animation: _glowController,
              builder: (context, _) {
                final glowAlpha = 0.5 + _glowController.value * 0.5;
                final scale = 1.0 + _glowController.value * 0.15;
                return Transform.scale(
                  scale: scale,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: widget.themeColor.withValues(alpha: glowAlpha * 0.6),
                          blurRadius: 16,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.arrow_downward,
                      color: widget.themeColor.withValues(alpha: glowAlpha),
                      size: 36,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

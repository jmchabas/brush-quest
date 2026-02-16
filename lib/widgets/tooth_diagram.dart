import 'dart:math';
import 'package:flutter/material.dart';

enum ToothQuadrant { topLeft, topRight, bottomLeft, bottomRight }

class ToothDiagram extends StatefulWidget {
  final ToothQuadrant activeQuadrant;
  final Set<ToothQuadrant> completedQuadrants;
  final double size;
  final Color activeColor;

  const ToothDiagram({
    super.key,
    required this.activeQuadrant,
    required this.completedQuadrants,
    this.size = 150,
    this.activeColor = const Color(0xFF00E5FF),
  });

  @override
  State<ToothDiagram> createState() => _ToothDiagramState();
}

class _ToothDiagramState extends State<ToothDiagram>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _brushController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat(reverse: true);
    _brushController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _brushController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_pulseController, _brushController]),
      builder: (context, _) {
        return CustomPaint(
          size: Size(widget.size, widget.size * 0.72),
          painter: _MouthPainter(
            activeQuadrant: widget.activeQuadrant,
            completedQuadrants: widget.completedQuadrants,
            activeColor: widget.activeColor,
            pulseValue: _pulseController.value,
            brushOffset: _brushController.value,
          ),
        );
      },
    );
  }
}

class _MouthPainter extends CustomPainter {
  final ToothQuadrant activeQuadrant;
  final Set<ToothQuadrant> completedQuadrants;
  final Color activeColor;
  final double pulseValue;
  final double brushOffset;

  _MouthPainter({
    required this.activeQuadrant,
    required this.completedQuadrants,
    required this.activeColor,
    required this.pulseValue,
    required this.brushOffset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final centerX = w / 2;

    // Lip dimensions
    final lipTop = h * 0.05;
    final lipBottom = h * 0.95;
    final lipMidY = h * 0.48;
    final lipWidth = w * 0.88;
    final lipLeft = centerX - lipWidth / 2;
    final lipRight = centerX + lipWidth / 2;

    // Draw lip outline — U-shape (open mouth)
    final lipPaint = Paint()
      ..color = const Color(0xFFE57373).withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    final lipPath = Path();
    // Left side going down
    lipPath.moveTo(lipLeft, lipTop);
    lipPath.quadraticBezierTo(lipLeft - 4, lipMidY, lipLeft + 6, lipBottom);
    // Bottom curve
    lipPath.quadraticBezierTo(centerX, lipBottom + 10, lipRight - 6, lipBottom);
    // Right side going up
    lipPath.quadraticBezierTo(lipRight + 4, lipMidY, lipRight, lipTop);
    canvas.drawPath(lipPath, lipPaint);

    // Lip fill (mouth interior)
    final mouthFill = Paint()
      ..color = const Color(0xFF880E4F).withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;
    final fillPath = Path()..addPath(lipPath, Offset.zero);
    fillPath.close();
    canvas.drawPath(fillPath, mouthFill);

    // Tooth geometry
    final teethPerRow = 8;
    final toothAreaWidth = lipWidth * 0.82;
    final toothW = toothAreaWidth / teethPerRow - 2;
    final toothH = h * 0.17;
    final toothRadius = Radius.circular(toothW * 0.35);
    final teethStartX = centerX - toothAreaWidth / 2;

    // Top row — slight upward curve
    final topRowBaseY = lipTop + h * 0.10;
    for (int i = 0; i < teethPerRow; i++) {
      final x = teethStartX + i * (toothW + 2);
      // Curve: teeth in middle are slightly higher
      final curveOffset = -sin((i / (teethPerRow - 1)) * pi) * 4;
      final y = topRowBaseY + curveOffset;
      final isLeft = i < teethPerRow ~/ 2;
      final quadrant = isLeft ? ToothQuadrant.topLeft : ToothQuadrant.topRight;
      _drawTooth(canvas, Rect.fromLTWH(x, y, toothW, toothH), toothRadius,
          quadrant, true);
    }

    // Bottom row — slight downward curve
    final bottomRowBaseY = lipMidY + h * 0.12;
    for (int i = 0; i < teethPerRow; i++) {
      final x = teethStartX + i * (toothW + 2);
      final curveOffset = sin((i / (teethPerRow - 1)) * pi) * 4;
      final y = bottomRowBaseY + curveOffset;
      final isLeft = i < teethPerRow ~/ 2;
      final quadrant =
          isLeft ? ToothQuadrant.bottomLeft : ToothQuadrant.bottomRight;
      _drawTooth(canvas, Rect.fromLTWH(x, y, toothW, toothH), toothRadius,
          quadrant, false);
    }

    // Divider line between left/right
    final dividerPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.1)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(centerX, lipTop + 6),
      Offset(centerX, lipBottom - 6),
      dividerPaint,
    );

    // Horizontal divider between top/bottom
    canvas.drawLine(
      Offset(lipLeft + 12, lipMidY + 2),
      Offset(lipRight - 12, lipMidY + 2),
      dividerPaint,
    );

    // Draw toothbrush on active quadrant
    _drawToothbrush(canvas, size);
  }

  void _drawTooth(Canvas canvas, Rect rect, Radius radius,
      ToothQuadrant quadrant, bool isTopRow) {
    final isActive = quadrant == activeQuadrant;
    final isCompleted = completedQuadrants.contains(quadrant);
    final isFuture = !isActive && !isCompleted;

    Color toothColor;
    double opacity;
    if (isActive) {
      final pulse = 0.7 + pulseValue * 0.3;
      toothColor = activeColor;
      opacity = pulse;
    } else if (isCompleted) {
      toothColor = const Color(0xFF69F0AE);
      opacity = 0.9;
    } else {
      toothColor = Colors.white;
      opacity = 0.2;
    }

    final paint = Paint()
      ..color = toothColor.withValues(alpha: opacity)
      ..style = PaintingStyle.fill;

    final rrect = RRect.fromRectAndRadius(rect, radius);
    canvas.drawRRect(rrect, paint);

    // Border
    final borderPaint = Paint()
      ..color = toothColor.withValues(alpha: isActive ? 0.9 : isFuture ? 0.1 : 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = isActive ? 1.5 : 0.5;
    canvas.drawRRect(rrect, borderPaint);

    // Glow for active
    if (isActive) {
      final glowPaint = Paint()
        ..color = activeColor.withValues(alpha: 0.3 * pulseValue)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawRRect(rrect, glowPaint);
    }

    // Sparkle for completed
    if (isCompleted) {
      final sparkleSize = 3.0;
      final cx = rect.center.dx;
      final cy = rect.center.dy;
      final sparklePaint = Paint()
        ..color = const Color(0xFF69F0AE).withValues(alpha: 0.8)
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(cx - sparkleSize, cy),
          Offset(cx + sparkleSize, cy), sparklePaint);
      canvas.drawLine(Offset(cx, cy - sparkleSize),
          Offset(cx, cy + sparkleSize), sparklePaint);
    }
  }

  void _drawToothbrush(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final centerX = w / 2;
    final lipMidY = h * 0.48;

    // Determine brush position based on active quadrant
    double bx, by;
    switch (activeQuadrant) {
      case ToothQuadrant.topLeft:
        bx = centerX * 0.5;
        by = h * 0.22;
        break;
      case ToothQuadrant.topRight:
        bx = centerX * 1.5;
        by = h * 0.22;
        break;
      case ToothQuadrant.bottomLeft:
        bx = centerX * 0.5;
        by = lipMidY + h * 0.22;
        break;
      case ToothQuadrant.bottomRight:
        bx = centerX * 1.5;
        by = lipMidY + h * 0.22;
        break;
    }

    // Brush back-and-forth animation
    final brushDx = (brushOffset - 0.5) * 8;
    bx += brushDx;

    // Draw brush handle
    final handlePaint = Paint()
      ..color = const Color(0xFF42A5F5)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(bx, by - 10), Offset(bx, by + 10), handlePaint);

    // Draw brush head
    final headPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(bx, by - 13), width: 10, height: 6),
        const Radius.circular(2),
      ),
      headPaint,
    );

    // Bristles
    final bristlePaint = Paint()
      ..color = activeColor.withValues(alpha: 0.8)
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;
    for (int i = -2; i <= 2; i++) {
      canvas.drawLine(
        Offset(bx + i * 2.0, by - 16),
        Offset(bx + i * 2.0, by - 19),
        bristlePaint,
      );
    }
  }

  @override
  bool shouldRepaint(_MouthPainter oldDelegate) => true;
}

import 'package:flutter/material.dart';

enum ToothQuadrant { topLeft, topRight, bottomLeft, bottomRight }

class ToothDiagram extends StatelessWidget {
  final ToothQuadrant activeQuadrant;
  final Set<ToothQuadrant> completedQuadrants;
  final double size;

  const ToothDiagram({
    super.key,
    required this.activeQuadrant,
    required this.completedQuadrants,
    this.size = 120,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size * 0.85,
      child: CustomPaint(
        painter: _ToothDiagramPainter(
          activeQuadrant: activeQuadrant,
          completedQuadrants: completedQuadrants,
        ),
      ),
    );
  }
}

class _ToothDiagramPainter extends CustomPainter {
  final ToothQuadrant activeQuadrant;
  final Set<ToothQuadrant> completedQuadrants;

  _ToothDiagramPainter({
    required this.activeQuadrant,
    required this.completedQuadrants,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final w = size.width;
    final h = size.height;

    // Draw the mouth outline - a U-shaped arch
    final mouthPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // Upper arch (upside-down U for top teeth)
    final topArch = Path();
    topArch.moveTo(w * 0.1, cy - 2);
    topArch.quadraticBezierTo(w * 0.1, h * 0.08, cx, h * 0.08);
    topArch.quadraticBezierTo(w * 0.9, h * 0.08, w * 0.9, cy - 2);
    canvas.drawPath(topArch, mouthPaint);

    // Lower arch (U for bottom teeth)
    final bottomArch = Path();
    bottomArch.moveTo(w * 0.1, cy + 2);
    bottomArch.quadraticBezierTo(w * 0.1, h * 0.92, cx, h * 0.92);
    bottomArch.quadraticBezierTo(w * 0.9, h * 0.92, w * 0.9, cy + 2);
    canvas.drawPath(bottomArch, mouthPaint);

    // Horizontal divider (gum line)
    final dividerPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.2)
      ..strokeWidth = 1.5;
    canvas.drawLine(
      Offset(w * 0.08, cy),
      Offset(w * 0.92, cy),
      dividerPaint,
    );

    // Vertical divider
    canvas.drawLine(
      Offset(cx, h * 0.06),
      Offset(cx, h * 0.94),
      dividerPaint,
    );

    // Draw teeth as small rounded rects in each quadrant
    _drawQuadrantTeeth(canvas, size, ToothQuadrant.topLeft);
    _drawQuadrantTeeth(canvas, size, ToothQuadrant.topRight);
    _drawQuadrantTeeth(canvas, size, ToothQuadrant.bottomLeft);
    _drawQuadrantTeeth(canvas, size, ToothQuadrant.bottomRight);
  }

  void _drawQuadrantTeeth(Canvas canvas, Size size, ToothQuadrant quadrant) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final isActive = quadrant == activeQuadrant;
    final isCompleted = completedQuadrants.contains(quadrant);
    Color toothColor;
    if (isActive) {
      toothColor = const Color(0xFF00E5FF);
    } else if (isCompleted) {
      toothColor = const Color(0xFF69F0AE);
    } else {
      toothColor = Colors.white.withValues(alpha: 0.2);
    }

    final paint = Paint()
      ..color = toothColor
      ..style = PaintingStyle.fill;

    final glowPaint = Paint()
      ..color = toothColor.withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    // Define tooth positions based on quadrant
    List<Rect> teeth = [];
    final tw = size.width * 0.08; // tooth width
    final th = size.height * 0.14; // tooth height

    switch (quadrant) {
      case ToothQuadrant.topLeft:
        // Top-left: 3 teeth along the left side of top arch
        for (int i = 0; i < 3; i++) {
          final t = (i + 1) / 4.0;
          // Interpolate along the arch
          final x = cx - (cx - size.width * 0.12) * t - tw / 2;
          final archY = _quadBezierY(
            size.height * 0.08,
            cy - 2,
            t,
            isTop: true,
            size: size,
            isLeft: true,
          );
          teeth.add(Rect.fromLTWH(x, archY + 4, tw, th));
        }
        break;
      case ToothQuadrant.topRight:
        for (int i = 0; i < 3; i++) {
          final t = (i + 1) / 4.0;
          final x = cx + (size.width * 0.88 - cx) * t - tw / 2;
          final archY = _quadBezierY(
            size.height * 0.08,
            cy - 2,
            t,
            isTop: true,
            size: size,
            isLeft: false,
          );
          teeth.add(Rect.fromLTWH(x, archY + 4, tw, th));
        }
        break;
      case ToothQuadrant.bottomLeft:
        for (int i = 0; i < 3; i++) {
          final t = (i + 1) / 4.0;
          final x = cx - (cx - size.width * 0.12) * t - tw / 2;
          final archY = _quadBezierY(
            size.height * 0.92,
            cy + 2,
            t,
            isTop: false,
            size: size,
            isLeft: true,
          );
          teeth.add(Rect.fromLTWH(x, archY - th - 4, tw, th));
        }
        break;
      case ToothQuadrant.bottomRight:
        for (int i = 0; i < 3; i++) {
          final t = (i + 1) / 4.0;
          final x = cx + (size.width * 0.88 - cx) * t - tw / 2;
          final archY = _quadBezierY(
            size.height * 0.92,
            cy + 2,
            t,
            isTop: false,
            size: size,
            isLeft: false,
          );
          teeth.add(Rect.fromLTWH(x, archY - th - 4, tw, th));
        }
        break;
    }

    for (final rect in teeth) {
      final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(4));
      if (isActive) {
        canvas.drawRRect(rrect, glowPaint);
      }
      canvas.drawRRect(rrect, paint);
    }

    // Draw checkmark for completed quadrants
    if (isCompleted) {
      final checkCenter = _getQuadrantCenter(size, quadrant);
      final checkPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;

      final checkSize = size.width * 0.08;
      final path = Path()
        ..moveTo(checkCenter.dx - checkSize, checkCenter.dy)
        ..lineTo(checkCenter.dx - checkSize * 0.3, checkCenter.dy + checkSize * 0.7)
        ..lineTo(checkCenter.dx + checkSize, checkCenter.dy - checkSize * 0.5);
      canvas.drawPath(path, checkPaint);
    }
  }

  Offset _getQuadrantCenter(Size size, ToothQuadrant quadrant) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    switch (quadrant) {
      case ToothQuadrant.topLeft:
        return Offset(cx * 0.5, cy * 0.5);
      case ToothQuadrant.topRight:
        return Offset(cx * 1.5, cy * 0.5);
      case ToothQuadrant.bottomLeft:
        return Offset(cx * 0.5, cy * 1.5);
      case ToothQuadrant.bottomRight:
        return Offset(cx * 1.5, cy * 1.5);
    }
  }

  double _quadBezierY(double endY, double startY, double t,
      {required bool isTop, required Size size, required bool isLeft}) {
    // Simple interpolation along the arch curve
    final peakY = isTop ? size.height * 0.08 : size.height * 0.92;
    final edgeY = isTop ? size.height * 0.42 : size.height * 0.58;
    // Quadratic bezier: y = (1-t)^2*start + 2*(1-t)*t*peak + t^2*end
    final tt = 1.0 - t;
    return tt * tt * edgeY + 2 * tt * t * peakY + t * t * edgeY;
  }

  @override
  bool shouldRepaint(covariant _ToothDiagramPainter old) =>
      old.activeQuadrant != activeQuadrant ||
      old.completedQuadrants != completedQuadrants;
}

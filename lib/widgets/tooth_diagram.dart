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
    this.size = 160,
  });

  @override
  Widget build(BuildContext context) {
    final cellSize = size / 2 - 4;
    return SizedBox(
      width: size,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // "TOP" label
          Text(
            'TOP',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 9,
              fontWeight: FontWeight.bold,
              letterSpacing: 3,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _QuadCell(
                quadrant: ToothQuadrant.topLeft,
                label: 'L',
                isActive: activeQuadrant == ToothQuadrant.topLeft,
                isCompleted: completedQuadrants.contains(ToothQuadrant.topLeft),
                size: cellSize,
                borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(14)),
              ),
              const SizedBox(width: 4),
              _QuadCell(
                quadrant: ToothQuadrant.topRight,
                label: 'R',
                isActive: activeQuadrant == ToothQuadrant.topRight,
                isCompleted:
                    completedQuadrants.contains(ToothQuadrant.topRight),
                size: cellSize,
                borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(14)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _QuadCell(
                quadrant: ToothQuadrant.bottomLeft,
                label: 'L',
                isActive: activeQuadrant == ToothQuadrant.bottomLeft,
                isCompleted:
                    completedQuadrants.contains(ToothQuadrant.bottomLeft),
                size: cellSize,
                borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(14)),
              ),
              const SizedBox(width: 4),
              _QuadCell(
                quadrant: ToothQuadrant.bottomRight,
                label: 'R',
                isActive: activeQuadrant == ToothQuadrant.bottomRight,
                isCompleted:
                    completedQuadrants.contains(ToothQuadrant.bottomRight),
                size: cellSize,
                borderRadius: const BorderRadius.only(
                    bottomRight: Radius.circular(14)),
              ),
            ],
          ),
          const SizedBox(height: 2),
          // "BOTTOM" label
          Text(
            'BOTTOM',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 9,
              fontWeight: FontWeight.bold,
              letterSpacing: 3,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuadCell extends StatelessWidget {
  final ToothQuadrant quadrant;
  final String label;
  final bool isActive;
  final bool isCompleted;
  final double size;
  final BorderRadius borderRadius;

  const _QuadCell({
    required this.quadrant,
    required this.label,
    required this.isActive,
    required this.isCompleted,
    required this.size,
    required this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive
        ? const Color(0xFF00E5FF)
        : isCompleted
            ? const Color(0xFF69F0AE)
            : Colors.white.withValues(alpha: 0.1);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: size,
      height: size * 0.55,
      decoration: BoxDecoration(
        color: isActive
            ? color.withValues(alpha: 0.3)
            : isCompleted
                ? color.withValues(alpha: 0.25)
                : color,
        borderRadius: borderRadius,
        border: isActive
            ? Border.all(color: const Color(0xFF00E5FF), width: 2)
            : Border.all(
                color: Colors.white.withValues(alpha: 0.1), width: 1),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: const Color(0xFF00E5FF).withValues(alpha: 0.4),
                  blurRadius: 10,
                ),
              ]
            : null,
      ),
      child: Center(
        child: isCompleted
            ? const Icon(Icons.check_rounded, color: Colors.white, size: 20)
            : isActive
                ? const Icon(Icons.brush, color: Colors.white, size: 18)
                : null,
      ),
    );
  }
}

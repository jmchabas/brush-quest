// lib/widgets/item_silhouette.dart
import 'package:flutter/material.dart';

/// A dark silhouette of [child] (keeps its shape, paints it black) for a
/// locked "next goal" item.
class ItemSilhouette extends StatelessWidget {
  final Widget child;
  final double opacity;

  const ItemSilhouette({super.key, required this.child, this.opacity = 0.85});

  @override
  Widget build(BuildContext context) {
    return ColorFiltered(
      colorFilter: ColorFilter.mode(
        Colors.black.withValues(alpha: opacity),
        BlendMode.srcATop,
      ),
      child: child,
    );
  }
}

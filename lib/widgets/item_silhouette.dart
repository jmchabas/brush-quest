// lib/widgets/item_silhouette.dart
import 'package:flutter/material.dart';

/// A dark silhouette of [child] for a locked "next goal" item.
///
/// By default it keeps the child's own shape and paints it black, which suits
/// art with a transparent background (the heroes).
///
/// Weapon and planet art is an opaque square on a near-black space
/// background, so a black pass would paint a hard-edged black box. For that
/// art pass [opaqueArt]: the child is dimmed to a grey at a quarter of its
/// brightness instead, so the near-black background melts into the app's dark
/// background and the item stays visible as a dim shape, and a small lock
/// sits in the bottom-right corner. Still a single filter layer. [opacity]
/// only applies to the black silhouette.
class ItemSilhouette extends StatelessWidget {
  final Widget child;
  final double opacity;
  final bool opaqueArt;

  const ItemSilhouette({
    super.key,
    required this.child,
    this.opacity = 0.85,
    this.opaqueArt = false,
  });

  // Grey = 0.25 x Rec. 709 luminance (0.2126 R + 0.7152 G + 0.0722 B),
  // written to R, G and B alike; alpha is left alone.
  static const _dimRed = 0.2126 * 0.25;
  static const _dimGreen = 0.7152 * 0.25;
  static const _dimBlue = 0.0722 * 0.25;
  static const _dimGrey = ColorFilter.matrix(<double>[
    _dimRed, _dimGreen, _dimBlue, 0, 0, //
    _dimRed, _dimGreen, _dimBlue, 0, 0, //
    _dimRed, _dimGreen, _dimBlue, 0, 0, //
    0, 0, 0, 1, 0, //
  ]);

  /// The lock's size as a share of the item's shorter side.
  static const _lockShare = 0.24;

  @override
  Widget build(BuildContext context) {
    if (!opaqueArt) {
      return ColorFiltered(
        colorFilter: ColorFilter.mode(
          Colors.black.withValues(alpha: opacity),
          BlendMode.srcATop,
        ),
        child: child,
      );
    }
    return Stack(
      children: [
        ColorFiltered(colorFilter: _dimGrey, child: child),
        Positioned.fill(
          child: LayoutBuilder(
            builder: (context, box) => Align(
              alignment: Alignment.bottomRight,
              child: Icon(
                Icons.lock,
                color: Colors.white54,
                size: box.biggest.shortestSide * _lockShare,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

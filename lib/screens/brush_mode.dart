// lib/screens/brush_mode.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/goal_service.dart';

/// What the Heroes & Weapons page and the Map need to run as a step of the
/// brush flow (spec
/// docs/superpowers/specs/2026-10-13-brush-steps-on-real-pages-design.md
/// §5, and 2026-10-15-sticker-card-design.md §3). A page built without one
/// behaves exactly as when it is opened from Home. A page keeps the same
/// instance for its whole life.
@immutable
class BrushMode {
  const BrushMode({
    required this.onClose,
    required this.tab,
    required this.onTabChanged,
    required this.highlightId,
    required this.reveal,
    required this.onChanged,
    required this.header,
  });

  /// The X: back to Home.
  final VoidCallback onClose;

  /// The Heroes & Weapons tab to show (0 heroes, 1 weapons). The page
  /// follows it; the Map ignores it.
  final ValueListenable<int> tab;

  /// He tapped or swiped to the other tab.
  final ValueChanged<int> onTabChanged;

  /// What glows as the closest next unlock: an evolution-cell id
  /// ('frost_stage1', 'blaze_stage2'), a weapon id or a planet id; null for
  /// nothing.
  final ValueListenable<String?> highlightId;

  /// Scroll the glowing item into view if it is not fully on screen.
  final Listenable reveal;

  /// After a selection or an unlock on the page.
  final ValueChanged<BrushChange> onChanged;

  /// The steps' HEROES · WEAPONS · WORLD header. The page shows it under its
  /// title row: the Heroes & Weapons page in place of its own tab bar, the
  /// Map in the same place.
  final Widget header;
}

/// What a page did during the brush steps: equipped something he owns, or
/// bought something. Reported through [BrushMode.onChanged].
@immutable
class BrushChange {
  const BrushChange.selected(this.category) : unlockedId = null;

  const BrushChange.unlocked(this.category, String this.unlockedId);

  final GoalCategory category;

  /// The hero, evolution or weapon id just bought; null for a selection.
  final String? unlockedId;

  @override
  bool operator ==(Object other) =>
      other is BrushChange &&
      other.category == category &&
      other.unlockedId == unlockedId;

  @override
  int get hashCode => Object.hash(category, unlockedId);

  @override
  String toString() => unlockedId == null
      ? 'BrushChange.selected(${category.name})'
      : 'BrushChange.unlocked(${category.name}, $unlockedId)';
}

/// Tells its listeners once per [ping].
class BrushPing extends ChangeNotifier {
  void ping() => notifyListeners();
}

/// Extra bottom padding on a page in brush mode: the floating GO button,
/// its margin and a little air, so the last row, card or planet can scroll
/// above GO.
const double kBrushGoClearance = 112;

/// Scrolls the item at [context] to 35% down its scroll view when any part
/// of it lies outside the visible area, which ends [bottomInset] above the
/// scroll view's bottom (where GO floats). Only the nearest scroll view
/// moves, never the tab pages around it.
Future<void> revealIfHidden(
  BuildContext context, {
  double bottomInset = kBrushGoClearance,
}) async {
  final item = context.findRenderObject();
  final scrollable = Scrollable.maybeOf(context);
  if (item is! RenderBox || !item.attached || !item.hasSize) return;
  if (scrollable == null) return;
  final view = scrollable.context.findRenderObject();
  if (view is! RenderBox || !view.attached || !view.hasSize) return;
  final top = item.localToGlobal(Offset.zero, ancestor: view).dy;
  final bottom = top + item.size.height;
  if (top >= 0 && bottom <= view.size.height - bottomInset) return;
  await scrollable.position.ensureVisible(
    item,
    alignment: 0.35,
    duration: const Duration(milliseconds: 400),
    curve: Curves.easeInOut,
  );
}

/// The X on a page in brush mode: the Map's 56 × 56 back button, with a
/// close icon.
class BrushCloseButton extends StatelessWidget {
  const BrushCloseButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: const ValueKey('brush_close'),
        onTap: onTap,
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
          child: const Icon(Icons.close, color: Colors.white, size: 30),
        ),
      ),
    );
  }
}

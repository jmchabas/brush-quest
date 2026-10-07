// lib/widgets/loadout_carousel.dart
import 'package:flutter/material.dart';

class LoadoutItem {
  final String id;
  final Widget image;
  const LoadoutItem({required this.id, required this.image});
}

/// Owned items in a swipe row: the choice is centred and big, neighbours
/// peek in from the sides, ‹ › arrows for kids who don't swipe (spec §4.1).
///
/// Uncontrolled: [items] and [selectedId] are read once, when it is first
/// built, and the carousel keeps its own position after that. To show other
/// items, give it a new key (the pre-brush screen keys one per step).
class LoadoutCarousel extends StatefulWidget {
  final List<LoadoutItem> items;
  final String selectedId;
  final ValueChanged<String> onSelected;

  /// Any touch — pauses the step's auto-advance.
  final VoidCallback onInteraction;

  const LoadoutCarousel({
    super.key,
    required this.items,
    required this.selectedId,
    required this.onSelected,
    required this.onInteraction,
  });

  @override
  State<LoadoutCarousel> createState() => _LoadoutCarouselState();
}

class _LoadoutCarouselState extends State<LoadoutCarousel> {
  late PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = _indexOf(widget.selectedId);
    _controller = PageController(viewportFraction: 0.6, initialPage: _index);
  }

  int _indexOf(String id) {
    final i = widget.items.indexWhere((item) => item.id == id);
    return i < 0 ? 0 : i;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _go(int delta) {
    widget.onInteraction();
    final next = (_index + delta).clamp(0, widget.items.length - 1);
    if (next == _index) return;
    _controller.animateToPage(
      next,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final many = widget.items.length > 1;
    return Listener(
      onPointerDown: (_) => widget.onInteraction(),
      child: Row(
        children: [
          if (many)
            IconButton(
              key: const ValueKey('carousel_prev'),
              iconSize: 48,
              color: Colors.white70,
              icon: const Icon(Icons.chevron_left),
              onPressed: _index > 0 ? () => _go(-1) : null,
            ),
          Expanded(
            child: PageView.builder(
              controller: _controller,
              itemCount: widget.items.length,
              onPageChanged: (i) {
                setState(() => _index = i);
                widget.onSelected(widget.items[i].id);
              },
              itemBuilder: (context, i) => AnimatedScale(
                scale: i == _index ? 1.0 : 0.7,
                duration: const Duration(milliseconds: 200),
                child: AnimatedOpacity(
                  opacity: i == _index ? 1.0 : 0.5,
                  duration: const Duration(milliseconds: 200),
                  child: widget.items[i].image,
                ),
              ),
            ),
          ),
          if (many)
            IconButton(
              key: const ValueKey('carousel_next'),
              iconSize: 48,
              color: Colors.white70,
              icon: const Icon(Icons.chevron_right),
              onPressed: _index < widget.items.length - 1 ? () => _go(1) : null,
            ),
        ],
      ),
    );
  }
}

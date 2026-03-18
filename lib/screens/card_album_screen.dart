import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/card_service.dart';
import '../services/world_service.dart';
import '../services/audio_service.dart';
import '../widgets/space_background.dart';

class CardAlbumScreen extends StatefulWidget {
  const CardAlbumScreen({super.key});

  @override
  State<CardAlbumScreen> createState() => _CardAlbumScreenState();
}

class _CardAlbumScreenState extends State<CardAlbumScreen> {
  final _cardService = CardService();
  final _worldService = WorldService();

  List<String> _collectedIds = [];
  List<String> _unlockedWorldIds = [];
  Map<String, int> _duplicateCounts = {};
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _loadData();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final collected = await _cardService.getCollectedCardIds();
    final worldId = await _worldService.getCurrentWorldId();
    final dupCounts = await _cardService.getAllDuplicateCounts();

    final unlocked = <String>[];
    for (final world in WorldService.allWorlds) {
      if (await _worldService.isWorldUnlocked(world.id)) {
        unlocked.add(world.id);
      }
    }

    if (mounted) {
      setState(() {
        _collectedIds = collected;
        _unlockedWorldIds = unlocked;
        _duplicateCounts = dupCounts;
      });
      // Set initial page to current world
      final idx = unlocked.indexOf(worldId);
      if (idx > 0) {
        _pageController.jumpToPage(idx);
        _currentPage = idx;
      }
      _maybePlayTutorial();
    }
  }

  Future<void> _maybePlayTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    final visitCount = prefs.getInt('card_album_visit_count') ?? 0;
    await prefs.setInt('card_album_visit_count', visitCount + 1);

    // Track last visit date for staleness check
    final now = DateTime.now();
    final lastVisitStr = prefs.getString('last_card_album_visit');
    await prefs.setString('last_card_album_visit', now.toIso8601String());

    // Play intro voice only if:
    // 1. First 4 visits (visitCount is 0-based before increment, so 0-3), OR
    // 2. Haven't visited in more than 7 days
    bool shouldPlay = visitCount < 4;
    if (!shouldPlay && lastVisitStr != null) {
      final lastVisit = DateTime.tryParse(lastVisitStr);
      if (lastVisit != null &&
          now.difference(lastVisit).inDays > 7) {
        shouldPlay = true;
      }
    }
    // Also play on very first visit when lastVisitStr is null (covered by visitCount < 4)

    if (!shouldPlay) return;

    await Future.delayed(const Duration(milliseconds: 400));
    if (mounted) {
      AudioService().playVoice('voice_card_album_intro.mp3',
          clearQueue: true, interrupt: true);
    }
  }

  void _showCardDetail(MonsterCard card) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => _CardDetailDialog(card: card),
    );
    AudioService().playVoice('voice_card_${card.id}.mp3',
        clearQueue: true, interrupt: true);
  }

  @override
  Widget build(BuildContext context) {
    final unlockedWorlds = WorldService.allWorlds
        .where((w) => _unlockedWorldIds.contains(w.id))
        .toList();

    return Scaffold(
      body: SpaceBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Header with back button
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back,
                          color: Colors.white, size: 28),
                    ),
                  ],
                ),
              ),

              // World pages
              Expanded(
                child: unlockedWorlds.isEmpty
                    ? const SizedBox.shrink()
                    : PageView.builder(
                        controller: _pageController,
                        itemCount: unlockedWorlds.length,
                        onPageChanged: (page) =>
                            setState(() => _currentPage = page),
                        itemBuilder: (context, index) {
                          final world = unlockedWorlds[index];
                          return _buildWorldPage(world);
                        },
                      ),
              ),

              // Page dots + arrows — large touch targets for kids
              if (unlockedWorlds.length > 1)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Left arrow with 48px minimum touch target
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _currentPage > 0
                            ? () => _pageController.previousPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut)
                            : null,
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Icon(
                            Icons.chevron_left,
                            color: _currentPage > 0
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.2),
                            size: 36,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      // Dots
                      for (int i = 0; i < unlockedWorlds.length; i++)
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: i == _currentPage ? 10 : 8,
                          height: i == _currentPage ? 10 : 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: i == _currentPage
                                ? unlockedWorlds[i].themeColor
                                : Colors.white.withValues(alpha: 0.3),
                          ),
                        ),
                      const SizedBox(width: 4),
                      // Right arrow with 48px minimum touch target
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _currentPage < unlockedWorlds.length - 1
                            ? () => _pageController.nextPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut)
                            : null,
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Icon(
                            Icons.chevron_right,
                            color: _currentPage < unlockedWorlds.length - 1
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.2),
                            size: 36,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWorldPage(WorldData world) {
    final worldCards = CardService.cardsForWorld(world.id);
    final visibleCards =
        CardService.visibleCardsForWorld(world.id, _collectedIds);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          const SizedBox(height: 12),
          // Large planet image
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: world.themeColor.withValues(alpha: 0.4),
                  blurRadius: 20,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: ClipOval(
              child: Image.asset(world.imagePath,
                  width: 80, height: 80, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(height: 10),
          // World name
          Text(
            world.name.toUpperCase(),
            style: TextStyle(
              color: world.themeColor,
              fontWeight: FontWeight.bold,
              fontSize: 20,
              letterSpacing: 3,
            ),
          ),
          const SizedBox(height: 10),
          // 7-dot progress indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(worldCards.length, (i) {
              final card = worldCards[i];
              final collected = _collectedIds.contains(card.id);
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: collected
                      ? card.rarityColor
                      : Colors.white.withValues(alpha: 0.15),
                  border: Border.all(
                    color: collected
                        ? card.rarityColor
                        : Colors.white.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                  boxShadow: collected
                      ? [
                          BoxShadow(
                            color: card.rarityColor.withValues(alpha: 0.5),
                            blurRadius: 6,
                          ),
                        ]
                      : null,
                ),
              );
            }),
          ),
          const SizedBox(height: 16),
          // Card grid — 2 columns for kid-friendly touch targets
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: visibleCards.map((card) {
              final isCollected = _collectedIds.contains(card.id);
              return SizedBox(
                width: (MediaQuery.of(context).size.width - 40 - 14) / 2,
                child: AspectRatio(
                  aspectRatio: 0.75,
                  child: _buildCardTile(card, isCollected),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildCardTile(MonsterCard card, bool isCollected) {
    return GestureDetector(
      onTap: isCollected
          ? () {
              HapticFeedback.lightImpact();
              _showCardDetail(card);
            }
          : () {
              HapticFeedback.lightImpact();
              AudioService().playVoice('voice_card_mystery.mp3',
                  clearQueue: true, interrupt: true);
            },
      child: Container(
        decoration: BoxDecoration(
          color: isCollected
              ? Colors.black.withValues(alpha: 0.4)
              : Colors.black.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isCollected
                ? card.rarityColor.withValues(alpha: 0.7)
                : Colors.white.withValues(alpha: 0.08),
            width: isCollected ? 2 : 1,
          ),
          boxShadow: isCollected
              ? [
                  BoxShadow(
                    color: card.rarityColor.withValues(alpha: 0.3),
                    blurRadius: 8,
                  ),
                ]
              : null,
        ),
        child: Stack(
          children: [
            // Monster image
            Center(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: isCollected
                    ? ShaderMask(
                        shaderCallback: (bounds) => RadialGradient(
                          colors: [
                            Colors.white,
                            Colors.white.withValues(alpha: 0.0),
                          ],
                          radius: 0.75,
                        ).createShader(bounds),
                        child: ColorFiltered(
                          colorFilter: ColorFilter.mode(
                            card.tintColor.withValues(alpha: 0.35),
                            BlendMode.srcATop,
                          ),
                          child:
                              Image.asset(card.imagePath, fit: BoxFit.contain),
                        ),
                      )
                    : // Uncollected: solid black silhouette with "?" overlay
                    Stack(
                        alignment: Alignment.center,
                        children: [
                          ColorFiltered(
                            colorFilter: const ColorFilter.mode(
                              Colors.black,
                              BlendMode.srcIn,
                            ),
                            child: Image.asset(card.imagePath,
                                fit: BoxFit.contain),
                          ),
                          Text(
                            '?',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            // Rarity dot at bottom center
            Positioned(
              bottom: 6,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isCollected
                        ? card.rarityColor
                        : card.rarityColor.withValues(alpha: 0.25),
                  ),
                ),
              ),
            ),
            // Duplicate count badge (top-left)
            if (isCollected && (_duplicateCounts[card.id] ?? 0) > 0)
              Positioned(
                top: 4,
                left: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD54F),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFFD54F).withValues(alpha: 0.5),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: Text(
                    'x${_duplicateCounts[card.id]! + 1}',
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w900,
                      fontSize: 10,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CardDetailDialog extends StatefulWidget {
  final MonsterCard card;

  const _CardDetailDialog({required this.card});

  @override
  State<_CardDetailDialog> createState() => _CardDetailDialogState();
}

class _CardDetailDialogState extends State<_CardDetailDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.card;
    final world = WorldService.getWorldById(card.worldId);

    return Dialog(
      backgroundColor: Colors.transparent,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 300),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                card.rarityColor.withValues(alpha: 0.2),
                Colors.black.withValues(alpha: 0.9),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: card.rarityColor.withValues(alpha: 0.6),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: card.rarityColor.withValues(alpha: 0.4),
                blurRadius: 20,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 20),
              // Monster image
              SizedBox(
                width: 120,
                height: 120,
                child: ShaderMask(
                  shaderCallback: (bounds) => RadialGradient(
                    colors: [
                      Colors.white,
                      Colors.white.withValues(alpha: 0.0),
                    ],
                    radius: 0.75,
                  ).createShader(bounds),
                  child: ColorFiltered(
                    colorFilter: ColorFilter.mode(
                      card.tintColor.withValues(alpha: 0.35),
                      BlendMode.srcATop,
                    ),
                    child: Image.asset(card.imagePath, fit: BoxFit.contain),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Rarity badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: card.rarityColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: card.rarityColor.withValues(alpha: 0.5),
                  ),
                ),
                child: Text(
                  card.rarityLabel,
                  style: TextStyle(
                    color: card.rarityColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    letterSpacing: 2,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // Name & title
              Text(
                card.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                  letterSpacing: 2,
                ),
              ),
              Text(
                card.title,
                style: TextStyle(
                  color: card.tintColor,
                  fontSize: 14,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 12),
              // Flavor text
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  '"${card.flavorText}"',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // World info
              Text(
                world.name.toUpperCase(),
                style: TextStyle(
                  color: world.themeColor.withValues(alpha: 0.7),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

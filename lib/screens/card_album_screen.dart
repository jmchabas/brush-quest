import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/card_service.dart';
import '../services/world_service.dart';
import '../services/audio_service.dart';
import '../widgets/space_background.dart';
import '../widgets/glass_card.dart';

class CardAlbumScreen extends StatefulWidget {
  const CardAlbumScreen({super.key});

  @override
  State<CardAlbumScreen> createState() => _CardAlbumScreenState();
}

class _CardAlbumScreenState extends State<CardAlbumScreen> {
  final _cardService = CardService();
  final _worldService = WorldService();

  List<String> _collectedIds = [];
  int _fragments = 0;
  String _currentWorldId = 'candy_crater';
  List<String> _unlockedWorldIds = [];

  @override
  void initState() {
    super.initState();
    _loadData();
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) {
        AudioService().playVoice('voice_entry_card_album.mp3', clearQueue: true, interrupt: true);
      }
    });
  }

  Future<void> _loadData() async {
    final collected = await _cardService.getCollectedCardIds();
    final fragments = await _cardService.getFragments();
    final worldId = await _worldService.getCurrentWorldId();

    // Determine which worlds are unlocked
    final unlocked = <String>[];
    for (final world in WorldService.allWorlds) {
      if (await _worldService.isWorldUnlocked(world.id)) {
        unlocked.add(world.id);
      }
    }

    if (mounted) {
      final wasBelow = _fragments < 3;
      setState(() {
        _collectedIds = collected;
        _fragments = fragments;
        _currentWorldId = worldId;
        _unlockedWorldIds = unlocked;
      });
      // Play fragments ready voice when we first detect >= 3 fragments
      if (fragments >= 3 && wasBelow) {
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            AudioService().playVoice('voice_fragments_ready.mp3');
          }
        });
      }
      // Fragment tutorial voice on first view with fragments > 0
      _maybePlayFragmentTutorial(fragments);
    }
  }

  Future<void> _maybePlayFragmentTutorial(int fragments) async {
    if (fragments <= 0) return;
    final prefs = await SharedPreferences.getInstance();
    final shown = prefs.getBool('fragment_tutorial_shown') ?? false;
    if (shown) return;
    await prefs.setBool('fragment_tutorial_shown', true);
    // Delay to let entry voice finish
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        AudioService().playVoice('voice_fragment_explain.mp3');
      }
    });
  }

  Future<void> _redeemFragments() async {
    if (_fragments < 3) return;
    final card = await _cardService.redeemFragments(_currentWorldId);
    if (card != null && mounted) {
      HapticFeedback.heavyImpact();
      AudioService().playSfx('star_chime.mp3');
      _showCardDetail(card, isNewReveal: true);
      await _loadData();
    }
  }

  void _showCardDetail(MonsterCard card, {bool isNewReveal = false}) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => _CardDetailDialog(
        card: card,
        isNew: isNewReveal,
      ),
    );
    AudioService().playVoice('voice_card_${card.id}.mp3', clearQueue: true, interrupt: true);
  }

  @override
  Widget build(BuildContext context) {
    final totalCollected = _collectedIds.length;
    final totalCards = CardService.allCards.length;

    // Filter to only unlocked worlds
    final unlockedWorlds = WorldService.allWorlds
        .where((w) => _unlockedWorldIds.contains(w.id))
        .toList();

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
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: const Icon(
                        Icons.arrow_back,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'MONSTER CARDS',
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 26,
                              letterSpacing: 3,
                            ),
                      ),
                    ),
                  ],
                ),
              ),

              // Progress bar + fragments
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: GlassCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      // Collection progress
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.style, color: Colors.white70, size: 16),
                                const SizedBox(width: 6),
                                Text(
                                  '$totalCollected / $totalCards',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: totalCards > 0
                                    ? totalCollected / totalCards
                                    : 0,
                                backgroundColor:
                                    Colors.white.withValues(alpha: 0.15),
                                valueColor: const AlwaysStoppedAnimation(
                                  Color(0xFF69F0AE),
                                ),
                                minHeight: 8,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Fragment display with puzzle pieces
                      GestureDetector(
                        onTap: _fragments >= 3 ? _redeemFragments : null,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: _fragments >= 3
                                ? const Color(0xFFFFD54F).withValues(alpha: 0.3)
                                : Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _fragments >= 3
                                  ? const Color(0xFFFFD54F)
                                      .withValues(alpha: 0.6)
                                  : Colors.white.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (int i = 0; i < 3; i++)
                                Padding(
                                  padding: const EdgeInsets.only(right: 2),
                                  child: Icon(
                                    i < _fragments
                                        ? Icons.extension
                                        : Icons.extension_outlined,
                                    color: i < _fragments
                                        ? const Color(0xFFFFD54F)
                                        : Colors.white24,
                                    size: 16,
                                  ),
                                ),
                              const SizedBox(width: 4),
                              Text(
                                '$_fragments/3',
                                style: TextStyle(
                                  color: _fragments >= 3
                                      ? const Color(0xFFFFD54F)
                                      : Colors.white54,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // Scrollable list of worlds with cards
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: unlockedWorlds.length,
                  itemBuilder: (context, index) {
                    final world = unlockedWorlds[index];
                    return _buildWorldSection(world);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWorldSection(WorldData world) {
    final visibleCards = CardService.visibleCardsForWorld(world.id, _collectedIds);
    final worldCards = CardService.cardsForWorld(world.id);
    final collectedCount = worldCards.where((c) => _collectedIds.contains(c.id)).length;
    final totalCount = worldCards.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // World header
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              ClipOval(
                child: Image.asset(
                  world.imagePath,
                  width: 28,
                  height: 28,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  world.name.toUpperCase(),
                  style: TextStyle(
                    color: world.themeColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    letterSpacing: 2,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: world.themeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: world.themeColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  '$collectedCount/$totalCount',
                  style: TextStyle(
                    color: world.themeColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
        // Cards grid
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: visibleCards.map((card) {
            final isCollected = _collectedIds.contains(card.id);
            return SizedBox(
              width: (MediaQuery.of(context).size.width - 32 - 24) / 3,
              child: AspectRatio(
                aspectRatio: 0.7,
                child: _buildCardTile(card, isCollected),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
      ],
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
              AudioService().playVoice('voice_card_mystery.mp3', clearQueue: true, interrupt: true);
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
                : Colors.white.withValues(alpha: 0.1),
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Monster image or silhouette
            SizedBox(
              width: 64,
              height: 64,
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
                        child: Image.asset(card.imagePath, fit: BoxFit.contain),
                      ),
                    )
                  : ShaderMask(
                      shaderCallback: (bounds) => RadialGradient(
                        colors: [
                          Colors.white,
                          Colors.white.withValues(alpha: 0.0),
                        ],
                        radius: 0.75,
                      ).createShader(bounds),
                      child: ColorFiltered(
                        colorFilter: const ColorFilter.mode(
                          Colors.black54,
                          BlendMode.srcATop,
                        ),
                        child: Image.asset(card.imagePath, fit: BoxFit.contain),
                      ),
                    ),
            ),
            const SizedBox(height: 6),
            // Name or "???"
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                isCollected ? card.name : '???',
                style: TextStyle(
                  color: isCollected ? Colors.white : Colors.white24,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                  letterSpacing: 0.5,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isCollected) ...[
              const SizedBox(height: 2),
              Text(
                card.rarityLabel,
                style: TextStyle(
                  color: card.rarityColor,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CardDetailDialog extends StatefulWidget {
  final MonsterCard card;
  final bool isNew;

  const _CardDetailDialog({required this.card, this.isNew = false});

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
              if (widget.isNew)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: card.rarityColor.withValues(alpha: 0.3),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(18),
                      topRight: Radius.circular(18),
                    ),
                  ),
                  child: Text(
                    'NEW CARD!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: card.rarityColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      letterSpacing: 3,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class _CardAlbumScreenState extends State<CardAlbumScreen>
    with SingleTickerProviderStateMixin {
  final _cardService = CardService();
  final _worldService = WorldService();

  List<String> _collectedIds = [];
  int _fragments = 0;
  String _currentWorldId = 'candy_crater';
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 10, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final collected = await _cardService.getCollectedCardIds();
    final fragments = await _cardService.getFragments();
    final worldId = await _worldService.getCurrentWorldId();
    if (mounted) {
      setState(() {
        _collectedIds = collected;
        _fragments = fragments;
        _currentWorldId = worldId;
      });
    }
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
                            Text(
                              '$totalCollected / $totalCards COLLECTED',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                letterSpacing: 1.5,
                              ),
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
                      // Fragment redeem button
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
                              const Icon(
                                Icons.auto_awesome_mosaic,
                                color: Color(0xFFFFD54F),
                                size: 18,
                              ),
                              const SizedBox(width: 6),
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

              // World tabs
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  indicator: BoxDecoration(
                    color: const Color(0xFF7C4DFF).withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white54,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    letterSpacing: 1,
                  ),
                  tabAlignment: TabAlignment.start,
                  tabs: WorldService.allWorlds.map((world) {
                    final worldCards = CardService.cardsForWorld(world.id);
                    final collected = worldCards
                        .where((c) => _collectedIds.contains(c.id))
                        .length;
                    return Tab(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text('${world.name.toUpperCase()} $collected/7'),
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 8),

              // Card grid
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: WorldService.allWorlds.map((world) {
                    return _buildWorldCards(world);
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWorldCards(WorldData world) {
    final cards = CardService.cardsForWorld(world.id);
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.7,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: cards.length,
      itemBuilder: (context, index) {
        final card = cards[index];
        final isCollected = _collectedIds.contains(card.id);
        return _buildCardTile(card, isCollected);
      },
    );
  }

  Widget _buildCardTile(MonsterCard card, bool isCollected) {
    return GestureDetector(
      onTap: isCollected
          ? () {
              HapticFeedback.lightImpact();
              _showCardDetail(card);
            }
          : null,
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

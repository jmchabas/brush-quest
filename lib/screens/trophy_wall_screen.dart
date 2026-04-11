import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/trophy_service.dart';
import '../services/world_service.dart';
import '../services/audio_service.dart';
import '../widgets/space_background.dart';
import '../widgets/trophy_detail_dialog.dart';


class TrophyWallScreen extends StatefulWidget {
  const TrophyWallScreen({super.key});

  @override
  State<TrophyWallScreen> createState() => _TrophyWallScreenState();
}

class _TrophyWallScreenState extends State<TrophyWallScreen>
    with TickerProviderStateMixin {
  final _trophyService = TrophyService();
  final _worldService = WorldService();

  List<String> _capturedIds = [];
  Map<String, int> _defeatCounts = {};
  String _selectedWorldId = 'candy_crater';
  int _totalCaptured = 0;
  Map<String, bool> _worldUnlocked = {};
  bool _loading = true;

  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    )..repeat(reverse: true);
    _glowAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
    _loadData();
  }

  @override
  void dispose() {
    AudioService().stopVoice();
    AudioService().stopMusic();
    _glowController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final captured = await _trophyService.getCapturedIds();
    final currentWorld = await _worldService.getCurrentWorldId();

    // Check which trophy worlds are unlocked
    final unlocked = <String, bool>{};
    for (final wId in TrophyService.worldIds) {
      unlocked[wId] = await _worldService.isWorldUnlocked(wId);
    }

    // Default to current world if it has trophies, else first world
    final initialWorld = TrophyService.worldIds.contains(currentWorld)
        ? currentWorld
        : 'candy_crater';

    if (mounted) {
      setState(() {
        _capturedIds = captured;
        _totalCaptured = captured.length;
        _worldUnlocked = unlocked;
        _selectedWorldId = initialWorld;
      });
    }

    await _loadWorldDefeats(initialWorld);

    if (mounted) {
      setState(() => _loading = false);
      // Ambient music — low volume so voice lines stay clear
      unawaited(AudioService().playMusic('battle_music_loop.mp3'));
      unawaited(AudioService().setMusicVolume(0.04));
      // Play entry voice explaining the monster collection
      unawaited(AudioService().playVoice(
        'voice_card_album_intro.mp3',
        clearQueue: true,
        interrupt: true,
      ));
    }
  }

  Future<void> _loadWorldDefeats(String worldId) async {
    final worldTrophies = TrophyService.trophiesForWorld(worldId);
    final defeats = <String, int>{};
    for (final t in worldTrophies) {
      defeats[t.id] = await _trophyService.getDefeatCount(t.id);
    }
    if (mounted) {
      setState(() {
        _defeatCounts = defeats;
      });
    }
  }

  Future<void> _selectWorld(String worldId) async {
    if (worldId == _selectedWorldId) return;
    unawaited(HapticFeedback.selectionClick());
    unawaited(AudioService().playSfx('whoosh.mp3'));
    setState(() => _selectedWorldId = worldId);
    await _loadWorldDefeats(worldId);
  }

  void _onTrophyTap(TrophyMonster trophy) {
    final isCaptured = _capturedIds.contains(trophy.id);
    if (isCaptured) {
      HapticFeedback.mediumImpact();
      // Play the monster's voice line
      final cardVoiceId = trophy.id.replaceAll('_t', '_0');
      AudioService().playVoice(
        'voice_card_$cardVoiceId.mp3',
        clearQueue: true,
        interrupt: true,
      );
      _showTrophyDetail(trophy);
    } else {
      HapticFeedback.lightImpact();
      AudioService().playSfx('whoosh.mp3');
    }
  }

  void _showTrophyDetail(TrophyMonster trophy) {
    final worldColor = WorldService.getWorldById(_selectedWorldId).themeColor;
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (ctx) => TrophyDetailDialog(
        trophy: trophy,
        defeatCount: _defeatCounts[trophy.id] ?? 0,
        worldColor: worldColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: SpaceBackground(
          child: Center(
            child: CircularProgressIndicator(color: Color(0xFFB388FF)),
          ),
        ),
      );
    }

    final worldTrophies = TrophyService.trophiesForWorld(_selectedWorldId);
    final worldData = WorldService.getWorldById(_selectedWorldId);
    final worldProgress =
        worldTrophies.where((t) => _capturedIds.contains(t.id)).length;

    return Scaffold(
      body: SpaceBackground(
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              const SizedBox(height: 8),
              _buildWorldSelector(),
              const SizedBox(height: 6),
              // World name + progress
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      worldData.name.toUpperCase(),
                      style: TextStyle(
                        color: worldData.themeColor,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: worldData.themeColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: worldData.themeColor.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Text(
                        '$worldProgress / ${worldTrophies.length}',
                        style: TextStyle(
                          color: worldData.themeColor,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Trophy grid
              Expanded(
                child: _buildTrophyGrid(worldTrophies),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 16, 0),
      child: Row(
        children: [
          // Back button
          IconButton(
            onPressed: () {
              AudioService().stopVoice();
              AudioService().playSfx('whoosh.mp3');
              Navigator.of(context).pop();
            },
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const Spacer(),
          // Total progress
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                children: [
                  const Icon(Icons.emoji_events_rounded,
                      color: Color(0xFFFFD54F), size: 22),
                  const SizedBox(width: 6),
                  Text(
                    '$_totalCaptured',
                    style: const TextStyle(
                      color: Color(0xFFFFD54F),
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    ' / ${TrophyService.allTrophies.length}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                'MONSTERS CAUGHT',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 4),
              // Progress bar
              SizedBox(
                width: 140,
                height: 6,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: _totalCaptured / TrophyService.allTrophies.length,
                    backgroundColor: Colors.white.withValues(alpha: 0.1),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFFFFD54F)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWorldSelector() {
    return SizedBox(
      height: 60,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: TrophyService.worldIds.length,
        itemBuilder: (context, index) {
          final worldId = TrophyService.worldIds[index];
          final world = WorldService.getWorldById(worldId);
          final isSelected = worldId == _selectedWorldId;
          final isUnlocked = _worldUnlocked[worldId] ?? false;

          return GestureDetector(
            onTap: isUnlocked
                ? () => _selectWorld(worldId)
                : () {
                    HapticFeedback.lightImpact();
                    AudioService().playSfx('whoosh.mp3');
                  },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? world.themeColor.withValues(alpha: 0.25)
                    : isUnlocked
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.white.withValues(alpha: 0.02),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected
                      ? world.themeColor.withValues(alpha: 0.8)
                      : isUnlocked
                          ? Colors.white.withValues(alpha: 0.15)
                          : Colors.white.withValues(alpha: 0.05),
                  width: isSelected ? 2 : 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: world.themeColor.withValues(alpha: 0.3),
                          blurRadius: 12,
                        ),
                      ]
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  isUnlocked
                      ? Image.asset(
                          world.imagePath,
                          width: 24,
                          height: 24,
                          errorBuilder: (_, _, _) => Icon(
                            Icons.public,
                            size: 24,
                            color: isSelected
                                ? world.themeColor
                                : Colors.white.withValues(alpha: 0.4),
                          ),
                        )
                      : Icon(
                          Icons.lock_rounded,
                          size: 20,
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                  const SizedBox(height: 2),
                  Text(
                    isUnlocked
                        ? world.name.split(' ').first.toUpperCase()
                        : '???',
                    style: TextStyle(
                      color: isSelected
                          ? world.themeColor
                          : isUnlocked
                              ? Colors.white.withValues(alpha: 0.5)
                              : Colors.white.withValues(alpha: 0.2),
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTrophyGrid(List<TrophyMonster> trophies) {
    final worldColor = WorldService.getWorldById(_selectedWorldId).themeColor;
    // Layout: 2 columns. Rows of 2, last row centered if odd count.
    // For 5 trophies: row1(2), row2(2), row3(1 centered = boss)
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        children: _buildTrophyRows(trophies, worldColor),
      ),
    );
  }

  List<Widget> _buildTrophyRows(List<TrophyMonster> trophies, Color worldColor) {
    final rows = <Widget>[];
    for (int i = 0; i < trophies.length; i += 2) {
      final isLastSingle = i + 1 >= trophies.length;
      if (isLastSingle) {
        // Centered boss tile
        rows.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Center(
              child: SizedBox(
                width: 170,
                child: _buildTrophyTile(trophies[i], worldColor),
              ),
            ),
          ),
        );
      } else {
        rows.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Expanded(child: _buildTrophyTile(trophies[i], worldColor)),
                const SizedBox(width: 12),
                Expanded(child: _buildTrophyTile(trophies[i + 1], worldColor)),
              ],
            ),
          ),
        );
      }
    }
    return rows;
  }

  Widget _buildTrophyTile(TrophyMonster trophy, Color worldColor) {
    final isCaptured = _capturedIds.contains(trophy.id);
    final defeatCount = _defeatCounts[trophy.id] ?? 0;
    final inProgress = !isCaptured && defeatCount > 0;
    // Boss monster (last in each world, highest defeat requirement)
    final isBoss = trophy.defeatsRequired >= 3;

    return GestureDetector(
      onTap: () => _onTrophyTap(trophy),
      child: ListenableBuilder(
        listenable: _glowAnimation,
        builder: (context, child) {
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              // Consistent world color for all cards
              gradient: isCaptured
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        worldColor.withValues(alpha: 0.12),
                        worldColor.withValues(alpha: 0.04),
                      ],
                    )
                  : null,
              color: isCaptured ? null : Colors.black.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isCaptured
                    ? worldColor.withValues(
                        alpha: 0.4 + 0.3 * _glowAnimation.value)
                    : inProgress
                        ? worldColor.withValues(alpha: 0.15)
                        : Colors.white.withValues(alpha: 0.06),
                width: isCaptured ? (isBoss ? 2.5 : 2) : 1,
              ),
              boxShadow: isCaptured
                  ? [
                      BoxShadow(
                        color: worldColor.withValues(
                            alpha: 0.12 + 0.12 * _glowAnimation.value),
                        blurRadius: isBoss ? 20 : 14,
                        spreadRadius: isBoss ? 3 : 1,
                      ),
                    ]
                  : null,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Monster image — original colors, no tint
                SizedBox(
                  height: 100,
                  width: 100,
                  child: _buildMonsterImage(trophy, isCaptured, inProgress, worldColor),
                ),
                const SizedBox(height: 8),
                // Name — use world color for consistency
                Text(
                  isCaptured ? trophy.name : '???',
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isCaptured
                        ? worldColor
                        : Colors.white.withValues(alpha: inProgress ? 0.4 : 0.2),
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                // Progress dots for uncaptured (visual only — no text)
                if (!isCaptured) ...[
                  const SizedBox(height: 6),
                  _buildProgressDots(trophy, defeatCount, worldColor),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMonsterImage(
      TrophyMonster trophy, bool isCaptured, bool inProgress, Color worldColor) {
    if (isCaptured) {
      // Show monster in its original colors — no tint overlay
      return Image.asset(
        trophy.imagePath,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => Icon(
          Icons.bug_report,
          size: 60,
          color: worldColor,
        ),
      );
    } else if (inProgress) {
      // Dark silhouette with world-color tint — shape visible, identity hidden
      return Stack(
        alignment: Alignment.center,
        children: [
          ColorFiltered(
            colorFilter: ColorFilter.mode(
              worldColor.withValues(alpha: 0.8),
              BlendMode.srcATop,
            ),
            child: Opacity(
              opacity: 0.35,
              child: Image.asset(
                trophy.imagePath,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => Icon(
                  Icons.bug_report,
                  size: 60,
                  color: worldColor.withValues(alpha: 0.3),
                ),
              ),
            ),
          ),
          // Subtle question mark overlay to hint at mystery
          Icon(
            Icons.help_outline_rounded,
            size: 32,
            color: worldColor.withValues(alpha: 0.25),
          ),
        ],
      );
    } else {
      // Fully locked — dark silhouette showing monster shape
      return Stack(
        children: [
          Center(
            child: ColorFiltered(
              colorFilter: const ColorFilter.mode(
                Color(0xFF1a1a2e),
                BlendMode.srcATop,
              ),
              child: Opacity(
                opacity: 0.3,
                child: Image.asset(
                  trophy.imagePath,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const Icon(
                    Icons.bug_report,
                    size: 60,
                    color: Color(0xFF1a1a2e),
                  ),
                ),
              ),
            ),
          ),
          // Subtle "???" overlay centered
          Center(
            child: Text(
              '???',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.08),
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          // Small lock icon in the bottom-right corner
          Positioned(
            bottom: 4,
            right: 4,
            child: Icon(
              Icons.lock_rounded,
              size: 16,
              color: Colors.white.withValues(alpha: 0.15),
            ),
          ),
        ],
      );
    }
  }

  Widget _buildProgressDots(TrophyMonster trophy, int defeatCount, Color worldColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(trophy.defeatsRequired, (i) {
        final filled = i < defeatCount;
        return Container(
          width: 14,
          height: 14,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled
                ? worldColor.withValues(alpha: 0.8)
                : Colors.white.withValues(alpha: 0.08),
            border: Border.all(
              color: filled
                  ? worldColor.withValues(alpha: 0.9)
                  : worldColor.withValues(alpha: 0.25),
              width: 1.5,
            ),
            boxShadow: filled
                ? [
                    BoxShadow(
                      color: worldColor.withValues(alpha: 0.4),
                      blurRadius: 4,
                    ),
                  ]
                : null,
          ),
          child: filled
              ? Icon(
                  Icons.flash_on_rounded,
                  size: 9,
                  color: Colors.white.withValues(alpha: 0.9),
                )
              : null,
        );
      }),
    );
  }
}

// Monster Detail Dialog moved to ../widgets/trophy_detail_dialog.dart

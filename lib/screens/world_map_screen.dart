import 'package:flutter/material.dart';
import '../services/world_service.dart';
import '../widgets/space_background.dart';

class WorldMapScreen extends StatefulWidget {
  const WorldMapScreen({super.key});

  @override
  State<WorldMapScreen> createState() => _WorldMapScreenState();
}

class _WorldMapScreenState extends State<WorldMapScreen> {
  final _worldService = WorldService();
  String _currentWorldId = 'candy_crater';
  final Map<String, int> _progress = {};
  final Map<String, bool> _unlocked = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final currentId = await _worldService.getCurrentWorldId();
    final progress = <String, int>{};
    final unlocked = <String, bool>{};

    for (final world in WorldService.allWorlds) {
      progress[world.id] = await _worldService.getWorldProgress(world.id);
      unlocked[world.id] = await _worldService.isWorldUnlocked(world.id);
    }

    if (mounted) {
      setState(() {
        _currentWorldId = currentId;
        _progress.addAll(progress);
        _unlocked.addAll(unlocked);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => Navigator.of(context).pop(),
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
                          child: const Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'WORLD MAP',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 28,
                            letterSpacing: 3,
                          ),
                    ),
                  ],
                ),
              ),

              // World list — scrollable vertical path
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: WorldService.allWorlds.length,
                  itemBuilder: (context, index) {
                    final world = WorldService.allWorlds[index];
                    final isUnlocked = _unlocked[world.id] ?? false;
                    final isCurrent = world.id == _currentWorldId;
                    final progress = _progress[world.id] ?? 0;
                    final isCompleted = progress >= world.missionsRequired;

                    return Column(
                      children: [
                        if (index > 0)
                          // Path connector between planets
                          _PathConnector(isActive: isUnlocked),

                        _WorldCard(
                          world: world,
                          isUnlocked: isUnlocked,
                          isCurrent: isCurrent,
                          isCompleted: isCompleted,
                          progress: progress,
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PathConnector extends StatelessWidget {
  final bool isActive;

  const _PathConnector({required this.isActive});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: Center(
        child: Container(
          width: 3,
          height: 40,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isActive
                  ? [
                      Colors.white.withValues(alpha: 0.5),
                      Colors.white.withValues(alpha: 0.3),
                    ]
                  : [
                      Colors.white.withValues(alpha: 0.1),
                      Colors.white.withValues(alpha: 0.05),
                    ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WorldCard extends StatelessWidget {
  final WorldData world;
  final bool isUnlocked;
  final bool isCurrent;
  final bool isCompleted;
  final int progress;

  const _WorldCard({
    required this.world,
    required this.isUnlocked,
    required this.isCurrent,
    required this.isCompleted,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isCurrent
              ? world.themeColor
              : isCompleted
              ? const Color(0xFF69F0AE).withValues(alpha: 0.5)
              : Colors.white.withValues(alpha: 0.1),
          width: isCurrent ? 2 : 1,
        ),
        boxShadow: isCurrent
            ? [
                BoxShadow(
                  color: world.themeColor.withValues(alpha: 0.3),
                  blurRadius: 15,
                ),
              ]
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Planet image
            SizedBox(
              width: 80,
              height: 80,
              child: ColorFiltered(
                colorFilter: isUnlocked
                    ? const ColorFilter.mode(Colors.transparent, BlendMode.dst)
                    : ColorFilter.mode(
                        Colors.black.withValues(alpha: 0.7),
                        BlendMode.srcATop,
                      ),
                child: ClipOval(
                  child: Image.asset(world.imagePath, fit: BoxFit.cover),
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    world.name.toUpperCase(),
                    style: TextStyle(
                      color: isUnlocked
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.4),
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    world.description,
                    style: TextStyle(
                      color: isUnlocked
                          ? Colors.white.withValues(alpha: 0.6)
                          : Colors.white.withValues(alpha: 0.2),
                      fontSize: 12,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  // Progress bar
                  if (isUnlocked) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: SizedBox(
                        height: 8,
                        child: LinearProgressIndicator(
                          value: progress / world.missionsRequired,
                          backgroundColor: Colors.white.withValues(alpha: 0.1),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isCompleted
                                ? const Color(0xFF69F0AE)
                                : world.themeColor,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isCompleted
                          ? 'COMPLETED!'
                          : '$progress / ${world.missionsRequired} missions',
                      style: TextStyle(
                        color: isCompleted
                            ? const Color(0xFF69F0AE)
                            : world.themeColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ] else
                    Row(
                      children: [
                        Icon(
                          Icons.lock,
                          color: Colors.white.withValues(alpha: 0.3),
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'LOCKED',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.3),
                            fontSize: 11,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            // Status icon
            if (isCompleted)
              const Icon(Icons.check_circle, color: Color(0xFF69F0AE), size: 28)
            else if (isCurrent)
              Icon(Icons.play_circle_fill, color: world.themeColor, size: 28),
          ],
        ),
      ),
    );
  }
}

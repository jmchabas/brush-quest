import 'package:flutter/material.dart';
import '../services/audio_service.dart';
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
      // Auto-play voice describing the current world on screen open
      AudioService().playVoice('voice_world_$currentId.mp3', clearQueue: true, interrupt: true);
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
                          onSetCurrent: (isUnlocked && !isCurrent && !isCompleted)
                              ? () async {
                                  final messenger = ScaffoldMessenger.of(context);
                                  await _worldService.setCurrentWorld(world.id);
                                  await _loadData();
                                  if (mounted) {
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text('${world.name} is now your world!'),
                                        backgroundColor: world.themeColor,
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                  }
                                }
                              : null,
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

class _WorldCard extends StatefulWidget {
  final WorldData world;
  final bool isUnlocked;
  final bool isCurrent;
  final bool isCompleted;
  final int progress;
  final VoidCallback? onSetCurrent;

  const _WorldCard({
    required this.world,
    required this.isUnlocked,
    required this.isCurrent,
    required this.isCompleted,
    required this.progress,
    this.onSetCurrent,
  });

  @override
  State<_WorldCard> createState() => _WorldCardState();
}

class _WorldCardState extends State<_WorldCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    if (widget.isCurrent) {
      _glowController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant _WorldCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isCurrent && !oldWidget.isCurrent) {
      _glowController.repeat(reverse: true);
    } else if (!widget.isCurrent && oldWidget.isCurrent) {
      _glowController.stop();
      _glowController.value = 0;
    }
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Always play the world description voice
        AudioService().playVoice('voice_world_${widget.world.id}.mp3', clearQueue: true, interrupt: true);
        if (!widget.isUnlocked) {
          // Locked world — describe world, then say needs more brushing
          AudioService().playVoice('voice_need_stars.mp3');
          return;
        }
        if (widget.onSetCurrent != null) {
          // Unlocked but not current — set as current world
          widget.onSetCurrent!();
        }
      },
      child: AnimatedBuilder(
        animation: _glowController,
        builder: (context, child) {
          final glowAlpha = widget.isCurrent
              ? 0.2 + 0.4 * _glowController.value
              : 0.0;
          final glowBlur = widget.isCurrent
              ? 12.0 + 16.0 * _glowController.value
              : 0.0;
          return Container(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: widget.isCurrent
                    ? widget.world.themeColor
                    : widget.isCompleted
                    ? const Color(0xFF69F0AE).withValues(alpha: 0.5)
                    : Colors.white.withValues(alpha: 0.1),
                width: widget.isCurrent ? 2 : 1,
              ),
              boxShadow: widget.isCurrent
                  ? [
                      BoxShadow(
                        color: widget.world.themeColor.withValues(alpha: glowAlpha),
                        blurRadius: glowBlur,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
            child: child,
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Planet image
              SizedBox(
                width: 100,
                height: 100,
                child: ColorFiltered(
                  colorFilter: widget.isUnlocked
                      ? const ColorFilter.mode(Colors.transparent, BlendMode.dst)
                      : ColorFilter.mode(
                          Colors.black.withValues(alpha: 0.7),
                          BlendMode.srcATop,
                        ),
                  child: ClipOval(
                    child: Image.asset(widget.world.imagePath, fit: BoxFit.cover),
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
                      widget.world.name.toUpperCase(),
                      style: TextStyle(
                        color: widget.isUnlocked
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.4),
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Progress bar
                    if (widget.isUnlocked) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: SizedBox(
                          height: 8,
                          child: LinearProgressIndicator(
                            value: widget.progress / widget.world.missionsRequired,
                            backgroundColor: Colors.white.withValues(alpha: 0.1),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              widget.isCompleted
                                  ? const Color(0xFF69F0AE)
                                  : widget.world.themeColor,
                            ),
                          ),
                        ),
                      ),
                    ] else
                      Icon(
                        Icons.lock,
                        color: Colors.white.withValues(alpha: 0.3),
                        size: 18,
                      ),
                  ],
                ),
              ),
              // Status icon — only for completed worlds
              if (widget.isCompleted)
                const Icon(Icons.check_circle, color: Color(0xFF69F0AE), size: 28),
            ],
          ),
        ),
      ),
    );
  }
}

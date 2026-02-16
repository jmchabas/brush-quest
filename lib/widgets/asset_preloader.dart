import 'package:flutter/material.dart';
import '../services/audio_service.dart';

class AssetPreloader extends StatefulWidget {
  final Widget child;

  const AssetPreloader({super.key, required this.child});

  @override
  State<AssetPreloader> createState() => _AssetPreloaderState();
}

class _AssetPreloaderState extends State<AssetPreloader> {
  bool _loaded = false;

  static const _images = [
    'assets/images/background_space.png',
    'assets/images/monster_purple.png',
    'assets/images/monster_green.png',
    'assets/images/monster_orange.png',
    'assets/images/monster_red.png',
    'assets/images/hero_blaze.png',
    'assets/images/hero_frost.png',
    'assets/images/hero_bolt.png',
    'assets/images/hero_shadow.png',
    'assets/images/hero_leaf.png',
    'assets/images/hero_nova.png',
    'assets/images/planet_candy.png',
    'assets/images/planet_slime.png',
    'assets/images/planet_volcano.png',
    'assets/images/planet_shadow.png',
    'assets/images/planet_fortress.png',
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded) {
      _preload();
    }
  }

  Future<void> _preload() async {
    await Future.wait([
      // Precache all images
      for (final path in _images) precacheImage(AssetImage(path), context),
      // Preload all audio
      AudioService().preloadAll(),
    ]);
    if (mounted) {
      setState(() => _loaded = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loaded) return widget.child;

    return Scaffold(
      body: Container(
        color: const Color(0xFF0D0B2E),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'BRUSH QUEST',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontSize: 42,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 3,
                      shadows: [
                        Shadow(
                          color:
                              const Color(0xFF7C4DFF).withValues(alpha: 0.8),
                          blurRadius: 20,
                        ),
                        Shadow(
                          color:
                              const Color(0xFF00E5FF).withValues(alpha: 0.5),
                          blurRadius: 40,
                        ),
                      ],
                    ),
              ),
              const SizedBox(height: 32),
              const SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  color: Color(0xFF00E5FF),
                  strokeWidth: 3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../widgets/space_background.dart';

class ParentGuideScreen extends StatelessWidget {
  const ParentGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SpaceBackground(
        child: SafeArea(
          child: Column(
            children: [
              // App bar row
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'How Brush Quest Works',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              // Scrollable content
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _section(
                      'Our Promise',
                      'Brush Quest is designed to make tooth brushing a habit your '
                          'child looks forward to.\n\n'
                          'There are no ads. No purchase prompts are shown to children. '
                          'Everything is earned through brushing.',
                      Icons.favorite,
                      Colors.red,
                    ),
                    _section(
                      'Streaks',
                      'Brushing every day builds a streak. The longer the streak, '
                          'the better the treasure chest rewards.\n\n'
                          'If a day is missed, there\'s a one-day grace period \u2014 '
                          'your child won\'t lose their streak from a single missed day. '
                          'You can also pause the streak from the parent dashboard for '
                          'vacations or sick days.\n\n'
                          'Their best streak is always remembered and celebrated.',
                      Icons.local_fire_department,
                      Colors.orange,
                    ),
                    _section(
                      'Morning & Evening',
                      'The app supports two brushing sessions per day \u2014 '
                          'morning (before 3pm) and evening (after 3pm). When your child '
                          'brushes both morning and evening, they earn a bonus star.\n\n'
                          'Two teeth icons on the home screen show which sessions are complete.',
                      Icons.wb_twilight,
                      Colors.amber,
                    ),
                    _section(
                      'Treasure Chests',
                      'After each session, your child earns a treasure chest. Better '
                          'streaks mean better chests \u2014 this is structured, not random. '
                          'There are no loot boxes or gambling mechanics.',
                      Icons.card_giftcard,
                      Colors.green,
                    ),
                    _section(
                      'Daily Bonuses',
                      'Each day has a theme that adds variety: extra energy, precision '
                          'focus, treasure boost, or boss encounters. These rotate '
                          'automatically on a 5-day cycle. Your child doesn\'t need to '
                          'track these \u2014 they add variety automatically.',
                      Icons.flash_on,
                      Colors.yellow,
                    ),
                    _section(
                      'Trophy Collecting',
                      'Your child captures monster trophies by brushing. Each trophy '
                          'requires defeating a monster 1\u20133 times. Trophies are earned '
                          'through brushing \u2014 never randomly, never through purchases.',
                      Icons.emoji_events,
                      const Color(0xFFFFD54F),
                    ),
                    _section(
                      'Stars & The Shop',
                      'Stars are earned by brushing (2 per session, plus streak bonuses). '
                          'Stars can be spent in the shop on new heroes and gear.\n\n'
                          'Your child\'s Ranger Rank (lifetime total) never goes down \u2014 '
                          'only the spendable wallet changes when they buy something.',
                      Icons.star,
                      Colors.yellow,
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section(
      String title, String body, IconData icon, Color iconColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: iconColor, size: 22),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              body,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

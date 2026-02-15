# Brush Quest - Kids Toothbrushing App

## Project Overview
An Android app to help 7-year-old boys build a toothbrushing habit through gamification.
Theme: Space Rangers vs Cavity Monsters.

## Status: MVP Complete (v1)

## Key Decisions
- **Concept**: Gamified 2-minute timer (4 x 30s quadrants), defeat cavity monsters
- **Theme**: Space + Monsters. Kid is a "Space Ranger"
- **Tech stack**: Flutter/Dart, Android-only for now
- **Dependencies**: audioplayers, shared_preferences, google_fonts (Fredoka)
- **Design**: Dark space background, neon purple/cyan palette, large touch targets
- **Audio**: ElevenLabs TTS for voice prompts, ElevenLabs SFX for sound effects
- **Art**: DALL-E generated monster illustrations (4 unique monsters)
- **Persistence**: Local only via shared_preferences (streaks, stars, brush count)

## Architecture
```
lib/
  main.dart                    # App entry, theme, routing
  screens/
    home_screen.dart           # Main screen: title, stats, big BRUSH button
    brushing_screen.dart       # Core game: countdown, 4 phases, monster animations
    victory_screen.dart        # Post-brush celebration: star, confetti, stats
  services/
    audio_service.dart         # Singleton for SFX and voice playback
    streak_service.dart        # SharedPreferences-based streak/star tracking
assets/
  images/                      # Monster PNGs, space background
  audio/                       # SFX (zap, defeat, victory, whoosh, beep) + voice lines
```

## Game Flow
1. Home screen → big pulsing BRUSH button, shows streak/stars/today count
2. Countdown → "3, 2, 1, GO!" with voice + animation
3. Brushing → 4 phases (TL, TR, BL, BR) x 30s each, monster shrinks/fades as timer runs
4. Victory → star earned, confetti, streak updated, "Great job Space Ranger!"

## Build & Run
```bash
export JAVA_HOME="/opt/homebrew/opt/openjdk/libexec/openjdk.jdk/Contents/Home"
flutter run          # run on connected device/emulator
flutter build apk    # build release APK
```

## Next Steps / Ideas
- Polish animations (monster entrance, defeat explosion)
- Add more monster variety / randomization
- Morning/evening detection (sun/moon icon)
- Parent settings screen (adjust timer, view history)
- Unlockable spaceship upgrades for long streaks
- Haptic feedback on phase transitions

# Brush Quest - Kids Toothbrushing App

## Project Overview
An Android app to help 7-year-old boys build a toothbrushing habit through gamification.
Theme: Space Rangers vs Cavity Monsters.

## Status: v3 — Simplified Economy + Voiced Encouragements

## Key Decisions
- **Concept**: Gamified 2-minute timer (4 x 30s quadrants), defeat cavity monsters
- **Theme**: Space + Monsters. Kid is a "Space Ranger"
- **Tech stack**: Flutter/Dart, Android-only for now
- **Dependencies**: audioplayers, shared_preferences, google_fonts (Fredoka), wakelock_plus, camera, permission_handler
- **Design**: Dark space background, neon purple/cyan palette, large touch targets
- **Audio**: ElevenLabs TTS for voice prompts and encouragements. 3-player SFX pool. Music uses pre-looped 2-min file. SFX suppressed during voice playback.
- **Art**: DALL-E generated monster illustrations (4 base images, tinted/varied procedurally)
- **Persistence**: Local only via shared_preferences (streaks, stars, brush count, onboarding flag)
- **Economy**: 1 star per completed brush. No mid-brush star collection. No chest mechanic. Hero costs: 0/5/10/15/25/40. Weapon costs: 0/3/7/12/20/30.

## Architecture
```
lib/
  main.dart                    # App entry, theme, routing, onboarding check
  screens/
    home_screen.dart           # Main screen: hero+weapon display, stats, BRUSH button
    brushing_screen.dart       # Core game: countdown, 4 phases, monster combat
    victory_screen.dart        # Post-brush celebration: +1 star, monsters defeated, progress bar
    onboarding_screen.dart     # First-launch tutorial (3 pages)
    world_map_screen.dart      # World progression map
    hero_shop_screen.dart      # Hero/weapon shop
  services/
    audio_service.dart         # Singleton SFX pool + voice + music playback
    streak_service.dart        # SharedPreferences-based streak/star tracking
    achievement_service.dart   # Milestone achievement system
    world_service.dart         # World progression (5 worlds)
    hero_service.dart          # Hero roster + unlock system
    weapon_service.dart        # Weapon roster + unlock system
    camera_service.dart        # Front camera motion detection for brushing
  widgets/
    space_background.dart      # Reusable space background
    mute_button.dart           # Audio mute toggle
    glass_card.dart            # Semi-transparent card widget
    achievement_popup.dart     # Overlay popup for achievements
    asset_preloader.dart       # Loading screen with progress
    mouth_guide.dart           # Visual mouth/teeth diagram for quadrant guidance
assets/
  images/                      # Monster PNGs, hero PNGs, planet PNGs, space background
  audio/                       # SFX, voice lines (11 encouragements), battle music loop
```

## Game Flow
1. First launch → Onboarding (3 pages: welcome, how to play, mouth guide tutorial)
2. Home screen → big pulsing BRUSH button with hero + weapon badge, shows streak/stars/today count
3. Countdown → "3, 2, 1, GO!" with voice + animation
4. Brushing → 4 phases (TL, TR, BL, BR) x 30s each:
   - Visual mouth guide overlay shows which teeth to brush (3s per transition)
   - Compact mouth indicator stays visible in header during brushing
   - Each monster has unique personality (name, movement, size, tint, entrance style)
   - Camera-based motion detection drives attack frequency
   - Voiced encouragements play every 8s + at 20s and 10s remaining
   - Companion bubbles show icons (no text) since kids can't read
5. Victory → +1 star, monsters defeated count, total stars, next hero progress bar

## Monster Personality System
Each monster gets randomized: bob speed/amount, wobble intensity, size multiplier, color tint, entrance animation style (scale/slide-left/slide-right/drop), and a randomly generated name (e.g. "Captain Plaque", "Evil Gumrot"). Bosses get special personality with golden tint and "THE CAVITY KING" name.

## Audio System
- 3-player SFX pool for parallel playback
- SFX suppressed during voice playback to prevent channel contention
- Dedicated voice player with overlap prevention
- 11 voiced encouragement lines (ElevenLabs "Jessica" voice)
- Music: 2-min pre-concatenated loop file (battle_music_loop.mp3) for reliable Android playback
- Music ducks (volume 0.12) while voice lines play, restores to 0.5 after
- Fresh AudioPlayer created for each music session to avoid stuck state
- Mute state persisted in SharedPreferences

## Build & Run
```bash
export JAVA_HOME="/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home"
export PATH="$JAVA_HOME/bin:$PATH"
flutter run          # run on connected device/emulator
flutter build apk    # build release APK
```
Note: JDK 17 required. JDK 25 is incompatible with AGP 8.11.1.

## Next Steps / Ideas
- Morning/evening detection (sun/moon icon)
- Parent settings screen (adjust timer, view history)
- Unlockable spaceship upgrades for long streaks
- Brush history view (data already collected via getHistory())
- More monster base images for even more variety

#!/usr/bin/env python3
"""Generate Cycle 7 voice files: world mission briefings + unlock encouragements.

Generates for both 'classic' (Jessica) and 'buddy' (BQ Buddy) voice styles.
Replaces existing world briefing voices with new mission-briefing format.
Creates new unlock encouragement voices.

Usage:
    python3 tmp/generate_cycle7_voices.py              # generate all
    python3 tmp/generate_cycle7_voices.py --force       # overwrite existing
    python3 tmp/generate_cycle7_voices.py --classic     # classic only
    python3 tmp/generate_cycle7_voices.py --buddy       # buddy only
"""

import json
import os
import sys
import time
import urllib.request
import urllib.error
from pathlib import Path

# DEPRECATED: Use generate_all_voices.py instead for new voice generation.
# This script had a bug: buddy voice ID was BQ Buddy instead of George.
# Voice IDs (fixed)
CLASSIC_VOICE_ID = "cgSgspJ2msm6clMCkdW9"  # Jessica
BUDDY_VOICE_ID = "JBFqnCBsd6RMkjVDRZzb"    # George (was incorrectly KgnilQWk9YVtLxuGYyYS)

MODEL_ID = "eleven_multilingual_v2"

BASE_DIR = Path(__file__).parent.parent / "assets" / "audio" / "voices"

# Voice settings per style
CLASSIC_SETTINGS = {
    "stability": 0.35,
    "similarity_boost": 0.75,
    "style": 0.2,
    "speed": 0.95,
    "use_speaker_boost": True,
}

BUDDY_SETTINGS = {
    "stability": 0.35,
    "similarity_boost": 0.75,
    "style": 0.25,
    "speed": 1.0,
    "use_speaker_boost": True,
}

# ─── World Mission Briefings (replace existing voice_world_*.mp3) ───

WORLD_VOICES_CLASSIC = {
    "voice_world_candy_crater": (
        "Space Ranger! Cavity monsters are hiding in the Candy Crater "
        "— a sweet planet covered in candy and sugar crystals! "
        "Get your toothbrush ready and fight them off!"
    ),
    "voice_world_slime_swamp": (
        "Space Ranger! Cavity monsters are hiding in the Slime Swamp "
        "— a gooey planet full of slimy creatures! "
        "Get your toothbrush ready and fight them off!"
    ),
    "voice_world_sugar_volcano": (
        "Space Ranger! Cavity monsters are hiding in the Sugar Volcano "
        "— a fiery planet with erupting volcanoes! "
        "Get your toothbrush ready and fight them off!"
    ),
    "voice_world_shadow_nebula": (
        "Space Ranger! You're heading into the Shadow Nebula "
        "— a mysterious dark planet full of spooky surprises! "
        "Get your toothbrush ready and fight them off!"
    ),
    "voice_world_cavity_fortress": (
        "Space Ranger! You've reached the Cavity Fortress "
        "— the Cavity King's stronghold! This is a big challenge! "
        "Get your toothbrush ready!"
    ),
    "voice_world_frozen_tundra": (
        "Space Ranger! Cavity monsters are hiding in the Frozen Tundra "
        "— an icy planet with blizzards and frozen monsters! "
        "Get your toothbrush ready and fight them off!"
    ),
    "voice_world_toxic_jungle": (
        "Space Ranger! You're entering the Toxic Jungle "
        "— a poisonous jungle with venomous creatures! "
        "Get your toothbrush ready and fight them off!"
    ),
    "voice_world_crystal_cave": (
        "Space Ranger! You're exploring the Crystal Cave "
        "— underground caverns filled with glowing crystals! "
        "Get your toothbrush ready and fight them off!"
    ),
    "voice_world_storm_citadel": (
        "Space Ranger! You're approaching the Storm Citadel "
        "— a floating fortress in a lightning storm! "
        "Get your toothbrush ready and fight them off!"
    ),
    "voice_world_dark_dimension": (
        "Space Ranger! You're entering the Dark Dimension "
        "— the final dark realm beyond space and time! "
        "This is the ultimate challenge! Get your toothbrush ready!"
    ),
}

WORLD_VOICES_BUDDY = {
    "voice_world_candy_crater": (
        "Ooh, we're going to the Candy Crater! "
        "It's all sticky and sweet but there's monsters hiding! "
        "Let's get 'em!"
    ),
    "voice_world_slime_swamp": (
        "Ew, the Slime Swamp! It's so gooey and gross! "
        "There's slimy monsters everywhere! Let's get 'em!"
    ),
    "voice_world_sugar_volcano": (
        "Whoa, the Sugar Volcano! It's super hot and fiery! "
        "Those monsters think they can hide in there! Let's get 'em!"
    ),
    "voice_world_shadow_nebula": (
        "Ooh, the Shadow Nebula! It's really dark and spooky! "
        "But we're not scared, right? Let's get 'em!"
    ),
    "voice_world_cavity_fortress": (
        "Oh my gosh, the Cavity Fortress! This is the big one! "
        "The Cavity King lives here! We can totally do this!"
    ),
    "voice_world_frozen_tundra": (
        "Brrr, the Frozen Tundra! It's freezing cold with big blizzards! "
        "Those frozen monsters don't stand a chance! Let's go!"
    ),
    "voice_world_toxic_jungle": (
        "Whoa, the Toxic Jungle! It's all green and poisonous! "
        "Those creatures are no match for us! Let's get 'em!"
    ),
    "voice_world_crystal_cave": (
        "Ooh, the Crystal Cave! It's so sparkly and glowy! "
        "But there's monsters hiding in those crystals! Let's find 'em!"
    ),
    "voice_world_storm_citadel": (
        "Whoa, the Storm Citadel! There's lightning everywhere! "
        "This is gonna be epic! Let's do this!"
    ),
    "voice_world_dark_dimension": (
        "The Dark Dimension! This is it, the final challenge! "
        "We're the bravest Space Rangers ever! Let's finish this!"
    ),
}

# ─── Unlock Encouragement Voices (new files) ───

UNLOCK_VOICES_CLASSIC = {
    "voice_unlock_next_frost": (
        "Keep brushing to unlock Frost the Ice Wolf! You're getting closer!"
    ),
    "voice_unlock_next_bolt": (
        "Keep brushing to unlock Bolt the Lightning Robot! You're almost there!"
    ),
    "voice_unlock_next_shadow": (
        "Keep brushing to unlock Shadow the Ninja Cat! So close!"
    ),
    "voice_unlock_next_leaf": (
        "Keep brushing to unlock Leaf the Nature Guardian! You're getting closer!"
    ),
    "voice_unlock_next_nova": (
        "Keep brushing to unlock Nova the Cosmic Phoenix! The ultimate hero!"
    ),
    "voice_unlock_next_flame_sword": (
        "Keep brushing to unlock the Flame Sword! Fiery power awaits!"
    ),
    "voice_unlock_next_ice_hammer": (
        "Keep brushing to unlock the Ice Hammer! Freezing power awaits!"
    ),
    "voice_unlock_next_lightning_wand": (
        "Keep brushing to unlock the Lightning Wand! Electric power awaits!"
    ),
    "voice_unlock_next_vine_whip": (
        "Keep brushing to unlock the Vine Whip! Nature power awaits!"
    ),
    "voice_unlock_next_cosmic_shield": (
        "Keep brushing to unlock the Cosmic Shield! Ultimate defense awaits!"
    ),
}

UNLOCK_VOICES_BUDDY = {
    "voice_unlock_next_frost": (
        "We're almost gonna get Frost! He's so cool, literally! Keep brushing!"
    ),
    "voice_unlock_next_bolt": (
        "Bolt is almost ours! He's like a super robot! Keep going!"
    ),
    "voice_unlock_next_shadow": (
        "Shadow is so close! A ninja cat, how cool is that! Keep brushing!"
    ),
    "voice_unlock_next_leaf": (
        "Leaf is almost here! A nature guardian with vine powers! Keep going!"
    ),
    "voice_unlock_next_nova": (
        "Nova is the ultimate hero! A cosmic phoenix! We're so close!"
    ),
    "voice_unlock_next_flame_sword": (
        "The Flame Sword is almost ours! It's on fire! Keep brushing!"
    ),
    "voice_unlock_next_ice_hammer": (
        "The Ice Hammer is so close! It freezes everything! Keep going!"
    ),
    "voice_unlock_next_lightning_wand": (
        "The Lightning Wand shoots lightning! We almost have it! Keep brushing!"
    ),
    "voice_unlock_next_vine_whip": (
        "The Vine Whip is almost ours! Nature power! Keep going!"
    ),
    "voice_unlock_next_cosmic_shield": (
        "The Cosmic Shield! Ultimate defense! We're so close! Keep brushing!"
    ),
}

# Also generate the extra world voice that may exist
# voice_world_plaque_plains — check if this world exists
# (It doesn't in the current 10 worlds, skip)


def get_api_key():
    config_path = Path.home() / ".claude.json"
    with open(config_path) as f:
        config = json.load(f)
    for name, server in config.get("mcpServers", {}).items():
        if "eleven" in name.lower():
            key = server.get("env", {}).get("ELEVENLABS_API_KEY", "")
            if key:
                return key
    raise RuntimeError("ELEVENLABS_API_KEY not found in ~/.claude.json")


def generate_voice(api_key, voice_id, settings, filename, text, output_dir, force=False):
    """Generate a single voice file via ElevenLabs API."""
    output_path = output_dir / f"{filename}.mp3"

    if output_path.exists() and output_path.stat().st_size > 1000 and not force:
        return filename, "skipped", 0

    payload = json.dumps({
        "text": text,
        "model_id": MODEL_ID,
        "voice_settings": settings,
    }).encode("utf-8")

    url = f"https://api.elevenlabs.io/v1/text-to-speech/{voice_id}"
    headers = {
        "xi-api-key": api_key,
        "Content-Type": "application/json",
        "Accept": "audio/mpeg",
    }

    req = urllib.request.Request(url, data=payload, headers=headers, method="POST")

    max_retries = 3
    for attempt in range(max_retries):
        try:
            with urllib.request.urlopen(req, timeout=30) as resp:
                audio_data = resp.read()
                with open(output_path, "wb") as f:
                    f.write(audio_data)
                return filename, "ok", len(audio_data)
        except urllib.error.HTTPError as e:
            if e.code == 429:
                wait = 2 ** (attempt + 1)
                print(f"  Rate limited on {filename}, waiting {wait}s...")
                time.sleep(wait)
            else:
                body = e.read().decode("utf-8", errors="replace")
                return filename, f"HTTP {e.code}: {body[:100]}", 0
        except Exception as e:
            if attempt < max_retries - 1:
                time.sleep(1)
            else:
                return filename, f"Error: {e}", 0

    return filename, "max retries exceeded", 0


def generate_batch(api_key, voice_id, settings, voices, output_dir, style_name, force=False):
    """Generate a batch of voice files."""
    output_dir.mkdir(parents=True, exist_ok=True)

    total = len(voices)
    success = 0
    skipped = 0
    failed = 0

    for i, (filename, text) in enumerate(voices.items(), 1):
        print(f"  [{style_name}] {i}/{total}: {filename}")
        name, status, size = generate_voice(
            api_key, voice_id, settings, filename, text, output_dir, force
        )
        if status == "ok":
            print(f"    -> OK ({size:,} bytes)")
            success += 1
        elif status == "skipped":
            print(f"    -> Skipped (exists)")
            skipped += 1
        else:
            print(f"    -> FAILED: {status}")
            failed += 1

        # Small delay between requests to avoid rate limits
        if status == "ok" and i < total:
            time.sleep(0.5)

    return success, skipped, failed


def main():
    force = "--force" in sys.argv
    classic_only = "--classic" in sys.argv
    buddy_only = "--buddy" in sys.argv

    if classic_only and buddy_only:
        print("Cannot specify both --classic and --buddy")
        sys.exit(1)

    do_classic = not buddy_only
    do_buddy = not classic_only

    api_key = get_api_key()
    print(f"API key loaded: {api_key[:8]}...")
    if force:
        print("Force mode: will overwrite existing files")
    print()

    total_success = 0
    total_skipped = 0
    total_failed = 0

    # Classic voices
    if do_classic:
        classic_dir = BASE_DIR / "classic"

        print("=== Classic World Briefings (Jessica) ===")
        s, sk, f = generate_batch(
            api_key, CLASSIC_VOICE_ID, CLASSIC_SETTINGS,
            WORLD_VOICES_CLASSIC, classic_dir, "classic", force
        )
        total_success += s; total_skipped += sk; total_failed += f

        print("\n=== Classic Unlock Encouragements (Jessica) ===")
        s, sk, f = generate_batch(
            api_key, CLASSIC_VOICE_ID, CLASSIC_SETTINGS,
            UNLOCK_VOICES_CLASSIC, classic_dir, "classic", force
        )
        total_success += s; total_skipped += sk; total_failed += f

    # Buddy voices
    if do_buddy:
        buddy_dir = BASE_DIR / "buddy"

        print("\n=== Buddy World Briefings (BQ Buddy) ===")
        s, sk, f = generate_batch(
            api_key, BUDDY_VOICE_ID, BUDDY_SETTINGS,
            WORLD_VOICES_BUDDY, buddy_dir, "buddy", force
        )
        total_success += s; total_skipped += sk; total_failed += f

        print("\n=== Buddy Unlock Encouragements (BQ Buddy) ===")
        s, sk, f = generate_batch(
            api_key, BUDDY_VOICE_ID, BUDDY_SETTINGS,
            UNLOCK_VOICES_BUDDY, buddy_dir, "buddy", force
        )
        total_success += s; total_skipped += sk; total_failed += f

    print(f"\n{'='*40}")
    print(f"Done! Generated: {total_success}, Skipped: {total_skipped}, Failed: {total_failed}")
    est_chars = sum(len(t) for t in WORLD_VOICES_CLASSIC.values()) + \
                sum(len(t) for t in UNLOCK_VOICES_CLASSIC.values()) + \
                sum(len(t) for t in WORLD_VOICES_BUDDY.values()) + \
                sum(len(t) for t in UNLOCK_VOICES_BUDDY.values())
    print(f"Total characters across all voices: ~{est_chars:,}")


if __name__ == "__main__":
    main()

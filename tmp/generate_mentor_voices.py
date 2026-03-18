#!/usr/bin/env python3
"""Batch generate Brush Quest mentor voice files from MASTER_SCRIPT_V2.md

Generates all buddy voice files using "George" (warm male storyteller).
Victory arcs are generated as single-take full scripts, then split with ffmpeg.
"""

import json
import re
import os
import sys
import time
import subprocess
import urllib.request
import urllib.error
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

# Config
VOICE_ID = "JBFqnCBsd6RMkjVDRZzb"  # George - Warm, Captivating Storyteller
MODEL_ID = "eleven_multilingual_v2"
OUTPUT_DIR = Path(__file__).parent.parent / "assets" / "audio" / "voices" / "buddy"
SCRIPT_FILE = Path(__file__).parent / "voice-test" / "MASTER_SCRIPT_V2.md"

# Voice settings — calm, warm mentor style
SETTINGS_BATTLE = {  # encouragements, arcs, directions — engaged but calm
    "stability": 0.55,
    "similarity_boost": 0.75,
    "style": 0.20,
    "speed": 0.92,
    "use_speaker_boost": True,
}
SETTINGS_DESCRIPTIVE = {  # cards, worlds, onboarding, greetings — warm narrator
    "stability": 0.60,
    "similarity_boost": 0.75,
    "style": 0.15,
    "speed": 0.90,
    "use_speaker_boost": True,
}

# Files that use battle/engaged settings
BATTLE_PREFIXES = [
    "voice_arc", "voice_victory_arc", "voice_countdown",
    "voice_keep_going", "voice_youre_doing_great", "voice_nice_combo",
    "voice_keep_it_up", "voice_so_strong", "voice_super", "voice_go_go_go",
    "voice_awesome", "voice_wow_amazing", "voice_unstoppable", "voice_almost_there",
    "voice_lets_fight", "voice_chest_wow", "voice_chest_dance",
    "voice_chest_bonus_star", "voice_chest_double", "voice_chest_jackpot",
    "voice_chest_encourage", "voice_need_stars", "voice_welcome_back",
    "voice_top_left", "voice_top_right", "voice_bottom_left", "voice_bottom_right",
]

# Victory arc full takes — will be split into beats after generation
VICTORY_FULL_TAKES = [
    "voice_victory_arc1_full",
    "voice_victory_arc2_full",
    "voice_victory_arc3_full",
    "voice_victory_arc4_full",
]


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


def parse_script(script_path):
    """Parse MASTER_SCRIPT_V2.md and return list of (filename, text) tuples."""
    lines = []
    with open(script_path) as f:
        for line in f:
            line = line.strip()
            match = re.match(r'^(voice_\S+)\s*\|\s*"(.+)"$', line)
            if match:
                filename = match.group(1)
                text = match.group(2)
                lines.append((filename, text))
    return lines


def is_battle_file(filename):
    return any(filename.startswith(prefix) for prefix in BATTLE_PREFIXES)


def generate_voice(api_key, filename, text, output_dir):
    """Generate a single voice file via ElevenLabs API."""
    output_path = output_dir / f"{filename}.mp3"

    settings = SETTINGS_BATTLE if is_battle_file(filename) else SETTINGS_DESCRIPTIVE

    payload = json.dumps({
        "text": text,
        "model_id": MODEL_ID,
        "voice_settings": settings,
    }).encode("utf-8")

    url = f"https://api.elevenlabs.io/v1/text-to-speech/{VOICE_ID}"
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


def split_victory_arc(full_file, beat_files, output_dir):
    """Split a full victory arc take into 3 beats using silence detection.

    Uses ffmpeg to detect silence, then splits at the pause points.
    Falls back to even thirds if silence detection fails.
    """
    full_path = output_dir / f"{full_file}.mp3"
    if not full_path.exists():
        print(f"  Cannot split {full_file}: file not found")
        return

    # Get duration
    result = subprocess.run(
        ["ffprobe", "-v", "quiet", "-show_entries", "format=duration",
         "-of", "csv=p=0", str(full_path)],
        capture_output=True, text=True
    )
    duration = float(result.stdout.strip())

    # Detect silence points (pauses between beats)
    result = subprocess.run(
        ["ffmpeg", "-i", str(full_path), "-af",
         "silencedetect=noise=-30dB:d=0.3", "-f", "null", "-"],
        capture_output=True, text=True
    )

    # Parse silence end times
    silence_ends = []
    for line in result.stderr.split('\n'):
        if 'silence_end' in line:
            match = re.search(r'silence_end:\s*([\d.]+)', line)
            if match:
                silence_ends.append(float(match.group(1)))

    # We need 2 split points for 3 beats
    if len(silence_ends) >= 2:
        # Use the first two significant silences
        split1 = silence_ends[0]
        split2 = silence_ends[1] if len(silence_ends) >= 2 else duration * 2 / 3
    else:
        # Fallback: even thirds
        split1 = duration / 3
        split2 = duration * 2 / 3

    # Split into 3 beats
    splits = [
        (0, split1, beat_files[0]),
        (split1, split2, beat_files[1]),
        (split2, duration, beat_files[2]),
    ]

    for start, end, beat_name in splits:
        beat_path = output_dir / f"{beat_name}.mp3"
        subprocess.run([
            "ffmpeg", "-y", "-i", str(full_path),
            "-ss", str(start), "-to", str(end),
            "-ac", "1", "-ab", "64k", "-ar", "22050",
            beat_path
        ], capture_output=True)
        if beat_path.exists():
            print(f"  Split: {beat_name} ({end - start:.1f}s)")

    # Remove the full take file (not needed in the app)
    full_path.unlink(missing_ok=True)


def main():
    api_key = get_api_key()
    print(f"API key loaded: {api_key[:8]}...")
    print(f"Voice: George (JBFqnCBsd6RMkjVDRZzb)")

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    # Parse script
    entries = parse_script(SCRIPT_FILE)
    print(f"Found {len(entries)} voice lines in script")

    # Separate full-take victory arcs from regular entries
    regular = [(fn, txt) for fn, txt in entries if fn not in VICTORY_FULL_TAKES]
    full_takes = [(fn, txt) for fn, txt in entries if fn in VICTORY_FULL_TAKES]

    # Skip beat files that will be split from full takes
    beat_names = set()
    for ft in VICTORY_FULL_TAKES:
        base = ft.replace("_full", "")
        for i in range(1, 4):
            beat_names.add(f"{base}_beat{i}")
    regular = [(fn, txt) for fn, txt in regular if fn not in beat_names]

    # Delete existing buddy files to start fresh
    existing = list(OUTPUT_DIR.glob("voice_*.mp3"))
    if existing:
        print(f"Deleting {len(existing)} existing buddy voice files...")
        for f in existing:
            f.unlink()

    print(f"Generating {len(regular)} regular files + {len(full_takes)} full-take victory arcs")
    print(f"Estimated characters: {sum(len(t) for _, t in regular + full_takes)}")
    print()

    # Generate regular files with thread pool
    completed = 0
    errors = []
    total = len(regular) + len(full_takes)

    with ThreadPoolExecutor(max_workers=5) as pool:
        futures = {
            pool.submit(generate_voice, api_key, fn, txt, OUTPUT_DIR): fn
            for fn, txt in regular + full_takes
        }

        for future in as_completed(futures):
            filename, status, size = future.result()
            completed += 1

            if status == "ok":
                print(f"  [{completed}/{total}] OK {filename} ({size // 1024}KB)")
            else:
                print(f"  [{completed}/{total}] FAIL {filename}: {status}")
                errors.append((filename, status))

    # Split victory arc full takes into beats
    print("\nSplitting victory arcs into beats...")
    for i in range(1, 5):
        full = f"voice_victory_arc{i}_full"
        beats = [f"voice_victory_arc{i}_beat{b}" for b in range(1, 4)]
        split_victory_arc(full, beats, OUTPUT_DIR)

    # Compress all generated files to 64kbps mono
    print("\nCompressing to 64kbps mono...")
    for mp3 in OUTPUT_DIR.glob("voice_*.mp3"):
        tmp = mp3.with_suffix(".tmp.mp3")
        subprocess.run([
            "ffmpeg", "-y", "-i", str(mp3),
            "-ac", "1", "-ab", "64k", "-ar", "22050", str(tmp)
        ], capture_output=True)
        if tmp.exists() and tmp.stat().st_size > 0:
            tmp.rename(mp3)

    print(f"\nDone! Generated {completed - len(errors)}/{total} files")
    if errors:
        print(f"Errors ({len(errors)}):")
        for fn, err in errors:
            print(f"  {fn}: {err}")

    buddy_files = list(OUTPUT_DIR.glob("voice_*.mp3"))
    print(f"Total buddy voice files: {len(buddy_files)}")


if __name__ == "__main__":
    main()

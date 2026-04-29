#!/usr/bin/env python3
"""Re-render the 8 captioned Play Store screenshots at iPhone aspect ratios.

Source:  marketing/screenshots/captioned_NN_<scene>.png  (864×1728, 1:2)
Output:  marketing/screenshots/ios/<size>/captioned_NN_<scene>.png
         at 6.9" (1320×2868), 6.7" (1290×2796), 6.5" (1242×2688).

Strategy: resize source by the WIDTH ratio, then pad top + bottom with the
app's space background color (#0A0E27) until the image reaches the iPhone's
target height. See docs/ios-port/screenshots.md.

Run:  python3 marketing/screenshots/generate_ios_screenshots.py
"""

from pathlib import Path

from PIL import Image

SCREENSHOTS = [
    "captioned_01_home_screen.png",
    "captioned_02_battle_monster.png",
    "captioned_03_battle_combo.png",
    "captioned_04_brushing_guide.png",
    "captioned_05_heroes.png",
    "captioned_06_weapons.png",
    "captioned_07_monster_collection.png",
    "captioned_08_world_map.png",
]

# (folder name, target_w, target_h)
TARGETS = [
    ("6.9", 1320, 2868),
    ("6.7", 1290, 2796),
    ("6.5", 1242, 2688),
]

# App's space background color — matches the in-app aesthetic.
PAD_COLOR = (10, 14, 39)  # #0A0E27


def adapt(src_path: Path, target_w: int, target_h: int) -> Image.Image:
    src = Image.open(src_path).convert("RGB")
    src_w, src_h = src.size
    scale = target_w / src_w
    scaled_h = round(src_h * scale)
    scaled = src.resize((target_w, scaled_h), Image.Resampling.LANCZOS)
    canvas = Image.new("RGB", (target_w, target_h), PAD_COLOR)
    y_offset = (target_h - scaled_h) // 2
    canvas.paste(scaled, (0, y_offset))
    return canvas


def main() -> None:
    here = Path(__file__).resolve().parent
    out_root = here / "ios"
    out_root.mkdir(exist_ok=True)

    written = 0
    for size_name, w, h in TARGETS:
        out_dir = out_root / size_name
        out_dir.mkdir(exist_ok=True)
        for filename in SCREENSHOTS:
            src = here / filename
            if not src.exists():
                print(f"  skip (missing source): {filename}")
                continue
            out_img = adapt(src, w, h)
            out_path = out_dir / filename
            out_img.save(out_path, "PNG", optimize=True)
            print(f"  wrote {out_path.relative_to(here.parent.parent)}  {w}x{h}")
            written += 1
    print(f"\nDone. {written} screenshots written under {out_root.relative_to(here.parent.parent)}/")


if __name__ == "__main__":
    main()

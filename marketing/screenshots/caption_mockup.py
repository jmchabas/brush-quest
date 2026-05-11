"""
Batch overlay marketing captions on Play Store screenshots.
Output: captioned_<name>.png alongside each source.
"""
from PIL import Image, ImageDraw, ImageFont
from pathlib import Path

SCREENSHOTS = Path("/Users/jimchabas/Projects/brush-quest/marketing/screenshots")
FONT = "/Users/jimchabas/Projects/brush-quest/assets/fonts/Fredoka/Fredoka-VariableFont_wdth_wght.ttf"
FONT_WEIGHT = 500  # Medium on Fredoka's wght axis (300 = light, 500 = medium, 700 = bold)

CAPTIONS = [
    ("01_home_screen.png",        "Pick a hero. Start the quest"),
    ("02_battle_monster.png",     "Every stroke powers the hero"),
    ("03_battle_combo.png",       "Brush longer, hit harder"),
    ("04_brushing_guide.png",     "Voice-guided — no reading needed"),
    ("05_heroes.png",             "Heroes earned by brushing"),
    ("06_weapons.png",            "Weapons earned by brushing"),
    ("07_monster_collection.png", "Catch all 50 cavity monsters"),
    ("08_world_map.png",          "10 worlds to conquer"),
]

BAND_HEIGHT_RATIO = 0.16
BAND_COLOR = (20, 13, 43, 255)     # near-black #140D2B, matches space bg
TEXT_COLOR = (255, 221, 0)         # #FFDD00 yellow, matches BRUSH QUEST logo
STROKE_COLOR = (0, 0, 0)
STROKE_WIDTH = 3
FONT_SIZE_RATIO = 0.08

# Auto-shrink font until the caption fits on one line within the band
MIN_FONT_RATIO = 0.055


def render(img_path: Path, caption: str, out_path: Path) -> None:
    base = Image.open(img_path).convert("RGBA")
    w, h = base.size
    band_h = int(h * BAND_HEIGHT_RATIO)

    overlay = Image.new("RGBA", base.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    draw.rectangle([0, 0, w, band_h], fill=BAND_COLOR)

    font_size = int(w * FONT_SIZE_RATIO)
    min_size = int(w * MIN_FONT_RATIO)
    while font_size >= min_size:
        font = ImageFont.truetype(FONT, font_size)
        try:
            font.set_variation_by_axes([FONT_WEIGHT, 100])  # [wght, wdth]
        except (AttributeError, OSError):
            pass
        bbox = draw.textbbox((0, 0), caption, font=font, stroke_width=STROKE_WIDTH)
        text_w = bbox[2] - bbox[0]
        if text_w <= w * 0.92:
            break
        font_size -= 2

    text_h = bbox[3] - bbox[1]
    text_x = (w - text_w) / 2 - bbox[0]
    text_y = (band_h - text_h) / 2 - bbox[1]
    draw.text((text_x, text_y), caption, font=font, fill=TEXT_COLOR,
              stroke_width=STROKE_WIDTH, stroke_fill=STROKE_COLOR)

    final = Image.alpha_composite(base, overlay).convert("RGB")
    final.save(out_path, format="PNG", optimize=True)
    print(f"  {out_path.name}  [{font_size}pt]")


if __name__ == "__main__":
    print(f"Rendering {len(CAPTIONS)} captioned screenshots:")
    for name, caption in CAPTIONS:
        src = SCREENSHOTS / name
        out = SCREENSHOTS / f"captioned_{name}"
        render(src, caption, out)
    print("done")

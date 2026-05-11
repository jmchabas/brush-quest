"""
Batch caption v2 (fresh phone screenshots of v20).
Output: captioned_<name>.png alongside each source.
Black+Yellow style, Fredoka Medium, thin stroke.
"""
from PIL import Image, ImageDraw, ImageFont
from pathlib import Path

HERE = Path("/Users/jimchabas/Projects/brush-quest/marketing/screenshots/v2")
FONT = "/Users/jimchabas/Projects/brush-quest/assets/fonts/Fredoka/Fredoka-VariableFont_wdth_wght.ttf"
FONT_WEIGHT = 500

CAPTIONS = [
    ("01_home.png",      "Pick a hero. Start the quest"),
    ("02_worldmap.png",  "10 worlds to conquer"),
    ("03_heroes.png",    "Heroes earned by brushing"),
    ("04_brushing.png",  "Voice-guided — no reading needed"),
    ("05_victory.png",   "Every brush defeats a monster"),
    ("06_dashboard.png", "A progress dashboard for parents"),
    ("07_settings.png",  "Grows with ages 3–12"),
    ("08_monsters.png",  "Catch all 50 cavity monsters"),
]

BAND_HEIGHT_RATIO = 0.16
BAND_COLOR = (20, 13, 43, 255)     # near-black #140D2B
TEXT_COLOR = (255, 221, 0)         # #FFDD00 yellow
STROKE_COLOR = (0, 0, 0)
STROKE_WIDTH = 3
FONT_SIZE_RATIO = 0.08
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
            font.set_variation_by_axes([FONT_WEIGHT, 100])
        except (AttributeError, OSError):
            pass
        bbox = draw.textbbox((0, 0), caption, font=font, stroke_width=STROKE_WIDTH)
        if (bbox[2] - bbox[0]) <= w * 0.92:
            break
        font_size -= 2

    text_w = bbox[2] - bbox[0]
    text_h = bbox[3] - bbox[1]
    text_x = (w - text_w) / 2 - bbox[0]
    text_y = (band_h - text_h) / 2 - bbox[1]
    draw.text((text_x, text_y), caption, font=font, fill=TEXT_COLOR,
              stroke_width=STROKE_WIDTH, stroke_fill=STROKE_COLOR)

    final = Image.alpha_composite(base, overlay).convert("RGB")
    final.save(out_path, format="PNG", optimize=True)
    print(f"  {out_path.name}  [{font_size}pt, {w}x{h}]")


if __name__ == "__main__":
    print(f"Rendering {len(CAPTIONS)} captioned v2 screenshots:")
    for name, caption in CAPTIONS:
        src = HERE / name
        out = HERE / f"captioned_{name}"
        render(src, caption, out)
    print("done")

"""
Render font-weight/stroke variants of the home-screen caption for comparison.
"""
from PIL import Image, ImageDraw, ImageFont
from pathlib import Path

SCREENSHOTS = Path("/Users/jimchabas/Projects/brush-quest/marketing/screenshots")
FONT = "/Users/jimchabas/Projects/brush-quest/assets/fonts/Fredoka/Fredoka-VariableFont_wdth_wght.ttf"
SHOT = "01_home_screen.png"
CAPTION = "Pick a hero. Start the quest"

VARIANTS = [
    # label, weight, stroke_width
    ("A_medium_stroke8",   500, 8),
    ("B_medium_stroke3",   500, 3),
    ("C_semibold_stroke6", 600, 6),
]

BAND_HEIGHT_RATIO = 0.16
BAND_COLOR = (20, 13, 43, 255)
TEXT_COLOR = (255, 221, 0)
STROKE_COLOR = (0, 0, 0)
FONT_SIZE_RATIO = 0.08
MIN_FONT_RATIO = 0.055


def render(img_path: Path, caption: str, weight: int, stroke_width: int, out_path: Path) -> None:
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
            font.set_variation_by_axes([weight, 100])
        except (AttributeError, OSError):
            pass
        bbox = draw.textbbox((0, 0), caption, font=font, stroke_width=stroke_width)
        if (bbox[2] - bbox[0]) <= w * 0.92:
            break
        font_size -= 2

    text_w = bbox[2] - bbox[0]
    text_h = bbox[3] - bbox[1]
    text_x = (w - text_w) / 2 - bbox[0]
    text_y = (band_h - text_h) / 2 - bbox[1]
    draw.text((text_x, text_y), caption, font=font, fill=TEXT_COLOR,
              stroke_width=stroke_width, stroke_fill=STROKE_COLOR)

    final = Image.alpha_composite(base, overlay).convert("RGB")
    final.save(out_path, format="PNG", optimize=True)
    print(f"  font_{out_path.stem}.png  [{font_size}pt, weight {weight}, stroke {stroke_width}px]")


if __name__ == "__main__":
    src = SCREENSHOTS / SHOT
    print("Rendering 3 font variants:")
    for label, weight, stroke_width in VARIANTS:
        out = SCREENSHOTS / f"font_{label}.png"
        render(src, CAPTION, weight, stroke_width, out)
    print("done")

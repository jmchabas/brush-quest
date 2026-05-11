"""
Render color variants of the same caption + screenshot for side-by-side comparison.
Pick a winner, then use in the main caption_mockup.py batch.
"""
from PIL import Image, ImageDraw, ImageFont
from pathlib import Path

SCREENSHOTS = Path("/Users/jimchabas/Projects/brush-quest/marketing/screenshots")
FONT = "/System/Library/Fonts/Supplemental/Arial Rounded Bold.ttf"

SHOT = "01_home_screen.png"
CAPTION = "Pick a hero. Start the quest"

VARIANTS = [
    # label, band color, text color
    ("navy",        (26, 27, 58, 255),   (255, 255, 255)),  # deep space navy + white
    ("purple",      (139, 47, 205, 255), (255, 255, 255)),  # neon purple + white
    ("black_yellow",(20, 13, 43, 255),   (255, 221, 0)),    # near-black + #FFDD00 yellow
]

BAND_HEIGHT_RATIO = 0.16
STROKE_COLOR = (0, 0, 0)
STROKE_WIDTH = 8
FONT_SIZE_RATIO = 0.08


def render(img_path: Path, caption: str, band_color, text_color, out_path: Path) -> None:
    base = Image.open(img_path).convert("RGBA")
    w, h = base.size
    band_h = int(h * BAND_HEIGHT_RATIO)

    overlay = Image.new("RGBA", base.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    draw.rectangle([0, 0, w, band_h], fill=band_color)

    font_size = int(w * FONT_SIZE_RATIO)
    font = ImageFont.truetype(FONT, font_size)
    bbox = draw.textbbox((0, 0), caption, font=font, stroke_width=STROKE_WIDTH)
    while (bbox[2] - bbox[0]) > w * 0.92 and font_size > int(w * 0.055):
        font_size -= 2
        font = ImageFont.truetype(FONT, font_size)
        bbox = draw.textbbox((0, 0), caption, font=font, stroke_width=STROKE_WIDTH)

    text_w = bbox[2] - bbox[0]
    text_h = bbox[3] - bbox[1]
    text_x = (w - text_w) / 2 - bbox[0]
    text_y = (band_h - text_h) / 2 - bbox[1]
    draw.text((text_x, text_y), caption, font=font, fill=text_color,
              stroke_width=STROKE_WIDTH, stroke_fill=STROKE_COLOR)

    final = Image.alpha_composite(base, overlay).convert("RGB")
    final.save(out_path, format="PNG", optimize=True)
    print(f"  variant_{out_path.stem.split('_', 1)[1]}.png  [{font_size}pt]")


if __name__ == "__main__":
    src = SCREENSHOTS / SHOT
    print("Rendering 3 color variants of caption #1:")
    for label, band_color, text_color in VARIANTS:
        out = SCREENSHOTS / f"variant_{label}.png"
        render(src, CAPTION, band_color, text_color, out)
    print("done")

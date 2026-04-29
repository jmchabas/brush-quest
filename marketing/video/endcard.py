"""Generate end-card PNG at phone-video resolution.

Two variants:
  endcard.png       — Play Store CTA  ("Get it on Google Play")
  endcard_ios.png   — App Store / iOS — privacy-first pill ("Free. No ads. No tracking.")
                      Apple App Previews play inside the App Store, so a CTA
                      to the App Store is redundant; the privacy claim is the
                      actual differentiator vs other kids' apps and matches
                      the parent VO line at 22.5s.
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

OUT_DIR = Path("/Users/jimchabas/Projects/brush-quest/marketing/video")
FONT = "/Users/jimchabas/Projects/brush-quest/assets/fonts/Fredoka/Fredoka-VariableFont_wdth_wght.ttf"

W, H = 1080, 2410
BG = (20, 13, 43)       # near-black space navy
YELLOW = (255, 221, 0)  # BRUSH QUEST logo yellow
WHITE = (255, 255, 255)


def render(cta_text: str, out_name: str) -> None:
    img = Image.new("RGB", (W, H), BG)
    draw = ImageDraw.Draw(img)

    # Title
    title_font = ImageFont.truetype(FONT, 180)
    try: title_font.set_variation_by_axes([700, 100])
    except Exception: pass
    title = "BRUSH QUEST"
    bbox = draw.textbbox((0, 0), title, font=title_font)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    draw.text(((W - tw) / 2 - bbox[0], H * 0.36 - th / 2 - bbox[1]), title, font=title_font, fill=YELLOW)

    # Subtitle
    sub_font = ImageFont.truetype(FONT, 78)
    try: sub_font.set_variation_by_axes([500, 100])
    except Exception: pass
    sub = "Kids Toothbrush"
    bbox = draw.textbbox((0, 0), sub, font=sub_font)
    sw, sh = bbox[2] - bbox[0], bbox[3] - bbox[1]
    draw.text(((W - sw) / 2 - bbox[0], H * 0.46 - sh / 2 - bbox[1]), sub, font=sub_font, fill=WHITE)

    # CTA pill (smaller font for longer iOS copy)
    cta_size = 70 if len(cta_text) <= 22 else 56
    cta_font = ImageFont.truetype(FONT, cta_size)
    try: cta_font.set_variation_by_axes([600, 100])
    except Exception: pass
    bbox = draw.textbbox((0, 0), cta_text, font=cta_font)
    cw_, ch = bbox[2] - bbox[0], bbox[3] - bbox[1]

    pill_pad_x, pill_pad_y = 60, 40
    pill_x0 = (W - cw_) / 2 - bbox[0] - pill_pad_x
    pill_y0 = H * 0.64 - ch / 2 - bbox[1] - pill_pad_y
    pill_x1 = pill_x0 + cw_ + pill_pad_x * 2
    pill_y1 = pill_y0 + ch + pill_pad_y * 2
    draw.rounded_rectangle([pill_x0, pill_y0, pill_x1, pill_y1], radius=60, fill=YELLOW)
    draw.text(((W - cw_) / 2 - bbox[0], H * 0.64 - ch / 2 - bbox[1]), cta_text, font=cta_font, fill=BG)

    out_path = OUT_DIR / out_name
    img.save(out_path)
    print(f"wrote {out_path}")


if __name__ == "__main__":
    render("Get it on Google Play", "endcard.png")
    render("Free. No ads. No tracking.", "endcard_ios.png")

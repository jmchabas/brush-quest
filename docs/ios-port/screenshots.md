# iPhone Screenshot Spec — App Store Connect

**Source:** Apple's App Store Connect display sizes table.

## Required sizes (App Store Connect upload form)

App Store Connect requires at least one screenshot for the **largest iPhone display size** present in your app. Brush Quest is iPhone-only for v1 (`TARGETED_DEVICE_FAMILY = 1`), so the required sets are:

| Display size | Pixel size (portrait) | Devices | Required? |
|---|---|---|---|
| **6.9"** | 1320 × 2868 | iPhone 16 Pro Max | ✅ Required (largest size as of 2026) |
| **6.7"** | 1290 × 2796 | iPhone 15 Pro Max, 16 Plus | Optional but recommended |
| **6.5"** | 1242 × 2688 | iPhone 11 Pro Max, XS Max | Optional |
| **5.5"** | 1242 × 2208 | iPhone 8 Plus, 7 Plus | Required if app supports iOS 11.0 (we don't — ours is iOS 15.0+) |

Since we ship `IPHONEOS_DEPLOYMENT_TARGET = 15.0`, the 5.5" set is **NOT required** (5.5" devices stop receiving iOS updates after iOS 16). We just need 6.9" at minimum; uploading 6.7" + 6.5" gives Apple flexibility to render the right size on different devices.

**Per-set count:** 2–10 screenshots per size. We ship 8 (matches our Play Store set).

## Source assets we already have

| Source | Path | Pixel size | Aspect | Notes |
|---|---|---|---|---|
| Captioned Play Store screenshots (8 panels) | `marketing/screenshots/captioned_01_home_screen.png` … `captioned_08_world_map.png` | 864 × 1728 | 1:2.000 | Captions baked in via `marketing/screenshots/caption_mockup.py` |

## Aspect adaptation map

The Play Store source is 1:2 (864×1728). iPhone targets are slightly taller (1:2.17). Two adaptation strategies:

### Option A — Resize-then-pad (recommended)

1. Scale the source by the width ratio:
   - 6.9": 864 → 1320 ⇒ height becomes 2640
   - 6.7": 864 → 1290 ⇒ height becomes 2580
   - 6.5": 864 → 1242 ⇒ height becomes 2484
2. Add a top + bottom band of solid `#0A0E27` (the app's space background) to reach the target height:
   - 6.9": pad 2640 → 2868 (114 px top + 114 px bottom)
   - 6.7": pad 2580 → 2796 (108 px top + 108 px bottom)
   - 6.5": pad 2484 → 2688 (102 px top + 102 px bottom)

**Why this works:** preserves the captioned image at full fidelity, and the dark band reads as more space — visually consistent with the in-app aesthetic.

### Option B — Native iPhone simulator capture

Re-shoot the eight scenes on iPhone Simulator at native 6.9" aspect, then re-apply captions via `caption_mockup.py`. More effort, more authentic but requires shooting all eight scenes (home, battle monster, battle combo, brushing guide, heroes, weapons, monster collection, world map). Skip for v1; revisit for v1.1.

## Output paths (target)

`marketing/screenshots/ios/<size>/captioned_NN_<scene>.png`

- `marketing/screenshots/ios/6.9/captioned_01_home_screen.png` (1320×2868)
- `marketing/screenshots/ios/6.7/captioned_01_home_screen.png` (1290×2796)
- `marketing/screenshots/ios/6.5/captioned_01_home_screen.png` (1242×2688)

…repeated for all 8 scenes per size.

## Generator script (Phase 1M-2)

A Python+PIL script will:

1. For each captioned source PNG (8 files):
   1. For each iPhone size (6.9, 6.7, 6.5):
      1. Compute scale factor = target_w / 864
      2. Resize via Lanczos resampling
      3. Compute pad = (target_h - scaled_h) / 2
      4. Composite onto a `target_w × target_h` canvas filled with `#0A0E27`, centered vertically
      5. Save to `marketing/screenshots/ios/<size>/captioned_NN_<scene>.png`

Acceptance: 24 output files (8 scenes × 3 sizes) at exact pixel dimensions, no transparency, captions readable.

## Pre-upload check

Before uploading to App Store Connect:

```bash
for f in marketing/screenshots/ios/*/captioned_*.png; do
  sips -g pixelWidth -g pixelHeight -g hasAlpha "$f" | head -3
done
```

Verify each file matches its directory's expected dimensions and `hasAlpha: no`.

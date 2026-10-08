#!/usr/bin/env python3
"""Builds every logo and icon from apps/mobile/assets/brand/splitbit_icon_source.png.

  python3 tool/make_brand_assets.py

Writes: the transparent in-app mark, Android launcher icons (legacy and adaptive) and the splash
logo, the iOS app icon set, and the share page logo. Run again if the source image changes.
"""
import json
import os

import numpy as np
from PIL import Image

root = os.path.join(os.path.dirname(__file__), "..")
mobile = os.path.join(root, "apps", "mobile")
src = Image.open(os.path.join(mobile, "assets", "brand", "splitbit_icon_source.png")).convert("RGB")


def logo_with_alpha(img):
    """Crop to the logo and turn the white background transparent (soft edges)."""
    arr = np.array(img).astype(np.float32)
    dist = (255.0 - arr).max(axis=2)  # how far each pixel is from white
    mask = dist > 6
    ys, xs = np.where(mask)
    x0, x1, y0, y1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
    alpha = np.clip(dist / 64.0, 0.0, 1.0)  # anything clearly off-white is fully opaque
    rgba = np.dstack([arr, alpha * 255.0]).astype(np.uint8)
    return Image.fromarray(rgba, "RGBA").crop((x0, y0, x1, y1))


mark = logo_with_alpha(src)  # transparent, tight crop


def fit(img, box_w, box_h):
    s = min(box_w / img.width, box_h / img.height)
    return img.resize((max(1, round(img.width * s)), max(1, round(img.height * s))), Image.LANCZOS)


def on_canvas(size, fraction, bg=None):
    """The mark centred on a square canvas, its longer side `fraction` of the canvas."""
    canvas = Image.new("RGBA", (size, size), bg if bg else (0, 0, 0, 0))
    m = fit(mark, size * fraction, size * fraction)
    canvas.alpha_composite(m, ((size - m.width) // 2, (size - m.height) // 2))
    return canvas


def save(img, *path, rgb=False):
    p = os.path.join(mobile, *path)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    (img.convert("RGB") if rgb else img).save(p, optimize=True)


# ---- in-app mark (Logo widget, share picture)
save(fit(mark, 240, 300), "assets", "brand", "splitbit_mark.png")

# ---- Android
res = ["app", "src", "main", "res"]
legacy = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
adaptive = {"mdpi": 108, "hdpi": 162, "xhdpi": 216, "xxhdpi": 324, "xxxhdpi": 432}
white = (255, 255, 255, 255)
for d, px in legacy.items():
    save(on_canvas(px, 0.74, white), "android", *res, f"mipmap-{d}", "ic_launcher.png", rgb=True)
for d, px in adaptive.items():
    # The adaptive icon is cropped to a circle or squircle: keep the mark inside the middle 60%.
    save(on_canvas(px, 0.62), "android", *res, f"mipmap-{d}", "ic_launcher_foreground.png")
# Splash logo, about 120 dp.
save(fit(mark, 300, 372), "android", *res, "drawable-xxhdpi", "launch_logo.png")

# ---- iOS (no transparency allowed in app icons)
icon_dir = os.path.join(mobile, "ios", "Runner", "Assets.xcassets", "AppIcon.appiconset")
contents = json.load(open(os.path.join(icon_dir, "Contents.json")))
for entry in contents["images"]:
    w = float(entry["size"].split("x")[0])
    px = round(w * int(entry["scale"].rstrip("x")))
    on_canvas(px, 0.74, white).convert("RGB").save(os.path.join(icon_dir, entry["filename"]), optimize=True)

# ---- share page
share = os.path.join(root, "web", "share")
fit(mark, 160, 200).save(os.path.join(share, "logo.png"), optimize=True)
print("brand assets written")

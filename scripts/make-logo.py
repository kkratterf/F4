#!/usr/bin/env python3
"""Build every F4 logo asset from one still: Stanis, "F4, basito".

The logo is the "F4, basito" face of Stanis from the Italian series Boris,
the meme F4 is named after, committed on the maintainer's explicit request.
The source still is kept as it came in Resources/logo/source-frame.png;
this script crops the face square, cleans it and scales it up.

Usage: python3 scripts/make-logo.py   (needs Pillow, numpy and
opencv-python-headless)

Writes, all committed:
  Resources/logo/logo.png         1024px square master, full bleed
  Resources/logo/icon.png         1024px macOS app icon (squircle + shadow)
  Resources/AppIcon.icns          the app icon, picked up by build-app.sh
  site/favicon.svg, favicon.ico   site favicon and header logo
  site/apple-touch-icon.png       180px, iOS rounds it itself
  site/icon-192.png, icon-512.png web app manifest icons
  raycast/assets/icon.png         512px Raycast extension icon
"""

import base64
import io
import struct
import sys
from pathlib import Path

import cv2
import numpy as np
from PIL import Image, ImageEnhance, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "Resources/logo/source-frame.png"
CROP_X, CROP_Y, CROP = 170, 0, 400   # the face, in source pixels


def denoise(frame: Image.Image) -> Image.Image:
    """Remove the clip's compression noise and block edges before scaling up,
    so the upscale doesn't magnify them into grain."""
    bgr = cv2.cvtColor(np.asarray(frame), cv2.COLOR_RGB2BGR)
    bgr = cv2.fastNlMeansDenoisingColored(bgr, None, 2, 2, 5, 13)
    return Image.fromarray(cv2.cvtColor(bgr, cv2.COLOR_BGR2RGB))


def upscale(img: Image.Image, size: int) -> Image.Image:
    """Scale in 2x steps with an edge-aware pass in between: cleaner than one
    big Lanczos jump, which turns every leftover artefact into grain."""
    while img.width * 2 <= size:
        img = img.resize((img.width * 2, img.height * 2), Image.BICUBIC)
        bgr = cv2.cvtColor(np.asarray(img), cv2.COLOR_RGB2BGR)
        bgr = cv2.edgePreservingFilter(bgr, flags=cv2.RECURS_FILTER, sigma_s=6, sigma_r=0.07)
        img = Image.fromarray(cv2.cvtColor(bgr, cv2.COLOR_BGR2RGB))
    return img.resize((size, size), Image.LANCZOS)


def master(frame: Image.Image) -> Image.Image:
    crop = denoise(frame.crop((CROP_X, CROP_Y, CROP_X + CROP, CROP_Y + CROP)))
    big = upscale(crop, 1024)
    big = big.filter(ImageFilter.UnsharpMask(radius=2, percent=45, threshold=3))
    big = ImageEnhance.Color(big).enhance(1.1)
    big = ImageEnhance.Contrast(big).enhance(1.05)
    # Soft vignette so the eyes read first.
    yy, xx = np.mgrid[0:1024, 0:1024].astype(np.float32)
    d = np.sqrt(((xx - 512) / 700) ** 2 + ((yy - 380) / 700) ** 2)
    v = (1 - 0.28 * np.clip(d - 0.35, 0, 1) ** 1.4)[..., None]
    out = np.asarray(big, dtype=np.float32) * v
    return Image.fromarray(out.clip(0, 255).astype(np.uint8))


def squircle(size: int, n: float = 4.2) -> Image.Image:
    """Superellipse mask close to the macOS app icon shape, 4x supersampled."""
    s = size * 4
    c = (s - 1) / 2
    yy, xx = np.mgrid[0:s, 0:s].astype(np.float32)
    inside = (np.abs((xx - c) / c) ** n + np.abs((yy - c) / c) ** n) <= 1
    m = Image.fromarray((inside * 255).astype(np.uint8))
    return m.resize((size, size), Image.LANCZOS)


def app_icon(logo: Image.Image) -> Image.Image:
    """macOS icon grid: an 824px shape centred on a 1024px canvas, with shadow."""
    canvas = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    shape = squircle(824)
    shadow = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    sm = Image.new("L", (1024, 1024), 0)
    sm.paste(shape, (100, 112))
    shadow.putalpha(sm.point(lambda a: a * 0.35).filter(ImageFilter.GaussianBlur(14)))
    canvas = Image.alpha_composite(canvas, shadow)
    face = logo.resize((824, 824), Image.LANCZOS).convert("RGBA")
    face.putalpha(shape)
    canvas.alpha_composite(face, (100, 100))
    return canvas


def write_icns(icon: Image.Image, path: Path) -> None:
    """Minimal .icns with PNG chunks, the format iconutil writes."""
    chunks = [("icp4", 16), ("icp5", 32), ("icp6", 64), ("ic07", 128), ("ic08", 256),
              ("ic09", 512), ("ic10", 1024)]
    body = b""
    for kind, px in chunks:
        buf = io.BytesIO()
        icon.resize((px, px), Image.LANCZOS).save(buf, "PNG", optimize=True)
        data = buf.getvalue()
        body += kind.encode() + struct.pack(">I", len(data) + 8) + data
    path.write_bytes(b"icns" + struct.pack(">I", len(body) + 8) + body)


def favicon_svg(logo: Image.Image) -> str:
    buf = io.BytesIO()
    logo.resize((192, 192), Image.LANCZOS).save(buf, "JPEG", quality=86, optimize=True, progressive=True)
    b64 = base64.b64encode(buf.getvalue()).decode()
    return (
        '<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" viewBox="0 0 64 64">\n'
        '  <!-- The F4 logo: Stanis, basito, built by scripts/make-logo.py. -->\n'
        '  <clipPath id="s"><rect width="64" height="64" rx="15"/></clipPath>\n'
        f'  <image clip-path="url(#s)" width="64" height="64" href="data:image/jpeg;base64,{b64}"/>\n'
        '</svg>\n')


def main() -> int:
    logo = master(Image.open(SOURCE).convert("RGB"))
    (ROOT / "Resources/logo").mkdir(parents=True, exist_ok=True)
    logo.save(ROOT / "Resources/logo/logo.png", optimize=True)
    icon = app_icon(logo)
    icon.save(ROOT / "Resources/logo/icon.png", optimize=True)
    write_icns(icon, ROOT / "Resources/AppIcon.icns")

    site = ROOT / "site"
    (site / "favicon.svg").write_text(favicon_svg(logo))
    rounded = logo.resize((256, 256), Image.LANCZOS).convert("RGBA")
    mask = Image.new("L", (1024, 1024), 0)
    from PIL import ImageDraw
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, 1023, 1023), radius=240, fill=255)
    rounded.putalpha(mask.resize((256, 256), Image.LANCZOS))
    rounded.save(site / "favicon.ico", sizes=[(16, 16), (32, 32), (48, 48)])
    logo.resize((180, 180), Image.LANCZOS).save(site / "apple-touch-icon.png", optimize=True)
    for px in (192, 512):
        logo.resize((px, px), Image.LANCZOS).save(site / f"icon-{px}.png", optimize=True)
    (ROOT / "raycast/assets").mkdir(parents=True, exist_ok=True)
    icon.resize((512, 512), Image.LANCZOS).save(ROOT / "raycast/assets/icon.png", optimize=True)
    print("logo assets written")
    return 0


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter
import math


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "TrainyIOS/Trainy/Assets.xcassets/AppIcon.appiconset/TrainyAppIcon.png"
SIZE = 1024
SCALE = 3
W = SIZE * SCALE


def rounded_rectangle_mask(size: int, radius: int) -> Image.Image:
    mask = Image.new("L", (size, size), 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle((0, 0, size - 1, size - 1), radius=radius, fill=255)
    return mask


def vertical_gradient(top, bottom) -> Image.Image:
    img = Image.new("RGB", (W, W), top)
    px = img.load()
    for y in range(W):
        t = y / (W - 1)
        # Slightly weighted so the bottom stays deep and premium.
        t = t * t * 0.72 + t * 0.28
        color = tuple(round(top[i] * (1 - t) + bottom[i] * t) for i in range(3))
        for x in range(W):
            px[x, y] = color
    return img


def radial_glow(center, radius, color, alpha) -> Image.Image:
    glow = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    px = glow.load()
    cx, cy = center
    for y in range(max(0, cy - radius), min(W, cy + radius)):
        for x in range(max(0, cx - radius), min(W, cx + radius)):
            d = math.hypot(x - cx, y - cy) / radius
            if d < 1:
                a = int(alpha * (1 - d) ** 2)
                px[x, y] = (*color, a)
    return glow


def poly(draw: ImageDraw.ImageDraw, pts, fill):
    draw.polygon([(int(x), int(y)) for x, y in pts], fill=fill)


def main() -> None:
    bg = vertical_gradient((12, 18, 29), (2, 6, 13)).convert("RGBA")

    bg.alpha_composite(radial_glow((int(W * 0.33), int(W * 0.18)), int(W * 0.65), (52, 142, 255), 95))
    bg.alpha_composite(radial_glow((int(W * 0.78), int(W * 0.83)), int(W * 0.55), (36, 215, 190), 46))
    bg.alpha_composite(radial_glow((int(W * 0.45), int(W * 0.63)), int(W * 0.45), (255, 255, 255), 18))

    vignette = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    vpx = vignette.load()
    c = W / 2
    for y in range(W):
        for x in range(W):
            d = min(1, math.hypot(x - c, y - c) / (W * 0.72))
            a = int(116 * max(0, d - 0.56) ** 1.7)
            if a:
                vpx[x, y] = (0, 0, 0, a)
    bg.alpha_composite(vignette)

    art = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    d = ImageDraw.Draw(art)

    white = (248, 252, 255, 255)
    ink = (5, 12, 22, 235)
    glass = (185, 221, 255, 88)

    # Flighty-like principle: one confident, unmistakable vehicle glyph.
    # Front-on train shape so it cannot read as a plane or shuttle.
    body_layer = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    bd = ImageDraw.Draw(body_layer)
    body = (W * 0.30, W * 0.27, W * 0.70, W * 0.74)
    bd.rounded_rectangle(body, radius=int(W * 0.105), fill=white)

    # Lower taper gives the car a rail nose without becoming illustrative.
    poly(
        bd,
        [
            (W * 0.30, W * 0.60),
            (W * 0.70, W * 0.60),
            (W * 0.64, W * 0.78),
            (W * 0.36, W * 0.78),
        ],
        white,
    )

    # Wide windshield and destination band.
    bd.rounded_rectangle(
        (W * 0.37, W * 0.35, W * 0.63, W * 0.49),
        radius=int(W * 0.03),
        fill=(12, 25, 42, 245),
    )
    bd.rounded_rectangle(
        (W * 0.39, W * 0.30, W * 0.61, W * 0.335),
        radius=int(W * 0.018),
        fill=(12, 25, 42, 238),
    )
    bd.polygon(
        [
            (W * 0.51, W * 0.36),
            (W * 0.62, W * 0.37),
            (W * 0.62, W * 0.46),
            (W * 0.53, W * 0.48),
        ],
        fill=glass,
    )

    # Simple front details: headlights and center coupler.
    bd.ellipse((W * 0.37, W * 0.61, W * 0.43, W * 0.67), fill=(14, 26, 42, 255))
    bd.ellipse((W * 0.57, W * 0.61, W * 0.63, W * 0.67), fill=(14, 26, 42, 255))
    bd.rounded_rectangle(
        (W * 0.46, W * 0.61, W * 0.54, W * 0.70),
        radius=int(W * 0.018),
        fill=(7, 15, 26, 238),
    )

    shadow = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    sd.rounded_rectangle(body, radius=int(W * 0.105), fill=(0, 0, 0, 135))
    poly(
        sd,
        [
            (W * 0.30, W * 0.60),
            (W * 0.70, W * 0.60),
            (W * 0.64, W * 0.78),
            (W * 0.36, W * 0.78),
        ],
        (0, 0, 0, 135),
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(int(W * 0.026)))
    bg.alpha_composite(shadow, (0, int(W * 0.03)))
    bg.alpha_composite(body_layer)

    # Track mark: quiet, centered, and obviously rail-related at small sizes.
    d = ImageDraw.Draw(bg)
    d.rounded_rectangle((W * 0.30, W * 0.84, W * 0.70, W * 0.89), radius=int(W * 0.025), fill=white)
    d.rounded_rectangle((W * 0.37, W * 0.91, W * 0.63, W * 0.935), radius=int(W * 0.013), fill=(248, 252, 255, 214))

    bg.alpha_composite(art)

    # Fine rim for the iOS icon mask without drawing rounded corners into the asset.
    rim = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    rd = ImageDraw.Draw(rim)
    rd.rounded_rectangle(
        (int(W * 0.045), int(W * 0.045), int(W * 0.955), int(W * 0.955)),
        radius=int(W * 0.19),
        outline=(255, 255, 255, 26),
        width=int(W * 0.006),
    )
    bg.alpha_composite(rim)

    icon = bg.convert("RGB").resize((SIZE, SIZE), Image.Resampling.LANCZOS)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    icon.save(OUT, optimize=True)
    print(OUT)


if __name__ == "__main__":
    main()

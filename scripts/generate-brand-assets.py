#!/usr/bin/env python3
"""Generate TypeTide platform icon assets from the checked-in brand master."""

from pathlib import Path
from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
MASTER = ROOT / "docs/branding/typetide-icon-master.png"
APPICON = ROOT / "macos/TypeTide/Assets.xcassets/AppIcon.appiconset"
BRANDMARK = ROOT / "macos/TypeTide/Assets.xcassets/BrandMark.imageset"
WINDOWS_ICON = ROOT / "windows/assets/app.ico"
FLOATING_SCREENSHOT = ROOT / "docs/screenshots/icon.png"


def cubic(p0, p1, p2, p3, steps=32):
    points = []
    for index in range(steps + 1):
        t = index / steps
        u = 1 - t
        points.append((
            u**3 * p0[0] + 3 * u**2 * t * p1[0] + 3 * u * t**2 * p2[0] + t**3 * p3[0],
            u**3 * p0[1] + 3 * u**2 * t * p1[1] + 3 * u * t**2 * p2[1] + t**3 * p3[1],
        ))
    return points


def make_template_mark(size: int) -> Image.Image:
    canvas_size = 512
    image = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)

    # One bold crest: the same particle-to-wave silhouette as the color master.
    outline = []
    outline += cubic((150, 350), (255, 350), (270, 132), (388, 132))
    outline += cubic((388, 132), (487, 132), (498, 250), (425, 288))
    outline += cubic((425, 288), (462, 232), (411, 204), (370, 217))
    outline += cubic((370, 217), (326, 232), (333, 340), (449, 377))
    outline += cubic((449, 377), (330, 402), (238, 397), (150, 350))
    draw.polygon(outline, fill=(0, 0, 0, 255))

    dots = [
        (73, 238, 12), (106, 218, 10), (139, 205, 8),
        (68, 277, 9), (102, 266, 13), (141, 255, 11), (178, 244, 9),
        (78, 316, 8), (112, 311, 11), (151, 301, 14), (192, 287, 11),
        (101, 349, 8), (139, 347, 10), (179, 338, 12), (220, 320, 10),
    ]
    for x, y, radius in dots:
        draw.ellipse((x - radius, y - radius, x + radius, y + radius), fill=(0, 0, 0, 255))

    return image.resize((size, size), Image.Resampling.LANCZOS)


def main() -> None:
    master = Image.open(MASTER).convert("RGBA")
    mac_sizes = {
        "appicon_16x16.png": 16,
        "appicon_16x16@2x.png": 32,
        "appicon_32x32.png": 32,
        "appicon_32x32@2x.png": 64,
        "appicon_128x128.png": 128,
        "appicon_128x128@2x.png": 256,
        "appicon_256x256.png": 256,
        "appicon_256x256@2x.png": 512,
        "appicon_512x512.png": 512,
        "appicon_512x512@2x.png": 1024,
    }
    for filename, size in mac_sizes.items():
        master.resize((size, size), Image.Resampling.LANCZOS).save(APPICON / filename)

    BRANDMARK.mkdir(parents=True, exist_ok=True)
    make_template_mark(32).save(BRANDMARK / "brand-mark.png")
    make_template_mark(64).save(BRANDMARK / "brand-mark@2x.png")

    # Keep the README's floating-button screenshot aligned with the real UI.
    screenshot = Image.open(FLOATING_SCREENSHOT).convert("RGBA")
    screenshot_draw = ImageDraw.Draw(screenshot)
    screenshot_draw.rounded_rectangle((966, 55, 1009, 99), radius=8, fill=(19, 119, 232, 255))
    mark = make_template_mark(34)
    white = Image.new("RGBA", mark.size, (255, 255, 255, 0))
    white.putalpha(mark.getchannel("A"))
    screenshot.alpha_composite(white, (971, 60))
    screenshot.save(FLOATING_SCREENSHOT)

    master.save(
        WINDOWS_ICON,
        format="ICO",
        sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)],
    )


if __name__ == "__main__":
    main()

"""Builds the Melo wordmark and the splash assets drawn from it.

Run from the project root: python tool/generate_logo.py

Writes the vector logo, the Android splash drawable and, through a headless
Chromium browser (Edge or Chrome, or MELO_BROWSER), the PNG renders used by
Flutter and the iOS launch screen. Needs fontTools and Pillow.
"""

import os
import shutil
import subprocess
import tempfile
from pathlib import Path

from fontTools.pens.boundsPen import BoundsPen
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen
from fontTools.ttLib import TTFont

ROOT = Path(__file__).resolve().parent.parent
FONT = ROOT / "assets/fonts/NunitoSans-Bold.ttf"
SVG_OUT = ROOT / "assets/branding/melo-logo.svg"
PNG_OUT = ROOT / "assets/branding/melo-logo.png"
ANDROID_OUT = ROOT / "android/app/src/main/res/drawable/launch_logo.xml"
IOS_LAUNCH = ROOT / "ios/Runner/Assets.xcassets/LaunchImage.imageset"

INDIGO = "#4B55A1"
YELLOW = "#F4CD87"
TEAL = "#7DB9A6"
LILAC = "#AA8FC6"

# Artwork coordinates follow the supplied reference image; this box hugs the ink.
VIEW_X, VIEW_Y, VIEW_W, VIEW_H = 70, 29, 990, 525

# Android 12+ masks the splash icon to a 192dp circle inside a 288dp square;
# at this width every part of the logo stays inside that circle. Keep in step
# with AppSizes.launchLogo.
LAUNCH_WIDTH = 168

TAGLINE = "Every Expression Has Meaning."
TAGLINE_CAP = 51
TAGLINE_STROKE = 5


def _num(value):
    return ("%.1f" % value).rstrip("0").rstrip(".")


def tagline_path(left, right, baseline):
    font = TTFont(str(FONT))
    glyphs = font.getGlyphSet()
    cmap = font.getBestCmap()
    advances = font["hmtx"]
    names = [cmap[ord(ch)] for ch in TAGLINE]
    # The cap height fixes the scale; tracking is solved so the ink spans left..right.
    scale = (TAGLINE_CAP - TAGLINE_STROKE) / font["OS/2"].sCapHeight

    def extent(track):
        x = 0
        pen = BoundsPen(glyphs)
        for name in names:
            glyphs[name].draw(TransformPen(pen, (1, 0, 0, 1, x, 0)))
            x += advances[name][0] + track
        return pen.bounds[0], pen.bounds[2]

    low, high = -100.0, 200.0
    for _ in range(50):
        track = (low + high) / 2
        start, end = extent(track)
        if (end - start) * scale < right - left - TAGLINE_STROKE:
            low = track
        else:
            high = track
    start, _ = extent(track)
    pen = SVGPathPen(glyphs, ntos=_num)
    x = 0
    for name in names:
        offset = left + TAGLINE_STROKE / 2 + (x - start) * scale
        glyphs[name].draw(
            TransformPen(pen, (scale, 0, 0, -scale, offset, baseline - TAGLINE_STROKE / 2))
        )
        x += advances[name][0] + track
    return pen.getCommands()


def drop_path(radius, length):
    r, l = radius, length
    return (
        f"M{-r},0 A{r},{r} 0 0 1 0,{-r} "
        f"C{_num(l * 0.45)},{-r} {_num(l * 0.82)},{_num(-r * 0.42)} {l},0 "
        f"C{_num(l * 0.82)},{_num(r * 0.42)} {_num(l * 0.45)},{r} 0,{r} "
        f"A{r},{r} 0 0 1 {-r},0Z"
    )


def circle_path(cx, cy, r):
    return f"M{cx - r},{cy} a{r},{r} 0 1,0 {2 * r},0 a{r},{r} 0 1,0 {-2 * r},0"


# (path, stroke width) drawn with round caps and joins.
STROKES = [
    ("M140,396 L174,178 L275,325 L378,162 L429,383", 76),
    (
        "M513,312 L598,296 Q630,288 629,258 C628,226 606,210 580,210 "
        "C535,210 508,250 508,296 C508,345 540,384 584,384 C610,384 630,374 641,360",
        57,
    ),
    (circle_path(873, 313, 96), 46),
    ("M846,341 Q873,367 900,341", 14),
]
FILLS = [
    "M685,119 A34,34 0 0 1 753,119 L738,378 A25.5,25.5 0 0 1 687,378Z",
    circle_path(840.5, 299, 10.5),
    circle_path(905.5, 300.5, 11),
]
# (centre of the round end, tip angle in degrees, radius, length, colour)
DROPS = [
    ((850, 62), 86, 31, 94, YELLOW),
    ((954, 96), 122, 31, 90, TEAL),
    ((1026, 187), 165, 32, 73, LILAC),
]


def svg(tagline):
    parts = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{VIEW_W}" height="{VIEW_H}" '
        f'viewBox="{VIEW_X} {VIEW_Y} {VIEW_W} {VIEW_H}">',
        "  <title>Melo</title>",
        f'  <g fill="none" stroke="{INDIGO}" stroke-linecap="round" stroke-linejoin="round">',
    ]
    parts += [f'    <path d="{d}" stroke-width="{w}"/>' for d, w in STROKES]
    parts.append("  </g>")
    parts.append(f'  <g fill="{INDIGO}">')
    parts += [f'    <path d="{d}"/>' for d in FILLS]
    parts.append(
        f'    <path d="{tagline}" stroke="{INDIGO}" stroke-width="{TAGLINE_STROKE}" '
        'stroke-linejoin="round"/>'
    )
    parts.append("  </g>")
    for (cx, cy), angle, r, length, colour in DROPS:
        parts.append(
            f'  <path transform="translate({cx} {cy}) rotate({angle})" '
            f'd="{drop_path(r, length)}" fill="{colour}"/>'
        )
    parts.append("</svg>")
    return "\n".join(parts) + "\n"


def android_vector(tagline):
    scale = LAUNCH_WIDTH / VIEW_W
    centre_x = VIEW_X + VIEW_W / 2
    centre_y = VIEW_Y + VIEW_H / 2
    lines = [
        '<?xml version="1.0" encoding="utf-8"?>',
        "<!-- Generated by tool/generate_logo.py. The full Melo logo, sized for the",
        "     Android 12+ splash icon (288dp, masked to a 192dp circle). -->",
        '<vector xmlns:android="http://schemas.android.com/apk/res/android"',
        '    android:width="288dp"',
        '    android:height="288dp"',
        '    android:viewportWidth="288"',
        '    android:viewportHeight="288">',
        "    <group",
        f'        android:translateX="{144 - centre_x * scale:.3f}"',
        f'        android:translateY="{144 - centre_y * scale:.3f}"',
        f'        android:scaleX="{scale:.5f}"',
        f'        android:scaleY="{scale:.5f}">',
    ]
    for d, width in STROKES:
        lines.append(
            f'        <path android:pathData="{d}" android:strokeColor="{INDIGO}" '
            f'android:strokeWidth="{width}" android:strokeLineCap="round" '
            'android:strokeLineJoin="round" android:fillColor="#00000000" />'
        )
    for d in FILLS:
        lines.append(f'        <path android:fillColor="{INDIGO}" android:pathData="{d}" />')
    lines.append(
        f'        <path android:fillColor="{INDIGO}" android:strokeColor="{INDIGO}" '
        f'android:strokeWidth="{TAGLINE_STROKE}" android:strokeLineJoin="round" '
        f'android:pathData="{tagline}" />'
    )
    for (cx, cy), angle, r, length, colour in DROPS:
        lines.append(
            f'        <group android:translateX="{cx}" android:translateY="{cy}" '
            f'android:rotation="{angle}">'
        )
        lines.append(
            f'            <path android:fillColor="{colour}" '
            f'android:pathData="{drop_path(r, length)}" />'
        )
        lines.append("        </group>")
    lines += ["    </group>", "</vector>"]
    return "\n".join(lines) + "\n"


def browser():
    candidates = [
        os.environ.get("MELO_BROWSER"),
        r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
        r"C:\Program Files\Google\Chrome\Application\chrome.exe",
        "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
        shutil.which("google-chrome"),
        shutil.which("chromium"),
    ]
    for candidate in candidates:
        if candidate and Path(candidate).exists():
            return candidate
    raise SystemExit("No Chromium browser found; set MELO_BROWSER.")


def render(source, target, pixel_width):
    """Screenshots the SVG with a transparent background at pixel_width."""
    with tempfile.TemporaryDirectory() as scratch:
        shot = Path(scratch) / "shot.png"
        subprocess.run(
            [
                browser(),
                "--headless",
                "--disable-gpu",
                "--hide-scrollbars",
                "--default-background-color=00000000",
                f"--force-device-scale-factor={pixel_width / VIEW_W}",
                f"--window-size={VIEW_W},{VIEW_H}",
                f"--screenshot={shot}",
                source.as_uri(),
            ],
            check=True,
            capture_output=True,
        )
        shutil.copyfile(shot, target)


def main():
    tagline = tagline_path(72, 1040, 539)
    SVG_OUT.write_text(svg(tagline), encoding="utf-8")
    ANDROID_OUT.write_text(android_vector(tagline), encoding="utf-8")
    render(SVG_OUT, PNG_OUT, VIEW_W * 2)
    for scale, suffix in ((1, ""), (2, "@2x"), (3, "@3x")):
        render(SVG_OUT, IOS_LAUNCH / f"LaunchImage{suffix}.png", LAUNCH_WIDTH * scale)


if __name__ == "__main__":
    main()

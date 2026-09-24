#!/usr/bin/env python3
"""
Generate the app icon: the imp's head and shoulders (front frame of the enemy
sheet) over a dark red backdrop with a chunky pixel frame, written at every size
the asset catalog wants for macOS and iOS.

    python3 tools/sprite_art/icon.py            # writes fpsgame1/Assets.xcassets/AppIcon.appiconset/*
    python3 tools/sprite_art/icon.py --preview  # writes build/sprite_art/icon.png only

The 64×64 pixel art is resampled nearest-neighbour, so every size stays crisp.
"""

import json
import os
import struct
import sys
import zlib

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
ROOT = os.path.dirname(os.path.dirname(HERE))

from pixelart import Canvas, TRANSPARENT, mix, rgb  # noqa: E402
import imp as imp_art  # noqa: E402

SIZE = 64
SIZES = [16, 32, 64, 128, 256, 512, 1024]
ICON_DIR = os.path.join(ROOT, "fpsgame1", "Assets.xcassets", "AppIcon.appiconset")


def draw_icon():
    cv = Canvas(SIZE, SIZE)
    top, bottom = rgb(96, 14, 14), rgb(12, 6, 8)
    glow = rgb(190, 40, 20)
    cx, cy = SIZE / 2, SIZE * 0.42
    for y in range(SIZE):
        for x in range(SIZE):
            base = mix(top, bottom, y / (SIZE - 1))
            # radial glow behind the head, dithered like the sprites
            d = ((x - cx) ** 2 + ((y - cy) * 1.2) ** 2) ** 0.5 / (SIZE * 0.5)
            g = max(0.0, 1.0 - d) ** 2 * 0.7
            if (x + y) % 2 == 0:
                g *= 0.8
            cv.set(x, y, mix(base, glow, g))

    # scanlines: every fourth row a touch darker, the CRT look of the title screen
    for y in range(0, SIZE, 4):
        for x in range(SIZE):
            cv.set(x, y, mix(cv.get(x, y), bottom, 0.25))

    # the imp, front view, horns to mid-torso
    imp = imp_art.draw_standing(0, 0)
    for y in range(SIZE):
        for x in range(imp.w):
            p = imp.get(x, y)
            if p is not TRANSPARENT and 0 <= x < SIZE:
                cv.set(x, y, p)

    # pixel frame: dark rim with a lit inner edge
    rim, lit = rgb(28, 8, 8), rgb(150, 70, 30)
    for i in range(SIZE):
        for t in range(2):
            cv.set(i, t, rim)
            cv.set(i, SIZE - 1 - t, rim)
            cv.set(t, i, rim)
            cv.set(SIZE - 1 - t, i, rim)
    for i in range(2, SIZE - 2):
        cv.set(i, 2, lit)
        cv.set(2, i, lit)
        cv.set(i, SIZE - 3, mix(lit, rim, 0.5))
        cv.set(SIZE - 3, i, mix(lit, rim, 0.5))
    return cv


def write_square_png(path, cv, size):
    """Opaque RGB PNG of the canvas resampled (nearest neighbour) to size×size."""
    rows = []
    for Y in range(size):
        sy = Y * cv.h // size
        row = bytearray([0])
        for X in range(size):
            p = cv.get(X * cv.w // size, sy)
            row += bytes(p if p is not TRANSPARENT else (0, 0, 0))
        rows.append(bytes(row))
    raw = b"".join(rows)

    def chunk(tag, data):
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", size, size, 8, 2, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")
    with open(path, "wb") as f:
        f.write(png)


def catalog_entries():
    """Contents.json images: every mac size/scale pair plus the iOS universal icon."""
    entries = [{"filename": "icon_1024.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"}]
    for points in (16, 32, 128, 256, 512):
        for scale in (1, 2):
            entries.append({
                "filename": f"icon_{points * scale}.png",
                "idiom": "mac",
                "scale": f"{scale}x",
                "size": f"{points}x{points}",
            })
    return entries


def main(argv):
    cv = draw_icon()
    preview_dir = os.path.join(ROOT, "build", "sprite_art")
    os.makedirs(preview_dir, exist_ok=True)
    write_square_png(os.path.join(preview_dir, "icon.png"), cv, 256)
    if "--preview" in argv:
        print("wrote build/sprite_art/icon.png")
        return

    os.makedirs(ICON_DIR, exist_ok=True)
    for size in SIZES:
        write_square_png(os.path.join(ICON_DIR, f"icon_{size}.png"), cv, size)
    contents = {"images": catalog_entries(), "info": {"author": "xcode", "version": 1}}
    with open(os.path.join(ICON_DIR, "Contents.json"), "w") as f:
        json.dump(contents, f, indent=2)
        f.write("\n")
    print(f"wrote {len(SIZES)} icons to {os.path.relpath(ICON_DIR, ROOT)}")


if __name__ == "__main__":
    main(sys.argv[1:])

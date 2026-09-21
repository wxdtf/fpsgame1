"""Exit portal texture, 64x64, animated.

This is the design reference for TextureAtlas.generateExitPortalTexture(time:) in
Textures.swift, which is a line-for-line port: keep the two in sync. Every time
term uses an angular frequency that is a multiple of 0.5 rad/s so the whole
animation repeats every 4π seconds (TextureAtlas.exitPortalPeriod).

Layout: a riveted dark-iron frame with four glowing rune plates, a three-armed
vortex spiralling into a white-green core, orbiting sparks, and "EXIT" over it.
"""

import math

from pixelart import Canvas, rgb

W = H = 64
SIZE = 64


def noise01(x, y, seed):
    h = (x * 374761393 + y * 668265263 + seed * 1274126177) & 0xFFFFFFFF
    h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
    h = h ^ (h >> 16)
    return (h & 0xFF) / 255.0


def clamp(v):
    return max(0, min(255, int(v)))


LETTERS = [
    [[1, 1, 1], [1, 0, 0], [1, 1, 0], [1, 0, 0], [1, 1, 1]],
    [[1, 0, 1], [0, 1, 0], [0, 1, 0], [0, 1, 0], [1, 0, 1]],
    [[1, 1, 1], [0, 1, 0], [0, 1, 0], [0, 1, 0], [1, 1, 1]],
    [[1, 1, 1], [0, 1, 0], [0, 1, 0], [0, 1, 0], [0, 1, 0]],
]


def pixel(x, y, t):
    """Colour of one texel at time t. Mirrors the Swift function exactly."""
    cx = cy = SIZE / 2.0
    maxR = SIZE / 2.0 - 5.0
    frame_w = 5

    # --- iron frame with rivets and rune plates ---------------------------
    if x < frame_w or x >= SIZE - frame_w or y < frame_w or y >= SIZE - frame_w:
        n = noise01(x, y, 700)
        v = 34 + int(n * 14)
        # bevel: lighter on the top/left edges, darker on the inner edge
        edge_in = min(x, y, SIZE - 1 - x, SIZE - 1 - y)
        if edge_in == 0:
            v += 22
        elif edge_in == frame_w - 1:
            v -= 12
        r, g, b = v, v + 4, v + 8
        # rivets in the corners and mid-sides
        for rx, ry in ((2, 2), (61, 2), (2, 61), (61, 61), (31, 2), (2, 31), (61, 31), (31, 61)):
            if abs(x - rx) <= 1 and abs(y - ry) <= 1:
                bright = 70 if (x == rx and y == ry) else 52
                r, g, b = bright, bright + 4, bright + 6
        # rune plates: a glowing slot on each side, pulsing
        pulse = 0.55 + 0.45 * math.sin(t * 3.0)
        on_plate = (y in (1, 2) and 22 <= x <= 41) or (y in (61, 62) and 22 <= x <= 41) or \
                   (x in (1, 2) and 22 <= y <= 41) or (x in (61, 62) and 22 <= y <= 41)
        if on_plate:
            k = (x if y in (1, 2, 61, 62) else y) - 22
            if k % 5 in (1, 2, 3):
                r, g, b = int(20 + 40 * pulse), int(90 + 140 * pulse), int(40 + 60 * pulse)
        # inner lip glow from the vortex
        if edge_in == frame_w - 1:
            g += int(30 * pulse)
        return rgb(clamp(r), clamp(g), clamp(b))

    dx, dy = x + 0.5 - cx, y + 0.5 - cy
    dist = math.sqrt(dx * dx + dy * dy)
    nd = dist / maxR
    if nd > 1.0:
        # stone lip between the frame and the vortex
        n = noise01(x, y, 90)
        v = 22 + int(n * 10)
        return rgb(v, v + 3, v + 2)

    # --- vortex ---------------------------------------------------------------
    ang = math.atan2(dy, dx)
    swirl1 = 0.5 + 0.5 * math.sin(ang * 3.0 + dist * 0.45 - t * 2.0)     # three arms
    swirl2 = 0.5 + 0.5 * math.sin(ang * 5.0 - dist * 0.7 + t * 1.5)      # counter-spiral
    rings = 0.5 + 0.5 * math.sin(dist * 1.4 - t * 3.0)                   # rings flowing inward
    depth = (1.0 - nd) ** 1.6
    pulse = 0.85 + 0.15 * math.sin(t * 4.0)
    core = math.exp(-(dist * dist) / 18.0) * pulse

    v = 0.15 + 0.55 * swirl1 * depth + 0.2 * swirl2 * (1.0 - depth) + 0.15 * rings * depth
    r = 10 + 40 * v + 120 * core
    g = 40 + 170 * v + 200 * core
    b = 30 + 90 * v * (1.0 - depth) + 60 * swirl2 + 190 * core
    # dark eye between the arms near the rim
    edge = 1.0 if nd > 0.78 else 0.0
    ring_glow = edge * (0.5 + 0.5 * math.sin(t * 5.0 + nd * 6.0))
    r += 60 * ring_glow
    g += 90 * ring_glow
    b += 40 * ring_glow

    # --- sparks orbiting inward -------------------------------------------------
    for k in range(6):
        phase = (t * 0.5 + k * (1.0 / 6.0)) % 1.0
        sr = 4.0 + (1.0 - phase) * (maxR - 6.0)
        sa = t * 1.5 + k * 1.0472 + phase * 6.0
        sx = cx + math.cos(sa) * sr
        sy = cy + math.sin(sa) * sr
        if abs(x + 0.5 - sx) < 1.0 and abs(y + 0.5 - sy) < 1.0:
            r, g, b = 230, 255, 240
    return rgb(clamp(r), clamp(g), clamp(b))


def frame(t):
    cv = Canvas(W, H)
    for y in range(SIZE):
        for x in range(SIZE):
            cv.set(x, y, pixel(x, y, t))
    # "EXIT" over the vortex, pulsing, with a dark outline
    text_pulse = 0.8 + 0.2 * math.sin(t * 6.0)
    text = rgb(int(255 * text_pulse), int(255 * text_pulse), int(230 * text_pulse))
    dark = rgb(6, 20, 10)
    sx0, sy0 = SIZE // 2 - 9, SIZE // 2 - 3
    for li, letter in enumerate(LETTERS):
        ox = sx0 + li * 5
        for ry, row in enumerate(letter):
            for rx, val in enumerate(row):
                if val:
                    for ddx in (-1, 0, 1):
                        for ddy in (-1, 0, 1):
                            if ddx or ddy:
                                cv.set(ox + rx + ddx, sy0 + ry + ddy, dark)
    for li, letter in enumerate(LETTERS):
        ox = sx0 + li * 5
        for ry, row in enumerate(letter):
            for rx, val in enumerate(row):
                if val:
                    cv.set(ox + rx, sy0 + ry, text)
    return cv


def frames(times=(0.0, 0.8, 1.6, 2.4, 3.2, 4.0, 4.8, 5.6)):
    return [frame(t) for t in times]

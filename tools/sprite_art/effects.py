"""Hit effects, 24x24: a spurt of blood thrown out of an enemy when a shot lands.

Frames 0-3 are red blood (imp, demon, soldier), 4-7 the same burst in the
Baron's green ichor. Each burst: a flash of droplets bursting from the impact
point, then the drops flying outward and falling under gravity, then a few
last drops and a fading mist.
"""

import math

from pixelart import Canvas, mix, ramp, rgb

W, H = 24, 24

RED = ramp(rgb(170, 18, 14), deep=rgb(70, 6, 6), hi=rgb(240, 110, 90))
GREEN = ramp(rgb(60, 180, 50), deep=rgb(18, 80, 18), hi=rgb(180, 255, 160))
OUTLINE_RED = rgb(50, 4, 4)
OUTLINE_GREEN = rgb(10, 50, 10)

# (angle, speed, size) of the droplets, fixed so the burst reads the same every time
DROPS = [(-1.2, 1.0, 2.2), (-0.6, 1.35, 1.6), (0.1, 1.15, 1.9), (0.7, 0.9, 1.4), (1.5, 1.25, 1.7),
         (2.3, 1.05, 1.5), (3.0, 1.3, 1.9), (-2.0, 0.85, 1.3), (-2.7, 1.2, 1.6), (0.4, 0.55, 1.2),
         (-1.6, 0.5, 1.1), (2.0, 0.6, 1.0)]


def burst(mat, outline, phase):
    """phase 0..3"""
    cv = Canvas(W, H)
    cx, cy = 12, 12
    t = 0.55 + phase * 0.5                   # time since impact
    gravity = 1.6
    if phase == 0:
        # impact flash: a tight splat with a bright core
        cv.paint(cv.mask().circle(cx, cy, 3.6), mat[1])
        cv.paint(cv.mask().circle(cx - 0.5, cy - 0.5, 2.3), mat[2])
        cv.paint(cv.mask().circle(cx - 1, cy - 1, 1.2), mat[4])
    for i, (a, spd, size) in enumerate(DROPS):
        if phase == 3 and i % 3 != 0:
            continue                          # most drops have hit the floor
        r = t * spd * 6.5
        x = cx + math.cos(a) * r
        y = cy + math.sin(a) * r * 0.8 + gravity * t * t * 2.2
        s = size * (1.0 if phase < 2 else 0.75)
        if phase == 0:
            s *= 0.8
        if not (-2 <= x < W + 2 and -2 <= y < H + 2):
            continue
        cv.paint(cv.mask().circle(x, y, s), mat[2] if i % 2 else mat[1])
        cv.set(int(x - 0.5), int(y - 0.5), mat[3])
        # motion streak back toward the impact point while the drops are fast
        if phase <= 1:
            for k in range(1, 3):
                sx = x - math.cos(a) * k * 1.4
                sy = y - math.sin(a) * k * 1.1
                cv.set(int(sx), int(sy), mat[1] if k == 1 else mat[0])
    if phase >= 2:
        # thin mist left hanging where the hit landed
        for k in range(5):
            mx = cx + math.cos(k * 1.9) * (2 + phase)
            my = cy - 1 + math.sin(k * 1.9) * 1.5
            cv.set(int(mx), int(my), mix(mat[1], rgb(60, 50, 50), 0.4))
    cv.outline(outline)
    return cv


def frames():
    return [burst(RED, OUTLINE_RED, p) for p in range(4)] + [burst(GREEN, OUTLINE_GREEN, p) for p in range(4)]

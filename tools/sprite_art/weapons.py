"""First-person weapon sprites, seen from behind the marine's hands.

Canvas 240x150 (the 1.6:1 the game shows them at, so no stretching). Frame
counts match WeaponDefinition.animationFrames: fist 4, pistol 4, shotgun 5,
chaingun 3, rocket launcher 4. Frame 0 is idle; the rest play once per shot.
"""

import math

from pixelart import Canvas, ramp, rgb, mix

W, H = 240, 150
CX = 120

STEEL = ramp(rgb(92, 96, 106), deep=rgb(22, 24, 30), hi=rgb(180, 186, 198))
STEEL_DK = ramp(rgb(58, 60, 68), deep=rgb(12, 12, 16), hi=rgb(130, 134, 144))
GUNMETAL = ramp(rgb(40, 42, 50), deep=rgb(8, 8, 12), hi=rgb(104, 108, 120))
WOOD = ramp(rgb(126, 78, 40), deep=rgb(44, 24, 10), hi=rgb(200, 142, 88))
GLOVE = ramp(rgb(112, 74, 44), deep=rgb(36, 20, 10), hi=rgb(184, 134, 92))
SKIN = ramp(rgb(214, 168, 132), deep=rgb(88, 56, 40), hi=rgb(248, 214, 184))
SLEEVE = ramp(rgb(62, 92, 64), deep=rgb(18, 30, 20), hi=rgb(122, 160, 122))
BRASS = ramp(rgb(190, 150, 60), deep=rgb(80, 58, 16), hi=rgb(248, 226, 150))
RED = ramp(rgb(170, 40, 34), deep=rgb(60, 10, 8), hi=rgb(240, 120, 100))
BONE = ramp(rgb(226, 214, 190), deep=rgb(100, 90, 70), hi=rgb(255, 250, 236))
WHITE_WRAP = ramp(rgb(196, 190, 176), deep=rgb(80, 76, 66), hi=rgb(240, 236, 226))
OUTLINE = rgb(10, 10, 14)
FLASH = [rgb(255, 252, 220), rgb(255, 220, 90), rgb(255, 150, 30), rgb(200, 70, 10)]
SMOKE = [rgb(150, 146, 140), rgb(110, 106, 100), rgb(80, 78, 74)]


def muzzle_flash(cv, x, y, r, spikes=6, seed=0):
    """Layered star-shaped flash."""
    for i, col in enumerate(FLASH[::-1]):
        rr = r - i * (r / 4.5)
        if rr <= 0:
            continue
        m = cv.mask().circle(x, y, rr * 0.75)
        for k in range(spikes):
            a = (k / spikes) * math.tau + seed * 0.4
            tx, ty = x + math.cos(a) * rr * 1.5, y + math.sin(a) * rr * 1.5
            m.poly([(x + math.cos(a + 0.5) * rr * 0.4, y + math.sin(a + 0.5) * rr * 0.4),
                    (x + math.cos(a - 0.5) * rr * 0.4, y + math.sin(a - 0.5) * rr * 0.4), (tx, ty)])
        cv.paint(m, col)


def smoke_puff(cv, x, y, r, seed=0):
    for i, col in enumerate(SMOKE):
        for k in range(3):
            a = seed * 1.3 + k * 2.1
            cv.paint(cv.mask().circle(x + math.cos(a) * r * 0.5, y - k * r * 0.4 + math.sin(a) * r * 0.3,
                                      r * (0.8 - i * 0.2)), col)


def hand_on_grip(cv, x, y, w=30, h=44, thumb=True, glove=True):
    """A gloved hand wrapping a grip, seen from behind. (x, y) is the top centre."""
    mat = GLOVE if glove else SKIN
    m = cv.mask()
    m.oval(x, y + h * 0.55, w * 0.5, h * 0.45)
    m.rect(x - w * 0.5, y + h * 0.4, w, h * 0.6)
    cv.part(m, mat, thickness=4, rim=2)
    # knuckles
    for k in range(4):
        kx = x - w * 0.36 + k * w * 0.24
        cv.part(cv.mask().oval(kx, y + h * 0.28 + (2 if k in (0, 3) else 0), w * 0.11, h * 0.09), mat, thickness=2, rim=1, shadow=1)
    if thumb:
        cv.part(cv.mask().tapered(x + w * 0.35, y + h * 0.35, w * 0.12, x + w * 0.05, y + h * 0.05, w * 0.1), mat, thickness=2, rim=1)
    # sleeve below
    cv.part(cv.mask().rect(x - w * 0.62, y + h * 0.9, w * 1.24, H), SLEEVE, thickness=3, rim=1)


def draw_pistol(frame):
    cv = Canvas(W, H)
    recoil = {1: -12, 2: -6, 3: -2}.get(frame, 0)      # muzzle climbs, whole gun lifts
    slide = {1: 0, 2: 14, 3: 6}.get(frame, 0)            # slide travels back toward the viewer
    gx, gy = CX + 18, 62 + recoil

    # grip and hand
    cv.part(cv.mask().poly([(gx - 14, gy + 40), (gx + 16, gy + 40), (gx + 22, gy + 90), (gx - 6, gy + 92)]), GUNMETAL, thickness=3, rim=2)
    hand_on_grip(cv, gx + 6, gy + 44, w=40, h=60)

    # frame + trigger guard
    cv.part(cv.mask().poly([(gx - 20, gy + 30), (gx + 20, gy + 30), (gx + 24, gy + 48), (gx - 24, gy + 48)]), STEEL_DK, thickness=3, rim=1)
    cv.part(cv.mask().oval(gx - 22, gy + 52, 7, 9), STEEL_DK, thickness=2, rim=1)
    cv.paint(cv.mask().oval(gx - 22, gy + 52, 4, 6), OUTLINE)

    # slide: a trapezoid receding from the viewer; the far end is the muzzle
    top = gy - 18 + slide * 0.2
    near = gy + 32 + slide
    m = cv.mask().poly([(gx - 13, top), (gx + 13, top), (gx + 22, near), (gx - 22, near)])
    cv.part(m, STEEL, thickness=4, rim=3)
    # serrations at the rear of the slide, ejection port
    for k in range(5):
        cv.paint(cv.mask().rect(gx - 16 + k * 8, near - 10, 3, 8), STEEL[1])
    cv.paint(cv.mask().rect(gx + 4, gy + 4 + slide * 0.5, 9, 7), STEEL[0])
    # rear sight and hammer
    cv.part(cv.mask().rect(gx - 8, near - 4, 16, 5), GUNMETAL, thickness=1, rim=1)
    cv.paint(cv.mask().rect(gx - 2, near - 3, 4, 3), OUTLINE)
    cv.part(cv.mask().poly([(gx + 10, near + 2), (gx + 18, near + 2), (gx + 16, near + 10), (gx + 12, near + 10)]), GUNMETAL, thickness=1, rim=1)
    # muzzle: bore at the far end
    cv.part(cv.mask().oval(gx, top + 1, 9, 4), STEEL_DK, thickness=1, rim=1)
    cv.paint(cv.mask().oval(gx, top + 1, 5, 2), OUTLINE)
    cv.paint(cv.mask().rect(gx - 2, top - 5, 4, 5), STEEL[3])   # front sight

    if frame == 1:
        muzzle_flash(cv, gx, top - 14, 26, spikes=7, seed=1)
    elif frame == 2:
        smoke_puff(cv, gx, top - 10, 9, seed=2)
        # ejected casing
        cv.part(cv.mask().oval(gx + 30, gy + 4, 5, 2.5), BRASS, thickness=1, rim=1)

    cv.outline(OUTLINE)
    return cv


def draw_shotgun(frame):
    cv = Canvas(W, H)
    recoil = {1: -16, 2: -8, 3: -3, 4: -1}.get(frame, 0)
    pump = {3: 18, 4: 8}.get(frame, 0)                    # fore-end slides toward the viewer
    gx, gy = CX + 6, 20 + recoil

    # stock/receiver held at the hip on the right, disappearing off the bottom
    cv.part(cv.mask().poly([(gx + 12, gy + 84), (gx + 52, gy + 80), (gx + 78, gy + 150), (gx + 30, gy + 150)]), WOOD, thickness=4, rim=2)
    cv.part(cv.mask().poly([(gx - 18, gy + 70), (gx + 36, gy + 70), (gx + 50, gy + 96), (gx - 24, gy + 96)]), STEEL_DK, thickness=4, rim=2)
    # trigger hand on the grip
    hand_on_grip(cv, gx + 40, gy + 96, w=42, h=56)

    # barrel and magazine tube: long trapezoid to the far muzzle
    top = gy + 2
    m = cv.mask().poly([(gx - 7, top), (gx + 7, top), (gx + 18, gy + 74), (gx - 18, gy + 74)])
    cv.part(m, STEEL, thickness=4, rim=3)
    m = cv.mask().poly([(gx - 5, top + 6), (gx + 5, top + 6), (gx + 14, gy + 76), (gx - 14, gy + 76)])
    cv.part(m, STEEL_DK, thickness=3, rim=1, shadow=1)   # tube below the barrel
    cv.paint(cv.mask().rect(gx - 1, top - 4, 3, 5), STEEL[3])   # bead sight
    cv.part(cv.mask().oval(gx, top, 7, 3), STEEL_DK, thickness=1, rim=1)
    cv.paint(cv.mask().oval(gx, top, 4, 1.5), OUTLINE)

    # pump fore-end (ribbed wood) with the support hand on it
    py = gy + 30 + pump
    m = cv.mask().poly([(gx - 12, py), (gx + 12, py), (gx + 18, py + 28), (gx - 18, py + 28)])
    cv.part(m, WOOD, thickness=3, rim=2)
    for k in range(4):
        cv.paint(cv.mask().rect(gx - 14 + k * 8, py + 4, 2, 20), WOOD[1])
    hand_on_grip(cv, gx - 10, py + 14, w=38, h=52, thumb=False)

    if frame == 1:
        muzzle_flash(cv, gx, top - 18, 36, spikes=9, seed=3)
    elif frame == 2:
        smoke_puff(cv, gx, top - 12, 12, seed=1)
    elif frame == 3:
        # shell ejected from the port
        cv.part(cv.mask().oval(gx + 44, gy + 60, 8, 4), RED, thickness=1, rim=1)
        cv.paint(cv.mask().oval(gx + 50, gy + 60, 2.5, 3), BRASS[3])

    cv.outline(OUTLINE)
    return cv


def draw_chaingun(frame):
    cv = Canvas(W, H)
    spin = frame * (math.tau / 12)    # barrel cluster rotates between the two firing frames
    gx, gy = CX + 4, 26

    # body: heavy receiver box, ammo drum on the left
    cv.part(cv.mask().poly([(gx - 40, gy + 60), (gx + 40, gy + 60), (gx + 56, gy + 150), (gx - 56, gy + 150)]), GUNMETAL, thickness=5, rim=3)
    cv.part(cv.mask().oval(gx - 62, gy + 92, 22, 26), STEEL_DK, thickness=4, rim=2)
    cv.paint(cv.mask().oval(gx - 62, gy + 92, 10, 12), STEEL_DK[1])
    # feed belt with brass rounds
    for k in range(6):
        cv.part(cv.mask().oval(gx - 40 + k * 3, gy + 72 + k * 12, 5, 2.5), BRASS, thickness=1, rim=1)
    # grips and hands
    cv.part(cv.mask().rect(gx + 30, gy + 96, 16, 30), GUNMETAL, thickness=2, rim=1)
    hand_on_grip(cv, gx + 38, gy + 100, w=42, h=50)
    cv.part(cv.mask().rect(gx - 40, gy + 100, 16, 26), GUNMETAL, thickness=2, rim=1)
    hand_on_grip(cv, gx - 34, gy + 104, w=40, h=48, thumb=False)

    # barrel cluster: six barrels around a hub, receding to the muzzle plate
    hub_far = (gx, gy + 6)
    hub_near = (gx, gy + 58)
    cv.part(cv.mask().tapered(hub_far[0], hub_far[1], 20, hub_near[0], hub_near[1], 30), STEEL_DK, thickness=4, rim=2)
    barrels = []
    for k in range(6):
        a = spin + k * math.tau / 6
        bx_far = hub_far[0] + math.cos(a) * 15
        by_far = hub_far[1] + math.sin(a) * 9
        bx_near = hub_near[0] + math.cos(a) * 24
        by_near = hub_near[1] + math.sin(a) * 14
        barrels.append((math.sin(a), bx_far, by_far, bx_near, by_near))
    for _, xf, yf, xn, yn in sorted(barrels):
        cv.part(cv.mask().tapered(xf, yf, 3.5, xn, yn, 5), STEEL, thickness=2, rim=1)
    # muzzle plate and bores
    cv.part(cv.mask().oval(hub_far[0], hub_far[1], 22, 13), STEEL_DK, thickness=2, rim=1, shadow=1)
    for _, xf, yf, _, _ in barrels:
        cv.paint(cv.mask().oval(xf, yf, 3, 2), OUTLINE)
        cv.paint(cv.mask().oval(xf, yf, 1.5, 1), STEEL_DK[1])

    if frame >= 1:
        muzzle_flash(cv, gx, gy - 6, 30 if frame == 1 else 24, spikes=8, seed=frame)
        for k in range(3):
            smoke_puff(cv, gx - 30 + k * 30, gy - 2, 5, seed=k + frame)

    cv.outline(OUTLINE)
    return cv


def draw_launcher(frame):
    cv = Canvas(W, H)
    recoil = {1: 10, 2: 5}.get(frame, 0)                  # the tube kicks back toward the viewer
    gx, gy = CX + 2, 18 + recoil

    # shoulder rest / stock off to the right, pistol grip with hand
    cv.part(cv.mask().poly([(gx + 30, gy + 90), (gx + 70, gy + 86), (gx + 90, gy + 150), (gx + 50, gy + 150)]), GUNMETAL, thickness=4, rim=2)
    cv.part(cv.mask().rect(gx + 22, gy + 94, 18, 32), GUNMETAL, thickness=2, rim=1)
    hand_on_grip(cv, gx + 31, gy + 98, w=42, h=52)
    cv.part(cv.mask().rect(gx - 46, gy + 92, 16, 28), GUNMETAL, thickness=2, rim=1)
    hand_on_grip(cv, gx - 38, gy + 96, w=40, h=48, thumb=False)

    # the tube: a wide cylinder receding to the big muzzle ring
    m = cv.mask().tapered(gx, gy + 8, 30, gx, gy + 76, 40)
    cv.part(m, STEEL_DK, thickness=6, rim=3)
    # reinforcing bands
    for t, r in ((0.25, 33), (0.6, 37)):
        yy = gy + 8 + (76 - 8) * t
        cv.part(cv.mask().oval(gx, yy, r, r * 0.55), STEEL, thickness=2, rim=1, shadow=1)
        cv.paint(cv.mask().oval(gx, yy - 2, r - 6, (r - 6) * 0.55), STEEL_DK[2])
    # warning stripes
    for k in range(3):
        cv.paint(cv.mask().poly([(gx + 14 + k * 8, gy + 40), (gx + 18 + k * 8, gy + 40), (gx + 12 + k * 8, gy + 62), (gx + 8 + k * 8, gy + 62)]), BRASS[2])
    # muzzle ring and the bore, with a rocket's nose showing when loaded
    cv.part(cv.mask().oval(gx, gy + 8, 30, 17), STEEL, thickness=3, rim=2)
    cv.paint(cv.mask().oval(gx, gy + 8, 22, 12), OUTLINE)
    if frame in (0, 3):
        cv.part(cv.mask().oval(gx, gy + 9, 14, 8), RED, thickness=3, rim=2, contact=False)
        cv.paint(cv.mask().oval(gx, gy + 9, 5, 3), RED[4])
    # sight post
    cv.part(cv.mask().rect(gx - 30, gy + 20, 6, 30), STEEL, thickness=1, rim=1)
    cv.paint(cv.mask().rect(gx - 29, gy + 20, 4, 4), RED[3])

    if frame == 1:
        muzzle_flash(cv, gx, gy - 12, 44, spikes=10, seed=5)
        for k in range(4):
            smoke_puff(cv, gx - 45 + k * 30, gy + 4, 10, seed=k)
    elif frame == 2:
        for k in range(5):
            smoke_puff(cv, gx - 50 + k * 25, gy - 6 - (k % 2) * 8, 12, seed=k + 3)

    cv.outline(OUTLINE)
    return cv


def draw_fist(frame):
    cv = Canvas(W, H)
    # the right fist rests at the bottom right; the punch drives it up and into the centre
    punch = {1: 1.0, 2: 0.55, 3: 0.15}.get(frame, 0.0)
    fx = 172 - punch * 60
    fy = 112 - punch * 50
    sc = 1.0 + punch * 0.18

    # forearm coming in from the bottom right, wrapped in a bandage at the wrist
    cv.part(cv.mask().tapered(fx + 8, fy + 26 * sc, 22 * sc, 224, 176, 30 * sc), SLEEVE, thickness=4, rim=2)
    cv.part(cv.mask().tapered(fx + 2, fy + 22 * sc, 21 * sc, fx + 16, fy + 40 * sc, 24 * sc), SKIN, thickness=4, rim=2)
    for k in range(3):
        cv.paint(cv.mask().line(fx - 12 * sc + k * 3, fy + 30 * sc + k * 5, fx + 30 * sc + k * 3, fy + 24 * sc + k * 5, thick=3), WHITE_WRAP[2 + (k % 2)])

    # palm block behind the fingers
    cv.part(cv.mask().oval(fx, fy + 6 * sc, 30 * sc, 20 * sc), SKIN, thickness=5, rim=2)

    # four curled fingers: vertical segments with rounded knuckles on top, seen from behind
    for k in range(4):
        cx = fx - 22 * sc + k * 14.5 * sc
        top = fy - 16 * sc - (3 * sc if k in (1, 2) else 0)
        m = cv.mask()
        m.rect(cx - 6 * sc, top, 12 * sc, 26 * sc)
        m.oval(cx, top, 6 * sc, 6 * sc)
        cv.part(m, SKIN, thickness=4, rim=2)
        # second joint crease and a knuckle highlight
        cv.paint(cv.mask().rect(cx - 5 * sc, top + 12 * sc, 10 * sc, 1.5), SKIN[1])
        cv.paint(cv.mask().oval(cx - 1, top - 1, 2.5 * sc, 1.5 * sc), SKIN[4])

    # thumb wrapping across the fingers, nail at the tip
    cv.part(cv.mask().tapered(fx - 30 * sc, fy + 10 * sc, 7 * sc, fx + 12 * sc, fy + 14 * sc, 6.5 * sc), SKIN, thickness=4, rim=2)
    cv.part(cv.mask().oval(fx + 13 * sc, fy + 14 * sc, 4 * sc, 3 * sc), BONE, thickness=1, rim=1, shadow=1)
    cv.paint(cv.mask().rect(fx - 12 * sc, fy + 8 * sc, 1.5, 10 * sc), SKIN[1])   # thumb joint crease

    # impact lines on the full-extension frame
    if frame == 1:
        for k, (dx, dy) in enumerate(((-1, -0.6), (-0.2, -1), (0.6, -0.8))):
            x0, y0 = fx + dx * 44, fy + dy * 40
            cv.paint(cv.mask().line(x0, y0, x0 + dx * 16, y0 + dy * 16, thick=2), FLASH[1])

    cv.outline(OUTLINE)
    return cv


SHEETS = {
    "fist": (draw_fist, 4),
    "pistol": (draw_pistol, 4),
    "shotgun": (draw_shotgun, 5),
    "chaingun": (draw_chaingun, 3),
    "rocketLauncher": (draw_launcher, 4),
}


def frames_for(name):
    fn, count = SHEETS[name]
    return [fn(f) for f in range(count)]
